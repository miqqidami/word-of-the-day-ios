import Foundation

/// Remembers when the user asked for an extra word, shared between the app and
/// the widget through the App Group.
///
/// Each entry is the schedule day index on which "Next word" was tapped. Every
/// tap moves today's and all later words one step further along the list, so
/// no word is skipped or repeated.
enum WordProgress {
    private static let advancesKey = "advanceDayIndices"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func advances() -> [Int] {
        defaults.array(forKey: advancesKey) as? [Int] ?? []
    }

    static func recordAdvance(onDayIndex dayIndex: Int) {
        defaults.set(advances() + [dayIndex], forKey: advancesKey)
    }
}
