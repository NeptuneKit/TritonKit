#if canImport(UIKit)
import UIKit

/// A bounded, ephemeral crop of the authoritative business window. Rendering
/// this window alone prevents recursively capturing the inspector itself.
@MainActor
final class TKPickerMagnifierView: UIImageView {
    private var lastRenderTime: TimeInterval = -.infinity
    private let zoom: CGFloat = 2

    init() {
        super.init(frame: .zero)
        accessibilityIdentifier = "triton.picker.magnifier"
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.borderWidth = 2
        layer.borderColor = UIColor(red: 0.12, green: 0.83, blue: 0.72, alpha: 1).cgColor
        clipsToBounds = true
        isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    func clear() {
        isHidden = true
        image = nil
        lastRenderTime = -.infinity
    }

    func update(window: UIWindow, point: CGPoint, targetRect: CGRect,
                time: TimeInterval, force: Bool) {
        guard !bounds.isEmpty else { clear(); return }
        isHidden = false
        guard force || time - lastRenderTime >= 1.0 / 15 else { return }
        lastRenderTime = time
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(window.screen.scale, 2)
        format.opaque = true
        image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            let cg = context.cgContext
            UIColor.secondarySystemBackground.setFill()
            cg.fill(bounds)
            cg.saveGState()
            cg.translateBy(x: bounds.midX - point.x * zoom, y: bounds.midY - point.y * zoom)
            cg.scaleBy(x: zoom, y: zoom)
            window.layer.render(in: cg)
            cg.setStrokeColor(layer.borderColor!)
            cg.setLineWidth(1)
            cg.stroke(targetRect)
            cg.restoreGState()
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.7).cgColor)
            cg.setLineWidth(3)
            for width: CGFloat in [3, 1] {
                cg.setLineWidth(width)
                if width == 1 { cg.setStrokeColor(UIColor.white.cgColor) }
                cg.move(to: CGPoint(x: center.x - 8, y: center.y))
                cg.addLine(to: CGPoint(x: center.x + 8, y: center.y))
                cg.move(to: CGPoint(x: center.x, y: center.y - 8))
                cg.addLine(to: CGPoint(x: center.x, y: center.y + 8))
                cg.strokePath()
            }
        }
    }
}
#endif
