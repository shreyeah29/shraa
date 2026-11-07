import Foundation
import UserNotifications
import SwiftData
import BackgroundTasks

/// Plans every reminder from your real progress. Re-plans whenever you log something,
/// when the app opens, when Health gets new steps, and on background refresh.
@MainActor
final class NudgeScheduler {
    static let shared = NudgeScheduler()
    static let refreshTaskID = "com.shreya.shraa.replan"

    enum Cat {
        static let water = "WATER"
        static let gym = "GYM"
        static let steps = "STEPS"
        static let meal = "MEAL"
        static let plain = "PLAIN"
    }
    enum Action {
        static let water250 = "WATER_250"
        static let water500 = "WATER_500"
        static let gymIn = "GYM_IN"
        static let ate = "MEAL_ATE"
        static let skipped = "MEAL_SKIPPED"
        static let snooze = "SNOOZE_30"
    }

    private let center = UNUserNotificationCenter.current()
    private let prefix = "nudge."

    // MARK: Setup

    /// Safe to call from background callbacks.
    static func replanNow() async {
        await shared.replan(context: DataStore.container.mainContext)
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func registerCategories() {
        let snooze = UNNotificationAction(identifier: Action.snooze, title: "Snooze 30 min")
        let water = UNNotificationCategory(identifier: Cat.water, actions: [
            UNNotificationAction(identifier: Action.water250, title: "Drank 250 ml 💧"),
            UNNotificationAction(identifier: Action.water500, title: "Drank 500 ml 💧💧"),
            snooze], intentIdentifiers: [])
        let gym = UNNotificationCategory(identifier: Cat.gym, actions: [
            UNNotificationAction(identifier: Action.gymIn, title: "At the gym 💪"), snooze], intentIdentifiers: [])
        let steps = UNNotificationCategory(identifier: Cat.steps, actions: [snooze], intentIdentifiers: [])
        let meal = UNNotificationCategory(identifier: Cat.meal, actions: [
            UNNotificationAction(identifier: Action.ate, title: "Ate it ✅"),
            UNNotificationAction(identifier: Action.skipped, title: "Skipped"), snooze], intentIdentifiers: [])
        center.setNotificationCategories([water, gym, steps, meal])
    }

    // MARK: Plan

    private struct Planned {
        let date: Date
        let line: NudgeLibrary.Line
        let category: String
        let key: String
        var info: [String: String] = [:]
    }

    func replan(context: ModelContext) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        guard Prefs.nudgesEnabled else { return }

        let now = Date()
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let wake = Prefs.wakeMinutes, sleep = Prefs.sleepMinutes
        var plan: [Planned] = []

        // Water
        let waterGoal = Prefs.waterGoalML
        let water = HealthActions.todayWater(context: context)
        let waterSlots = stride(from: wake + 60, through: sleep - 60, by: 90).map { $0 }
        if water < waterGoal {
            for m in waterSlots {
                let t = now.at(minutes: m)
                guard t > now else { continue }
                let fraction = Double(m - wake) / Double(max(sleep - 60 - wake, 1))
                let deficit = Double(waterGoal) * min(fraction, 1) - Double(water)
                let level = deficit <= 250 ? 0 : (deficit <= 900 && m < sleep - 180 ? 1 : 2)
                let v = ["done": "\(water)", "goal": "\(waterGoal)", "left": "\(waterGoal - water)"]
                plan.append(Planned(date: t, line: NudgeLibrary.pick(NudgeLibrary.water[level], v),
                                    category: Cat.water, key: "water.\(m)"))
            }
        }
        for m in waterSlots.prefix(3) {
            let v = ["done": "0", "goal": "\(waterGoal)", "left": "\(waterGoal)"]
            plan.append(Planned(date: tomorrow.at(minutes: m), line: NudgeLibrary.pick(NudgeLibrary.water[0], v),
                                category: Cat.water, key: "water.t.\(m)"))
        }

        // Steps
        let stepGoal = Prefs.stepGoal
        let steps = await HealthService.shared.todaySteps()
        let checkpoints: [(Int, Double)] = [(11 * 60, 0.25), (15 * 60, 0.5), (18 * 60 + 30, 0.7), (20 * 60 + 30, 0.9)]
        if steps < stepGoal {
            for (m, expected) in checkpoints where m > wake && m < sleep {
                let t = now.at(minutes: m)
                guard t > now, Double(steps) < Double(stepGoal) * expected else { continue }
                let left = stepGoal - steps
                let level = m >= 20 * 60 ? 2 : (Double(steps) < Double(stepGoal) * expected * 0.6 ? 1 : 0)
                let v = ["steps": steps.withCommas, "left": left.withCommas, "mins": "\(max(left / 100, 5))"]
                plan.append(Planned(date: t, line: NudgeLibrary.pick(NudgeLibrary.steps[level], v),
                                    category: Cat.steps, key: "steps.\(m)"))
            }
        }

        // Gym
        let streak = HealthActions.gymStreak(context: context)
        let gymAt = Prefs.gymMinutes
        if Prefs.isGymDay(now) && !HealthActions.checkedInToday(context: context) {
            for (offset, level) in [(-45, 0), (0, 1), (75, 2)] {
                let t = now.at(minutes: gymAt + offset)
                guard t > now else { continue }
                plan.append(Planned(date: t, line: NudgeLibrary.pick(NudgeLibrary.gym[level], ["streak": "\(streak)"]),
                                    category: Cat.gym, key: "gym.\(offset)"))
            }
        }
        if Prefs.isGymDay(tomorrow) {
            plan.append(Planned(date: tomorrow.at(minutes: gymAt - 45),
                                line: NudgeLibrary.pick(NudgeLibrary.gym[0], ["streak": "\(streak)"]),
                                category: Cat.gym, key: "gym.t"))
        }

        // Meals
        for kind in [MealKind.breakfast, .lunch, .dinner] {
            guard let m = Prefs.mealMinutes(kind) else { continue }
            let t = now.at(minutes: m + 15)
            if t > now && !HealthActions.mealLoggedToday(kind, context: context) {
                plan.append(Planned(date: t, line: NudgeLibrary.pick(NudgeLibrary.meal(kind), [:]),
                                    category: Cat.meal, key: "meal.\(kind.rawValue)", info: ["meal": kind.rawValue]))
            }
        }

        // Morning plan (tomorrow) and evening scorecard (today)
        let stats = MoneyStats(context: context, now: tomorrow)
        let top = topTasks(for: tomorrow, context: context)
        plan.append(Planned(date: tomorrow.at(minutes: wake + 15),
                            line: NudgeLibrary.pick(NudgeLibrary.morning,
                                                    ["tasks": top.isEmpty ? "plan your day in Shraa" : top.joined(separator: ", "),
                                                     "daily": stats.safeToSpendPerDay.rupees]),
                            category: Cat.plain, key: "morning"))
        let evening = now.at(minutes: sleep - 60)
        if evening > now {
            plan.append(Planned(date: evening, line: NudgeLibrary.pick(NudgeLibrary.evening, [:]),
                                category: Cat.plain, key: "evening"))
        }

        // Quiet hours + iOS cap of 64 pending (keep headroom for instant alerts)
        let filtered = plan
            .filter { minutesOfDay($0.date) >= wake && minutesOfDay($0.date) <= sleep }
            .sorted { $0.date < $1.date }
            .prefix(55)

        for p in filtered {
            await schedule(p.line, at: p.date, category: p.category, id: prefix + p.key, info: p.info)
        }
    }

    // MARK: Instant money alerts

    func afterTransaction(_ t: Txn, context: ModelContext) async {
        guard t.isExpense else { return }
        let stats = MoneyStats(context: context)
        if let budget = stats.budgets.first(where: { $0.category == t.category }), budget.monthlyLimit > 0 {
            let after = stats.spent(in: t.category)
            let before = after - t.amount
            let v = ["cat": t.category.label, "pct": "\(Int(after / budget.monthlyLimit * 100))"]
            if before < budget.monthlyLimit && after >= budget.monthlyLimit {
                await sendNow(NudgeLibrary.pick(NudgeLibrary.budgetBlown, v))
            } else if before < budget.monthlyLimit * 0.8 && after >= budget.monthlyLimit * 0.8 {
                await sendNow(NudgeLibrary.pick(NudgeLibrary.budgetWarning, v))
            }
        }
        if stats.spent - t.amount < stats.monthlyBudget && stats.spent >= stats.monthlyBudget {
            await sendNow(NudgeLibrary.pick(NudgeLibrary.monthBlown, [:]))
        } else if t.amount >= 2_000 {
            await sendNow(NudgeLibrary.pick(NudgeLibrary.bigSpend, ["amount": t.amount.rupees]))
        }
    }

    // MARK: Helpers

    func snooze(_ content: UNNotificationContent) async {
        let c = content.mutableCopy() as! UNMutableNotificationContent
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "snooze.\(UUID().uuidString)", content: c, trigger: trigger))
    }

    private func sendNow(_ line: NudgeLibrary.Line) async {
        let c = UNMutableNotificationContent()
        c.title = line.title
        c.body = line.body
        c.sound = .default
        try? await center.add(UNNotificationRequest(identifier: "now.\(UUID().uuidString)", content: c, trigger: nil))
    }

    private func schedule(_ line: NudgeLibrary.Line, at date: Date, category: String, id: String, info: [String: String]) async {
        let c = UNMutableNotificationContent()
        c.title = line.title
        c.body = line.body
        c.sound = .default
        c.categoryIdentifier = category
        c.userInfo = info
        c.interruptionLevel = .timeSensitive
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: c, trigger: trigger))
    }

    private func minutesOfDay(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func topTasks(for day: Date, context: ModelContext) -> [String] {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day.startOfDay)!
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isDone }))) ?? []
        return tasks
            .filter { ($0.due ?? .distantFuture) < end }
            .sorted { ($0.priority, $1.due ?? .distantFuture) > ($1.priority, $0.due ?? .distantFuture) }
            .prefix(3).map(\.title)
    }

    // MARK: Background refresh

    func scheduleBackgroundRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        req.earliestBeginDate = Date().addingTimeInterval(60 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }
}
