import Foundation

enum AppConfig {
    static let widgetKind = "TurkishWordOfTheDay"
    static let sentenceWidgetKind = "TurkishSentenceOfTheDay"
    static let urlScheme = "wordoftheday"
    static let appGroupID = "group.com.miqdam.wordoftheday"

    /// The word changes every day at this local hour.
    static let rolloverHour = 7

    /// Day 0 of the schedule: the first entry of `turkish_words.json` is shown
    /// from 07:00 on this date. Never change it, or already-shown words would
    /// come up again.
    static let scheduleStart = DateComponents(year: 2026, month: 9, day: 29)

    static func url(for word: Word) -> URL {
        URL(string: "\(urlScheme)://word/\(word.id)")!
    }

    static func wordID(from url: URL) -> String? {
        guard url.scheme == urlScheme, url.host == "word" else { return nil }
        return url.pathComponents.dropFirst().first
    }
}
