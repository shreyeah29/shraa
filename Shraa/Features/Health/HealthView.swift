import SwiftUI
import SwiftData
import Charts

struct HealthView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.Key.stepGoal)   private var stepGoal  = 10_000
    @AppStorage(Prefs.Key.waterGoalML) private var waterGoal = 3_000

    @Query private var weekWater: [WaterLog]
    @Query private var weekGym:   [GymLog]
    @Query private var todayMeals: [MealLog]

    @State private var steps   = 0
    @State private var energy  = 0
    @State private var sleep: Double? = nil
    @State private var workout = "Strength"

    private let workouts = ["Strength", "Cardio", "Yoga", "Home workout", "Sports", "Walk / Run"]

    init() {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date().startOfDay)!
        let today   = Date().startOfDay
        _weekWater  = Query(filter: #Predicate<WaterLog> { $0.date >= weekAgo }, sort: \WaterLog.date, order: .reverse)
        _weekGym    = Query(filter: #Predicate<GymLog>   { $0.date >= weekAgo }, sort: \GymLog.date,   order: .reverse)
        _todayMeals = Query(filter: #Predicate<MealLog>  { $0.date >= today })
    }

    private var todayWaterLogs: [WaterLog] { weekWater.filter { $0.date >= Date().startOfDay } }
    private var water:   Int  { todayWaterLogs.reduce(0) { $0 + $1.ml } }
    private var gymToday: Bool { weekGym.contains { $0.date >= Date().startOfDay } }

    struct DayStat: Identifiable {
        let day: Date; let water: Int; let gym: Bool
        var id: Date { day }
    }

    private var last7: [DayStat] {
        (0..<7).reversed().map { offset in
            let day  = Calendar.current.date(byAdding: .day, value: -offset, to: Date().startOfDay)!
            let next = Calendar.current.date(byAdding: .day, value:  1,      to: day)!
            let w = weekWater.filter { $0.date >= day && $0.date < next }.reduce(0) { $0 + $1.ml }
            let g = weekGym.contains   { $0.date >= day && $0.date < next }
            return DayStat(day: day, water: w, gym: g)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ringsCard
                    waterCard
                    gymCard
                    mealsCard
                    weekCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.surfaceBase)
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.large)
            .task     { await refresh() }
            .refreshable { await refresh() }
        }
    }

    private func refresh() async {
        steps  = await HealthService.shared.todaySteps()
        energy = await HealthService.shared.todayActiveEnergy()
        sleep  = await HealthService.shared.lastNightSleepHours()
    }

    // MARK: – Cards

    private var ringsCard: some View {
        Card {
            HStack(spacing: 0) {
                RingStat(value: steps.withCommas,
                         label: "of \(stepGoal.withCommas)\nsteps",
                         progress: Double(steps) / Double(max(stepGoal, 1)),
                         color: .green, icon: "figure.walk")
                RingStat(value: "\(energy)",
                         label: "active\nkcal",
                         progress: Double(energy) / 500,
                         color: .pink, icon: "flame.fill")
                RingStat(value: sleep.map { String(format: "%.1f h", $0) } ?? "–",
                         label: "sleep",
                         progress: (sleep ?? 0) / 8,
                         color: .indigo, icon: "moon.fill")
            }
            .padding(.bottom, 4)

            if steps >= stepGoal {
                Label("Step goal smashed. Legend behaviour 🏆", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Text("\((stepGoal - steps).withCommas) steps to go — about \(max((stepGoal - steps) / 100, 1)) min of walking")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var waterCard: some View {
        Card(title: "Water", icon: "drop.fill") {
            HStack(alignment: .firstTextBaseline) {
                Text("\(water)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("/ \(waterGoal) ml")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                StreakBadge(count: HealthActions.waterStreak(context: context), label: "days")
            }
            BudgetBar(spent: Double(water), limit: Double(waterGoal), color: .blue)
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                ForEach([250, 500, 750], id: \.self) { ml in
                    Button("+\(ml) ml") {
                        Task { await HealthActions.logWater(ml, context: context) }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.small)
                }
            }

            if let last = todayWaterLogs.first {
                Button {
                    context.delete(last)
                    try? context.save()
                    Task { await NudgeScheduler.shared.replan(context: context) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo last log")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private var gymCard: some View {
        Card(title: "Gym", icon: "dumbbell.fill") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(gymToday
                         ? "Done today ✅"
                         : (Prefs.isGymDay() ? "Not yet — today is a gym day" : "Rest day"))
                        .font(.headline)
                    Text("Gym at \(timeString(minutes: Prefs.gymMinutes))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StreakBadge(count: HealthActions.gymStreak(context: context), label: "streak")
            }

            if !gymToday {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(workouts, id: \.self) { w in
                            Button(w) { workout = w }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(workout).lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        Task { await HealthActions.checkInGym(workout: workout, context: context) }
                    } label: {
                        Label("Check in", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
    }

    private var mealsCard: some View {
        Card(title: "Meals", icon: "fork.knife") {
            VStack(spacing: 0) {
                ForEach([MealKind.breakfast, .lunch, .dinner]) { kind in
                    mealRow(kind)
                    if kind != .dinner { Divider() }
                }
            }
        }
    }

    private func mealRow(_ kind: MealKind) -> some View {
        let log = todayMeals.first { $0.kind == kind }
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: mealIcon(kind))
                    .font(.subheadline)
                    .foregroundStyle(mealColor(kind))
                    .frame(width: 28)
                Text(kind.label)
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
            if let log {
                Text(log.skipped ? "Skipped" : (log.outside ? "Ate outside" : "Home cooked"))
                    .font(.subheadline)
                    .foregroundStyle(log.skipped ? .red : .green)
            } else {
                Menu("Log") {
                    Button { Task { await HealthActions.logMeal(kind, skipped: false,          context: context) } }
                        label: { Label("Ate at home",    systemImage: "house.fill") }
                    Button { Task { await HealthActions.logMeal(kind, skipped: false, outside: true, context: context) } }
                        label: { Label("Ate outside",    systemImage: "fork.knife") }
                    Button(role: .destructive) { Task { await HealthActions.logMeal(kind, skipped: true, context: context) } }
                        label: { Label("Skipped",        systemImage: "xmark.circle") }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 10)
    }

    private func mealIcon(_ k: MealKind) -> String {
        switch k { case .breakfast: "sunrise.fill"; case .lunch: "sun.max.fill"; case .dinner: "moon.stars.fill"; default: "fork.knife" }
    }
    private func mealColor(_ k: MealKind) -> Color {
        switch k { case .breakfast: .orange; case .lunch: .yellow; case .dinner: .indigo; default: .secondary }
    }

    private var weekCard: some View {
        Card(title: "Last 7 days", icon: "calendar") {
            Chart(last7) { d in
                BarMark(x: .value("Day", d.day, unit: .day),
                        y: .value("Water (ml)", d.water))
                    .foregroundStyle(d.water >= waterGoal
                                     ? Color.blue
                                     : Color.blue.opacity(0.30))
                    .cornerRadius(6)
                RuleMark(y: .value("Goal", waterGoal))
                    .foregroundStyle(Color.blue.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 110)

            // Gym dots row
            HStack {
                ForEach(last7) { d in
                    VStack(spacing: 4) {
                        Image(systemName: d.gym ? "dumbbell.fill" : "circle.dotted")
                            .font(.caption2)
                            .foregroundStyle(d.gym ? Color.orange : Color.secondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)

            HStack(spacing: 16) {
                Label("water goal met", systemImage: "square.fill")
                    .foregroundStyle(.blue)
                Label("gym day", systemImage: "square.fill")
                    .foregroundStyle(.orange)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
