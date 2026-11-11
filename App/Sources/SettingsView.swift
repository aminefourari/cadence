import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var updater = Updater.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PomodoroConfig.defaults
    @State private var loaded = false
    @State private var section: AppSettingsSection = .timer
    @State private var shortcutNames: [String]?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 208)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                contentHeader
                    .padding(.horizontal, Theme.s(28))
                    .padding(.top, Theme.s(24))
                    .padding(.bottom, Theme.s(16))

                ScrollView(.vertical, showsIndicators: false) {
                    sectionContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.s(28))
                        .padding(.bottom, Theme.s(24))
                }
                .scrollBounceBehavior(.basedOnSize)
                .id(section)
            }
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: [Theme.inkDeep, Theme.ink, Theme.backgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Theme.accent.opacity(Theme.isLight ? 0.08 : 0.11), .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 620
                )
            }
        }
        .overlay(alignment: .top) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.top, Theme.s(14))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 800, height: 600)
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
        .onChange(of: draft) { _, next in
            guard loaded else { return }
            model.saveTimerConfig(next)
        }
        .onChange(of: model.timer.config) { _, next in
            if next != draft { draft = next }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Theme.s(4)) {
            HStack(spacing: Theme.s(10)) {
                CadenceMark(size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Preferences")
                        .font(Theme.font(14, .semibold, design: .rounded))
                        .foregroundStyle(Theme.cream)
                    Text("Changes apply instantly")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                }
            }
            .padding(.horizontal, Theme.s(8))
            .padding(.top, Theme.s(22))
            .padding(.bottom, Theme.s(18))

            ForEach(AppSettingsSection.allCases) { item in
                SettingsNavItem(
                    section: item,
                    selected: section == item,
                    badge: item == .updates && updater.hasUpdate
                ) {
                    withAnimation(.easeOut(duration: 0.15)) { section = item }
                }
            }

            Spacer()

            Text("Cadence \(updater.currentVersion)")
                .font(Theme.font(9.5, .medium, design: .monospaced))
                .foregroundStyle(Theme.mutedDim)
                .padding(.horizontal, Theme.s(8))
                .padding(.bottom, Theme.s(16))
        }
        .padding(.horizontal, Theme.s(12))
        .background(Theme.inkDeep.opacity(Theme.isLight ? 0.25 : 0.35))
    }

    private var contentHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.s(4)) {
                Text(section.title)
                    .font(Theme.font(24, .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                Text(section.subtitle)
                    .font(Theme.font(11, .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, Theme.s(16))
                    .frame(height: 30)
                    .background { Capsule().fill(Theme.accent) }
            }
            .buttonStyle(PressableStyle())
            .keyboardShortcut(.cancelAction)
            .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .timer:
            VStack(alignment: .leading, spacing: Theme.s(16)) {
                intervalsSection
                flowSection
                HStack {
                    Text(model.timer.running || !model.timer.isFreshInterval
                         ? "The interval in progress keeps its length. New lengths start with the next one."
                         : "Changes apply right away.")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                    Spacer()
                    if draft != .defaults {
                        SmallSettingsButton(title: "Restore defaults") { draft = .defaults }
                    }
                }
                .padding(.horizontal, Theme.s(2))
            }
        case .automation:
            automationContent
        case .appearance:
            VStack(alignment: .leading, spacing: Theme.s(16)) {
                appearanceSection
                appearanceModesSection
                animatedScenesSection
                backgroundImageSection
                backgroundVideoSection
            }
        case .notifications:
            notificationsSection
        case .agents:
            agentsSection
        case .updates:
            updatesSection
        }
    }

    // MARK: - AI agents (MCP)

    /// The MCP server shipped in the bundle (embedded by the "Embed cadence-mcp" build phase).
    private var mcpPath: String {
        Bundle.main.url(forAuxiliaryExecutable: "cadence-mcp")?.path
            ?? "/Applications/Cadence.app/Contents/MacOS/cadence-mcp"
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.s(16)) {
            Text("Cadence includes an MCP server, so any AI agent can add, edit and complete tasks, check the timer and start a focus block. Changes show up here instantly, and it works while Cadence is closed too. Register it once with each agent:")
                .font(Theme.font(11, .medium))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            SettingsSection(title: "Claude Code · run in Terminal") {
                snippet("claude mcp add --scope user cadence '\(mcpPath)'")
            }
            SettingsSection(title: "Codex · add to ~/.codex/config.toml") {
                snippet("[mcp_servers.cadence]\ncommand = \"\(mcpPath)\"")
            }
            SettingsSection(title: "opencode · add to opencode.json") {
                snippet("{\n  \"mcp\": {\n    \"cadence\": { \"type\": \"local\", \"command\": [\"\(mcpPath)\"] }\n  }\n}")
            }
            SettingsSection(title: "Any other MCP client · stdio command") {
                snippet(mcpPath)
            }
            SettingsSection(title: "What agents can do") {
                VStack(alignment: .leading, spacing: Theme.s(6)) {
                    ForEach(Self.mcpTools, id: \.0) { name, caption in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.s(10)) {
                            Text(name)
                                .font(Theme.font(10.5, .medium, design: .monospaced))
                                .foregroundStyle(Theme.cream)
                                .frame(width: 120, alignment: .leading)
                            Text(caption)
                                .font(Theme.font(10.5, .medium))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(Theme.s(14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel(cornerRadius: Theme.radius(18))
            }
            Text("Keep Cadence in Applications: the path above moves with the app. Try it by asking your agent \"add a high-priority task to Cadence\".")
                .font(Theme.font(9.5, .medium))
                .foregroundStyle(Theme.mutedDim)
                .padding(.horizontal, Theme.s(2))
        }
    }

    private static let mcpTools: [(String, String)] = [
        ("list_tasks", "Read the board, optionally with done or archived cards."),
        ("add_task", "New card with priority, estimate, deadline and column."),
        ("update_task", "Rename, reprioritize, re-estimate, reschedule, move or archive."),
        ("set_task_done", "Complete a task or reopen it."),
        ("delete_task", "Remove a task for good."),
        ("timer_status", "Phase, time left, active task and today's stats."),
        ("start_focus", "Start or resume focus, on a task, with an intention."),
        ("pause_timer", "Pause the running interval."),
        ("day_plan", "Time-box open tasks toward a daily target."),
        ("list_sessions", "Recent completed focus blocks."),
    ]

    private func snippet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.s(12)) {
            Text(text)
                .font(Theme.font(10.5, .medium, design: .monospaced))
                .foregroundStyle(Theme.cream)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            SmallSettingsButton(title: "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                model.showToast("Copied", "Paste it into your agent's setup.", icon: "doc.on.doc.fill", tint: Theme.mint)
            }
        }
        .padding(Theme.s(14))
        .panel(cornerRadius: Theme.radius(18))
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: Theme.s(16)) {
            SettingsSection(title: "This Mac") {
                updateStatusRow
            }
            SettingsSection(title: "Delivery") {
                toggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    tint: Theme.mint,
                    title: "Install updates automatically",
                    caption: "Downloads new releases in the background and restarts when you're not focusing or listening.",
                    isOn: $updater.installAutomatically
                )
                .panel(cornerRadius: Theme.radius(18))
            }
            SmallSettingsButton(title: "All releases on GitHub") { NSWorkspace.shared.open(updater.releasesPage) }
        }
    }

    private var updateStatusRow: some View {
            HStack(spacing: Theme.s(12)) {
                ZStack {
                    Circle()
                        .fill(Theme.sky.opacity(0.1))
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(Theme.font(11, .semibold))
                        .foregroundStyle(Theme.sky.opacity(0.9))
                }
                VStack(alignment: .leading, spacing: Theme.s(2)) {
                    Text("Cadence \(updater.currentVersion)")
                        .font(Theme.font(12, .medium))
                        .foregroundStyle(Theme.cream.opacity(0.9))
                    Text(updateStatus)
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(updateStatusIsError ? Theme.amber : Theme.mutedDim)
                        .lineLimit(2)
                }
                Spacer()
                switch updater.state {
                case .checking, .installing, .downloading:
                    ProgressView().controlSize(.small)
                case .available(let release), .ready(let release):
                    SmallSettingsButton(title: "Release notes") { NSWorkspace.shared.open(release.pageURL) }
                    SmallSettingsButton(title: "Restart & install") {
                        Task { await updater.install(release) }
                    }
                default:
                    SmallSettingsButton(title: "Check now") {
                        Task { await updater.check() }
                    }
                }
            }
            .padding(.horizontal, Theme.s(14))
            .frame(height: 58)
            .panel(cornerRadius: Theme.radius(18))
    }

    private var updateStatus: String {
        switch updater.state {
        case .idle: return "Checks GitHub for new releases every few hours."
        case .checking: return "Checking for updates…"
        case .upToDate: return "You're on the latest version."
        case .available(let release): return "Version \(release.version) is available. Cadence restarts to install it."
        case .downloading(let release): return "Downloading version \(release.version)…"
        case .ready(let release): return "Version \(release.version) installs when you're not focusing, or when you quit."
        case .installing: return "Installing… Cadence will restart."
        case .failed(let message): return message
        }
    }

    private var updateStatusIsError: Bool {
        if case .failed = updater.state { return true }
        return false
    }

    private var automationContent: some View {
        VStack(alignment: .leading, spacing: Theme.s(14)) {
            SettingsSection(title: "Music") {
                toggleRow(
                    icon: "music.note",
                    tint: Theme.sky,
                    title: "Music follows the timer",
                    caption: "Pause YouTube when focus stops, resume when it starts again.",
                    isOn: $model.musicFollowsTimer
                )
                .panel(cornerRadius: Theme.radius(18))
            }

            SettingsSection(title: "Focus guard") {
                VStack(spacing: 0) {
                    toggleRow(
                        icon: "shield.lefthalf.filled",
                        tint: Theme.accent,
                        title: "Nudge me when I drift",
                        caption: "A notification if one of these apps comes forward during focus.",
                        isOn: $model.focusGuardEnabled
                    )
                    SettingsDivider()
                    DistractingAppsRow()
                    .opacity(model.focusGuardEnabled ? 1 : 0.5)
                    .disabled(!model.focusGuardEnabled)
                }
                .panel(cornerRadius: Theme.radius(18))
            }

            SettingsSection(title: "Shortcuts") {
                VStack(alignment: .leading, spacing: 0) {
                    ShortcutPickerRow(title: "When focus starts", selection: $model.focusStartShortcut, available: shortcutNames)
                    SettingsDivider()
                    ShortcutPickerRow(title: "When focus stops", selection: $model.focusEndShortcut, available: shortcutNames)
                }
                .panel(cornerRadius: Theme.radius(18))
                .task { shortcutNames = await ShortcutsLibrary.names() }
                // Pick up shortcuts created in the Shortcuts app while Cadence was in the background.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { shortcutNames = await ShortcutsLibrary.names() }
                }

                Text("Pick a shortcut from the Shortcuts app, for example one that uses “Set Focus” to turn Do Not Disturb on and off.")
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
                    .padding(.leading, Theme.s(2))
            }
        }
    }

    private func toggleRow(
        icon: String,
        tint: Color,
        title: String,
        caption: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: Theme.s(12)) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(tint.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: Theme.s(2)) {
                Text(title)
                    .font(Theme.font(12, .medium))
                    .foregroundStyle(Theme.cream.opacity(0.9))
                Text(caption)
                    .font(Theme.font(10, .medium))
                    .foregroundStyle(Theme.mutedDim)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .controlSize(.small)
        }
        .padding(.horizontal, Theme.s(14))
        .frame(height: 62)
    }

    private var appearanceSection: some View {
        SettingsSection(title: "Theme") {
            VStack(alignment: .leading, spacing: Theme.s(8)) {
                HStack(spacing: Theme.s(8)) {
                    ForEach(AppThemeMode.allCases) { mode in
                        ThemeChoiceCard(
                            mode: mode,
                            palette: .resolve(mode, light: Theme.isLight),
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
        VStack(alignment: .leading, spacing: Theme.s(12)) {
            themePhotoSection
            sceneGrid(title: "Ambient scenes", scenes: AnimatedBackground.allCases, columns: 2, height: 64)
        }
    }

    private var themePhotoSection: some View {
        SettingsSection(title: "Theme photo") {
            let selected = model.backgroundStyle == .theme
            Button {
                model.setBackgroundStyle(.theme)
            } label: {
                HStack(spacing: Theme.s(11)) {
                    Image(model.themeMode.photoName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 43)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous))
                    VStack(alignment: .leading, spacing: Theme.s(2)) {
                        Text("\(model.themeMode.title) photo")
                            .font(Theme.font(11, .semibold))
                            .foregroundStyle(Theme.cream)
                        Text("Changes with your theme · Photo by \(model.themeMode.photoCredit) on Unsplash")
                            .font(Theme.font(9, .medium))
                            .foregroundStyle(selected ? Theme.accent : Theme.mutedDim)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Theme.font(12, .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(Theme.s(8))
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius(11), style: .continuous)
                        .fill(selected ? Theme.accent.opacity(0.08) : Theme.controlFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radius(11), style: .continuous)
                        .strokeBorder(selected ? Theme.accent.opacity(0.3) : Theme.controlStroke, lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func sceneGrid(title: String, scenes: [AnimatedBackground], columns: Int, height: CGFloat) -> some View {
        SettingsSection(title: title) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Theme.s(8)), count: columns),
                spacing: Theme.s(8)
            ) {
                ForEach(scenes) { scene in
                    AnimatedSceneTile(
                        scene: scene,
                        previewHeight: height,
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

    private var backgroundVideoSection: some View {
        SettingsSection(title: "Your video") {
            HStack(spacing: Theme.s(8)) {
                Image(systemName: "film")
                    .font(Theme.font(10, .medium))
                    .foregroundStyle(Theme.mutedDim)
                Text(model.backgroundVideoURL == nil
                     ? "Loop any video behind Cadence, muted. Try a rainy café or forest clip."
                     : (model.backgroundStyle == .video ? "Your video is playing" : "Stored locally in Cadence"))
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(model.backgroundStyle == .video ? Theme.accent : Theme.mutedDim)
                Spacer(minLength: 4)
                if model.backgroundVideoURL != nil {
                    if model.backgroundStyle != .video {
                        SmallSettingsButton(title: "Use video") { model.setBackgroundStyle(.video) }
                    }
                    SmallSettingsButton(title: "Replace") { model.chooseBackgroundVideo() }
                    SmallSettingsButton(title: "Remove", destructive: true) { model.removeBackgroundVideo() }
                } else {
                    SmallSettingsButton(title: "Choose…") { model.chooseBackgroundVideo() }
                }
            }
            .padding(.horizontal, Theme.s(10))
            .frame(height: 42)
            .panel(cornerRadius: Theme.radius(14))
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
        SettingsSection(title: "Interval alerts") {
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

}

private struct SettingsNavItem: View {
    let section: AppSettingsSection
    let selected: Bool
    var badge = false
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s(10)) {
                Image(systemName: section.icon)
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(selected ? Theme.accent : Theme.muted)
                    .frame(width: 18)
                Text(section.title)
                    .font(Theme.font(12, selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.cream : Theme.muted)
                Spacer()
                if badge {
                    Circle().fill(Theme.mint).frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, Theme.s(10))
            .frame(height: 34)
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(10), style: .continuous)
                    .fill(selected ? Theme.controlFillHover : (hovered ? Theme.controlFill : .clear))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
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
                        .font(Theme.font(15, .semibold, design: ThemeStyle.resolve(mode).fontDesign))
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
                        .lineLimit(12)
                        .fixedSize(horizontal: false, vertical: true)
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
    var previewHeight: CGFloat = 48
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.s(6)) {
                AnimatedBackgroundView(scene: scene, compact: true)
                    .frame(height: previewHeight)
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

private struct DistractingAppsRow: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPicker = false

    var body: some View {
        HStack(spacing: Theme.s(12)) {
            Text("Distracting apps")
                .font(Theme.font(11, .medium))
                .foregroundStyle(Theme.cream.opacity(0.85))
                .frame(width: 130, alignment: .leading)

            Button {
                showPicker = true
            } label: {
                HStack(spacing: Theme.s(8)) {
                    Text(summary)
                        .font(Theme.font(11, .medium))
                        .foregroundStyle(model.distractingAppList.isEmpty ? Theme.muted : Theme.cream)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Theme.font(9, .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, Theme.s(10))
                .frame(height: 28)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                        .fill(Theme.controlFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                        .strokeBorder(Theme.controlStroke, lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                AppPickerList()
                    .environmentObject(model)
            }
        }
        .padding(.horizontal, Theme.s(14))
        .frame(height: 48)
    }

    private var summary: String {
        let names = model.distractingAppList
        switch names.count {
        case 0: return "None selected"
        case 1...3: return names.joined(separator: ", ")
        default: return names.prefix(2).joined(separator: ", ") + " +\(names.count - 2) more"
        }
    }
}

private struct AppPickerList: View {
    @EnvironmentObject private var model: AppModel
    @State private var installed: [InstalledApp]?
    @State private var query = ""

    /// Installed apps plus anything already selected that isn't installed, so it can still be unticked.
    private var apps: [InstalledApp] {
        let installed = installed ?? []
        let known = Set(installed.map(\.id))
        let missing = model.distractingAppList
            .filter { !known.contains($0.lowercased()) }
            .map { InstalledApp(name: $0, url: nil) }
        let all = (missing + installed).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        let selected = Set(model.distractingAppList.map { $0.lowercased() })
        VStack(spacing: 0) {
            HStack(spacing: Theme.s(6)) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.muted)
                TextField("Search apps", text: $query)
                    .textFieldStyle(.plain)
            }
            .font(Theme.font(11, .medium))
            .padding(.horizontal, Theme.s(10))
            .frame(height: 34)

            Divider()

            if installed == nil {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(apps) { app in
                            AppPickerRow(app: app, selected: selected.contains(app.id)) {
                                model.toggleDistractingApp(app.name)
                            }
                        }
                    }
                    .padding(.vertical, Theme.s(4))
                }
            }

            Divider()

            HStack {
                Text("\(selected.count) selected")
                    .font(Theme.font(10, .medium))
                    .foregroundStyle(Theme.muted)
                Spacer()
                if !selected.isEmpty {
                    Button("Clear") { model.distractingApps = "" }
                        .buttonStyle(.link)
                        .font(Theme.font(10, .medium))
                }
            }
            .padding(.horizontal, Theme.s(10))
            .frame(height: 30)
        }
        .frame(width: 280, height: 380)
        .task {
            installed = await Task.detached { InstalledApps.scan() }.value
        }
    }
}

private struct AppPickerRow: View {
    let app: InstalledApp
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s(8)) {
                Group {
                    if let url = app.url {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                    } else {
                        Image(systemName: "app.dashed")
                            .resizable()
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 20, height: 20)

                Text(app.name)
                    .font(Theme.font(11.5, .medium))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                if app.url == nil {
                    Text("not installed")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(Theme.font(13, .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.muted.opacity(0.6))
            }
            .padding(.horizontal, Theme.s(10))
            .frame(height: 30)
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(6), style: .continuous)
                    .fill(hovered ? Theme.controlFillHover : .clear)
                    .padding(.horizontal, Theme.s(4))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct ShortcutPickerRow: View {
    let title: String
    @Binding var selection: String
    /// nil while loading.
    let available: [String]?

    private var missing: Bool {
        guard let available, !selection.isEmpty else { return false }
        return !available.contains(selection)
    }

    var body: some View {
        HStack(spacing: Theme.s(12)) {
            Text(title)
                .font(Theme.font(11, .medium))
                .foregroundStyle(Theme.cream.opacity(0.85))
                .frame(width: 130, alignment: .leading)

            Menu {
                Button { selection = "" } label: { item("None", checked: selection.isEmpty) }
                Divider()
                if let available, !available.isEmpty {
                    ForEach(available, id: \.self) { name in
                        Button { selection = name } label: { item(name, checked: name == selection) }
                    }
                } else {
                    Text(available == nil ? "Loading shortcuts…" : "No shortcuts yet")
                }
                Divider()
                Button("Open Shortcuts…") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
            } label: {
                HStack(spacing: Theme.s(6)) {
                    if missing {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.amber)
                            .help("“\(selection)” isn't in the Shortcuts app anymore")
                    }
                    Text(selection.isEmpty ? "None" : selection)
                        .foregroundStyle(selection.isEmpty ? Theme.muted : Theme.cream)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Theme.font(9, .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .font(Theme.font(11, .medium))
                .padding(.horizontal, Theme.s(10))
                .frame(height: 28)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                        .fill(Theme.controlFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radius(8), style: .continuous)
                        .strokeBorder(Theme.controlStroke, lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.s(14))
        .frame(height: 48)
    }

    @ViewBuilder
    private func item(_ name: String, checked: Bool) -> some View {
        if checked {
            Label(name, systemImage: "checkmark")
        } else {
            Text(name)
        }
    }
}
