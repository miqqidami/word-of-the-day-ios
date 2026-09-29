import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var schedule = WordProgress.load()
    @State private var path: [Word] = []
    @State private var showsLevels = false
    /// Restarts the 07:00 timer whenever the schedule is refreshed.
    @State private var refreshedAt = Date()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let word = schedule.currentWord {
                    WordDetailView(word: word, subtitle: "Today's word", onNext: showNextWord)
                        .id(word.id)
                        .transition(.opacity)
                } else {
                    ContentUnavailableView("No words found", systemImage: "text.book.closed")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsLevels = true
                    } label: {
                        Label(CEFRLevel.summary(of: schedule.levels), systemImage: "graduationcap")
                            .labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HistoryView(schedule: schedule)
                    } label: {
                        Label("Past words", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .navigationDestination(for: Word.self) { word in
                WordDetailView(word: word, subtitle: nil)
            }
            .sheet(isPresented: $showsLevels) {
                LevelsView(schedule: schedule, onChange: setLevels)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear(perform: refresh)
        .onOpenURL { url in
            refresh()
            // The widget links to the word it is showing. If that is the current word it
            // is already on screen; otherwise (e.g. a stale widget) open it on top.
            guard let id = AppConfig.wordID(from: url),
                  id != schedule.currentWord?.id,
                  let word = WordLibrary.word(withID: id) else {
                path = []
                return
            }
            path = [word]
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refresh()
        }
        .task(id: refreshedAt) {
            // Switch to the next word at 07:00 if the app is left open.
            let wait = schedule.nextRollover(after: Date()).timeIntervalSinceNow
            try? await Task.sleep(for: .seconds(max(1, wait)))
            if !Task.isCancelled { refresh() }
        }
    }

    /// Reloads the shared log (the widget may have written to it) and records
    /// today's word if a new day has started.
    private func refresh() {
        var latest = WordProgress.load()
        if latest.update(for: Date()) {
            WordProgress.save(latest)
        }
        apply(latest)
    }

    /// Moves on to the next unseen word right away, in the app and the widgets.
    private func showNextWord() {
        var latest = WordProgress.load()
        latest.showNext(at: Date())
        WordProgress.save(latest)
        apply(latest)
    }

    private func setLevels(_ levels: Set<CEFRLevel>) {
        var latest = WordProgress.load()
        latest.setLevels(levels, at: Date())
        WordProgress.save(latest)
        apply(latest)
    }

    private func apply(_ latest: DailySchedule) {
        let changed = latest.log != schedule.log || latest.levels != schedule.levels
        withAnimation(.easeInOut(duration: 0.25)) {
            schedule = latest
        }
        refreshedAt = Date()
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

private struct LevelsView: View {
    @Environment(\.dismiss) private var dismiss
    let schedule: DailySchedule
    let onChange: (Set<CEFRLevel>) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CEFRLevel.allCases) { level in
                        row(for: level)
                    }
                } footer: {
                    Text("Only words from the selected levels are shown. Changing this takes effect right away, on the widget too. Words you've already seen never come back.")
                }
            }
            .navigationTitle("Levels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(for level: CEFRLevel) -> some View {
        let isSelected = schedule.levels.contains(level)
        let isLastSelected = isSelected && schedule.levels.count == 1
        let unseen = schedule.unseenCount(of: level)

        return Button {
            var levels = schedule.levels
            if isSelected { levels.remove(level) } else { levels.insert(level) }
            onChange(levels)
        } label: {
            HStack(spacing: 14) {
                Text(level.rawValue)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .frame(width: 32, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .foregroundStyle(.primary)
                    Text(unseen == 0 ? "All \(schedule.totalCount(of: level)) seen" : "\(unseen) new words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLastSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct HistoryView: View {
    let schedule: DailySchedule

    var body: some View {
        let history = schedule.history()
        List {
            Section {
                ForEach(history, id: \.position) { item in
                    NavigationLink(value: item.word) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.word.word).font(.headline)
                                Text(item.word.level)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
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
                Text(footer)
            }
        }
        .navigationTitle("Past words")
    }

    private var footer: String {
        let unseen = schedule.levels.reduce(0) { $0 + schedule.unseenCount(of: $1) }
        let levels = CEFRLevel.summary(of: schedule.levels)
        if schedule.selectedLevelsFinished {
            return "You've seen every \(levels) word, so new words now come from the nearest other level. Add more with tools/build_words.py."
        }
        return "\(schedule.log.count) words shown so far. \(unseen) new \(levels) words to go, none of them repeats."
    }
}

#Preview {
    ContentView()
}
