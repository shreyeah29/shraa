import SwiftUI

enum SpendCategory: String, Codable, CaseIterable, Identifiable {
    case food, groceries, transport, fuel, shopping, bills, rent, subscriptions,
         entertainment, health, fitness, education, travel, family, investments,
         transfers, income, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food: return "Food & dining"
        case .groceries: return "Groceries"
        case .transport: return "Transport"
        case .fuel: return "Fuel"
        case .shopping: return "Shopping"
        case .bills: return "Bills & recharges"
        case .rent: return "Rent"
        case .subscriptions: return "Subscriptions"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .fitness: return "Fitness"
        case .education: return "Education"
        case .travel: return "Travel"
        case .family: return "Family & gifts"
        case .investments: return "Investments"
        case .transfers: return "Transfers"
        case .income: return "Income"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .groceries: return "cart"
        case .transport: return "car"
        case .fuel: return "fuelpump"
        case .shopping: return "bag"
        case .bills: return "bolt"
        case .rent: return "house"
        case .subscriptions: return "repeat"
        case .entertainment: return "popcorn"
        case .health: return "cross.case"
        case .fitness: return "dumbbell"
        case .education: return "graduationcap"
        case .travel: return "airplane"
        case .family: return "gift"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .transfers: return "arrow.left.arrow.right"
        case .income: return "arrow.down.circle"
        case .other: return "square.grid.2x2"
        }
    }

    var color: Color {
        switch self {
        case .food: return .orange
        case .groceries: return .green
        case .transport: return .blue
        case .fuel: return .brown
        case .shopping: return .pink
        case .bills: return .yellow
        case .rent: return .indigo
        case .subscriptions: return .purple
        case .entertainment: return .red
        case .health: return .mint
        case .fitness: return .teal
        case .education: return .cyan
        case .travel: return .blue.opacity(0.7)
        case .family: return .pink.opacity(0.7)
        case .investments: return .green.opacity(0.7)
        case .transfers: return .gray
        case .income: return .green
        case .other: return .secondary
        }
    }

    /// Categories you'd put a budget on.
    static var spendable: [SpendCategory] { allCases.filter { ![.transfers, .income].contains($0) } }
}
