import Foundation
import SwiftData

// MARK: - Money

enum AccountKind: String, Codable, CaseIterable, Identifiable {
    case bank, creditCard, debitCard, cash, wallet
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bank: return "Bank account"
        case .creditCard: return "Credit card"
        case .debitCard: return "Debit card"
        case .cash: return "Cash"
        case .wallet: return "Wallet"
        }
    }
    var icon: String {
        switch self {
        case .bank: return "building.columns"
        case .creditCard: return "creditcard"
        case .debitCard: return "creditcard.and.123"
        case .cash: return "banknote"
        case .wallet: return "wallet.pass"
        }
    }
}

@Model
final class Account {
    var name: String
    var bank: String
    var last4: String
    var kindRaw: String
    var creditLimit: Double?
    var statementDay: Int?
    var dueDay: Int?
    var createdAt: Date

    var kind: AccountKind {
        get { AccountKind(rawValue: kindRaw) ?? .bank }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, bank: String, last4: String, kind: AccountKind,
         creditLimit: Double? = nil, statementDay: Int? = nil, dueDay: Int? = nil) {
        self.name = name
        self.bank = bank
        self.last4 = last4
        self.kindRaw = kind.rawValue
        self.creditLimit = creditLimit
        self.statementDay = statementDay
        self.dueDay = dueDay
        self.createdAt = .now
    }
}

enum TxnDirection: String, Codable { case debit, credit }
enum TxnSource: String, Codable { case sms, manual, statement }

@Model
final class Txn {
    var date: Date
    var amount: Double
    var directionRaw: String
    var merchant: String
    var categoryRaw: String
    var bank: String
    var accountLast4: String
    var isCard: Bool
    var upiRef: String?
    var sourceRaw: String
    var rawText: String?
    var note: String
    /// Credit card bill payments, self transfers: not counted as spending or income.
    var isTransfer: Bool
    var createdAt: Date

    var direction: TxnDirection {
        get { TxnDirection(rawValue: directionRaw) ?? .debit }
        set { directionRaw = newValue.rawValue }
    }
    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    var source: TxnSource { TxnSource(rawValue: sourceRaw) ?? .manual }
    var isExpense: Bool { direction == .debit && !isTransfer }
    var isIncome: Bool { direction == .credit && !isTransfer }

    init(date: Date, amount: Double, direction: TxnDirection, merchant: String,
         category: SpendCategory, bank: String = "", accountLast4: String = "",
         isCard: Bool = false, upiRef: String? = nil, source: TxnSource,
         rawText: String? = nil, note: String = "", isTransfer: Bool = false) {
        self.date = date
        self.amount = amount
        self.directionRaw = direction.rawValue
        self.merchant = merchant
        self.categoryRaw = category.rawValue
        self.bank = bank
        self.accountLast4 = accountLast4
        self.isCard = isCard
        self.upiRef = upiRef
        self.sourceRaw = source.rawValue
        self.rawText = rawText
        self.note = note
        self.isTransfer = isTransfer
        self.createdAt = .now
    }
}

@Model
final class Budget {
    var categoryRaw: String
    var monthlyLimit: Double
    var category: SpendCategory { SpendCategory(rawValue: categoryRaw) ?? .other }
    init(category: SpendCategory, monthlyLimit: Double) {
        self.categoryRaw = category.rawValue
        self.monthlyLimit = monthlyLimit
    }
}

/// Learned from your corrections: a merchant keyword maps to a category.
@Model
final class MerchantRule {
    var keyword: String
    var categoryRaw: String
    init(keyword: String, category: SpendCategory) {
        self.keyword = keyword.lowercased()
        self.categoryRaw = category.rawValue
    }
}

/// Bank SMS the parser couldn't read. Shown in the Review inbox.
@Model
final class UnparsedSMS {
    var text: String
    var receivedAt: Date
    init(text: String, receivedAt: Date = .now) {
        self.text = text
        self.receivedAt = receivedAt
    }
}

// MARK: - Work & Growth

enum TaskArea: String, Codable, CaseIterable, Identifiable {
    case work, learn, life
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .work: return "briefcase"
        case .learn: return "book"
        case .life: return "house"
        }
    }
}

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case lead, active, delivered, invoiced, paid, idea
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var isMoneyPending: Bool { [.lead, .active, .delivered, .invoiced].contains(self) }
}

@Model
final class Project {
    var name: String
    var client: String
    var agreedAmount: Double
    var receivedAmount: Double
    var statusRaw: String
    var deadline: Date?
    var expectedPaymentDate: Date?
    var notes: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.project) var tasks: [TaskItem] = []

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    var pendingAmount: Double { max(agreedAmount - receivedAmount, 0) }

    init(name: String, client: String = "", agreedAmount: Double = 0, status: ProjectStatus = .active,
         deadline: Date? = nil, expectedPaymentDate: Date? = nil, notes: String = "") {
        self.name = name
        self.client = client
        self.agreedAmount = agreedAmount
        self.receivedAmount = 0
        self.statusRaw = status.rawValue
        self.deadline = deadline
        self.expectedPaymentDate = expectedPaymentDate
        self.notes = notes
        self.createdAt = .now
    }
}

@Model
final class TaskItem {
    var title: String
    var notes: String
    var due: Date?
    var priority: Int   // 0 low, 1 normal, 2 high
    var areaRaw: String
    var isDone: Bool
    var doneAt: Date?
    var createdAt: Date
    var project: Project?

    var area: TaskArea {
        get { TaskArea(rawValue: areaRaw) ?? .life }
        set { areaRaw = newValue.rawValue }
    }

    init(title: String, notes: String = "", due: Date? = nil, priority: Int = 1,
         area: TaskArea = .life, project: Project? = nil) {
        self.title = title
        self.notes = notes
        self.due = due
        self.priority = priority
        self.areaRaw = area.rawValue
        self.isDone = false
        self.createdAt = .now
        self.project = project
    }
}

// MARK: - Health

@Model
final class WaterLog {
    var date: Date
    var ml: Int
    init(ml: Int, date: Date = .now) { self.ml = ml; self.date = date }
}

@Model
final class GymLog {
    var date: Date
    var workout: String
    init(workout: String = "Gym", date: Date = .now) { self.workout = workout; self.date = date }
}

enum MealKind: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

@Model
final class MealLog {
    var date: Date
    var kindRaw: String
    var skipped: Bool
    var outside: Bool
    var kind: MealKind { MealKind(rawValue: kindRaw) ?? .snack }
    init(kind: MealKind, skipped: Bool = false, outside: Bool = false, date: Date = .now) {
        self.kindRaw = kind.rawValue
        self.skipped = skipped
        self.outside = outside
        self.date = date
    }
}

// MARK: - Shared container

enum DataStore {
    static let schema = Schema([
        Account.self, Txn.self, Budget.self, MerchantRule.self, UnparsedSMS.self,
        Project.self, TaskItem.self, WaterLog.self, GymLog.self, MealLog.self
    ])

    /// One container for the app, App Intents and background tasks.
    static let container: ModelContainer = {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not open Shraa database: \(error)")
        }
    }()
}
