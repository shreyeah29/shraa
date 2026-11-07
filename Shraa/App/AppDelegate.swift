import UIKit
import UserNotifications
import BackgroundTasks
import SwiftData

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Prefs.registerDefaults()
        UNUserNotificationCenter.current().delegate = self

        BGTaskScheduler.shared.register(forTaskWithIdentifier: NudgeScheduler.refreshTaskID, using: nil) { task in
            Task { @MainActor in
                await NudgeScheduler.replanNow()
                NudgeScheduler.shared.scheduleBackgroundRefresh()
                task.setTaskCompleted(success: true)
            }
        }

        Task { @MainActor in
            NudgeScheduler.shared.registerCategories()
            // New steps in Health → re-plan step nudges with fresh numbers.
            HealthService.shared.startStepObserver {
                await NudgeScheduler.replanNow()
            }
        }
        return true
    }

    // Show nudges even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    // Notification buttons.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        await handle(action: response.actionIdentifier, content: content)
    }

    @MainActor
    private func handle(action: String, content: UNNotificationContent) async {
        let context = DataStore.container.mainContext
        switch action {
        case NudgeScheduler.Action.water250:
            await HealthActions.logWater(250, context: context)
        case NudgeScheduler.Action.water500:
            await HealthActions.logWater(500, context: context)
        case NudgeScheduler.Action.gymIn:
            await HealthActions.checkInGym(context: context)
        case NudgeScheduler.Action.ate, NudgeScheduler.Action.skipped:
            if let raw = content.userInfo["meal"] as? String, let kind = MealKind(rawValue: raw) {
                await HealthActions.logMeal(kind, skipped: action == NudgeScheduler.Action.skipped, context: context)
            }
        case NudgeScheduler.Action.snooze:
            await NudgeScheduler.shared.snooze(content)
        default:
            break
        }
    }
}
