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

// MARK: - Nutrition

@Model
final class FoodEntry {
    var date: Date
    var mealKindRaw: String
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingG: Double
    var brand: String

    var mealKind: MealKind { MealKind(rawValue: mealKindRaw) ?? .snack }

    init(name: String, brand: String = "", calories: Double, protein: Double = 0,
         carbs: Double = 0, fat: Double = 0, servingG: Double = 100,
         mealKind: MealKind, date: Date = .now) {
        self.name = name
        self.brand = brand
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingG = servingG
        self.mealKindRaw = mealKind.rawValue
        self.date = date
    }
}

// MARK: - Gym PRs

@Model
final class PRLog {
    var date: Date
    var exercise: String
    var weightKg: Double
    var reps: Int
    var sets: Int
    var notes: String

    var oneRepMax: Double { weightKg * (1 + Double(reps) / 30.0) }

    init(exercise: String, weightKg: Double, reps: Int, sets: Int = 3,
         notes: String = "", date: Date = .now) {
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
        self.sets = sets
        self.notes = notes
        self.date = date
    }
}

// MARK: - Progress Photos

enum ProgressPhotoCategory: String, Codable, CaseIterable, Identifiable {
    case gym, skin
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String { self == .gym ? "dumbbell.fill" : "face.smiling" }
}

@Model
final class ProgressPhoto {
    var date: Date
    var categoryRaw: String
    var imageData: Data
    var note: String

    var category: ProgressPhotoCategory { ProgressPhotoCategory(rawValue: categoryRaw) ?? .gym }

    init(imageData: Data, category: ProgressPhotoCategory, note: String = "", date: Date = .now) {
        self.imageData = imageData
        self.categoryRaw = category.rawValue
        self.note = note
        self.date = date
    }
}

// MARK: - Skincare

enum SkincareStep: String, Codable, CaseIterable, Identifiable {
    case cleanser, toner, serum, moisturiser, sunscreen, eyeCream, retinol, treatment, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cleanser: return "Cleanser"
        case .toner: return "Toner"
        case .serum: return "Serum"
        case .moisturiser: return "Moisturiser"
        case .sunscreen: return "Sunscreen"
        case .eyeCream: return "Eye Cream"
        case .retinol: return "Retinol"
        case .treatment: return "Treatment"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .cleanser: return "drop.fill"
        case .toner: return "sparkles"
        case .serum: return "testtube.2"
        case .moisturiser: return "cloud.fill"
        case .sunscreen: return "sun.max.fill"
        case .eyeCream: return "eye.fill"
        case .retinol: return "moon.stars.fill"
        case .treatment: return "cross.case.fill"
        case .other: return "circle.fill"
        }
    }
}

enum SkincareTime: String, Codable, CaseIterable, Identifiable {
    case am, pm, both
    var id: String { rawValue }
    var label: String { self == .am ? "Morning" : self == .pm ? "Night" : "AM + PM" }
}

@Model
final class SkincareProduct {
    var name: String
    var brand: String
    var stepRaw: String
    var timeRaw: String
    var isActive: Bool
    var order: Int

    var step: SkincareStep { SkincareStep(rawValue: stepRaw) ?? .other }
    var time: SkincareTime { SkincareTime(rawValue: timeRaw) ?? .am }

    init(name: String, brand: String = "", step: SkincareStep,
         time: SkincareTime = .am, order: Int = 0) {
        self.name = name
        self.brand = brand
        self.stepRaw = step.rawValue
        self.timeRaw = time.rawValue
        self.isActive = true
        self.order = order
    }
}

@Model
final class SkincareLog {
    var date: Date
    var timeRaw: String
    var completedProductNames: [String]
    var skinRating: Int      // 1–5
    var concerns: [String]   // oily, dry, breakout, redness, dull
    var note: String

    var time: SkincareTime { SkincareTime(rawValue: timeRaw) ?? .am }

    init(time: SkincareTime, completedProductNames: [String] = [],
         skinRating: Int = 3, concerns: [String] = [], note: String = "", date: Date = .now) {
        self.timeRaw = time.rawValue
        self.completedProductNames = completedProductNames
        self.skinRating = skinRating
        self.concerns = concerns
        self.note = note
        self.date = date
    }
}

// MARK: - Shared container

enum DataStore {
    static let schema = Schema([
        Account.self, Txn.self, Budget.self, MerchantRule.self, UnparsedSMS.self,
        Project.self, TaskItem.self, WaterLog.self, GymLog.self, MealLog.self,
        FoodEntry.self, PRLog.self, ProgressPhoto.self,
        SkincareProduct.self, SkincareLog.self
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
