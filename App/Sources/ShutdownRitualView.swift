import SwiftUI

struct ShutdownRitualView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: YouTubePlayerController
    @State private var confirmClear = false

    private var openTasks: [TaskItem] { model.todayOpenTasks }
    private var completedTasks: [TaskItem] { model.todayCompletedTasks }

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()
                .onTapGesture { } // closing is a deliberate action

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(Theme.amber.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "moon.stars.fill")
                            .font(Theme.font(19, .medium))
                            .foregroundStyle(Theme.amber)
                    }

                    VStack(alignment: .leading, spacing: Theme.s(4)) {
                        Text("Shut down the day")
                            .font(Theme.font(25, .semibold, design: .rounded))
                            .foregroundStyle(Theme.cream)
                        Text("A clean ending makes tomorrow easier.")
                            .font(Theme.font(10.5, .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.leading, Theme.s(4))

                    Spacer()

                    Button {
                        model.showShutdown = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(Theme.font(9, .bold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 27, height: 27)
                            .background { Circle().fill(Theme.cream.opacity(0.05)) }
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 0) {
                    metric("\(model.timer.todayFocusMinutes)", "minutes focused")
                    divider
                    metric("\(completedTasks.count)", "tasks completed")
                    divider
                    metric("\(openTasks.count)", "left open")
                }
                .padding(.vertical, Theme.s(16))
                .padding(.top, Theme.s(4))

                HStack(alignment: .top, spacing: Theme.s(14)) {
                    VStack(alignment: .leading, spacing: Theme.s(8)) {
                        SectionLabel(text: "Completed today")
                        if completedTasks.isEmpty {
                            emptyLine("Nothing checked off yet — that is allowed.")
                        } else {
                            ForEach(completedTasks.prefix(5)) { task in
                                taskLine(task, completed: true)
                            }
                            if completedTasks.count > 5 {
                                Text("+ \(completedTasks.count - 5) more")
                                    .font(Theme.font(9, .medium))
                                    .foregroundStyle(Theme.mutedDim)
                                    .padding(.leading, Theme.s(20))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: Theme.s(8)) {
                        SectionLabel(text: "Still open")
                        if openTasks.isEmpty {
                            emptyLine("Your list is clear.")
                        } else {
                            ForEach(openTasks.prefix(5)) { task in
                                taskLine(task, completed: false)
                            }
                            if openTasks.count > 5 {
                                Text("+ \(openTasks.count - 5) more")
                                    .font(Theme.font(9, .medium))
                                    .foregroundStyle(Theme.mutedDim)
                                    .padding(.leading, Theme.s(20))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(Theme.s(15))
                .frame(maxHeight: .infinity, alignment: .top)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius(15), style: .continuous)
                        .fill(Theme.cream.opacity(0.025))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radius(15), style: .continuous)
                        .strokeBorder(Theme.cream.opacity(0.055), lineWidth: 1)
                }

                HStack(spacing: Theme.s(9)) {
                    Button {
                        player.pause()
                    } label: {
                        HStack(spacing: Theme.s(6)) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "speaker.slash.fill")
                                .font(Theme.font(9, .semibold))
                            Text(player.isPlaying ? "Pause music" : "Music paused")
                                .font(Theme.font(10, .medium))
                        }
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.s(12))
                        .frame(height: 31)
                        .background { Capsule().fill(Theme.cream.opacity(0.045)) }
                    }
                    .buttonStyle(.plain)
                    .disabled(!player.isPlaying)
                    .opacity(player.isPlaying ? 1 : 0.55)

                    Button {
                        confirmClear = true
                    } label: {
                        HStack(spacing: Theme.s(6)) {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(Theme.font(9, .medium))
                            Text("Clear remaining")
                                .font(Theme.font(10, .medium))
                        }
                        .foregroundStyle(Theme.mutedDim)
                        .padding(.horizontal, Theme.s(12))
                        .frame(height: 31)
                        .background { Capsule().fill(Theme.cream.opacity(0.025)) }
                    }
                    .buttonStyle(.plain)
                    .disabled(openTasks.isEmpty)
                    .opacity(openTasks.isEmpty ? 0.45 : 1)

                    Spacer()

                    QuietButton(title: "Not yet") {
                        model.showShutdown = false
                    }
                    AccentButton(title: "Finish workday", icon: "moon.stars.fill") {
                        player.pause()
                        model.finishWorkday()
                    }
                }
                .padding(.top, Theme.s(14))
            }
            .padding(Theme.s(24))
            .frame(width: 650, height: 590)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius(28), style: .continuous)
                        .fill(Theme.surface.opacity(0.97))
                    RadialGradient(
                        colors: [Theme.amber.opacity(0.12), .clear],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 500
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius(28), style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(28), style: .continuous)
                    .strokeBorder(Theme.cream.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.48), radius: 45, x: 0, y: 28)
        }
        .alert("Clear remaining tasks?", isPresented: $confirmClear) {
            Button("Clear tasks", role: .destructive) {
                model.clearOpenTasks()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(openTasks.count) open tasks will be removed. Completed tasks stay in your history.")
        }
        .onExitCommand {
            model.showShutdown = false
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 34)
            .padding(.horizontal, Theme.s(18))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.s(2)) {
            Text(value)
                .font(Theme.font(23, .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.cream)
            Text(label)
                .font(Theme.font(9, .medium))
                .foregroundStyle(Theme.mutedDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taskLine(_ task: TaskItem, completed: Bool) -> some View {
        HStack(spacing: Theme.s(7)) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .font(Theme.font(9.5, .medium))
                .foregroundStyle(completed ? Theme.mint : task.quadrant.tint.opacity(0.65))
            Text(task.title)
                .font(Theme.font(9.5, .medium))
                .foregroundStyle(completed ? Theme.mutedDim : Theme.muted)
                .strikethrough(completed, color: Theme.mutedDim)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(9.5, .medium))
            .foregroundStyle(Theme.mutedDim.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
    }
}
