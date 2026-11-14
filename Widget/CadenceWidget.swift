import SwiftUI
import WidgetKit

struct CadenceEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct CadenceProvider: TimelineProvider {
    func placeholder(in context: Context) -> CadenceEntry {
        CadenceEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CadenceEntry) -> Void) {
        completion(CadenceEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load() ?? .placeholder))
    }

    /// The app reloads timelines whenever what the widget shows changes. A running
    /// interval gets a second entry at its end; the 30-minute refresh catches the new day.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CadenceEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        var entries = [CadenceEntry(date: .now, snapshot: snapshot)]
        if let snapshot, snapshot.running, let end = snapshot.endsAt, end > .now {
            entries.append(CadenceEntry(date: end, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

private enum Palette {
    static let focus = Color(red: 0.96, green: 0.46, blue: 0.38)
    static let rest = Color(red: 0.42, green: 0.80, blue: 0.67)
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let inkDeep = Color(red: 0.05, green: 0.05, blue: 0.07)
}

struct CadenceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CadenceEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if family == .systemSmall {
                    timerColumn(snapshot)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        timerColumn(snapshot)
                        Divider().overlay(Color.white.opacity(0.08))
                        weekColumn(snapshot)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CADENCE").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
                    Spacer()
                    Text("Open Cadence to start focusing.").font(.system(size: 13, weight: .medium))
                }
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Palette.inkDeep, Palette.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(URL(string: "cadence://open"))
    }

    private func accent(_ snapshot: WidgetSnapshot) -> Color {
        snapshot.isFocus ? Palette.focus : Palette.rest
    }

    private func timerColumn(_ snapshot: WidgetSnapshot) -> some View {
        let ended = snapshot.running && (snapshot.endsAt ?? .distantFuture) <= entry.date
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(accent(snapshot)).frame(width: 6, height: 6).opacity(snapshot.running ? 1 : 0.5)
                Text(snapshot.phaseTitle.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            Group {
                if snapshot.running, !ended, let end = snapshot.endsAt {
                    Text(timerInterval: entry.date...end, countsDown: true)
                } else {
                    Text(ended ? "0:00" : Self.clock(snapshot.remainingSeconds))
                }
            }
            .font(.system(size: 30, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            Text(ended ? "Interval complete" : (snapshot.taskTitle ?? (snapshot.running ? "Focusing" : "Ready")))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 0)
            ProgressView(value: Double(min(snapshot.todayMinutes, snapshot.dailyTargetMinutes)), total: Double(max(1, snapshot.dailyTargetMinutes)))
                .tint(accent(snapshot))
            Text("\(Self.hours(snapshot.todayMinutes)) of \(Self.hours(snapshot.dailyTargetMinutes)) today")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weekColumn(_ snapshot: WidgetSnapshot) -> some View {
        let progress = Double(snapshot.weekMinutes) / Double(max(1, snapshot.weeklyTargetMinutes))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(1, progress))
                        .stroke(Palette.focus, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                    Text("\(Self.hours(snapshot.weekMinutes)) / \(Self.hours(snapshot.weeklyTargetMinutes))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            if let next = snapshot.nextBlockTitle {
                VStack(alignment: .leading, spacing: 1) {
                    Text("UP NEXT").font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(.white.opacity(0.45))
                    Text(next).font(.system(size: 10.5, weight: .medium)).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Link(destination: URL(string: "cadence://toggle")!) {
                Label(snapshot.running ? "Pause" : "Start", systemImage: snapshot.running ? "pause.fill" : "play.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(accent(snapshot)))
                    .foregroundStyle(Palette.inkDeep)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func hours(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : (minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m")
    }
}

@main
struct CadenceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CadenceTimer", provider: CadenceProvider()) { entry in
            CadenceWidgetView(entry: entry)
        }
        .configurationDisplayName("Cadence")
        .description("The focus timer, today's progress and this week's goal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
