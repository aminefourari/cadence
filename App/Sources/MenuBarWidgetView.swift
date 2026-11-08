import AppKit
import SwiftUI

struct MenuBarWidgetView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: YouTubePlayerController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s(12)) {
            HStack(spacing: Theme.s(8)) {
                CadenceMark(size: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Cadence")
                        .font(Theme.font(12, .semibold, design: .rounded))
                        .foregroundStyle(Theme.cream)
                    Text(model.timer.phase.isBreak ? "Recovery time" : "Focus timer")
                        .font(Theme.font(8.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                }
                Spacer()
                statusDot
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.s(8)) {
                Text(model.timer.formattedRemaining)
                    .font(Theme.font(34, .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.cream)
                Text(model.timer.phase.title)
                    .font(Theme.font(9.5, .semibold))
                    .foregroundStyle(model.timer.phase.accent)
                    .padding(.horizontal, Theme.s(7))
                    .padding(.vertical, Theme.s(4))
                    .background { Capsule().fill(model.timer.phase.accent.opacity(0.1)) }
                Spacer(minLength: 0)
            }

            if let task = model.activeTask {
                HStack(spacing: Theme.s(6)) {
                    Image(systemName: "scope")
                        .font(Theme.font(8, .semibold))
                        .foregroundStyle(Theme.accent.opacity(0.8))
                    Text(task.title)
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            } else {
                Text("No task attached")
                    .font(Theme.font(10, .medium))
                    .foregroundStyle(Theme.mutedDim)
            }

            HStack(spacing: Theme.s(7)) {
                Button(action: toggle) {
                    HStack(spacing: Theme.s(5)) {
                        Image(systemName: model.timer.running ? "pause.fill" : "play.fill")
                            .font(Theme.font(9, .bold))
                        Text(model.timer.running ? "Pause" : "Start")
                            .font(Theme.font(10.5, .semibold))
                    }
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, Theme.s(12))
                    .frame(height: 30)
                    .background { Capsule().fill(Theme.accent) }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: model.resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(Theme.font(10, .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 30, height: 30)
                        .background { Circle().fill(Theme.controlFill) }
                        .overlay { Circle().strokeBorder(Theme.controlStroke, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Reset")

                Button(action: model.skipTimer) {
                    Image(systemName: "forward.end.fill")
                        .font(Theme.font(9, .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 30, height: 30)
                        .background { Circle().fill(Theme.controlFill) }
                        .overlay { Circle().strokeBorder(Theme.controlStroke, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Skip interval")

                Spacer()

                Button(action: openMain) {
                    Image(systemName: "macwindow")
                        .font(Theme.font(10.5, .semibold))
                        .foregroundStyle(Theme.cream.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background { Circle().fill(Theme.controlFill) }
                        .overlay { Circle().strokeBorder(Theme.controlStroke, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Open Cadence")
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)

            HStack(spacing: Theme.s(10)) {
                Button {
                    open(.focus)
                } label: {
                    widgetTab("Focus", icon: "timer")
                }
                .buttonStyle(.plain)

                Button {
                    open(.tasks)
                } label: {
                    widgetTab("Tasks", icon: "checklist")
                }
                .buttonStyle(.plain)

                Button {
                    open(.music)
                } label: {
                    widgetTab("Music", icon: "play.rectangle.fill")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(Theme.font(9, .medium))
                        .foregroundStyle(Theme.mutedDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.s(15))
        .frame(width: 300)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Theme.inkDeep, Theme.ink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Theme.accent.opacity(Theme.isLight ? 0.1 : 0.13), .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 280
                )
            }
        }
        .preferredColorScheme(model.appearanceMode.colorScheme)
    }

    private var statusDot: some View {
        HStack(spacing: Theme.s(5)) {
            Circle()
                .fill(model.timer.running ? Theme.accent : Theme.mutedDim)
                .frame(width: 5, height: 5)
            Text(model.timer.running ? "Running" : "Ready")
                .font(Theme.font(8.5, .medium))
                .foregroundStyle(Theme.mutedDim)
        }
    }

    private func widgetTab(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.s(4)) {
            Image(systemName: icon)
                .font(Theme.font(8.5, .semibold))
            Text(title)
                .font(Theme.font(9, .medium))
        }
        .foregroundStyle(Theme.muted)
        .contentShape(Rectangle())
    }

    private func toggle() {
        if !model.timer.running {
            openMain()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                model.requestTimerToggle()
            }
        } else {
            model.requestTimerToggle()
        }
    }

    private func open(_ tab: AppTab) {
        model.selectTab(tab)
        openMain()
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        dismiss()
    }
}
