import Foundation

enum LanguageOption: String, CaseIterable, Identifiable, Codable {
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case turkish = "tr"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .turkish: return "Turkish"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        }
    }

    var localeIdentifier: String {
        rawValue
    }
}
