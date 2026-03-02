import Foundation

class KeychainManager {
    private let apiKeyKey = "vaani_api_key"

    func saveAPIKey(_ key: String) throws {
        UserDefaults.standard.set(key, forKey: apiKeyKey)
    }

    func getAPIKey() -> String? {
        let key = UserDefaults.standard.string(forKey: apiKeyKey)
        return (key?.isEmpty == false) ? key : nil
    }

    func deleteAPIKey() throws {
        UserDefaults.standard.removeObject(forKey: apiKeyKey)
    }

    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}
