import Foundation

/// Sends commands without any UI. Used by Siri & Shortcuts, widgets, Control Center
/// controls and the Lock Screen remote.
@MainActor
enum RemoteCommandRunner {
    private static var clients: [UUID: BraviaClient] = [:]
    private static var codeTables: [UUID: [String: String]] = [:]

    /// The requested TV, or the one currently selected in the app.
    static func tv(_ id: UUID?) throws -> SavedTV {
        let stored = TVStore.load()
        if let id, let tv = stored.tvs.first(where: { $0.id == id }) { return tv }
        if let tv = TVStore.currentTV() { return tv }
        throw RemoteIntentError.noTV
    }

    private static func client(for tv: SavedTV) -> BraviaClient {
        if let client = clients[tv.id], client.host == tv.host { return client }
        let client = BraviaClient(host: tv.host,
                                  clientId: tv.clientId,
                                  nickname: "Bravia Remote",
                                  credentialScope: tv.credentialScope)
        clients[tv.id] = client
        return client
    }

    private static func code(for key: RemoteKey, on tv: SavedTV, client: BraviaClient) async -> String {
        if codeTables[tv.id] == nil, let table = try? await client.remoteControllerCodes(), !table.isEmpty {
            codeTables[tv.id] = table
        }
        return codeTables[tv.id]?[key.rawValue] ?? key.fallbackCode
    }

    @discardableResult
    static func press(_ key: RemoteKey, times: Int = 1, on id: UUID? = nil) async throws -> SavedTV {
        let tv = try tv(id)
        let client = client(for: tv)
        let code = await code(for: key, on: tv, client: client)
        for index in 0..<max(1, min(times, 30)) {
            if index > 0 { try? await Task.sleep(nanoseconds: 120_000_000) }
            try await client.send(code: code)
        }
        return tv
    }

    /// Returns the TV and whether it's on afterwards.
    static func power(_ action: PowerAction, on id: UUID? = nil) async throws -> (tv: SavedTV, isOn: Bool) {
        let tv = try tv(id)
        let client = client(for: tv)
        let currentlyOn = (try? await client.isPoweredOn())
            ?? AppGroup.defaults.object(forKey: AppGroup.Key.lastPower) as? Bool
            ?? true
        let turnOn: Bool
        switch action {
        case .on: turnOn = true
        case .off: turnOn = false
        case .toggle: turnOn = !currentlyOn
        }
        if turnOn != currentlyOn || action != .toggle {
            do {
                try await client.setPower(turnOn)
            } catch BraviaError.notPaired {
                throw BraviaError.notPaired
            } catch {
                let key: RemoteKey = turnOn ? .wakeUp : .powerOff
                let code = await code(for: key, on: tv, client: client)
                try await client.send(code: code)
            }
        }
        AppGroup.defaults.set(turnOn, forKey: AppGroup.Key.lastPower)
        return (tv, turnOn)
    }

    static func isOn(_ id: UUID? = nil) async -> Bool? {
        guard let tv = try? tv(id) else { return nil }
        return try? await client(for: tv).isPoweredOn()
    }

    @discardableResult
    static func switchToHDMI(_ port: Int, on id: UUID? = nil) async throws -> SavedTV {
        let tv = try tv(id)
        try await client(for: tv).switchInput(uri: "extInput:hdmi?port=\(port)")
        return tv
    }

    /// Opens an installed app whose name contains `name` (shortest match wins, so
    /// "YouTube" beats "YouTube Kids"). Returns the app's title.
    static func openApp(named name: String, on id: UUID? = nil) async throws -> (tv: SavedTV, title: String) {
        let tv = try tv(id)
        let client = client(for: tv)
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let apps = try await client.applications()
        let match = apps.first { $0.title.lowercased() == query }
            ?? apps.filter { $0.title.lowercased().contains(query) }.min { $0.title.count < $1.title.count }
        guard let app = match else { throw RemoteIntentError.appNotFound(name) }
        try await client.launch(uri: app.uri)
        return (tv, app.title)
    }
}
