import Charts
import SwiftUI

/// Read-only view over the focus sessions the core logs on every completed block.
struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        let stats = HistoryStats(sessions: model.sessions, today: model.currentDate, formatter: Self.dayFormatter)

        VStack(alignment: .leading, spacing: Theme.s(18)) {
            header(stats)

            HStack(spacing: Theme.s(12)) {
                tile(value: Self.hours(stats.weekMinutes), label: "Focused this week", tint: Theme.accent)
                tile(value: "\(stats.streak) \(stats.streak == 1 ? "day" : "days")", label: "Current streak", tint: Theme.amber)
                tile(value: Self.hours(stats.bestDayMinutes), label: "Best day", tint: Theme.mint)
                tile(value: "\(model.sessions.count)", label: "Sessions logged", tint: Theme.sky)
            }

            HStack(alignment: .top, spacing: Theme.s(16)) {
                VStack(alignment: .leading, spacing: Theme.s(16)) {
                    chartPanel(stats)
                    priorityPanel(stats)
                }
                .frame(maxWidth: .infinity)

                recentPanel
                    .frame(width: 300)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Theme.s(34))
        .padding(.top, Theme.s(40))
        .padding(.bottom, Theme.s(22))
    }

    private func header(_ stats: HistoryStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.s(7)) {
            Text("History")
                .font(Theme.font(31, .semibold, design: .rounded))
                .foregroundStyle(Theme.cream)
                .tracking(-0.4)
            HStack(spacing: Theme.s(8)) {
                Text("WHERE YOUR FOCUS WENT")
                    .font(Theme.font(9.5, .semibold))
                    .tracking(1.35)
                    .foregroundStyle(Theme.mutedDim)
                Circle()
                    .fill(Theme.mutedDim.opacity(0.55))
                    .frame(width: 2, height: 2)
                Text("\(Self.hours(stats.totalMinutes)) all time")
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func tile(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.s(4)) {
            Text(value)
                .font(Theme.font(20, .semibold, design: .rounded))
                .foregroundStyle(Theme.cream)
                .monospacedDigit()
            Text(label)
                .font(Theme.font(9.5, .medium))
                .foregroundStyle(Theme.mutedDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.s(14))
        .overlay(alignment: .topTrailing) {
            Circle().fill(tint).frame(width: 6, height: 6).padding(Theme.s(12))
        }
        .panel(cornerRadius: Theme.radius(16))
    }

    private func chartPanel(_ stats: HistoryStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.s(12)) {
            SectionLabel(text: "Last 14 days")
            Chart(stats.lastTwoWeeks) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Minutes", day.minutes)
                )
                .foregroundStyle(day.isToday ? Theme.accent : Theme.accent.opacity(0.55))
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow).day())
                        .foregroundStyle(Theme.mutedDim)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes)m").foregroundStyle(Theme.mutedDim)
                        }
                    }
                }
            }
            .frame(minHeight: 170)
        }
        .padding(Theme.s(16))
        .panel(cornerRadius: Theme.radius(18))
    }

    private func priorityPanel(_ stats: HistoryStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.s(10)) {
            SectionLabel(text: "This week by priority")
            if stats.weekMinutes == 0 {
                Text("Finish a focus block with a task attached to see the split.")
                    .font(Theme.font(10, .medium))
                    .foregroundStyle(Theme.mutedDim)
            } else {
                ForEach(stats.weekByPriority, id: \.label) { row in
                    HStack(spacing: Theme.s(10)) {
                        Text(row.label)
                            .font(Theme.font(10, .medium))
                            .foregroundStyle(Theme.cream.opacity(0.85))
                            .frame(width: 140, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule()
                                .fill(row.tint.opacity(0.75))
                                .frame(width: max(4, proxy.size.width * CGFloat(row.minutes) / CGFloat(max(1, stats.weekMinutes))))
                        }
                        .frame(height: 7)
                        Text("\(row.minutes)m")
                            .font(Theme.font(10, .semibold, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.s(16))
        .panel(cornerRadius: Theme.radius(18))
    }

    private var recentPanel: some View {
        VStack(alignment: .leading, spacing: Theme.s(10)) {
            SectionLabel(text: "Recent sessions")
            if model.sessions.isEmpty {
                Spacer()
                Text("Completed focus blocks show up here, with the task and intention you set.")
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: Theme.s(8)) {
                        ForEach(model.sessions.reversed().prefix(100)) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
        .padding(Theme.s(16))
        .panel(cornerRadius: Theme.radius(18))
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        HStack(alignment: .top, spacing: Theme.s(9)) {
            Circle()
                .fill(session.priority?.tint ?? Theme.mutedDim)
                .frame(width: 6, height: 6)
                .padding(.top, Theme.s(5))
            VStack(alignment: .leading, spacing: Theme.s(2)) {
                Text(session.taskTitle ?? "Untitled focus")
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.cream.opacity(0.9))
                    .lineLimit(1)
                if let intention = session.intention, !intention.isEmpty {
                    Text("“\(intention)”")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                Text("\(session.completedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())) · \(session.minutes)m")
                    .font(Theme.font(8.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
            }
        }
    }

    private static func hours(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}

/// Aggregates computed from the session log. Days are the core's `yyyy-MM-dd` strings.
struct HistoryStats {
    struct Day: Identifiable {
        let date: Date
        let minutes: Int
        let isToday: Bool
        var id: Date { date }
    }

    struct PriorityRow {
        let label: String
        let tint: Color
        let minutes: Int
    }

    let totalMinutes: Int
    let weekMinutes: Int
    let bestDayMinutes: Int
    let streak: Int
    let lastTwoWeeks: [Day]
    let weekByPriority: [PriorityRow]

    init(sessions: [FocusSession], today: Date, formatter: DateFormatter) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        var minutesByDay: [String: Int] = [:]
        for session in sessions {
            minutesByDay[session.day, default: 0] += session.minutes
        }
        func key(daysAgo: Int) -> (String, Date) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: start) ?? start
            return (formatter.string(from: date), date)
        }

        totalMinutes = minutesByDay.values.reduce(0, +)
        bestDayMinutes = minutesByDay.values.max() ?? 0

        let weekKeys = Set((0..<7).map { key(daysAgo: $0).0 })
        weekMinutes = weekKeys.reduce(0) { $0 + (minutesByDay[$1] ?? 0) }

        lastTwoWeeks = (0..<14).reversed().map { offset in
            let (day, date) = key(daysAgo: offset)
            return Day(date: date, minutes: minutesByDay[day] ?? 0, isToday: offset == 0)
        }

        // A streak survives a today with no sessions yet; it counts back from yesterday.
        var streak = 0
        var offset = (minutesByDay[key(daysAgo: 0).0] ?? 0) > 0 ? 0 : 1
        while (minutesByDay[key(daysAgo: offset).0] ?? 0) > 0 {
            streak += 1
            offset += 1
        }
        self.streak = streak

        var byPriority: [TaskPriority?: Int] = [:]
        for session in sessions where weekKeys.contains(session.day) {
            byPriority[session.priority, default: 0] += session.minutes
        }
        var rows = TaskPriority.allCases.compactMap { priority -> PriorityRow? in
            guard let minutes = byPriority[priority], minutes > 0 else { return nil }
            return PriorityRow(label: "\(priority.title) priority", tint: priority.tint, minutes: minutes)
        }
        if let untagged = byPriority[nil], untagged > 0 {
            rows.append(PriorityRow(label: "No task", tint: Theme.mutedDim, minutes: untagged))
        }
        weekByPriority = rows
    }
}
