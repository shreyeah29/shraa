import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("name") private var name = "Shreya"
    @AppStorage(Prefs.Key.stepGoal) private var stepGoal = 10_000
    @AppStorage(Prefs.Key.waterGoalML) private var waterGoal = 3_000
    @AppStorage(Prefs.Key.gymDays) private var gymDays = "2,3,4,5,6"
    @AppStorage(Prefs.Key.wakeMinutes) private var wake = 420
    @AppStorage(Prefs.Key.sleepMinutes) private var sleep = 1380
    @AppStorage(Prefs.Key.gymMinutes) private var gym = 1080
    @AppStorage(Prefs.Key.breakfastMinutes) private var breakfast = 540
    @AppStorage(Prefs.Key.lunchMinutes) private var lunch = 810
    @AppStorage(Prefs.Key.dinnerMinutes) private var dinner = 1230
    @AppStorage(Prefs.Key.faceIDLock) private var faceID = true
    @AppStorage(Prefs.Key.nudgesEnabled) private var nudges = true

    @State private var testSent = false

    var body: some View {
        NavigationStack {
            List {
                // ── Profile ──────────────────────────────────────────────
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.brand)
                                .frame(width: 60, height: 60)
                            Text(name.prefix(1).uppercased())
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Your name", text: $name)
                                .font(.title3.weight(.bold))
                            Text("Shraa personal OS")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // ── Daily goals ───────────────────────────────────────────
                Section {
                    goalRow(icon: "figure.walk", color: .green, label: "Steps") {
                        Stepper("\(stepGoal.withCommas)", value: $stepGoal, in: 2_000...30_000, step: 500)
                            .labelsHidden()
                    }
                    goalRow(icon: "drop.fill", color: .blue, label: "Water") {
                        Stepper("\(waterGoal) ml", value: $waterGoal, in: 1_000...6_000, step: 250)
                            .labelsHidden()
                    }
                } header: { sectionHeader("Daily goals", icon: "target") }

                // ── Gym schedule ───────────────────────────────────────────
                Section {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            let on = days.contains(day)
                            Button(Calendar.current.veryShortWeekdaySymbols[day - 1]) {
                                withAnimation(.spring(response: 0.3)) { toggle(day) }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(on ? Color.orange : Color(.tertiarySystemFill),
                                        in: Circle())
                            .foregroundStyle(on ? Color.white : Color.primary)
                            .buttonStyle(.plain)
                            .font(.caption2.weight(.bold))
                        }
                    }
                    .padding(.vertical, 2)
                    timePicker("Gym at", $gym, icon: "dumbbell.fill", color: .orange)
                } header: {
                    sectionHeader("Gym (\(days.count) day\(days.count == 1 ? "" : "s")/week)", icon: "dumbbell.fill")
                }

                // ── Your day ──────────────────────────────────────────────
                Section {
                    timePicker("Wake up",   $wake,      icon: "sunrise.fill",  color: .yellow)
                    timePicker("Breakfast", $breakfast, icon: "cup.and.saucer.fill", color: .orange)
                    timePicker("Lunch",     $lunch,     icon: "fork.knife",     color: .brandCoral)
                    timePicker("Dinner",    $dinner,    icon: "moon.stars.fill", color: .indigo)
                    timePicker("Sleep",     $sleep,     icon: "bed.double.fill", color: .purple)
                } header: {
                    sectionHeader("Your day", icon: "clock.fill")
                } footer: {
                    Text("No nudges before you wake or after you sleep.")
                }

                // ── App ───────────────────────────────────────────────────
                Section {
                    HStack {
                        iconChip("bell.badge.fill", color: .brandCoral)
                        Toggle("Nudges", isOn: $nudges)
                    }
                    HStack {
                        iconChip("faceid", color: .green)
                        Toggle("Face ID lock", isOn: $faceID)
                    }
                } header: {
                    sectionHeader("App", icon: "gearshape.fill")
                } footer: {
                    Text("Nudge tone: tough, strict and funny. You asked for it.")
                }

                // ── Test ──────────────────────────────────────────────────
                Section {
                    Button {
                        Task {
                            await test()
                            withAnimation { testSent = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { testSent = false }
                            }
                        }
                    } label: {
                        HStack {
                            Label(testSent ? "Nudge sent ✓" : "Send a test nudge",
                                  systemImage: testSent ? "checkmark.circle.fill" : "bell.badge.fill")
                                .foregroundStyle(testSent ? .green : Color.brandCoral)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task { await NudgeScheduler.shared.replan(context: context) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brandCoral)
                }
            }
        }
    }

    // MARK: – Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.brandCoral)
            .textCase(nil)
    }

    private func iconChip(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: 30, height: 30)
            Image(systemName: name)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
    }

    private func goalRow<Content: View>(icon: String, color: Color, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            iconChip(icon, color: color)
            Text(label)
            Spacer()
            content()
        }
    }

    private func timePicker(_ label: String, _ minutes: Binding<Int>, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            iconChip(icon, color: color)
            DatePicker(label, selection: Binding(
                get: { Date().at(minutes: minutes.wrappedValue) },
                set: {
                    let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                    minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                }), displayedComponents: .hourAndMinute)
        }
    }

    private var days: Set<Int> { Set(gymDays.split(separator: ",").compactMap { Int($0) }) }

    private func toggle(_ day: Int) {
        var d = days
        if d.contains(day) { d.remove(day) } else { d.insert(day) }
        gymDays = d.sorted().map(String.init).joined(separator: ",")
    }

    private func test() async {
        let c = UNMutableNotificationContent()
        let line = NudgeLibrary.pick(NudgeLibrary.water[2], ["done": "500", "goal": "\(waterGoal)", "left": "\(waterGoal - 500)"])
        c.title = line.title
        c.body = line.body
        c.sound = .default
        c.categoryIdentifier = NudgeScheduler.Cat.water
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: c, trigger: trigger))
    }
}
