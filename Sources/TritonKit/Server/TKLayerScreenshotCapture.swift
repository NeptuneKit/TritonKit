#if canImport(UIKit)
import UIKit

/// A synchronous main-actor operation. Rendering one layer cannot be interrupted;
/// callers must check their deadline between captures and cap both pixels and bytes.
@MainActor
enum TKLayerScreenshotCapture {
    struct Result {
        let data: Data?
        let scale: Double?
        let pixelCount: Int
        let failureReason: String?
    }

    static func capture(_ layer: CALayer, solo: Bool, maxPixelCount: Int) -> Result {
        guard TritonKit.isRuntimeEnabled else { return failure("runtime_disabled") }
        let bounds = layer.bounds
        guard maxPixelCount > 0 else { return failure("budget_exceeded") }
        guard bounds.origin.x.isFinite, bounds.origin.y.isFinite,
              bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0,
              !layer.isHidden, layer.opacity > 0.01,
              !layer.tk_isInspectorOverlay else { return failure("screenshot_unavailable") }
        let area = bounds.width * bounds.height
        guard area.isFinite, area > 0 else { return failure("screenshot_unavailable") }
        // The per-axis limit also bounds extremely thin or wide layers, whose
        // rounded-up one-pixel short side would otherwise exceed the area budget.
        let budget = CGFloat(maxPixelCount)
        let scale = [layer.tk_inspectionScale, sqrt(budget / area),
                     budget / bounds.width, budget / bounds.height,
                     8_192 / bounds.width, 8_192 / bounds.height].min() ?? 1
        guard scale.isFinite, scale > 0 else { return failure("screenshot_unavailable") }
        let width = max(1, Int(floor(bounds.width * scale)))
        let height = max(1, Int(floor(bounds.height * scale)))
        guard width * height <= maxPixelCount else { return failure("budget_exceeded") }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(width), height: CGFloat(height)), format: format)
        let data: Data
        if solo {
            // Do not detach/reorder layers. No await or run-loop turn is allowed
            // while children are hidden, and their individual state is restored.
            let children = (layer.sublayers ?? []).map { ($0, $0.isHidden) }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer {
                for (child, hidden) in children { child.isHidden = hidden }
                CATransaction.commit()
            }
            for (child, _) in children { child.isHidden = true }
            data = render(layer, renderer: renderer, scale: scale, bounds: bounds)
        } else {
            data = render(layer, renderer: renderer, scale: scale, bounds: bounds)
        }
        guard !data.isEmpty else { return failure("screenshot_unavailable") }
        return Result(data: data, scale: Double(scale), pixelCount: width * height, failureReason: nil)
    }

    private static func render(_ layer: CALayer, renderer: UIGraphicsImageRenderer,
                               scale: CGFloat, bounds: CGRect) -> Data {
        renderer.pngData { context in
            // UIKit renderers already use top-left coordinates. A second y-flip
            // would invert the layer and its contents.
            context.cgContext.scaleBy(x: scale, y: scale)
            context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            layer.render(in: context.cgContext)
        }
    }

    private static func failure(_ reason: String) -> Result {
        Result(data: nil, scale: nil, pixelCount: 0, failureReason: reason)
    }
}
#endif
