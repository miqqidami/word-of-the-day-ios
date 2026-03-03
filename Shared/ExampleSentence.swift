import Foundation

struct ExampleSentence: Codable, Hashable, Identifiable {
    let sentence: String
    let englishTranslation: String

    var id: String {
        sentence + "|" + englishTranslation
    }
}
