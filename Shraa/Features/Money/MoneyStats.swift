import Foundation
import SwiftData

/// Numbers the Money and Today screens (and nudges) need.
struct CategoryAmount: Identifiable {
    let category: SpendCategory
    let amount: Double
    var id: SpendCategory { category }
}

struct MoneyStats {
    let txns: [Txn]          // this month's transactions
    let budgets: [Budget]
    let monthlyBudget: Double
    let now: Date

    init(context: ModelContext, now: Date = .now) {
        let start = now.startOfMonth
        self.txns = (try? context.fetch(FetchDescriptor<Txn>(predicate: #Predicate { $0.date >= start }))) ?? []
        self.budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        self.monthlyBudget = Prefs.monthlyBudget
        self.now = now
    }

    init(txns: [Txn], budgets: [Budget], now: Date = .now) {
        let start = now.startOfMonth
        self.txns = txns.filter { $0.date >= start }
        self.budgets = budgets
        self.monthlyBudget = Prefs.monthlyBudget
        self.now = now
    }

    var spent: Double { txns.filter(\.isExpense).reduce(0) { $0 + $1.amount } }
    var income: Double { txns.filter(\.isIncome).reduce(0) { $0 + $1.amount } }
    var spentToday: Double {
        let start = now.startOfDay
        return txns.filter { $0.isExpense && $0.date >= start }.reduce(0) { $0 + $1.amount }
    }

    func spent(in category: SpendCategory) -> Double {
        txns.filter { $0.isExpense && $0.category == category }.reduce(0) { $0 + $1.amount }
    }

    var byCategory: [CategoryAmount] {
        var map: [SpendCategory: Double] = [:]
        for t in txns where t.isExpense { map[t.category, default: 0] += t.amount }
        return map.map { CategoryAmount(category: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    /// What you can spend per day for the rest of the month and stay within the monthly budget.
    var safeToSpendPerDay: Double {
        let left = monthlyBudget - spent + spentToday
        return max(left, 0) / Double(max(now.daysLeftInMonth, 1))
    }

    var budgetLeft: Double { monthlyBudget - spent }
}
