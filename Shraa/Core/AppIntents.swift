import AppIntents
import SwiftData

/// Called by the Shortcuts "Message" automation with the bank SMS text. Runs without opening the app.
struct LogBankSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Bank SMS"
    static var description = IntentDescription("Reads a bank transaction SMS and saves it to Shraa.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Message text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = DataStore.container.mainContext
        let outcome = TxnIngest.ingestSMS(text, context: context)
        switch outcome {
        case .saved(let t):
            await NudgeScheduler.shared.afterTransaction(t, context: context)
            let verb = t.direction == .debit ? "spent at" : "from"
            return .result(dialog: "\(t.amount.rupees) \(verb) \(t.merchant) · \(t.category.label)")
        case .duplicate:
            return .result(dialog: "Already logged.")
        case .ignored:
            return .result(dialog: "Not a transaction, skipped.")
        case .sentToReview:
            return .result(dialog: "Couldn't read it. Saved to Review in Shraa.")
        }
    }
}

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Adds water to today's total.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Millilitres", default: 250)
    var ml: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = DataStore.container.mainContext
        let total = await HealthActions.logWater(ml, context: context)
        let goal = Prefs.waterGoalML
        let left = max(goal - total, 0)
        return .result(dialog: left == 0
                       ? "Logged. \(total) ml today. Goal done, hydrated legend."
                       : "Logged. \(total) ml today, \(left) ml to go.")
    }
}

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Quickly log a cash or manual expense.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "What for", default: "Cash")
    var merchant: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = DataStore.container.mainContext
        let rules = (try? context.fetch(FetchDescriptor<MerchantRule>())) ?? []
        let cat = Categorizer.category(for: merchant, direction: .debit, isBillPayment: false,
                                       rules: rules.map { ($0.keyword, SpendCategory(rawValue: $0.categoryRaw) ?? .other) })
        let txn = Txn(date: .now, amount: amount, direction: .debit, merchant: merchant,
                      category: cat, source: .manual)
        context.insert(txn)
        try? context.save()
        await NudgeScheduler.shared.afterTransaction(txn, context: context)
        return .result(dialog: "\(amount.rupees) on \(merchant) logged under \(cat.label).")
    }
}

struct GymCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Gym Check-in"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let streak = await HealthActions.checkInGym(context: DataStore.container.mainContext)
        return .result(dialog: "Checked in. Streak: \(streak) day\(streak == 1 ? "" : "s"). Now go lift something.")
    }
}

struct ShraaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogWaterIntent(),
                    phrases: ["Log water in \(.applicationName)", "I drank water \(.applicationName)"],
                    shortTitle: "Log Water", systemImageName: "drop.fill")
        AppShortcut(intent: AddExpenseIntent(),
                    phrases: ["Add expense in \(.applicationName)", "I spent money \(.applicationName)"],
                    shortTitle: "Add Expense", systemImageName: "indianrupeesign.circle")
        AppShortcut(intent: GymCheckInIntent(),
                    phrases: ["Gym check in \(.applicationName)", "I'm at the gym \(.applicationName)"],
                    shortTitle: "Gym Check-in", systemImageName: "dumbbell.fill")
        AppShortcut(intent: LogBankSMSIntent(),
                    phrases: ["Log bank SMS in \(.applicationName)"],
                    shortTitle: "Log Bank SMS", systemImageName: "message.badge")
    }
}
