import Foundation

/// Decides which word belongs to which day.
///
/// The word list is stored pre-shuffled, and day N of the schedule shows entry N,
/// so a word can only appear once until the whole list has been shown. The
/// schedule is computed from the date alone, which lets the widget and the app
/// agree on today's word without sharing any storage.
struct DailySchedule {
    var words: [Word] = WordLibrary.all
    var calendar: Calendar = .current

    /// Index of the word for the "word day" containing `date`. A word day runs
    /// from 07:00 to 07:00 the next morning.
    func dayIndex(for date: Date) -> Int {
        guard let start = calendar.date(from: AppConfig.scheduleStart) else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: wordDay(containing: date)).day ?? 0
        return max(0, days)
    }

    func word(for date: Date) -> Word? {
        word(atDayIndex: dayIndex(for: date))
    }

    /// Wraps around only after every word has been shown once.
    func word(atDayIndex index: Int) -> Word? {
        guard !words.isEmpty else { return nil }
        return words[index % words.count]
    }

    /// The next 07:00 strictly after `date`.
    func nextRollover(after date: Date) -> Date {
        let components = DateComponents(hour: AppConfig.rolloverHour, minute: 0, second: 0)
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(24 * 60 * 60)
    }

    /// Words shown so far, newest first, including today's.
    func history(upTo date: Date) -> [(date: Date, word: Word)] {
        guard let start = calendar.date(from: AppConfig.scheduleStart) else { return [] }
        let today = dayIndex(for: date)
        let shown = min(today + 1, words.count)
        return (0..<shown).reversed().compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: start),
                  let word = word(atDayIndex: index) else { return nil }
            return (day, word)
        }
    }

    /// Whether every word has been shown at least once.
    func hasCompletedCycle(at date: Date) -> Bool {
        dayIndex(for: date) >= words.count
    }

    private func wordDay(containing date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        guard calendar.component(.hour, from: date) < AppConfig.rolloverHour else { return startOfDay }
        return calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
    }
}
