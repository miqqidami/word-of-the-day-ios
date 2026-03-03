import Foundation

final class WordStore {
    static let shared = WordStore()

    private let defaults: UserDefaults
    private let selectedLanguageKey = "selectedLanguage"
    private let selectedDifficultyKey = "selectedDifficulty"
    private let selectedThemeKey = "selectedTheme"
    private let currentWordKey = "currentWord"

    init(userDefaults: UserDefaults? = nil) {
        if let userDefaults {
            defaults = userDefaults
        } else {
            defaults = UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
        }
    }

    func selectedLanguage() -> LanguageOption {
        guard let rawValue = defaults.string(forKey: selectedLanguageKey),
              let language = LanguageOption(rawValue: rawValue) else {
            return .spanish
        }
        return language
    }

    func saveSelectedLanguage(_ language: LanguageOption) {
        defaults.set(language.rawValue, forKey: selectedLanguageKey)
    }

    func selectedDifficulty() -> LearningDifficulty {
        guard let rawValue = defaults.string(forKey: selectedDifficultyKey),
              let difficulty = LearningDifficulty(rawValue: rawValue) else {
            return .easy
        }
        return difficulty
    }

    func saveSelectedDifficulty(_ difficulty: LearningDifficulty) {
        defaults.set(difficulty.rawValue, forKey: selectedDifficultyKey)
    }

    func selectedTheme() -> AppTheme {
        guard let rawValue = defaults.string(forKey: selectedThemeKey),
              let theme = AppTheme(rawValue: rawValue) else {
            return .system
        }
        return theme
    }

    func saveSelectedTheme(_ theme: AppTheme) {
        defaults.set(theme.rawValue, forKey: selectedThemeKey)
    }

    func currentWord() -> WordEntry? {
        guard let data = defaults.data(forKey: currentWordKey) else { return nil }
        return try? JSONDecoder().decode(WordEntry.self, from: data)
    }

    func saveCurrentWord(_ entry: WordEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: currentWordKey)
    }
}
