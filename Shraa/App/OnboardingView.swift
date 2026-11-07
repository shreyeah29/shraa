import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.Key.onboarded)    private var onboarded    = false
    @AppStorage(Prefs.Key.monthlyBudget) private var monthlyBudget = 30_000.0
    @AppStorage("name")                 private var name          = "Shreya"
    @State private var step = 0

    // Per-step palette
    private let pages: [(icon: String, gradient: [Color], title: String, body: String)] = [
        ("sparkles.tv",
         [Color(red: 1, green: 0.38, blue: 0.28), Color(red: 1, green: 0.62, blue: 0.20)],
         "Hey there, I'm Shraa.",
         "Your money, your work and your health in one app. Fair warning — I nag. That's the whole point."),
        ("heart.text.square",
         [Color(red: 0.30, green: 0.70, blue: 0.55), Color(red: 0.20, green: 0.55, blue: 0.85)],
         "Connect Apple Health",
         "Steps, sleep, workouts — I read them and nag you if you're falling behind. I also save water you log."),
        ("bell.badge.fill",
         [Color(red: 0.55, green: 0.35, blue: 1.00), Color(red: 0.30, green: 0.55, blue: 1.00)],
         "Allow Notifications",
         "Tough, strict and a little rude. Only when you're actually behind. Turn on Time Sensitive so I cut through Focus."),
    ]

    var body: some View {
        ZStack {
            // Full-screen gradient background
            LinearGradient(
                colors: step < pages.count ? pages[step].gradient : [.brandCoral, .brandAmber],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: step)

            VStack(spacing: 0) {
                Spacer()

                if step < pages.count {
                    // Info page
                    VStack(spacing: 28) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.20))
                                .frame(width: 110, height: 110)
                            Image(systemName: pages[step].icon)
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 12) {
                            Text(pages[step].title)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text(pages[step].body)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)))
                    .id(step)
                } else {
                    // Budget page
                    VStack(spacing: 28) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.20))
                                .frame(width: 110, height: 110)
                            Image(systemName: "indianrupeesign.circle.fill")
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 12) {
                            Text("One last thing.")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            Text("What's your monthly spending budget? Everything except rent and big investments.")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }

                        // Budget input field
                        VStack(spacing: 6) {
                            Text("₹")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            TextField("30000", value: $monthlyBudget, format: .number)
                                .keyboardType(.numberPad)
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .tint(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)))
                    .id(step)
                }

                Spacer()

                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<(pages.count + 1), id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.white : Color.white.opacity(0.35))
                            .frame(width: i == step ? 20 : 7, height: 7)
                            .animation(.spring(response: 0.35), value: step)
                    }
                }
                .padding(.bottom, 32)

                // CTA button
                Button(action: advance) {
                    Text(ctaLabel)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundStyle(step < pages.count ? pages[step].gradient.first ?? .brandCoral : .brandCoral)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private var ctaLabel: String {
        switch step {
        case 1:              return "Connect Health"
        case 2:              return "Allow Notifications"
        case pages.count:    return "Let's go 🚀"
        default:             return "Continue"
        }
    }

    private func advance() {
        Task {
            switch step {
            case 1: await HealthService.shared.requestAuthorization()
            case 2: _ = await NudgeScheduler.shared.requestPermission()
            case pages.count:
                withAnimation { onboarded = true }
                await NudgeScheduler.shared.replan(context: context)
                return
            default: break
            }
            withAnimation(.spring(response: 0.45)) { step += 1 }
        }
    }
}
