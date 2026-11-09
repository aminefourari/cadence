import Combine
import SwiftUI

struct IntentionCheckInView: View {
    @EnvironmentObject private var model: AppModel
    @State private var intention = ""
    @State private var countdown = 5
    @State private var didBegin = false
    @State private var minutes = 25
    @State private var holding = false
    @FocusState private var fieldFocused: Bool

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()
                .onTapGesture { } // keep the check-in intentional

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Theme.s(5)) {
                        Text("Before you begin")
                            .font(Theme.font(11, .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.mutedDim)
                            .textCase(.uppercase)
                        Text("One outcome for this block.")
                            .font(Theme.font(25, .semibold, design: .rounded))
                            .foregroundStyle(Theme.cream)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Theme.cream.opacity(0.07), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: Double(countdown) / 5.0)
                            .stroke(
                                Theme.accent,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.25), value: countdown)
                        Text("\(countdown)")
                            .font(Theme.font(16, .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.cream)
                    }
                    .frame(width: 48, height: 48)
                }

                if let task = model.activeTask {
                    HStack(spacing: Theme.s(7)) {
                        Image(systemName: task.priority.icon)
                            .font(Theme.font(9, .semibold))
                            .foregroundStyle(task.priority.tint)
                        Text(task.title)
                            .font(Theme.font(10.5, .medium))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Text("· \(task.completedBlocks)/\(task.estimateBlocks) blocks")
                            .font(Theme.font(9.5, .medium))
                            .foregroundStyle(Theme.mutedDim)
                    }
                    .padding(.horizontal, Theme.s(10))
                    .frame(height: 30)
                    .background {
                        Capsule().fill(task.priority.tint.opacity(0.08))
                    }
                    .padding(.top, Theme.s(15))
                }

                VStack(alignment: .leading, spacing: Theme.s(8)) {
                    Text("What single outcome defines success for this \(minutes)-minute block?")
                        .font(Theme.font(11, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(2)

                    TextField("e.g. A clear first draft", text: $intention)
                        .textFieldStyle(.plain)
                        .font(Theme.font(14, .medium))
                        .foregroundStyle(Theme.cream)
                        .tint(Theme.accent)
                        .focused($fieldFocused)
                        .onSubmit(begin)
                        .onChange(of: intention) { _, _ in holding = true }
                        .padding(.horizontal, Theme.s(13))
                        .frame(height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.radius(11), style: .continuous)
                                .fill(Theme.cream.opacity(0.04))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.radius(11), style: .continuous)
                                .strokeBorder(fieldFocused ? Theme.accent.opacity(0.4) : Theme.cream.opacity(0.07), lineWidth: 1)
                        }
                }
                .padding(.top, Theme.s(22))

                lengthRow
                    .padding(.top, Theme.s(16))

                Spacer(minLength: 18)

                HStack(spacing: Theme.s(10)) {
                    Text(holding ? "Press Return to begin" : "Starting automatically in \(countdown)s")
                        .font(Theme.font(9.5, .medium))
                        .foregroundStyle(Theme.mutedDim)
                    Spacer()
                    QuietButton(title: "Not now") {
                        model.cancelIntentionPrompt()
                    }
                    AccentButton(title: "Begin focus", icon: "play.fill", action: begin)
                }
            }
            .padding(Theme.s(26))
            .frame(width: 520, height: 445)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius(26), style: .continuous)
                        .fill(Theme.surface.opacity(0.96))
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.1), .clear],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: 400
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius(26), style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(26), style: .continuous)
                    .strokeBorder(Theme.cream.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 40, x: 0, y: 24)
            .scaleEffect(0.99)
        }
        .onAppear {
            minutes = model.timer.intervalMinutes
            fieldFocused = true
        }
        .onReceive(ticker) { _ in
            guard !didBegin, !holding, countdown > 0 else { return }
            if ProcessInfo.processInfo.arguments.contains("--hold-intention") { return }
            countdown -= 1
            if countdown == 0 { begin() }
        }
        .onExitCommand {
            model.cancelIntentionPrompt()
        }
    }

    private var lengthRow: some View {
        let standard = model.timer.config.focusMinutes
        return HStack(spacing: Theme.s(10)) {
            VStack(alignment: .leading, spacing: Theme.s(3)) {
                Text("Length")
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(Theme.cream.opacity(0.9))
                Text(minutes == standard
                     ? "Your usual block"
                     : "This block only · next ones are \(standard) min")
                    .font(Theme.font(9.5, .medium))
                    .foregroundStyle(minutes == standard ? Theme.mutedDim : Theme.accent.opacity(0.9))
            }
            Spacer()
            ForEach(lengthPresets(standard: standard), id: \.self) { preset in
                Button {
                    holding = true
                    minutes = preset
                } label: {
                    Text("\(preset)")
                        .font(Theme.font(10.5, .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(minutes == preset ? Theme.onAccent : Theme.cream.opacity(0.8))
                        .frame(width: 34, height: 28)
                        .background {
                            Capsule().fill(minutes == preset ? Theme.accent : Theme.controlFill)
                        }
                        .overlay {
                            Capsule().strokeBorder(Theme.controlStroke, lineWidth: minutes == preset ? 0 : 1)
                        }
                }
                .buttonStyle(.plain)
            }
            Divider().frame(height: 18)
            Button {
                holding = true
                minutes = TimerState.lengthStep(from: minutes, up: false)
            } label: { Image(systemName: "minus") }
                .buttonStyle(CircleControlStyle(size: 28))
                .disabled(minutes <= 1)
            Text("\(minutes) min")
                .font(Theme.font(12, .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.cream)
                .frame(width: 54)
            Button {
                holding = true
                minutes = TimerState.lengthStep(from: minutes, up: true)
            } label: { Image(systemName: "plus") }
                .buttonStyle(CircleControlStyle(size: 28))
                .disabled(minutes >= 180)
        }
    }

    /// Common shorter options plus the usual length, e.g. 10 · 15 · 20 · 25.
    private func lengthPresets(standard: Int) -> [Int] {
        Array(Set([10, 15, 20, standard].filter { $0 <= standard })).sorted()
    }

    private func begin() {
        guard !didBegin else { return }
        didBegin = true
        model.beginFocus(intention: intention, minutes: minutes)
    }
}
