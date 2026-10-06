import AppKit
import ClockioCore
import SwiftUI

struct BackgroundSceneView: View {
    var background: ClockBackground
    var speed: Double
    var saver: Bool = false
    var nightMode: Bool = false
    var pointerUnit: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if background.scene == .image,
                   let path = background.imagePath,
                   let image = BackgroundImageStore.image(atPath: path) {
                    CroppedBackgroundImage(image: image)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .saturation(1)
                        .contrast(1)
                        .ignoresSafeArea()
                } else {
                    TimelineView(.animation) { timeline in
                        // `rendersAsynchronously` renders the Canvas off the main thread so the
                        // scene keeps up with ProMotion (120Hz). Canvas is vector, so it already
                        // rasterizes at the display's native scale — crisp on 4K/Retina.
                        Canvas(rendersAsynchronously: true) { context, size in
                            draw(context: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                        }
                    }
                }

                LinearGradient(
                    colors: [
                        .white.opacity(background.scene == .image ? 0.04 : (background.isLightScene ? 0.16 : 0.12)),
                        .clear,
                        .black.opacity(background.scene == .image ? 0.24 : (background.isLightScene ? 0.10 : 0.46))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [.clear, .black.opacity(background.scene == .image ? 0.16 : (background.isLightScene ? 0.08 : 0.36))],
                    center: .center,
                    startRadius: 0,
                    endRadius: saver ? 760 : 460
                )

                if nightMode {
                    Color.black
                        .opacity(background.scene == .image ? 0.62 : 0.18)
                        .blendMode(.multiply)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color(hex: background.gradient.first ?? "#040812", fallback: .black))
            .clipped()
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let colors = background.colors

        switch background.scene {
        case .paint:
            drawPaint(context: &context, size: size, time: time, colors: colors)
        case .mist:
            drawMist(context: &context, size: size, time: time, colors: colors)
        case .horizon:
            drawHorizon(context: &context, size: size, time: time, colors: colors)
        case .contourHorizon:
            drawContourHorizon(context: &context, size: size, time: time, colors: colors)
        case .aurora:
            drawAurora(context: &context, size: size, time: time, colors: colors)
        default:
            drawRibbons(context: &context, size: size, time: time, colors: colors)
        }
    }

    private func drawPaint(context: inout GraphicsContext, size: CGSize, time: TimeInterval, colors: [Color]) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(colors[safe: 0] ?? .white))
        let drift = CGFloat(time * 0.22 * speed)

        for index in stride(from: 1, to: min(colors.count, 5), by: 1) {
            var path = Path()
            let startX = size.width * (-0.04 + CGFloat(index - 1) * 0.2)
            path.move(to: bent(CGPoint(x: startX, y: size.height * 0.94), size: size, amount: 0.82))

            for step in 0...8 {
                let x = startX + CGFloat(step) * size.width * 0.115
                let wave = sin(CGFloat(step) * 1.22 + drift + CGFloat(index)) * size.height * 0.08
                let y = size.height * (0.2 + CGFloat(index) * 0.035) + wave
                path.addQuadCurve(
                    to: bent(CGPoint(x: x, y: y), size: size, amount: 0.82),
                    control: bent(CGPoint(x: x - size.width * 0.05, y: y + size.height * 0.16), size: size, amount: 0.82)
                )
            }

            context.stroke(
                path,
                with: .color(colors[index].opacity(0.88)),
                style: StrokeStyle(lineWidth: size.height * (saver ? 0.17 : 0.15), lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawMist(context: inout GraphicsContext, size: CGSize, time: TimeInterval, colors: [Color]) {
        guard !colors.isEmpty else {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            return
        }

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    colors[safe: 0] ?? .black,
                    colors[safe: 1] ?? .gray,
                    colors[safe: 0] ?? .black
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )

        let drift = CGFloat(time * 0.045 * max(speed, 0.04))
        let fields: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, c: Int, opacity: Double, phase: CGFloat)] = [
            (0.18, 0.42, 0.72, 0.54, 2, 0.62, 0.2),
            (0.58, 0.46, 0.82, 0.48, 3, 0.52, 1.4),
            (0.84, 0.36, 0.52, 0.38, 4, 0.36, 2.2),
            (0.42, 0.68, 0.76, 0.34, 1, 0.38, 3.0)
        ]

        for field in fields {
            let color = colors[safe: min(field.c, colors.count - 1)] ?? .white
            let center = bent(
                CGPoint(
                    x: size.width * (field.x + cos(drift + field.phase) * 0.045),
                    y: size.height * (field.y + sin(drift * 0.86 + field.phase) * 0.04)
                ),
                size: size,
                amount: 0.44
            )
            let rect = CGRect(
                x: center.x - size.width * field.w / 2,
                y: center.y - size.height * field.h / 2,
                width: size.width * field.w,
                height: size.height * field.h
            )
            var layer = context
            layer.translateBy(x: rect.midX, y: rect.midY)
            layer.rotate(by: .radians(Double(sin(drift + field.phase) * 0.18) + pointerTilt(x: field.x, y: field.y, amount: 0.075)))
            layer.translateBy(x: -rect.midX, y: -rect.midY)
            layer.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(field.opacity), color.opacity(0)]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0,
                    endRadius: max(rect.width, rect.height) * 0.52
                )
            )
        }

        let ridgeY = size.height * (0.58 + sin(drift * 1.2) * 0.018)
        var ridge = Path()
        ridge.move(to: bent(CGPoint(x: -size.width * 0.08, y: ridgeY), size: size, amount: 0.54))
        for step in 0...7 {
            let x = CGFloat(step) / 7 * size.width
            let y = ridgeY
                + sin(CGFloat(step) * 0.92 + drift * 1.8) * size.height * 0.045
                + cos(CGFloat(step) * 0.54 - drift) * size.height * 0.026
            ridge.addQuadCurve(
                to: bent(CGPoint(x: x, y: y), size: size, amount: 0.54),
                control: bent(CGPoint(x: x - size.width * 0.08, y: y - size.height * 0.05), size: size, amount: 0.54)
            )
        }
        ridge.addLine(to: CGPoint(x: size.width * 1.08, y: size.height * 1.08))
        ridge.addLine(to: CGPoint(x: -size.width * 0.08, y: size.height * 1.08))
        ridge.closeSubpath()
        context.fill(
            ridge,
            with: .linearGradient(
                Gradient(colors: [
                    (colors[safe: 1] ?? .black).opacity(0.30),
                    (colors[safe: 0] ?? .black).opacity(0.64)
                ]),
                startPoint: CGPoint(x: 0, y: ridgeY),
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )
    }

    private func drawHorizon(context: inout GraphicsContext, size: CGSize, time: TimeInterval, colors: [Color]) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(colors[safe: 0] ?? .white))
        let drift = CGFloat(time * 0.26 * speed)

        var path = Path()
        path.move(to: bent(CGPoint(x: -size.width * 0.1, y: size.height * 0.54), size: size, amount: 0.72))

        for step in 0...9 {
            let x = CGFloat(step) / 9 * size.width
            let y = size.height * 0.52
                + sin(CGFloat(step) * 1.1 + drift) * size.height * 0.12
                + cos(CGFloat(step) * 0.72 - drift) * size.height * 0.06
            path.addQuadCurve(
                to: bent(CGPoint(x: x, y: y), size: size, amount: 0.72),
                control: bent(CGPoint(x: x - size.width * 0.08, y: y - size.height * 0.08), size: size, amount: 0.72)
            )
        }

        context.addFilter(.shadow(color: .black.opacity(0.13), radius: 42))
        context.stroke(
            path,
            with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: 0, y: size.height * 0.35), endPoint: CGPoint(x: size.width, y: size.height * 0.78)),
            style: StrokeStyle(lineWidth: size.height * 0.28, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawContourHorizon(context: inout GraphicsContext, size: CGSize, time: TimeInterval, colors: [Color]) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    colors[safe: 0] ?? .white,
                    colors[safe: 1]?.opacity(0.34) ?? .blue.opacity(0.34),
                    colors[safe: 0] ?? .white
                ]),
                startPoint: CGPoint(x: size.width * 0.2, y: 0),
                endPoint: CGPoint(x: size.width * 0.8, y: size.height)
            )
        )

        let drift = CGFloat(time * 0.18 * speed)
        let sunColor = colors[safe: 2] ?? .orange
        let sunCenter = bent(
            CGPoint(
                x: size.width * (0.34 + cos(drift * 0.72) * 0.025),
                y: size.height * (0.38 + sin(drift) * 0.02)
            ),
            size: size,
            amount: 0.36
        )
        let sunRadius = min(size.width, size.height) * (saver ? 0.15 : 0.13)
        context.fill(
            Path(ellipseIn: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [sunColor.opacity(0.54), sunColor.opacity(0.10), sunColor.opacity(0)]),
                center: sunCenter,
                startRadius: 0,
                endRadius: sunRadius
            )
        )

        for layerIndex in 0..<4 {
            var shape = Path()
            let baseY = size.height * (0.52 + CGFloat(layerIndex) * 0.09)
            shape.move(to: CGPoint(x: -size.width * 0.08, y: size.height * 1.12))
            shape.addLine(to: bent(CGPoint(x: -size.width * 0.08, y: baseY), size: size, amount: 0.62))

            for step in 0...8 {
                let x = CGFloat(step) / 8 * size.width
                let wave = sin(CGFloat(step) * (0.88 + CGFloat(layerIndex) * 0.11) + drift + CGFloat(layerIndex)) * size.height * (0.045 + CGFloat(layerIndex) * 0.006)
                let ridge = cos(CGFloat(step) * 0.54 - drift * 0.8) * size.height * 0.026
                let y = baseY + wave + ridge
                shape.addQuadCurve(
                    to: bent(CGPoint(x: x, y: y), size: size, amount: 0.62),
                    control: bent(CGPoint(x: x - size.width * 0.08, y: y - size.height * 0.055), size: size, amount: 0.62)
                )
            }

            shape.addLine(to: CGPoint(x: size.width * 1.08, y: size.height * 1.12))
            shape.closeSubpath()

            let color = colors[safe: min(layerIndex + 1, colors.count - 1)] ?? .gray
            let nextColor = colors[safe: min(layerIndex + 2, colors.count - 1)] ?? color
            context.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.52), nextColor.opacity(0.72)]),
                    startPoint: CGPoint(x: 0, y: baseY - size.height * 0.1),
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
        }

        var contour = Path()
        contour.move(to: bent(CGPoint(x: -size.width * 0.04, y: size.height * 0.66), size: size, amount: 0.7))
        for step in 0...10 {
            let x = CGFloat(step) / 10 * size.width
            let y = size.height * 0.66 + sin(CGFloat(step) * 0.86 + drift * 1.4) * size.height * 0.045
            contour.addQuadCurve(
                to: bent(CGPoint(x: x, y: y), size: size, amount: 0.7),
                control: bent(CGPoint(x: x - size.width * 0.05, y: y + size.height * 0.035), size: size, amount: 0.7)
            )
        }
        context.stroke(
            contour,
            with: .color((colors[safe: 4] ?? .black).opacity(0.36)),
            style: StrokeStyle(lineWidth: saver ? 3.0 : 2.0, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawRibbons(context: inout GraphicsContext, size: CGSize, time: TimeInterval, colors: [Color]) {
        let baseGradient = Gradient(colors: [
            colors[safe: 1] ?? .black,
            colors[safe: 0] ?? .black,
            colors[safe: 2]?.opacity(0.38) ?? .gray.opacity(0.38),
            .black
        ])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(baseGradient, center: CGPoint(x: size.width * 0.5, y: size.height * 0.42), startRadius: 0, endRadius: max(size.width, size.height))
        )

        let base = ribbonBase(for: background.id)
        for index in 0..<3 {
            var path = Path()
            let yBase = size.height * (base.y + CGFloat(index) * base.gap)
            let amp = size.height * (base.amp + CGFloat(index) * 0.024)
            let drift = CGFloat(time * speed * (0.62 + Double(index) * 0.18))
            path.move(to: bent(CGPoint(x: -size.width * 0.1, y: yBase), size: size, amount: 0.9))

            for step in 0...6 {
                let x = CGFloat(step) / 6 * size.width
                let y = yBase
                    + sin(CGFloat(step) * base.bend + drift) * amp
                    + cos(CGFloat(step) * 0.88 - drift * 0.7) * amp * 0.45
                path.addQuadCurve(
                    to: bent(CGPoint(x: x, y: y), size: size, amount: 0.9),
                    control: bent(CGPoint(x: x - size.width * 0.12, y: y - amp * 0.62), size: size, amount: 0.9)
                )
            }

            let colorA = colors[safe: index + 1] ?? .white
            let colorB = colors[safe: index + 2] ?? .cyan
            context.addFilter(.shadow(color: colorB.opacity(0.38), radius: saver ? 54 : 34))
            context.stroke(
                path,
                with: .linearGradient(Gradient(colors: [colorA.opacity(0.56), colorB.opacity(0.64)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)),
                style: StrokeStyle(lineWidth: size.height * (saver ? 0.052 : 0.042), lineCap: .round, lineJoin: .round)
            )
        }
    }

    /// The one intentionally soft / blurred preset (Lumen Haze): large drifting radial colour
    /// fields, no per-frame blur filter, so it stays smooth at 4K/120Hz.
    private func drawAurora(context: inout GraphicsContext, size: CGSize, time: TimeInterval, colors: [Color]) {
        guard !colors.isEmpty else {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            return
        }
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [colors[0], colors[safe: 1] ?? colors[0]]),
                startPoint: CGPoint(x: size.width * 0.15, y: 0),
                endPoint: CGPoint(x: size.width * 0.85, y: size.height)
            )
        )

        let t = time * 0.05 * max(speed, 0.04)
        let fields: [(x: CGFloat, y: CGFloat, r: CGFloat, aspect: CGFloat, drift: CGFloat, op: Double, c: Int)] = [
            (0.24, 0.44, 0.62, 0.62, 0.06, 0.60, 1),
            (0.56, 0.50, 0.66, 0.58, 0.07, 0.58, 2),
            (0.82, 0.45, 0.60, 0.62, 0.06, 0.56, 3),
            (0.42, 0.30, 0.50, 0.70, 0.08, 0.46, 4)
        ]

        for (index, field) in fields.enumerated() {
            let color = colors[min(field.c, colors.count - 1)]
            let phase = t + Double(index) * 1.27
            let fieldCenter = bent(
                CGPoint(
                    x: size.width * (field.x + CGFloat(sin(phase)) * field.drift),
                    y: size.height * (field.y + CGFloat(cos(phase * 0.82)) * field.drift)
                ),
                size: size,
                amount: 0.5
            )
            let cx = fieldCenter.x
            let cy = fieldCenter.y
            let radius = min(size.width, size.height) * field.r
            let center = CGPoint(x: cx, y: cy)

            var layer = context
            layer.translateBy(x: cx, y: cy)
            layer.rotate(by: .radians(pointerTilt(x: field.x, y: field.y, amount: 0.06)))
            layer.scaleBy(x: 1, y: field.aspect)
            layer.translateBy(x: -cx, y: -cy)
            layer.fill(
                Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(field.op), color.opacity(0)]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }

    private func ribbonBase(for id: String) -> (y: CGFloat, gap: CGFloat, amp: CGFloat, bend: CGFloat) {
        switch id {
        case "mahogany": (0.48, 0.075, 0.055, 1.08)
        case "lumen": (0.33, 0.112, 0.082, 1.72)
        default: (0.4, 0.09, 0.07, 1.38)
        }
    }

    /// Curves individual drawn points toward the pointer without translating the whole canvas.
    /// The center stays anchored while edges flex, so the active screensaver feels responsive
    /// without the old full-background parallax drift.
    private func bent(_ point: CGPoint, size: CGSize, amount: CGFloat) -> CGPoint {
        let unit = saver ? pointerUnit : .zero
        guard unit != .zero, size.width > 0, size.height > 0 else { return point }

        let nx = min(1.2, max(-1.2, point.x / size.width * 2 - 1))
        let ny = min(1.2, max(-1.2, point.y / size.height * 2 - 1))
        let strength = min(size.width, size.height) * 0.026 * amount
        let twist = nx * ny * 0.22

        return CGPoint(
            x: point.x + unit.width * strength * ny * ny + unit.height * strength * twist,
            y: point.y + unit.height * strength * nx * nx + unit.width * strength * twist
        )
    }

    private func pointerTilt(x: CGFloat, y: CGFloat, amount: Double) -> Double {
        let unit = saver ? pointerUnit : .zero
        guard unit != .zero else { return 0 }
        return Double(unit.width * (y - 0.5) - unit.height * (x - 0.5)) * amount
    }
}
