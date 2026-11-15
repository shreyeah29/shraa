import SwiftUI

// MARK: - Design tokens

extension Color {
    // Brand gradient stops – coral → warm amber
    static let brandCoral  = Color(red: 1.00, green: 0.38, blue: 0.28)
    static let brandAmber  = Color(red: 1.00, green: 0.62, blue: 0.20)
    // Surfaces
    static let surface     = Color(.secondarySystemGroupedBackground)
    static let surfaceBase = Color(.systemGroupedBackground)
}

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.brandCoral, .brandAmber],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let greenGrad = LinearGradient(
        colors: [Color(hue: 0.37, saturation: 0.65, brightness: 0.70),
                 Color(hue: 0.42, saturation: 0.55, brightness: 0.60)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Card (white surface, shadow, optional coloured icon chip)

struct Card<Content: View>: View {
    var title: String? = nil
    var icon: String?  = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.brandCoral)
                            .padding(6)
                            .background(Color.brandCoral.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 8))
                    }
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.055), radius: 12, x: 0, y: 3)
    }
}

// MARK: - HeroCard (gradient background, used as page header)

struct HeroCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient.brand,
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Color.brandCoral.opacity(0.38), radius: 18, x: 0, y: 6)
    }
}

// MARK: - ProgressRing (angular gradient stroke)

struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.13), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: color.opacity(0.65), location: 0),
                            .init(color: color,               location: 1)]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.75, dampingFraction: 0.7), value: progress)
        }
    }
}

// MARK: - RingStat

struct RingStat: View {
    var value: String
    var label: String
    var progress: Double
    var color: Color
    var icon: String

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                ProgressRing(progress: progress, color: color, lineWidth: 7)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 72, height: 72)

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - BudgetBar (gradient fill, animated)

struct BudgetBar: View {
    var spent: Double
    var limit: Double
    var color: Color = .accentColor

    private var fraction: Double { limit > 0 ? min(spent / limit, 1) : 0 }
    private var fillColors: [Color] {
        fraction >= 1   ? [.red,    Color(red: 1, green: 0.25, blue: 0.25)] :
        fraction >= 0.8 ? [.orange, Color(red: 1, green: 0.78, blue: 0)]   :
                           [color,   color.opacity(0.6)]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(LinearGradient(colors: fillColors,
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * fraction)
                    .animation(.spring(response: 0.55, dampingFraction: 0.75), value: fraction)
            }
        }
        .frame(height: 7)
    }
}

// MARK: - StreakBadge

struct StreakBadge: View {
    var count: Int
    var label: String

    var body: some View {
        HStack(spacing: 4) {
            Text("🔥").font(.caption)
            Text("\(count)")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(Color.orange.opacity(0.09), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.orange.opacity(0.22), lineWidth: 1))
    }
}

// MARK: - TxnRow

struct TxnRow: View {
    let txn: Txn

    var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(txn.category.color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: txn.category.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(txn.category.color)
            }

            // Description
            VStack(alignment: .leading, spacing: 3) {
                Text(txn.merchant)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text([txn.category.label,
                      txn.bank.isEmpty ? nil : txn.bank,
                      txn.accountLast4.isEmpty ? nil : "••\(txn.accountLast4)"]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 3) {
                Text((txn.direction == .debit ? "−" : "+") + txn.amount.rupees)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(txn.isTransfer ? AnyShapeStyle(.secondary) :
                                     txn.direction == .debit ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.green))
                    .monospacedDigit()
                Text(txn.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }
}
