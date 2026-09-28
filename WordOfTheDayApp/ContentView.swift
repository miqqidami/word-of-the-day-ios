import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    @State private var path: [Word] = []

    private let schedule = DailySchedule()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let word = schedule.word(for: now) {
                    WordDetailView(word: word, subtitle: "Today's word")
                } else {
                    ContentUnavailableView("No words found", systemImage: "text.book.closed")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HistoryView(now: now, schedule: schedule)
                    } label: {
                        Label("Past words", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .navigationDestination(for: Word.self) { word in
                WordDetailView(word: word, subtitle: nil)
            }
        }
        .onOpenURL { url in
            now = Date()
            // The widget links to the word it is showing. If that is today's word it is
            // already on screen; otherwise (e.g. a stale widget) open it on top.
            guard let id = AppConfig.wordID(from: url),
                  id != schedule.word(for: now)?.id,
                  let word = WordLibrary.word(withID: id) else {
                path = []
                return
            }
            path = [word]
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            now = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
        .task(id: now) {
            // Switch to the next word at 07:00 if the app is left open.
            let wait = schedule.nextRollover(after: now).timeIntervalSince(Date())
            try? await Task.sleep(for: .seconds(max(1, wait)))
            if !Task.isCancelled { now = Date() }
        }
    }
}

private struct HistoryView: View {
    let now: Date
    let schedule: DailySchedule

    var body: some View {
        let history = schedule.history(upTo: now)
        List {
            Section {
                ForEach(history, id: \.date) { item in
                    NavigationLink(value: item.word) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.word.word).font(.headline)
                                Spacer()
                                Text(item.date, format: .dateTime.day().month(.abbreviated))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.word.meaning)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text(footer(shown: history.count))
            }
        }
        .navigationTitle("Past words")
    }

    private func footer(shown: Int) -> String {
        let total = schedule.words.count
        if schedule.hasCompletedCycle(at: now) {
            return "You've seen all \(total) words. Add more with tools/build_words.py to keep getting new ones."
        }
        return "\(shown) of \(total) words shown. Each word appears only once, so the next \(total - shown) days will all be new words."
    }
}

#Preview {
    ContentView()
}
