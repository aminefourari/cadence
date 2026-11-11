import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("focusShowsPlan") private var showPlan = false

    private var timerStack: some View {
        VStack(spacing: Theme.s(9)) {
            TimerDial(timer: model.timer)
            CurrentTaskBar()
            TimerControls(timer: model.timer)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 16)

            // Three columns when the window is wide; otherwise Session and Day plan share one.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Theme.s(24)) {
                    PlanPanel()
                        .frame(width: 236)
                        .frame(maxHeight: .infinity)
                    timerStack
                    FocusPanel()
                        .frame(width: 274)
                        .frame(maxHeight: .infinity)
                }

                HStack(alignment: .center, spacing: Theme.s(24)) {
                    timerStack
                    VStack(spacing: Theme.s(10)) {
                        PanelSwitch(showPlan: $showPlan)
                        if showPlan { PlanPanel() } else { FocusPanel() }
                    }
                    .frame(width: 274)
                    .frame(maxHeight: .infinity)
                }
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, Theme.s(34))
        .padding(.top, Theme.s(40))
        .padding(.bottom, Theme.s(22))
        .animation(.easeInOut(duration: 0.4), value: model.timer.phase)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.s(16)) {
            VStack(alignment: .leading, spacing: Theme.s(7)) {
                Text("Focus")
                    .font(Theme.font(31, .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .tracking(-0.4)

                HStack(spacing: Theme.s(8)) {
                    Text(model.dateLabel.uppercased())
                        .font(Theme.font(9.5, .semibold))
                        .tracking(1.35)
                        .foregroundStyle(Theme.mutedDim)
                    Circle()
                        .fill(Theme.mutedDim.opacity(0.55))
                        .frame(width: 2, height: 2)
                    Text(headerSubtitle)
                        .font(Theme.font(10.5, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: Theme.s(10)) {
                StatusPill(
                    text: statusText,
                    color: model.timer.phase.accent,
                    pulsing: model.timer.running
                )
                UtilityIconButton(
                    icon: "gearshape.fill",
                    help: "Preferences"
                ) {
                    model.showSettings = true
                }
            }
            .padding(.top, Theme.s(5))
        }
    }

    private var headerSubtitle: String {
        if model.timer.phase.isBreak {
            return model.timer.running ? "Recovery in progress" : "A pause is part of the work"
        }
        if let task = model.activeTask {
            if model.timer.running { return "Working on \(task.title)" }
            if !model.timer.isFreshInterval { return "Paused — \(task.title)" }
            return "Ready to focus on \(task.title)"
        }
        if model.timer.running { return "Deep work in progress" }
        return model.timer.isFreshInterval
            ? "Drop in a task. Make space for one thing."
            : "Paused — pick up where you left off"
    }

    private var statusText: String {
        if model.timer.running {
            return model.timer.phase == .focus ? "In focus" : "On a break"
        }
        return model.timer.isFreshInterval ? "Ready" : "Paused"
    }
}

struct TimerDial: View {
    @EnvironmentObject private var model: AppModel
    let timer: TimerState

    @State private var taskDropTargeted = false

    private let size: CGFloat = 320
    private let ringSize: CGFloat = 272

    private var color: Color { timer.phase.accent }

    var body: some View {
        ZStack {
            breathingGlow

            TickRing(size: size)

            Circle()
                .stroke(Theme.cream.opacity(0.055), lineWidth: 9)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: timer.remainingFraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.42),
                            color,
                            color.opacity(0.74),
                            color.opacity(0.42)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.45), radius: 8)
                .animation(.linear(duration: 0.25), value: timer.remainingFraction)

            Circle()
                .trim(from: 0, to: 0.0025)
                .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90 + 360 * timer.remainingFraction))

            dialContent
        }
        .frame(width: size, height: size)
        .overlay {
            if taskDropTargeted {
                Circle()
                    .strokeBorder(color.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                    .padding(Theme.s(4))
                    .transition(.opacity)
            }
        }
        .scaleEffect(taskDropTargeted ? 1.012 : 1)
        .animation(.easeOut(duration: 0.18), value: taskDropTargeted)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first,
                  let task = model.openTasks.first(where: { $0.id == id }) else { return false }
            model.assignTask(task)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.18)) {
                taskDropTargeted = targeted
            }
        }
    }

    private var dialContent: some View {
        VStack(spacing: Theme.s(10)) {
            HStack(spacing: Theme.s(6)) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .shadow(color: color.opacity(0.9), radius: 4)
                Text(timer.phase.title.uppercased())
                    .font(Theme.font(9.5, .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.muted)
            }

            Text(timer.formattedRemaining)
                .font(Theme.font(72, .semibold, design: .rounded))
                .monospacedDigit()
                .kerning(-1.5)
                .minimumScaleFactor(0.62)
                .lineLimit(1)
                .frame(width: 250)
                .foregroundStyle(Theme.cream)
                .shadow(color: .black.opacity(0.32), radius: 2, x: 0, y: 2)

            HStack(spacing: Theme.s(6)) {
                Text(stateCaption)
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.muted)
                Circle()
                    .fill(Theme.mutedDim.opacity(0.7))
                    .frame(width: 2.5, height: 2.5)
                if canAdjustLength {
                    lengthButton(icon: "minus", up: false)
                }
                Text(timer.hasCustomLength ? "\(timer.intervalMinutes) min · this one only" : "\(timer.intervalMinutes) min interval")
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(timer.hasCustomLength ? color.opacity(0.9) : Theme.mutedDim)
                if canAdjustLength {
                    lengthButton(icon: "plus", up: true)
                }
            }
        }
        .frame(width: 250)
        .offset(y: -1)
    }

    /// The length can change only before an interval starts.
    private var canAdjustLength: Bool {
        !timer.running && timer.isFreshInterval
    }

    private func lengthButton(icon: String, up: Bool) -> some View {
        Button {
            model.setIntervalLength(TimerState.lengthStep(from: timer.intervalMinutes, up: up))
        } label: {
            Image(systemName: icon)
                .font(Theme.font(8, .bold))
                .foregroundStyle(Theme.muted)
                .frame(width: 18, height: 18)
                .background { Circle().fill(Theme.controlFill) }
                .overlay { Circle().strokeBorder(Theme.controlStroke, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .help(up ? "Make this interval longer" : "Make this interval shorter")
    }

    private var stateCaption: String {
        if timer.running { return "remaining" }
        if timer.isFreshInterval { return "ready" }
        return "paused"
    }

    private var breathingGlow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !timer.running)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let wave = timer.running ? (sin(time * 1.35) + 1) / 2 : 0.18
            let intensity = 0.55 + wave * 0.45

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.22 * intensity),
                            color.opacity(0.06 * intensity),
                            .clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 174
                    )
                )
                .frame(width: 320, height: 320)
                .scaleEffect(timer.running ? 0.95 + wave * 0.07 : 0.98)
        }
        .allowsHitTesting(false)
    }
}

private struct TickRing: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let base = min(canvasSize.width, canvasSize.height) / 2

            for index in 0..<60 {
                let isMajor = index % 5 == 0
                // Explicit CGFloat math: mixed Double/CGFloat here times out older type checkers.
                let angle: CGFloat = CGFloat(index) / 60 * 2 * .pi - .pi / 2
                let dx: CGFloat = cos(angle)
                let dy: CGFloat = sin(angle)
                let outer: CGFloat = base - 8
                let inner: CGFloat = outer - (isMajor ? 9 : 4)

                var path = Path()
                path.move(to: CGPoint(x: center.x + dx * inner, y: center.y + dy * inner))
                path.addLine(to: CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))
                context.stroke(
                    path,
                    with: .color(Theme.cream.opacity(isMajor ? 0.21 : 0.08)),
                    lineWidth: isMajor ? 1.3 : 0.8
                )
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

struct CurrentTaskBar: View {
    @EnvironmentObject private var model: AppModel
    @State private var targeted = false

    var body: some View {
        HStack(spacing: Theme.s(9)) {
            if let task = model.activeTask {
                Image(systemName: task.priority.icon)
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(task.priority.tint)
                    .frame(width: 22, height: 22)
                    .background {
                        Circle().fill(task.priority.tint.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: Theme.s(1)) {
                    Text(task.title)
                        .font(Theme.font(11.5, .semibold))
                        .foregroundStyle(Theme.cream.opacity(0.92))
                        .lineLimit(1)
                    HStack(spacing: Theme.s(5)) {
                        Text("\(task.completedBlocks)/\(task.estimateBlocks) blocks")
                            .font(Theme.font(9.5, .medium))
                            .foregroundStyle(Theme.mutedDim)
                        if let intention = model.timer.intention, !intention.isEmpty {
                            Text("·")
                                .foregroundStyle(Theme.mutedDim)
                            Text("“\(intention)”")
                                .font(Theme.font(9.5, .medium))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 6)

                Button {
                    model.clearActiveTask()
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.font(8.5, .bold))
                        .foregroundStyle(Theme.mutedDim)
                        .frame(width: 22, height: 22)
                        .background { Circle().fill(Theme.cream.opacity(0.045)) }
                }
                .buttonStyle(.plain)
                .help("Unlink task")
            } else {
                Image(systemName: "hand.draw")
                    .font(Theme.font(11, .medium))
                    .foregroundStyle(Theme.muted)
                Text("Drag a task here or pick one from the queue")
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
        }
        .padding(.horizontal, Theme.s(11))
        .frame(height: 45)
        .frame(maxWidth: 360)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(12), style: .continuous)
                .fill(targeted ? Theme.accent.opacity(0.09) : Theme.controlFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(12), style: .continuous)
                .strokeBorder(
                    targeted ? Theme.accent.opacity(0.6) : Theme.cream.opacity(0.16),
                    style: StrokeStyle(lineWidth: 1, dash: model.activeTask == nil ? [5, 5] : [])
                )
        }
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first,
                  let task = model.openTasks.first(where: { $0.id == id }) else { return false }
            model.assignTask(task)
            return true
        } isTargeted: { value in
            withAnimation(.easeOut(duration: 0.18)) {
                targeted = value
            }
        }
    }
}

struct TimerControls: View {
    @EnvironmentObject private var model: AppModel
    let timer: TimerState

    private var color: Color { timer.phase.accent }

    var body: some View {
        HStack(spacing: Theme.s(17)) {
            Button {
                model.resetTimer()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(CircleControlStyle(size: 44))
            .help("Reset interval")

            Button {
                model.requestTimerToggle()
            } label: {
                Image(systemName: timer.running ? "pause.fill" : "play.fill")
                    .offset(x: timer.running ? 0 : 1.5)
            }
            .buttonStyle(CircleControlStyle(size: 64, accent: color, filled: true))
            .shadow(color: Theme.shadow, radius: 8, x: 0, y: 4)
            .help(timer.running ? "Pause timer" : "Start timer")

            Button {
                model.skipTimer()
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(CircleControlStyle(size: 44))
            .help("Skip to next interval")
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: Theme.s(5)) {
                ShortcutHint(text: "⌘↩")
                Text(timer.running ? "to pause" : "to start")
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.muted)
            }
            .offset(y: 24)
        }
        .padding(.bottom, Theme.s(6))
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
                            .opacity(0.35)
                            .frame(width: geometry.size.width * fraction(model.plan.doneMinutes + model.plan.focusMinutes))
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: geometry.size.width * fraction(model.plan.doneMinutes))
                    }
                }
                .frame(height: 4)
                .help("\(model.plan.doneMinutes)m done today, \(model.plan.focusMinutes)m planned")
                Text("\(model.plan.doneMinutes + model.plan.focusMinutes)m")
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
                    Image(systemName: targetMet ? "checkmark.seal" : "calendar.badge.clock")
                        .font(Theme.font(22, .light))
                        .foregroundStyle(Theme.mutedDim.opacity(0.5))
                    Text(targetMet
                         ? "Today's focus target is met. Raise it to plan more."
                         : "Add tasks to generate a time-boxed day.")
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
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            Text(lateCount > 0
                 ? "\(lateCount) \(lateCount == 1 ? "block misses its" : "blocks miss their") deadline · starts at \(planStartLabel)"
                 : "Deadlines first · 5 min buffers · starts at \(planStartLabel)")
                .font(Theme.font(8.5, .medium))
                .foregroundStyle(lateCount > 0 ? Theme.danger : Theme.mutedDim.opacity(0.75))
                .lineLimit(1)
                .padding(.top, Theme.s(8))
        }
        .padding(Theme.s(15))
        .panel(cornerRadius: Theme.radius(22))
    }

    private var targetMet: Bool {
        model.plan.doneMinutes >= model.dailyTargetMinutes
    }

    private var lateCount: Int {
        model.plan.blocks.filter(\.late).count
    }

    private func fraction(_ minutes: Int) -> Double {
        min(1, Double(minutes) / Double(max(1, model.dailyTargetMinutes)))
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
        if block.kind.isFocus { return block.priority?.tint ?? Theme.accent }
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
                Text(block.late
                     ? "Ends after the deadline · \(block.minutes)m"
                     : block.kind.isFocus
                     ? "\(block.priority.map { "\($0.title) priority" } ?? "Focus") · \(block.minutes)m"
                     : "Recovery · \(block.minutes)m")
                    .font(Theme.font(8, .medium))
                    .foregroundStyle(block.late ? Theme.danger : Theme.mutedDim)
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

/// Themed two-way switch between the Session and Day plan panels.
private struct PanelSwitch: View {
    @Binding var showPlan: Bool
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 0) {
            segment("Session", icon: "timer", isPlan: false)
            segment("Day plan", icon: "calendar", isPlan: true)
        }
        .padding(Theme.s(3))
        .background { Capsule().fill(Theme.controlFill) }
        .overlay { Capsule().strokeBorder(Theme.controlStroke, lineWidth: 1) }
    }

    private func segment(_ title: String, icon: String, isPlan: Bool) -> some View {
        let selected = showPlan == isPlan
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showPlan = isPlan }
        } label: {
            HStack(spacing: Theme.s(5)) {
                Image(systemName: icon)
                    .font(Theme.font(9.5, .semibold))
                Text(title)
                    .font(Theme.font(10.5, .semibold))
            }
            .foregroundStyle(selected ? Theme.onAccent : Theme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background {
                if selected {
                    Capsule()
                        .fill(Theme.accent)
                        .matchedGeometryEffect(id: "selection", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct FocusPanel: View {
    @EnvironmentObject private var model: AppModel

    private var timer: TimerState { model.timer }
    private var cycle: Int { max(1, timer.cycleLength) }
    private var filled: Int { min(cycle, max(0, timer.completedInCycle)) }
    private var queue: [TaskItem] {
        model.openTasks
            .filter { $0.id != model.timer.activeTaskId }
            .sorted { lhs, rhs in
                if lhs.priority.sortOrder != rhs.priority.sortOrder {
                    return lhs.priority.sortOrder < rhs.priority.sortOrder
                }
                return lhs.createdAtMs < rhs.createdAtMs
            }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "Session")
                Spacer()
                Text("\(filled) / \(cycle)")
                    .font(Theme.font(10, .semibold, design: .monospaced))
                    .foregroundStyle(Theme.mutedDim)
            }
            .padding(.bottom, Theme.s(11))

            VStack(spacing: Theme.s(6)) {
                ForEach(PomodoroPhase.allCases) { phase in
                    PhaseOptionRow(
                        phase: phase,
                        minutes: timer.config.minutes(for: phase),
                        selected: timer.phase == phase,
                        running: timer.running && timer.phase == phase
                    ) {
                        model.selectPhase(phase)
                    }
                }
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.vertical, Theme.s(13))

            if timer.phase.isBreak {
                BreakRitualCard()
            } else {
                focusQueue
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.vertical, Theme.s(13))

            SectionLabel(text: "Rhythm")
                .padding(.bottom, Theme.s(7))

            HStack(spacing: Theme.s(6)) {
                ForEach(0..<cycle, id: \.self) { index in
                    Capsule()
                        .fill(index < filled ? timer.phase.accent : Theme.cream.opacity(0.075))
                        .frame(height: 4)
                }
            }
            .padding(.bottom, Theme.s(6))

            Text(rhythmCaption)
                .font(Theme.font(9.5, .medium))
                .foregroundStyle(Theme.mutedDim)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: Theme.s(7)) {
                Image(systemName: "quote.opening")
                    .font(Theme.font(8.5, .semibold))
                    .foregroundStyle(Theme.accent.opacity(0.6))
                    .padding(.top, Theme.s(1))
                Text(focusNote)
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.muted.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.s(9))
            .padding(.vertical, Theme.s(9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                    .fill(Theme.cream.opacity(0.022))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                    .strokeBorder(Theme.cream.opacity(0.04), lineWidth: 1)
            }
            .padding(.top, Theme.s(11))

            Spacer(minLength: 8)

            HStack(spacing: Theme.s(10)) {
                metric(value: "\(timer.todayFocusMinutes)", label: "min today")
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1, height: 24)
                metric(value: "\(timer.todaySessions)", label: "sessions")
            }
        }
        .padding(Theme.s(16))
        .panel(cornerRadius: Theme.radius(24))
    }

    private var focusQueue: some View {
        VStack(alignment: .leading, spacing: Theme.s(7)) {
            HStack {
                SectionLabel(text: "Focus queue")
                Spacer()
                Button("View all") {
                    model.selectTab(.tasks)
                }
                .buttonStyle(.plain)
                .font(Theme.font(9, .medium))
                .foregroundStyle(Theme.mutedDim)
            }

            if queue.isEmpty {
                VStack(alignment: .leading, spacing: Theme.s(5)) {
                    Text("Your queue is clear.")
                        .font(Theme.font(10.5, .semibold))
                        .foregroundStyle(Theme.muted)
                    Text("Add a task, then drag it onto the timer.")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                }
                .padding(.vertical, Theme.s(12))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(queue) { task in
                    QueueTaskRow(task: task)
                }
            }
        }
    }

    private var rhythmCaption: String {
        if timer.phase == .longBreak {
            return "Long break in progress. Step away from the screen."
        }
        let remaining = max(0, cycle - filled)
        if remaining == 0 { return "A long break is next." }
        return "Long break after \(remaining) more \(remaining == 1 ? "focus session" : "focus sessions")."
    }

    private var focusNote: String {
        if let intention = timer.intention, !intention.isEmpty {
            return intention
        }
        if timer.phase.isBreak {
            return "No productivity required. Just let the work settle."
        }
        if let task = model.activeTask {
            return "Protect the next \(timer.config.focusMinutes) minutes for \(task.title)."
        }
        return "Protect this time. Everything else can wait."
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.s(2)) {
            Text(value)
                .font(Theme.font(18, .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.cream)
            Text(label)
                .font(Theme.font(9, .medium))
                .foregroundStyle(Theme.mutedDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QueueTaskRow: View {
    @EnvironmentObject private var model: AppModel
    let task: TaskItem

    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.s(8)) {
            Circle()
                .fill(task.priority.tint)
                .frame(width: 5, height: 5)
                .shadow(color: task.priority.tint.opacity(0.6), radius: 3)

            VStack(alignment: .leading, spacing: Theme.s(1)) {
                Text(task.title)
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.cream.opacity(0.85))
                    .lineLimit(1)
                Text("\(task.remainingBlocks) blocks left")
                    .font(Theme.font(8.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
            }

            Spacer(minLength: 4)

            Image(systemName: "line.3.horizontal")
                .font(Theme.font(8, .semibold))
                .foregroundStyle(Theme.mutedDim.opacity(hovered ? 0.8 : 0.3))
        }
        .padding(.horizontal, Theme.s(8))
        .frame(height: 37)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                .fill(hovered ? Theme.cream.opacity(0.045) : Theme.cream.opacity(0.018))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                .strokeBorder(Theme.cream.opacity(0.04), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture {
            model.assignTask(task)
        }
        .draggable(task.id)
        .help("Click or drag onto the timer")
    }
}

private struct PhaseOptionRow: View {
    let phase: PomodoroPhase
    let minutes: Int
    let selected: Bool
    let running: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s(9)) {
                ZStack {
                    Circle()
                        .fill(phase.accent.opacity(selected ? 0.16 : 0.07))
                        .frame(width: 27, height: 27)
                    Image(systemName: phase.icon)
                        .font(Theme.font(10, .semibold))
                        .foregroundStyle(phase.accent.opacity(selected ? 1 : 0.6))
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(phase.title)
                        .font(Theme.font(11, selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Theme.cream : Theme.cream.opacity(0.62))
                    Text("\(minutes) min")
                        .font(Theme.font(9, .medium))
                        .foregroundStyle(Theme.mutedDim)
                }

                Spacer()

                if selected {
                    ZStack {
                        Circle()
                            .fill(phase.accent)
                            .frame(width: 6, height: 6)
                            .shadow(color: phase.accent.opacity(0.8), radius: 4)
                        if running {
                            Circle()
                                .stroke(phase.accent.opacity(0.35), lineWidth: 1)
                                .frame(width: 13, height: 13)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.s(8))
            .frame(height: 42)
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(10), style: .continuous)
                    .fill(
                        selected
                            ? phase.accent.opacity(0.075)
                            : (hovered ? Theme.cream.opacity(0.035) : .clear)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(10), style: .continuous)
                    .strokeBorder(selected ? phase.accent.opacity(0.15) : .clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Break rituals

enum BreakRitual: String, CaseIterable, Identifiable {
    case breathe
    case stretch
    case eyes
    case hydrate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breathe: return "Box breathing"
        case .stretch: return "Neck & wrist reset"
        case .eyes: return "20-20-20"
        case .hydrate: return "Water & breath"
        }
    }

    var icon: String {
        switch self {
        case .breathe: return "wind"
        case .stretch: return "figure.cooldown"
        case .eyes: return "eye.fill"
        case .hydrate: return "drop.fill"
        }
    }

    var instruction: String {
        switch self {
        case .breathe: return "Inhale 4. Hold 4. Exhale 4. Hold 4."
        case .stretch: return "Roll your shoulders. Tilt your neck gently. Unclench your jaw."
        case .eyes: return "Look 20 feet away for 20 seconds. Blink slowly."
        case .hydrate: return "Drink a glass of water. Take three slow breaths."
        }
    }

    var tint: Color {
        switch self {
        case .breathe: return Theme.mint
        case .stretch: return Theme.amber
        case .eyes: return Theme.sky
        case .hydrate: return Theme.sky
        }
    }
}

struct BreakRitualCard: View {
    @State private var ritual: BreakRitual = .breathe

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s(8)) {
            HStack {
                SectionLabel(text: "Break ritual")
                Spacer()
                Button {
                    cycleRitual()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(Theme.font(8.5, .semibold))
                        .foregroundStyle(Theme.mutedDim)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Next ritual")
            }

            if ritual == .breathe {
                HStack(spacing: Theme.s(12)) {
                    BoxBreathingOrb()
                        .frame(width: 86, height: 86)
                    VStack(alignment: .leading, spacing: Theme.s(5)) {
                        Text(ritual.title)
                            .font(Theme.font(12, .semibold))
                            .foregroundStyle(Theme.cream)
                        Text(ritual.instruction)
                            .font(Theme.font(9.5, .medium))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                HStack(spacing: Theme.s(12)) {
                    ZStack {
                        Circle()
                            .fill(ritual.tint.opacity(0.1))
                            .frame(width: 68, height: 68)
                        Circle()
                            .strokeBorder(ritual.tint.opacity(0.2), lineWidth: 1)
                            .frame(width: 56, height: 56)
                        Image(systemName: ritual.icon)
                            .font(Theme.font(21, .light))
                            .foregroundStyle(ritual.tint)
                    }
                    VStack(alignment: .leading, spacing: Theme.s(5)) {
                        Text(ritual.title)
                            .font(Theme.font(12, .semibold))
                            .foregroundStyle(Theme.cream)
                        Text(ritual.instruction)
                            .font(Theme.font(9.5, .medium))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: Theme.s(5)) {
                ForEach(BreakRitual.allCases) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { ritual = option }
                    } label: {
                        Image(systemName: option.icon)
                            .font(Theme.font(9, .semibold))
                            .foregroundStyle(option == ritual ? option.tint : Theme.mutedDim.opacity(0.6))
                            .frame(width: 24, height: 20)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.radius(6), style: .continuous)
                                    .fill(option == ritual ? option.tint.opacity(0.1) : .clear)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(option.title)
                }
                Spacer()
                Text("Optional · 5 min")
                    .font(Theme.font(8.5, .medium))
                    .foregroundStyle(Theme.mutedDim.opacity(0.8))
            }
            .padding(.top, Theme.s(2))
        }
        .padding(Theme.s(10))
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(12), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ritual.tint.opacity(0.07), Theme.cream.opacity(0.018)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(12), style: .continuous)
                .strokeBorder(ritual.tint.opacity(0.13), lineWidth: 1)
        }
    }

    private func cycleRitual() {
        let all = BreakRitual.allCases
        guard let index = all.firstIndex(of: ritual) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            ritual = all[(index + 1) % all.count]
        }
    }
}

private struct BoxBreathingOrb: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let state = breathingState(at: context.date)
            ZStack {
                Circle()
                    .fill(Theme.mint.opacity(0.06))
                    .frame(width: 80, height: 80)
                    .scaleEffect(state.scale)
                Circle()
                    .strokeBorder(Theme.mint.opacity(0.28), lineWidth: 1)
                    .frame(width: 66, height: 66)
                    .scaleEffect(state.scale)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.mint.opacity(0.28), Theme.mint.opacity(0.05)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 38
                        )
                    )
                    .frame(width: 54, height: 54)
                    .scaleEffect(state.scale)
                Text(state.label)
                    .font(Theme.font(7.5, .semibold))
                    .foregroundStyle(Theme.mint.opacity(0.95))
            }
            .frame(width: 86, height: 86)
        }
    }

    private func breathingState(at date: Date) -> (scale: CGFloat, label: String) {
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 16)
        let phase = Int(cycle / 4)
        let fraction = cycle.truncatingRemainder(dividingBy: 4) / 4
        let eased = fraction * fraction * (3 - 2 * fraction)
        switch phase {
        case 0:
            return (CGFloat(0.72 + 0.28 * eased), "Breathe in")
        case 1:
            return (1, "Hold")
        case 2:
            return (CGFloat(1 - 0.28 * eased), "Breathe out")
        default:
            return (0.72, "Rest")
        }
    }
}
