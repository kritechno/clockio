import AppKit
import SwiftUI

/// Tracks the pointer position inside a view and exposes it to children as a normalized
/// vector in `-1...1` on each axis (`.zero` = centred / pointer absent). Movement is spring
/// smoothed so layered children can drift with the cursor to create depth — the app's
/// signature detail.
///
/// Honors `accessibilityReduceMotion`: when reduce-motion is on the offset is pinned to
/// `.zero` and the scene stays still.
struct PointerParallax<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var unit: CGSize = .zero

    /// When provided, pointer movement is read from global screen coordinates instead of
    /// per-window hover events. That keeps multi-display screensaver windows smooth at seams.
    var globalFrame: CGRect?

    /// `content` receives the smoothed unit vector to build its own layered offsets/tilt.
    var content: (CGSize) -> Content

    var body: some View {
        GeometryReader { geo in
            let pointerContent = content(reduceMotion ? .zero : unit)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())

            if let globalFrame {
                pointerContent
                    .onAppear {
                        updateGlobalPointer(in: globalFrame, immediate: true)
                    }
                    .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
                        updateGlobalPointer(in: globalFrame)
                    }
            } else {
                pointerContent
                    .onContinuousHover { phase in
                        guard !reduceMotion else { return }
                        switch phase {
                        case .active(let point):
                            let nx = clamp(point.x / max(geo.size.width, 1) * 2 - 1)
                            let ny = clamp(point.y / max(geo.size.height, 1) * 2 - 1)
                            // Soft, trailing follow — smooth rather than snappy.
                            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.25)) {
                                unit = CGSize(width: nx, height: ny)
                            }
                        case .ended:
                            // Ease back to rest when the pointer leaves.
                            withAnimation(.spring(response: 0.85, dampingFraction: 0.9)) {
                                unit = .zero
                            }
                        }
                    }
                }
        }
    }

    private func clamp(_ value: CGFloat) -> CGFloat { min(1, max(-1, value)) }

    private func updateGlobalPointer(in frame: CGRect, immediate: Bool = false) {
        guard !reduceMotion, frame.width > 0, frame.height > 0 else {
            unit = .zero
            return
        }

        let target = globalUnit(for: NSEvent.mouseLocation, in: frame)
        guard !immediate else {
            unit = target
            return
        }

        let easing: CGFloat = 0.16
        unit = CGSize(
            width: unit.width + (target.width - unit.width) * easing,
            height: unit.height + (target.height - unit.height) * easing
        )

        if abs(unit.width) < 0.001, abs(unit.height) < 0.001 {
            unit = .zero
        }
    }

    private func globalUnit(for location: CGPoint, in frame: CGRect) -> CGSize {
        let x = (location.x - frame.minX) / max(frame.width, 1) * 2 - 1
        let yFromTop = (frame.maxY - location.y) / max(frame.height, 1)
        let y = yFromTop * 2 - 1

        let dx = max(frame.minX - location.x, 0, location.x - frame.maxX)
        let dy = max(frame.minY - location.y, 0, location.y - frame.maxY)
        let outsideDistance = hypot(dx, dy)
        let falloffDistance = max(220, min(frame.width, frame.height) * 0.35)
        let influence = max(0, 1 - outsideDistance / falloffDistance)

        return CGSize(
            width: clamp(x) * influence,
            height: clamp(y) * influence
        )
    }
}

extension View {
    /// Drift the view along the pointer vector. Larger `depth` = closer to the viewer
    /// (moves more). Use opposing depths on layers to separate fore/background.
    func parallaxOffset(_ unit: CGSize, depth: CGFloat) -> some View {
        offset(x: unit.width * depth, y: unit.height * depth)
    }

}

/// A soft specular highlight that tracks the pointer — adds a premium glass sheen to the
/// preview without any banned gradient slop. Drawn additively at very low opacity.
struct PointerSheen: View {
    var unit: CGSize
    var intensity: Double = 0.22

    var body: some View {
        GeometryReader { geo in
            let center = UnitPoint(
                x: 0.5 + unit.width * 0.5,
                y: 0.5 + unit.height * 0.5
            )
            RadialGradient(
                colors: [.white.opacity(intensity), .clear],
                center: center,
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.7
            )
            .blendMode(.softLight)
            .allowsHitTesting(false)
        }
    }
}
