import Foundation

struct WordEntry: Codable, Hashable {
    let word: String
    let transliteration: String?
    let englishMeaning: String
    let exampleSentences: [ExampleSentence]
    let characteristics: WordCharacteristics
    let languageCode: String
    let difficultyCode: String
    let fetchedAt: Date

    var language: LanguageOption? {
        LanguageOption(rawValue: languageCode)
    }

    var difficulty: LearningDifficulty? {
        LearningDifficulty(rawValue: difficultyCode)
    }
}
