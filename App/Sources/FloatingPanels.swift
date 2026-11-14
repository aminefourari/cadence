import AppKit
import SwiftUI

/// Borderless panel that floats above other apps without activating Cadence.
final class FloatingPanel: NSPanel {
    var acceptsKey = false
    override var canBecomeKey: Bool { acceptsKey }

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }
}

// MARK: - Mini timer

@MainActor
final class MiniTimerController {
    static let shared = MiniTimerController()
    private static let frameName = "CadenceMiniTimer"
    private var panel: FloatingPanel?

    func setVisible(_ visible: Bool, model: AppModel) {
        guard visible else {
            panel?.orderOut(nil)
            return
        }
        let panel = self.panel ?? makePanel(model: model)
        self.panel = panel
        panel.orderFrontRegardless()
    }

    private func makePanel(model: AppModel) -> FloatingPanel {
        let panel = FloatingPanel(size: NSSize(width: 264, height: 64))
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: MiniTimerView().environmentObject(model))
        if !panel.setFrameUsingName(Self.frameName), let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.maxX - 284, y: screen.maxY - 84))
        }
        panel.setFrameAutosaveName(Self.frameName)
        return panel
    }
}

struct MiniTimerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let timer = model.timer
        HStack(spacing: Theme.s(10)) {
            Circle()
                .fill(timer.phase.accent)
                .frame(width: 7, height: 7)
                .opacity(timer.running ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 1) {
                Text(timer.formattedRemaining)
                    .font(Theme.font(21, .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.cream)
                Text(model.activeTask?.title ?? timer.phase.title)
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.s(4))

            miniButton(timer.running ? "pause.fill" : "play.fill", filled: true, help: timer.running ? "Pause" : "Start") {
                model.toggleTimerQuietly()
            }
            miniButton("goforward.5", help: "Add 5 minutes") { model.extendInterval(minutes: 5) }
            miniButton("forward.end.fill", help: "Skip interval") { model.skipTimer() }
        }
        .padding(.horizontal, Theme.s(14))
        .frame(width: 264, height: 64)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Theme.inkDeep, Theme.ink], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                Capsule()
                    .fill(timer.phase.accent.opacity(0.8))
                    .frame(width: proxy.size.width * (1 - timer.remainingFraction), height: 2)
            }
            .frame(height: 2)
            .padding(.horizontal, Theme.s(16))
            .padding(.bottom, Theme.s(5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.controlStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button("Open Cadence") { model.openMainWindow() }
            Button("Hide Mini Timer") { model.miniTimerVisible = false }
        }
        .preferredColorScheme(model.appearanceMode.colorScheme)
    }

    private func miniButton(_ icon: String, filled: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.font(10, .bold))
                .foregroundStyle(filled ? Theme.onAccent : Theme.cream.opacity(0.75))
                .frame(width: 28, height: 28)
                .background { Circle().fill(filled ? model.timer.phase.accent : Theme.controlFill) }
                .overlay { Circle().strokeBorder(filled ? .clear : Theme.controlStroke, lineWidth: 1) }
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
    }
}

// MARK: - Quick add

@MainActor
final class QuickAddController: NSObject, NSWindowDelegate {
    static let shared = QuickAddController()
    private var panel: FloatingPanel?

    func show(model: AppModel) {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = FloatingPanel(size: NSSize(width: 480, height: 104))
        panel.acceptsKey = true
        panel.delegate = self
        // A fresh view each time, so the field starts empty and focused.
        panel.contentView = NSHostingView(
            rootView: QuickAddView(close: { [weak self] in self?.close() }).environmentObject(model)
        )
        if let screen = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.midX - 240, y: screen.minY + screen.height * 0.68))
        }
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

struct QuickAddView: View {
    @EnvironmentObject private var model: AppModel
    let close: () -> Void
    @State private var title = ""
    @State private var priority: TaskPriority = .medium
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s(12)) {
            HStack(spacing: Theme.s(10)) {
                Image(systemName: "plus.circle.fill")
                    .font(Theme.font(17, .semibold))
                    .foregroundStyle(priority.tint)
                TextField("Add a task to Cadence…", text: $title)
                    .textFieldStyle(.plain)
                    .font(Theme.font(16, .medium))
                    .foregroundStyle(Theme.cream)
                    .focused($focused)
                    .onSubmit(submit)
            }
            HStack(spacing: Theme.s(6)) {
                ForEach(TaskPriority.allCases, id: \.self) { option in
                    Button { priority = option } label: {
                        Text(option.title)
                            .font(Theme.font(10, .semibold))
                            .foregroundStyle(priority == option ? Theme.onAccent : Theme.muted)
                            .padding(.horizontal, Theme.s(10))
                            .frame(height: 24)
                            .background { Capsule().fill(priority == option ? option.tint : Theme.controlFill) }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("↩ add · esc close")
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
            }
        }
        .padding(Theme.s(18))
        .frame(width: 480, height: 104)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Theme.inkDeep, Theme.ink], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.controlStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .preferredColorScheme(model.appearanceMode.colorScheme)
        .onAppear { focused = true }
        .onExitCommand(perform: close)
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return close() }
        model.addTask(title: trimmed, priority: priority, estimateBlocks: 1)
        close()
    }
}
