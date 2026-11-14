import Foundation

/// What the widget shows. The app writes it into the App Group container shared with the
/// sandboxed widget extension; the widget never talks to the core directly.
struct WidgetSnapshot: Codable, Equatable {
    static let appGroup = "T7A3N2UXYN.com.amine.cadence"

    /// `focus`, `short_break` or `long_break`, as the core names phases.
    var phase: String
    var phaseTitle: String
    var running: Bool
    var endsAt: Date?
    /// Only meaningful while paused; a running interval counts down to `endsAt`.
    var remainingSeconds: Int
    var taskTitle: String?
    var todayMinutes: Int
    var dailyTargetMinutes: Int
    var weekMinutes: Int
    var weeklyTargetMinutes: Int
    var nextBlockTitle: String?

    var isFocus: Bool { phase == "focus" }

    static let placeholder = WidgetSnapshot(
        phase: "focus", phaseTitle: "Focus", running: false, endsAt: nil, remainingSeconds: 25 * 60,
        taskTitle: "Draft the API specification", todayMinutes: 75, dailyTargetMinutes: 240,
        weekMinutes: 410, weeklyTargetMinutes: 1200, nextBlockTitle: "Review the Q4 roadmap"
    )

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() throws {
        guard let url = Self.fileURL else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
