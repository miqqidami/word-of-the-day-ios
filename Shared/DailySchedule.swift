import Foundation

/// Decides which word belongs to which day.
///
/// The word list is stored pre-shuffled and words are handed out strictly in
/// list order: one per day, plus one more each time the user taps "Next word"
/// (see `WordProgress`). A word can therefore only appear once until the whole
/// list has been shown.
struct DailySchedule {
    var words: [Word] = WordLibrary.all
    var calendar: Calendar = .current
    /// Day indices on which the user asked for an extra word.
    var advances: [Int] = WordProgress.advances()

    struct ShownWord {
        let position: Int
        let date: Date
        let word: Word
    }

    /// Index of the "word day" containing `date`. A word day runs from 07:00 to
    /// 07:00 the next morning.
    func dayIndex(for date: Date) -> Int {
        guard let start = calendar.date(from: AppConfig.scheduleStart) else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: wordDay(containing: date)).day ?? 0
        return max(0, days)
    }

    /// Position in the word list shown at `date`: one per day plus every
    /// "Next word" tap up to and including that day.
    func position(for date: Date) -> Int {
        position(onDayIndex: dayIndex(for: date))
    }

    func word(for date: Date) -> Word? {
        word(atPosition: position(for: date))
    }

    /// Wraps around only after every word has been shown once.
    func word(atPosition position: Int) -> Word? {
        guard !words.isEmpty else { return nil }
        return words[position % words.count]
    }

    /// The next 07:00 strictly after `date`.
    func nextRollover(after date: Date) -> Date {
        let components = DateComponents(hour: AppConfig.rolloverHour, minute: 0, second: 0)
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(24 * 60 * 60)
    }

    /// Every word shown so far, newest first, including the current one.
    func history(upTo date: Date) -> [ShownWord] {
        guard let start = calendar.date(from: AppConfig.scheduleStart) else { return [] }
        let today = dayIndex(for: date)
        var shown: [ShownWord] = []
        for day in (0...today).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: day, to: start) else { continue }
            let first = day + advances.filter { $0 < day }.count
            let last = position(onDayIndex: day)
            for index in (first...last).reversed() {
                if let word = word(atPosition: index) {
                    shown.append(ShownWord(position: index, date: dayDate, word: word))
                }
            }
        }
        return shown
    }

    /// Whether every word has been shown at least once.
    func hasCompletedCycle(at date: Date) -> Bool {
        position(for: date) >= words.count
    }

    private func position(onDayIndex day: Int) -> Int {
        day + advances.filter { $0 <= day }.count
    }

    private func wordDay(containing date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        guard calendar.component(.hour, from: date) < AppConfig.rolloverHour else { return startOfDay }
        return calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
    }
}
