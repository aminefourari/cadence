import AppKit
import SwiftUI

struct ThemePalette {
    let ink: Color
    let inkDeep: Color
    let surface: Color
    let surfaceHigh: Color
    let backgroundEnd: Color
    let cream: Color
    let muted: Color
    let mutedDim: Color
    let accent: Color
    let accentLight: Color
    let amber: Color
    let mint: Color
    let sky: Color
    let danger: Color
    let hairline: Color
    let panelFill: Color
    let onAccent: Color
    let controlFill: Color
    let controlFillHover: Color
    let controlStroke: Color
    let strongFill: Color
    let shadow: Color
    let imageVeil: Color

    static let dynamic = ThemePalette(
        ink: Color(hex: 0x12100D),
        inkDeep: Color(hex: 0x0C0B09),
        surface: Color(hex: 0x1B1712),
        surfaceHigh: Color(hex: 0x26201A),
        backgroundEnd: Color(hex: 0x17130F),
        cream: Color(hex: 0xF6EEE1),
        muted: Color(hex: 0xA99D8D),
        mutedDim: Color(hex: 0x70665A),
        accent: Color(hex: 0xF36F4D),
        accentLight: Color(hex: 0xFFA57F),
        amber: Color(hex: 0xE7BE6B),
        mint: Color(hex: 0x9DC9A9),
        sky: Color(hex: 0x91B9D0),
        danger: Color(hex: 0xE57B65),
        hairline: Color.white.opacity(0.075),
        panelFill: Color(hex: 0x1D1813).opacity(0.86),
        onAccent: Color(hex: 0x12100D),
        controlFill: Color.white.opacity(0.05),
        controlFillHover: Color.white.opacity(0.09),
        controlStroke: Color.white.opacity(0.075),
        strongFill: Color.white.opacity(0.085),
        shadow: Color.black.opacity(0.3),
        imageVeil: Color(hex: 0x0C0B09).opacity(0.72)
    )

    static let cozy = ThemePalette(
        ink: Color(hex: 0x24170F),
        inkDeep: Color(hex: 0x170E09),
        surface: Color(hex: 0x2C1D13),
        surfaceHigh: Color(hex: 0x3A281A),
        backgroundEnd: Color(hex: 0x2B1A10),
        cream: Color(hex: 0xF8E9CF),
        muted: Color(hex: 0xC3A688),
        mutedDim: Color(hex: 0x8B7058),
        accent: Color(hex: 0xE7A55C),
        accentLight: Color(hex: 0xFFD29A),
        amber: Color(hex: 0xF0C878),
        mint: Color(hex: 0xA9C7A3),
        sky: Color(hex: 0xB8C7DA),
        danger: Color(hex: 0xD9856B),
        hairline: Color.white.opacity(0.085),
        panelFill: Color(hex: 0x2B1D13).opacity(0.9),
        onAccent: Color(hex: 0x17100A),
        controlFill: Color.white.opacity(0.055),
        controlFillHover: Color.white.opacity(0.1),
        controlStroke: Color.white.opacity(0.08),
        strongFill: Color.white.opacity(0.09),
        shadow: Color.black.opacity(0.32),
        imageVeil: Color(hex: 0x170E09).opacity(0.76)
    )

    static let dynamicLight = ThemePalette(
        ink: Color(hex: 0xF4EBDD),
        inkDeep: Color(hex: 0xECE0CF),
        surface: Color(hex: 0xF8F1E6),
        surfaceHigh: Color(hex: 0xFFFBF4),
        backgroundEnd: Color(hex: 0xEADCC9),
        cream: Color(hex: 0x241C15),
        muted: Color(hex: 0x6E6154),
        mutedDim: Color(hex: 0x998A79),
        accent: Color(hex: 0xD95A3E),
        accentLight: Color(hex: 0xB8442D),
        amber: Color(hex: 0x94651C),
        mint: Color(hex: 0x4E7D5F),
        sky: Color(hex: 0x4D7287),
        danger: Color(hex: 0xB84F3D),
        hairline: Color.black.opacity(0.075),
        panelFill: Color(hex: 0xFFFAF2).opacity(0.9),
        onAccent: Color(hex: 0x1B120D),
        controlFill: Color.black.opacity(0.035),
        controlFillHover: Color.black.opacity(0.065),
        controlStroke: Color.black.opacity(0.08),
        strongFill: Color.black.opacity(0.07),
        shadow: Color.black.opacity(0.12),
        imageVeil: Color(hex: 0xF4EBDD).opacity(0.66)
    )

    static let blossom = ThemePalette(
        ink: Color(hex: 0x1E1219),
        inkDeep: Color(hex: 0x150C12),
        surface: Color(hex: 0x281821),
        surfaceHigh: Color(hex: 0x35202C),
        backgroundEnd: Color(hex: 0x25131D),
        cream: Color(hex: 0xFBE9F0),
        muted: Color(hex: 0xC9A3B5),
        mutedDim: Color(hex: 0x8F6A7D),
        accent: Color(hex: 0xF27BA8),
        accentLight: Color(hex: 0xFFB3CF),
        amber: Color(hex: 0xF2C38B),
        mint: Color(hex: 0xA8D5C2),
        sky: Color(hex: 0xBBA9EA),
        danger: Color(hex: 0xE77A8A),
        hairline: Color.white.opacity(0.08),
        panelFill: Color(hex: 0x2A1822).opacity(0.88),
        onAccent: Color(hex: 0x1E1018),
        controlFill: Color.white.opacity(0.055),
        controlFillHover: Color.white.opacity(0.1),
        controlStroke: Color.white.opacity(0.08),
        strongFill: Color.white.opacity(0.09),
        shadow: Color.black.opacity(0.3),
        imageVeil: Color(hex: 0x150C12).opacity(0.72)
    )

    static let blossomLight = ThemePalette(
        ink: Color(hex: 0xFBEAF0),
        inkDeep: Color(hex: 0xF5DDE7),
        surface: Color(hex: 0xFDF2F6),
        surfaceHigh: Color(hex: 0xFFF9FB),
        backgroundEnd: Color(hex: 0xF2D4E1),
        cream: Color(hex: 0x3A1B2B),
        muted: Color(hex: 0x84576D),
        mutedDim: Color(hex: 0xAD8498),
        accent: Color(hex: 0xDB4F86),
        accentLight: Color(hex: 0xB8336A),
        amber: Color(hex: 0x9A6A2A),
        mint: Color(hex: 0x3F7D66),
        sky: Color(hex: 0x6D5BB5),
        danger: Color(hex: 0xC0475C),
        hairline: Color.black.opacity(0.07),
        panelFill: Color(hex: 0xFFF7FA).opacity(0.9),
        onAccent: Color(hex: 0xFFFFFF),
        controlFill: Color.black.opacity(0.035),
        controlFillHover: Color.black.opacity(0.065),
        controlStroke: Color.black.opacity(0.08),
        strongFill: Color.black.opacity(0.07),
        shadow: Color(hex: 0x6B2347).opacity(0.12),
        imageVeil: Color(hex: 0xFBEAF0).opacity(0.66)
    )

    static func resolve(_ mode: AppThemeMode, light: Bool) -> ThemePalette {
        switch (mode, light) {
        case (.dynamic, false): return .dynamic
        case (.dynamic, true): return .dynamicLight
        case (.cozy, false): return .cozy
        case (.cozy, true): return .cozyLight
        case (.blossom, false): return .blossom
        case (.blossom, true): return .blossomLight
        }
    }

    static let cozyLight = ThemePalette(
        ink: Color(hex: 0xF3E7D2),
        inkDeep: Color(hex: 0xEBDCC4),
        surface: Color(hex: 0xF8EEDB),
        surfaceHigh: Color(hex: 0xFFF8EA),
        backgroundEnd: Color(hex: 0xE6D2B5),
        cream: Color(hex: 0x2A1D12),
        muted: Color(hex: 0x765F48),
        mutedDim: Color(hex: 0x9E8264),
        accent: Color(hex: 0xC77A2C),
        accentLight: Color(hex: 0x9A5A1C),
        amber: Color(hex: 0x93651E),
        mint: Color(hex: 0x5E7D50),
        sky: Color(hex: 0x617A8E),
        danger: Color(hex: 0xAF4D3C),
        hairline: Color.black.opacity(0.085),
        panelFill: Color(hex: 0xFFF7E9).opacity(0.9),
        onAccent: Color(hex: 0x1B120D),
        controlFill: Color.black.opacity(0.035),
        controlFillHover: Color.black.opacity(0.07),
        controlStroke: Color.black.opacity(0.085),
        strongFill: Color.black.opacity(0.075),
        shadow: Color.black.opacity(0.14),
        imageVeil: Color(hex: 0xF3E7D2).opacity(0.68)
    )
}

struct ThemeStyle {
    let fontDesign: Font.Design
    let typeScale: CGFloat
    let spacingScale: CGFloat
    let radiusScale: CGFloat

    static let dynamic = ThemeStyle(
        fontDesign: .default,
        typeScale: 1,
        spacingScale: 1,
        radiusScale: 1
    )

    static let cozy = ThemeStyle(
        fontDesign: .serif,
        typeScale: 1.035,
        spacingScale: 1.12,
        radiusScale: 1.18
    )

    static let blossom = ThemeStyle(
        fontDesign: .rounded,
        typeScale: 1.02,
        spacingScale: 1.06,
        radiusScale: 1.4
    )

    static func resolve(_ mode: AppThemeMode) -> ThemeStyle {
        switch mode {
        case .dynamic: return .dynamic
        case .cozy: return .cozy
        case .blossom: return .blossom
        }
    }
}

enum Theme {
    static var mode: AppThemeMode = .dynamic
    static var appearance: AppAppearance = .system

    static var style: ThemeStyle {
        .resolve(mode)
    }

    static var fontDesign: Font.Design { style.fontDesign }

    /// Theme-aware type. Monospaced faces stay monospaced in every theme.
    static func font(
        _ size: CGFloat,
        _ weight: Font.Weight = .regular,
        design: Font.Design? = nil
    ) -> Font {
        let resolved: Font.Design
        if design == .monospaced {
            resolved = .monospaced
        } else if mode != .dynamic {
            resolved = style.fontDesign
        } else {
            resolved = design ?? .default
        }
        return .system(size: size * style.typeScale, weight: weight, design: resolved)
    }

    /// Theme-aware padding and stack spacing.
    static func s(_ value: CGFloat) -> CGFloat {
        guard value != 0 else { return 0 }
        return (value * style.spacingScale * 2).rounded() / 2
    }

    /// Theme-aware corner radii: tighter in Dynamic, softer in Cozy.
    static func radius(_ value: CGFloat) -> CGFloat {
        guard value != 0 else { return 0 }
        return (value * style.radiusScale * 2).rounded() / 2
    }

    static var isLight: Bool {
        switch appearance {
        case .light: return true
        case .dark: return false
        case .system:
            return NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
        }
    }

    static var palette: ThemePalette {
        .resolve(mode, light: isLight)
    }

    static var isCozy: Bool { mode == .cozy }
    static var ink: Color { palette.ink }
    static var inkDeep: Color { palette.inkDeep }
    static var surface: Color { palette.surface }
    static var surfaceHigh: Color { palette.surfaceHigh }
    static var backgroundEnd: Color { palette.backgroundEnd }
    static var cream: Color { palette.cream }
    static var muted: Color { palette.muted }
    static var mutedDim: Color { palette.mutedDim }
    static var accent: Color { palette.accent }
    static var accentLight: Color { palette.accentLight }
    static var amber: Color { palette.amber }
    static var mint: Color { palette.mint }
    static var sky: Color { palette.sky }
    static var danger: Color { palette.danger }
    static var hairline: Color { palette.hairline }
    static var panelFill: Color { palette.panelFill }
    static var onAccent: Color { palette.onAccent }
    static var controlFill: Color { palette.controlFill }
    static var controlFillHover: Color { palette.controlFillHover }
    static var controlStroke: Color { palette.controlStroke }
    static var strongFill: Color { palette.strongFill }
    static var shadow: Color { palette.shadow }
    static var imageVeil: Color { palette.imageVeil }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension PomodoroPhase {
    var accent: Color {
        switch self {
        case .focus: return Theme.accent
        case .shortBreak: return Theme.mint
        case .longBreak: return Theme.sky
        }
    }
}

struct AppBackground: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if model.backgroundStyle == .theme, let image = NSImage(named: model.themeMode.photoName) {
                imageBackground(image)
                if model.themeMode == .blossom {
                    PetalFall()
                }
            } else if model.backgroundStyle == .image, let image = model.backgroundImage {
                imageBackground(image)
            } else if model.backgroundStyle == .video, let url = model.backgroundVideoURL {
                LoopingVideoView(url: url)
                    .overlay { Theme.imageVeil }
                    .overlay {
                        LinearGradient(
                            colors: [Theme.inkDeep.opacity(0.3), .clear, Theme.inkDeep.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                AnimatedBackgroundView(scene: model.animatedBackground)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(Theme.isLight ? 0.025 : 0.12),
                    .clear,
                    Color.black.opacity(Theme.isLight ? 0.06 : 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: model.backgroundStyle)
        .animation(.easeInOut(duration: 0.5), value: model.animatedBackground)
        .animation(.easeInOut(duration: 0.5), value: model.themeMode)
    }

    private func imageBackground(_ image: NSImage) -> some View {
        GeometryReader { geometry in
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay {
                    Theme.imageVeil
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Theme.inkDeep.opacity(Theme.isLight ? 0.36 : 0.42),
                            .clear,
                            Theme.inkDeep.opacity(Theme.isLight ? 0.62 : 0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay {
                    RadialGradient(
                        colors: [Theme.accent.opacity(Theme.isLight ? 0.12 : 0.1), .clear],
                        center: .topTrailing,
                        startRadius: 20,
                        endRadius: 700
                    )
                }
        }
    }
}

struct AnimatedBackgroundView: View {
    let scene: AnimatedBackground
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Weather scenes need a smoother frame rate for falling rain.
        let fps: Double = compact ? 12 : 30
        TimelineView(.animation(minimumInterval: 1.0 / fps, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                SceneBase()

                switch scene {
                case .rainyForest:
                    ForestScene(time: time, compact: compact, weather: .rain)
                case .rainyCafe:
                    CafeRainScene(time: time, compact: compact)
                case .cityRain:
                    CityRainScene(time: time, compact: compact)
                case .snowyForest:
                    ForestScene(time: time, compact: compact, weather: .snow)
                }
            }
        }
        .clipped()
    }
}

private struct SceneBase: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.inkDeep, Theme.ink, Theme.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Theme.surfaceHigh.opacity(Theme.isLight ? 0.42 : 0.17), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 740
            )
        }
    }
}

/// Cherry petals drifting over the Blossom theme photo.
private struct PetalFall: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for index in 0..<28 {
                    let r = { (salt: Double) in fract(sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453) }
                    let speed = 0.025 + r(1) * 0.03
                    let progress = fract(time * speed + r(2))
                    let sway = sin(time * (0.5 + r(3) * 0.6) + r(4) * 6) * size.width * 0.04
                    let x = size.width * (r(5) * 1.2 - 0.1) + progress * size.width * 0.18 + sway
                    let y = size.height * (progress * 1.15 - 0.08)
                    let scale = 5 + r(6) * 7
                    let spin = Angle.radians(time * (0.6 + r(7)) + r(8) * 6)
                    // Flutter: squash the petal's width as it turns.
                    let flutter = 0.45 + abs(sin(time * (1.2 + r(9)) + r(10) * 5)) * 0.55

                    var petal = context
                    petal.translateBy(x: x, y: y)
                    petal.rotate(by: spin)
                    petal.scaleBy(x: flutter, y: 1)
                    let rect = CGRect(x: -scale * 0.6, y: -scale, width: scale * 1.2, height: scale * 2)
                    petal.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(hex: index.isMultiple(of: 3) ? 0xFFE3EE : 0xF9B6CF).opacity(0.55 + r(11) * 0.3))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func fract(_ value: Double) -> Double { value - floor(value) }
}

struct CadenceMark: View {
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x2A241E), Color(hex: 0x15120E)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .strokeBorder(Color(hex: 0xF6EEE1).opacity(0.1), lineWidth: 1)

            Circle()
                .trim(from: 0.06, to: 0.9)
                .stroke(
                    Color(hex: 0xF6EEE1).opacity(0.9),
                    style: StrokeStyle(lineWidth: size * 0.062, lineCap: .round)
                )
                .frame(width: size * 0.54, height: size * 0.54)
                .rotationEffect(.degrees(-90))

            HStack(spacing: size * 0.045) {
                Capsule().fill(Theme.accent).frame(width: size * 0.052, height: size * 0.13)
                Capsule().fill(Theme.accent).frame(width: size * 0.052, height: size * 0.25)
                Capsule().fill(Theme.accent).frame(width: size * 0.052, height: size * 0.18)
            }
            .offset(y: size * 0.01)

            Circle()
                .fill(Theme.accent.opacity(0.35))
                .frame(width: size * 0.16)
                .offset(x: size * 0.18, y: -size * 0.17)
                .blur(radius: size * 0.06)
            Circle()
                .fill(Theme.accentLight)
                .frame(width: size * 0.075)
                .offset(x: size * 0.18, y: -size * 0.17)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: size * 0.2, x: 0, y: size * 0.14)
    }
}

struct PanelBackground: ViewModifier {
    var cornerRadius: CGFloat = 26
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.055),
                                tint.opacity(0.018)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Theme.surface.opacity(0.88))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.cream.opacity(0.11), Theme.cream.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Theme.shadow, radius: 28, x: 0, y: 16)
    }
}

extension View {
    func panel(cornerRadius: CGFloat = 26, tint: Color = Theme.cream) -> some View {
        modifier(PanelBackground(cornerRadius: cornerRadius, tint: tint))
    }
}

struct PressableStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CircleControlStyle: ButtonStyle {
    var size: CGFloat
    var accent: Color = Theme.cream
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(size * 0.34, .semibold))
            .foregroundStyle(filled ? Theme.onAccent : accent.opacity(0.9))
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(filled ? accent : Theme.strongFill)
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        filled ? accent.opacity(0.5) : Theme.controlStroke,
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct UtilityIconButton: View {
    let icon: String
    var help: String = ""
    var tint: Color = Theme.cream
    var action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.font(13, .semibold))
                .foregroundStyle(tint.opacity(hovered ? 1 : 0.68))
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(hovered ? Theme.controlFillHover : Theme.controlFill)
                }
                .overlay {
                    Circle().strokeBorder(hovered ? Theme.cream.opacity(0.14) : Theme.controlStroke, lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(help)
    }
}

struct AccentButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s(6)) {
                if let icon {
                    Image(systemName: icon)
                        .font(Theme.font(10, .semibold))
                }
                Text(title)
                    .font(Theme.font(11, .semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, Theme.s(14))
            .frame(height: 34)
            .background { Capsule().fill(Theme.accent) }
            .shadow(color: Theme.accent.opacity(0.22), radius: 11, x: 0, y: 5)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

struct QuietButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s(6)) {
                if let icon {
                    Image(systemName: icon)
                        .font(Theme.font(10, .medium))
                }
                Text(title)
                    .font(Theme.font(11, .medium))
            }
            .foregroundStyle(Theme.cream.opacity(0.72))
            .padding(.horizontal, Theme.s(13))
            .frame(height: 34)
            .background { Capsule().fill(Theme.controlFill) }
            .overlay { Capsule().strokeBorder(Theme.controlStroke, lineWidth: 1) }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

struct SectionLabel: View {
    let text: String
    var tint: Color = Theme.mutedDim

    var body: some View {
        Text(text.uppercased())
            .font(Theme.font(10, .semibold, design: .default))
            .tracking(1.5)
            .foregroundStyle(tint)
    }
}

struct StatusPill: View {
    let text: String
    var color: Color = Theme.mint
    var pulsing: Bool = false

    @State private var pulse = false

    var body: some View {
        HStack(spacing: Theme.s(6)) {
            ZStack {
                if pulsing {
                    Circle().fill(color.opacity(0.25))
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulse ? 1.5 : 0.8)
                        .opacity(pulse ? 0 : 0.8)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
                }
                Circle()
                    .fill(color)
                    .frame(width: 5.5, height: 5.5)
                    .shadow(color: color.opacity(0.8), radius: 4)
            }
            .frame(width: 8, height: 8)

            Text(text)
                .font(Theme.font(11, .medium))
                .foregroundStyle(Theme.cream.opacity(0.72))
        }
        .padding(.horizontal, Theme.s(10))
        .padding(.vertical, Theme.s(7))
        .background {
            Capsule().fill(Theme.controlFill)
        }
        .overlay {
            Capsule().strokeBorder(Theme.controlStroke, lineWidth: 1)
        }
        .onAppear { pulse = true }
    }
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: Theme.s(12)) {
            ZStack {
                Circle().fill(toast.tint.opacity(0.14)).frame(width: 36, height: 36)
                Image(systemName: toast.icon)
                    .font(Theme.font(14, .semibold))
                    .foregroundStyle(toast.tint)
            }

            VStack(alignment: .leading, spacing: Theme.s(2)) {
                Text(toast.title)
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(Theme.cream)
                Text(toast.message)
                    .font(Theme.font(11.5))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, Theme.s(14))
        .padding(.vertical, Theme.s(11))
        .frame(width: 380, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius(16), style: .continuous)
                .fill(Theme.surfaceHigh.opacity(0.97))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius(16), style: .continuous)
                .strokeBorder(toast.tint.opacity(0.24), lineWidth: 1)
        }
        .shadow(color: Theme.shadow, radius: 24, x: 0, y: 12)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

private final class WindowAttachmentView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.tabbingMode = .disallowed
        window.backgroundColor = NSColor(
            calibratedRed: 0.07,
            green: 0.062,
            blue: 0.052,
            alpha: 1
        )
        window.minSize = NSSize(width: 940, height: 700)
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowAttachmentView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ShortcutHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.font(10, .medium, design: .monospaced))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, Theme.s(6))
            .padding(.vertical, Theme.s(3))
            .background {
                RoundedRectangle(cornerRadius: Theme.radius(5), style: .continuous)
                    .fill(Theme.controlFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius(5), style: .continuous)
                    .strokeBorder(Theme.controlStroke, lineWidth: 1)
            }
    }
}
