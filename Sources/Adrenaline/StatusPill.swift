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

            let splitWidth: CGFloat = 1.9 * pillScale
            let splitInset: CGFloat = 1.75 * pillScale
            let splitRect = CGRect(
                x: -splitWidth / 2,
                y: pillRect.minY - splitInset,
                width: splitWidth,
                height: pillRect.height + (splitInset * 2)
            )

            switch fill {
            case .full:
                context.addPath(pillPath)
                context.fillPath()
                context.setBlendMode(.clear)
                context.fill(splitRect)
            case .half:
                // The rotation lifts the pill's right end, so its left half is the lower one:
                // fill it up to the seam gap, and outline the other half as a closed shape.
                let lineWidth: CGFloat = 1.6
                let bounds = pillRect.insetBy(dx: -2, dy: -2)
                context.saveGState()
                context.clip(to: CGRect(x: bounds.minX, y: bounds.minY, width: splitRect.minX - bounds.minX, height: bounds.height))
                context.addPath(pillPath)
                context.fillPath()
                context.restoreGState()

                let seamEdge = splitRect.maxX + lineWidth / 2
                context.saveGState()
                context.clip(to: CGRect(x: splitRect.maxX, y: bounds.minY, width: bounds.maxX - splitRect.maxX, height: bounds.height))
                context.setLineWidth(lineWidth)
                context.addPath(pillPath)
                context.move(to: CGPoint(x: seamEdge, y: pillRect.minY))
                context.addLine(to: CGPoint(x: seamEdge, y: pillRect.maxY))
                context.strokePath()
                context.restoreGState()
            case .none:
                context.setLineWidth(1.6)
                context.addPath(pillPath)
                context.strokePath()

                context.setLineWidth(1.25)
                let seamOvershoot: CGFloat = 0.9 * pillScale
                context.move(to: CGPoint(x: 0, y: pillRect.minY - seamOvershoot))
                context.addLine(to: CGPoint(x: 0, y: pillRect.maxY + seamOvershoot))
                context.strokePath()
            }

            return true
        }

        image.isTemplate = true
        return image
    }
}
