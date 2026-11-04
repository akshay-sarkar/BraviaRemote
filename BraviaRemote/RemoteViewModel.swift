import SwiftUI
import UIKit

@MainActor
final class RemoteViewModel: ObservableObject {
    private enum Defaults {
        static let host = "tv.host"
        static let name = "tv.name"
        static let model = "tv.model"
        static let clientId = "tv.clientId"
    }

    @Published private(set) var host: String
    @Published private(set) var tvName: String
    @Published private(set) var tvModel: String?
    @Published private(set) var isPaired: Bool
    @Published private(set) var isReachable: Bool?
    @Published private(set) var isOn: Bool?
    @Published private(set) var apps: [TVApp] = []
    @Published private(set) var toast: String?

    private let client: BraviaClient
    private var codes: [String: String] = [:]
    private var queue: Task<Void, Never>?
    private var pending = 0
    private var toastTask: Task<Void, Never>?
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        let defaults = UserDefaults.standard
        let clientId: String
        if let saved = defaults.string(forKey: Defaults.clientId) {
            clientId = saved
        } else {
            clientId = "BraviaRemote:\(UUID().uuidString)"
            defaults.set(clientId, forKey: Defaults.clientId)
        }
        let host = defaults.string(forKey: Defaults.host) ?? ""
        self.host = host
        self.tvName = defaults.string(forKey: Defaults.name) ?? "BRAVIA"
        self.tvModel = defaults.string(forKey: Defaults.model)
        let client = BraviaClient(host: host,
                                  clientId: clientId,
                                  nickname: "\(UIDevice.current.name) (Bravia Remote)")
        self.client = client
        self.isPaired = !host.isEmpty && client.hasCredentials
    }

    // MARK: - Lifecycle

    func refresh() {
        guard isPaired else { return }
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

    // MARK: - Pairing

    /// Returns true if the TV is now showing a PIN.
    func requestPIN(host: String, name: String?) async throws -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidHost(trimmed) else { throw BraviaError.invalidHost }
        client.host = trimmed
        self.host = trimmed
        if let name, !name.isEmpty { tvName = name }
        let needsPIN = try await client.requestPIN()
        if !needsPIN { try await finishPairing() }
        return needsPIN
    }

    func pair(pin: String) async throws {
        try await client.confirmPIN(pin.trimmingCharacters(in: .whitespaces))
        try await finishPairing()
    }

    private func finishPairing() async throws {
        if let info = try? await client.systemInfo() {
            tvModel = info.model
            if let name = info.name, tvName == "BRAVIA" { tvName = name }
        }
        let defaults = UserDefaults.standard
        defaults.set(host, forKey: Defaults.host)
        defaults.set(tvName, forKey: Defaults.name)
        defaults.set(tvModel, forKey: Defaults.model)
        codes = (try? await client.remoteControllerCodes()) ?? [:]
        isReachable = true
        isPaired = true
        heavyHaptic.impactOccurred()
        refresh()
    }

    func forgetTV() {
        client.forget()
        codes = [:]
        apps = []
        isOn = nil
        isReachable = nil
        UserDefaults.standard.removeObject(forKey: Defaults.host)
        isPaired = false
    }

    // MARK: - Commands

    func press(_ key: RemoteKey) {
        lightHaptic.impactOccurred()
        let code = codes[key.rawValue] ?? key.fallbackCode
        enqueue { [client] in try await client.send(code: code) }
    }

    func togglePower() {
        heavyHaptic.impactOccurred()
        enqueue { [weak self] in
            guard let self else { return }
            let currentlyOn = (try? await self.client.isPoweredOn()) ?? (self.isOn ?? true)
            do {
                try await self.client.setPower(!currentlyOn)
            } catch BraviaError.notPaired {
                throw BraviaError.notPaired
            } catch {
                // Fall back to IR-style power keys if the REST call isn't allowed.
                let key: RemoteKey = currentlyOn ? .powerOff : .wakeUp
                try await self.client.send(code: self.codes[key.rawValue] ?? key.fallbackCode)
            }
            self.isOn = !currentlyOn
        }
    }

    func loadApps() async {
        do {
            apps = try await client.applications()
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } catch {
            handle(error)
        }
    }

    func launch(_ app: TVApp) {
        lightHaptic.impactOccurred()
        enqueue { [client] in try await client.launch(uri: app.uri) }
    }

    /// One-touch app keys on the remote. Launches the installed app by name;
    /// Netflix/YouTube fall back to their dedicated IRCC keys.
    func open(_ shortcut: AppShortcut) {
        lightHaptic.impactOccurred()
        enqueue { [weak self] in
            guard let self else { return }
            if self.apps.isEmpty {
                self.apps = (try? await self.client.applications()) ?? []
            }
            if let app = shortcut.bestMatch(in: self.apps) {
                try await self.client.launch(uri: app.uri)
            } else if let key = shortcut.fallbackKey {
                try await self.client.send(code: self.codes[key.rawValue] ?? key.fallbackCode)
            } else {
                self.show("\(shortcut.rawValue) isn't installed on the TV.")
            }
        }
    }

    /// Replaces the text in the TV's focused text field ("" clears it).
    func sendText(_ text: String) {
        enqueue { [client] in try await client.sendText(text) }
    }

    /// Serialises commands so key presses reach the TV in order.
    private func enqueue(_ work: @escaping () async throws -> Void) {
        guard pending < 10 else { return } // TV unreachable — don't build a backlog
        pending += 1
        let previous = queue
        queue = Task { [weak self] in
            await previous?.value
            do {
                try await work()
                self?.isReachable = true
            } catch {
                self?.handle(error)
            }
            self?.pending -= 1
        }
    }

    // MARK: - Errors

    private func handle(_ error: Error, quiet: Bool = false) {
        if let braviaError = error as? BraviaError, case .notPaired = braviaError {
            show("Pairing expired — pair your TV again.")
            forgetTV()
            return
        }
        if error is URLError {
            isReachable = false
            if !quiet { show("Can't reach the TV at \(host). Is it on the same Wi‑Fi?") }
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
