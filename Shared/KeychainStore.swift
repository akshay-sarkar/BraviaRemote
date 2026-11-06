import Foundation
import Security

/// Tiny Keychain wrapper for TV credentials (auth cookie, PIN, Pre-Shared Key).
///
/// Items go into the app group's keychain access group so the widget extension and
/// Control Center controls can use the same pairing. If the app group isn't available
/// (some sideloading setups), items fall back to the app's private keychain.
enum KeychainStore {
    private static let service = "com.akshay.BraviaRemote"

    /// Whether the shared access group is usable in this build.
    private static let sharedGroupAvailable: Bool = {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "keychain.probe",
            kSecAttrAccessGroup as String: AppGroup.id,
            kSecValueData as String: Data("1".utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(probe as CFDictionary, nil)
        var cleanup = probe
        cleanup.removeValue(forKey: kSecValueData as String)
        cleanup.removeValue(forKey: kSecAttrAccessible as String)
        SecItemDelete(cleanup as CFDictionary)
        return status == errSecSuccess || status == errSecDuplicateItem
    }()

    private static func baseQuery(_ key: String, shared: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if shared { query[kSecAttrAccessGroup as String] = AppGroup.id }
        return query
    }

    static func set(_ value: String?, for key: String) {
        // Without an access group, delete matches the item in every group we can see
        // (removes both the shared copy and any older private copy).
        SecItemDelete(baseQuery(key, shared: false) as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var attributes = baseQuery(key, shared: sharedGroupAvailable)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(attributes as CFDictionary, nil) != errSecSuccess, sharedGroupAvailable {
            attributes.removeValue(forKey: kSecAttrAccessGroup as String)
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    static func get(_ key: String) -> String? {
        if sharedGroupAvailable, let value = read(baseQuery(key, shared: true)) {
            return value
        }
        // Not in the shared group: look anywhere (e.g. an item saved by v1.1)
        // and move it into the shared group for next time.
        guard let value = read(baseQuery(key, shared: false)) else { return nil }
        if sharedGroupAvailable { set(value, for: key) }
        return value
    }

    private static func read(_ query: [String: Any]) -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
