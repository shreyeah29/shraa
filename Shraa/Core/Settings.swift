import Foundation

/// All user goals and preferences. Stored in UserDefaults so App Intents and background tasks can read them.
/// Times are stored as minutes after midnight.
enum Prefs {
    enum Key {
        static let stepGoal = "stepGoal"
        static let waterGoalML = "waterGoalML"
        static let gymDays = "gymDays"              // comma-separated weekday numbers, 1 = Sunday
        static let wakeMinutes = "wakeMinutes"
        static let sleepMinutes = "sleepMinutes"
        static let gymMinutes = "gymMinutes"
        static let breakfastMinutes = "breakfastMinutes"
        static let lunchMinutes = "lunchMinutes"
        static let dinnerMinutes = "dinnerMinutes"
        static let monthlyBudget = "monthlyBudget"
        static let faceIDLock = "faceIDLock"
        static let nudgesEnabled = "nudgesEnabled"
        static let onboarded = "onboarded"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.stepGoal: 10_000,
            Key.waterGoalML: 3_000,
            Key.gymDays: "2,3,4,5,6",      // Mon–Fri
            Key.wakeMinutes: 7 * 60,
            Key.sleepMinutes: 23 * 60,
            Key.gymMinutes: 18 * 60,
            Key.breakfastMinutes: 9 * 60,
            Key.lunchMinutes: 13 * 60 + 30,
            Key.dinnerMinutes: 20 * 60 + 30,
            Key.monthlyBudget: 30_000.0,
            Key.faceIDLock: true,
            Key.nudgesEnabled: true,
            Key.onboarded: false
        ])
    }

    private static var d: UserDefaults { .standard }
    static var stepGoal: Int { d.integer(forKey: Key.stepGoal) }
    static var waterGoalML: Int { d.integer(forKey: Key.waterGoalML) }
    static var wakeMinutes: Int { d.integer(forKey: Key.wakeMinutes) }
    static var sleepMinutes: Int { d.integer(forKey: Key.sleepMinutes) }
    static var gymMinutes: Int { d.integer(forKey: Key.gymMinutes) }
    static var monthlyBudget: Double { d.double(forKey: Key.monthlyBudget) }
    static var nudgesEnabled: Bool { d.bool(forKey: Key.nudgesEnabled) }
    static var gymDays: Set<Int> {
        Set((d.string(forKey: Key.gymDays) ?? "").split(separator: ",").compactMap { Int($0) })
    }
    static func mealMinutes(_ meal: MealKind) -> Int? {
        switch meal {
        case .breakfast: return d.integer(forKey: Key.breakfastMinutes)
        case .lunch: return d.integer(forKey: Key.lunchMinutes)
        case .dinner: return d.integer(forKey: Key.dinnerMinutes)
        case .snack: return nil
        }
    }
    static func isGymDay(_ date: Date = .now) -> Bool {
        gymDays.contains(Calendar.current.component(.weekday, from: date))
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
    func at(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: startOfDay) ?? self
    }
    var daysLeftInMonth: Int {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: self) ?? 1..<31
        return range.count - cal.component(.day, from: self) + 1
    }
}

extension Double {
    /// ₹1,23,456 style (Indian grouping).
    var rupees: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_IN")
        f.currencySymbol = "₹"
        f.maximumFractionDigits = self.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return f.string(from: NSNumber(value: self)) ?? "₹\(Int(self))"
    }
}

extension Int {
    var withCommas: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IN")
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

func timeString(minutes: Int) -> String {
    let date = Date().at(minutes: minutes)
    return date.formatted(date: .omitted, time: .shortened)
}
