import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: AppTab = .focus
    @Published private(set) var timer: TimerState = .placeholder
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var plan: DayPlan = .empty
    @Published private(set) var sessions: [FocusSession] = []
    @Published private(set) var notificationsAuthorized = false
    @Published private(set) var currentDate = Date()
    @Published var showSettings = false
    @Published var showIntentionPrompt = false
    @Published var showShutdown = false
    @Published var settingsSection: AppSettingsSection = .general
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
    @Published var dailyTargetMinutes: Int {
        didSet {
            let clamped = min(720, max(30, dailyTargetMinutes))
            if clamped != dailyTargetMinutes {
                dailyTargetMinutes = clamped
                return
            }
            UserDefaults.standard.set(dailyTargetMinutes, forKey: Self.targetKey)
            refreshPlan()
        }
    }

    @Published var musicFollowsTimer: Bool {
        didSet { UserDefaults.standard.set(musicFollowsTimer, forKey: Self.musicFollowsKey) }
    }
    @Published var focusGuardEnabled: Bool {
        didSet {
            UserDefaults.standard.set(focusGuardEnabled, forKey: Self.focusGuardKey)
            focusGuard.isEnabled = focusGuardEnabled
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

    init(player: YouTubePlayerController) {
        self.player = player
        let defaults = UserDefaults.standard
        musicFollowsTimer = defaults.object(forKey: Self.musicFollowsKey) as? Bool ?? true
        focusGuardEnabled = defaults.bool(forKey: Self.focusGuardKey)
        distractingApps = defaults.string(forKey: Self.distractingAppsKey) ?? Self.defaultDistractingApps
        focusStartShortcut = defaults.string(forKey: Self.focusStartShortcutKey) ?? ""
        focusEndShortcut = defaults.string(forKey: Self.focusEndShortcutKey) ?? ""

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

        let savedTarget = UserDefaults.standard.integer(forKey: Self.targetKey)
        dailyTargetMinutes = savedTarget > 0 ? savedTarget : 240

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
            .flatMap(AppBackgroundStyle.init(rawValue:)) ?? .animated
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

        bootstrap()
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
                let demoTasks: [(String, TaskQuadrant, Int)] = [
                    ("Draft the API specification", .urgentImportant, 3),
                    ("Review the Q4 roadmap", .importantNotUrgent, 2),
                    ("Reply to design feedback", .urgentNotImportant, 1),
                    ("Send the weekly update", .urgentImportant, 1),
                    ("Organize the reading list", .neither, 1)
                ]
                for item in demoTasks {
                    _ = try CoreClient.shared.addTask(
                        title: item.0,
                        quadrant: item.1,
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
        tasks.filter { !$0.done }
    }

    var todayCompletedTasks: [TaskItem] {
        tasks.filter { $0.done && $0.completedDay == currentDay }
    }

    var todayOpenTasks: [TaskItem] {
        tasks.filter { !$0.done }
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
            reloadTasks()
            reloadSessions()
            syncScheduledNotification()
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
        Updater.shared.checkAutomaticallyIfDue { [weak self] release in
            self?.showToast(
                "Cadence \(release.version) is available",
                "Install it from Preferences → General.",
                icon: "arrow.down.circle.fill",
                tint: Theme.mint
            )
        }
        #endif
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

    private func heartbeat() {
        currentDate = Date()
        do {
            let state = try CoreClient.shared.tick(nowMs: CoreClient.nowMs(), day: currentDay)
            applyTimer(state)
            if coreError != nil { coreError = nil }
        } catch {
            coreError = error.localizedDescription
        }

        if selectedTab == .tasks, Date().timeIntervalSince(lastPlanRefresh) > 60 {
            refreshPlan()
        }
    }

    private func applyTimer(_ state: TimerState, notify: Bool = true) {
        let previouslyScheduled = scheduledEndMs != nil
        let previousTimer = timer
        timer = state
        syncScheduledNotification()
        let wasFocusing = previousTimer.running && previousTimer.phase == .focus
        let isFocusing = state.running && state.phase == .focus
        if wasFocusing != isFocusing {
            focusActivityChanged(isFocusing)
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
        Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
        )
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

    func selectPhase(_ phase: PomodoroPhase) {
        guard phase != timer.phase || timer.running || timer.remainingMs != timer.totalMs else { return }
        performTimerCommand("timer.select", phase: phase)
    }

    @discardableResult
    func saveTimerConfig(_ config: PomodoroConfig) -> Bool {
        do {
            let state = try CoreClient.shared.performTimer(
                "timer.configure",
                nowMs: CoreClient.nowMs(),
                day: currentDay,
                config: config
            )
            applyTimer(state)
            refreshPlan()
            showToast(
                "Intervals updated",
                "Your next session uses the new rhythm.",
                icon: "slider.horizontal.3",
                tint: Theme.mint
            )
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
                    tint: task.quadrant.tint
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

    func addTask(title: String, quadrant: TaskQuadrant, estimateBlocks: Int) {
        do {
            tasks = try CoreClient.shared.addTask(
                title: title,
                quadrant: quadrant,
                estimateBlocks: estimateBlocks,
                nowMs: CoreClient.nowMs(),
                day: currentDay
            )
            refreshPlan()
            showToast(
                "Task added",
                title,
                icon: "plus.circle.fill",
                tint: quadrant.tint
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
        title: String,
        quadrant: TaskQuadrant,
        estimateBlocks: Int
    ) {
        do {
            tasks = try CoreClient.shared.updateTask(
                id: task.id,
                title: title,
                quadrant: quadrant,
                estimateBlocks: estimateBlocks,
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

    func reloadSessions() {
        do {
            sessions = try CoreClient.shared.sessions(nowMs: CoreClient.nowMs(), day: currentDay)
        } catch {
            coreError = error.localizedDescription
        }
    }

    func refreshPlan() {
        do {
            plan = try CoreClient.shared.buildPlan(
                nowMs: CoreClient.nowMs(),
                targetMinutes: dailyTargetMinutes,
                bufferMinutes: planBufferMinutes
            )
            lastPlanRefresh = Date()
        } catch {
            coreError = error.localizedDescription
        }
    }

    func setDailyTargetHours(_ hours: Int) {
        dailyTargetMinutes = min(720, max(30, hours * 60))
    }

    func adjustDailyTarget(byMinutes minutes: Int) {
        dailyTargetMinutes = min(720, max(30, dailyTargetMinutes + minutes))
    }

    // MARK: - Theme

    func setTheme(_ mode: AppThemeMode) {
        withAnimation(.easeInOut(duration: 0.35)) {
            themeMode = mode
        }
    }

    func setAppearance(_ appearance: AppAppearance) {
        withAnimation(.easeInOut(duration: 0.28)) {
            appearanceMode = appearance
        }
    }

    func toggleTheme() {
        setTheme(themeMode == .dynamic ? .cozy : .dynamic)
    }

    func openSettings(_ section: AppSettingsSection = .general) {
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

extension TaskQuadrant {
    var tint: Color {
        switch self {
        case .urgentImportant: return Theme.accent
        case .importantNotUrgent: return Theme.mint
        case .urgentNotImportant: return Theme.amber
        case .neither: return Theme.mutedDim
        }
    }
}
