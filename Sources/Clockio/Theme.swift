import SwiftUI

/// Design tokens for Clockio's "Editorial Warm-Minimal" direction.
///
/// One warm accent, warm paper neutrals (never pure black/white), an 8pt spacing
/// grid, and a serif display face (New York) for the wordmark. The colourful clock
/// scenes are the content; this chrome is intentionally quiet so the preview is the hero.
enum Theme {
    // MARK: Palette
    static let canvas        = Color.adaptive(light: "F2EEE7", dark: "050609")   // warm paper / off-black shell
    static let canvasDeep    = Color.adaptive(light: "E8E3DA", dark: "030405")   // gradient base for depth
    static let surface       = Color.adaptive(light: "FBFAF6", dark: "090B10")   // card / panel surface
    static let surfaceSunken  = Color.adaptive(light: "EFEBE3", dark: "05070B")  // recessed fields
    static let ink           = Color.adaptive(light: "201E1A", dark: "F7F2E8")   // primary text
    static let inkSecondary  = Color.adaptive(light: "6C685F", dark: "B9B0A1")   // muted label
    static let inkTertiary   = Color.adaptive(light: "A39E93", dark: "7C7468")   // faint metadata
    static let hairline      = Color.adaptive(light: "000000", dark: "FFFFFF").opacity(0.06)
    static let accent        = Color.adaptive(light: "C25A38", dark: "D86445")   // terracotta — the single accent
    static let accentSoft    = Color.adaptive(light: "C25A38", dark: "D86445").opacity(0.18)

    // MARK: Spacing (8pt grid)
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32
    static let s7: CGFloat = 48

    // MARK: Radii
    static let rSm: CGFloat = 12
    static let rMd: CGFloat = 18
    static let rLg: CGFloat = 28

    // MARK: Type
    /// New York serif — used only for the wordmark and section display titles.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Monospaced eyebrow labels (calm tracking, low contrast).
    static func eyebrow(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
    static func body(_ size: CGFloat = 14, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Reusable chrome

/// Plain-looking button whose **entire** frame is clickable (not just the text/icon), with a
/// subtle press feedback. `.buttonStyle(.plain)` only hit-tests drawn content, so padded rows
/// and icon buttons felt dead everywhere but on the glyph.
struct ClickableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.98
    var shape: AnyShape = AnyShape(Rectangle())

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ClickableButtonStyle {
    /// Full-frame clickable area with a rectangular hit shape.
    static var clickable: ClickableButtonStyle { ClickableButtonStyle() }
    /// Full-frame clickable area with a circular hit shape (for round icon buttons).
    static var clickableCircle: ClickableButtonStyle {
        ClickableButtonStyle(shape: AnyShape(Circle()))
    }
}

/// A calm warm-paper surface with a hairline border and a single soft shadow.
/// Replaces the previous stacked translucent-white panels.
struct Card<Content: View>: View {
    var radius: CGFloat = Theme.rMd
    var padding: CGFloat = Theme.s5
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 24, x: 0, y: 14)
    }
}

/// A slim, single-accent slider. macOS ignores `.tint` on the stock `Slider`, which left a
/// stray system-blue fill — this keeps the chrome on one terracotta accent.
struct MinimalSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>

    private let knob: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - knob, 1)
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let t = min(max(fraction, 0), 1)

            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceSunken).frame(height: 5)
                Capsule().fill(Theme.accent).frame(width: t * usable + knob / 2, height: 5)
                Circle()
                    .fill(Theme.surface)
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                    .frame(width: knob, height: knob)
                    .offset(x: t * usable)
            }
            .frame(height: knob)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let clamped = min(max((g.location.x - knob / 2) / usable, 0), 1)
                        value = range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: knob)
    }
}

/// Small uppercase section label used across panels.
struct Eyebrow: View {
    var text: String
    var trailing: String?

    init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(text)
                .tracking(1.4)
            if let trailing {
                Spacer()
                Text(trailing)
                    .tracking(1.0)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .font(Theme.eyebrow())
        .foregroundStyle(Theme.inkSecondary)
    }
}
