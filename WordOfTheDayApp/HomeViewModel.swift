import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedLanguage: LanguageOption
    @Published var selectedDifficulty: LearningDifficulty
    @Published var selectedTheme: AppTheme
    @Published var currentWord: WordEntry?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let store: WordStore
    private let provider: WordProvider
    private let calendar = Calendar.current

    init(provider: WordProvider, store: WordStore = .shared) {
        self.provider = provider
        self.store = store
        self.selectedLanguage = store.selectedLanguage()
        self.selectedDifficulty = store.selectedDifficulty()
        self.selectedTheme = store.selectedTheme()
        self.currentWord = store.currentWord()
    }

    func onLanguageChanged(_ language: LanguageOption) {
        selectedLanguage = language
        store.saveSelectedLanguage(language)
    }

    func onDifficultyChanged(_ difficulty: LearningDifficulty) {
        selectedDifficulty = difficulty
        store.saveSelectedDifficulty(difficulty)
    }

    func onThemeChanged(_ theme: AppTheme) {
        selectedTheme = theme
        store.saveSelectedTheme(theme)
    }

    func refreshWord(
        for language: LanguageOption? = nil,
        difficulty: LearningDifficulty? = nil
    ) async {
        let targetLanguage = language ?? selectedLanguage
        let targetDifficulty = difficulty ?? selectedDifficulty
        selectedLanguage = targetLanguage
        selectedDifficulty = targetDifficulty
        store.saveSelectedLanguage(targetLanguage)
        store.saveSelectedDifficulty(targetDifficulty)

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let word = try await provider.fetchWord(for: targetLanguage, difficulty: targetDifficulty)
            currentWord = word
            store.saveCurrentWord(word)
#if canImport(WidgetKit)
            if shouldReloadWidgets {
                WidgetCenter.shared.reloadAllTimelines()
            }
#endif
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func ensureDailyWord() async {
        if let currentWord, calendar.isDateInToday(currentWord.fetchedAt) {
            return
        }

        await refreshWord(
            for: selectedLanguage,
            difficulty: selectedDifficulty
        )
    }

    private var shouldReloadWidgets: Bool {
#if targetEnvironment(simulator)
        return false
#else
        return true
#endif
    }
}
