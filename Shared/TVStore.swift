import Foundation

/// A paired TV. Credentials (cookie / PIN / PSK) live in the Keychain, scoped by `id`.
struct SavedTV: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var model: String?
    var clientId: String
    /// Wi‑Fi/Ethernet MAC reported by the TV. Used to find it again if its IP changes.
    var mac: String? = nil

    /// Keychain scope for this TV's credentials.
    var credentialScope: String { id.uuidString }

    static func newClientId() -> String { "BraviaRemote:\(UUID().uuidString)" }
}

/// Persists the list of paired TVs and which one is active, in the app-group defaults
/// so widgets and Siri / Shortcuts can see them.
enum TVStore {
    private static let listKey = "tvs.v2"
    private static let currentKey = "tvs.current"

    private static var defaults: UserDefaults { AppGroup.defaults }

    static func load() -> (tvs: [SavedTV], current: UUID?) {
        migrateFromV1IfNeeded()
        migrateToAppGroupIfNeeded()
        let tvs = defaults.data(forKey: listKey)
            .flatMap { try? JSONDecoder().decode([SavedTV].self, from: $0) } ?? []
        let current = defaults.string(forKey: currentKey).flatMap(UUID.init(uuidString:))
        let valid = tvs.contains { $0.id == current } ? current : tvs.first?.id
        return (tvs, valid)
    }

    static func save(_ tvs: [SavedTV], current: UUID?) {
        if let data = try? JSONEncoder().encode(tvs) { defaults.set(data, forKey: listKey) }
        defaults.set(current?.uuidString, forKey: currentKey)
    }

    /// The current TV, falling back to the first saved one.
    static func currentTV() -> SavedTV? {
        let stored = load()
        return stored.tvs.first { $0.id == stored.current } ?? stored.tvs.first
    }

    /// v1.1 kept the list in the app's private defaults. Copy it to the app group (v1.2).
    private static func migrateToAppGroupIfNeeded() {
        let old = UserDefaults.standard
        guard defaults !== old,
              defaults.data(forKey: listKey) == nil,
              let data = old.data(forKey: listKey) else { return }
        defaults.set(data, forKey: listKey)
        defaults.set(old.string(forKey: currentKey), forKey: currentKey)
        old.removeObject(forKey: listKey)
        old.removeObject(forKey: currentKey)
    }

    /// v1.0 stored a single TV in plain UserDefaults keys and unscoped Keychain items.
    /// Move it into the v1.1 multi-TV list so existing users stay paired.
    private static func migrateFromV1IfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.data(forKey: listKey) == nil,
              AppGroup.defaults.data(forKey: listKey) == nil,
              let host = defaults.string(forKey: "tv.host"), !host.isEmpty else { return }

        let tv = SavedTV(id: UUID(),
                         name: defaults.string(forKey: "tv.name") ?? "BRAVIA",
                         host: host,
                         model: defaults.string(forKey: "tv.model"),
                         clientId: defaults.string(forKey: "tv.clientId") ?? SavedTV.newClientId())

        for item in ["auth.cookie", "auth.pin", "auth.psk"] {
            if let value = KeychainStore.get(item) {
                KeychainStore.set(value, for: "\(item).\(tv.credentialScope)")
                KeychainStore.set(nil, for: item)
            }
        }
        for key in ["tv.host", "tv.name", "tv.model", "tv.clientId"] { defaults.removeObject(forKey: key) }
        save([tv], current: tv.id) // writes to the app group
    }
}
