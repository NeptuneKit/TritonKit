import Foundation
import CoreGraphics
import ObjectiveC

#if os(macOS)
/// Only read properties with an available getter. Unknown KVC keys can raise
/// Objective-C exceptions, which Swift optional casts and do/catch cannot catch.
enum AXGeometryPropertyReader {
    static func read(_ object: NSObject, key: String) -> Any? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        return object.value(forKey: key)
    }
}

struct AXFrameTransform: Equatable, Sendable {
    let rootFrame: CGRect
    let pointSize: CGSize

    init(rootFrame: CGRect, pointSize: CGSize) throws {
        guard Self.valid(rootFrame), Self.valid(pointSize),
              (pointSize.width / rootFrame.width).isFinite,
              pointSize.width / rootFrame.width > 0,
              ((pointSize.height - rootFrame.height * (pointSize.width / rootFrame.width)) / 2).isFinite else {
            throw HostSimulatorAXError.geometryUnavailable
        }
        self.rootFrame = rootFrame
        self.pointSize = pointSize
    }

    static func pointSize(pixelSize: CGSize, scale: Double) throws -> CGSize {
        guard valid(pixelSize), scale.isFinite, scale > 0 else { throw HostSimulatorAXError.geometryUnavailable }
        let result = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
        guard valid(result) else { throw HostSimulatorAXError.geometryUnavailable }
        return result
    }

    static func valid(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    static func valid(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite && valid(frame.size)
    }

    func map(_ macFrame: CGRect) throws -> CGRect {
        guard macFrame.origin.x.isFinite, macFrame.origin.y.isFinite, macFrame.width.isFinite, macFrame.height.isFinite, macFrame.size.width >= 0, macFrame.size.height >= 0 else { throw HostSimulatorAXError.geometryUnavailable }
        let scale = pointSize.width / rootFrame.width
        let yOffset = (pointSize.height - rootFrame.height * scale) / 2
        let result = CGRect(x: (macFrame.origin.x - rootFrame.origin.x) * scale,
                      y: (macFrame.origin.y - rootFrame.origin.y) * scale + yOffset,
                      width: macFrame.size.width * scale, height: macFrame.size.height * scale)
        guard result.origin.x.isFinite, result.origin.y.isFinite, result.width.isFinite, result.height.isFinite else { throw HostSimulatorAXError.geometryUnavailable }
        return result
    }

    func unmap(_ devicePoint: CGPoint) throws -> CGPoint {
        guard devicePoint.x.isFinite, devicePoint.y.isFinite else { throw HostSimulatorAXError.geometryUnavailable }
        let scale = pointSize.width / rootFrame.width
        let yOffset = (pointSize.height - rootFrame.height * scale) / 2
        let result = CGPoint(x: devicePoint.x / scale + rootFrame.origin.x,
                       y: (devicePoint.y - yOffset) / scale + rootFrame.origin.y)
        guard result.x.isFinite, result.y.isFinite else { throw HostSimulatorAXError.geometryUnavailable }
        return result
    }
}
#endif
