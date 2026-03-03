import Foundation

enum LearningDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var promptHint: String {
        switch self {
        case .easy:
            return "Choose an extremely easy A1 daily-life word used constantly by beginners (examples: water, home, eat, go, friend, book, sleep). Avoid names, places, countries, brands, and abstract/rare words."
        case .medium:
            return "Choose a common daily-life word at A2-B1 level (home, school, shopping, travel, routine, work). Keep it practical and frequent. Avoid names, places, countries, brands, jargon, and literary words."
        case .hard:
            return "Choose a still-practical daily-life word at B1-B2 level: more nuanced than medium but still common in real conversations (work, planning, relationships, communication). Avoid names, places, countries, brands, and overly technical/academic terms."
        }
    }

    var cefrRange: String {
        switch self {
        case .easy: return "A1"
        case .medium: return "A2-B1"
        case .hard: return "B1-B2"
        }
    }
}
