import Foundation
import HealthKit
import SwiftData

/// Thin wrapper over HealthKit.
final class HealthService {
    static let shared = HealthService()
    let store = HKHealthStore()
    private var observerStarted = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning),
         HKQuantityType(.dietaryWater), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()]
    }
    private var writeTypes: Set<HKSampleType> { [HKQuantityType(.dietaryWater)] }

    func requestAuthorization() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    func todaySteps() async -> Int {
        Int(await todaySum(.stepCount, unit: .count()))
    }

    func todayActiveEnergy() async -> Int {
        Int(await todaySum(.activeEnergyBurned, unit: .kilocalorie()))
    }

    private func todaySum(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard isAvailable else { return 0 }
        let type = HKQuantityType(id)
        let pred = HKQuery.predicateForSamples(withStart: Date().startOfDay, end: .now)
        let desc = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: pred),
                                               options: .cumulativeSum)
        let result = try? await desc.result(for: store)
        return result?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    /// Hours asleep from 6 pm yesterday until now.
    func lastNightSleepHours() async -> Double? {
        guard isAvailable else { return nil }
        let start = Date().startOfDay.addingTimeInterval(-6 * 3600)
        let pred = HKQuery.predicateForSamples(withStart: start, end: .now)
        let desc = HKSampleQueryDescriptor(predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: pred)],
                                           sortDescriptors: [])
        guard let samples = try? await desc.result(for: store), !samples.isEmpty else { return nil }
        let asleep = samples.filter {
            guard let v = HKCategoryValueSleepAnalysis(rawValue: $0.value) else { return false }
            return HKCategoryValueSleepAnalysis.allAsleepValues.contains(v)
        }
        let seconds = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return seconds > 0 ? seconds / 3600 : nil
    }

    func saveWater(ml: Int) async {
        guard isAvailable else { return }
        let q = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
        let sample = HKQuantitySample(type: HKQuantityType(.dietaryWater), quantity: q, start: .now, end: .now)
        try? await store.save(sample)
    }

    /// Wakes the app (about hourly) when new steps arrive, so step nudges use fresh numbers.
    func startStepObserver(onUpdate: @escaping @Sendable () async -> Void) {
        guard isAvailable, !observerStarted else { return }
        observerStarted = true
        let type = HKQuantityType(.stepCount)
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            Task {
                await onUpdate()
                completion()
            }
        }
        store.execute(query)
        store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
    }
}

/// Logging actions shared by screens, notification buttons and Siri.
@MainActor
enum HealthActions {

    @discardableResult
    static func logWater(_ ml: Int, context: ModelContext) async -> Int {
        context.insert(WaterLog(ml: ml))
        try? context.save()
        await HealthService.shared.saveWater(ml: ml)
        await NudgeScheduler.shared.replan(context: context)
        return todayWater(context: context)
    }

    static func todayWater(context: ModelContext) -> Int {
        let start = Date().startOfDay
        let logs = (try? context.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.date >= start }))) ?? []
        return logs.reduce(0) { $0 + $1.ml }
    }

    /// Returns the gym streak after checking in.
    @discardableResult
    static func checkInGym(workout: String = "Gym", context: ModelContext) async -> Int {
        if !checkedInToday(context: context) {
            context.insert(GymLog(workout: workout))
            try? context.save()
        }
        await NudgeScheduler.shared.replan(context: context)
        return gymStreak(context: context)
    }

    static func checkedInToday(context: ModelContext) -> Bool {
        let start = Date().startOfDay
        var d = FetchDescriptor<GymLog>(predicate: #Predicate { $0.date >= start })
        d.fetchLimit = 1
        return !((try? context.fetch(d)) ?? []).isEmpty
    }

    /// Consecutive planned gym days attended. Rest days don't break the streak; today only counts once done.
    static func gymStreak(context: ModelContext) -> Int {
        let logs = (try? context.fetch(FetchDescriptor<GymLog>())) ?? []
        let days = Set(logs.map { $0.date.startOfDay })
        let cal = Calendar.current
        var streak = 0
        var day = Date().startOfDay
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        for _ in 0..<365 {
            if days.contains(day) {
                streak += 1
            } else if Prefs.isGymDay(day) {
                break
            }
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    static func logMeal(_ kind: MealKind, skipped: Bool, outside: Bool = false, context: ModelContext) async {
        context.insert(MealLog(kind: kind, skipped: skipped, outside: outside))
        try? context.save()
        await NudgeScheduler.shared.replan(context: context)
    }

    static func mealLoggedToday(_ kind: MealKind, context: ModelContext) -> Bool {
        let start = Date().startOfDay
        let raw = kind.rawValue
        let logs = (try? context.fetch(FetchDescriptor<MealLog>(predicate: #Predicate { $0.date >= start && $0.kindRaw == raw }))) ?? []
        return !logs.isEmpty
    }

    /// Days in a row the water goal was hit (today counts only once hit).
    static func waterStreak(context: ModelContext) -> Int {
        let from = Calendar.current.date(byAdding: .day, value: -60, to: Date().startOfDay)!
        let logs = (try? context.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.date >= from }))) ?? []
        var perDay: [Date: Int] = [:]
        for l in logs { perDay[l.date.startOfDay, default: 0] += l.ml }
        let goal = Prefs.waterGoalML
        var day = Date().startOfDay
        if (perDay[day] ?? 0) < goal { day = Calendar.current.date(byAdding: .day, value: -1, to: day)! }
        var streak = 0
        while (perDay[day] ?? 0) >= goal {
            streak += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }
}
