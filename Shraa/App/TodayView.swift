import SwiftUI
import SwiftData

struct TodayView: View {
    @Binding var tab: Int
    @Environment(\.modelContext) private var context
    @AppStorage("name") private var name = "Shreya"
    @AppStorage(Prefs.Key.stepGoal) private var stepGoal = 10_000
    @AppStorage(Prefs.Key.waterGoalML) private var waterGoal = 3_000

    @Query private var monthTxns: [Txn]
    @Query private var todayWater: [WaterLog]
    @Query private var todayGym: [GymLog]
    @Query(filter: #Predicate<TaskItem> { !$0.isDone }, sort: \TaskItem.due) private var openTasks: [TaskItem]
    @Query private var budgets: [Budget]
    @Query private var unparsed: [UnparsedSMS]

    @State private var steps = 0
    @State private var showSettings = false

    init(tab: Binding<Int>) {
        _tab = tab
        let month = Date().startOfMonth
        let today = Date().startOfDay
        _monthTxns = Query(filter: #Predicate<Txn> { $0.date >= month }, sort: \Txn.date, order: .reverse)
        _todayWater = Query(filter: #Predicate<WaterLog> { $0.date >= today })
        _todayGym   = Query(filter: #Predicate<GymLog>  { $0.date >= today })
    }

    private var stats: MoneyStats { MoneyStats(txns: monthTxns, budgets: budgets) }
    private var water: Int { todayWater.reduce(0) { $0 + $1.ml } }

    private var topTasks: [TaskItem] {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Date().startOfDay)!
        return openTasks
            .filter { ($0.due ?? .distantFuture) < end }
            .sorted { $0.priority > $1.priority }
            .prefix(3).map { $0 }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<12:  return "Good morning, \(name) ☀️"
        case 12..<17: return "Hey \(name) 👋"
        case 17..<21: return "Evening, \(name) 🌆"
        default:      return "Late night, \(name) 🌙"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ── Hero ────────────────────────────────────────────────
                    HeroCard {
                        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.70))
                            .tracking(0.6)

                        Text(greeting)
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            heroPill(count: HealthActions.gymStreak(context: context),   label: "gym")
                            heroPill(count: HealthActions.waterStreak(context: context), label: "water")
                        }
                    }

                    // ── Review inbox banner ──────────────────────────────
                    if !unparsed.isEmpty {
                        NavigationLink { ReviewInboxView() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "tray.full.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(unparsed.count) bank SMS need a look")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Tap to review or add by hand")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(Color.orange.opacity(0.09),
                                        in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    // ── Money card ───────────────────────────────────────
                    Button { tab = 1 } label: { moneyCard }
                        .buttonStyle(.plain)

                    // ── Health card ──────────────────────────────────────
                    healthCard

                    // ── Top 3 tasks ──────────────────────────────────────
                    Button { tab = 2 } label: { tasksCard }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.surfaceBase)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.brandCoral)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task { steps = await HealthService.shared.todaySteps() }
            .refreshable { steps = await HealthService.shared.todaySteps() }
        }
    }

    // MARK: – Sub-views

    // White semi-transparent pill on the gradient hero
    private func heroPill(count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("🔥").font(.caption)
            Text("\(count)")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(.white.opacity(0.20), in: Capsule())
    }

    private var moneyCard: some View {
        Card(title: "Money", icon: "indianrupeesign.circle") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stats.spentToday.rupees)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text("spent today").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(stats.safeToSpendPerDay.rupees)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(stats.spentToday > stats.safeToSpendPerDay ? .red : .green)
                    Text("safe per day").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 2)

            BudgetBar(spent: stats.spent, limit: stats.monthlyBudget, color: .brandCoral)

            Text("\(stats.spent.rupees) of \(stats.monthlyBudget.rupees) this month")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var healthCard: some View {
        Card(title: "Body", icon: "figure.walk") {
            HStack(spacing: 0) {
                RingStat(value: steps.withCommas,
                         label: "of \(stepGoal.withCommas)\nsteps",
                         progress: Double(steps) / Double(max(stepGoal, 1)),
                         color: .green, icon: "figure.walk")
                RingStat(value: "\(water) ml",
                         label: "of \(waterGoal) ml\nwater",
                         progress: Double(water) / Double(max(waterGoal, 1)),
                         color: .blue, icon: "drop.fill")
                RingStat(value: todayGym.isEmpty ? (Prefs.isGymDay() ? "Not yet" : "Rest") : "Done ✓",
                         label: "gym",
                         progress: todayGym.isEmpty ? 0 : 1,
                         color: .orange, icon: "dumbbell.fill")
            }
            .padding(.bottom, 6)

            HStack(spacing: 8) {
                waterButton(ml: 250)
                waterButton(ml: 500)
                if todayGym.isEmpty {
                    Button {
                        Task { await HealthActions.checkInGym(context: context) }
                    } label: {
                        Label("Gym", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
            }
        }
    }

    private func waterButton(ml: Int) -> some View {
        Button {
            Task { await HealthActions.logWater(ml, context: context) }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "drop.fill").font(.caption2)
                Text("+\(ml)")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .controlSize(.small)
    }

    private var tasksCard: some View {
        Card(title: "Top 3 today", icon: "checklist") {
            if topTasks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                    Text("Nothing due. Tap to plan your day →")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topTasks.enumerated()), id: \.offset) { idx, task in
                        TaskRow(task: task)
                            .padding(.vertical, 6)
                        if idx < topTasks.count - 1 {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
    }
}
