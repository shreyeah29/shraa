import SwiftUI
import SwiftData
import Charts

struct MoneyView: View {
    @Environment(\.modelContext) private var context
    @Query private var monthTxns: [Txn]
    @Query private var budgets: [Budget]
    @Query private var unparsed: [UnparsedSMS]
    @State private var showAdd   = false
    @State private var showPaste = false

    init() {
        let month = Date().startOfMonth
        _monthTxns = Query(filter: #Predicate<Txn> { $0.date >= month }, sort: \Txn.date, order: .reverse)
    }

    private var stats: MoneyStats { MoneyStats(txns: monthTxns, budgets: budgets) }

    var body: some View {
        NavigationStack {
            List {
                // ── Summary header ────────────────────────────────────────
                Section {
                    summaryHeader
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.init())

                // ── Donut chart ───────────────────────────────────────────
                if !stats.byCategory.isEmpty {
                    Section {
                        donutSection
                    } header: {
                        sectionHeader("Where it went", icon: "chart.pie.fill")
                    }
                }

                // ── Recent transactions ───────────────────────────────────
                Section {
                    if monthTxns.isEmpty {
                        ContentUnavailableView(
                            "No transactions yet",
                            systemImage: "indianrupeesign.circle",
                            description: Text("Set up the Shortcuts automation in the README, or tap + to add one.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(monthTxns.prefix(15)) { t in
                            NavigationLink { TxnDetailView(txn: t) } label: { TxnRow(txn: t) }
                        }
                        NavigationLink("All transactions →") { TransactionsView() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.brandCoral)
                    }
                } header: {
                    sectionHeader("Recent", icon: "clock.fill")
                }

                // ── Management links ──────────────────────────────────────
                Section {
                    NavigationLink {
                        BudgetsView()
                    } label: {
                        Label("Budgets", systemImage: "chart.bar.fill")
                    }
                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("Accounts & cards", systemImage: "creditcard.fill")
                    }
                    NavigationLink {
                        ReviewInboxView()
                    } label: {
                        Label("Review inbox", systemImage: "tray.full.fill")
                            .badge(unparsed.count)
                    }
                    NavigationLink {
                        ExportView()
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    sectionHeader("Manage", icon: "gearshape.fill")
                }
            }
            .navigationTitle("Money")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showAdd   = true } label: { Label("Add manually",   systemImage: "plus")               }
                        Button { showPaste = true } label: { Label("Paste bank SMS", systemImage: "doc.on.clipboard")   }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.brandCoral)
                    }
                }
            }
            .sheet(isPresented: $showAdd)   { AddTxnView() }
            .sheet(isPresented: $showPaste) { PasteSMSView() }
        }
    }

    // MARK: – Sub-views

    private var summaryHeader: some View {
        VStack(spacing: 0) {
            // Gradient hero strip
            HeroCard {
                Text(Date().formatted(.dateTime.month(.wide).year()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .tracking(0.5)

                Text(stats.spent.rupees)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text("spent this month")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.80))

                BudgetBar(spent: stats.spent, limit: stats.monthlyBudget, color: .white)
                    .opacity(0.9)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Metric row
            HStack(spacing: 0) {
                metricTile("Budget left",  stats.budgetLeft.rupees,       stats.budgetLeft < 0 ? .red : .primary)
                Divider().frame(height: 36)
                metricTile("Safe / day",   stats.safeToSpendPerDay.rupees, .green)
                Divider().frame(height: 36)
                metricTile("Income",       stats.income.rupees,            .primary)
            }
            .padding(.vertical, 14)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 0))
            .padding(.horizontal, 16)
        }
    }

    private func metricTile(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var donutSection: some View {
        VStack(spacing: 16) {
            // Donut chart
            Chart(stats.byCategory) { item in
                SectorMark(angle: .value("Amount", item.amount),
                           innerRadius: .ratio(0.60),
                           angularInset: 2)
                    .foregroundStyle(item.category.color)
                    .cornerRadius(5)
            }
            .chartBackground { _ in
                VStack(spacing: 2) {
                    Text(stats.byCategory.first?.category.label ?? "")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(stats.byCategory.first?.amount.rupees ?? "")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
            }
            .frame(height: 200)

            // Category rows
            VStack(spacing: 0) {
                ForEach(stats.byCategory) { item in
                    CategoryBudgetRow(
                        category: item.category,
                        spent: item.amount,
                        limit: budgets.first(where: { $0.category == item.category })?.monthlyLimit)
                    if item.id != stats.byCategory.last?.id { Divider() }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.brandCoral)
            .textCase(nil)
    }
}

// MARK: - CategoryBudgetRow

struct CategoryBudgetRow: View {
    let category: SpendCategory
    let spent: Double
    let limit: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(category.color.opacity(0.12)).frame(width: 28, height: 28)
                        Image(systemName: category.icon).font(.caption.weight(.medium)).foregroundStyle(category.color)
                    }
                    Text(category.label).font(.subheadline.weight(.medium))
                }
                Spacer()
                Text(limit.map { "\(spent.rupees) / \($0.rupees)" } ?? spent.rupees)
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            if let limit {
                BudgetBar(spent: spent, limit: limit, color: category.color)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - All transactions

struct TransactionsView: View {
    @Query(sort: \Txn.date, order: .reverse) private var txns: [Txn]
    @State private var search = ""
    @State private var category: SpendCategory?

    private var filtered: [Txn] {
        txns.filter { t in
            (category == nil || t.category == category) &&
            (search.isEmpty || t.merchant.localizedCaseInsensitiveContains(search)
                            || t.note.localizedCaseInsensitiveContains(search))
        }
    }

    struct DayGroup: Identifiable {
        let day: Date; let items: [Txn]; var id: Date { day }
    }

    private var grouped: [DayGroup] {
        Dictionary(grouping: filtered) { $0.date.startOfDay }
            .map { DayGroup(day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            ForEach(grouped) { group in
                Section(group.day.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(group.items) { t in
                        NavigationLink { TxnDetailView(txn: t) } label: { TxnRow(txn: t) }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Merchant or note")
        .navigationTitle("Transactions")
        .toolbar {
            Menu {
                Button("All categories") { category = nil }
                ForEach(SpendCategory.allCases) { c in
                    Button { category = c } label: { Label(c.label, systemImage: c.icon) }
                }
            } label: {
                Image(systemName: category == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }
}

// MARK: - Detail / edit

struct TxnDetailView: View {
    @Bindable var txn: Txn
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(txn.direction == .debit ? "Spent" : "Received")
                    Spacer()
                    TextField("Amount", value: $txn.amount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.bold())
                }
                TextField("Merchant", text: $txn.merchant)
                DatePicker("Date", selection: $txn.date)
            }
            Section {
                Picker("Category", selection: Binding(
                    get: { txn.category },
                    set: { newValue in
                        txn.category  = newValue
                        txn.isTransfer = newValue == .transfers
                        TxnIngest.learn(merchant: txn.merchant, category: newValue, context: context)
                    })) {
                    ForEach(SpendCategory.allCases) { c in Label(c.label, systemImage: c.icon).tag(c) }
                }
                Toggle("Transfer between my accounts", isOn: $txn.isTransfer)
            } footer: {
                Text("Changing the category teaches Shraa — future \(Categorizer.ruleKeyword(from: txn.merchant)) transactions go there automatically.")
            }
            Section("Note") {
                TextField("Add a note", text: $txn.note, axis: .vertical)
            }
            if !txn.bank.isEmpty || txn.upiRef != nil {
                Section("Details") {
                    LabeledContent("Account", value: "\(txn.bank) ••\(txn.accountLast4)")
                    if let ref = txn.upiRef { LabeledContent("UPI ref", value: ref) }
                    LabeledContent("Source", value: txn.source.rawValue.capitalized)
                }
            }
            if let raw = txn.rawText {
                Section("Original SMS") {
                    Text(raw).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Section {
                Button("Delete transaction", role: .destructive) {
                    context.delete(txn); try? context.save(); dismiss()
                }
            }
        }
        .navigationTitle(txn.merchant)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }
}

// MARK: - Add

struct AddTxnView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Query(sort: \Account.name)  private var accounts: [Account]

    @State private var amount: Double?
    @State private var merchant = ""
    @State private var direction: TxnDirection = .debit
    @State private var category: SpendCategory = .food
    @State private var date  = Date()
    @State private var account: Account?
    @State private var note  = ""
    @State private var categoryTouched = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $direction) {
                    Text("Expense").tag(TxnDirection.debit)
                    Text("Income").tag(TxnDirection.credit)
                }
                .pickerStyle(.segmented)

                Section {
                    TextField("Amount (₹)", value: $amount, format: .number)
                        .keyboardType(.decimalPad).font(.title2.bold())
                    TextField(direction == .debit ? "Where / what" : "From", text: $merchant)
                        .onChange(of: merchant) { _, m in
                            guard !categoryTouched else { return }
                            category = Categorizer.category(for: m, direction: direction, isBillPayment: false, rules: [])
                        }
                    Picker("Category", selection: Binding(
                        get: { category },
                        set: { category = $0; categoryTouched = true })) {
                        ForEach(SpendCategory.allCases) { c in Label(c.label, systemImage: c.icon).tag(c) }
                    }
                    DatePicker("Date", selection: $date)
                    Picker("Paid with", selection: $account) {
                        Text("Cash").tag(Account?.none)
                        ForEach(accounts) { a in Text(a.name).tag(Optional(a)) }
                    }
                }
                Section { TextField("Note", text: $note) }
            }
            .navigationTitle("Add transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled((amount ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let t = Txn(date: date, amount: amount ?? 0, direction: direction,
                    merchant: merchant.isEmpty ? (direction == .debit ? "Cash" : "Income") : merchant,
                    category: category, bank: account?.bank ?? "", accountLast4: account?.last4 ?? "",
                    isCard: account.map { $0.kind == .creditCard || $0.kind == .debitCard } ?? false,
                    source: .manual, note: note, isTransfer: category == .transfers)
        context.insert(t)
        try? context.save()
        if categoryTouched && !merchant.isEmpty { TxnIngest.learn(merchant: merchant, category: category, context: context) }
        Task { await NudgeScheduler.shared.afterTransaction(t, context: context) }
        dismiss()
    }
}

// MARK: - Paste SMS

struct PasteSMSView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @State private var text   = ""
    @State private var result: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text).frame(minHeight: 140)
                    Button("Paste from clipboard") { text = UIPasteboard.general.string ?? "" }
                } footer: {
                    Text("Paste any bank transaction SMS. Great for testing before the automation is set up.")
                }
                if let result { Section { Text(result) } }
            }
            .navigationTitle("Paste bank SMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log it") {
                        switch TxnIngest.ingestSMS(text, context: context) {
                        case .saved(let t):
                            result = "✅ \(t.direction == .debit ? "Spent" : "Received") \(t.amount.rupees) · \(t.merchant) · \(t.category.label)"
                            text = ""
                        case .duplicate:   result = "Already logged."
                        case .ignored:     result = "Not a transaction (OTP, reminder or promo). Skipped."
                        case .sentToReview: result = "Couldn't read it. Saved to Review inbox."
                        }
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}
