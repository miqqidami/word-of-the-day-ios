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
    private let schedule = DailySchedule()

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

struct WordWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordWidgetEntry

    var body: some View {
        Group {
            if let word = entry.word {
                content(for: word)
                    .widgetURL(AppConfig.url(for: word))
            } else {
                Text("Open the app")
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium {
                Color(.systemBackground)
            }
        }
    }

    @ViewBuilder
    private func content(for word: Word) -> some View {
        switch family {
        case .accessoryInline:
            Text("🇹🇷 \(word.word) · \(word.meaning)")

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text("TÜRKÇE · WORD OF THE DAY")
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()
                    .opacity(0.8)
                Text(word.word)
                    .font(.headline)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(word.meaning)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
                header(for: word)
                Text(word.word)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let example = word.examples.first {
                    Text(example.tr)
                        .font(.footnote)
                        .italic()
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        default:
            VStack(alignment: .leading, spacing: 6) {
                header(for: word)
                Spacer(minLength: 0)
                Text(word.word)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                Text(word.meaning)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func header(for word: Word) -> some View {
        HStack {
            Text("🇹🇷 Word of the Day")
            Spacer()
            Text(word.level)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.red)
    }
}

@main
struct WordOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: WordWidgetProvider()) { entry in
            WordWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Turkish Word of the Day")
        .description("A new everyday Turkish word at 7 AM. Tap to see its meaning and example sentences.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
    }
}

#Preview(as: .accessoryRectangular) {
    WordOfTheDayWidget()
} timeline: {
    WordWidgetEntry(date: .now, word: WordLibrary.all.first)
}
