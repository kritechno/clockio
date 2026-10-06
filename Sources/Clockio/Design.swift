import AppKit
import ClockioCore
import SwiftUI

extension Color {
    init(hex: String, fallback: Color = .white) {
        guard let nsColor = NSColor(hex: hex) else {
            self = fallback
            return
        }
        self = Color(nsColor)
    }

    static func adaptive(light: String, dark: String) -> Color {
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
                ?? NSColor(hex: light)
                ?? .white
        })
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = Int(value, radix: 16) else { return nil }
        let red = CGFloat((rgb >> 16) & 0xFF) / 255
        let green = CGFloat((rgb >> 8) & 0xFF) / 255
        let blue = CGFloat(rgb & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    var hexString: String {
        let color = usingColorSpace(.sRGB) ?? self
        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension ClockBackground {
    var colors: [Color] {
        gradient.map { Color(hex: $0) }
    }

    var isLightScene: Bool {
        switch scene {
        case .paint, .horizon, .contourHorizon:
            true
        case .ribbons, .mist, .aurora, .image:
            false
        }
    }

    func applyingNightMode(_ isActive: Bool) -> ClockBackground {
        guard isActive, scene != .image else { return self }
        var next = self
        next.gradient = gradient.enumerated().map { index, hex in
            NightPalette.adjustedHex(hex, scene: scene, index: index)
        }
        if gradient.indices.contains(3) {
            next.accent = NightPalette.adjustedHex(gradient[3], scene: scene, index: 3)
        }
        return next
    }
}

private enum NightPalette {
    static func adjustedHex(_ hex: String, scene: BackgroundScene, index: Int) -> String {
        guard let color = NSColor(hex: hex)?.usingColorSpace(.sRGB),
              let base = NSColor(hex: baseHex(for: index))?.usingColorSpace(.sRGB)
        else { return hex }

        let amount = blendAmount(for: scene, index: index)
        let red = color.redComponent * (1 - amount) + base.redComponent * amount
        let green = color.greenComponent * (1 - amount) + base.greenComponent * amount
        let blue = color.blueComponent * (1 - amount) + base.blueComponent * amount
        return NSColor(red: red, green: green, blue: blue, alpha: 1).hexString
    }

    private static func baseHex(for index: Int) -> String {
        switch index {
        case 0: "#020308"
        case 1: "#050711"
        case 2: "#090D1A"
        case 3: "#111827"
        default: "#1A2233"
        }
    }

    private static func blendAmount(for scene: BackgroundScene, index: Int) -> CGFloat {
        switch scene {
        case .paint, .horizon, .contourHorizon:
            index == 0 ? 0.86 : 0.74
        case .ribbons, .mist, .aurora:
            index == 0 ? 0.56 : 0.62
        case .image:
            0
        }
    }
}

enum DisplayFormat {
    static func temperature(_ celsius: Int) -> String {
        "\(celsius)°C"
    }
}

struct IconGlyph: View {
    var systemName: String
    var size: CGFloat = 17

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 22, height: 22)
    }
}

/// Decoding an `NSImage` from disk on every SwiftUI body pass is wasteful: the screensaver
/// re-evaluates the background view on every pointer move and once per second, which re-read
/// the file from disk each time and could hitch on large custom images. Cache decoded images
/// by path so a custom background is loaded exactly once. A new import gets a fresh UUID path,
/// so the key changes and the cache never serves a stale image. `NSCache` is thread-safe.
@MainActor
enum BackgroundImageStore {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(atPath path: String) -> NSImage? {
        let key = path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

struct CroppedBackgroundImage: View {
    var image: NSImage

    var body: some View {
        GeometryReader { proxy in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

struct BackgroundThumb: View {
    var background: ClockBackground
    var cornerRadius: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if background.scene == .image,
                   let imagePath = background.imagePath,
                   let image = BackgroundImageStore.image(atPath: imagePath) {
                    CroppedBackgroundImage(image: image)
                } else {
                    ThumbPattern(background: background)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

private struct ThumbPattern: View {
    var background: ClockBackground

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let colors = background.colors
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [colors[safe: 0] ?? .black, colors[safe: 1] ?? .gray]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )

                switch background.scene {
                case .paint:
                    for index in stride(from: 1, to: min(colors.count, 5), by: 1) {
                        var path = Path()
                        let x = size.width * CGFloat(index - 1) * 0.21
                        path.move(to: CGPoint(x: x, y: size.height * 0.95))
                        path.addCurve(
                            to: CGPoint(x: x + size.width * 0.48, y: size.height * 0.08),
                            control1: CGPoint(x: x + size.width * 0.04, y: size.height * 0.52),
                            control2: CGPoint(x: x + size.width * 0.22, y: size.height * 0.12)
                        )
                        context.stroke(path, with: .color(colors[index]), style: StrokeStyle(lineWidth: size.height * 0.32, lineCap: .round))
                    }
                case .mist:
                    let layout: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, c: Int)] = [
                        (0.18, 0.42, 0.86, 0.62, 2),
                        (0.58, 0.46, 0.9, 0.52, 3),
                        (0.86, 0.36, 0.58, 0.42, 4)
                    ]
                    for field in layout {
                        let color = colors[safe: field.c] ?? .white
                        let rect = CGRect(
                            x: size.width * field.x - size.width * field.w / 2,
                            y: size.height * field.y - size.height * field.h / 2,
                            width: size.width * field.w,
                            height: size.height * field.h
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [color.opacity(0.64), color.opacity(0)]),
                                center: CGPoint(x: rect.midX, y: rect.midY),
                                startRadius: 0,
                                endRadius: max(rect.width, rect.height) * 0.5
                            )
                        )
                    }
                    var ridge = Path()
                    ridge.move(to: CGPoint(x: -size.width * 0.1, y: size.height * 0.62))
                    ridge.addCurve(
                        to: CGPoint(x: size.width * 1.12, y: size.height * 0.54),
                        control1: CGPoint(x: size.width * 0.24, y: size.height * 0.45),
                        control2: CGPoint(x: size.width * 0.76, y: size.height * 0.78)
                    )
                    ridge.addLine(to: CGPoint(x: size.width * 1.12, y: size.height * 1.1))
                    ridge.addLine(to: CGPoint(x: -size.width * 0.1, y: size.height * 1.1))
                    ridge.closeSubpath()
                    context.fill(
                        ridge,
                        with: .linearGradient(
                            Gradient(colors: [
                                (colors[safe: 1] ?? .gray).opacity(0.34),
                                (colors[safe: 0] ?? .black).opacity(0.72)
                            ]),
                            startPoint: CGPoint(x: 0, y: size.height * 0.58),
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )
                case .horizon:
                    var path = Path()
                    path.move(to: CGPoint(x: -size.width * 0.1, y: size.height * 0.58))
                    path.addCurve(
                        to: CGPoint(x: size.width * 1.12, y: size.height * 0.36),
                        control1: CGPoint(x: size.width * 0.25, y: size.height * 0.14),
                        control2: CGPoint(x: size.width * 0.72, y: size.height * 0.88)
                    )
                    context.stroke(
                        path,
                        with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)),
                        style: StrokeStyle(lineWidth: size.height * 0.36, lineCap: .round)
                    )
                case .contourHorizon:
                    let sun = CGPoint(x: size.width * 0.34, y: size.height * 0.38)
                    let radius = min(size.width, size.height) * 0.18
                    context.fill(
                        Path(ellipseIn: CGRect(x: sun.x - radius, y: sun.y - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(
                            Gradient(colors: [(colors[safe: 2] ?? .orange).opacity(0.6), .clear]),
                            center: sun,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                    for layer in 0..<3 {
                        var path = Path()
                        let y = size.height * (0.52 + CGFloat(layer) * 0.13)
                        path.move(to: CGPoint(x: -size.width * 0.1, y: size.height * 1.1))
                        path.addLine(to: CGPoint(x: -size.width * 0.1, y: y))
                        path.addCurve(
                            to: CGPoint(x: size.width * 1.1, y: y + size.height * (layer.isMultiple(of: 2) ? -0.08 : 0.07)),
                            control1: CGPoint(x: size.width * 0.28, y: y - size.height * 0.18),
                            control2: CGPoint(x: size.width * 0.7, y: y + size.height * 0.16)
                        )
                        path.addLine(to: CGPoint(x: size.width * 1.1, y: size.height * 1.1))
                        path.closeSubpath()
                        let color = colors[safe: layer + 1] ?? .gray
                        let next = colors[safe: layer + 2] ?? color
                        context.fill(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [color.opacity(0.55), next.opacity(0.74)]),
                                startPoint: CGPoint(x: 0, y: y),
                                endPoint: CGPoint(x: size.width, y: size.height)
                            )
                        )
                    }
                case .aurora:
                    // Soft-field miniature for the one blurred preset.
                    let layout: [(x: CGFloat, y: CGFloat, r: CGFloat, aspect: CGFloat, c: Int)] = [
                        (0.28, 0.42, 0.8, 0.6, 1), (0.6, 0.5, 0.82, 0.58, 2), (0.82, 0.46, 0.74, 0.6, 3)
                    ]
                    for field in layout {
                        let color = colors[safe: field.c] ?? .white
                        let cx = size.width * field.x
                        let cy = size.height * field.y
                        let radius = min(size.width, size.height) * field.r
                        var layer = context
                        layer.translateBy(x: cx, y: cy)
                        layer.scaleBy(x: 1, y: field.aspect)
                        layer.translateBy(x: -cx, y: -cy)
                        layer.fill(
                            Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                            with: .radialGradient(
                                Gradient(colors: [color.opacity(0.62), color.opacity(0)]),
                                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: radius
                            )
                        )
                    }
                default:
                    for index in stride(from: 1, to: min(colors.count, 5), by: 1) {
                        var path = Path()
                        let y = size.height * (0.28 + CGFloat(index) * 0.14)
                        path.move(to: CGPoint(x: -size.width * 0.12, y: y))
                        path.addCurve(
                            to: CGPoint(x: size.width * 1.12, y: y + CGFloat(index % 2 == 0 ? -1 : 1) * size.height * 0.16),
                            control1: CGPoint(x: size.width * 0.25, y: y - size.height * 0.28),
                            control2: CGPoint(x: size.width * 0.7, y: y + size.height * 0.28)
                        )
                        context.stroke(path, with: .color(colors[index]), style: StrokeStyle(lineWidth: size.height * 0.12, lineCap: .round))
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
