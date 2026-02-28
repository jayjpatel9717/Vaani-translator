import Foundation
import KeychainAccess

class KeychainManager {
    private let keychain = Keychain(service: "com.vaani.app")
    private let apiKeyKey = "vaani_api_key"

    func saveAPIKey(_ key: String) throws {
        try keychain.set(key, key: apiKeyKey)
    }

    func getAPIKey() -> String? {
        return try? keychain.get(apiKeyKey)
    }

    func deleteAPIKey() throws {
        try keychain.remove(apiKeyKey)
    }

    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}
