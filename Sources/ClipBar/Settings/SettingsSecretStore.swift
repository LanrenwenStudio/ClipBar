import Foundation
import Security

@MainActor
protocol SettingsSecretStore {
    func loadManagementKey() -> String?
    func saveManagementKey(_ value: String)
    func removeLegacyAccessToken()
}

/// Stores connection credentials in iCloud Keychain rather than in the
/// iCloud key-value store settings payload. Synchronizable Keychain items are
/// protected storage and remain available to background refresh after the
/// first device unlock.
@MainActor
final class KeychainSettingsSecretStore: SettingsSecretStore {
    private enum Account {
        static let managementKey = "managementKey"
        static let legacyBackendAccessToken = "backendAccessToken"
    }

    private let service: String

    init(service: String = "com.lanrenwen.clipbar.settings") {
        self.service = service
    }

    func loadManagementKey() -> String? {
        load(account: Account.managementKey)
    }

    func saveManagementKey(_ value: String) {
        save(value, account: Account.managementKey)
    }

    func removeLegacyAccessToken() {
        delete(account: Account.legacyBackendAccessToken)
    }

    private func load(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func save(_ value: String, account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        if value.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        guard let data = value.data(using: .utf8) else { return }
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        guard updateStatus == errSecItemNotFound else { return }

        var insertQuery = query
        insertQuery[kSecAttrSynchronizable] = true
        insertQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        insertQuery[kSecValueData] = data
        SecItemAdd(insertQuery as CFDictionary, nil)
    }
}
