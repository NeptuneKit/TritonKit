import CoreGraphics
import Foundation
import ImageIO
import TritonKitShared

enum VisualFeedbackError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { switch self { case .invalid(let message): return message } }
}

struct VisualRaster {
    let width: Int
    let height: Int
    let rgba: [UInt8]

    init(width: Int, height: Int, rgba: [UInt8]) throws {
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              rgba.count == width * height * 4 else {
            throw VisualFeedbackError.invalid("Invalid or oversized visual raster")
        }
        self.width = width
        self.height = height
        self.rgba = rgba
    }
}

struct VisualScreenshotFrame {
    let raster: VisualRaster
    let capturedAt: String
    let source: String
    let pixelWidth: Int
    let pixelHeight: Int
    let scale: Double?
}

func visualChangedAreaFraction(_ previous: VisualRaster, _ current: VisualRaster, pixelThreshold: Double) throws -> Double {
    guard pixelThreshold.isFinite, (0...1).contains(pixelThreshold) else {
        throw VisualFeedbackError.invalid("Pixel difference threshold must be finite and between 0 and 1")
    }
    guard previous.width == current.width, previous.height == current.height else { return 1 }
    let pixels = current.width * current.height
    var changed = 0
    for pixel in 0..<pixels {
        let offset = pixel * 4
        // Ignore alpha; decoded screenshots use an opaque background.
        let difference = max(abs(Int(previous.rgba[offset]) - Int(current.rgba[offset])),
                             max(abs(Int(previous.rgba[offset + 1]) - Int(current.rgba[offset + 1])),
                                 abs(Int(previous.rgba[offset + 2]) - Int(current.rgba[offset + 2]))))
        if Double(difference) / 255 > pixelThreshold { changed += 1 }
    }
    return Double(changed) / Double(pixels)
}

struct VisualSettleConfiguration: Codable, Equatable {
    let changeThreshold: Double
    let pixelThreshold: Double
    let stableWindow: Double
    let interval: Double
    let timeout: Double

    private enum CodingKeys: String, CodingKey { case changeThreshold, pixelThreshold, stableWindow, interval, timeout }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(changeThreshold: container.decodeIfPresent(Double.self, forKey: .changeThreshold) ?? 0.01,
                      pixelThreshold: container.decodeIfPresent(Double.self, forKey: .pixelThreshold) ?? 0.04,
                      stableWindow: container.decodeIfPresent(Double.self, forKey: .stableWindow) ?? 0.5,
                      interval: container.decodeIfPresent(Double.self, forKey: .interval) ?? 0.1,
                      timeout: container.decodeIfPresent(Double.self, forKey: .timeout) ?? 5)
    }

    init(changeThreshold: Double = 0.01, pixelThreshold: Double = 0.04, stableWindow: Double = 0.5, interval: Double = 0.1, timeout: Double = 5) throws {
        guard changeThreshold.isFinite, (0...1).contains(changeThreshold),
              pixelThreshold.isFinite, (0...1).contains(pixelThreshold),
              stableWindow.isFinite, (0.05...30).contains(stableWindow),
              interval.isFinite, (0.02...5).contains(interval),
              timeout.isFinite, (0.05...60).contains(timeout),
              stableWindow <= timeout, interval <= timeout else {
            throw VisualFeedbackError.invalid("Visual settle requires finite thresholds 0...1, window 0.05...30s, interval 0.02...5s, timeout 0.05...60s; window and interval must fit timeout")
        }
        self.changeThreshold = changeThreshold
        self.pixelThreshold = pixelThreshold
        self.stableWindow = stableWindow
        self.interval = interval
        self.timeout = timeout
    }
}

enum VisualSettleState: String, Codable { case settled, timeout, unknown }

struct VisualSettleOutput: Codable, Equatable {
    let ok: Bool
    let action: String
    let state: VisualSettleState
    let reason: String
    let businessVerified: Bool
    let elapsedMs: Int
    let sampleCount: Int
    let lastChangeFraction: Double?
    let capturedAt: String?
    let source: String?
    let configuration: VisualSettleConfiguration
    let comparisonPolicy: String
}

/// The screenshot provider receives the remaining deadline. Native provider cancellation is
/// cooperative; this function never pretends a blocked native collector was forcibly stopped.
func runVisualSettle(
    configuration: VisualSettleConfiguration,
    capture: (Double) async throws -> VisualScreenshotFrame,
    startedAt: TimeInterval? = nil,
    now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
    sleep: (Double) async throws -> Void = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
) async -> VisualSettleOutput {
    let start = startedAt ?? now()
    var previous: VisualScreenshotFrame?
    var stableSince: TimeInterval?
    var stableAnchor: VisualScreenshotFrame?
    var sampleCount = 0
    var lastChange: Double?

    func output(_ state: VisualSettleState, _ reason: String) -> VisualSettleOutput {
        VisualSettleOutput(ok: state == .settled, action: "observe.settle", state: state, reason: reason,
                          businessVerified: false, elapsedMs: max(0, Int((now() - start) * 1000)),
                          sampleCount: sampleCount, lastChangeFraction: lastChange,
                          capturedAt: previous?.capturedAt, source: previous?.source, configuration: configuration,
                          comparisonPolicy: "changed RGB pixel area on a raw-raster thumbnail of at most 384 pixels per axis")
    }

    while now() - start < configuration.timeout {
        let frame: VisualScreenshotFrame
        do {
            try Task.checkCancellation()
            frame = try await capture(configuration.timeout - (now() - start))
        } catch {
            return output(.unknown, "screenshot_unavailable")
        }
        let sampledAt = now()
        sampleCount += 1
        if sampledAt - start >= configuration.timeout {
            previous = frame
            return output(.unknown, "screenshot_deadline_exceeded")
        }
        if let previous {
            do {
                let sameGeometry = previous.pixelWidth == frame.pixelWidth && previous.pixelHeight == frame.pixelHeight && previous.scale == frame.scale
                lastChange = sameGeometry ? try visualChangedAreaFraction(previous.raster, frame.raster, pixelThreshold: configuration.pixelThreshold) : 1
            } catch {
                return output(.unknown, "screenshot_comparison_failed")
            }
            if let lastChange, lastChange <= configuration.changeThreshold {
                // A slowly moving surface may change only a few pixels per frame. Compare
                // against the window's first frame as well, so cumulative motion resets it.
                if let anchor = stableAnchor {
                    let sameGeometry = anchor.pixelWidth == frame.pixelWidth && anchor.pixelHeight == frame.pixelHeight && anchor.scale == frame.scale
                    let anchorChange: Double? = sameGeometry ? (try? visualChangedAreaFraction(anchor.raster, frame.raster, pixelThreshold: configuration.pixelThreshold)) : 1
                    if anchorChange == nil || (anchorChange ?? 1) > configuration.changeThreshold {
                        stableSince = nil
                        stableAnchor = nil
                    }
                }
                if stableSince == nil { stableSince = sampledAt; stableAnchor = frame }
            } else {
                stableSince = nil
                stableAnchor = nil
            }
        }
        previous = frame
        if let stableSince, sampledAt - stableSince + 0.000001 >= configuration.stableWindow {
            return output(.settled, "visual_stable_window")
        }
        do {
            try await sleep(min(configuration.interval, max(0, configuration.timeout - (now() - start))))
        } catch {
            return output(.unknown, "observation_cancelled")
        }
    }
    return sampleCount < 2 ? output(.unknown, "insufficient_visual_samples") : output(.timeout, "visual_motion_timeout")
}

func visualImageSource(_ data: Data) throws -> (CGImageSource, Int, Int) {
    guard data.count <= 64 * 1024 * 1024,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 16000, height <= 16000,
          width * height <= 40_000_000 else {
        throw VisualFeedbackError.invalid("Screenshot is malformed or exceeds 64 MiB / 40 million pixels")
    }
    return (source, width, height)
}

func visualScreenshotFrame(data: Data, capturedAt: String, source: String, scale: Double?) throws -> VisualScreenshotFrame {
    let (imageSource, pixelWidth, pixelHeight) = try visualImageSource(data)
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                  kCGImageSourceThumbnailMaxPixelSize: 384,
                                  kCGImageSourceCreateThumbnailWithTransform: false]
    guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
        throw VisualFeedbackError.invalid("Cannot decode screenshot")
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let decoded = bytes.withUnsafeMutableBytes { storage -> Bool in
        guard let context = CGContext(data: storage.baseAddress, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    guard decoded else { throw VisualFeedbackError.invalid("Cannot allocate screenshot comparison raster") }
    return VisualScreenshotFrame(raster: try VisualRaster(width: image.width, height: image.height, rgba: bytes),
                                 capturedAt: capturedAt, source: source, pixelWidth: pixelWidth, pixelHeight: pixelHeight, scale: scale)
}
