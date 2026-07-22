#if canImport(UIKit)
import Testing
import UIKit
@testable import TritonKit

@Suite(.serialized)
@MainActor
struct TKRuntimeScreenshotFormatTests {
    @Test("embedded runtime screenshot encodes PNG bytes and metadata")
    func embeddedRuntimeScreenshotEncodesPNG() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }

        let capture = makePNGScreenshotCapture(image: image, width: 2, height: 2, scale: 1)

        #expect(capture.format == "png")
        #expect(capture.width == 2)
        #expect(capture.height == 2)
        #expect(capture.scale == 1)
        #expect(capture.data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }
}
#endif
