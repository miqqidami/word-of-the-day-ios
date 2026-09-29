import Foundation

/// Saves the shown-words log and the selected levels in the App Group, so the
/// app and the widget share them.
enum WordProgress {
    private static let logKey = "shownWords"
    private static let levelsKey = "selectedLevels"
    /// Written by the earlier position-based version ("Next word" tap days).
    private static let legacyAdvancesKey = "advanceDayIndices"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load(at date: Date = Date()) -> DailySchedule {
        var schedule = DailySchedule()

        if let raw = defaults.stringArray(forKey: levelsKey) {
            let levels = Set(raw.compactMap(CEFRLevel.init(rawValue:)))
            if !levels.isEmpty { schedule.levels = levels }
        }

        if let data = defaults.data(forKey: logKey),
           let log = try? JSONDecoder().decode([ShownWord].self, from: data) {
            schedule.log = log
        } else if let advances = defaults.array(forKey: legacyAdvancesKey) as? [Int] {
            schedule.log = legacyLog(advances: advances, schedule: schedule, date: date)
            save(schedule)
            defaults.removeObject(forKey: legacyAdvancesKey)
        }

        return schedule
    }

    static func save(_ schedule: DailySchedule) {
        if let data = try? JSONEncoder().encode(schedule.log) {
            defaults.set(data, forKey: logKey)
        }
        defaults.set(schedule.levels.sorted().map(\.rawValue), forKey: levelsKey)
    }

    /// Rebuilds the words the previous version showed: word N on day N, plus
    /// one extra word per "Next word" tap.
    private static func legacyLog(advances: [Int], schedule: DailySchedule, date: Date) -> [ShownWord] {
        let words = schedule.words
        guard !words.isEmpty else { return [] }
        var log: [ShownWord] = []
        for day in 0...schedule.dayIndex(for: date) {
            let first = day + advances.filter { $0 < day }.count
            let last = day + advances.filter { $0 <= day }.count
            for position in first...last {
                log.append(ShownWord(id: words[position % words.count].id, day: day))
            }
        }
        return log
    }
}
