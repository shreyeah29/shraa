import SwiftUI
import SwiftData

// MARK: - Main View

struct SkincareView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \SkincareProduct.order) private var products: [SkincareProduct]
    @Query(sort: \SkincareLog.date, order: .reverse) private var logs: [SkincareLog]

    @State private var selectedTime: SkincareTime = {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 14 ? .am : .pm
    }()
    @State private var showAddProduct = false
    @State private var showLogSheet = false
    @State private var todayLogDone = false

    private var todayLogs: [SkincareLog] {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return logs.filter { $0.date >= start && $0.date < end && $0.time == selectedTime }
    }

    private var activeProducts: [SkincareProduct] {
        products.filter { $0.isActive && ($0.time == selectedTime || $0.time == .both) }
    }

    private var latestLog: SkincareLog? { todayLogs.first }

    private var streakDays: Int {
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: .now)
        while true {
            let end = Calendar.current.date(byAdding: .day, value: 1, to: checkDate)!
            let hasLog = logs.contains { $0.date >= checkDate && $0.date < end }
            if hasLog { streak += 1 }
            else { break }
            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timePicker
                    if streakDays > 0 { streakBanner }
                    routineCard
                    skinHistoryCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.surfaceBase)
            .navigationTitle("Skincare")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showAddProduct = true } label: {
                            Label("Add Product", systemImage: "plus")
                        }
                        Button { showLogSheet = true } label: {
                            Label("Log Routine", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddProduct) {
                AddSkincareProductSheet()
            }
            .sheet(isPresented: $showLogSheet) {
                SkincareLogSheet(time: selectedTime, products: activeProducts)
            }
        }
    }

    // MARK: Time picker

    private var timePicker: some View {
        HStack(spacing: 0) {
            ForEach([SkincareTime.am, .pm], id: \.id) { t in
                SkincareTimeButton(time: t, isSelected: selectedTime == t) {
                    withAnimation(.spring(response: 0.3)) { selectedTime = t }
                }
            }
        }
        .background(Color.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    // MARK: Streak

    private var streakBanner: some View {
        Card {
            HStack(spacing: 14) {
                Text("🔥")
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streakDays)-day streak!")
                        .font(.headline)
                    Text("Your skin is loving the consistency.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: Routine card

    private var routineCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(selectedTime.label) Routine")
                        .font(.headline)
                    Spacer()
                    if let log = latestLog {
                        Text("\(log.completedProductNames.count)/\(activeProducts.count) done")
                            .font(.caption)
                            .foregroundStyle(Color.brandCoral)
                    } else {
                        Button {
                            showLogSheet = true
                        } label: {
                            Text("Start Routine")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(LinearGradient.brand)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }

                if activeProducts.isEmpty {
                    HStack {
                        Text("No products for \(selectedTime.label) yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showAddProduct = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.brandCoral)
                        }
                    }
                } else {
                    ForEach(activeProducts) { product in
                        let done = latestLog?.completedProductNames.contains(product.name) ?? false
                        ProductRow(product: product, isDone: done) {
                            ctx.delete(product)
                        }
                    }
                }
            }
        }
    }

    // MARK: Skin history

    private var skinHistoryCard: some View {
        Group {
            if !logs.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Skin Journal")
                            .font(.headline)

                        ForEach(logs.prefix(5)) { log in
                            HStack(alignment: .top, spacing: 12) {
                                skinRatingCircle(log.skinRating)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(log.time.label)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(log.time == .am ? Color.brandAmber : Color.indigo)
                                        Text(log.date, style: .date)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !log.concerns.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(log.concerns, id: \.self) { c in
                                                Text(c)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color.brandCoral.opacity(0.12))
                                                    .foregroundStyle(Color.brandCoral)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    if !log.note.isEmpty {
                                        Text(log.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            if log.id != logs.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func skinRatingCircle(_ rating: Int) -> some View {
        ZStack {
            Circle()
                .fill(ratingColor(rating).opacity(0.15))
                .frame(width: 36, height: 36)
            Text(ratingEmoji(rating))
                .font(.system(size: 18))
        }
    }

    private func ratingColor(_ r: Int) -> Color {
        switch r {
        case 1: return .red
        case 2: return .orange
        case 3: return .brandAmber
        case 4: return Color(red: 0.4, green: 0.8, blue: 0.5)
        default: return .brandCoral
        }
    }

    private func ratingEmoji(_ r: Int) -> String {
        switch r {
        case 1: return "😞"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "😊"
        default: return "✨"
        }
    }
}

// MARK: - Time Button

private struct SkincareTimeButton: View {
    let time: SkincareTime
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: time == .am ? "sun.max.fill" : "moon.stars.fill")
                Text(time.label).fontWeight(.semibold)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? AnyView(LinearGradient.brand) : AnyView(Color.clear))
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Product Row

private struct ProductRow: View {
    let product: SkincareProduct
    let isDone: Bool
    let onDelete: () -> Void
    @State private var showDelete = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.brandCoral.opacity(0.15) : Color.surface)
                    .frame(width: 36, height: 36)
                Image(systemName: isDone ? "checkmark" : product.step.icon)
                    .imageScale(.small)
                    .foregroundStyle(isDone ? Color.brandCoral : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline)
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone)
                HStack(spacing: 4) {
                    Text(product.step.label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if !product.brand.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(product.brand)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .onLongPressGesture { showDelete = true }
        .confirmationDialog("Remove product?", isPresented: $showDelete) {
            Button("Remove", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Add Product Sheet

struct AddSkincareProductSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var step: SkincareStep = .cleanser
    @State private var time: SkincareTime = .am

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Product name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }
                Section("Step") {
                    Picker("Step", selection: $step) {
                        ForEach(SkincareStep.allCases) { s in
                            Label(s.label, systemImage: s.icon).tag(s)
                        }
                    }
                }
                Section("Routine") {
                    Picker("Use in", selection: $time) {
                        ForEach(SkincareTime.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceBase)
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let p = SkincareProduct(name: name, brand: brand, step: step, time: time)
                        ctx.insert(p)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Log Sheet

struct SkincareLogSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let time: SkincareTime
    let products: [SkincareProduct]

    @State private var completed: Set<String> = []
    @State private var rating = 3
    @State private var concerns: Set<String> = []
    @State private var note = ""

    private let allConcerns = ["Oily", "Dry", "Breakout", "Redness", "Dull", "Glowing"]

    var body: some View {
        NavigationStack {
            Form {
                if !products.isEmpty {
                    Section("Products Used") {
                        ForEach(products) { product in
                            Button {
                                if completed.contains(product.name) {
                                    completed.remove(product.name)
                                } else {
                                    completed.insert(product.name)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: completed.contains(product.name) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(completed.contains(product.name) ? Color.brandCoral : .secondary)
                                    Text(product.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(product.step.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("How's your skin today?") {
                    HStack {
                        ForEach(1...5, id: \.self) { r in
                            Button {
                                rating = r
                            } label: {
                                Text(emojiForRating(r))
                                    .font(.system(size: 32))
                                    .opacity(rating == r ? 1 : 0.35)
                                    .scaleEffect(rating == r ? 1.2 : 1)
                                    .animation(.spring(response: 0.25), value: rating)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Skin Concerns") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(allConcerns, id: \.self) { concern in
                            Button {
                                if concerns.contains(concern) {
                                    concerns.remove(concern)
                                } else {
                                    concerns.insert(concern)
                                }
                            } label: {
                                Text(concern)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(concerns.contains(concern) ? Color.brandCoral.opacity(0.15) : Color.surface)
                                    .foregroundStyle(concerns.contains(concern) ? Color.brandCoral : Color.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(concerns.contains(concern) ? Color.brandCoral.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Note") {
                    TextField("Any observations…", text: $note, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceBase)
            .navigationTitle("Log \(time.label) Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let log = SkincareLog(
                            time: time,
                            completedProductNames: Array(completed),
                            skinRating: rating,
                            concerns: Array(concerns).sorted(),
                            note: note
                        )
                        ctx.insert(log)
                        dismiss()
                    }
                }
            }
        }
    }

    private func emojiForRating(_ r: Int) -> String {
        ["😞", "😕", "😐", "😊", "✨"][r - 1]
    }
}
