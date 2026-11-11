import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case focus
    case tasks
    case music
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .tasks: return "Tasks"
        case .music: return "Music"
        case .history: return "History"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "timer"
        case .tasks: return "checklist"
        case .music: return "play.rectangle.fill"
        case .history: return "chart.bar.fill"
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case dynamic
    case cozy
    case blossom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .dynamic: return "Dynamic"
        case .cozy: return "Cozy"
        case .blossom: return "Blossom"
        }
    }
    var subtitle: String {
        switch self {
        case .dynamic: return "Crisp type, coral light"
        case .cozy: return "Serif warmth, slower rhythm"
        case .blossom: return "Rose petals, rounded softness"
        }
    }

    /// Bundled Unsplash photo (Assets.xcassets) used by the "Theme photo" background.
    var photoName: String {
        switch self {
        case .dynamic: return "ThemeDynamic"
        case .cozy: return "ThemeCozy"
        case .blossom: return "ThemeBlossom"
        }
    }

    var photoCredit: String {
        switch self {
        case .dynamic: return "Lison Zhao"
        case .cozy: return "Clay Banks"
        case .blossom: return "Anita Austvika"
        }
    }
}

enum AnimatedBackground: String, CaseIterable, Identifiable {
    case rainyForest
    case rainyCafe
    case cityRain
    case snowyForest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rainyForest: return "Rainy forest"
        case .rainyCafe: return "Rainy café"
        case .cityRain: return "City rain"
        case .snowyForest: return "Snowfall"
        }
    }

    var subtitle: String {
        switch self {
        case .rainyForest: return "Pines, fog and steady rain"
        case .rainyCafe: return "Street lights through a wet window"
        case .cityRain: return "A night skyline in the rain"
        case .snowyForest: return "Quiet snow over the pines"
        }
    }

    var icon: String {
        switch self {
        case .rainyForest: return "cloud.rain.fill"
        case .rainyCafe: return "cup.and.saucer.fill"
        case .cityRain: return "building.2.fill"
        case .snowyForest: return "snowflake"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppBackgroundStyle: String, CaseIterable, Identifiable {
    case theme
    case animated
    case image
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: return "Theme photo"
        case .animated: return "Animated"
        case .image: return "Your image"
        case .video: return "Your video"
        }
    }

    var subtitle: String {
        switch self {
        case .theme: return "A photo that follows your theme"
        case .animated: return "A living scene from the gallery"
        case .image: return "A photo from your Mac"
        case .video: return "A looping video from your Mac"
        }
    }

    var icon: String {
        switch self {
        case .theme: return "photo.artframe"
        case .animated: return "sparkles"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        }
    }
}

enum AppSettingsSection: String, CaseIterable, Identifiable {
    case timer
    case automation
    case appearance
    case notifications
    case agents
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: return "Timer"
        case .automation: return "Automation"
        case .appearance: return "Appearance"
        case .notifications: return "Notifications"
        case .agents: return "AI Agents"
        case .updates: return "Updates"
        }
    }

    var subtitle: String {
        switch self {
        case .timer: return "Interval lengths and how one flows into the next."
        case .automation: return "What happens around a focus block."
        case .appearance: return "Theme, light or dark, and the scene behind everything."
        case .notifications: return "How Cadence tells you an interval ended."
        case .agents: return "Let Claude Code, Codex or opencode manage your tasks over MCP."
        case .updates: return "New versions straight from GitHub."
        }
    }

    var icon: String {
        switch self {
        case .timer: return "timer"
        case .automation: return "wand.and.stars"
        case .appearance: return "paintpalette.fill"
        case .notifications: return "bell.badge.fill"
        case .agents: return "sparkles"
        case .updates: return "arrow.down.circle.fill"
        }
    }
}

enum PomodoroPhase: String, Codable, CaseIterable, Identifiable {
    case focus
    case shortBreak = "short_break"
    case longBreak = "long_break"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var shortTitle: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short"
        case .longBreak: return "Long"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "scope"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "moon.stars.fill"
        }
    }

    var isBreak: Bool { self != .focus }
}

struct PomodoroConfig: Codable, Equatable {
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var sessionsBeforeLongBreak: Int
    var autoStartNext: Bool

    static let defaults = PomodoroConfig(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        sessionsBeforeLongBreak: 4,
        autoStartNext: false
    )

    func minutes(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }
}

struct TimerTransition: Codable, Identifiable {
    let id: Int
    let completedPhase: PomodoroPhase
    let nextPhase: PomodoroPhase
    let skipped: Bool
    let autoStarted: Bool
    let focusMinutesAdded: Int
}

struct TimerState: Codable {
    let phase: PomodoroPhase
    let running: Bool
    let remainingMs: Int
    let totalMs: Int
    let endsAtMs: Int?
    let completedInCycle: Int
    let cycleLength: Int
    let todayFocusMinutes: Int
    let todaySessions: Int
    let totalSessions: Int
    let config: PomodoroConfig
    let activeTaskId: String?
    let intention: String?
    let transition: TimerTransition?
    /// Changes when another process (cadence-mcp) edited the saved state.
    var externalRevision: Int? = nil

    static let placeholder = TimerState(
        phase: .focus,
        running: false,
        remainingMs: 25 * 60 * 1000,
        totalMs: 25 * 60 * 1000,
        endsAtMs: nil,
        completedInCycle: 0,
        cycleLength: 4,
        todayFocusMinutes: 0,
        todaySessions: 0,
        totalSessions: 0,
        config: .defaults,
        activeTaskId: nil,
        intention: nil,
        transition: nil
    )

    var remainingSeconds: Int {
        max(0, Int(ceil(Double(remainingMs) / 1000.0)))
    }

    var remainingFraction: Double {
        guard totalMs > 0 else { return 0 }
        return min(1, max(0, Double(remainingMs) / Double(totalMs)))
    }

    var isFreshInterval: Bool {
        remainingMs == totalMs
    }

    /// Length of the current interval in minutes (may be a one-off override).
    var intervalMinutes: Int {
        Int((Double(totalMs) / 60_000).rounded())
    }

    /// True when the current interval uses a one-off length instead of the configured one.
    var hasCustomLength: Bool {
        intervalMinutes != config.minutes(for: phase)
    }

    /// Step for adjusting an interval: 5 minutes, or 1 below 10 minutes.
    static func lengthStep(from minutes: Int, up: Bool) -> Int {
        let step = (up ? minutes : minutes - 1) < 10 ? 1 : 5
        return min(180, max(1, minutes + (up ? step : -step)))
    }

    var formattedRemaining: String {
        Self.clockString(seconds: remainingSeconds)
    }

    static func clockString(seconds: Int) -> String {
        let seconds = max(0, seconds)
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var icon: String {
        switch self {
        case .high: return "chevron.up.2"
        case .medium: return "equal"
        case .low: return "chevron.down"
        }
    }

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

struct TaskItem: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var priority: TaskPriority
    var estimateBlocks: Int
    var completedBlocks: Int
    var focusedMinutes: Int
    var done: Bool
    var createdAtMs: Int
    var completedAtMs: Int?
    var completedDay: String?
    var lastFocusedAtMs: Int?
    var inProgress: Bool
    var archived: Bool
    var position: Int

    var remainingBlocks: Int {
        max(0, estimateBlocks - completedBlocks)
    }

    var progress: Double {
        guard estimateBlocks > 0 else { return 0 }
        return min(1, max(0, Double(completedBlocks) / Double(estimateBlocks)))
    }
}

enum PlanBlockKind: String, Codable {
    case focus
    case shortBreak = "short_break"
    case longBreak = "long_break"

    var isFocus: Bool { self == .focus }
    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}

struct PlanBlock: Codable, Identifiable, Equatable {
    let id: String
    let kind: PlanBlockKind
    let taskId: String?
    let taskTitle: String?
    let priority: TaskPriority?
    let startAtMs: Int
    let endAtMs: Int
    let minutes: Int

    var startDate: Date { Date(timeIntervalSince1970: Double(startAtMs) / 1000) }
    var endDate: Date { Date(timeIntervalSince1970: Double(endAtMs) / 1000) }
}

struct DayPlan: Codable, Equatable {
    let blocks: [PlanBlock]
    let focusMinutes: Int
    let targetMinutes: Int
    let startAtMs: Int
    let endAtMs: Int

    static let empty = DayPlan(
        blocks: [],
        focusMinutes: 0,
        targetMinutes: 0,
        startAtMs: 0,
        endAtMs: 0
    )
}

/// A completed focus block, logged by the Rust core (`tasks::FocusSession`).
struct FocusSession: Codable, Identifiable, Equatable {
    let id: String
    let taskId: String?
    let taskTitle: String?
    let priority: TaskPriority?
    let intention: String?
    let minutes: Int
    let completedAtMs: Int
    let day: String

    var completedAt: Date { Date(timeIntervalSince1970: Double(completedAtMs) / 1000) }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let tint: Color
}

extension Double {
    var clockString: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self.rounded(.down))
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

extension Date {
    var shortTimeString: String {
        formatted(date: .omitted, time: .shortened)
    }
}
