import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case focus
    case tasks
    case music

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .tasks: return "Tasks"
        case .music: return "Music"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "timer"
        case .tasks: return "checklist"
        case .music: return "play.rectangle.fill"
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case dynamic
    case cozy

    var id: String { rawValue }
    var title: String { self == .dynamic ? "Dynamic" : "Cozy" }
    var subtitle: String {
        self == .dynamic ? "Crisp type, coral light" : "Serif warmth, slower rhythm"
    }
}

enum AnimatedBackground: String, CaseIterable, Identifiable {
    case aurora
    case embers
    case tide
    case orbit
    case bokeh
    case silk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aurora: return "Aurora"
        case .embers: return "Embers"
        case .tide: return "Tide"
        case .orbit: return "Orbit"
        case .bokeh: return "Bokeh"
        case .silk: return "Silk"
        }
    }

    var subtitle: String {
        switch self {
        case .aurora: return "Slow drifting light"
        case .embers: return "Warm rising sparks"
        case .tide: return "Layered evening waves"
        case .orbit: return "Quiet circling rings"
        case .bokeh: return "Soft floating lights"
        case .silk: return "Flowing bands of color"
        }
    }

    var icon: String {
        switch self {
        case .aurora: return "sparkles"
        case .embers: return "flame.fill"
        case .tide: return "water.waves"
        case .orbit: return "circle.dashed"
        case .bokeh: return "circle.grid.cross"
        case .silk: return "wind"
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
    case animated
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .animated: return "Animated"
        case .image: return "Your image"
        }
    }

    var subtitle: String {
        switch self {
        case .animated: return "A living scene from the gallery"
        case .image: return "A photo from your Mac"
        }
    }

    var icon: String {
        switch self {
        case .animated: return "sparkles"
        case .image: return "photo.fill"
        }
    }
}

enum AppSettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .appearance: return "paintpalette.fill"
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

enum TaskQuadrant: String, Codable, CaseIterable, Identifiable {
    case urgentImportant = "urgent_important"
    case importantNotUrgent = "important_not_urgent"
    case urgentNotImportant = "urgent_not_important"
    case neither

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urgentImportant: return "Urgent & important"
        case .importantNotUrgent: return "Important, not urgent"
        case .urgentNotImportant: return "Urgent, not important"
        case .neither: return "Neither"
        }
    }

    var shortTitle: String {
        switch self {
        case .urgentImportant: return "Do first"
        case .importantNotUrgent: return "Schedule"
        case .urgentNotImportant: return "Quick wins"
        case .neither: return "Let go"
        }
    }

    var icon: String {
        switch self {
        case .urgentImportant: return "flame.fill"
        case .importantNotUrgent: return "leaf.fill"
        case .urgentNotImportant: return "bolt.fill"
        case .neither: return "cloud.fill"
        }
    }

    var detail: String {
        switch self {
        case .urgentImportant: return "Clear the fire"
        case .importantNotUrgent: return "Protect the deep work"
        case .urgentNotImportant: return "Keep it short"
        case .neither: return "Not now"
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgentImportant: return 0
        case .importantNotUrgent: return 1
        case .urgentNotImportant: return 2
        case .neither: return 3
        }
    }
}

struct TaskItem: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var quadrant: TaskQuadrant
    var estimateBlocks: Int
    var completedBlocks: Int
    var focusedMinutes: Int
    var done: Bool
    var createdAtMs: Int
    var completedAtMs: Int?
    var completedDay: String?
    var lastFocusedAtMs: Int?

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
    let quadrant: TaskQuadrant?
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
