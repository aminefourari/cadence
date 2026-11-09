import SwiftUI

enum BoardColumn: CaseIterable, Identifiable {
    case todo, inProgress, done

    var id: Self { self }

    static func of(_ task: TaskItem) -> BoardColumn {
        task.done ? .done : (task.inProgress ? .inProgress : .todo)
    }

    var title: String {
        switch self {
        case .todo: return "To Do"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        }
    }

    var icon: String {
        switch self {
        case .todo: return "circle.dashed"
        case .inProgress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .todo: return Theme.muted
        case .inProgress: return Theme.accent
        case .done: return Theme.mint
        }
    }
}

enum TaskSort: String, CaseIterable, Identifiable {
    case manual, priority, created

    var id: Self { self }

    var title: String {
        switch self {
        case .manual: return "Manual"
        case .priority: return "Priority"
        case .created: return "Newest first"
        }
    }

    func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            switch self {
            case .manual:
                return (lhs.position, lhs.createdAtMs) < (rhs.position, rhs.createdAtMs)
            case .priority:
                return (lhs.priority.sortOrder, lhs.position, lhs.createdAtMs)
                    < (rhs.priority.sortOrder, rhs.position, rhs.createdAtMs)
            case .created:
                return lhs.createdAtMs > rhs.createdAtMs
            }
        }
    }
}

extension AppModel {
    func move(_ task: TaskItem, to column: BoardColumn) {
        switch column {
        case .done:
            if !task.done { toggleTask(task, toDone: true) }
        case .todo, .inProgress:
            if task.done { toggleTask(task, toDone: false) }
            let wantsProgress = column == .inProgress
            if task.inProgress != wantsProgress { updateTask(task, inProgress: wantsProgress) }
        }
    }
}

struct TasksView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("taskSort") private var sort: TaskSort = .manual
    @State private var editorMode: TaskEditorMode?
    @State private var taskToDelete: TaskItem?
    @State private var showArchive = false

    private var archivedCount: Int { model.tasks.filter(\.archived).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 16)

            HStack(alignment: .top, spacing: Theme.s(12)) {
                ForEach(BoardColumn.allCases) { column in
                    KanbanColumn(
                        column: column,
                        sort: sort,
                        onEdit: { editorMode = .edit($0) },
                        onDelete: { taskToDelete = $0 },
                        onFocus: focus(task:)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, Theme.s(34))
        .padding(.top, Theme.s(40))
        .padding(.bottom, Theme.s(22))
        .sheet(item: $editorMode) { mode in
            TaskEditorView(mode: mode) { title, priority, estimate in
                switch mode {
                case .add:
                    model.addTask(title: title, priority: priority, estimateBlocks: estimate)
                case .edit(let task):
                    model.updateTask(task, title: title, priority: priority, estimateBlocks: estimate)
                }
            }
            .environmentObject(model)
        }
        .sheet(isPresented: $showArchive) {
            ArchiveView(onDelete: { taskToDelete = $0 })
                .environmentObject(model)
        }
        .alert(
            "Delete task?",
            isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            ),
            presenting: taskToDelete
        ) { task in
            Button("Delete", role: .destructive) {
                model.deleteTask(task)
                taskToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                taskToDelete = nil
            }
        } message: { task in
            Text("“\(task.title)” will be removed. Its logged focus sessions stay in your history.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.s(16)) {
            VStack(alignment: .leading, spacing: Theme.s(7)) {
                Text("Tasks")
                    .font(Theme.font(31, .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .tracking(-0.4)

                HStack(spacing: Theme.s(8)) {
                    Text("MOVE THE WORK ACROSS THE BOARD")
                        .font(Theme.font(9.5, .semibold))
                        .tracking(1.35)
                        .foregroundStyle(Theme.mutedDim)
                    Circle()
                        .fill(Theme.mutedDim.opacity(0.55))
                        .frame(width: 2, height: 2)
                    Text("\(model.openTasks.count) open · \(model.todayCompletedTasks.count) completed today")
                        .font(Theme.font(10.5, .medium))
                        .foregroundStyle(Theme.muted)
                }
            }

            Spacer()

            HStack(spacing: Theme.s(10)) {
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(TaskSort.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    pillLabel("Sort: \(sort.title)", icon: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Button { showArchive = true } label: {
                    pillLabel(archivedCount > 0 ? "Archive · \(archivedCount)" : "Archive", icon: "archivebox")
                }
                .buttonStyle(PressableStyle())

                AccentButton(title: "New task", icon: "plus") {
                    editorMode = .add
                }
                UtilityIconButton(icon: "gearshape.fill", help: "Preferences") {
                    model.showSettings = true
                }
            }
            .padding(.top, Theme.s(5))
        }
    }

    private func pillLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.s(6)) {
            Image(systemName: icon)
                .font(Theme.font(10, .medium))
            Text(title)
                .font(Theme.font(11, .medium))
        }
        .foregroundStyle(Theme.cream.opacity(0.72))
        .padding(.horizontal, Theme.s(13))
        .frame(height: 34)
        .background { Capsule().fill(Theme.controlFill) }
        .overlay { Capsule().strokeBorder(Theme.controlStroke, lineWidth: 1) }
        .contentShape(Capsule())
    }

    private func focus(task: TaskItem) {
        model.assignTask(task)
        model.selectTab(.focus)
    }
}

private enum TaskEditorMode: Identifiable {
    case add
    case edit(TaskItem)

    var id: String {
        switch self {
        case .add: return "new"
        case .edit(let task): return task.id
        }
    }
}

private struct KanbanColumn: View {
    @EnvironmentObject private var model: AppModel
    let column: BoardColumn
    let sort: TaskSort
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onFocus: (TaskItem) -> Void

    @State private var targeted = false
    @State private var adding = false
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    private var tasks: [TaskItem] {
        sort.sorted(model.tasks.filter { !$0.archived && BoardColumn.of($0) == column })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s(8)) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Theme.s(7)) {
                    ForEach(tasks) { task in
                        TaskCard(
                            task: task,
                            onEdit: onEdit,
                            onDelete: onDelete,
                            onFocus: onFocus,
                            onDropBefore: { drop($0, before: task) }
                        )
                    }
                    if tasks.isEmpty && !adding {
                        Text(column == .done ? "Drop finished cards here" : "No cards yet")
                            .font(Theme.font(9.5, .medium))
                            .foregroundStyle(Theme.mutedDim.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    if adding { addField }
                }
                .padding(.bottom, Theme.s(2))
            }
            .frame(maxHeight: .infinity)

            if column != .done && !adding {
                Button {
                    adding = true
                    draftFocused = true
                } label: {
                    Label("Add a card", systemImage: "plus")
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.s(8))
                        .frame(height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                                .fill(Theme.cream.opacity(0.03))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.s(10))
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(16), style: .continuous)
                .fill(targeted ? column.tint.opacity(0.08) : Theme.surface.opacity(0.7))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(16), style: .continuous)
                .strokeBorder(
                    targeted ? column.tint.opacity(0.45) : Theme.cream.opacity(0.055),
                    style: StrokeStyle(lineWidth: 1, dash: targeted ? [5, 4] : [])
                )
        }
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            return drop(id, before: nil)
        } isTargeted: { value in
            withAnimation(.easeOut(duration: 0.18)) { targeted = value }
        }
    }

    /// Moves the dragged card into this column; in manual sort it lands before `target` (or last).
    private func drop(_ id: String, before target: TaskItem?) -> Bool {
        guard let task = model.tasks.first(where: { $0.id == id }), task.id != target?.id else { return false }
        let sameColumn = BoardColumn.of(task) == column
        guard !sameColumn || sort == .manual else { return false }
        if sort == .manual {
            var ids = tasks.map(\.id).filter { $0 != id }
            let index = target.flatMap { target in ids.firstIndex(of: target.id) } ?? ids.count
            ids.insert(id, at: index)
            model.reorderTasks(ids: ids)
        }
        if !sameColumn { model.move(task, to: column) }
        return true
    }

    private var header: some View {
        HStack(spacing: Theme.s(7)) {
            Image(systemName: column.icon)
                .font(Theme.font(11, .semibold))
                .foregroundStyle(column.tint)
            Text(column.title)
                .font(Theme.font(12, .semibold))
                .foregroundStyle(Theme.cream.opacity(0.9))
            Text("\(tasks.count)")
                .font(Theme.font(10, .semibold, design: .monospaced))
                .foregroundStyle(Theme.mutedDim)
            Spacer(minLength: 2)
            if column == .done && !tasks.isEmpty {
                Menu {
                    Button {
                        for task in tasks { model.updateTask(task, archived: true) }
                    } label: {
                        Label("Archive all cards in this list", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(Theme.font(10, .bold))
                        .foregroundStyle(Theme.mutedDim)
                        .frame(width: 22, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, Theme.s(4))
        .frame(height: 24)
    }

    private var addField: some View {
        TextField("Enter a title for this card…", text: $draft)
            .textFieldStyle(.plain)
            .font(Theme.font(10.5, .medium))
            .foregroundStyle(Theme.cream)
            .tint(Theme.accent)
            .focused($draftFocused)
            .padding(Theme.s(9))
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                    .fill(Theme.surfaceHigh)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                    .strokeBorder(column.tint.opacity(0.4), lineWidth: 1)
            }
            .onSubmit {
                commitDraft()
                draftFocused = true
            }
            .onExitCommand(perform: cancelDraft)
            .onChange(of: draftFocused) { _, focused in
                if !focused {
                    commitDraft()
                    cancelDraft()
                }
            }
    }

    /// Return adds the card and keeps the field open for the next one, like Trello.
    private func commitDraft() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        model.addTask(title: title, priority: .medium, estimateBlocks: 1, inProgress: column == .inProgress)
        draft = ""
    }

    private func cancelDraft() {
        draft = ""
        adding = false
    }
}

private struct TaskCard: View {
    @EnvironmentObject private var model: AppModel
    let task: TaskItem
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onFocus: (TaskItem) -> Void
    let onDropBefore: (String) -> Bool

    @State private var hovered = false
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s(7)) {
            HStack(spacing: Theme.s(6)) {
                PriorityBadge(priority: task.priority)
                Spacer()
                if model.timer.activeTaskId == task.id {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 5, height: 5)
                        .shadow(color: Theme.accent.opacity(0.8), radius: 3)
                }
                menu
            }

            Text(task.title)
                .font(Theme.font(11, task.done ? .regular : .medium))
                .foregroundStyle(task.done ? Theme.mutedDim : Theme.cream.opacity(0.92))
                .strikethrough(task.done, color: Theme.mutedDim)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Theme.s(8)) {
                Button {
                    model.toggleTask(task)
                } label: {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .font(Theme.font(11, .medium))
                        .foregroundStyle(task.done ? Theme.mint : Theme.mutedDim.opacity(hovered ? 0.9 : 0.55))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(task.done ? "Mark as not done" : "Mark as done")

                Label("\(task.completedBlocks)/\(task.estimateBlocks)", systemImage: "timer")
                    .font(Theme.font(8.5, .medium, design: .monospaced))
                    .foregroundStyle(Theme.mutedDim)
                if task.focusedMinutes > 0 {
                    Text("\(task.focusedMinutes)m")
                        .font(Theme.font(8.5, .medium, design: .monospaced))
                        .foregroundStyle(Theme.mutedDim.opacity(0.8))
                }
                Spacer()
            }
        }
        .padding(Theme.s(9))
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                .fill(hovered ? Theme.controlFillHover : Theme.surfaceHigh)
                .shadow(color: Theme.shadow.opacity(0.25), radius: 1.5, y: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                .strokeBorder(Theme.cream.opacity(hovered ? 0.09 : 0.045), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            if dropTargeted {
                Capsule()
                    .fill(Theme.accent)
                    .frame(height: 2)
                    .offset(y: -Theme.s(5))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture(count: 2) { onEdit(task) }
        .opacity(task.done ? 0.7 : 1)
        .draggable(task.id)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            return onDropBefore(id)
        } isTargeted: { dropTargeted = $0 }
    }

    private var menu: some View {
        Menu {
            if !task.done {
                Button { onFocus(task) } label: { Label("Focus now", systemImage: "scope") }
            }
            Button { onEdit(task) } label: { Label("Edit card", systemImage: "pencil") }
            Picker("Priority", selection: Binding(
                get: { task.priority },
                set: { model.updateTask(task, priority: $0) }
            )) {
                ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
            }
            Menu("Move to") {
                ForEach(BoardColumn.allCases.filter { $0 != BoardColumn.of(task) }) { column in
                    Button(column.title) { model.move(task, to: column) }
                }
            }
            Divider()
            Button { model.updateTask(task, archived: true) } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive) { onDelete(task) } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(Theme.font(9, .bold))
                .foregroundStyle(Theme.mutedDim.opacity(hovered ? 0.9 : 0.35))
                .frame(width: 18, height: 14)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

private struct PriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        HStack(spacing: Theme.s(3)) {
            Image(systemName: priority.icon)
                .font(Theme.font(7.5, .bold))
            Text(priority.title)
                .font(Theme.font(8.5, .semibold))
        }
        .foregroundStyle(priority.tint)
        .padding(.horizontal, Theme.s(6))
        .frame(height: 17)
        .background { Capsule().fill(priority.tint.opacity(0.13)) }
    }
}

private struct ArchiveView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onDelete: (TaskItem) -> Void

    private var archived: [TaskItem] {
        model.tasks.filter(\.archived).sorted { $0.createdAtMs > $1.createdAtMs }
    }

    var body: some View {
        ZStack {
            SheetBackground()

            VStack(alignment: .leading, spacing: Theme.s(16)) {
                HStack {
                    Text("Archived cards")
                        .font(Theme.font(22, .semibold, design: .rounded))
                        .foregroundStyle(Theme.cream)
                    Spacer()
                    QuietButton(title: "Done") { dismiss() }
                }

                if archived.isEmpty {
                    Text("Nothing archived yet.")
                        .font(Theme.font(11, .medium))
                        .foregroundStyle(Theme.mutedDim)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: Theme.s(6)) {
                            ForEach(archived) { task in
                                row(task)
                            }
                        }
                    }
                }
            }
            .padding(Theme.s(24))
        }
        .frame(width: 480, height: 460)
        .preferredColorScheme(model.appearanceMode.colorScheme)
    }

    private func row(_ task: TaskItem) -> some View {
        HStack(spacing: Theme.s(8)) {
            PriorityBadge(priority: task.priority)
            Text(task.title)
                .font(Theme.font(11, .medium))
                .foregroundStyle(Theme.cream.opacity(0.85))
                .strikethrough(task.done, color: Theme.mutedDim)
                .lineLimit(1)
            Spacer()
            Button("Restore") { model.updateTask(task, archived: false) }
                .buttonStyle(.plain)
                .font(Theme.font(10, .semibold))
                .foregroundStyle(Theme.accent)
            Button {
                onDelete(task)
            } label: {
                Image(systemName: "trash")
                    .font(Theme.font(10, .medium))
                    .foregroundStyle(Theme.mutedDim)
            }
            .buttonStyle(.plain)
            .help("Delete permanently")
        }
        .padding(.horizontal, Theme.s(10))
        .frame(height: 38)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                .fill(Theme.cream.opacity(0.12))
        }
    }
}

/// The app background, dimmed a little more so sheet content stays readable.
private struct SheetBackground: View {
    var body: some View {
        AppBackground()
            .overlay { Theme.inkDeep.opacity(Theme.isLight ? 0.55 : 0.62) }
    }
}

struct MiniStepperButton: View {
    let icon: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.font(7.5, .bold))
                .foregroundStyle(enabled ? Theme.cream.opacity(0.7) : Theme.mutedDim.opacity(0.3))
                .frame(width: 18, height: 18)
                .background { Circle().fill(Theme.cream.opacity(enabled ? 0.14 : 0.05)) }
                .overlay { Circle().strokeBorder(Theme.cream.opacity(0.14), lineWidth: 1) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct TaskEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let mode: TaskEditorMode
    let onSave: (String, TaskPriority, Int) -> Void

    @State private var title: String
    @State private var priority: TaskPriority
    @State private var estimateBlocks: Int
    @FocusState private var titleFocused: Bool

    init(mode: TaskEditorMode, onSave: @escaping (String, TaskPriority, Int) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _title = State(initialValue: "")
            _priority = State(initialValue: .medium)
            _estimateBlocks = State(initialValue: 1)
        case .edit(let task):
            _title = State(initialValue: task.title)
            _priority = State(initialValue: task.priority)
            _estimateBlocks = State(initialValue: task.estimateBlocks)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            SheetBackground()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Theme.s(4)) {
                        Text(isEditing ? "Edit task" : "New task")
                            .font(Theme.font(24, .semibold, design: .rounded))
                            .foregroundStyle(Theme.cream)
                        Text("Give it a shape, then give it a block.")
                            .font(Theme.font(10.5, .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(Theme.font(9, .bold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 27, height: 27)
                            .background { Circle().fill(Theme.cream.opacity(0.14)) }
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: Theme.s(7)) {
                    SectionLabel(text: "Outcome")
                    TextField("What needs doing?", text: $title)
                        .textFieldStyle(.plain)
                        .font(Theme.font(13, .medium))
                        .foregroundStyle(Theme.cream)
                        .tint(Theme.accent)
                        .focused($titleFocused)
                        .padding(.horizontal, Theme.s(12))
                        .frame(height: 40)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.radius(10), style: .continuous)
                                .fill(Theme.cream.opacity(0.14))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.radius(10), style: .continuous)
                                .strokeBorder(titleFocused ? Theme.accent.opacity(0.6) : Theme.cream.opacity(0.2), lineWidth: 1)
                        }
                }
                .padding(.top, Theme.s(22))

                SectionLabel(text: "Priority")
                    .padding(.top, Theme.s(19))
                    .padding(.bottom, Theme.s(8))

                HStack(spacing: Theme.s(8)) {
                    ForEach(TaskPriority.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { priority = option }
                        } label: {
                            HStack(spacing: Theme.s(6)) {
                                Image(systemName: option.icon)
                                    .font(Theme.font(10, .semibold))
                                    .foregroundStyle(option.tint.opacity(priority == option ? 1 : 0.65))
                                Text(option.title)
                                    .font(Theme.font(10.5, .semibold))
                                    .foregroundStyle(Theme.cream.opacity(priority == option ? 0.95 : 0.75))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                                    .fill(priority == option ? option.tint.opacity(0.26) : Theme.cream.opacity(0.12))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                                    .strokeBorder(priority == option ? option.tint.opacity(0.6) : Theme.cream.opacity(0.18), lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: Theme.s(12)) {
                    VStack(alignment: .leading, spacing: Theme.s(3)) {
                        SectionLabel(text: "Estimate")
                        Text("Each block is \(model.timer.config.focusMinutes) minutes")
                            .font(Theme.font(9, .medium))
                            .foregroundStyle(Theme.mutedDim)
                    }
                    Spacer()
                    HStack(spacing: Theme.s(6)) {
                        MiniStepperButton(icon: "minus", enabled: estimateBlocks > 1) {
                            estimateBlocks = max(1, estimateBlocks - 1)
                        }
                        Text("\(estimateBlocks) \(estimateBlocks == 1 ? "block" : "blocks")")
                            .font(Theme.font(10.5, .semibold, design: .monospaced))
                            .foregroundStyle(Theme.cream)
                            .frame(width: 62)
                        MiniStepperButton(icon: "plus", enabled: estimateBlocks < 24) {
                            estimateBlocks = min(24, estimateBlocks + 1)
                        }
                    }
                }
                .padding(.top, Theme.s(18))

                Spacer(minLength: 16)

                HStack(spacing: Theme.s(9)) {
                    Spacer()
                    QuietButton(title: "Cancel") { dismiss() }
                    AccentButton(title: isEditing ? "Save task" : "Add task", icon: "checkmark") {
                        guard !trimmedTitle.isEmpty else { return }
                        onSave(trimmedTitle, priority, estimateBlocks)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .opacity(trimmedTitle.isEmpty ? 0.5 : 1)
                }
            }
            .padding(Theme.s(24))
        }
        .frame(width: 500, height: 420)
        .preferredColorScheme(model.appearanceMode.colorScheme)
        .onAppear {
            titleFocused = true
        }
    }
}
