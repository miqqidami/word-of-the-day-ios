import SwiftUI
import WidgetKit

struct WordWidgetEntry: TimelineEntry {
    let date: Date
    let word: WordEntry?
    let selectedLanguage: LanguageOption
}

struct WordWidgetProvider: TimelineProvider {
    private let store = WordStore.shared

    func placeholder(in context: Context) -> WordWidgetEntry {
        WordWidgetEntry(
            date: Date(),
            word: WordEntry(
                word: "hola",
                transliteration: nil,
                englishMeaning: "hello",
                exampleSentences: [
                    ExampleSentence(sentence: "Hola, como estas?", englishTranslation: "Hello, how are you?"),
                    ExampleSentence(sentence: "Ella dijo hola al entrar.", englishTranslation: "She said hello when entering."),
                    ExampleSentence(sentence: "Siempre digo hola con una sonrisa.", englishTranslation: "I always say hello with a smile.")
                ],
                characteristics: WordCharacteristics(
                    partOfSpeech: "Interjection",
                    cefrLevel: "A1",
                    register: "General",
                    usageTip: "Use it as a friendly greeting."
                ),
                languageCode: LanguageOption.spanish.rawValue,
                difficultyCode: LearningDifficulty.easy.rawValue,
                fetchedAt: Date()
            ),
            selectedLanguage: .spanish
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WordWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> WordWidgetEntry {
        let configuredLanguage = store.selectedLanguage()
        let storedWord = store.currentWord()
        let languageToDisplay = storedWord?.language ?? configuredLanguage

        return WordWidgetEntry(
            date: Date(),
            word: storedWord,
            selectedLanguage: languageToDisplay
        )
    }
}

struct WordWidgetEntryView: View {
    var entry: WordWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    private var appURL: URL? {
        URL(string: AppConfig.appDeepLink)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularView
            default:
                homeScreenView
            }
        }
        .widgetURL(appURL)
    }

    @ViewBuilder
    private var homeScreenView: some View {
        if let word = entry.word {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.selectedLanguage.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(word.word)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(word.englishMeaning)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No word yet")
                    .font(.headline)
                Text("Open the app and tap Get New Word.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    @ViewBuilder
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            if let word = entry.word {
                VStack(spacing: 2) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.caption2)
                    Text(shortWord(word.word))
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            } else {
                Image(systemName: "character.book.closed.fill")
                    .font(.caption)
            }
        }
    }

    private func shortWord(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(6))
    }
}

@main
struct WordOfTheDayWidget: Widget {
    let kind = AppConfig.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordWidgetProvider()) { entry in
            WordWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Word of the Day")
        .description("Shows your daily word. Tap to open app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
