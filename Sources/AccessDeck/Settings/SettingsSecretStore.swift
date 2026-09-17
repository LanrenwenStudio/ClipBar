import Foundation
import Security

@MainActor
protocol SettingsSecretStore {
    func loadManagementKey() -> String?
    @discardableResult
    func saveManagementKey(_ value: String) -> Bool
    func removeLegacyAccessToken()
}

/// Stores connection credentials in iCloud Keychain rather than the
/// iCloud key-value store settings payload. Existing ClipBar credentials are
/// migrated from the legacy service after a successful write.
@MainActor
final class KeychainSettingsSecretStore: SettingsSecretStore {
    private enum Account {
        static let managementKey = "managementKey"
        static let legacyBackendAccessToken = "backendAccessToken"
    }

    private let service: String
    private let legacyService: String

    init(
        service: String = "com.lanrenwen.accessdeck.settings",
        legacyService: String = "com.lanrenwen.clipbar.settings"
    ) {
        self.service = service
        self.legacyService = legacyService
    }

    func loadManagementKey() -> String? {
        if let current = load(account: Account.managementKey, service: service) {
            return current
        }

        guard let legacy = load(account: Account.managementKey, service: legacyService) else {
            return nil
        }
        if save(legacy, account: Account.managementKey, service: service) {
            _ = delete(account: Account.managementKey, service: legacyService)
        }
        return legacy
    }

    @discardableResult
    func saveManagementKey(_ value: String) -> Bool {
        let saved = save(value, account: Account.managementKey, service: service)
        if saved, !value.isEmpty {
            _ = delete(account: Account.managementKey, service: legacyService)
        }
        return saved
    }

    func removeLegacyAccessToken() {
        _ = delete(account: Account.legacyBackendAccessToken, service: service)
        _ = delete(account: Account.legacyBackendAccessToken, service: legacyService)
    }

    private func load(account: String, service: String) -> String? {
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

    @discardableResult
    private func delete(account: String, service: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func save(_ value: String, account: String, service: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }

        guard let data = value.data(using: .utf8) else { return false }
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var insertQuery = query
        insertQuery[kSecAttrSynchronizable] = true
        insertQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        insertQuery[kSecValueData] = data
        let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        if insertStatus == errSecSuccess { return true }
        guard insertStatus == errSecDuplicateItem else { return false }

        return SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary
        ) == errSecSuccess
    }
}
