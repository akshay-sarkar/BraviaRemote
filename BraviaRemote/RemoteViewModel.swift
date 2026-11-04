import SwiftUI
import UIKit

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

    init() {
        nickname = "\(UIDevice.current.name) (Bravia Remote)"
        let stored = TVStore.load()
        tvs = stored.tvs
        currentID = stored.current
        if let tv = stored.tvs.first(where: { $0.id == stored.current }) {
            client = makeClient(for: tv)
        }
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
        TVStore.save(tvs, current: currentID)
        refresh()
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = tvs.firstIndex(where: { $0.id == id }) else { return }
        tvs[index].name = trimmed
        TVStore.save(tvs, current: currentID)
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
        TVStore.save(tvs, current: currentID)
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
                isReachable = true
            } catch {
                isReachable = false
                handle(error, quiet: true)
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
        TVStore.save(tvs, current: currentID)
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
    func open(_ shortcut: AppShortcut) {
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

enum AppShortcut: String, CaseIterable, Identifiable {
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
