import SwiftUI
import SwiftData

struct WorkView: View {
    @State private var segment = 0
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    Text("Tasks").tag(0)
                    Text("Projects").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if segment == 0 { TasksList() } else { ProjectsList() }
            }
            .background(Color.surfaceBase)
            .navigationTitle("Work & Growth")
        }
    }
}

// MARK: - Tasks

struct TasksList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @State private var area: TaskArea?
    @State private var showAdd    = false
    @State private var quickTitle = ""

    private var open:     [TaskItem] { tasks.filter { !$0.isDone && (area == nil || $0.area == area) } }
    private var endOfToday: Date    { Calendar.current.date(byAdding: .day, value: 1, to: Date().startOfDay)! }
    private var today:    [TaskItem] { open.filter { ($0.due ?? .distantFuture) < endOfToday }.sorted { $0.priority > $1.priority } }
    private var upcoming: [TaskItem] { open.filter { ($0.due ?? .distantFuture) >= endOfToday && $0.due != nil }.sorted { $0.due! < $1.due! } }
    private var someday:  [TaskItem] { open.filter { $0.due == nil } }
    private var done:     [TaskItem] {
        tasks.filter { $0.isDone && (area == nil || $0.area == area) }
            .sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }
            .prefix(15).map { $0 }
    }

    var body: some View {
        List {
            // Quick add + area filter
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.brandCoral)
                        .font(.title3)
                    TextField("Quick add for today…", text: $quickTitle)
                        .onSubmit(quickAdd)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        areaChip(nil, label: "All")
                        ForEach(TaskArea.allCases) { a in
                            areaChip(a, label: a.label)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            taskSection("Today & overdue", today,     color: .brandCoral)
            taskSection("Upcoming",         upcoming,  color: .blue)
            taskSection("Someday",          someday,   color: .secondary)
            if !done.isEmpty {
                taskSection("Done",         done,      color: .green)
            }
        }
        .toolbar {
            Button { showAdd = true } label: {
                Image(systemName: "plus").foregroundStyle(Color.brandCoral)
            }
        }
        .sheet(isPresented: $showAdd) { NavigationStack { TaskEditView(task: nil) } }
    }

    private func areaChip(_ a: TaskArea?, label: String) -> some View {
        let selected = area == a
        return Button { withAnimation(.spring(response: 0.3)) { area = a } } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? Color.brandCoral : Color(.tertiarySystemFill),
                            in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func taskSection(_ title: String, _ items: [TaskItem], color: Color) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { t in
                    NavigationLink { TaskEditView(task: t) } label: { TaskRow(task: t) }
                }
                .onDelete { idx in
                    for i in idx { context.delete(items[i]) }
                    try? context.save()
                }
            } header: {
                Label(title, systemImage: "circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(color)
                    .textCase(nil)
            }
        }
    }

    private func quickAdd() {
        guard !quickTitle.isEmpty else { return }
        context.insert(TaskItem(title: quickTitle,
                                due: Date().startOfDay.addingTimeInterval(18 * 3600),
                                area: area ?? .life))
        try? context.save()
        quickTitle = ""
    }
}

// MARK: - TaskRow

struct TaskRow: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.35)) {
                    task.isDone.toggle()
                    task.doneAt = task.isDone ? .now : nil
                    try? context.save()
                }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(task.isDone, color: .secondary)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Area chip
                    HStack(spacing: 3) {
                        Image(systemName: task.area.icon).font(.caption2)
                        Text(task.area.label).font(.caption2)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(areaColor(task.area).opacity(0.10), in: Capsule())
                    .foregroundStyle(areaColor(task.area))

                    if let p = task.project { Text(p.name).font(.caption).foregroundStyle(.secondary).lineLimit(1) }

                    if let due = task.due {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar").font(.caption2)
                            Text(due.formatted(.relative(presentation: .named)))
                        }
                        .font(.caption)
                        .foregroundStyle(!task.isDone && due < .now ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Priority flag
            if task.priority == 2 {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    private func areaColor(_ a: TaskArea) -> Color {
        switch a { case .work: .blue; case .learn: .purple; case .life: .green }
    }
}

// MARK: - TaskEditView

struct TaskEditView: View {
    var task: TaskItem?
    var presetProject: Project? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Query(sort: \Project.name)  private var projects: [Project]

    @State private var title    = ""
    @State private var notes    = ""
    @State private var hasDue   = true
    @State private var due      = Date().startOfDay.addingTimeInterval(18 * 3600)
    @State private var priority = 1
    @State private var area: TaskArea = .work
    @State private var project: Project?

    var body: some View {
        Form {
            TextField("Task", text: $title)
            TextField("Notes", text: $notes, axis: .vertical)
            Picker("Area", selection: $area) {
                ForEach(TaskArea.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
            }
            Picker("Priority", selection: $priority) {
                Text("Low").tag(0); Text("Normal").tag(1); Text("High").tag(2)
            }
            .pickerStyle(.segmented)
            Toggle("Due date", isOn: $hasDue)
            if hasDue { DatePicker("Due", selection: $due) }
            Picker("Project", selection: $project) {
                Text("None").tag(Project?.none)
                ForEach(projects) { Text($0.name).tag(Optional($0)) }
            }
        }
        .navigationTitle(task == nil ? "New task" : "Edit task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(title.isEmpty) }
        }
        .onAppear {
            project = presetProject
            guard let t = task else { return }
            title = t.title; notes = t.notes; hasDue = t.due != nil; due = t.due ?? due
            priority = t.priority; area = t.area; project = t.project
        }
    }

    private func save() {
        let t = task ?? TaskItem(title: title)
        t.title = title; t.notes = notes; t.due = hasDue ? due : nil
        t.priority = priority; t.area = area; t.project = project
        if task == nil { context.insert(t) }
        try? context.save()
        Task { await NudgeScheduler.shared.replan(context: context) }
        dismiss()
    }
}

// MARK: - Projects

struct ProjectsList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var showAdd = false

    private var pipeline: Double { projects.filter { $0.status.isMoneyPending }.reduce(0) { $0 + $1.pendingAmount } }
    private var overdue:  Double {
        projects.filter { $0.status.isMoneyPending && ($0.expectedPaymentDate ?? .distantFuture) < .now }
            .reduce(0) { $0 + $1.pendingAmount }
    }

    var body: some View {
        List {
            // Pipeline summary
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pipeline.rupees)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .monospacedDigit()
                        Text("expected from projects").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if overdue > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(overdue.rupees)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.red)
                            Text("overdue").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            ForEach(ProjectStatus.allCases) { status in
                let items = projects.filter { $0.status == status }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { p in
                            NavigationLink { ProjectDetailView(project: p) } label: {
                                projectRow(p)
                            }
                        }
                    } header: {
                        Text(status.label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(statusColor(status))
                            .textCase(nil)
                    }
                }
            }
        }
        .toolbar { Button { showAdd = true } label: { Image(systemName: "plus").foregroundStyle(Color.brandCoral) } }
        .sheet(isPresented: $showAdd) { ProjectEditView(project: nil) }
    }

    private func projectRow(_ p: Project) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(p.name).font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                if !p.client.isEmpty {
                    Label(p.client, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if p.agreedAmount > 0 {
                    Label("\(p.receivedAmount.rupees) / \(p.agreedAmount.rupees)", systemImage: "indianrupeesign")
                        .font(.caption)
                        .foregroundStyle(p.pendingAmount > 0 ? .orange : .green)
                }
                let open = p.tasks.filter { !$0.isDone }.count
                if open > 0 {
                    Label("\(open) open", systemImage: "checklist")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ s: ProjectStatus) -> Color {
        switch s {
        case .lead:      return .secondary
        case .active:    return .brandCoral
        case .delivered: return .blue
        case .invoiced:  return .orange
        case .paid:      return .green
        case .idea:      return .purple
        }
    }
}

// MARK: - ProjectDetailView

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @State private var showEdit = false
    @State private var showTask = false
    @State private var payment: Double?

    var body: some View {
        List {
            Section {
                LabeledContent("Status",   value: project.status.label)
                if !project.client.isEmpty { LabeledContent("Client", value: project.client) }
                LabeledContent("Agreed",   value: project.agreedAmount.rupees)
                LabeledContent("Received", value: project.receivedAmount.rupees)
                LabeledContent("Pending",  value: project.pendingAmount.rupees)
                if let d = project.deadline {
                    LabeledContent("Deadline", value: d.formatted(date: .abbreviated, time: .omitted))
                }
                if let d = project.expectedPaymentDate {
                    LabeledContent("Payment expected", value: d.formatted(date: .abbreviated, time: .omitted))
                }
            }
            if project.pendingAmount > 0 {
                Section {
                    HStack {
                        TextField("Payment received ₹", value: $payment, format: .number)
                            .keyboardType(.numberPad)
                        Button("Record") { recordPayment() }.disabled((payment ?? 0) <= 0)
                    }
                } footer: {
                    Text("Records here and as income in Money (skip if the bank SMS already logged it).")
                }
            }
            Section("Tasks") {
                ForEach(project.tasks.sorted { !$0.isDone && $1.isDone }) { t in
                    NavigationLink { TaskEditView(task: t) } label: { TaskRow(task: t) }
                }
                Button { showTask = true } label: { Label("Add task", systemImage: "plus") }
            }
            if !project.notes.isEmpty {
                Section("Notes") { Text(project.notes) }
            }
        }
        .navigationTitle(project.name)
        .toolbar { Button("Edit") { showEdit = true } }
        .sheet(isPresented: $showEdit) { ProjectEditView(project: project) }
        .sheet(isPresented: $showTask) { NavigationStack { TaskEditView(task: nil, presetProject: project) } }
    }

    private func recordPayment() {
        guard let amt = payment, amt > 0 else { return }
        project.receivedAmount += amt
        if project.pendingAmount == 0 { project.status = .paid }
        context.insert(Txn(date: .now, amount: amt, direction: .credit,
                           merchant: project.client.isEmpty ? project.name : project.client,
                           category: .income, source: .manual,
                           note: "Project: \(project.name)"))
        try? context.save()
        payment = nil
    }
}

// MARK: - ProjectEditView

struct ProjectEditView: View {
    var project: Project?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @State private var name       = ""
    @State private var client     = ""
    @State private var amount: Double?
    @State private var status: ProjectStatus = .active
    @State private var hasDeadline  = false
    @State private var deadline     = Date()
    @State private var hasPayDate   = false
    @State private var payDate      = Date()
    @State private var notes        = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Project name", text: $name)
                TextField("Client",       text: $client)
                TextField("Agreed amount ₹", value: $amount, format: .number).keyboardType(.numberPad)
                Picker("Status", selection: $status) {
                    ForEach(ProjectStatus.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Deadline",           isOn: $hasDeadline)
                if hasDeadline { DatePicker("Deadline", selection: $deadline, displayedComponents: .date) }
                Toggle("Expected payment",   isOn: $hasPayDate)
                if hasPayDate  { DatePicker("Payment",  selection: $payDate,  displayedComponents: .date) }
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle(project == nil ? "New project" : "Edit project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.isEmpty) }
            }
            .onAppear {
                guard let p = project else { return }
                name = p.name; client = p.client; amount = p.agreedAmount; status = p.status
                hasDeadline = p.deadline != nil;         deadline = p.deadline ?? Date()
                hasPayDate  = p.expectedPaymentDate != nil; payDate = p.expectedPaymentDate ?? Date()
                notes = p.notes
            }
        }
    }

    private func save() {
        let p = project ?? Project(name: name)
        p.name = name; p.client = client; p.agreedAmount = amount ?? 0; p.status = status
        p.deadline = hasDeadline ? deadline : nil
        p.expectedPaymentDate = hasPayDate ? payDate : nil
        p.notes = notes
        if project == nil { context.insert(p) }
        try? context.save()
        dismiss()
    }
}
