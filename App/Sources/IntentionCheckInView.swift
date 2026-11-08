import Combine
import SwiftUI

struct IntentionCheckInView: View {
    @EnvironmentObject private var model: AppModel
    @State private var intention = ""
    @State private var countdown = 5
    @State private var didBegin = false
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
                        Image(systemName: task.quadrant.icon)
                            .font(Theme.font(9, .semibold))
                            .foregroundStyle(task.quadrant.tint)
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
                        Capsule().fill(task.quadrant.tint.opacity(0.08))
                    }
                    .padding(.top, Theme.s(15))
                }

                VStack(alignment: .leading, spacing: Theme.s(8)) {
                    Text("What single outcome defines success for this \(model.timer.config.focusMinutes)-minute block?")
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

                Spacer(minLength: 18)

                HStack(spacing: Theme.s(10)) {
                    Text("Starting automatically in \(countdown)s")
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
            .frame(width: 520, height: 410)
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
            fieldFocused = true
        }
        .onReceive(ticker) { _ in
            guard !didBegin, countdown > 0 else { return }
            if ProcessInfo.processInfo.arguments.contains("--hold-intention") { return }
            countdown -= 1
            if countdown == 0 { begin() }
        }
        .onExitCommand {
            model.cancelIntentionPrompt()
        }
    }

    private func begin() {
        guard !didBegin else { return }
        didBegin = true
        model.beginFocus(intention: intention)
    }
}
