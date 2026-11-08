import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PomodoroConfig.defaults
    @State private var loaded = false
    @State private var section: AppSettingsSection = .general

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.inkDeep, Theme.ink, Theme.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Theme.accent.opacity(Theme.isLight ? 0.09 : 0.13), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 560
            )

            VStack(alignment: .leading, spacing: 0) {
                header

                tabBar
                    .padding(.top, Theme.s(13))

                Group {
                    if section == .general {
                        generalContent
                    } else {
                        appearanceContent
                    }
                }
                .padding(.top, Theme.s(16))

                Spacer(minLength: 8)

                footer
                    .padding(.top, Theme.s(8))
            }
            .padding(Theme.s(22))

            if let toast = model.toast {
                VStack {
                    ToastView(toast: toast)
                        .padding(.top, Theme.s(14))
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .frame(width: 580, height: 700)
        .preferredColorScheme(model.appearanceMode.colorScheme)
        .onAppear {
            section = model.settingsSection
            guard !loaded else { return }
            draft = model.timer.config
            loaded = true
            Task { await model.refreshNotificationStatus() }
        }
        .onChange(of: model.settingsSection) { _, next in
            section = next
        }
    }

    private var tabBar: some View {
        HStack(spacing: Theme.s(4)) {
            ForEach(AppSettingsSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    HStack(spacing: Theme.s(5)) {
                        Image(systemName: item.icon)
                            .font(Theme.font(9, .semibold))
                        Text(item.title)
                            .font(Theme.font(10, .semibold))
                    }
                    .foregroundStyle(section == item ? Theme.cream : Theme.mutedDim)
                    .padding(.horizontal, Theme.s(11))
                    .frame(height: 27)
                    .background {
                        Capsule().fill(section == item ? Theme.controlFillHover : .clear)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(Theme.s(3))
        .background { Capsule().fill(Theme.controlFill) }
        .overlay { Capsule().strokeBorder(Theme.controlStroke, lineWidth: 1) }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: Theme.s(14)) {
            intervalsSection
            flowSection
            notificationsSection
        }
    }

    private var appearanceContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.s(12)) {
                appearanceSection
                appearanceModesSection
                animatedScenesSection
                backgroundImageSection
            }
            .padding(.bottom, Theme.s(4))
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.s(4)) {
                Text("Preferences")
                    .font(Theme.font(25, .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                Text("Shape a rhythm that fits your day.")
                    .font(Theme.font(11, .medium))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.font(10, .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 28, height: 28)
                    .background {
                        Circle().fill(Theme.controlFill)
                    }
                    .overlay {
                        Circle().strokeBorder(Theme.controlStroke, lineWidth: 1)
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: "Theme") {
            VStack(alignment: .leading, spacing: Theme.s(8)) {
                HStack(spacing: Theme.s(8)) {
                    ForEach(AppThemeMode.allCases) { mode in
                        ThemeChoiceCard(
                            mode: mode,
                            palette: mode == .dynamic
                                ? (Theme.isLight ? .dynamicLight : .dynamic)
                                : (Theme.isLight ? .cozyLight : .cozy),
                            selected: model.themeMode == mode
                        ) {
                            model.setTheme(mode)
                        }
                    }
                }

                Text("Each theme shapes type, spacing and corner radii — not just color.")
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
                    .padding(.leading, Theme.s(2))
            }
        }
    }

    private var appearanceModesSection: some View {
        SettingsSection(title: "Appearance") {
            HStack(spacing: Theme.s(7)) {
                ForEach(AppAppearance.allCases) { appearance in
                    AppearanceChoiceCard(
                        appearance: appearance,
                        selected: model.appearanceMode == appearance
                    ) {
                        model.setAppearance(appearance)
                    }
                }
            }
        }
    }

    private var animatedScenesSection: some View {
        SettingsSection(title: "Animated scenes") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Theme.s(8)), count: 3),
                spacing: Theme.s(8)
            ) {
                ForEach(AnimatedBackground.allCases) { scene in
                    AnimatedSceneTile(
                        scene: scene,
                        selected: model.backgroundStyle == .animated && model.animatedBackground == scene
                    ) {
                        model.setBackgroundScene(scene)
                    }
                }
            }
        }
    }

    private var backgroundImageSection: some View {
        SettingsSection(title: "Your image") {
            if let image = model.backgroundImage {
                HStack(spacing: Theme.s(11)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 43)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                                .strokeBorder(Theme.controlStroke, lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: Theme.s(2)) {
                        Text("Your background")
                            .font(Theme.font(11, .medium))
                            .foregroundStyle(Theme.cream.opacity(0.9))
                        Text(model.backgroundStyle == .image ? "In use now" : "Stored locally in Cadence")
                            .font(Theme.font(9, .medium))
                            .foregroundStyle(model.backgroundStyle == .image ? Theme.accent : Theme.mutedDim)
                    }

                    Spacer()

                    if model.backgroundStyle != .image {
                        SmallSettingsButton(title: "Use image") {
                            model.setBackgroundStyle(.image)
                        }
                    }
                    SmallSettingsButton(title: "Replace") {
                        model.chooseBackgroundImage()
                    }
                    SmallSettingsButton(title: "Remove", destructive: true) {
                        model.removeBackgroundImage()
                    }
                }
                .padding(Theme.s(10))
                .panel(cornerRadius: Theme.radius(14))
            } else {
                HStack(spacing: Theme.s(8)) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(Theme.mutedDim)
                    Text("Choose any photo from your Mac. Cadence keeps a local copy.")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                    Spacer(minLength: 4)
                    SmallSettingsButton(title: "Choose…") {
                        model.chooseBackgroundImage()
                    }
                }
                .padding(.horizontal, Theme.s(10))
                .frame(height: 42)
                .panel(cornerRadius: Theme.radius(14))
            }
        }
    }

    private var intervalsSection: some View {
        SettingsSection(title: "Intervals") {
            VStack(spacing: 0) {
                DurationRow(
                    icon: "scope",
                    title: "Focus",
                    caption: "Deep work",
                    accent: Theme.accent,
                    value: $draft.focusMinutes,
                    range: 5...90,
                    step: 5
                )
                SettingsDivider()
                DurationRow(
                    icon: "cup.and.saucer.fill",
                    title: "Short break",
                    caption: "Reset your eyes",
                    accent: Theme.mint,
                    value: $draft.shortBreakMinutes,
                    range: 1...30,
                    step: 1
                )
                SettingsDivider()
                DurationRow(
                    icon: "moon.stars.fill",
                    title: "Long break",
                    caption: "After a full cycle",
                    accent: Theme.sky,
                    value: $draft.longBreakMinutes,
                    range: 5...60,
                    step: 5
                )
                SettingsDivider()
                DurationRow(
                    icon: "repeat",
                    title: "Sessions per cycle",
                    caption: "Before a long break",
                    accent: Theme.amber,
                    value: $draft.sessionsBeforeLongBreak,
                    range: 2...8,
                    step: 1,
                    unit: ""
                )
            }
            .padding(.horizontal, Theme.s(14))
            .padding(.vertical, Theme.s(3))
            .panel(cornerRadius: Theme.radius(18))
        }
    }

    private var flowSection: some View {
        SettingsSection(title: "Flow") {
            HStack(spacing: Theme.s(12)) {
                ZStack {
                    Circle()
                        .fill(Theme.amber.opacity(0.1))
                        .frame(width: 30, height: 30)
                    Image(systemName: "bolt.fill")
                        .font(Theme.font(11, .semibold))
                        .foregroundStyle(Theme.amber.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: Theme.s(2)) {
                    Text("Auto-start the next interval")
                        .font(Theme.font(12, .medium))
                        .foregroundStyle(Theme.cream.opacity(0.9))
                    Text("Keep the cadence going without pressing play.")
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(Theme.mutedDim)
                }

                Spacer()

                Toggle("", isOn: $draft.autoStartNext)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    .controlSize(.small)
            }
            .padding(.horizontal, Theme.s(14))
            .frame(height: 62)
            .panel(cornerRadius: Theme.radius(18))
        }
    }

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            VStack(spacing: 0) {
                HStack(spacing: Theme.s(12)) {
                    ZStack {
                        Circle()
                            .fill(Theme.mint.opacity(0.1))
                            .frame(width: 30, height: 30)
                        Image(systemName: "bell.badge.fill")
                            .font(Theme.font(11, .semibold))
                            .foregroundStyle(Theme.mint.opacity(0.9))
                    }

                    VStack(alignment: .leading, spacing: Theme.s(2)) {
                        Text("Interval notifications")
                            .font(Theme.font(12, .medium))
                            .foregroundStyle(Theme.cream.opacity(0.9))
                        Text(model.notificationsAuthorized ? "Enabled in macOS" : "Allow Cadence to nudge you")
                            .font(Theme.font(10, .medium))
                            .foregroundStyle(Theme.mutedDim)
                    }

                    Spacer()

                    Button {
                        model.requestNotifications()
                    } label: {
                        Text(model.notificationsAuthorized ? "On" : "Enable")
                            .font(Theme.font(10.5, .semibold))
                            .foregroundStyle(model.notificationsAuthorized ? Theme.mint : Theme.cream.opacity(0.8))
                            .padding(.horizontal, Theme.s(12))
                            .frame(height: 27)
                            .background {
                                Capsule().fill(
                                    model.notificationsAuthorized
                                        ? Theme.mint.opacity(0.11)
                                        : Theme.controlFill
                                )
                            }
                            .overlay {
                                Capsule().strokeBorder(
                                    model.notificationsAuthorized
                                        ? Theme.mint.opacity(0.2)
                                        : Theme.controlStroke,
                                    lineWidth: 1
                                )
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(model.notificationsAuthorized)
                }
                .padding(.horizontal, Theme.s(14))
                .frame(height: 52)
            }
            .panel(cornerRadius: Theme.radius(18))
        }
    }

    private var footer: some View {
        VStack(spacing: Theme.s(12)) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)

            if section == .general {
                HStack(spacing: Theme.s(12)) {
                    Text("Saving resets the current interval.")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(Theme.font(11.5, .medium))
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, Theme.s(14))
                            .frame(height: 34)
                            .background {
                                Capsule().fill(Theme.controlFill)
                            }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)

                    Button {
                        if model.saveTimerConfig(draft) {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: Theme.s(5)) {
                            Text("Save changes")
                                .font(Theme.font(11.5, .semibold))
                            Image(systemName: "checkmark")
                                .font(Theme.font(9, .bold))
                        }
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, Theme.s(16))
                        .frame(height: 34)
                        .background {
                            Capsule().fill(Theme.accent)
                        }
                        .shadow(color: Theme.accent.opacity(0.25), radius: 12, x: 0, y: 5)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(draft == model.timer.config)
                    .opacity(draft == model.timer.config ? 0.55 : 1)
                }
            } else {
                HStack(spacing: Theme.s(12)) {
                    Text("Appearance changes apply immediately.")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: Theme.s(5)) {
                            Text("Done")
                                .font(Theme.font(11.5, .semibold))
                            Image(systemName: "checkmark")
                                .font(Theme.font(9, .bold))
                        }
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, Theme.s(18))
                        .frame(height: 34)
                        .background { Capsule().fill(Theme.accent) }
                    }
                    .buttonStyle(PressableStyle())
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

}

private struct ThemeChoiceCard: View {
    let mode: AppThemeMode
    let palette: ThemePalette
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s(9)) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.inkDeep, palette.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)

                    Text("Aa")
                        .font(Theme.font(15, .semibold, design: mode == .cozy ? .serif : .default))
                        .foregroundStyle(palette.cream)

                    HStack(spacing: Theme.s(2)) {
                        Circle().fill(palette.accent).frame(width: 3.5, height: 3.5)
                        Circle().fill(palette.mint).frame(width: 3.5, height: 3.5)
                        Circle().fill(palette.sky).frame(width: 3.5, height: 3.5)
                    }
                    .offset(y: 12)
                }

                VStack(alignment: .leading, spacing: Theme.s(1)) {
                    Text(mode.title)
                        .font(Theme.font(11, .semibold))
                        .foregroundStyle(selected ? Theme.cream : Theme.cream.opacity(0.72))
                    Text(mode.subtitle)
                        .font(Theme.font(8.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.font(11, .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.horizontal, Theme.s(10))
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(11), style: .continuous)
                    .fill(selected ? palette.accent.opacity(0.09) : Theme.controlFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(11), style: .continuous)
                    .strokeBorder(selected ? palette.accent.opacity(0.24) : Theme.controlStroke, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AppearanceChoiceCard: View {
    let appearance: AppAppearance
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.s(6)) {
                Image(systemName: appearance.icon)
                    .font(Theme.font(14, .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.muted)
                Text(appearance.title)
                    .font(Theme.font(10, .semibold))
                    .foregroundStyle(selected ? Theme.cream : Theme.muted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(11), style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.1) : Theme.controlFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(11), style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.25) : Theme.controlStroke, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AnimatedSceneTile: View {
    let scene: AnimatedBackground
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.s(6)) {
                AnimatedBackgroundView(scene: scene, compact: true)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radius(9), style: .continuous)
                            .strokeBorder(
                                selected ? Theme.accent.opacity(0.55) : Theme.cream.opacity(0.08),
                                lineWidth: selected ? 1.5 : 1
                            )
                    }
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(Theme.font(11, .semibold))
                                .foregroundStyle(Theme.cream, Theme.accent)
                                .padding(Theme.s(5))
                        }
                    }

                HStack(spacing: Theme.s(5)) {
                    Image(systemName: scene.icon)
                        .font(Theme.font(8.5, .semibold))
                    Text(scene.title)
                        .font(Theme.font(9.5, .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(selected ? Theme.cream : Theme.muted)
                .padding(.horizontal, Theme.s(2))
            }
            .padding(Theme.s(5))
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(12), style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.08) : Theme.controlFill.opacity(0.55))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(12), style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.22) : Theme.controlStroke, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(scene.subtitle)
    }
}

private struct SmallSettingsButton: View {
    let title: String
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.font(9.5, .medium))
                .foregroundStyle(destructive ? Theme.danger : Theme.cream.opacity(0.75))
                .padding(.horizontal, Theme.s(9))
                .frame(height: 25)
                .background {
                    Capsule().fill(destructive ? Theme.danger.opacity(0.1) : Theme.controlFill)
                }
                .overlay {
                    Capsule().strokeBorder(
                        destructive ? Theme.danger.opacity(0.18) : Theme.controlStroke,
                        lineWidth: 1
                    )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s(9)) {
            SectionLabel(text: title)
                .padding(.leading, Theme.s(2))
            content
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.leading, Theme.s(42))
    }
}

private struct DurationRow: View {
    let icon: String
    let title: String
    let caption: String
    let accent: Color
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var unit: String = "min"

    var body: some View {
        HStack(spacing: Theme.s(11)) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.1))
                    .frame(width: 29, height: 29)
                Image(systemName: icon)
                    .font(Theme.font(10.5, .semibold))
                    .foregroundStyle(accent.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: Theme.s(1)) {
                Text(title)
                    .font(Theme.font(11.5, .medium))
                    .foregroundStyle(Theme.cream.opacity(0.9))
                Text(caption)
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
            }

            Spacer()

            HStack(spacing: Theme.s(7)) {
                StepperButton(icon: "minus", enabled: value > range.lowerBound) {
                    value = max(range.lowerBound, value - step)
                }

                HStack(spacing: Theme.s(2)) {
                    Text("\(value)")
                        .font(Theme.font(12, .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Theme.cream)
                        .frame(minWidth: 18, alignment: .trailing)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(Theme.font(8.5, .medium))
                            .foregroundStyle(Theme.mutedDim)
                    }
                }
                .frame(width: 48)

                StepperButton(icon: "plus", enabled: value < range.upperBound) {
                    value = min(range.upperBound, value + step)
                }
            }
        }
        .frame(height: 46)
    }
}

private struct StepperButton: View {
    let icon: String
    let enabled: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.font(8.5, .bold))
                .foregroundStyle(enabled ? Theme.cream.opacity(hovered ? 0.95 : 0.65) : Theme.mutedDim.opacity(0.3))
                .frame(width: 22, height: 22)
                .background {
                    Circle().fill(enabled && hovered ? Theme.controlFillHover : Theme.controlFill)
                }
                .overlay {
                    Circle().strokeBorder(Theme.controlStroke, lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovered = $0 }
    }
}
