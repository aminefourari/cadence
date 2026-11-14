import Charts
import SwiftUI

/// This week against the weekly goal: per-day focus, top tasks and last week's total.
struct WeeklyReviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var week: WeekSummary { model.week }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s(18)) {
            header
            goalPanel
            HStack(alignment: .top, spacing: Theme.s(14)) {
                chartPanel.frame(maxWidth: .infinity)
                tasksPanel.frame(width: 250)
            }
            HStack {
                Text("Weeks run Monday to Sunday. Agents can read this too with week_summary.")
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
                Spacer()
                AccentButton(title: "Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.s(26))
        .frame(width: 720)
        .background {
            LinearGradient(colors: [Theme.inkDeep, Theme.ink, Theme.backgroundEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .preferredColorScheme(model.colorScheme)
        .onAppear { model.refreshWeek() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.s(4)) {
                Text("Week in review")
                    .font(Theme.font(25, .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                Text(rangeLabel)
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Theme.font(9, .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 27, height: 27)
                    .background { Circle().fill(Theme.cream.opacity(0.05)) }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
    }

    private var goalPanel: some View {
        VStack(alignment: .leading, spacing: Theme.s(12)) {
            HStack(alignment: .firstTextBaseline) {
                Text(Self.hours(week.focusMinutes))
                    .font(Theme.font(34, .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .monospacedDigit()
                Text("of your \(Self.hours(week.targetMinutes)) goal")
                    .font(Theme.font(12, .medium))
                    .foregroundStyle(Theme.muted)
                Spacer()
                goalStepper
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.controlFill)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: week.focusMinutes == 0 ? 0 : max(8, proxy.size.width * week.progress))
                }
            }
            .frame(height: 8)
            HStack(spacing: 0) {
                metric("\(week.sessions)", "sessions")
                metric("\(week.activeDays) of 7", "days with focus")
                metric(week.bestDay.map { "\(weekday($0.day)) · \(Self.hours($0.minutes))" } ?? "—", "best day")
                metric(comparison, "vs last week")
            }
        }
        .padding(Theme.s(18))
        .panel(cornerRadius: Theme.radius(18))
    }

    private var goalStepper: some View {
        HStack(spacing: Theme.s(6)) {
            Text("Weekly goal")
                .font(Theme.font(10, .medium))
                .foregroundStyle(Theme.mutedDim)
            stepButton("minus") { model.setWeeklyTargetHours(week.targetMinutes / 60 - 1) }
            Text("\(week.targetMinutes / 60)h")
                .font(Theme.font(11, .semibold, design: .monospaced))
                .foregroundStyle(Theme.cream)
                .frame(minWidth: 30)
            stepButton("plus") { model.setWeeklyTargetHours(week.targetMinutes / 60 + 1) }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.font(9, .bold))
                .foregroundStyle(Theme.cream.opacity(0.75))
                .frame(width: 24, height: 24)
                .background { Circle().fill(Theme.controlFill) }
                .overlay { Circle().strokeBorder(Theme.controlStroke, lineWidth: 1) }
        }
        .buttonStyle(PressableStyle())
    }

    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: Theme.s(12)) {
            SectionLabel(text: "Focus per day")
            Chart {
                ForEach(week.days, id: \.day) { day in
                    BarMark(x: .value("Day", weekday(day.day)), y: .value("Minutes", day.minutes))
                        .foregroundStyle(day.day == model.currentDay ? Theme.accent : Theme.accent.opacity(0.55))
                        .cornerRadius(3)
                }
                RuleMark(y: .value("Daily target", model.dailyTargetMinutes))
                    .foregroundStyle(Theme.mutedDim)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) { Text("\(minutes)m").foregroundStyle(Theme.mutedDim) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.mutedDim) }
            }
            .frame(height: 180)
            Text("Dashed line: your daily target.")
                .font(Theme.font(9, .medium))
                .foregroundStyle(Theme.mutedDim)
        }
        .padding(Theme.s(16))
        .panel(cornerRadius: Theme.radius(18))
    }

    private var tasksPanel: some View {
        VStack(alignment: .leading, spacing: Theme.s(10)) {
            SectionLabel(text: "Where it went")
            if week.topTasks.isEmpty {
                Text("Finish a focus block this week to see it here.")
                    .font(Theme.font(10, .medium))
                    .foregroundStyle(Theme.mutedDim)
            } else {
                ForEach(week.topTasks, id: \.title) { row in
                    VStack(alignment: .leading, spacing: Theme.s(4)) {
                        HStack {
                            Text(row.title)
                                .font(Theme.font(10.5, .medium))
                                .foregroundStyle(Theme.cream.opacity(0.9))
                                .lineLimit(1)
                            Spacer()
                            Text(Self.hours(row.minutes))
                                .font(Theme.font(10, .semibold, design: .monospaced))
                                .foregroundStyle(Theme.muted)
                        }
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Theme.accent.opacity(0.7))
                                .frame(width: max(4, proxy.size.width * CGFloat(row.minutes) / CGFloat(max(1, week.focusMinutes))))
                        }
                        .frame(height: 5)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(Theme.s(16))
        .panel(cornerRadius: Theme.radius(18))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.s(2)) {
            Text(value)
                .font(Theme.font(13, .semibold, design: .rounded))
                .foregroundStyle(Theme.cream)
                .monospacedDigit()
            Text(label)
                .font(Theme.font(9.5, .medium))
                .foregroundStyle(Theme.mutedDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparison: String {
        let previous = week.previousWeekMinutes
        guard previous > 0 else { return week.focusMinutes > 0 ? "New" : "—" }
        let change = Int((Double(week.focusMinutes - previous) / Double(previous) * 100).rounded())
        return change >= 0 ? "+\(change)%" : "\(change)%"
    }

    private var rangeLabel: String {
        guard let first = week.days.first.flatMap({ Self.dayParser.date(from: $0.day) }),
              let last = week.days.last.flatMap({ Self.dayParser.date(from: $0.day) }) else { return "This week" }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func weekday(_ day: String) -> String {
        Self.dayParser.date(from: day)?.formatted(.dateTime.weekday(.abbreviated)) ?? day
    }

    static func hours(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : (minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m")
    }
}
