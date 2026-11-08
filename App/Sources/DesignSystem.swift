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
}

enum Theme {
    static var mode: AppThemeMode = .dynamic
    static var appearance: AppAppearance = .system

    static var style: ThemeStyle {
        mode == .cozy ? .cozy : .dynamic
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
        } else if mode == .cozy {
            resolved = .serif
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
        switch (mode, isLight) {
        case (.dynamic, false): return .dynamic
        case (.cozy, false): return .cozy
        case (.dynamic, true): return .dynamicLight
        case (.cozy, true): return .cozyLight
        }
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
            if model.backgroundStyle == .image, let image = model.backgroundImage {
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
        let fps: Double = compact ? 12 : (scene.isAmbient ? 30 : 20)
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
                case .aurora:
                    AuroraScene(time: time, compact: compact)
                case .embers:
                    EmbersScene(time: time, compact: compact)
                case .tide:
                    TideScene(time: time, compact: compact)
                case .orbit:
                    OrbitScene(time: time, compact: compact)
                case .bokeh:
                    BokehScene(time: time, compact: compact)
                case .silk:
                    SilkScene(time: time, compact: compact)
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

private struct AuroraScene: View {
    let time: Double
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let span = max(size.width, size.height)
            let t = CGFloat(time)
            let driftX = sin(t * 0.055) * span * 0.14
            let driftY = cos(t * 0.042) * span * 0.1

            glow(
                in: &context,
                center: CGPoint(x: size.width * 0.82 + driftX, y: size.height * 0.12 + driftY),
                radius: span * (compact ? 0.42 : 0.62),
                color: Theme.accent,
                opacity: (Theme.isLight ? 0.52 : 0.32) * (compact ? 1.12 : 1)
            )
            glow(
                in: &context,
                center: CGPoint(
                    x: size.width * 0.16 + cos(t * 0.036 + 1.7) * span * 0.16,
                    y: size.height * 0.86 + sin(t * 0.048 + 0.6) * span * 0.1
                ),
                radius: span * (compact ? 0.36 : 0.54),
                color: Theme.mint,
                opacity: (Theme.isLight ? 0.34 : 0.2) * (compact ? 1.12 : 1)
            )
            glow(
                in: &context,
                center: CGPoint(
                    x: size.width * 0.78 + cos(t * 0.03) * span * 0.12,
                    y: size.height * 0.82 + cos(t * 0.04) * span * 0.12
                ),
                radius: span * (compact ? 0.3 : 0.44),
                color: Theme.sky,
                opacity: (Theme.isLight ? 0.28 : 0.16) * (compact ? 1.12 : 1)
            )
        }
    }
}

private struct EmbersScene: View {
    let time: Double
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let count = compact ? 14 : 38
            let t = CGFloat(time)

            glow(
                in: &context,
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.95),
                radius: max(size.width, size.height) * 0.7,
                color: Theme.amber,
                opacity: 0.14
            )

            for index in 0..<count {
                let speed = 0.018 + Double(seeded(index, 3)) * 0.026
                let progress = (time * speed + Double(seeded(index, 4))).truncatingRemainder(dividingBy: 1)
                let sway = sin(t * (0.3 + seeded(index, 5) * 0.4) + seeded(index, 6) * 8)
                let x = size.width * (0.08 + seeded(index, 1) * 0.84) + sway * size.width * 0.035
                let y = size.height * (1.08 - progress * 1.16)
                let flicker = 0.4 + 0.45 * ((sin(t * (0.8 + seeded(index, 7)) + seeded(index, 8) * 7) + 1) / 2)
                let radius = (compact ? 0.9 : 1.4) + seeded(index, 2) * (compact ? 2.2 : 3.6)
                let color = index.isMultiple(of: 3) ? Theme.amber : Theme.accent
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)

                context.fill(
                    Path(ellipseIn: rect.insetBy(dx: -radius * 2.4, dy: -radius * 2.4)),
                    with: .color(color.opacity(0.1 * flicker))
                )
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.75 * flicker)))
            }
        }
    }
}

private struct TideScene: View {
    let time: Double
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let layers: [(Color, CGFloat)] = [
                (Theme.sky, 0.54),
                (Theme.accent, 0.66),
                (Theme.mint, 0.78),
                (Theme.accentLight, 0.9)
            ]
            let count = compact ? 3 : 4

            for index in 0..<count {
                let (color, basePosition) = layers[index]
                let baseY = size.height * basePosition
                let amplitude = size.height * (0.035 + CGFloat(index) * 0.012)
                let speed = 0.18 + Double(index) * 0.05
                let phase = Double(index) * 1.7
                let steps = compact ? 22 : 44

                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: baseY))

                for step in 0...steps {
                    let fraction = CGFloat(step) / CGFloat(steps)
                    let x = size.width * fraction
                    let wave = sin(Double(fraction) * 5.4 + time * speed + phase)
                    let chop = cos(Double(fraction) * 9.1 - time * speed * 0.7 + phase) * 0.32
                    let y = baseY + CGFloat(wave + chop) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(Theme.isLight ? 0.42 : 0.3), color.opacity(0.02)]),
                        startPoint: CGPoint(x: size.width * 0.5, y: baseY - amplitude * 2),
                        endPoint: CGPoint(x: size.width * 0.5, y: size.height)
                    )
                )
            }
        }
    }
}

private struct OrbitScene: View {
    let time: Double
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
            let span = max(size.width, size.height)
            let t = CGFloat(time)
            let colors = [Theme.accent, Theme.mint, Theme.sky, Theme.amber]

            glow(
                in: &context,
                center: center,
                radius: span * 0.48,
                color: Theme.accent,
                opacity: (Theme.isLight ? 0.28 : 0.16) * (compact ? 1.12 : 1)
            )

            for index in 0..<5 {
                let radius = span * (0.12 + CGFloat(index) * 0.085)
                let color = colors[index % colors.count]
                let rotation = t * (0.12 + CGFloat(index) * 0.03) + CGFloat(index) * 0.8
                let arc = 0.42 + CGFloat(index) * 0.06

                var path = Path()
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .radians(Double(rotation)),
                    endAngle: .radians(Double(rotation + arc * .pi * 2)),
                    clockwise: false
                )

                context.stroke(
                    path,
                    with: .color(color.opacity(compact ? 0.32 : 0.42)),
                    style: StrokeStyle(lineWidth: compact ? 1 : 1.6, lineCap: .round)
                )

                let dotAngle = Double(rotation + arc * .pi * 2)
                let dot = CGRect(
                    x: center.x + CGFloat(cos(dotAngle)) * radius - 2,
                    y: center.y + CGFloat(sin(dotAngle)) * radius - 2,
                    width: 4,
                    height: 4
                )
                context.fill(Path(ellipseIn: dot), with: .color(color.opacity(0.9)))
            }
        }
    }
}

private struct BokehScene: View {
    let time: Double
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let count = compact ? 9 : 18
            let span = max(size.width, size.height)
            let t = CGFloat(time)

            for index in 0..<count {
                let colors = [Theme.accent, Theme.mint, Theme.sky, Theme.amber]
                let color = colors[index % colors.count]
                let drift = 0.02 + Double(seeded(index, 2)) * 0.035
                let x = size.width * (seeded(index, 1) + CGFloat(sin(time * drift + Double(seeded(index, 3)) * 6)) * 0.08)
                let y = size.height * (seeded(index, 4) + CGFloat(cos(time * drift * 0.8 + Double(seeded(index, 5)) * 6)) * 0.08)
                let radius = span * (0.035 + seeded(index, 6) * (compact ? 0.06 : 0.1))
                let pulse = 0.75 + 0.25 * CGFloat((sin(time * 0.4 + Double(seeded(index, 7)) * 6) + 1) / 2)
                let opacity = (compact ? 0.14 : 0.18) * pulse

                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), .clear]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: radius
                    )
                )

                let core = radius * 0.12
                context.fill(
                    Path(ellipseIn: CGRect(x: x - core, y: y - core, width: core * 2, height: core * 2)),
                    with: .color(color.opacity(opacity * 2.2))
                )
            }
        }
    }
}

private struct SilkScene: View {
    let time: Double
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let count = compact ? 5 : 7
            let colors = [Theme.accent, Theme.mint, Theme.sky, Theme.amber]
            let steps = compact ? 18 : 32

            for band in 0..<count {
                let color = colors[band % colors.count]
                let centerX = size.width * (CGFloat(band) + 0.5) / CGFloat(count)
                let bandWidth = size.width / CGFloat(count) * (0.7 + seeded(band, 2) * 0.9)
                let amplitude = size.width * (0.025 + seeded(band, 3) * 0.04)
                let speed = 0.12 + Double(seeded(band, 4)) * 0.12
                let phase = Double(seeded(band, 5)) * 6

                var path = Path()
                for step in 0...steps {
                    let fraction = CGFloat(step) / CGFloat(steps)
                    let y = -size.height * 0.1 + fraction * size.height * 1.2
                    let offset = CGFloat(sin(Double(fraction) * 3.4 + time * speed + phase)) * amplitude
                    let x = centerX + offset - bandWidth * 0.5
                    if step == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                for step in stride(from: steps, through: 0, by: -1) {
                    let fraction = CGFloat(step) / CGFloat(steps)
                    let y = -size.height * 0.1 + fraction * size.height * 1.2
                    let offset = CGFloat(sin(Double(fraction) * 3.4 + time * speed + phase)) * amplitude
                    let x = centerX + offset + bandWidth * 0.5
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.closeSubpath()
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(Theme.isLight ? 0.2 : 0.14), color.opacity(Theme.isLight ? 0.08 : 0.05), color.opacity(0.01)]),
                        startPoint: CGPoint(x: centerX, y: 0),
                        endPoint: CGPoint(x: centerX, y: size.height)
                    )
                )
            }
        }
    }
}

private func glow(
    in context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    color: Color,
    opacity: Double
) {
    guard radius > 0 else { return }
    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    context.fill(
        Path(ellipseIn: rect),
        with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.28), .clear]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    )
}

private func seeded(_ index: Int, _ salt: Double) -> CGFloat {
    let value = sin(Double(index) * 127.1 + salt * 311.7) * 43758.5453
    return CGFloat(value - floor(value))
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
                    .fill(filled ? accent : Theme.controlFill)
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
            .foregroundStyle(Theme.mutedDim)
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
