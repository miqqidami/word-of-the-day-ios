import Foundation

/// One entry of the shown-words log.
struct ShownWord: Codable, Hashable {
    let id: String
    /// Schedule day index (see `DailySchedule.dayIndex(for:)`) it was shown on.
    let day: Int
}

/// Decides which word is shown, and keeps the log of every word already shown
/// so none of them comes up again.
///
/// A new word is picked at each 07:00 rollover and whenever the user taps
/// "Next word": the first word in the (pre-shuffled) list that has the selected
/// level and is not in the log. Picking is deterministic, so the app and the
/// widget agree on the next word even before it is written to the log.
struct DailySchedule {
    var words: [Word] = WordLibrary.all
    var calendar: Calendar = .current
    var levels: Set<CEFRLevel> = Set(CEFRLevel.allCases)
    var log: [ShownWord] = []

    /// Days missed while nothing ran (phone off, app never opened) are filled in
    /// up to this many days back: the widget may have displayed them already.
    static let catchUpDays = 7

    // MARK: Dates

    /// Index of the "word day" containing `date`. A word day runs from 07:00 to
    /// 07:00 the next morning; day 0 starts on `AppConfig.scheduleStart`.
    func dayIndex(for date: Date) -> Int {
        guard let start = calendar.date(from: AppConfig.scheduleStart) else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: wordDay(containing: date)).day ?? 0
        return max(0, days)
    }

    func date(forDayIndex day: Int) -> Date {
        let start = calendar.date(from: AppConfig.scheduleStart) ?? Date()
        return calendar.date(byAdding: .day, value: day, to: start) ?? start
    }

    /// The next 07:00 strictly after `date`.
    func nextRollover(after date: Date) -> Date {
        let components = DateComponents(hour: AppConfig.rolloverHour, minute: 0, second: 0)
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(24 * 60 * 60)
    }

    // MARK: Current word

    /// The word currently shown. Call `update(for:)` first.
    var currentWord: Word? {
        log.last.flatMap { entry in words.first { $0.id == entry.id } }
    }

    /// Records the words for any days that started since the last entry.
    /// Returns whether the log changed.
    @discardableResult
    mutating func update(for date: Date) -> Bool {
        let today = dayIndex(for: date)
        guard let lastDay = log.last?.day else {
            record(onDay: today)
            return true
        }
        guard lastDay < today else { return false }
        for day in max(lastDay + 1, today - Self.catchUpDays + 1)...today {
            record(onDay: day)
        }
        return true
    }

    /// "Next word": moves on to the next unseen word right away.
    mutating func showNext(at date: Date) {
        update(for: date)
        record(onDay: dayIndex(for: date))
    }

    /// Changes the selected levels. If the current word is not one of them any
    /// more, it is replaced straight away.
    mutating func setLevels(_ newLevels: Set<CEFRLevel>, at date: Date) {
        guard !newLevels.isEmpty else { return }
        levels = newLevels
        update(for: date)
        if let current = currentWord, !matches(current) {
            record(onDay: dayIndex(for: date))
        }
    }

    /// The words the next `count` rollovers after `date` will show, without
    /// recording them.
    func upcoming(after date: Date, count: Int) -> [(date: Date, word: Word)] {
        var preview = self
        var time = date
        var result: [(date: Date, word: Word)] = []
        for _ in 0..<count {
            time = nextRollover(after: time)
            preview.update(for: time)
            if let word = preview.currentWord {
                result.append((time, word))
            }
        }
        return result
    }

    // MARK: History and stats

    /// Every word shown so far, newest first.
    func history() -> [(position: Int, date: Date, word: Word)] {
        log.enumerated().reversed().compactMap { position, entry in
            guard let word = words.first(where: { $0.id == entry.id }) else { return nil }
            return (position, date(forDayIndex: entry.day), word)
        }
    }

    func unseenCount(of level: CEFRLevel) -> Int {
        let seen = Set(log.map(\.id))
        return words.filter { $0.cefr == level && !seen.contains($0.id) }.count
    }

    func totalCount(of level: CEFRLevel) -> Int {
        words.filter { $0.cefr == level }.count
    }

    /// True once every word of the selected levels has been shown.
    var selectedLevelsFinished: Bool {
        levels.allSatisfy { unseenCount(of: $0) == 0 }
    }

    // MARK: Picking

    private func matches(_ word: Word) -> Bool {
        word.cefr.map(levels.contains) ?? false
    }

    private mutating func record(onDay day: Int) {
        guard let word = nextWord() else { return }
        log.append(ShownWord(id: word.id, day: day))
    }

    /// The first unseen word of the selected levels, in list order. When those
    /// run out, the first unseen word of the nearest other level; when every
    /// word has been shown, the selected-level word shown longest ago.
    private func nextWord() -> Word? {
        let seen = Set(log.map(\.id))
        if let word = words.first(where: { matches($0) && !seen.contains($0.id) }) {
            return word
        }

        let unseen = words.filter { !seen.contains($0.id) }
        if let nearest = unseen.min(by: { distance($0) < distance($1) }) {
            return nearest
        }

        var lastShown: [String: Int] = [:]
        for (position, entry) in log.enumerated() { lastShown[entry.id] = position }
        let candidates = words.filter(matches)
        return (candidates.isEmpty ? words : candidates).min {
            lastShown[$0.id, default: -1] < lastShown[$1.id, default: -1]
        }
    }

    private func distance(_ word: Word) -> Int {
        guard let level = word.cefr else { return .max }
        return levels.map { abs($0.rank - level.rank) }.min() ?? .max
    }

    private func wordDay(containing date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        guard calendar.component(.hour, from: date) < AppConfig.rolloverHour else { return startOfDay }
        return calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
    }
}
