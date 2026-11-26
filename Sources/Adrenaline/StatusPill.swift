import AppKit

enum StatusPill {
    enum Fill {
        /// Outlined pill (Off).
        case none
        /// Lower half filled, upper half outlined (Auto).
        case half
        /// Filled pill (On).
        case full
    }

    static func image(fill: Fill, badged: Bool) -> NSImage {
        let pillScale: CGFloat = 1.2
        let size = NSSize(width: 21, height: 17)

        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.saveGState()
            defer { context.restoreGState() }

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)

            if badged {
                context.setFillColor(NSColor.black.cgColor)
                context.fillEllipse(in: CGRect(x: rect.maxX - 5, y: rect.minY + 1, width: 4, height: 4))
            }

            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: .pi / 6)

            let pillWidth: CGFloat = 13.2 * pillScale
            let pillHeight: CGFloat = 6.5 * pillScale
            let pillRect = CGRect(
                x: -pillWidth / 2,
                y: -pillHeight / 2,
                width: pillWidth,
                height: pillHeight
            )
            let radius = pillRect.height / 2
            let pillPath = CGPath(
                roundedRect: pillRect,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )

            context.setStrokeColor(NSColor.black.cgColor)
            context.setFillColor(NSColor.black.cgColor)

            // Each half is the pill cut at a gap in the middle. A filled half and an
            // outlined half have the same outer edge: the outline is drawn inside the
            // half's shape, never over it. The rotation lifts the pill's right end, so
            // the left half is the lower one.
            let splitWidth: CGFloat = 1.9 * pillScale
            let lineWidth: CGFloat = 1.5
            let bounds = pillRect.insetBy(dx: -2, dy: -2)
            let lower = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.midX - splitWidth / 2 - bounds.minX, height: bounds.height)
            let upper = CGRect(x: splitWidth / 2, y: bounds.minY, width: bounds.maxX - splitWidth / 2, height: bounds.height)

            func drawHalf(_ half: CGRect, seamX: CGFloat, filled: Bool) {
                context.saveGState()
                defer { context.restoreGState() }
                context.clip(to: half)
                context.addPath(pillPath)
                if filled {
                    context.fillPath()
                    return
                }
                context.clip()
                // Clipped to the half's shape, a stroke twice as wide leaves exactly
                // lineWidth inside it.
                context.setLineWidth(lineWidth * 2)
                context.addPath(pillPath)
                context.move(to: CGPoint(x: seamX, y: bounds.minY))
                context.addLine(to: CGPoint(x: seamX, y: bounds.maxY))
                context.strokePath()
            }

            drawHalf(lower, seamX: lower.maxX, filled: fill != .none)
            drawHalf(upper, seamX: upper.minX, filled: fill == .full)

            return true
        }

        image.isTemplate = true
        return image
    }
}
