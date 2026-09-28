import SwiftUI
import WidgetKit

/// Caption row at the top of every tile, like the system widgets
/// (symbol + name, extra info on the trailing side).
struct TileLabel: View {
    let symbol: String
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(title)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
            }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
    }
}

/// Lock screen tile with today's word and its meaning. No background: like the
/// system widgets, the text sits directly on the wallpaper.
struct WordTile: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileLabel(symbol: "character.book.closed.fill", title: "Kelime", trailing: word.level)
            Text(word.word)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .widgetAccentable()
            Text(word.meaning.withoutParentheticals)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Lock screen tile with a short example sentence for today's word. Meant to
/// sit to the right of `WordTile` so the two fill the widget row.
struct SentenceTile: View {
    let word: Word

    /// The shortest example fits the small tile best.
    private var example: Word.Example? {
        word.examples.min { $0.tr.count < $1.tr.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileLabel(symbol: "text.quote", title: "Örnek")
            Text(example?.tr ?? word.word)
                .font(.subheadline.weight(.semibold))
                .minimumScaleFactor(0.75)
                .lineLimit(2)
                .widgetAccentable()
            Text((example?.en ?? word.meaning).withoutParentheticals)
                .font(.caption)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Home screen tiles: plain system background with a quiet red accent.
struct HomeWordTile: View {
    let word: Word
    let showsExample: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TileLabel(symbol: "character.book.closed.fill", title: "Kelime", trailing: word.level)
                .foregroundStyle(.red)
            Spacer(minLength: 0)
            Text(word.word)
                .font(.system(size: showsExample ? 28 : 24, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(showsExample ? 1 : 2)
            Text(word.meaning.withoutParentheticals)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(showsExample ? 1 : 2)
            if showsExample, let example = word.examples.min(by: { $0.tr.count < $1.tr.count }) {
                Divider().padding(.vertical, 2)
                Text(example.tr)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Text(example.en.withoutParentheticals)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension String {
    /// Drops "(…)" notes so text fits a small tile; the app shows the full text.
    var withoutParentheticals: String {
        replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
