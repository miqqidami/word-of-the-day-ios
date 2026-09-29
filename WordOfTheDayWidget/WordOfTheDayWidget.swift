import SwiftUI
import WidgetKit

struct WordWidgetEntry: TimelineEntry {
    let date: Date
    let word: Word?
}

struct WordWidgetProvider: TimelineProvider {
    /// How many upcoming 07:00 rollovers to schedule ahead, so the word still
    /// changes on time if WidgetKit delays the next reload.
    private let daysAhead = 7
    /// Rebuilt on every request so a "Next word" tap in the app is picked up.
    private var schedule: DailySchedule { DailySchedule() }

    func placeholder(in context: Context) -> WordWidgetEntry {
        WordWidgetEntry(date: Date(), word: schedule.word(for: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (WordWidgetEntry) -> Void) {
        completion(WordWidgetEntry(date: Date(), word: schedule.word(for: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordWidgetEntry>) -> Void) {
        let now = Date()
        var entries = [WordWidgetEntry(date: now, word: schedule.word(for: now))]

        var rollover = now
        for _ in 0..<daysAhead {
            rollover = schedule.nextRollover(after: rollover)
            entries.append(WordWidgetEntry(date: rollover, word: schedule.word(for: rollover)))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// Adds the deep link and the right background for the widget family.
private struct WidgetContainer<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    let word: Word?
    @ViewBuilder let content: (Word) -> Content

    var body: some View {
        Group {
            if let word {
                content(word)
                    .widgetURL(AppConfig.url(for: word))
            } else {
                Text("Open Kelime")
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium {
                Color(.systemBackground)
            }
        }
    }
}

struct WordWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordWidgetEntry

    var body: some View {
        WidgetContainer(word: entry.word) { word in
            switch family {
            case .accessoryInline:
                Label("\(word.word) · \(word.meaning.withoutParentheticals)", systemImage: "character.book.closed.fill")
            case .accessoryRectangular:
                WordTile(word: word)
            default:
                HomeWordTile(word: word, showsExample: family == .systemMedium)
            }
        }
    }
}

struct WordOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: WordWidgetProvider()) { entry in
            WordWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Word")
        .description("Today's Turkish word and its meaning. New word at 7 AM.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
    }
}

struct SentenceOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.sentenceWidgetKind, provider: WordWidgetProvider()) { entry in
            WidgetContainer(word: entry.word) { word in
                SentenceTile(word: word)
            }
        }
        .configurationDisplayName("Sentence")
        .description("An example sentence with today's word. Place it next to the Word widget to fill the row.")
        .supportedFamilies([.accessoryRectangular])
    }
}

@main
struct KelimeWidgets: WidgetBundle {
    var body: some Widget {
        WordOfTheDayWidget()
        SentenceOfTheDayWidget()
    }
}

#Preview("Word", as: .accessoryRectangular) {
    WordOfTheDayWidget()
} timeline: {
    WordWidgetEntry(date: .now, word: WordLibrary.all.first)
}

#Preview("Sentence", as: .accessoryRectangular) {
    SentenceOfTheDayWidget()
} timeline: {
    WordWidgetEntry(date: .now, word: WordLibrary.all.first)
}
