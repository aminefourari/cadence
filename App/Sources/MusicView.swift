import AppKit
import SwiftUI

struct MusicView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: YouTubePlayerController
    @State private var urlInput = ""
    @State private var volumeDraft: Double = 70
    @State private var editingVolume = false
    @FocusState private var urlFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            urlBar
                .padding(.top, Theme.s(16))

            videoCard
                .padding(.top, Theme.s(14))

            if player.hasVideo {
                nowPlaying
                    .padding(.top, Theme.s(14))
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, Theme.s(34))
        .padding(.top, Theme.s(40))
        .padding(.bottom, Theme.s(20))
        .onAppear {
            volumeDraft = player.volume
            player.autoImportFromBraveIfNeeded()
        }
        .onChange(of: player.volume) { _, value in
            if !editingVolume { volumeDraft = value }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.s(7)) {
                Text("Music")
                    .font(Theme.font(31, .semibold, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .tracking(-0.4)

                HStack(spacing: Theme.s(8)) {
                    Text("YOUTUBE, INSIDE CADENCE")
                        .font(Theme.font(9.5, .semibold))
                        .tracking(1.35)
                        .foregroundStyle(Theme.mutedDim)
                    Circle()
                        .fill(Theme.mutedDim.opacity(0.55))
                        .frame(width: 2, height: 2)
                    Text("Keep playing while you focus")
                        .font(Theme.font(10.5, .medium))
                        .foregroundStyle(Theme.muted)
                }
            }

            Spacer()

            HStack(spacing: Theme.s(10)) {
                StatusPill(
                    text: playerStatus,
                    color: playerStatusColor,
                    pulsing: player.isPlaying
                )
                UtilityIconButton(icon: "gearshape.fill", help: "Preferences") {
                    model.showSettings = true
                }
            }
            .padding(.top, Theme.s(5))
        }
    }

    private var urlBar: some View {
        HStack(spacing: Theme.s(10)) {
            Image(systemName: "link")
                .font(Theme.font(12, .medium))
                .foregroundStyle(Theme.mutedDim)

            TextField("Paste a YouTube link or video ID", text: $urlInput)
                .textFieldStyle(.plain)
                .font(Theme.font(12.5, .medium))
                .foregroundStyle(Theme.cream)
                .tint(Theme.accent)
                .focused($urlFocused)
                .onSubmit(playInput)

            if !urlInput.isEmpty {
                Button {
                    urlInput = ""
                    urlFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.mutedDim)
                }
                .buttonStyle(.plain)
            }

            Button {
                if let text = NSPasteboard.general.string(forType: .string) {
                    urlInput = text
                    urlFocused = true
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(Theme.font(10.5, .medium))
                    .foregroundStyle(Theme.mutedDim)
                    .frame(width: 25, height: 25)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Paste from clipboard")

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1, height: 18)

            Button(action: playInput) {
                HStack(spacing: Theme.s(5)) {
                    Text("Play")
                        .font(Theme.font(10.5, .semibold))
                    Image(systemName: "arrow.right")
                        .font(Theme.font(9, .bold))
                }
                .foregroundStyle(canPlayInput ? Theme.onAccent : Theme.mutedDim)
                .padding(.horizontal, Theme.s(11))
                .frame(height: 27)
                .background {
                    Capsule().fill(canPlayInput ? Theme.accent : Theme.cream.opacity(0.045))
                }
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canPlayInput)

            Button {
                player.importFromBrave()
            } label: {
                HStack(spacing: Theme.s(5)) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(Theme.font(9, .semibold))
                    Text("From Brave")
                        .font(Theme.font(9.5, .medium))
                }
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.s(9))
                .frame(height: 27)
                .background { Capsule().fill(Theme.cream.opacity(0.045)) }
                .overlay { Capsule().strokeBorder(Theme.cream.opacity(0.06), lineWidth: 1) }
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(player.isImportingFromBrave)
        }
        .padding(.horizontal, Theme.s(14))
        .frame(height: 43)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(13), style: .continuous)
                .fill(Theme.cream.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(13), style: .continuous)
                .strokeBorder(
                    urlFocused ? Theme.accent.opacity(0.38) : Theme.cream.opacity(0.065),
                    lineWidth: 1
                )
        }
        .onTapGesture { urlFocused = true }
    }

    private var videoCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radius(24), style: .continuous)
                .fill(Color.black)

            YouTubePlayerWebView(player: player)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius(24), style: .continuous))

            if player.isImportingFromBrave {
                VStack(spacing: Theme.s(11)) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(Theme.cream)
                    Text("Reading the video from Brave…")
                        .font(Theme.font(11, .medium))
                        .foregroundStyle(Theme.cream.opacity(0.75))
                }
                .padding(Theme.s(22))
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius(14), style: .continuous)
                        .fill(Color.black.opacity(0.6))
                }
            } else if !player.hasVideo {
                emptyPlayerState
            }

            if player.isLoading {
                VStack(spacing: Theme.s(12)) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(Theme.cream)
                    Text("Loading YouTube…")
                        .font(Theme.font(11, .medium))
                        .foregroundStyle(Theme.cream.opacity(0.72))
                }
                .padding(Theme.s(20))
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius(14), style: .continuous)
                        .fill(Color.black.opacity(0.5))
                }
            }

            if let error = player.errorMessage, !player.isLoading {
                VStack(spacing: Theme.s(10)) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(Theme.font(20, .medium))
                        .foregroundStyle(Theme.amber)
                    Text("Video unavailable")
                        .font(Theme.font(15, .semibold, design: .rounded))
                        .foregroundStyle(Theme.cream)
                    Text(error)
                        .font(Theme.font(10.5, .medium))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(maxWidth: 360)
                    Button("Retry") { player.reload() }
                        .buttonStyle(.plain)
                        .font(Theme.font(10.5, .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, Theme.s(14))
                        .frame(height: 30)
                        .background { Capsule().fill(Theme.accent) }
                        .padding(.top, Theme.s(2))
                }
                .padding(Theme.s(22))
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius(18), style: .continuous)
                        .fill(Theme.surfaceHigh.opacity(0.94))
                }
            }

            if player.hasVideo && !player.isPlaying && player.isReady && !player.isLoading && player.errorMessage == nil {
                Button {
                    player.play()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 58, height: 58)
                            .shadow(color: Theme.accent.opacity(0.4), radius: 22, x: 0, y: 8)
                        Image(systemName: "play.fill")
                            .font(Theme.font(20, .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .offset(x: 2)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            VStack {
                HStack {
                    HStack(spacing: Theme.s(4)) {
                        Image(systemName: "play.rectangle.fill")
                            .font(Theme.font(8, .semibold))
                        Text("IN APP")
                            .font(Theme.font(8, .semibold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(Theme.cream.opacity(0.82))
                    .padding(.horizontal, Theme.s(7))
                    .padding(.vertical, Theme.s(4))
                    .background { Capsule().fill(Color.black.opacity(0.38)) }

                    Spacer()

                    if player.isLive {
                        HStack(spacing: Theme.s(4)) {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 4, height: 4)
                            Text("LIVE")
                                .font(Theme.font(8, .semibold))
                                .tracking(0.8)
                        }
                        .foregroundStyle(Theme.cream.opacity(0.8))
                        .padding(.horizontal, Theme.s(7))
                        .padding(.vertical, Theme.s(4))
                        .background { Capsule().fill(Color.black.opacity(0.38)) }
                    } else if player.duration > 0 {
                        Text(player.duration.clockString)
                            .font(Theme.font(9, .medium, design: .monospaced))
                            .foregroundStyle(Theme.cream.opacity(0.6))
                            .padding(.horizontal, Theme.s(7))
                            .padding(.vertical, Theme.s(4))
                            .background { Capsule().fill(Color.black.opacity(0.38)) }
                    }
                }
                Spacer()
            }
            .padding(Theme.s(13))
            .allowsHitTesting(false)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(24), style: .continuous)
                .strokeBorder(Theme.cream.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 26, x: 0, y: 15)
        .animation(.easeInOut(duration: 0.2), value: player.isPlaying)
        .animation(.easeInOut(duration: 0.2), value: player.isLoading)
    }

    private var nowPlaying: some View {
        VStack(alignment: .leading, spacing: Theme.s(10)) {
            HStack(alignment: .top, spacing: Theme.s(12)) {
                VStack(alignment: .leading, spacing: Theme.s(3)) {
                    HStack(spacing: Theme.s(6)) {
                        PlayerEqualizer(active: player.isPlaying, color: Theme.accent)
                        Text("NOW PLAYING")
                            .font(Theme.font(9, .semibold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.mutedDim)
                    }
                    Text(player.title)
                        .font(Theme.font(19, .semibold, design: .rounded))
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)
                    Text(player.author.isEmpty ? "YouTube" : player.author)
                        .font(Theme.font(10.5, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                Spacer()

                if let watchURL = player.watchURL {
                    Button {
                        NSWorkspace.shared.open(watchURL)
                    } label: {
                        HStack(spacing: Theme.s(5)) {
                            Text("Open on YouTube")
                                .font(Theme.font(9.5, .semibold))
                            Image(systemName: "arrow.up.right.square")
                                .font(Theme.font(8.5, .semibold))
                        }
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.s(9))
                        .frame(height: 25)
                        .background { Capsule().fill(Theme.cream.opacity(0.045)) }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.s(3))
                }
            }

            if player.isLive {
                HStack(spacing: Theme.s(6)) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 5, height: 5)
                        .shadow(color: Theme.accent.opacity(0.8), radius: 4)
                    Text("LIVE FROM YOUTUBE")
                        .font(Theme.font(8.5, .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("Live stream")
                        .font(Theme.font(9, .medium))
                        .foregroundStyle(Theme.mutedDim)
                }
                .frame(height: 18)
            } else {
                VideoScrubber(
                    currentTime: player.currentTime,
                    duration: player.duration,
                    accent: Theme.accent
                ) { time in
                    player.seek(to: time)
                }
            }

            HStack(spacing: Theme.s(14)) {
                Button {
                    player.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 48, height: 48)
                            .shadow(color: Theme.accent.opacity(0.32), radius: 13, x: 0, y: 5)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(Theme.font(16, .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .offset(x: player.isPlaying ? 0 : 1.5)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!player.isReady)
                .opacity(player.isReady ? 1 : 0.6)
                .help(player.isPlaying ? "Pause" : "Play")

                Button {
                    player.toggleMute()
                } label: {
                    Image(systemName: player.isMuted || volumeDraft < 1 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(Theme.font(12, .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 30, height: 30)
                        .background { Circle().fill(Theme.cream.opacity(0.045)) }
                }
                .buttonStyle(.plain)
                .help(player.isMuted ? "Unmute" : "Mute")

                Slider(value: $volumeDraft, in: 0...100, onEditingChanged: { editing in
                    editingVolume = editing
                    if !editing {
                        player.setVolume(volumeDraft)
                    }
                })
                .tint(Theme.accent)
                .controlSize(.mini)
                .frame(width: 110)

                Text("\(Int(volumeDraft.rounded()))")
                    .font(Theme.font(9.5, .medium, design: .monospaced))
                    .foregroundStyle(Theme.mutedDim)
                    .frame(width: 22, alignment: .leading)

                Spacer()

                Button {
                    player.reload()
                } label: {
                    HStack(spacing: Theme.s(5)) {
                        Image(systemName: "arrow.clockwise")
                            .font(Theme.font(9.5, .semibold))
                        Text("Reload stream")
                            .font(Theme.font(9.5, .medium))
                    }
                    .foregroundStyle(Theme.mutedDim)
                    .padding(.horizontal, Theme.s(9))
                    .frame(height: 25)
                    .background { Capsule().fill(Theme.cream.opacity(0.035)) }
                }
                .buttonStyle(.plain)

                Text("Playback continues while you focus")
                    .font(Theme.font(9, .medium))
                    .foregroundStyle(Theme.mutedDim.opacity(0.8))
            }
        }
    }

    @ViewBuilder
    private var emptyPlayerState: some View {
        VStack(spacing: Theme.s(9)) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.1))
                    .frame(width: 54, height: 54)
                Image(systemName: "play.rectangle.fill")
                    .font(Theme.font(20, .medium))
                    .foregroundStyle(Theme.accent.opacity(0.9))
            }

            Text("Bring the video from Brave")
                .font(Theme.font(17, .semibold, design: .rounded))
                .foregroundStyle(Theme.cream)
            Text(player.braveImportMessage ?? "Cadence will pick up the YouTube video already playing in Brave and continue it here.")
                .font(Theme.font(10, .medium))
                .foregroundStyle(player.braveImportMessage == nil ? Theme.muted : Theme.amber.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 370)

            HStack(spacing: Theme.s(8)) {
                AccentButton(title: "From Brave", icon: "shield.lefthalf.filled") {
                    player.importFromBrave()
                }
                QuietButton(title: "Paste a link") {
                    urlFocused = true
                }
                if let message = player.braveImportMessage,
                   message.localizedCaseInsensitiveContains("automation") {
                    QuietButton(title: "Open Settings") {
                        openAutomationSettings()
                    }
                }
            }
            .padding(.top, Theme.s(3))

            Text("You can also paste a YouTube link above.")
                .font(Theme.font(8.5, .medium))
                .foregroundStyle(Theme.mutedDim)
        }
        .padding(Theme.s(24))
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(18), style: .continuous)
                .fill(Theme.surface.opacity(0.9))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(18), style: .continuous)
                .strokeBorder(Theme.cream.opacity(0.07), lineWidth: 1)
        }
    }

    private var canPlayInput: Bool {
        !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else { return }
        NSWorkspace.shared.open(url)
    }

    private func playInput() {
        guard canPlayInput else { return }
        if player.loadInput(urlInput) {
            urlFocused = false
            urlInput = ""
        }
    }

    private var playerStatus: String {
        if player.isImportingFromBrave { return "Reading Brave" }
        if player.isLoading { return "Loading video" }
        if player.errorMessage != nil { return "Needs attention" }
        if player.isPlaying { return "Playing in app" }
        if player.isReady { return "Paused" }
        return "No video yet"
    }

    private var playerStatusColor: Color {
        if player.isImportingFromBrave { return Theme.sky }
        if player.isLoading { return Theme.sky }
        if player.errorMessage != nil { return Theme.amber }
        if player.isPlaying { return Theme.mint }
        return Theme.amber
    }
}

struct VideoScrubber: View {
    let currentTime: Double
    let duration: Double
    let accent: Color
    let onSeek: (Double) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        let fraction = dragFraction ?? (duration > 0 ? min(1, max(0, currentTime / duration)) : 0)
        let displayed = dragFraction.map { $0 * duration } ?? currentTime

        VStack(spacing: Theme.s(5)) {
            GeometryReader { geometry in
                let width = max(1, geometry.size.width)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.cream.opacity(0.075))
                        .frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [accent.opacity(0.6), accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, width * fraction), height: 4)
                        .shadow(color: accent.opacity(0.3), radius: 4)
                    Circle()
                        .fill(Theme.cream)
                        .frame(width: 11, height: 11)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        .offset(x: max(0, min(width - 11, width * fraction - 5.5)))
                        .opacity(duration > 0 ? 1 : 0)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard duration > 0 else { return }
                            dragFraction = min(1, max(0, value.location.x / width))
                        }
                        .onEnded { value in
                            guard duration > 0 else {
                                dragFraction = nil
                                return
                            }
                            let final = min(1, max(0, value.location.x / width))
                            dragFraction = nil
                            onSeek(final * duration)
                        }
                )
            }
            .frame(height: 13)

            HStack {
                Text(displayed.clockString)
                Spacer()
                Text(duration.clockString)
            }
            .font(Theme.font(9, .medium, design: .monospaced))
            .foregroundStyle(Theme.mutedDim)
        }
    }
}

struct PlayerEqualizer: View {
    let active: Bool
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: Theme.s(2)) {
                ForEach(0..<4, id: \.self) { index in
                    let wave = abs(sin(time * 2.1 + Double(index) * 0.9))
                    let level = active ? 0.24 + 0.76 * wave : 0.24
                    Capsule()
                        .fill(color.opacity(active ? 0.9 : 0.35))
                        .frame(width: 2.2, height: max(2, 10 * level))
                }
            }
            .frame(height: 10, alignment: .bottom)
        }
    }
}
