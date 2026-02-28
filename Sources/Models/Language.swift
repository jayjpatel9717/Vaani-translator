import Foundation

enum Language: String, CaseIterable, Identifiable {
    case english = "en-IN"
    case hindi = "hi-IN"
    case bengali = "bn-IN"
    case telugu = "te-IN"
    case marathi = "mr-IN"
    case tamil = "ta-IN"
    case gujarati = "gu-IN"
    case kannada = "kn-IN"
    case malayalam = "ml-IN"
    case odia = "od-IN"
    case punjabi = "pa-IN"
    case assamese = "as-IN"
    case urdu = "ur-IN"
    case kashmiri = "ks-IN"
    case konkani = "kok-IN"
    case maithili = "mai-IN"
    case manipuri = "mni-IN"
    case nepali = "ne-IN"
    case santali = "sat-IN"
    case sindhi = "sd-IN"
    case dogri = "doi-IN"
    case bodo = "brx-IN"
    case sanskrit = "sa-IN"

    var id: String { rawValue }

    var bcp47Code: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .hindi: return "हिन्दी (Hindi)"
        case .bengali: return "বাংলা (Bengali)"
        case .telugu: return "తెలుగు (Telugu)"
        case .marathi: return "मराठी (Marathi)"
        case .tamil: return "தமிழ் (Tamil)"
        case .gujarati: return "ગુજરાતી (Gujarati)"
        case .kannada: return "ಕನ್ನಡ (Kannada)"
        case .malayalam: return "മലയാളം (Malayalam)"
        case .odia: return "ଓଡ଼ିଆ (Odia)"
        case .punjabi: return "ਪੰਜਾਬੀ (Punjabi)"
        case .assamese: return "অসমীয়া (Assamese)"
        case .urdu: return "اردو (Urdu)"
        case .kashmiri: return "कॉशुर (Kashmiri)"
        case .konkani: return "कोंकणी (Konkani)"
        case .maithili: return "मैथिली (Maithili)"
        case .manipuri: return "মৈতৈলোন্ (Manipuri)"
        case .nepali: return "नेपाली (Nepali)"
        case .santali: return "ᱥᱟᱱᱛᱟᱲᱤ (Santali)"
        case .sindhi: return "سنڌي (Sindhi)"
        case .dogri: return "डोगरी (Dogri)"
        case .bodo: return "बर'/बड़ो (Bodo)"
        case .sanskrit: return "संस्कृतम् (Sanskrit)"
        }
    }
}

enum TranslationMode: String, CaseIterable, Identifiable {
    case transcribe = "transcribe"
    case translate = "translate"
    case translit = "translit"
    case codemix = "codemix"
    case verbatim = "verbatim"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transcribe: return "Transcribe"
        case .translate: return "Translate"
        case .translit: return "Transliterate"
        case .codemix: return "Code-mix"
        case .verbatim: return "Verbatim"
        }
    }

    var description: String {
        switch self {
        case .transcribe: return "Standard transcription in original language with formatting"
        case .translate: return "Translate speech to a target language"
        case .translit: return "Romanize speech to Latin/Roman script"
        case .codemix: return "English words in English, Indic words in native script"
        case .verbatim: return "Exact word-for-word transcription, preserving fillers"
        }
    }

    var needsTargetLanguage: Bool {
        self == .translate
    }
}
