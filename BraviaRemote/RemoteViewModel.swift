import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class RemoteViewModel: ObservableObject {
    // Saved TVs
    @Published private(set) var tvs: [SavedTV]
    @Published private(set) var currentID: UUID?

    // Current TV state
    @Published private(set) var isReachable: Bool?
    @Published private(set) var isOn: Bool?
    @Published private(set) var apps: [TVApp] = []
    @Published private(set) var toast: String?

    // Setup / add-a-TV flow
    @Published var showingSetup = false
    @Published private(set) var setupPrefill: SavedTV?

    private var client: BraviaClient?
    private var pendingTV: SavedTV?
    private var pendingClient: BraviaClient?
    private var codes: [String: String] = [:]
    private var queue: Task<Void, Never>?
    private var pending = 0
    private var toastTask: Task<Void, Never>?
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let nickname: String
    private var powerObserver: NSObjectProtocol?
    private var lastReconnectAttempt: Date?

    init() {
        nickname = "\(UIDevice.current.name) (Bravia Remote)"
        let stored = TVStore.load()
        tvs = stored.tvs
        currentID = stored.current
        if let tv = stored.tvs.first(where: { $0.id == stored.current }) {
            client = makeClient(for: tv)
        }
        powerObserver = NotificationCenter.default.addObserver(
            forName: RemoteSignals.powerChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            let isOn = note.userInfo?["isOn"] as? Bool
            Task { @MainActor in
                guard let self, let isOn else { return }
                self.isOn = isOn
                self.lockScreenRemoteSync()
            }
        }
    }

    /// Saves the TV list and refreshes widgets, which read it from the app group.
    private func persist() {
        TVStore.save(tvs, current: currentID)
        WidgetCenter.shared.reloadAllTimelines()
        lockScreenRemoteSync()
    }

    // MARK: - Lock Screen remote

    var lockScreenRemoteEnabled: Bool {
        UserDefaults.standard.bool(forKey: LiveActivityController.settingKey)
    }

    func setLockScreenRemote(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: LiveActivityController.settingKey)
        if enabled && !LiveActivityController.isAllowed {
            show("Turn on Live Activities for Bravia Remote in iOS Settings.")
        }
        lockScreenRemoteSync()
        objectWillChange.send()
    }

    /// Keeps the Lock Screen remote in step with the setting, the current TV and the theme.
    func lockScreenRemoteSync() {
        guard lockScreenRemoteEnabled, let tv = currentTV else {
            LiveActivityController.end()
            return
        }
        let theme = UserDefaults.standard.string(forKey: AppTheme.storageKey) ?? AppTheme.default.rawValue
        LiveActivityController.start(tvName: tv.name, theme: theme, isOn: isOn ?? true)
    }

    // MARK: - Current TV

    var currentTV: SavedTV? { tvs.first { $0.id == currentID } }
    var isPaired: Bool { currentTV != nil }
    var host: String { currentTV?.host ?? "" }
    var tvName: String { currentTV?.name ?? "BRAVIA" }
    var tvModel: String? { currentTV?.model }

    private func makeClient(for tv: SavedTV) -> BraviaClient {
        BraviaClient(host: tv.host, clientId: tv.clientId, nickname: nickname, credentialScope: tv.credentialScope)
    }

    /// Makes another saved TV the active one.
    func switchTo(_ id: UUID) {
        guard id != currentID, let tv = tvs.first(where: { $0.id == id }) else { return }
        heavyHaptic.impactOccurred()
        queue?.cancel()
        queue = nil
        pending = 0
        client = makeClient(for: tv)
        currentID = id
        codes = [:]
        apps = []
        isOn = nil
        isReachable = nil
        persist()
        refresh()
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = tvs.firstIndex(where: { $0.id == id }) else { return }
        tvs[index].name = trimmed
        persist()
    }

    /// Removes a TV and its credentials. Switches to another saved TV if the active one was removed.
    func remove(_ id: UUID) {
        guard let tv = tvs.first(where: { $0.id == id }) else { return }
        makeClient(for: tv).forget()
        tvs.removeAll { $0.id == id }
        if currentID == id {
            currentID = nil
            client = nil
            codes = [:]
            apps = []
            isOn = nil
            isReachable = nil
            if let next = tvs.first { switchTo(next.id) }
        }
        persist()
    }

    func forgetTV() {
        if let id = currentID { remove(id) }
    }

    // MARK: - Lifecycle

    func refresh() {
        guard let client else { return }
        Task {
            do {
                if codes.isEmpty { codes = try await client.remoteControllerCodes() }
                isOn = try await client.isPoweredOn()
                if let isOn { AppGroup.defaults.set(isOn, forKey: AppGroup.Key.lastPower) }
                isReachable = true
            } catch {
                isReachable = false
                handle(error, quiet: true)
                if error is URLError { reconnectIfMoved() }
            }
        }
    }

    // MARK: - Pairing (first TV or "Add TV")

    func beginAddingTV(prefill: SavedTV? = nil) {
        setupPrefill = prefill
        cancelPairing()
        showingSetup = true
    }

    /// Discards a pairing attempt that wasn't finished.
    func cancelPairing() {
        pendingTV = nil
        pendingClient = nil
    }

    /// Returns true if the TV is now showing a PIN.
    func requestPIN(host: String, name: String?) async throws -> Bool {
        let client = try preparePending(host: host, name: name)
        let needsPIN = try await client.requestPIN()
        if !needsPIN { try await finishPairing() }
        return needsPIN
    }

    func pair(pin: String) async throws {
        guard let pendingClient else { throw BraviaError.notPaired }
        try await pendingClient.confirmPIN(pin.trimmingCharacters(in: .whitespaces))
        try await finishPairing()
    }

    func pair(host: String, psk: String, name: String?) async throws {
        let client = try preparePending(host: host, name: name)
        try await client.usePSK(psk.trimmingCharacters(in: .whitespacesAndNewlines))
        try await finishPairing()
    }

    /// Sets up the TV being paired. Re-pairing a saved IP reuses that entry. Every attempt
    /// gets a fresh client id, because the TV only shows a PIN for clients it doesn't know.
    private func preparePending(host: String, name: String?) throws -> BraviaClient {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidHost(trimmed) else { throw BraviaError.invalidHost }
        let existing = tvs.first { $0.host == trimmed }
        let base = pendingTV?.host == trimmed ? pendingTV : existing
        let tv = SavedTV(id: base?.id ?? UUID(),
                         name: (name?.isEmpty == false ? name : nil) ?? base?.name ?? "BRAVIA",
                         host: trimmed,
                         model: base?.model,
                         clientId: SavedTV.newClientId())
        let client = makeClient(for: tv)
        pendingTV = tv
        pendingClient = client
        return client
    }

    private func finishPairing() async throws {
        guard var tv = pendingTV, let newClient = pendingClient else { return }
        if let info = try? await newClient.systemInfo() {
            tv.model = info.model ?? tv.model
            tv.mac = info.mac ?? tv.mac
            if let name = info.name, tv.name == "BRAVIA" { tv.name = name }
        }
        if let index = tvs.firstIndex(where: { $0.id == tv.id }) {
            tvs[index] = tv
        } else {
            tvs.append(tv)
        }
        pendingTV = nil
        pendingClient = nil
        setupPrefill = nil

        queue?.cancel()
        queue = nil
        pending = 0
        client = newClient
        currentID = tv.id
        codes = (try? await newClient.remoteControllerCodes()) ?? [:]
        apps = []
        isReachable = true
        persist()
        showingSetup = false
        heavyHaptic.impactOccurred()
        refresh()
    }

    // MARK: - Commands

    func press(_ key: RemoteKey) {
        lightHaptic.impactOccurred()
        let code = codes[key.rawValue] ?? key.fallbackCode
        enqueue { client in try await client.send(code: code) }
    }

    func togglePower() {
        heavyHaptic.impactOccurred()
        enqueue { [weak self] client in
            guard let self else { return }
            let currentlyOn = (try? await client.isPoweredOn()) ?? (self.isOn ?? true)
            do {
                try await client.setPower(!currentlyOn)
            } catch BraviaError.notPaired {
                throw BraviaError.notPaired
            } catch {
                // Fall back to IR-style power keys if the REST call isn't allowed.
                let key: RemoteKey = currentlyOn ? .powerOff : .wakeUp
                try await client.send(code: self.codes[key.rawValue] ?? key.fallbackCode)
            }
            self.isOn = !currentlyOn
            AppGroup.defaults.set(!currentlyOn, forKey: AppGroup.Key.lastPower)
            LiveActivityController.update(isOn: !currentlyOn)
        }
    }

    func loadApps() async {
        guard let client else { return }
        do {
            apps = try await client.applications()
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } catch {
            handle(error)
        }
    }

    func launch(_ app: TVApp) {
        lightHaptic.impactOccurred()
        enqueue { client in try await client.launch(uri: app.uri) }
    }

    /// One-touch app keys. Launches the installed app by name;
    /// Netflix/YouTube fall back to their dedicated IRCC keys.
    func open(_ shortcut: AppQuickLaunch) {
        lightHaptic.impactOccurred()
        enqueue { [weak self] client in
            guard let self else { return }
            if self.apps.isEmpty {
                self.apps = (try? await client.applications()) ?? []
            }
            if let app = shortcut.bestMatch(in: self.apps) {
                try await client.launch(uri: app.uri)
            } else if let key = shortcut.fallbackKey {
                try await client.send(code: self.codes[key.rawValue] ?? key.fallbackCode)
            } else {
                self.show("\(shortcut.rawValue) isn't installed on the TV.")
            }
        }
    }

    /// Replaces the text in the TV's focused text field ("" clears it).
    func sendText(_ text: String) {
        enqueue { client in try await client.sendText(text) }
    }

    // MARK: - Inputs

    /// Loads the TV's external inputs and which one is on screen.
    func loadInputs() async throws -> (inputs: [TVInput], current: String?) {
        guard let client else { throw BraviaError.notPaired }
        do {
            let inputs = try await client.externalInputs()
            let current = await client.playingContentURI()
            isReachable = true
            return (inputs, current)
        } catch {
            if let braviaError = error as? BraviaError, case .notPaired = braviaError { handle(error) }
            throw error
        }
    }

    func switchInput(_ input: TVInput) {
        heavyHaptic.impactOccurred()
        enqueue { client in try await client.switchInput(uri: input.uri) }
    }

    /// Serialises commands so key presses reach the TV in order.
    private func enqueue(_ work: @escaping (BraviaClient) async throws -> Void) {
        guard let client else { return }
        guard pending < 10 else { return } // TV unreachable — don't build a backlog
        pending += 1
        let previous = queue
        queue = Task { [weak self] in
            await previous?.value
            if Task.isCancelled { return }
            do {
                try await work(client)
                self?.isReachable = true
            } catch {
                // Ignore failures from a TV the user has since switched away from.
                if self?.client === client { self?.handle(error) }
            }
            if let self { self.pending = max(0, self.pending - 1) }
        }
    }

    // MARK: - Auto-reconnect

    /// The TV stopped answering. If the router gave it a new IP address, find it again on the
    /// network and confirm it's the same TV (by MAC address, or by name for v1.1 pairings).
    /// Runs at most once a minute.
    private func reconnectIfMoved() {
        guard let tv = currentTV,
              Date().timeIntervalSince(lastReconnectAttempt ?? .distantPast) > 60 else { return }
        lastReconnectAttempt = Date()

        Task {
            let discovery = TVDiscovery()
            discovery.start()
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            let found = discovery.tvs.sorted { $0.looksLikeBravia && !$1.looksLikeBravia }
            discovery.stop()

            for candidate in found {
                guard let ip = await discovery.resolveIPv4(candidate), ip != tv.host else { continue }
                let probe = BraviaClient(host: ip, clientId: tv.clientId, nickname: nickname,
                                         credentialScope: tv.credentialScope)
                guard let info = try? await probe.systemInfo(allowRenew: false) else { continue }
                let sameMAC = tv.mac != nil && info.mac?.lowercased() == tv.mac?.lowercased()
                let sameName = tv.mac == nil && (candidate.name == tv.name || info.name == tv.name)
                if sameMAC || sameName {
                    moveTV(tv.id, to: ip, mac: info.mac)
                    return
                }
            }
        }
    }

    private func moveTV(_ id: UUID, to host: String, mac: String?) {
        guard let index = tvs.firstIndex(where: { $0.id == id }) else { return }
        tvs[index].host = host
        if let mac { tvs[index].mac = mac }
        persist()
        if id == currentID {
            client = makeClient(for: tvs[index])
            isReachable = true
            show("Found \(tvs[index].name) at its new address \(host).")
            refresh()
        }
    }

    // MARK: - Errors

    private func handle(_ error: Error, quiet: Bool = false) {
        if let braviaError = error as? BraviaError, case .notPaired = braviaError {
            show("Pairing expired — pair \(tvName) again.")
            let expired = currentTV
            if let id = currentID { remove(id) }
            beginAddingTV(prefill: expired)
            return
        }
        if error is URLError {
            isReachable = false
            reconnectIfMoved()
            if !quiet { show("Can't reach \(tvName) at \(host). Is it on the same Wi‑Fi?") }
            return
        }
        if !quiet { show(error.localizedDescription) }
    }

    func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    static func isValidHost(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        let isIPv4 = parts.count == 4 && parts.allSatisfy { part in
            guard let value = Int(part) else { return false }
            return (0...255).contains(value)
        }
        if isIPv4 { return true }
        // Also allow hostnames such as "bravia.local".
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        let hasLetters = host.rangeOfCharacter(from: .letters) != nil
        return hasLetters && host.contains(".") && host.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

/// One-tap app launchers (named so it doesn't clash with AppIntents.AppShortcut).
enum AppQuickLaunch: String, CaseIterable, Identifiable {
    case youtube = "YouTube"
    case netflix = "Netflix"
    case disney = "Disney+"
    case prime = "Prime Video"

    var id: String { rawValue }

    private var keywords: [String] {
        switch self {
        case .youtube: return ["youtube"]
        case .netflix: return ["netflix"]
        case .disney: return ["disney"]
        case .prime: return ["prime video", "amazon prime"]
        }
    }

    var fallbackKey: RemoteKey? {
        switch self {
        case .youtube: return .youtube
        case .netflix: return .netflix
        case .disney, .prime: return nil
        }
    }

    /// Exact title first, then a keyword match that skips variants like "YouTube Kids" / "YouTube Music".
    func bestMatch(in apps: [TVApp]) -> TVApp? {
        if let exact = apps.first(where: { $0.title.caseInsensitiveCompare(rawValue) == .orderedSame }) {
            return exact
        }
        let candidates = apps.filter { app in
            let title = app.title.lowercased()
            return keywords.contains { title.contains($0) }
        }
        return candidates.min { $0.title.count < $1.title.count }
    }
}
