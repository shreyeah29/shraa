import SwiftUI
import SwiftData

// MARK: - Open Food Facts

struct OFFProduct: Decodable {
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
    }
}

struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let energyKj100g: Double?   // fallback: many products only store kJ
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKj100g = "energy_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
    var kcalPer100g: Double {
        if let kcal = energyKcal100g, kcal > 0 { return kcal }
        if let kj = energyKj100g, kj > 0 { return kj / 4.184 }
        return 0
    }
}

struct OFFResponse: Decodable {
    let products: [OFFProduct]
}

struct FoodSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let caloriesPer100g: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

@MainActor
class FoodSearchVM: ObservableObject {
    @Published var query = ""
    @Published var results: [FoodSearchResult] = []
    @Published var isLoading = false
    @Published var error: String?

    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        error = nil
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&json=1&action=process&page_size=20"
        guard let url = URL(string: urlString) else { isLoading = false; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
            results = decoded.products.compactMap { p in
                guard let name = p.productName, !name.isEmpty else { return nil }
                let n = p.nutriments
                return FoodSearchResult(
                    name: name,
                    brand: p.brands ?? "",
                    caloriesPer100g: n?.kcalPer100g ?? 0,
                    protein: n?.proteins100g ?? 0,
                    carbs: n?.carbohydrates100g ?? 0,
                    fat: n?.fat100g ?? 0
                )
            }
        } catch {
            self.error = "Couldn't load results"
        }
        isLoading = false
    }
}

// MARK: - Main View

struct NutritionView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var showAdd = false
    @State private var addingMeal: MealKind = .breakfast
    @AppStorage("calorieGoal") private var calorieGoal: Double = 2000

    private var todayEntries: [FoodEntry] {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        return allEntries.filter { $0.date >= selectedDate && $0.date < end }
    }

    private var totalCal: Double { todayEntries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { todayEntries.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { todayEntries.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { todayEntries.reduce(0) { $0 + $1.fat } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    calorieSummaryCard
                    macroRow
                    mealsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.surfaceBase)
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .sheet(isPresented: $showAdd) {
                FoodSearchSheet(meal: addingMeal, date: selectedDate)
            }
        }
    }

    // MARK: Calorie card

    private var calorieSummaryCard: some View {
        Card {
            VStack(spacing: 12) {
                HStack {
                    Text("Today's Calories")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        let newGoal = calorieGoal == 2000 ? 1800.0 : (calorieGoal == 1800 ? 2200.0 : 2000.0)
                        calorieGoal = newGoal
                    } label: {
                        Text("Goal: \(Int(calorieGoal)) kcal")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.brandCoral.opacity(0.15))
                            .foregroundStyle(Color.brandCoral)
                            .clipShape(Capsule())
                    }
                }

                ZStack {
                    Circle()
                        .stroke(Color.surface, lineWidth: 14)
                        .frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: min(totalCal / calorieGoal, 1))
                        .stroke(
                            LinearGradient.brand,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 140, height: 140)
                        .animation(.spring(response: 0.6), value: totalCal)

                    VStack(spacing: 2) {
                        Text("\(Int(totalCal))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient.brand)
                        Text("kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(max(calorieGoal - totalCal, 0))) left")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Macros

    private var macroRow: some View {
        HStack(spacing: 12) {
            MacroChip(label: "Protein", value: totalProtein, color: .brandCoral, unit: "g")
            MacroChip(label: "Carbs", value: totalCarbs, color: .brandAmber, unit: "g")
            MacroChip(label: "Fat", value: totalFat, color: Color.indigo, unit: "g")
        }
    }

    // MARK: Meals

    private var mealsSection: some View {
        VStack(spacing: 12) {
            ForEach(MealKind.allCases) { meal in
                let entries = todayEntries.filter { $0.mealKind == meal }
                MealCard(meal: meal, entries: entries) {
                    addingMeal = meal
                    showAdd = true
                } onDelete: { entry in
                    ctx.delete(entry)
                }
            }
        }
    }
}

// MARK: - Macro Chip

private struct MacroChip: View {
    let label: String
    let value: Double
    let color: Color
    let unit: String

    var body: some View {
        Card {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Meal Card

private struct MealCard: View {
    let meal: MealKind
    let entries: [FoodEntry]
    let onAdd: () -> Void
    let onDelete: (FoodEntry) -> Void

    private var total: Double { entries.reduce(0) { $0 + $1.calories } }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(meal.label)
                        .font(.headline)
                    Spacer()
                    if total > 0 {
                        Text("\(Int(total)) kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.brandCoral)
                            .imageScale(.large)
                    }
                }

                if entries.isEmpty {
                    Text("Nothing logged yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.subheadline)
                                if !entry.brand.isEmpty {
                                    Text(entry.brand)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Text("\(Int(entry.calories)) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                onDelete(entry)
                            } label: {
                                Image(systemName: "xmark")
                                    .imageScale(.small)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

// MARK: - Food Search Sheet

struct FoodSearchSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let meal: MealKind
    let date: Date

    @StateObject private var vm = FoodSearchVM()
    @State private var selectedFood: FoodSearchResult?
    @State private var servingG: Double = 100
    @State private var showManual = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding()

                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let selected = selectedFood {
                    addFoodForm(selected)
                } else {
                    resultsList
                }
            }
            .background(Color.surfaceBase)
            .navigationTitle("\(meal.label) — Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manual") { showManual = true }
                        .foregroundStyle(Color.brandAmber)
                }
            }
            .sheet(isPresented: $showManual) {
                ManualFoodEntry(meal: meal, date: date)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search food (e.g. banana, rice)", text: $vm.query)
                .submitLabel(.search)
                .onSubmit {
                    Task { await vm.search() }
                }
            if !vm.query.isEmpty {
                Button { vm.query = ""; vm.results = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var resultsList: some View {
        List(vm.results) { item in
            Button {
                selectedFood = item
                servingG = 100
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    HStack {
                        Text(item.brand.isEmpty ? "Generic" : item.brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(item.caloriesPer100g)) kcal/100g")
                            .font(.caption)
                            .foregroundStyle(Color.brandCoral)
                    }
                }
            }
            .listRowBackground(Color.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func addFoodForm(_ food: FoodSearchResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(food.name)
                            .font(.headline)
                        if !food.brand.isEmpty {
                            Text(food.brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Card {
                    VStack(spacing: 16) {
                        // Serving presets
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How much?")
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 8) {
                                ForEach([50.0, 100.0, 150.0, 200.0, 250.0], id: \.self) { g in
                                    Button {
                                        servingG = g
                                    } label: {
                                        Text("\(Int(g))g")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(servingG == g ? Color.brandCoral : Color.surface)
                                            .foregroundStyle(servingG == g ? Color.white : Color.secondary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Stepper
                        HStack {
                            Button {
                                servingG = max(10, servingG - 10)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.brandCoral)
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Text("\(Int(servingG)) g")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.brandCoral)
                                Text("serving size")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                servingG = servingG + 10
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.brandCoral)
                            }
                        }
                        .padding(.vertical, 4)

                        Divider()

                        let multiplier = servingG / 100.0
                        Group {
                            macroRow2("🔥 Calories", value: food.caloriesPer100g * multiplier, color: Color.brandCoral)
                            macroRow2("💪 Protein", value: food.protein * multiplier, color: Color.brandAmber)
                            macroRow2("🌾 Carbs", value: food.carbs * multiplier, color: Color.indigo)
                            macroRow2("🥑 Fat", value: food.fat * multiplier, color: Color.secondary)
                        }
                    }
                }

                Button {
                    let multiplier = servingG / 100.0
                    let entry = FoodEntry(
                        name: food.name,
                        brand: food.brand,
                        calories: food.caloriesPer100g * multiplier,
                        protein: food.protein * multiplier,
                        carbs: food.carbs * multiplier,
                        fat: food.fat * multiplier,
                        servingG: servingG,
                        mealKind: meal,
                        date: date
                    )
                    ctx.insert(entry)
                    dismiss()
                } label: {
                    Text("Add to \(meal.label)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient.brand)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button { selectedFood = nil } label: {
                    Text("Back to results")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    private func macroRow2(_ label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(String(format: "%.1f", value))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Manual Entry

struct ManualFoodEntry: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let meal: MealKind
    let date: Date

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Food name") {
                    TextField("e.g. Homemade dal rice", text: $name)
                }
                Section("Nutrition") {
                    HStack {
                        Text("Calories (kcal)")
                        Spacer()
                        TextField("0", text: $calories).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $protein).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbs).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fat).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceBase)
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        let entry = FoodEntry(
                            name: name,
                            calories: Double(calories) ?? 0,
                            protein: Double(protein) ?? 0,
                            carbs: Double(carbs) ?? 0,
                            fat: Double(fat) ?? 0,
                            mealKind: meal,
                            date: date
                        )
                        ctx.insert(entry)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
