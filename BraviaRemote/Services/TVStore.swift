import Foundation

/// A paired TV. Credentials (cookie / PIN / PSK) live in the Keychain, scoped by `id`.
struct SavedTV: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var model: String?
    var clientId: String

    /// Keychain scope for this TV's credentials.
    var credentialScope: String { id.uuidString }

    static func newClientId() -> String { "BraviaRemote:\(UUID().uuidString)" }
}

/// Persists the list of paired TVs and which one is active.
enum TVStore {
    private static let listKey = "tvs.v2"
    private static let currentKey = "tvs.current"

    static func load() -> (tvs: [SavedTV], current: UUID?) {
        migrateFromV1IfNeeded()
        let defaults = UserDefaults.standard
        let tvs = defaults.data(forKey: listKey)
            .flatMap { try? JSONDecoder().decode([SavedTV].self, from: $0) } ?? []
        let current = defaults.string(forKey: currentKey).flatMap(UUID.init(uuidString:))
        let valid = tvs.contains { $0.id == current } ? current : tvs.first?.id
        return (tvs, valid)
    }

    static func save(_ tvs: [SavedTV], current: UUID?) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(tvs) { defaults.set(data, forKey: listKey) }
        defaults.set(current?.uuidString, forKey: currentKey)
    }

    /// v1.0 stored a single TV in plain UserDefaults keys and unscoped Keychain items.
    /// Move it into the v1.1 multi-TV list so existing users stay paired.
    private static func migrateFromV1IfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.data(forKey: listKey) == nil,
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
        save([tv], current: tv.id)
    }
}
