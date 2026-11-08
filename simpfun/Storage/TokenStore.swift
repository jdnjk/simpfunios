//
//  TokenStore.swift
//  simpfun
//

import Foundation
import Security

/// 登录凭证保存在钥匙串中，不写入 UserDefaults 或明文文件。
struct TokenStore {
    static let shared = TokenStore()

    private let service: String
    private let account = "auth-token"

    init(service: String = Bundle.main.bundleIdentifier ?? "io.jdnjk.simpfun") {
        self.service = service
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    func save(_ token: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemCopyMatching(baseQuery as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw TokenStoreError(status: updateStatus)
            }
        } else {
            var query = baseQuery
            query.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw TokenStoreError(status: addStatus)
            }
        }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

struct TokenStoreError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "无法安全保存登录凭证（\(status)），请重试。"
    }
}
