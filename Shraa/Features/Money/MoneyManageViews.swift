import SwiftUI
import SwiftData

// MARK: - Budgets

struct BudgetsView: View {
    @Environment(\.modelContext) private var context
    @Query private var budgets: [Budget]
    @AppStorage(Prefs.Key.monthlyBudget) private var monthlyBudget = 30_000.0

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Monthly total")
                    Spacer()
                    TextField("₹", value: $monthlyBudget, format: .number)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing).bold()
                }
            } footer: {
                Text("Drives \"safe to spend per day\" and the overspend alert.")
            }
            Section {
                ForEach(SpendCategory.spendable) { cat in
                    HStack {
                        Label(cat.label, systemImage: cat.icon).foregroundStyle(cat.color)
                        Spacer()
                        TextField("No limit", value: binding(for: cat), format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 110)
                    }
                }
            } header: {
                Text("Per category")
            } footer: {
                Text("You get a nudge at 80% and when you cross 100%.")
            }
        }
        .navigationTitle("Budgets")
        .onDisappear { try? context.save() }
    }

    private func binding(for cat: SpendCategory) -> Binding<Double?> {
        Binding(
            get: { budgets.first(where: { $0.category == cat })?.monthlyLimit },
            set: { value in
                if let existing = budgets.first(where: { $0.category == cat }) {
                    if let value, value > 0 { existing.monthlyLimit = value } else { context.delete(existing) }
                } else if let value, value > 0 {
                    context.insert(Budget(category: cat, monthlyLimit: value))
                }
            })
    }
}

// MARK: - Accounts

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(accounts) { a in
                NavigationLink { AccountEditView(account: a) } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(a.name)
                            Text(a.kind.label + (a.dueDay.map { " · due on \($0)" } ?? ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: a.kind.icon) }
                }
            }
            .onDelete { idx in
                for i in idx { context.delete(accounts[i]) }
                try? context.save()
            }
        }
        .overlay {
            if accounts.isEmpty {
                ContentUnavailableView("No accounts yet", systemImage: "creditcard",
                                       description: Text("Accounts appear automatically from your bank SMS. You can also add one."))
            }
        }
        .navigationTitle("Accounts & cards")
        .toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                AccountEditView(account: nil)
            }
        }
    }
}

struct AccountEditView: View {
    var account: Account?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var bank = "HDFC"
    @State private var last4 = ""
    @State private var kind: AccountKind = .bank
    @State private var limit: Double?
    @State private var dueDay: Int?

    var body: some View {
        Form {
            TextField("Name", text: $name)
            Picker("Type", selection: $kind) {
                ForEach(AccountKind.allCases) { Text($0.label).tag($0) }
            }
            TextField("Bank", text: $bank)
            TextField("Last 4 digits", text: $last4).keyboardType(.numberPad)
            if kind == .creditCard {
                TextField("Credit limit", value: $limit, format: .number).keyboardType(.numberPad)
                Picker("Bill due on", selection: $dueDay) {
                    Text("Not set").tag(Int?.none)
                    ForEach(1...31, id: \.self) { Text("\($0)").tag(Optional($0)) }
                }
            }
        }
        .navigationTitle(account == nil ? "New account" : "Edit account")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.isEmpty) }
        }
        .onAppear {
            guard let a = account else { return }
            name = a.name; bank = a.bank; last4 = a.last4; kind = a.kind; limit = a.creditLimit; dueDay = a.dueDay
        }
    }

    private func save() {
        let a = account ?? Account(name: name, bank: bank, last4: last4, kind: kind)
        a.name = name; a.bank = bank; a.last4 = last4; a.kind = kind; a.creditLimit = limit; a.dueDay = dueDay
        if account == nil { context.insert(a) }
        try? context.save()
        dismiss()
    }
}

// MARK: - Review inbox

struct ReviewInboxView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UnparsedSMS.receivedAt, order: .reverse) private var items: [UnparsedSMS]
    @State private var addFor: UnparsedSMS?

    var body: some View {
        List {
            ForEach(items) { sms in
                VStack(alignment: .leading, spacing: 8) {
                    Text(sms.text).font(.footnote).textSelection(.enabled)
                    HStack {
                        Text(sms.receivedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Add by hand") { addFor = sms }.buttonStyle(.bordered).controlSize(.small)
                        Button("Dismiss", role: .destructive) { context.delete(sms); try? context.save() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("All clear", systemImage: "checkmark.circle",
                                       description: Text("Bank SMS that Shraa can't read show up here."))
            }
        }
        .navigationTitle("Review inbox")
        .sheet(item: $addFor, onDismiss: nil) { sms in
            AddTxnView()
                .onDisappear { context.delete(sms); try? context.save() }
        }
    }
}

// MARK: - Export

struct ExportView: View {
    @Query(sort: \Txn.date, order: .reverse) private var txns: [Txn]
    @State private var url: URL?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells").font(.system(size: 48)).foregroundStyle(.tint)
            Text("\(txns.count) transactions").font(.headline)
            if let url {
                ShareLink(item: url) { Label("Share CSV", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Export")
        .task { url = makeCSV() }
    }

    private func makeCSV() -> URL? {
        func esc(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        let iso = ISO8601DateFormatter()
        var rows = ["date,type,amount,merchant,category,bank,account,upi_ref,transfer,note"]
        for t in txns {
            rows.append([iso.string(from: t.date), t.direction.rawValue, String(format: "%.2f", t.amount),
                         esc(t.merchant), t.category.label, t.bank, t.accountLast4, t.upiRef ?? "",
                         t.isTransfer ? "yes" : "no", esc(t.note)].joined(separator: ","))
        }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("shraa-transactions.csv")
        do {
            try rows.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch { return nil }
    }
}
