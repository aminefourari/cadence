import AVFoundation
import SwiftUI

// Atmospheric, procedurally drawn backgrounds (rain, fog, snow, city lights).
// Everything is drawn in one Canvas per frame; `time` comes from the TimelineView
// in AnimatedBackgroundView, `compact` is the small preview in Preferences.

// MARK: - Shared drawing helpers

/// Deterministic pseudo-random value in 0..<1 for a particle index.
private func rnd(_ index: Int, _ salt: Double) -> CGFloat {
    let value = sin(Double(index) * 127.1 + salt * 311.7) * 43758.5453
    return CGFloat(value - floor(value))
}

private func fract(_ value: Double) -> Double { value - floor(value) }

private struct RainLayer {
    var count: Int
    /// Fall speed in points per second.
    var speed: CGFloat
    var length: CGFloat
    var width: CGFloat
    var opacity: Double
    /// Horizontal drift per point of fall (wind).
    var slant: CGFloat = 0.12
}

private func drawRain(
    _ context: inout GraphicsContext,
    size: CGSize,
    time: Double,
    layer: RainLayer,
    color: Color,
    seed: Double
) {
    let travel = size.height + layer.length
    let spread = size.width + abs(layer.slant) * size.height
    var path = Path()
    for index in 0..<layer.count {
        let speed = layer.speed * (0.82 + 0.36 * rnd(index, seed + 2))
        let progress = fract(time * Double(speed / travel) + Double(rnd(index, seed + 3)))
        let y = CGFloat(progress) * travel - layer.length
        let x = rnd(index, seed + 1) * spread - abs(layer.slant) * size.height + y * layer.slant
        let length = layer.length * (0.7 + 0.6 * rnd(index, seed + 4))
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + layer.slant * length, y: y + length))
    }
    context.stroke(
        path,
        with: .color(color.opacity(layer.opacity)),
        style: StrokeStyle(lineWidth: layer.width, lineCap: .round)
    )
}

/// Little rings where drops hit the ground between `top` and `bottom`.
private func drawSplashes(
    _ context: inout GraphicsContext,
    size: CGSize,
    time: Double,
    count: Int,
    top: CGFloat,
    bottom: CGFloat,
    color: Color,
    opacity: Double
) {
    for index in 0..<count {
        let period = 0.55 + Double(rnd(index, 21)) * 0.9
        let phase = fract(time / period + Double(rnd(index, 22)))
        guard phase < 0.28 else { continue }
        let progress = CGFloat(phase / 0.28)
        let cycle = floor(time / period + Double(rnd(index, 22)))
        let x = rnd(index + Int(cycle) * 31, 23) * size.width
        let depth = rnd(index + Int(cycle) * 17, 24)
        let y = top + (bottom - top) * depth
        let radius = (2 + 5 * depth) * (0.3 + progress)
        let rect = CGRect(x: x - radius, y: y - radius * 0.3, width: radius * 2, height: radius * 0.6)
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(color.opacity(opacity * Double(1 - progress))),
            lineWidth: 0.8
        )
    }
}

private func softLight(
    _ context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    color: Color,
    opacity: Double
) {
    guard radius > 0 else { return }
    context.fill(
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), .clear]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    )
}

private func verticalGradient(_ context: inout GraphicsContext, rect: CGRect, colors: [Color]) {
    context.fill(
        Path(rect),
        with: .linearGradient(
            Gradient(colors: colors),
            startPoint: CGPoint(x: rect.midX, y: rect.minY),
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)
        )
    )
}

/// A brief double flash every so often (not every cycle), like distant lightning.
private func lightningIntensity(time: Double, cycle: Double) -> Double {
    let index = Int(floor(time / cycle))
    guard rnd(index, 41) > 0.45 else { return 0 }
    let t = time - Double(index) * cycle
    if t < 0.07 { return 1 }
    if t > 0.16 && t < 0.24 { return 0.6 }
    if t >= 0.24 && t < 0.9 { return 0.25 * (1 - (t - 0.24) / 0.66) }
    return 0
}

// MARK: - Forest (rain or snow)

private func pine(at x: CGFloat, base: CGFloat, height: CGFloat, width: CGFloat) -> Path {
    let top = base - height
    let tiers = 7
    var right: [CGPoint] = [CGPoint(x: x, y: top)]
    for tier in 1...tiers {
        let fraction = CGFloat(tier) / CGFloat(tiers)
        let y = top + height * 0.88 * fraction
        let half = width * 0.5 * fraction
        right.append(CGPoint(x: x + half, y: y))
        if tier < tiers {
            right.append(CGPoint(x: x + half * 0.42, y: y - height * 0.015))
        }
    }
    let trunk = max(1, width * 0.05)
    right.append(CGPoint(x: x + trunk, y: right.last!.y))
    right.append(CGPoint(x: x + trunk, y: base + 2))

    var path = Path()
    path.move(to: right[0])
    for point in right.dropFirst() { path.addLine(to: point) }
    for point in right.reversed() { path.addLine(to: CGPoint(x: 2 * x - point.x, y: point.y)) }
    path.closeSubpath()
    return path
}

private func ridge(width: CGFloat, height: CGFloat, base: CGFloat, amplitude: CGFloat, seed: Double) -> (Path, (CGFloat) -> CGFloat) {
    let curve: (CGFloat) -> CGFloat = { x in
        let u = Double(x / max(width, 1))
        return base
            + amplitude * CGFloat(sin(u * 5.1 + seed * 3.3))
            + amplitude * 0.5 * CGFloat(sin(u * 11.7 + seed * 1.7))
    }
    var path = Path()
    path.move(to: CGPoint(x: 0, y: height))
    for step in 0...40 {
        let x = width * CGFloat(step) / 40
        path.addLine(to: CGPoint(x: x, y: curve(x)))
    }
    path.addLine(to: CGPoint(x: width, y: height))
    path.closeSubpath()
    return (path, curve)
}

struct ForestScene: View {
    enum Weather { case rain, snow }

    let time: Double
    let compact: Bool
    var weather: Weather = .rain

    var body: some View {
        Canvas { context, size in
            let light = Theme.isLight
            let snow = weather == .snow
            let density: CGFloat = compact ? 0.3 : 1

            let sky: [Color] = snow
                ? (light ? [Color(hex: 0xA9B6C8), Color(hex: 0xDCE3EC)] : [Color(hex: 0x0B111D), Color(hex: 0x2B3550)])
                : (light ? [Color(hex: 0x93A3A4), Color(hex: 0xD3DBD9)] : [Color(hex: 0x0C1417), Color(hex: 0x33444A)])
            let mist = snow
                ? (light ? Color(hex: 0xE4E9F0) : Color(hex: 0x56617D))
                : (light ? Color(hex: 0xDCE3E1) : Color(hex: 0x52656A))
            let layers: [Color] = snow
                ? (light
                    ? [Color(hex: 0x8D9AAE), Color(hex: 0x6C7A90), Color(hex: 0x4A5870), Color(hex: 0x29354A)]
                    : [Color(hex: 0x29324A), Color(hex: 0x1C243A), Color(hex: 0x111829), Color(hex: 0x080C17)])
                : (light
                    ? [Color(hex: 0x82938F), Color(hex: 0x62746F), Color(hex: 0x43544F), Color(hex: 0x24322E)]
                    : [Color(hex: 0x2A3A3B), Color(hex: 0x1C2A29), Color(hex: 0x111C1A), Color(hex: 0x070E0C)])
            let snowGround = light ? Color(hex: 0xEEF2F7) : Color(hex: 0x9AA6BE)

            verticalGradient(&context, rect: CGRect(origin: .zero, size: size), colors: sky)
            // Moon/sky glow behind the clouds.
            softLight(
                &context,
                center: CGPoint(x: size.width * 0.72, y: size.height * 0.2),
                radius: max(size.width, size.height) * 0.45,
                color: snow ? Color(hex: 0xBFD0FF) : Color(hex: 0xC9DAD6),
                opacity: light ? 0.25 : 0.12
            )

            let bases: [CGFloat] = [0.6, 0.7, 0.82, 0.97]
            let treeCounts = [34, 24, 14, 8]
            for (layerIndex, color) in layers.enumerated() {
                let base = size.height * bases[layerIndex]
                let (ground, curve) = ridge(
                    width: size.width,
                    height: size.height,
                    base: base,
                    amplitude: size.height * 0.012 * CGFloat(layerIndex + 1),
                    seed: Double(layerIndex)
                )
                let scale = size.height * (0.16 + 0.11 * CGFloat(layerIndex))
                var trees = Path()
                let count = max(4, Int(CGFloat(treeCounts[layerIndex]) * (compact ? 0.6 : 1)))
                for tree in 0..<count {
                    let x = (CGFloat(tree) + rnd(tree, Double(layerIndex) + 0.3) * 0.8) / CGFloat(count) * size.width * 1.08 - size.width * 0.04
                    let height = scale * (0.55 + 0.6 * rnd(tree, Double(layerIndex) + 0.7))
                    // Near trees sway a little in the wind.
                    let sway = CGFloat(sin(time * 0.7 + Double(tree))) * CGFloat(layerIndex) * 0.6
                    trees.addPath(pine(at: x + sway, base: curve(x) + 4, height: height, width: height * 0.42))
                }
                context.fill(trees, with: .color(color))
                context.fill(ground, with: .color(snow ? snowGround.opacity(0.55 + 0.12 * Double(layerIndex)) : color))
                if snow {
                    // Snow-covered ground reads darker toward the viewer.
                    context.fill(ground, with: .color(color.opacity(0.35)))
                }

                if layerIndex < layers.count - 1 {
                    // Atmospheric perspective: each farther layer sits deeper in the fog.
                    verticalGradient(
                        &context,
                        rect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                        colors: [mist.opacity(0.05), mist.opacity(light ? 0.32 : 0.24), mist.opacity(0.08)]
                    )
                    // Drifting fog bank at this layer's tree line.
                    for wisp in 0..<3 {
                        let speed = 6 + 4 * Double(rnd(wisp, Double(layerIndex) + 9))
                        let x = CGFloat(fract(time * speed / Double(size.width * 1.6) + Double(rnd(wisp, Double(layerIndex) + 5)))) * size.width * 1.6 - size.width * 0.3
                        softLight(
                            &context,
                            center: CGPoint(x: x, y: base - size.height * 0.03),
                            radius: size.width * 0.28,
                            color: mist,
                            opacity: light ? 0.3 : 0.18
                        )
                    }
                }
            }

            if snow {
                let flakes = Int(170 * density)
                for index in 0..<flakes {
                    let depth = rnd(index, 51)
                    let speed = 18 + 46 * depth
                    let travel = size.height + 10
                    let progress = fract(time * Double(speed / travel) + Double(rnd(index, 52)))
                    let y = CGFloat(progress) * travel - 5
                    let x = rnd(index, 53) * size.width + CGFloat(sin(time * (0.4 + Double(depth)) + Double(index))) * 14 * depth
                    let radius = 0.7 + 2.4 * depth
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(Color.white.opacity(0.35 + 0.5 * Double(depth)))
                    )
                }
            } else {
                let rain = light ? Color(hex: 0x3E4D50) : Color(hex: 0xC6D6DA)
                drawRain(&context, size: size, time: time,
                         layer: RainLayer(count: Int(220 * density), speed: 520, length: 9, width: 0.6, opacity: light ? 0.18 : 0.16),
                         color: rain, seed: 1)
                drawRain(&context, size: size, time: time,
                         layer: RainLayer(count: Int(120 * density), speed: 820, length: 16, width: 0.9, opacity: light ? 0.24 : 0.22),
                         color: rain, seed: 2)
                drawRain(&context, size: size, time: time,
                         layer: RainLayer(count: Int(40 * density), speed: 1150, length: 28, width: 1.3, opacity: light ? 0.28 : 0.26),
                         color: rain, seed: 3)
                drawSplashes(&context, size: size, time: time, count: Int(46 * density),
                             top: size.height * 0.9, bottom: size.height, color: rain, opacity: 0.5)

                let flash = lightningIntensity(time: time, cycle: 23)
                if flash > 0 {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.1 * flash)))
                }
            }
        }
    }
}

// MARK: - Rainy café window

struct CafeRainScene: View {
    let time: Double
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let light = Theme.isLight
            let span = max(size.width, size.height)
            let density: CGFloat = compact ? 0.3 : 1

            // The street outside.
            verticalGradient(
                &context,
                rect: CGRect(origin: .zero, size: size),
                colors: light
                    ? [Color(hex: 0x7E8A97), Color(hex: 0xA4AEB8), Color(hex: 0x6F7A84)]
                    : [Color(hex: 0x070B14), Color(hex: 0x141B2A), Color(hex: 0x0B0E15)]
            )

            // Out-of-focus street lights, shop signs and passing cars.
            let palette = [Color(hex: 0xFFB45E), Color(hex: 0xFFD08A), Color(hex: 0xFF6A50), Color(hex: 0x9CC2FF), Color(hex: 0x7EE0C3)]
            let lights = Int(44 * (compact ? 0.5 : 1))
            for index in 0..<lights {
                let color = palette[index % palette.count]
                let x = rnd(index, 61) * size.width + CGFloat(sin(time * 0.05 + Double(index))) * 10
                let y = size.height * (0.28 + 0.5 * rnd(index, 62))
                let radius = span * (0.03 + 0.07 * rnd(index, 63))
                let pulse = 0.8 + 0.2 * sin(time * (0.3 + Double(rnd(index, 64))) + Double(index))
                softLight(&context, center: CGPoint(x: x, y: y), radius: radius, color: color,
                          opacity: (light ? 0.35 : 0.7) * pulse)
            }
            for car in 0..<3 {
                let speed = 0.035 + 0.03 * Double(rnd(car, 71))
                let direction: CGFloat = car.isMultiple(of: 2) ? 1 : -1
                let progress = CGFloat(fract(time * speed + Double(rnd(car, 72))))
                let x = direction > 0 ? progress * size.width * 1.6 - size.width * 0.3 : size.width * 1.3 - progress * size.width * 1.6
                let y = size.height * (0.7 + 0.06 * CGFloat(car))
                let color = direction > 0 ? Color(hex: 0xFFF1D0) : Color(hex: 0xFF4A3A)
                for offset in [-0.035, 0.035] {
                    softLight(&context, center: CGPoint(x: x + size.width * CGFloat(offset), y: y),
                              radius: span * 0.045, color: color, opacity: light ? 0.3 : 0.55)
                }
            }

            // Rain falling outside, softened by the glass.
            drawRain(&context, size: size, time: time,
                     layer: RainLayer(count: Int(140 * density), speed: 700, length: 14, width: 0.7, opacity: light ? 0.12 : 0.1, slant: 0.06),
                     color: light ? Color(hex: 0x3E4A55) : .white, seed: 7)

            // Condensation on the glass.
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(light ? 0.06 : 0.035)))

            // Beads of water sitting on the glass; they slowly come and go.
            let beads = Int(240 * density)
            for index in 0..<beads {
                let life = 0.5 + 0.5 * sin(time * 0.15 * Double(0.5 + rnd(index, 81)) + Double(index))
                guard life > 0.15 else { continue }
                let x = rnd(index, 82) * size.width
                let y = rnd(index, 83) * size.height
                let radius = 0.8 + 2.6 * rnd(index, 84) * rnd(index, 85)
                let rect = CGRect(x: x - radius, y: y - radius * 1.1, width: radius * 2, height: radius * 2.2)
                context.fill(Path(ellipseIn: rect.offsetBy(dx: 0.6, dy: 0.8)), with: .color(Color.black.opacity(0.18 * life)))
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.1 * life)))
                let highlight = radius * 0.4
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius * 0.45, y: y - radius * 0.7, width: highlight, height: highlight)),
                    with: .color(Color.white.opacity(0.45 * life))
                )
            }

            // Drops that run down the window in stops and starts, leaving a trail.
            let runners = Int(16 * density) + 2
            for index in 0..<runners {
                let period = 7 + 9 * Double(rnd(index, 91))
                let phase = fract(time / period + Double(rnd(index, 92)))
                let cycle = Int(floor(time / period + Double(rnd(index, 92))))
                let stops = 5.0
                let eased = phase - sin(phase * 2 * .pi * stops) / (2 * .pi * stops)
                let x0 = rnd(index + cycle * 13, 93) * size.width
                let start = rnd(index + cycle * 7, 94) * size.height * 0.4
                let y = start + CGFloat(eased) * (size.height * 1.1 - start)
                let x = x0 + CGFloat(sin(eased * 9 + Double(index))) * 3
                let radius = 2.2 + 2 * rnd(index, 95)

                var trail = Path()
                trail.move(to: CGPoint(x: x0, y: start))
                for step in 1...10 {
                    let e = eased * Double(step) / 10
                    trail.addLine(to: CGPoint(
                        x: x0 + CGFloat(sin(e * 9 + Double(index))) * 3,
                        y: start + CGFloat(e) * (size.height * 1.1 - start)
                    ))
                }
                context.stroke(trail, with: .color(Color.white.opacity(0.07)), lineWidth: radius * 0.7)
                let head = CGRect(x: x - radius, y: y - radius * 1.25, width: radius * 2, height: radius * 2.5)
                context.fill(Path(ellipseIn: head.offsetBy(dx: 0.8, dy: 1)), with: .color(Color.black.opacity(0.22)))
                context.fill(Path(ellipseIn: head), with: .color(Color.white.opacity(0.16)))
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius * 0.5, y: y - radius * 0.8, width: radius * 0.6, height: radius * 0.6)),
                    with: .color(Color.white.opacity(0.6))
                )
            }

            // Warm café interior light spilling onto the glass, and the window frame.
            softLight(&context, center: CGPoint(x: size.width * 0.05, y: size.height * 1.02),
                      radius: span * 0.7, color: Color(hex: 0xFFA85C), opacity: light ? 0.28 : 0.42)
            softLight(&context, center: CGPoint(x: size.width * 0.95, y: size.height * 1.05),
                      radius: span * 0.35, color: Color(hex: 0xFF8E4A), opacity: light ? 0.12 : 0.18)

            let wood = light ? Color(hex: 0x4A3626) : Color(hex: 0x1A120C)
            let bar = max(4, span * 0.008)
            var frame = Path()
            frame.addRect(CGRect(x: size.width * 0.62 - bar / 2, y: 0, width: bar, height: size.height))
            frame.addRect(CGRect(x: 0, y: size.height * 0.42 - bar / 2, width: size.width, height: bar))
            frame.addRect(CGRect(x: 0, y: size.height - bar * 2.6, width: size.width, height: bar * 2.6))
            context.fill(frame, with: .color(wood.opacity(0.92)))
            var edge = Path()
            edge.addRect(CGRect(x: size.width * 0.62 - bar / 2, y: 0, width: 1, height: size.height))
            edge.addRect(CGRect(x: 0, y: size.height * 0.42 - bar / 2, width: size.width, height: 1))
            edge.addRect(CGRect(x: 0, y: size.height - bar * 2.6, width: size.width, height: 1))
            context.fill(edge, with: .color(Color(hex: 0xFFC48A).opacity(0.18)))
        }
    }
}

// MARK: - City in the rain

struct CityRainScene: View {
    let time: Double
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let light = Theme.isLight
            let density: CGFloat = compact ? 0.3 : 1

            verticalGradient(
                &context,
                rect: CGRect(origin: .zero, size: size),
                colors: light
                    ? [Color(hex: 0x8C95A8), Color(hex: 0xC4BFC4)]
                    : [Color(hex: 0x070912), Color(hex: 0x1D1730), Color(hex: 0x3A2534)]
            )
            softLight(&context, center: CGPoint(x: size.width * 0.5, y: size.height * 0.85),
                      radius: size.width * 0.8, color: Color(hex: 0xFF8A5C), opacity: light ? 0.15 : 0.2)

            let layers: [(base: CGFloat, color: Color, windowOpacity: Double, count: Int)] = light
                ? [(0.78, Color(hex: 0x7D8597), 0.25, 26), (0.88, Color(hex: 0x5A6276), 0.4, 18), (1.0, Color(hex: 0x353C4E), 0.55, 11)]
                : [(0.78, Color(hex: 0x1C1A2E), 0.3, 26), (0.88, Color(hex: 0x121222), 0.42, 18), (1.0, Color(hex: 0x08080F), 0.55, 11)]
            let mist = light ? Color(hex: 0xD8D6DC) : Color(hex: 0x4A3C55)
            let windowColors = [Color(hex: 0xFFD08A), Color(hex: 0xFFE7C2), Color(hex: 0x9FC4FF)]

            for (layerIndex, layer) in layers.enumerated() {
                let base = size.height * layer.base
                let count = max(6, Int(CGFloat(layer.count) * (compact ? 0.6 : 1)))
                let slot = size.width / CGFloat(count)
                var buildings = Path()
                var windows: [Path] = Array(repeating: Path(), count: windowColors.count)
                for building in 0..<count {
                    let width = slot * (0.75 + 0.5 * rnd(building, Double(layerIndex) + 101))
                    let x = CGFloat(building) * slot + (slot - width) / 2
                    let height = size.height * (0.12 + 0.2 * rnd(building, Double(layerIndex) + 102)) * (1 + 0.2 * CGFloat(layerIndex))
                    let rect = CGRect(x: x, y: base - height, width: width, height: height)
                    buildings.addRect(rect)
                    if rnd(building, Double(layerIndex) + 103) > 0.6 {
                        buildings.addRect(CGRect(x: rect.midX - 1, y: rect.minY - height * 0.12, width: 2, height: height * 0.12))
                    }
                    guard !compact || layerIndex == 2 else { continue }
                    let cell = min(9, max(5, width / 9))
                    var row = 0
                    var y = rect.minY + cell
                    while y < base - cell {
                        var column = 0
                        var wx = rect.minX + cell * 0.6
                        while wx < rect.maxX - cell * 0.6 {
                            let id = building * 997 + row * 31 + column + layerIndex * 7919
                            let flicker = fract(time / (40 + 80 * Double(rnd(id, 104))) + Double(rnd(id, 105)))
                            if rnd(id, 106) > 0.62 && flicker < 0.85 {
                                windows[id % windowColors.count].addRect(CGRect(x: wx, y: y, width: cell * 0.42, height: cell * 0.55))
                            }
                            wx += cell
                            column += 1
                        }
                        y += cell * 1.1
                        row += 1
                    }
                }
                context.fill(buildings, with: .color(layer.color))
                for (index, path) in windows.enumerated() {
                    context.fill(path, with: .color(windowColors[index].opacity(layer.windowOpacity)))
                }
                if layerIndex < layers.count - 1 {
                    verticalGradient(
                        &context,
                        rect: CGRect(origin: .zero, size: size),
                        colors: [mist.opacity(0.04), mist.opacity(light ? 0.3 : 0.22)]
                    )
                }
            }

            let rain = light ? Color(hex: 0x3B4152) : Color(hex: 0xD8D2E8)
            drawRain(&context, size: size, time: time,
                     layer: RainLayer(count: Int(200 * density), speed: 600, length: 11, width: 0.6, opacity: 0.14, slant: -0.1),
                     color: rain, seed: 11)
            drawRain(&context, size: size, time: time,
                     layer: RainLayer(count: Int(70 * density), speed: 1050, length: 24, width: 1.1, opacity: 0.22, slant: -0.1),
                     color: rain, seed: 12)

            let flash = lightningIntensity(time: time, cycle: 31)
            if flash > 0 {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.08 * flash)))
            }
        }
    }
}

// MARK: - Video background

/// A muted, looping video that fills its frame (used for "Your video" backgrounds).
struct LoopingVideoView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.play(url)
        return view
    }

    func updateNSView(_ view: PlayerView, context: Context) {
        view.play(url)
    }

    final class PlayerView: NSView {
        private let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var currentURL: URL?
        private let playerLayer = AVPlayerLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            layer = CALayer()
            layer?.addSublayer(playerLayer)
            player.isMuted = true
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }

        func play(_ url: URL) {
            guard url != currentURL else { return }
            currentURL = url
            player.removeAllItems()
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            player.play()
        }
    }
}
