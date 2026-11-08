import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: YouTubePlayerController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.top, Theme.s(48))

            SectionLabel(text: "Workspace")
                .padding(.leading, Theme.s(13))
                .padding(.top, Theme.s(34))

            VStack(spacing: Theme.s(6)) {
                ForEach(AppTab.allCases) { tab in
                    SidebarItem(
                        tab: tab,
                        selected: model.selectedTab == tab,
                        active: isActive(tab),
                        badge: badge(for: tab)
                    ) {
                        model.selectTab(tab)
                    }
                }
            }
            .padding(.top, Theme.s(10))

            Spacer(minLength: 18)

            TodaySidebarCard()
                .padding(.bottom, Theme.s(12))

            shutdownRow
                .padding(.bottom, Theme.s(2))

            preferencesRow

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.horizontal, Theme.s(2))
                .padding(.top, Theme.s(8))

            HStack {
                Text("v\(Updater.shared.currentVersion)")
                Spacer()
                Text("Swift × Rust")
            }
            .font(Theme.font(9.5, .medium, design: .monospaced))
            .foregroundStyle(Theme.mutedDim.opacity(0.75))
            .padding(.horizontal, Theme.s(4))
            .padding(.top, Theme.s(8))
            .padding(.bottom, Theme.s(16))
        }
        .padding(.horizontal, Theme.s(16))
        .frame(width: 232)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Theme.inkDeep.opacity(0.94), Theme.ink.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                LinearGradient(
                    colors: [Theme.accent.opacity(Theme.isLight ? 0.07 : 0.055), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                Rectangle()
                    .fill(Theme.controlFill.opacity(0.35))
            }
            .ignoresSafeArea()
        }
    }

    private var brand: some View {
        HStack(spacing: Theme.s(11)) {
            CadenceMark(size: 38)
            VStack(alignment: .leading, spacing: Theme.s(1)) {
                Text("Cadence")
                    .font(Theme.font(20, .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                Text("focus, with a soundtrack")
                    .font(Theme.font(9.5, .medium))
                    .tracking(0.15)
                    .foregroundStyle(Theme.mutedDim)
            }
        }
        .padding(.leading, Theme.s(3))
    }

    private var shutdownRow: some View {
        Button {
            model.openShutdown()
        } label: {
            HStack(spacing: Theme.s(10)) {
                Image(systemName: "moon.stars.fill")
                    .font(Theme.font(12, .medium))
                    .frame(width: 18)
                Text("End the day")
                    .font(Theme.font(12.5, .medium))
                Spacer()
                ShortcutHint(text: "⌘⇧E")
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, Theme.s(11))
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarHoverButtonStyle())
    }

    private var preferencesRow: some View {
        Button {
            model.openSettings()
        } label: {
            HStack(spacing: Theme.s(10)) {
                Image(systemName: "slider.horizontal.3")
                    .font(Theme.font(13, .medium))
                    .frame(width: 18)
                Text("Preferences")
                    .font(Theme.font(12.5, .medium))
                Spacer()
                ShortcutHint(text: "⌘,")
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, Theme.s(11))
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarHoverButtonStyle())
    }

    private func isActive(_ tab: AppTab) -> Bool {
        switch tab {
        case .focus: return model.timer.running
        case .tasks: return false
        case .music: return player.isPlaying
        case .history: return false
        }
    }

    private func badge(for tab: AppTab) -> Int? {
        guard tab == .tasks else { return nil }
        let count = model.openTasks.count
        return count > 0 ? count : nil
    }
}

private struct SidebarItem: View {
    let tab: AppTab
    let selected: Bool
    let active: Bool
    let badge: Int?
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s(11)) {
                Image(systemName: tab.icon)
                    .font(Theme.font(14, .medium))
                    .frame(width: 18)
                    .foregroundStyle(selected ? Theme.accentLight : Theme.muted)

                Text(tab.title)
                    .font(Theme.font(13.5, selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.cream : Theme.cream.opacity(0.65))

                Spacer()

                if let badge {
                    Text("\(badge)")
                        .font(Theme.font(9, .semibold, design: .monospaced))
                        .foregroundStyle(selected ? Theme.accentLight : Theme.mutedDim)
                        .padding(.horizontal, Theme.s(5))
                        .padding(.vertical, Theme.s(2))
                        .background {
                            Capsule().fill(Theme.cream.opacity(0.055))
                        }
                }

                if active {
                    Circle()
                        .fill(selected ? Theme.accent : Theme.mint)
                        .frame(width: 5, height: 5)
                        .shadow(color: (selected ? Theme.accent : Theme.mint).opacity(0.7), radius: 4)
                }
            }
            .padding(.horizontal, Theme.s(12))
            .frame(height: 42)
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(12), style: .continuous)
                    .fill(
                        selected
                            ? Theme.accent.opacity(0.105)
                            : (hovered ? Theme.cream.opacity(0.04) : .clear)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(12), style: .continuous)
                    .strokeBorder(
                        selected ? Theme.accent.opacity(0.18) : .clear,
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .leading) {
                if selected {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: 3, height: 18)
                        .offset(x: -1)
                        .shadow(color: Theme.accent.opacity(0.7), radius: 5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct SidebarHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                    .fill(Theme.cream.opacity(configuration.isPressed ? 0.08 : 0.001))
            }
            .foregroundStyle(Theme.muted.opacity(configuration.isPressed ? 0.75 : 1))
    }
}

struct TodaySidebarCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let timer = model.timer
        let cycle = max(1, timer.cycleLength)
        let filled = min(cycle, max(0, timer.completedInCycle))

        VStack(alignment: .leading, spacing: Theme.s(12)) {
            HStack {
                SectionLabel(text: "Today", tint: Theme.muted)
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(Theme.font(10))
                    .foregroundStyle(Theme.amber.opacity(0.8))
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.s(5)) {
                Text("\(timer.todayFocusMinutes)")
                    .font(Theme.font(29, .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.cream)
                Text("min focused")
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: Theme.s(5)) {
                ForEach(0..<cycle, id: \.self) { index in
                    Capsule()
                        .fill(index < filled ? Theme.accent : Theme.cream.opacity(0.075))
                        .frame(height: 4)
                }
            }

            HStack {
                Text("\(timer.todaySessions) \(timer.todaySessions == 1 ? "session" : "sessions")")
                Spacer()
                Text("\(model.todayCompletedTasks.count) done")
            }
            .font(Theme.font(10.5, .medium))
            .foregroundStyle(Theme.mutedDim)
        }
        .padding(Theme.s(14))
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(16), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.065), Theme.cream.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(16), style: .continuous)
                .strokeBorder(Theme.cream.opacity(0.065), lineWidth: 1)
        }
    }
}
