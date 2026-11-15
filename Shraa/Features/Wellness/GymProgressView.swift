import SwiftUI
import SwiftData

// MARK: - Main View

struct GymProgressView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \PRLog.date, order: .reverse) private var allPRs: [PRLog]
    @State private var showAdd = false
    @State private var selectedExercise: String?

    private var exercises: [String] {
        Array(Set(allPRs.map(\.exercise))).sorted()
    }

    private var latestPRs: [String: PRLog] {
        Dictionary(grouping: allPRs, by: \.exercise)
            .compactMapValues { $0.first }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if allPRs.isEmpty {
                        emptyState
                    } else {
                        progressionHero
                        exerciseGrid
                        if let ex = selectedExercise {
                            exerciseHistory(for: ex)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.surfaceBase)
            .navigationTitle("Gym PRs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddPRSheet()
            }
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient.brand)
                .padding(.top, 60)
            Text("Log your first PR!")
                .font(.title2.bold())
            Text("Track how much you lift and we'll suggest your next target.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showAdd = true
            } label: {
                Label("Log a PR", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LinearGradient.brand)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: Hero — most recent PR

    private var progressionHero: some View {
        Group {
            if let first = allPRs.first {
                Card {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.brand)
                                .frame(width: 56, height: 56)
                            Image(systemName: "dumbbell.fill")
                                .foregroundStyle(.white)
                                .imageScale(.large)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latest PR")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(first.exercise)
                                .font(.headline)
                            Text("\(String(format: "%.1f", first.weightKg)) kg × \(first.reps) reps × \(first.sets) sets")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("1RM")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(String(format: "%.1f", first.oneRepMax)) kg")
                                .font(.title3.bold())
                                .foregroundStyle(Color.brandCoral)
                        }
                    }
                }
            }
        }
    }

    // MARK: Exercise grid

    private var exerciseGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(exercises, id: \.self) { ex in
                if let latest = latestPRs[ex] {
                    ExerciseCard(pr: latest, isSelected: selectedExercise == ex) {
                        withAnimation(.spring(response: 0.35)) {
                            selectedExercise = selectedExercise == ex ? nil : ex
                        }
                    }
                }
            }
        }
    }

    // MARK: Exercise history

    private func exerciseHistory(for exercise: String) -> some View {
        let entries = allPRs.filter { $0.exercise == exercise }
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(exercise)
                        .font(.headline)
                    Spacer()
                    Text("History")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Suggestion banner
                if let latest = entries.first {
                    suggestionBanner(for: latest)
                }

                // History list
                ForEach(entries.prefix(8)) { pr in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(String(format: "%.1f", pr.weightKg)) kg × \(pr.reps)r × \(pr.sets)s")
                                .font(.subheadline.weight(.medium))
                            Text(pr.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("1RM: \(String(format: "%.1f", pr.oneRepMax))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            ctx.delete(pr)
                        } label: {
                            Image(systemName: "trash")
                                .imageScale(.small)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                    if pr.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func suggestionBanner(for pr: PRLog) -> some View {
        let nextWeight = pr.weightKg + 2.5
        let nextReps = min(pr.reps + 1, 12)
        return HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(Color.brandAmber)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 2) {
                Text("Next session target")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(String(format: "%.1f", nextWeight)) kg × \(nextReps) reps — progressive overload")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(10)
        .background(Color.brandAmber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Exercise Card

private struct ExerciseCard: View {
    let pr: PRLog
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pr.exercise)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    if isSelected {
                        Image(systemName: "chevron.up")
                            .imageScale(.small)
                            .foregroundStyle(Color.brandCoral)
                    }
                }
                Text("\(String(format: "%.1f", pr.weightKg)) kg")
                    .font(.title2.bold())
                    .foregroundStyle(isSelected ? Color.brandCoral : .primary)
                Text("\(pr.reps) reps × \(pr.sets) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(isSelected ? Color.brandCoral.opacity(0.08) : Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.brandCoral.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add PR Sheet

struct AddPRSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var exercise = ""
    @State private var weightKg = ""
    @State private var reps = "8"
    @State private var sets = "3"
    @State private var notes = ""
    @State private var date = Date.now

    private let commonExercises = [
        "Bench Press", "Squat", "Deadlift", "Overhead Press",
        "Barbell Row", "Pull-up", "Dumbbell Curl", "Lat Pulldown",
        "Leg Press", "Romanian Deadlift", "Hip Thrust", "Cable Fly"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("e.g. Bench Press", text: $exercise)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonExercises, id: \.self) { ex in
                                Button {
                                    exercise = ex
                                } label: {
                                    Text(ex)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(exercise == ex ? Color.brandCoral : Color.surface)
                                        .foregroundStyle(exercise == ex ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Weight & Volume") {
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("0", text: $weightKg)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("8", text: $reps)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Sets")
                        Spacer()
                        TextField("3", text: $sets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceBase)
            .navigationTitle("Log PR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let pr = PRLog(
                            exercise: exercise,
                            weightKg: Double(weightKg) ?? 0,
                            reps: Int(reps) ?? 8,
                            sets: Int(sets) ?? 3,
                            notes: notes,
                            date: date
                        )
                        ctx.insert(pr)
                        dismiss()
                    }
                    .disabled(exercise.isEmpty || (Double(weightKg) ?? 0) == 0)
                }
            }
        }
    }
}
