import AppIntents

/// Shortcuts, Siri and Spotlight actions. They run in the app process and drive the
/// same `AppModel` the UI uses, so toasts, music-follows-timer and the focus guard apply.

enum CadenceIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notReady
    case emptyTitle

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady: return "Cadence isn't ready yet. Open it and try again."
        case .emptyTitle: return "The task needs a title."
        }
    }
}

@MainActor
private func cadenceModel() throws -> AppModel {
    guard let model = AppModel.shared else { throw CadenceIntentError.notReady }
    return model
}

struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus"
    static var description = IntentDescription("Starts a Cadence focus interval, or resumes a paused one.")

    @Parameter(title: "Intention", description: "What this block is for.")
    var intention: String?

    @Parameter(title: "Minutes", description: "A one-off length for this interval (1–180).")
    var minutes: Int?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try cadenceModel()
        model.startFocus(intention: intention, minutes: minutes)
        let remaining = model.timer.formattedRemaining
        return .result(dialog: model.timer.running ? "Focusing. \(remaining) to go." : "Couldn't start focus.")
    }
}

struct PauseFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Timer"
    static var description = IntentDescription("Pauses the running Cadence interval.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try cadenceModel()
        guard model.timer.running else { return .result(dialog: "Nothing is running.") }
        model.pauseTimer()
        return .result(dialog: "Paused with \(model.timer.formattedRemaining) left.")
    }
}

extension TaskPriority: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Priority"
    static var caseDisplayRepresentations: [TaskPriority: DisplayRepresentation] = [
        .high: "High",
        .medium: "Medium",
        .low: "Low",
    ]
}

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Adds a card to the To Do column of the Cadence board.")

    @Parameter(title: "Title")
    var taskTitle: String

    @Parameter(title: "Priority", default: .medium)
    var priority: TaskPriority

    @Parameter(title: "Estimate (minutes)", description: "Split into focus blocks.")
    var minutes: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle) to Cadence") {
            \.$priority
            \.$minutes
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw CadenceIntentError.emptyTitle }
        let model = try cadenceModel()
        model.addTask(
            title: title,
            priority: priority,
            estimateBlocks: 1,
            estimateMinutes: minutes.map { min(1440, max(1, $0)) }
        )
        return .result(dialog: "Added “\(title)”.")
    }
}

struct CadenceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: ["Start focus in \(.applicationName)", "Start a \(.applicationName) focus block"],
            shortTitle: "Start Focus",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: PauseFocusIntent(),
            phrases: ["Pause \(.applicationName)", "Pause the \(.applicationName) timer"],
            shortTitle: "Pause Timer",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: ["Add a task to \(.applicationName)", "New \(.applicationName) task"],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
    }
}
