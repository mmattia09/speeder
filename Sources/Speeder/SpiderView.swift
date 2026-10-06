import SpeederCore
import SwiftUI

/// The little spider that lives in the menu bar, seen from above: it walks faster
/// the quicker you type, and its colour says how fast that is.
struct SpiderView: View {
    let wpm: Double
    let isTyping: Bool
    let phase: Double

    /// 0 at a standstill, 1 at "blistering".
    private var motion: Double {
        guard isTyping else { return 0 }
        return min(1, wpm / 70)
    }

    var body: some View {
        Canvas { context, size in
            let palette = tint
            let time = phase * (1 + wpm / 25)

            drawLegs(context: context, size: size, time: time, color: palette)
            drawBody(context: context, size: size, color: palette)
        }
    }

    private var tint: Color {
        switch WPMFormatter.Tier.tier(for: wpm, isTyping: isTyping) {
        case .idle: return .secondary
        case .slow: return .blue
        case .steady: return .green
        case .brisk: return .orange
        case .fast: return .red
        }
    }

    private func drawBody(context: GraphicsContext, size: CGSize, color: Color) {
        let width = size.width
        let height = size.height
        let line = max(1, height * 0.055)

        let headRadius = height * 0.145
        let head = CGPoint(x: width * 0.5, y: height * 0.22)
        let abdomen = CGRect(
            x: width * 0.5 - width * 0.2,
            y: height * 0.4,
            width: width * 0.4,
            height: height * 0.52
        )

        // The waist first, so head and abdomen read as two parts of one body.
        var waist = Path()
        waist.move(to: CGPoint(x: width * 0.5, y: head.y + headRadius * 0.5))
        waist.addLine(to: CGPoint(x: width * 0.5, y: abdomen.midY))
        context.stroke(waist, with: .color(color), lineWidth: line * 1.6)

        var body = Path(ellipseIn: abdomen)
        body.addEllipse(in: CGRect(
            x: head.x - headRadius,
            y: head.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))
        context.fill(body, with: .color(color))

        // Eyes, in the front of the head.
        let eyeRadius = max(0.6, headRadius * 0.2)
        let eyeColor = Color(nsColor: .windowBackgroundColor)
        for offset in [-headRadius * 0.4, headRadius * 0.05, headRadius * 0.42] {
            let eye = CGRect(
                x: head.x + offset - eyeRadius,
                y: head.y - headRadius * 0.35 - eyeRadius,
                width: eyeRadius * 2,
                height: eyeRadius * 2
            )
            context.fill(Path(ellipseIn: eye), with: .color(eyeColor))
        }
    }

    private func drawLegs(context: GraphicsContext, size: CGSize, time: Double, color: Color) {
        let width = size.width
        let height = size.height
        let style = StrokeStyle(
            lineWidth: max(1, height * 0.055),
            lineCap: .round,
            lineJoin: .round
        )

        // Root positions along the abdomen, from the front pair to the back one,
        // and the angle each leg leaves the body at: forward legs point up.
        let roots: [(offset: Double, y: Double, angle: Double)] = [
            (0.17, 0.44, -1.25),
            (0.18, 0.55, -0.65),
            (0.18, 0.67, 0.05),
            (0.17, 0.79, 0.75),
        ]
        let upperLength = width * 0.16
        let lowerLength = width * 0.13

        for side in [-1.0, 1.0] {
            for (index, root) in roots.enumerated() {
                let wobble = sin(time + Double(index) * 0.9 + (side > 0 ? 1.7 : 0)) * 0.22 * motion
                let angle = root.angle + wobble
                let bend = root.angle * 0.4 - wobble * 0.4

                let origin = CGPoint(
                    x: width * (0.5 + root.offset * side),
                    y: height * root.y
                )
                let knee = CGPoint(
                    x: origin.x + side * cos(angle) * upperLength,
                    y: origin.y + sin(angle) * upperLength
                )
                let foot = CGPoint(
                    x: knee.x + side * cos(bend) * lowerLength,
                    y: knee.y + sin(bend) * lowerLength * 0.9
                )

                var leg = Path()
                leg.move(to: origin)
                leg.addLine(to: knee)
                leg.addLine(to: foot)
                context.stroke(leg, with: .color(color.opacity(0.92)), style: style)
            }
        }
    }
}
