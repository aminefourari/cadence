import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editorMode: TaskEditorMode?
    @State private var taskToDelete: TaskItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 16)

            HStack(alignment: .top, spacing: Theme.s(16)) {
                matrix
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                PlanPanel()
                    .frame(width: 236)
                    .frame(maxHeight: .infinity)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, Theme.s(34))
        .padding(.top, Theme.s(40))
        .padding(.bottom, Theme.s(22))
        .sheet(item: $editorMode) { mode in
            TaskEditorView(mode: mode) { title, quadrant, estimate in
                switch mode {
                case .add:
                    model.addTask(title: title, quadrant: quadrant, estimateBlocks: estimate)
                case .edit(let task):
                    model.updateTask(task, title: title, quadrant: quadrant, estimateBlocks: estimate)
                }
            }
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
                    Text("SORT THE NOISE, THEN BLOCK THE DAY")
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
                StatusPill(
                    text: "\(model.plan.focusMinutes) min planned",
                    color: Theme.sky
                )
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

    private var matrix: some View {
        VStack(spacing: Theme.s(12)) {
            HStack(spacing: Theme.s(12)) {
                QuadrantCell(
                    quadrant: .urgentImportant,
                    onEdit: { editorMode = .edit($0) },
                    onDelete: { taskToDelete = $0 },
                    onFocus: focus(task:)
                )
                QuadrantCell(
                    quadrant: .importantNotUrgent,
                    onEdit: { editorMode = .edit($0) },
                    onDelete: { taskToDelete = $0 },
                    onFocus: focus(task:)
                )
            }
            HStack(spacing: Theme.s(12)) {
                QuadrantCell(
                    quadrant: .urgentNotImportant,
                    onEdit: { editorMode = .edit($0) },
                    onDelete: { taskToDelete = $0 },
                    onFocus: focus(task:)
                )
                QuadrantCell(
                    quadrant: .neither,
                    onEdit: { editorMode = .edit($0) },
                    onDelete: { taskToDelete = $0 },
                    onFocus: focus(task:)
                )
            }
        }
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

private struct QuadrantCell: View {
    @EnvironmentObject private var model: AppModel
    let quadrant: TaskQuadrant
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onFocus: (TaskItem) -> Void

    @State private var targeted = false

    private var tasks: [TaskItem] {
        model.tasks
            .filter { $0.quadrant == quadrant }
            .sorted { lhs, rhs in
                if lhs.done != rhs.done { return !lhs.done }
                return lhs.createdAtMs < rhs.createdAtMs
            }
    }

    private var openCount: Int {
        tasks.filter { !$0.done }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.s(8)) {
                ZStack {
                    Circle()
                        .fill(quadrant.tint.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: quadrant.icon)
                        .font(Theme.font(10.5, .semibold))
                        .foregroundStyle(quadrant.tint)
                }

                VStack(alignment: .leading, spacing: Theme.s(1)) {
                    Text(quadrant.title)
                        .font(Theme.font(11.5, .semibold))
                        .foregroundStyle(Theme.cream.opacity(0.9))
                    Text(quadrant.detail)
                        .font(Theme.font(9, .medium))
                        .foregroundStyle(Theme.mutedDim)
                }

                Spacer()

                Text("\(openCount)")
                    .font(Theme.font(10, .semibold, design: .monospaced))
                    .foregroundStyle(quadrant.tint.opacity(0.9))
                    .padding(.horizontal, Theme.s(6))
                    .frame(height: 20)
                    .background { Capsule().fill(quadrant.tint.opacity(0.09)) }
            }
            .padding(.bottom, Theme.s(10))

            if tasks.isEmpty {
                VStack(spacing: Theme.s(5)) {
                    Image(systemName: "plus.circle.dashed")
                        .font(Theme.font(17, .light))
                        .foregroundStyle(Theme.mutedDim.opacity(0.5))
                    Text("Drop a task here")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: Theme.s(5)) {
                        ForEach(tasks) { task in
                            TaskRow(task: task, onEdit: onEdit, onDelete: onDelete, onFocus: onFocus)
                        }
                    }
                    .padding(.bottom, Theme.s(2))
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(Theme.s(13))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(20), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [quadrant.tint.opacity(targeted ? 0.09 : 0.035), Theme.cream.opacity(0.018)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius(20), style: .continuous)
                        .fill(Theme.surface.opacity(0.7))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(20), style: .continuous)
                .strokeBorder(
                    targeted ? quadrant.tint.opacity(0.45) : Theme.cream.opacity(0.055),
                    style: StrokeStyle(lineWidth: 1, dash: targeted ? [5, 4] : [])
                )
        }
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first,
                  let task = model.tasks.first(where: { $0.id == id }) else { return false }
            guard task.quadrant != quadrant else { return false }
            model.updateTask(
                task,
                title: task.title,
                quadrant: quadrant,
                estimateBlocks: task.estimateBlocks
            )
            return true
        } isTargeted: { value in
            withAnimation(.easeOut(duration: 0.18)) { targeted = value }
        }
    }
}

private struct TaskRow: View {
    @EnvironmentObject private var model: AppModel
    let task: TaskItem
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onFocus: (TaskItem) -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.s(7)) {
            Button {
                model.toggleTask(task)
            } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(Theme.font(12, .medium))
                    .foregroundStyle(task.done ? task.quadrant.tint : Theme.mutedDim.opacity(hovered ? 0.9 : 0.55))
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(task.done ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: Theme.s(2)) {
                Text(task.title)
                    .font(Theme.font(10.5, task.done ? .regular : .medium))
                    .foregroundStyle(task.done ? Theme.mutedDim.opacity(0.65) : Theme.cream.opacity(0.9))
                    .strikethrough(task.done, color: Theme.mutedDim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(task.title)

                HStack(spacing: Theme.s(5)) {
                    Text("\(task.completedBlocks)/\(task.estimateBlocks) blocks")
                        .font(Theme.font(8.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                    if task.focusedMinutes > 0 {
                        Text("· \(task.focusedMinutes)m")
                            .font(Theme.font(8.5, .medium))
                            .foregroundStyle(Theme.mutedDim.opacity(0.8))
                    }
                }
            }

            Spacer(minLength: 2)

            if model.timer.activeTaskId == task.id {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 5, height: 5)
                    .shadow(color: Theme.accent.opacity(0.8), radius: 3)
            }

            Menu {
                Button {
                    onFocus(task)
                } label: {
                    Label("Focus now", systemImage: "scope")
                }
                Button {
                    onEdit(task)
                } label: {
                    Label("Edit task", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    onDelete(task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(Theme.font(9, .bold))
                    .foregroundStyle(Theme.mutedDim.opacity(hovered ? 0.9 : 0.35))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, Theme.s(6))
        .padding(.vertical, Theme.s(5))
        .frame(minHeight: 40)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                .fill(hovered ? Theme.cream.opacity(0.04) : Theme.cream.opacity(0.012))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                .strokeBorder(Theme.cream.opacity(0.035), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .opacity(task.done ? 0.62 : 1)
        .draggable(task.id)
    }
}

private struct PlanPanel: View {
    @EnvironmentObject private var model: AppModel

    private var targetLabel: String {
        let minutes = model.dailyTargetMinutes
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "Daily plan")
                Spacer()
                Text(targetLabel)
                    .font(Theme.font(10, .semibold, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: Theme.s(7)) {
                Text("Target focus")
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
                Spacer()
                MiniStepperButton(icon: "minus", enabled: model.dailyTargetMinutes > 30) {
                    model.adjustDailyTarget(byMinutes: -30)
                }
                MiniStepperButton(icon: "plus", enabled: model.dailyTargetMinutes < 720) {
                    model.adjustDailyTarget(byMinutes: 30)
                }
            }
            .padding(.top, Theme.s(7))

            HStack(spacing: Theme.s(7)) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.cream.opacity(0.06))
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: geometry.size.width * min(1, Double(model.plan.focusMinutes) / Double(max(1, model.dailyTargetMinutes))))
                    }
                }
                .frame(height: 4)
                Text("\(model.plan.focusMinutes)m")
                    .font(Theme.font(8.5, .medium, design: .monospaced))
                    .foregroundStyle(Theme.mutedDim)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.top, Theme.s(8))

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.vertical, Theme.s(12))

            if model.plan.blocks.isEmpty {
                VStack(spacing: Theme.s(7)) {
                    Image(systemName: "calendar.badge.clock")
                        .font(Theme.font(22, .light))
                        .foregroundStyle(Theme.mutedDim.opacity(0.5))
                    Text("Add tasks to generate a time-boxed day.")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Theme.s(12))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.plan.blocks) { block in
                            PlanBlockRow(block: block) {
                                guard let id = block.taskId,
                                      let task = model.tasks.first(where: { $0.id == id }) else { return }
                                model.assignTask(task)
                                model.selectTab(.focus)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            Text("5 min buffers included · starts at \(planStartLabel)")
                .font(Theme.font(8.5, .medium))
                .foregroundStyle(Theme.mutedDim.opacity(0.75))
                .lineLimit(1)
                .padding(.top, Theme.s(8))
        }
        .padding(Theme.s(15))
        .panel(cornerRadius: Theme.radius(22))
    }

    private var planStartLabel: String {
        guard model.plan.startAtMs > 0 else { return "—" }
        return Date(timeIntervalSince1970: Double(model.plan.startAtMs) / 1000)
            .formatted(date: .omitted, time: .shortened)
    }
}

private struct PlanBlockRow: View {
    let block: PlanBlock
    let onFocus: () -> Void

    @State private var hovered = false

    private var tint: Color {
        if block.kind.isFocus { return block.quadrant?.tint ?? Theme.accent }
        return block.kind == .longBreak ? Theme.sky : Theme.mint
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.s(7)) {
            Text(block.startDate.formatted(date: .omitted, time: .shortened))
                .font(Theme.font(8.5, .medium, design: .monospaced))
                .foregroundStyle(Theme.mutedDim)
                .frame(width: 36, alignment: .trailing)
                .padding(.top, Theme.s(2))

            VStack(spacing: 0) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .padding(.top, Theme.s(4))
                Rectangle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: Theme.s(2)) {
                Text(block.kind.isFocus ? (block.taskTitle ?? "Focus") : block.kind.title)
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(block.kind.isFocus ? Theme.cream.opacity(0.85) : Theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(block.kind.isFocus
                     ? "\(block.quadrant?.shortTitle ?? "Focus") · \(block.minutes)m"
                     : "Recovery · \(block.minutes)m")
                    .font(Theme.font(8, .medium))
                    .foregroundStyle(Theme.mutedDim)
            }

            Spacer(minLength: 2)

            if block.kind.isFocus {
                Button(action: onFocus) {
                    Image(systemName: "play.fill")
                        .font(Theme.font(7.5, .bold))
                        .foregroundStyle(hovered ? Theme.onAccent : Theme.mutedDim)
                        .frame(width: 19, height: 19)
                        .background { Circle().fill(hovered ? tint : Theme.cream.opacity(0.035)) }
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.s(1))
            }
        }
        .padding(.vertical, Theme.s(5))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
}

private struct MiniStepperButton: View {
    let icon: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.font(7.5, .bold))
                .foregroundStyle(enabled ? Theme.cream.opacity(0.7) : Theme.mutedDim.opacity(0.3))
                .frame(width: 18, height: 18)
                .background { Circle().fill(Theme.cream.opacity(enabled ? 0.045 : 0.02)) }
                .overlay { Circle().strokeBorder(Theme.cream.opacity(0.05), lineWidth: 1) }
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
    let onSave: (String, TaskQuadrant, Int) -> Void

    @State private var title: String
    @State private var quadrant: TaskQuadrant
    @State private var estimateBlocks: Int
    @FocusState private var titleFocused: Bool

    init(mode: TaskEditorMode, onSave: @escaping (String, TaskQuadrant, Int) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _title = State(initialValue: "")
            _quadrant = State(initialValue: .importantNotUrgent)
            _estimateBlocks = State(initialValue: 1)
        case .edit(let task):
            _title = State(initialValue: task.title)
            _quadrant = State(initialValue: task.quadrant)
            _estimateBlocks = State(initialValue: task.estimateBlocks)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        ZStack {
            AppBackground()

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
                            .background { Circle().fill(Theme.cream.opacity(0.05)) }
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
                                .fill(Theme.cream.opacity(0.04))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.radius(10), style: .continuous)
                                .strokeBorder(titleFocused ? Theme.accent.opacity(0.35) : Theme.cream.opacity(0.06), lineWidth: 1)
                        }
                }
                .padding(.top, Theme.s(22))

                SectionLabel(text: "Eisenhower quadrant")
                    .padding(.top, Theme.s(19))
                    .padding(.bottom, Theme.s(8))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.s(8)), GridItem(.flexible(), spacing: Theme.s(8))], spacing: Theme.s(8)) {
                    ForEach(TaskQuadrant.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { quadrant = option }
                        } label: {
                            HStack(spacing: Theme.s(7)) {
                                Image(systemName: option.icon)
                                    .font(Theme.font(10, .semibold))
                                    .foregroundStyle(option.tint.opacity(quadrant == option ? 1 : 0.65))
                                VStack(alignment: .leading, spacing: Theme.s(1)) {
                                    Text(option.shortTitle)
                                        .font(Theme.font(9.5, .semibold))
                                        .foregroundStyle(Theme.cream.opacity(quadrant == option ? 0.95 : 0.7))
                                    Text(option.title)
                                        .font(Theme.font(8, .medium))
                                        .foregroundStyle(Theme.mutedDim)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, Theme.s(9))
                            .frame(height: 43)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                                    .fill(quadrant == option ? option.tint.opacity(0.1) : Theme.cream.opacity(0.025))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                                    .strokeBorder(quadrant == option ? option.tint.opacity(0.28) : Theme.cream.opacity(0.045), lineWidth: 1)
                            }
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
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, quadrant, estimateBlocks)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
            .padding(Theme.s(24))
        }
        .frame(width: 500, height: 500)
        .preferredColorScheme(.dark)
        .onAppear {
            titleFocused = true
        }
    }
}
