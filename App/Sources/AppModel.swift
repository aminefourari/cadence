import AppKit
import Carbon.HIToolbox
import Foundation
import Security
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    /// The app's model, for App Intents (Shortcuts, Siri), which run outside any view.
    private(set) static weak var shared: AppModel?

    @Published var selectedTab: AppTab = .focus
    @Published private(set) var timer: TimerState = .placeholder
    @Published private(set) var tasks: [TaskItem] = [] {
        didSet { syncDeadlineReminders() }
    }
    @Published private(set) var plan: DayPlan = .empty
    @Published private(set) var sessions: [FocusSession] = [] {
        didSet { refreshWeek() }
    }
    /// This (Monday-to-Sunday) week against the weekly goal, from the core.
    @Published private(set) var week: WeekSummary = .empty
    @Published var showWeeklyReview = false
    /// Set when focus was paused because the Mac slept or sat idle.
    @Published var awayPrompt: AwayPrompt?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var notificationsAuthorized = false
    @Published private(set) var currentDate = Date()
    @Published var showSettings = false
    @Published var showIntentionPrompt = false
    @Published var showShutdown = false
    @Published var settingsSection: AppSettingsSection = .timer
    @Published var toast: ToastMessage?
    @Published private(set) var coreError: String?
    @Published var themeMode: AppThemeMode {
        didSet {
            Theme.mode = themeMode
            UserDefaults.standard.set(themeMode.rawValue, forKey: Self.themeKey)
        }
    }
    @Published var appearanceMode: AppAppearance {
        didSet {
            Theme.appearance = appearanceMode
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Self.appearanceKey)
        }
    }
    @Published var backgroundStyle: AppBackgroundStyle {
        didSet {
            UserDefaults.standard.set(backgroundStyle.rawValue, forKey: Self.backgroundKey)
        }
    }
    @Published var animatedBackground: AnimatedBackground {
        didSet {
            UserDefaults.standard.set(animatedBackground.rawValue, forKey: Self.animatedBackgroundKey)
        }
    }
    @Published private(set) var backgroundImage: NSImage?
    @Published private(set) var backgroundVideoURL: URL?
    /// Saved in the core (so cadence-mcp plans with it too); mirrors `plan.targetMinutes`.
    @Published var dailyTargetMinutes: Int {
        didSet {
            let clamped = min(720, max(30, dailyTargetMinutes))
            if clamped != dailyTargetMinutes {
                dailyTargetMinutes = clamped
                return
            }
            guard dailyTargetMinutes != plan.targetMinutes else { return }
            do {
                plan = try CoreClient.shared.setDailyTarget(
                    minutes: dailyTargetMinutes,
                    nowMs: CoreClient.nowMs(),
                    bufferMinutes: planBufferMinutes
                )
                lastPlanRefresh = Date()
            } catch {
                coreError = error.localizedDescription
            }
        }
    }

    @Published var musicFollowsTimer: Bool {
        didSet { UserDefaults.standard.set(musicFollowsTimer, forKey: Self.musicFollowsKey) }
    }
    @Published var focusGuardEnabled: Bool {
        didSet {
            UserDefaults.standard.set(focusGuardEnabled, forKey: Self.focusGuardKey)
            focusGuard.isEnabled = focusGuardEnabled || focusFilterGuard
        }
    }
    /// Pause focus when the Mac sleeps or gets no input for `awayMinutes`.
    @Published var pauseWhenAway: Bool {
        didSet { UserDefaults.standard.set(pauseWhenAway, forKey: Self.pauseWhenAwayKey) }
    }
    @Published var awayMinutes: Int {
        didSet { UserDefaults.standard.set(awayMinutes, forKey: Self.awayMinutesKey) }
    }
    @Published var globalHotKeysEnabled: Bool {
        didSet {
            UserDefaults.standard.set(globalHotKeysEnabled, forKey: Self.hotKeysKey)
            GlobalHotKeys.shared.isEnabled = globalHotKeysEnabled
        }
    }
    @Published var miniTimerVisible: Bool {
        didSet {
            UserDefaults.standard.set(miniTimerVisible, forKey: Self.miniTimerKey)
            MiniTimerController.shared.setVisible(miniTimerVisible, model: self)
        }
    }
    /// Comma-separated app names that trigger a nudge during focus.
    @Published var distractingApps: String {
        didSet {
            UserDefaults.standard.set(distractingApps, forKey: Self.distractingAppsKey)
            focusGuard.appNames = Self.parseAppNames(distractingApps)
        }
    }
    /// Shortcuts (Shortcuts.app) run when focus starts / stops, e.g. to toggle a macOS Focus mode.
    @Published var focusStartShortcut: String {
        didSet { UserDefaults.standard.set(focusStartShortcut, forKey: Self.focusStartShortcutKey) }
    }
    @Published var focusEndShortcut: String {
        didSet { UserDefaults.standard.set(focusEndShortcut, forKey: Self.focusEndShortcutKey) }
    }

    private static let musicFollowsKey = "cadence.musicFollowsTimer"
    private static let focusGuardKey = "cadence.focusGuard"
    private static let distractingAppsKey = "cadence.distractingApps"
    private static let focusStartShortcutKey = "cadence.focusStartShortcut"
    private static let focusEndShortcutKey = "cadence.focusEndShortcut"
    private static let pauseWhenAwayKey = "cadence.pauseWhenAway"
    private static let awayMinutesKey = "cadence.awayMinutes"
    private static let hotKeysKey = "cadence.globalHotKeys"
    private static let miniTimerKey = "cadence.miniTimer"
    static let defaultDistractingApps = "Messages, Slack, Discord, Mail, WhatsApp, Telegram"
    private static let themeKey = "cadence.theme"
    private static let appearanceKey = "cadence.appearance"
    private static let backgroundKey = "cadence.backgroundStyle"
    private static let animatedBackgroundKey = "cadence.animatedBackground"
    private static let targetKey = "cadence.dailyTargetMinutes"
    private let planBufferMinutes = 5

    private var ticker: Timer?
    private var lastTransitionID = 0
    private var scheduledEndMs: Int?
    private var lastPlanRefresh = Date.distantPast
    private var toastWorkItem: DispatchWorkItem?
    private var hasRequestedNotifications = false
    private let storagePath: String
    private let backgroundImageURL: URL
    private let appFolder: URL
    private let dayFormatter: DateFormatter
    private let player: YouTubePlayerController
    private let focusGuard = FocusGuard()
    private var musicPausedByTimer = false
    /// What the pending deadline reminders were built from; forces one sync at launch.
    private var deadlineSignature = ["unsynced"]
    /// A macOS Focus filter turned the focus guard on for as long as that Focus is on.
    private var focusFilterGuard = false
    /// When the current run of the timer started; an away pause never reaches back past it.
    private var runStartedMs: Int?
    private var weekRefreshedFor = ""
    private var lastWidgetSnapshot: WidgetSnapshot?
    /// Captured from a SwiftUI view, so links, hot keys and panels can bring the window back.
    var openWindowAction: OpenWindowAction?

    init(player: YouTubePlayerController) {
        self.player = player
        let defaults = UserDefaults.standard
        musicFollowsTimer = defaults.object(forKey: Self.musicFollowsKey) as? Bool ?? true
        focusGuardEnabled = defaults.bool(forKey: Self.focusGuardKey)
        distractingApps = defaults.string(forKey: Self.distractingAppsKey) ?? Self.defaultDistractingApps
        focusStartShortcut = defaults.string(forKey: Self.focusStartShortcutKey) ?? ""
        focusEndShortcut = defaults.string(forKey: Self.focusEndShortcutKey) ?? ""
        pauseWhenAway = defaults.object(forKey: Self.pauseWhenAwayKey) as? Bool ?? true
        awayMinutes = defaults.object(forKey: Self.awayMinutesKey) as? Int ?? 10
        globalHotKeysEnabled = defaults.object(forKey: Self.hotKeysKey) as? Bool ?? true
        miniTimerVisible = defaults.bool(forKey: Self.miniTimerKey)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        dayFormatter = formatter

        let arguments = ProcessInfo.processInfo.arguments
        let savedTheme = UserDefaults.standard.string(forKey: Self.themeKey)
            .flatMap(AppThemeMode.init(rawValue:)) ?? .dynamic
        themeMode = savedTheme
        Theme.mode = savedTheme
        if let themeArg = arguments.first(where: { $0.hasPrefix("--theme=") }),
           let theme = AppThemeMode(rawValue: String(themeArg.dropFirst("--theme=".count))) {
            themeMode = theme
            Theme.mode = theme
        }

        let savedAppearance = UserDefaults.standard.string(forKey: Self.appearanceKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        appearanceMode = savedAppearance
        Theme.appearance = savedAppearance
        if let appearanceArg = arguments.first(where: { $0.hasPrefix("--appearance=") }),
           let appearance = AppAppearance(rawValue: String(appearanceArg.dropFirst("--appearance=".count))) {
            appearanceMode = appearance
            Theme.appearance = appearance
        }

        dailyTargetMinutes = 240 // replaced by the core's saved target in bootstrap()

        let fileManager = FileManager.default
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let appFolder = supportURL.appendingPathComponent("Cadence", isDirectory: true)
        self.appFolder = appFolder
        try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        let demoData = arguments.contains("--demo-data")
        storagePath = appFolder.appendingPathComponent(demoData ? "core-demo.json" : "core-state.json").path
        backgroundImageURL = appFolder.appendingPathComponent("background.png")

        let savedBackground = UserDefaults.standard.string(forKey: Self.backgroundKey)
            .flatMap(AppBackgroundStyle.init(rawValue:)) ?? .theme
        backgroundStyle = savedBackground
        let savedScene = UserDefaults.standard.string(forKey: Self.animatedBackgroundKey)
            .flatMap(AnimatedBackground.init(rawValue:)) ?? .rainyForest
        animatedBackground = savedScene
        if let sceneArg = arguments.first(where: { $0.hasPrefix("--background-scene=") }),
           let scene = AnimatedBackground(rawValue: String(sceneArg.dropFirst("--background-scene=".count))) {
            animatedBackground = scene
            backgroundStyle = .animated
        }
        if let savedImage = NSImage(contentsOf: backgroundImageURL) {
            backgroundImage = savedImage
        }
        backgroundVideoURL = Self.storedBackgroundVideo(in: appFolder)
        if backgroundStyle == .video && backgroundVideoURL == nil {
            backgroundStyle = .animated
        }
        if let imageArg = arguments.first(where: { $0.hasPrefix("--background-image=") }) {
            let path = String(imageArg.dropFirst("--background-image=".count))
            if let image = NSImage(contentsOfFile: path) {
                backgroundImage = image
                backgroundStyle = .image
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                if let image = NSImage(contentsOfFile: path) {
                    self?.backgroundImage = image
                    self?.backgroundStyle = .image
                }
            }
        } else if backgroundStyle == .image && backgroundImage == nil {
            backgroundStyle = .animated
        }

        if let tabArg = arguments.first(where: { $0.hasPrefix("--tab=") }),
           let tab = AppTab(rawValue: String(tabArg.dropFirst("--tab=".count))) {
            selectedTab = tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.selectedTab = tab
            }
        }
        if arguments.contains("--show-settings") {
            var requestedSection = settingsSection
            if let settingsArg = arguments.first(where: { $0.hasPrefix("--settings=") }),
               let savedSection = AppSettingsSection(rawValue: String(settingsArg.dropFirst("--settings=".count))) {
                requestedSection = savedSection
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.settingsSection = requestedSection
                self?.showSettings = true
            }
        }

        focusGuard.isEnabled = focusGuardEnabled
        focusGuard.appNames = Self.parseAppNames(distractingApps)
        focusGuard.onDistraction = { [weak self] appName in
            self?.nudgeBackToFocus(from: appName)
        }

        Self.shared = self
        bootstrap()
        configureHotKeys()
        if miniTimerVisible || arguments.contains("--mini-timer") {
            MiniTimerController.shared.setVisible(true, model: self)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.pauseWhenAway, self.timer.running, self.timer.phase == .focus else { return }
                self.pauseForAway(sinceMs: CoreClient.nowMs())
            }
        }
        if demoData {
            seedDemoDataIfNeeded()
        }
        if arguments.contains("--demo-break") {
            performTimerCommand("timer.select", phase: .shortBreak)
        }
        if arguments.contains("--show-intention") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.showIntentionPrompt = true
            }
        }
        if arguments.contains("--show-shutdown") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.showShutdown = true
            }
        }
    }

    private func seedDemoDataIfNeeded() {
        do {
            let existing = try CoreClient.shared.tasks(nowMs: CoreClient.nowMs(), day: currentDay)
            if existing.isEmpty {
                let demoTasks: [(String, TaskPriority, Int)] = [
                    ("Draft the API specification", .high, 3),
                    ("Review the Q4 roadmap", .medium, 2),
                    ("Reply to design feedback", .medium, 1),
                    ("Send the weekly update", .high, 1),
                    ("Organize the reading list", .low, 1)
                ]
                for item in demoTasks {
                    _ = try CoreClient.shared.addTask(
                        title: item.0,
                        priority: item.1,
                        estimateBlocks: item.2,
                        nowMs: CoreClient.nowMs(),
                        day: currentDay
                    )
                }
                if let completed = try CoreClient.shared.tasks(nowMs: CoreClient.nowMs(), day: currentDay)
                    .first(where: { $0.title == "Send the weekly update" }) {
                    _ = try CoreClient.shared.toggleTask(
                        id: completed.id,
                        nowMs: CoreClient.nowMs(),
                        day: currentDay
                    )
                }
            }
            tasks = try CoreClient.shared.tasks(nowMs: CoreClient.nowMs(), day: currentDay)
            if let first = tasks.first(where: { $0.title == "Draft the API specification" }) {
                timer = try CoreClient.shared.assignTask(first.id, nowMs: CoreClient.nowMs(), day: currentDay)
            }
            refreshPlan()
        } catch {
            coreError = error.localizedDescription
        }
    }

    var dateLabel: String {
        currentDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var currentDay: String {
        dayFormatter.string(from: Date())
    }

    var activeTask: TaskItem? {
        guard let id = timer.activeTaskId else { return nil }
        return tasks.first { $0.id == id }
    }

    var openTasks: [TaskItem] {
        tasks.filter { !$0.done && !$0.archived }
    }

    var todayCompletedTasks: [TaskItem] {
        tasks.filter { $0.done && $0.completedDay == currentDay }
    }

    var todayOpenTasks: [TaskItem] {
        tasks.filter { !$0.done && !$0.archived }
    }

    var targetHours: Int {
        max(1, dailyTargetMinutes / 60)
    }

    // MARK: - Boot

    private func bootstrap() {
        NotificationManager.shared.configure()
        do {
            let state = try CoreClient.shared.initialize(storagePath: storagePath, day: currentDay)
            timer = state
            lastTransitionID = state.transition?.id ?? 0
            if state.running { runStartedMs = CoreClient.nowMs() }
            announceStorageWarning(state.storageWarning, previous: nil)
            reloadTasks()
            reloadSessions()
            syncScheduledNotification()
            migrateDailyTarget()
            refreshPlan()
        } catch {
            coreError = error.localizedDescription
            showToast(
                "Native core unavailable",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
        startTicker()
        Task { await refreshNotificationStatus() }
        #if !DEBUG
        // Restarting to install an update must never interrupt a focus block or music.
        Updater.shared.isIdle = { [weak self] in
            guard let self else { return true }
            return !self.timer.running && !self.player.isPlaying
        }
        Updater.shared.startAutomaticUpdates()
        #endif
        announceUpdateIfJustInstalled()
    }

    private func startTicker() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.heartbeat()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    /// The daily target used to live in UserDefaults; move it into the core once.
    private func migrateDailyTarget() {
        let defaults = UserDefaults.standard
        // --demo-data uses its own file; the real target must land in the real one.
        guard defaults.object(forKey: Self.targetKey) != nil,
              !storagePath.hasSuffix("core-demo.json") else { return }
        let saved = defaults.integer(forKey: Self.targetKey)
        do {
            if saved > 0 {
                _ = try CoreClient.shared.setDailyTarget(
                    minutes: saved,
                    nowMs: CoreClient.nowMs(),
                    bufferMinutes: planBufferMinutes
                )
            }
            defaults.removeObject(forKey: Self.targetKey)
        } catch {
            coreError = error.localizedDescription
        }
    }

    private func announceStorageWarning(_ warning: String?, previous: String?) {
        guard let warning, warning != previous else { return }
        showToast("Your data needs attention", warning, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
    }

    private func heartbeat() {
        // Publishing re-renders every view that watches the model, so only publish what
        // changed visibly: the date by the minute, the timer by the second.
        let now = Date()
        if Int(now.timeIntervalSince1970 / 60) != Int(currentDate.timeIntervalSince1970 / 60) {
            currentDate = now
            if currentDay != weekRefreshedFor { refreshWeek() }
        }
        do {
            let state = try CoreClient.shared.tick(nowMs: CoreClient.nowMs(), day: currentDay)
            if !state.looksTheSame(as: timer) {
                applyTimer(state)
            }
            if coreError != nil { coreError = nil }
        } catch {
            coreError = error.localizedDescription
        }

        // The plan's start time moves with the clock; it shows on the Focus screen.
        if Date().timeIntervalSince(lastPlanRefresh) > 60 {
            refreshPlan()
        }
        checkAway()
    }

    private func applyTimer(_ state: TimerState, notify: Bool = true) {
        let previouslyScheduled = scheduledEndMs != nil
        let previousTimer = timer
        timer = state
        syncScheduledNotification()
        announceStorageWarning(state.storageWarning, previous: previousTimer.storageWarning)
        let wasFocusing = previousTimer.running && previousTimer.phase == .focus
        let isFocusing = state.running && state.phase == .focus
        if wasFocusing != isFocusing {
            focusActivityChanged(isFocusing)
        }
        if state.running && (!previousTimer.running || state.phase != previousTimer.phase) {
            runStartedMs = CoreClient.nowMs()
        }
        // Resuming, resetting or moving on answers the away prompt.
        if awayPrompt != nil && (state.running || state.phase != previousTimer.phase || state.isFreshInterval) {
            awayPrompt = nil
        }
        publishWidgetSnapshot()
        // Starting, pausing or a phase change moves where the plan begins.
        if state.running != previousTimer.running || state.phase != previousTimer.phase {
            refreshPlan()
        }
        if state.externalRevision != previousTimer.externalRevision {
            reloadTasks()
            reloadSessions()
            refreshPlan()
        }
        guard let transition = state.transition, transition.id > lastTransitionID else { return }
        lastTransitionID = transition.id
        if !transition.skipped {
            if transition.completedPhase == .focus {
                reloadTasks()
                reloadSessions()
                refreshPlan()
            }
            if notify {
                handleTransition(transition, alreadyNotified: previouslyScheduled)
            }
        }
    }

    /// Keeps exactly one pending system notification for the running interval's end.
    private func syncScheduledNotification() {
        let endsAt = timer.running ? timer.endsAtMs : nil
        guard endsAt != scheduledEndMs else { return }
        NotificationManager.shared.cancelPhaseEnd()
        scheduledEndMs = nil
        guard let endsAt else { return }
        let next = predictedNextPhase()
        let copy = transitionCopy(completed: timer.phase, next: next, task: activeTask)
        NotificationManager.shared.schedulePhaseEnd(
            at: Date(timeIntervalSince1970: Double(endsAt) / 1000),
            title: copy.title,
            body: copy.message
        )
        scheduledEndMs = endsAt
    }

    private func predictedNextPhase() -> PomodoroPhase {
        guard timer.phase == .focus else { return .focus }
        return timer.completedInCycle + 1 >= timer.cycleLength ? .longBreak : .shortBreak
    }

    private func transitionCopy(
        completed: PomodoroPhase,
        next: PomodoroPhase,
        task: TaskItem?
    ) -> (title: String, message: String) {
        let nextMinutes = timer.config.minutes(for: next)
        switch completed {
        case .focus:
            let title = next == .longBreak ? "Long break earned" : "Focus complete"
            if let task {
                return (title, "\(task.title) · your \(nextMinutes)-minute break is ready.")
            }
            return (title, "Your \(nextMinutes)-minute \(next.title.lowercased()) is ready.")
        case .shortBreak, .longBreak:
            return ("Break complete", "Ready for another \(nextMinutes)-minute focus interval.")
        }
    }

    private func handleTransition(_ transition: TimerTransition, alreadyNotified: Bool) {
        let copy = transitionCopy(
            completed: transition.completedPhase,
            next: transition.nextPhase,
            task: activeTask
        )
        let (title, message) = copy
        let icon = transition.completedPhase == .focus ? "checkmark.circle.fill" : "sunrise.fill"
        let tint = transition.completedPhase == .focus ? Theme.accent : Theme.mint

        showToast(title, message, icon: icon, tint: tint)
        if !alreadyNotified {
            NotificationManager.shared.post(title: title, body: message)
        }
        let soundName = transition.completedPhase == .focus ? "Glass" : "Ping"
        NSSound(named: NSSound.Name(soundName))?.play()
    }

    private func announceUpdateIfJustInstalled() {
        let key = "cadence.lastRunVersion"
        let current = Updater.shared.currentVersion
        let previous = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set(current, forKey: key)
        guard let previous, Updater.isNewer(current, than: previous) else { return }
        showToast("Updated to Cadence \(current)", "See what's new on the releases page.", icon: "sparkles", tint: Theme.mint)
    }

    // MARK: - Focus side effects

    /// Called whenever a focus interval starts running or stops (pause, end, skip, reset).
    private func focusActivityChanged(_ focusing: Bool) {
        focusGuard.update(focusRunning: focusing)
        runShortcut(named: focusing ? focusStartShortcut : focusEndShortcut)

        guard musicFollowsTimer, player.hasVideo else { return }
        if focusing {
            if musicPausedByTimer {
                musicPausedByTimer = false
                player.play()
            }
        } else if player.isPlaying {
            musicPausedByTimer = true
            player.pause()
        }
    }

    private func runShortcut(named name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.terminationHandler = { process in
            guard process.terminationStatus != 0 else { return }
            Task { @MainActor [weak self] in
                self?.showToast(
                    "Shortcut didn't run",
                    "Check that “\(name)” exists in the Shortcuts app.",
                    icon: "exclamationmark.triangle.fill",
                    tint: Theme.amber
                )
            }
        }
        do {
            try process.run()
        } catch {
            showToast("Shortcut didn't run", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    private func nudgeBackToFocus(from appName: String) {
        let minutes = max(1, timer.remainingSeconds / 60)
        let task = activeTask.map { " on \($0.title)" } ?? ""
        NotificationManager.shared.post(
            title: "Still focusing",
            body: "\(appName) can wait. \(minutes) min left\(task)."
        )
    }

    private static func parseAppNames(_ raw: String) -> Set<String> {
        Set(splitAppNames(raw).map { $0.lowercased() })
    }

    private static func splitAppNames(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var distractingAppList: [String] { Self.splitAppNames(distractingApps) }

    func toggleDistractingApp(_ name: String) {
        var names = distractingAppList
        if let index = names.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            names.remove(at: index)
        } else {
            names.append(name)
        }
        distractingApps = names.joined(separator: ", ")
    }

    // MARK: - Navigation

    func selectTab(_ tab: AppTab) {
        guard selectedTab != tab else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            selectedTab = tab
        }
        if tab == .tasks {
            refreshPlan()
        }
    }

    // MARK: - Timer

    func requestTimerToggle() {
        if timer.running {
            performTimerCommand("timer.pause")
            return
        }
        if timer.phase == .focus,
           timer.isFreshInterval,
           (timer.intention?.isEmpty ?? true) {
            showIntentionPrompt = true
            return
        }
        requestNotificationsIfNeeded()
        performTimerCommand("timer.resume")
    }

    /// Sets a one-off length for the current (not yet running) interval.
    func setIntervalLength(_ minutes: Int) {
        guard !timer.running, minutes != timer.intervalMinutes else { return }
        do {
            applyTimer(try CoreClient.shared.setLength(minutes: minutes, nowMs: CoreClient.nowMs(), day: currentDay))
        } catch {
            showToast("Couldn't change the length", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    func beginFocus(intention: String, minutes: Int? = nil) {
        showIntentionPrompt = false
        requestNotificationsIfNeeded()
        if let minutes {
            setIntervalLength(minutes)
        }
        let trimmed = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let state = try CoreClient.shared.performTimer(
                "timer.start",
                nowMs: CoreClient.nowMs(),
                day: currentDay,
                intention: trimmed
            )
            applyTimer(state)
        } catch {
            showToast(
                "Couldn't start focus",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
    }

    /// Starts focus without the intention prompt (Shortcuts, Siri): switches to the focus
    /// phase if a break is up, then starts a fresh interval or resumes a paused one.
    func startFocus(intention: String?, minutes: Int?) {
        guard !timer.running else { return }
        if timer.phase != .focus {
            performTimerCommand("timer.select", phase: .focus)
        }
        if timer.isFreshInterval {
            beginFocus(intention: intention ?? "", minutes: minutes.map { min(180, max(1, $0)) })
        } else {
            requestNotificationsIfNeeded()
            performTimerCommand("timer.resume")
        }
    }

    func cancelIntentionPrompt() {
        showIntentionPrompt = false
    }

    func pauseTimer() {
        guard timer.running else { return }
        performTimerCommand("timer.pause")
    }

    func resetTimer() {
        performTimerCommand("timer.reset")
    }

    func skipTimer() {
        performTimerCommand("timer.skip")
    }

    /// Start/pause without the intention prompt: for hot keys, links, the widget and the
    /// mini timer, which may run while the window is hidden.
    func toggleTimerQuietly() {
        if timer.running {
            pauseTimer()
        } else if timer.phase == .focus {
            startFocus(intention: nil, minutes: nil)
        } else {
            requestNotificationsIfNeeded()
            performTimerCommand("timer.resume")
        }
    }

    /// Adds time to the current interval, running or paused; the full length is credited.
    func extendInterval(minutes: Int = 5) {
        do {
            applyTimer(try CoreClient.shared.extend(minutes: minutes, nowMs: CoreClient.nowMs(), day: currentDay))
            showToast("+\(minutes) min", "\(timer.formattedRemaining) left in this \(timer.phase.title.lowercased()).", icon: "goforward.plus", tint: timer.phase.accent)
        } catch {
            showToast("Couldn't extend the interval", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    func applyPreset(_ preset: TimerPreset) {
        if saveTimerConfig(preset.applied(to: timer.config)) {
            showToast("\(preset.title) preset", "\(preset.summary) min · focus / short / long break.", icon: "dial.medium.fill", tint: Theme.accent)
        }
    }

    // MARK: - Away from the Mac

    private func checkAway() {
        guard pauseWhenAway, timer.running, timer.phase == .focus, let anyInput = CGEventType(rawValue: ~0) else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        guard idle >= Double(awayMinutes * 60) else { return }
        pauseForAway(sinceMs: CoreClient.nowMs() - Int(idle * 1000))
    }

    /// Pauses as of the moment the user left, so the away time is not counted.
    private func pauseForAway(sinceMs: Int) {
        let since = max(sinceMs, runStartedMs ?? sinceMs)
        do {
            applyTimer(try CoreClient.shared.performTimer("timer.pause", nowMs: since, day: currentDay))
            awayPrompt = AwayPrompt(sinceMs: since)
            NotificationManager.shared.post(
                title: "Focus paused while you were away",
                body: "Resume when you're back, or count the time if you were still working."
            )
        } catch {
            coreError = error.localizedDescription
        }
    }

    /// `counting`: resume as if never paused, so the away time counts as focus.
    func resumeAfterAway(counting: Bool) {
        guard let prompt = awayPrompt else { return }
        awayPrompt = nil
        guard !timer.running else { return }
        requestNotificationsIfNeeded()
        do {
            applyTimer(try CoreClient.shared.performTimer(
                "timer.resume",
                nowMs: counting ? prompt.sinceMs : CoreClient.nowMs(),
                day: currentDay
            ))
        } catch {
            showToast("Couldn't resume", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    func selectPhase(_ phase: PomodoroPhase) {
        guard phase != timer.phase || timer.running || timer.remainingMs != timer.totalMs else { return }
        performTimerCommand("timer.select", phase: phase)
    }

    /// Applies interval settings immediately. An interval already in progress keeps
    /// its length; the new lengths start with the next interval.
    @discardableResult
    func saveTimerConfig(_ config: PomodoroConfig) -> Bool {
        guard config != timer.config else { return true }
        do {
            let state = try CoreClient.shared.performTimer(
                "timer.configure",
                nowMs: CoreClient.nowMs(),
                day: currentDay,
                config: config
            )
            applyTimer(state)
            refreshPlan()
            return true
        } catch {
            showToast(
                "Couldn't save settings",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
            return false
        }
    }

    private func performTimerCommand(_ command: String, phase: PomodoroPhase? = nil) {
        do {
            let state = try CoreClient.shared.performTimer(
                command,
                nowMs: CoreClient.nowMs(),
                day: currentDay,
                phase: phase
            )
            applyTimer(state)
        } catch {
            showToast(
                "Timer unavailable",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
    }

    func refreshTimerFromCore() {
        do {
            let state = try CoreClient.shared.tick(nowMs: CoreClient.nowMs(), day: currentDay)
            applyTimer(state)
        } catch {
            coreError = error.localizedDescription
        }
    }

    // MARK: - Tasks

    func assignTask(_ task: TaskItem?) {
        if timer.running {
            performTimerCommand("timer.pause")
        }
        do {
            let state = try CoreClient.shared.assignTask(
                task?.id,
                nowMs: CoreClient.nowMs(),
                day: currentDay
            )
            timer = state
            if let task {
                showToast(
                    "Now focusing",
                    task.title,
                    icon: "scope",
                    tint: task.priority.tint
                )
            }
        } catch {
            showToast(
                "Couldn't assign task",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
    }

    func clearActiveTask() {
        assignTask(nil)
    }

    func addTask(
        title: String,
        priority: TaskPriority,
        estimateBlocks: Int,
        inProgress: Bool = false,
        estimateMinutes: Int? = nil,
        dueAtMs: Int? = nil
    ) {
        if dueAtMs != nil { requestNotificationsIfNeeded() }
        do {
            tasks = try CoreClient.shared.addTask(
                title: title,
                priority: priority,
                estimateBlocks: estimateBlocks,
                inProgress: inProgress,
                estimateMinutes: estimateMinutes,
                dueAtMs: dueAtMs,
                nowMs: CoreClient.nowMs(),
                day: currentDay
            )
            refreshPlan()
            showToast(
                "Task added",
                title,
                icon: "plus.circle.fill",
                tint: priority.tint
            )
        } catch {
            showToast(
                "Couldn't add task",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
    }

    func updateTask(
        _ task: TaskItem,
        title: String? = nil,
        priority: TaskPriority? = nil,
        estimateBlocks: Int? = nil,
        inProgress: Bool? = nil,
        archived: Bool? = nil,
        estimateMinutes: Int? = nil,
        dueAtMs: Int?? = nil
    ) {
        if case .some(.some) = dueAtMs { requestNotificationsIfNeeded() }
        do {
            tasks = try CoreClient.shared.updateTask(
                id: task.id,
                title: title,
                priority: priority,
                estimateBlocks: estimateBlocks,
                inProgress: inProgress,
                archived: archived,
                estimateMinutes: estimateMinutes,
                dueAtMs: dueAtMs,
                nowMs: CoreClient.nowMs(),
                day: currentDay
            )
            refreshPlan()
        } catch {
            showToast(
                "Couldn't update task",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
    }

    func reorderTasks(ids: [String]) {
        do {
            tasks = try CoreClient.shared.reorderTasks(ids: ids, nowMs: CoreClient.nowMs(), day: currentDay)
            refreshPlan()
        } catch {
            showToast(
                "Couldn't reorder tasks",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
    }

    func toggleTask(_ task: TaskItem, toDone: Bool? = nil) {
        let shouldBeDone = toDone ?? !task.done
        if shouldBeDone != task.done {
            do {
                tasks = try CoreClient.shared.toggleTask(
                    id: task.id,
                    nowMs: CoreClient.nowMs(),
                    day: currentDay
                )
                refreshTimerFromCore()
                refreshPlan()
            } catch {
                showToast(
                    "Couldn't update task",
                    error.localizedDescription,
                    icon: "exclamationmark.triangle.fill",
                    tint: Theme.amber
                )
            }
        }
    }

    func deleteTask(_ task: TaskItem) {
        do {
            tasks = try CoreClient.shared.deleteTask(
                id: task.id,
                nowMs: CoreClient.nowMs(),
                day: currentDay
            )
            refreshTimerFromCore()
            refreshPlan()
        } catch {
            showToast(
                "Couldn't delete task",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
    }

    func clearOpenTasks() {
        do {
            tasks = try CoreClient.shared.clearOpenTasks(
                nowMs: CoreClient.nowMs(),
                day: currentDay
            )
            refreshTimerFromCore()
            refreshPlan()
        } catch {
            showToast(
                "Couldn't clear tasks",
                error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                tint: Theme.amber
            )
        }
    }

    func reloadTasks() {
        do {
            tasks = try CoreClient.shared.tasks(nowMs: CoreClient.nowMs(), day: currentDay)
        } catch {
            coreError = error.localizedDescription
        }
    }

    /// This week's and last week's days, Monday first like cadence-mcp.
    private func weekDays() -> (this: [String], previous: [String])? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        guard let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return nil }
        let days = { (offset: Int) in
            (0..<7).compactMap { calendar.date(byAdding: .day, value: offset + $0, to: start) }.map(self.dayFormatter.string)
        }
        return (days(0), days(-7))
    }

    func refreshWeek() {
        guard let days = weekDays() else { return }
        do {
            week = try CoreClient.shared.weekSummary(days: days.this, previousDays: days.previous, nowMs: CoreClient.nowMs())
            weekRefreshedFor = currentDay
            publishWidgetSnapshot()
        } catch {
            coreError = error.localizedDescription
        }
    }

    func setWeeklyTargetHours(_ hours: Int) {
        guard let days = weekDays() else { return }
        do {
            week = try CoreClient.shared.setWeeklyTarget(
                minutes: min(84, max(1, hours)) * 60, days: days.this, previousDays: days.previous, nowMs: CoreClient.nowMs()
            )
            publishWidgetSnapshot()
        } catch {
            showToast("Couldn't save the weekly goal", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    func reloadSessions() {
        do {
            sessions = try CoreClient.shared.sessions(nowMs: CoreClient.nowMs(), day: currentDay)
        } catch {
            coreError = error.localizedDescription
        }
    }

    func refreshPlan() {
        do {
            plan = try CoreClient.shared.buildPlan(nowMs: CoreClient.nowMs(), bufferMinutes: planBufferMinutes)
            lastPlanRefresh = Date()
            if plan.targetMinutes > 0, plan.targetMinutes != dailyTargetMinutes {
                dailyTargetMinutes = plan.targetMinutes // the core's saved target wins
            }
            publishWidgetSnapshot()
        } catch {
            coreError = error.localizedDescription
        }
    }

    /// Opens the plan's focus blocks in Calendar, which asks which calendar to add them to.
    func exportPlanToCalendar() {
        do {
            let ics = try CoreClient.shared.planICS(nowMs: CoreClient.nowMs(), bufferMinutes: planBufferMinutes)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Cadence Day Plan.ics")
            try ics.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            showToast("Couldn't export the plan", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    /// Keeps one "due in 1 hour" reminder per open task with a deadline.
    private func syncDeadlineReminders() {
        let lead = 60 * 60_000
        let now = CoreClient.nowMs()
        let reminders: [DeadlineReminder] = tasks.compactMap { task in
            guard !task.done, !task.archived, let due = task.dueAtMs, due - lead > now,
                  let dueDate = task.dueDate else { return nil }
            return DeadlineReminder(
                id: task.id,
                fireAt: dueDate.addingTimeInterval(-Double(lead) / 1000),
                title: "Due in 1 hour",
                body: "“\(task.title)” is due at \(dueDate.shortTimeString)."
            )
        }
        let signature = reminders.map { "\($0.id)|\($0.fireAt.timeIntervalSince1970)|\($0.body)" }
        guard signature != deadlineSignature else { return }
        deadlineSignature = signature
        NotificationManager.shared.replaceDeadlineReminders(reminders)
    }

    func setDailyTargetHours(_ hours: Int) {
        dailyTargetMinutes = min(720, max(30, hours * 60))
    }

    func adjustDailyTarget(byMinutes minutes: Int) {
        dailyTargetMinutes = min(720, max(30, dailyTargetMinutes + minutes))
    }

    // MARK: - System integration

    private func configureHotKeys() {
        GlobalHotKeys.shared.configure([
            .init(keyCode: kVK_Space, symbol: "Space", title: "Start or pause") { [weak self] in self?.toggleTimerQuietly() },
            .init(keyCode: kVK_RightArrow, symbol: "→", title: "Skip interval") { [weak self] in self?.skipTimer() },
            .init(keyCode: kVK_ANSI_Equal, symbol: "=", title: "Add 5 minutes") { [weak self] in self?.extendInterval(minutes: 5) },
            .init(keyCode: kVK_ANSI_N, symbol: "N", title: "Quick-add a task") { [weak self] in self?.showQuickAdd() },
            .init(keyCode: kVK_ANSI_M, symbol: "M", title: "Show or hide the mini timer") { [weak self] in self?.miniTimerVisible.toggle() },
        ])
        GlobalHotKeys.shared.isEnabled = globalHotKeysEnabled
    }

    func showQuickAdd() {
        QuickAddController.shared.show(model: self)
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindowAction?(id: "main")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled { try service.register() } else { try service.unregister() }
        } catch {
            showToast("Couldn't change Open at Login", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
        launchAtLogin = service.status == .enabled
        if service.status == .requiresApproval {
            showToast("Approve Cadence in Login Items", "macOS asks once in System Settings.", icon: "person.badge.key.fill", tint: Theme.amber)
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    /// Applied when a macOS Focus with Cadence's filter turns on, and with the default
    /// values (both off) when it turns off.
    func applyFocusFilter(startFocus shouldStart: Bool, guardDistractions: Bool) {
        focusFilterGuard = guardDistractions
        focusGuard.isEnabled = focusGuardEnabled || focusFilterGuard
        if shouldStart && !timer.running {
            startFocus(intention: nil, minutes: nil)
        }
    }

    /// `cadence://` links, from scripts, launchers, notes and the widget.
    func handle(url: URL) {
        guard url.scheme?.lowercased() == "cadence" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        let minutes = value("minutes").flatMap(Int.init)
        switch (url.host ?? "").lowercased() {
        case "start":
            if let query = value("task") {
                guard let task = openTasks.first(where: { $0.id == query || $0.title.caseInsensitiveCompare(query) == .orderedSame })
                    ?? openTasks.first(where: { $0.title.localizedCaseInsensitiveContains(query) }) else {
                    showToast("No open task matches", "“\(query)”", icon: "questionmark.circle.fill", tint: Theme.amber)
                    return
                }
                if task.id != timer.activeTaskId { assignTask(task) }
            }
            startFocus(intention: value("intention"), minutes: minutes)
        case "pause": pauseTimer()
        case "toggle": toggleTimerQuietly()
        case "skip": skipTimer()
        case "reset": resetTimer()
        case "extend": extendInterval(minutes: min(60, max(1, minutes ?? 5)))
        case "add":
            guard let title = value("title") else {
                showToast("The link needs a title", "cadence://add?title=…", icon: "exclamationmark.triangle.fill", tint: Theme.amber)
                return
            }
            addTask(
                title: title,
                priority: value("priority").flatMap { TaskPriority(rawValue: $0.lowercased()) } ?? .medium,
                estimateBlocks: 1,
                estimateMinutes: minutes.map { min(1440, max(1, $0)) }
            )
        case "quick-add": showQuickAdd()
        case "mini-timer": miniTimerVisible.toggle()
        case "preset":
            guard let preset = TimerPreset.all.first(where: { $0.id == value("name")?.lowercased() }) else {
                showToast("Unknown preset", TimerPreset.all.map(\.id).joined(separator: ", "), icon: "exclamationmark.triangle.fill", tint: Theme.amber)
                return
            }
            applyPreset(preset)
        case "review":
            openMainWindow()
            showWeeklyReview = true
        case "open", "":
            if let tab = value("tab").flatMap(AppTab.init(rawValue:)) { selectTab(tab) }
            openMainWindow()
        default:
            showToast("Unknown Cadence link", url.absoluteString, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    /// Only Developer ID builds share data with the widget: an ad-hoc build touching the
    /// App Group container makes macOS ask for permission. `--share-widget` forces it.
    private static let canShareWithWidget: Bool = {
        if ProcessInfo.processInfo.arguments.contains("--share-widget") { return true }
        var code: SecCode?
        var requirement: SecRequirement?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(
                  "anchor apple generic and certificate leaf[subject.OU] = \"T7A3N2UXYN\"" as CFString, [], &requirement
              ) == errSecSuccess,
              let requirement else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }()

    /// Writes what the widget shows and reloads it, only when that changed.
    private func publishWidgetSnapshot() {
        guard Self.canShareWithWidget else { return }
        let snapshot = WidgetSnapshot(
            phase: timer.phase.rawValue,
            phaseTitle: timer.phase.title,
            running: timer.running,
            endsAt: timer.running ? timer.endsAtMs.map { Date(timeIntervalSince1970: Double($0) / 1000) } : nil,
            remainingSeconds: timer.running ? 0 : timer.remainingSeconds,
            taskTitle: activeTask?.title,
            todayMinutes: timer.todayFocusMinutes,
            dailyTargetMinutes: dailyTargetMinutes,
            weekMinutes: week.focusMinutes,
            weeklyTargetMinutes: week.targetMinutes,
            nextBlockTitle: plan.blocks.first { $0.kind.isFocus && $0.taskId != timer.activeTaskId }?.taskTitle
        )
        guard snapshot != lastWidgetSnapshot else { return }
        lastWidgetSnapshot = snapshot
        do {
            try snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            NSLog("[Cadence] widget snapshot: \(error.localizedDescription)")
        }
    }

    // MARK: - Theme

    func setTheme(_ mode: AppThemeMode) {
        withAnimation(.easeInOut(duration: 0.35)) {
            themeMode = mode
            // The weather scenes are tuned for Dynamic/Cozy; a theme change brings its own photo.
            if backgroundStyle == .animated { backgroundStyle = .theme }
        }
    }

    func setAppearance(_ appearance: AppAppearance) {
        withAnimation(.easeInOut(duration: 0.28)) {
            appearanceMode = appearance
        }
    }

    func toggleTheme() {
        let all = AppThemeMode.allCases
        setTheme(all[(all.firstIndex(of: themeMode)! + 1) % all.count])
    }

    func openSettings(_ section: AppSettingsSection = .timer) {
        settingsSection = section
        showSettings = true
    }

    // MARK: - Background

    func setBackgroundStyle(_ style: AppBackgroundStyle) {
        if style == .image && backgroundImage == nil {
            chooseBackgroundImage()
            return
        }
        if style == .video && backgroundVideoURL == nil {
            chooseBackgroundVideo()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            backgroundStyle = style
        }
    }

    func setBackgroundScene(_ scene: AnimatedBackground) {
        withAnimation(.easeInOut(duration: 0.4)) {
            animatedBackground = scene
            backgroundStyle = .animated
        }
    }

    func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Use as background"
        panel.message = "Choose a photo for your focus space."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importBackground(from: url)
    }

    func importBackground(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            showToast("Couldn't read that image", "Try a PNG, JPEG, HEIC, or WebP file.", icon: "photo.badge.exclamationmark", tint: Theme.amber)
            return
        }

        let resized = Self.resizedBackgroundImage(image, maximumDimension: 3000)
        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            showToast("Couldn't prepare that background", "The image could not be converted.", icon: "photo.badge.exclamationmark", tint: Theme.amber)
            return
        }

        do {
            try data.write(to: backgroundImageURL, options: .atomic)
            withAnimation(.easeInOut(duration: 0.4)) {
                backgroundImage = resized
                backgroundStyle = .image
            }
            showToast("Background updated", "Your focus space now carries this image.", icon: "photo.fill", tint: Theme.accent)
        } catch {
            showToast("Couldn't save the background", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    func removeBackgroundImage() {
        try? FileManager.default.removeItem(at: backgroundImageURL)
        withAnimation(.easeInOut(duration: 0.35)) {
            backgroundImage = nil
            backgroundStyle = .animated
        }
        showToast("Back to \(animatedBackground.title)", "Your imported background was removed.", icon: "sparkles", tint: Theme.mint)
    }

    func chooseBackgroundVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Use as background"
        panel.message = "Choose a video loop, e.g. rain on a café window. It plays muted."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // A new file name each time, so the player notices the change.
        let destination = appFolder.appendingPathComponent(
            "background-video-\(Int(Date().timeIntervalSince1970)).\(url.pathExtension.lowercased())"
        )
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            if let old = backgroundVideoURL {
                try? FileManager.default.removeItem(at: old)
            }
            withAnimation(.easeInOut(duration: 0.4)) {
                backgroundVideoURL = destination
                backgroundStyle = .video
            }
            showToast("Background updated", "Your video now loops behind Cadence.", icon: "film.fill", tint: Theme.accent)
        } catch {
            showToast("Couldn't use that video", error.localizedDescription, icon: "exclamationmark.triangle.fill", tint: Theme.amber)
        }
    }

    func removeBackgroundVideo() {
        if let url = backgroundVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            backgroundVideoURL = nil
            if backgroundStyle == .video { backgroundStyle = .animated }
        }
    }

    private static func storedBackgroundVideo(in folder: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix("background-video-") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
    }

    private static func resizedBackgroundImage(_ image: NSImage, maximumDimension: CGFloat) -> NSImage {
        let original = image.size
        guard original.width > 0, original.height > 0 else { return image }
        let scale = min(1, maximumDimension / max(original.width, original.height))
        guard scale < 1 else { return image }
        let target = NSSize(width: original.width * scale, height: original.height * scale)
        let resized = NSImage(size: target)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: NSRect(origin: .zero, size: original),
            operation: .copy,
            fraction: 1
        )
        resized.unlockFocus()
        return resized
    }

    // MARK: - Shutdown

    func openShutdown() {
        showShutdown = true
    }

    func finishWorkday() {
        if timer.running {
            performTimerCommand("timer.pause")
        }
        _ = try? CoreClient.shared.assignTask(nil, nowMs: CoreClient.nowMs(), day: currentDay)
        performTimerCommand("timer.reset")
        showShutdown = false
        selectedTab = .focus
        showToast(
            "Workday closed",
            "The desk is clear. Rest well.",
            icon: "moon.stars.fill",
            tint: Theme.amber
        )
    }

    // MARK: - Notifications

    func requestNotificationsIfNeeded() {
        guard !hasRequestedNotifications else { return }
        hasRequestedNotifications = true
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            notificationsAuthorized = granted
        }
    }

    func requestNotifications() {
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            notificationsAuthorized = granted
            showToast(
                granted ? "Notifications on" : "Notifications off",
                granted
                    ? "Cadence will nudge you when an interval ends."
                    : "You can enable them later in System Settings.",
                icon: granted ? "bell.badge.fill" : "bell.slash.fill",
                tint: granted ? Theme.mint : Theme.amber
            )
        }
    }

    func refreshNotificationStatus() async {
        notificationsAuthorized = await NotificationManager.shared.isAuthorized()
    }

    // MARK: - Helpers

    func showToast(
        _ title: String,
        _ message: String,
        icon: String = "sparkles",
        tint: Color = Theme.accent
    ) {
        let toastMessage = ToastMessage(icon: icon, title: title, message: message, tint: tint)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            toast = toastMessage
        }
        toastWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.toast = nil
            }
        }
        toastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2, execute: workItem)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension TaskPriority {
    var tint: Color {
        switch self {
        case .high: return Theme.accent
        case .medium: return Theme.amber
        case .low: return Theme.sky
        }
    }
}
