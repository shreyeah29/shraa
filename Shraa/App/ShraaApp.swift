import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct ShraaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(DataStore.container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @AppStorage(Prefs.Key.faceIDLock) private var faceIDLock = true
    @AppStorage(Prefs.Key.onboarded) private var onboarded = false
    @State private var locked = true
    @State private var authenticating = false
    @State private var tab = 0

    var body: some View {
        ZStack {
            if onboarded {
                TabView(selection: $tab) {
                    TodayView(tab: $tab)
                        .tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
                    MoneyView()
                        .tabItem { Label("Money", systemImage: "indianrupeesign.circle") }.tag(1)
                    WorkView()
                        .tabItem { Label("Work", systemImage: "checklist") }.tag(2)
                    HealthView()
                        .tabItem { Label("Health", systemImage: "figure.walk") }.tag(3)
                    WellnessView()
                        .tabItem { Label("Glow", systemImage: "sparkles") }.tag(4)
                }
            } else {
                OnboardingView()
            }

            if locked && faceIDLock && onboarded {
                LockScreen(unlock: authenticate)
            }
        }
        .onChange(of: phase) { _, newPhase in
            switch newPhase {
            case .active:
                if locked && faceIDLock { authenticate() }
                Task {
                    await NudgeScheduler.shared.replan(context: context)
                    NudgeScheduler.shared.scheduleBackgroundRefresh()
                }
            case .background:
                locked = true
            default: break
            }
        }
        .task {
            if faceIDLock { authenticate() } else { locked = false }
            await NudgeScheduler.shared.replan(context: context)
            NudgeScheduler.shared.scheduleBackgroundRefresh()
        }
    }

    private func authenticate() {
        guard !authenticating, locked else { return }
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { locked = false; return }
        authenticating = true
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Shraa") { ok, _ in
            DispatchQueue.main.async {
                if ok { locked = false }
                authenticating = false
            }
        }
    }
}

struct LockScreen: View {
    let unlock: () -> Void
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.tint)
                Text("Shraa is locked").font(.title3.bold())
                Button("Unlock", action: unlock).buttonStyle(.borderedProminent)
            }
        }
    }
}
