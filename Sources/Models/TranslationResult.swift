import Foundation

struct TranslationResult {
    let text: String
    let sourceLanguage: String?
    let confidence: Double?
    let processingTime: TimeInterval
}

struct HistoryItem: Identifiable {
    let id = UUID()
    let text: String
    let toLang: Language
    let mode: TranslationMode
    let date: Date
}

struct SarvamAPIResponse: Codable {
    let transcript: String
    let languageCode: String?
    let languageProbability: Double?

    enum CodingKeys: String, CodingKey {
        case transcript
        case languageCode = "language_code"
        case languageProbability = "language_probability"
    }
}

struct TranslateResponse: Codable {
    let translatedText: String

    enum CodingKeys: String, CodingKey {
        case translatedText = "translated_text"
    }
}
