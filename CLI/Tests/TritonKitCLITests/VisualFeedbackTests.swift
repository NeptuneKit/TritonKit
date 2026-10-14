import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct VisualFeedbackTests {
    @Test("repeated screenshot sampling honors the host artifact no-overwrite contract")
    func repeatedScreenshotCapturePaths() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = visualScreenshotCapturePath(in: directory)
        try prepareHostArtifactOutputPath(first)
        try Data([1]).write(to: URL(fileURLWithPath: first))
        let second = visualScreenshotCapturePath(in: directory)
        try prepareHostArtifactOutputPath(second)
        #expect(first != second)
        #expect(try Data(contentsOf: URL(fileURLWithPath: first)) == Data([1]))
    }
    @Test("visual CLI parses explicit image policy and host settle budgets")
    func commandParsing() throws {
        let ocr = try ObserveOCR.parse(["--image", "fixture.png", "--policy", "structure-unavailable", "--structure-unavailable-reason", "ax_unavailable", "--minimum-confidence", "0.7", "--scale", "2", "--json"])
        #expect(ocr.image == "fixture.png")
        #expect(ocr.policy == .structureUnavailable)
        #expect(ocr.minimumConfidence == 0.7)
        #expect(ocr.scale == 2)
        let settle = try ObserveSettle.parse(["--device", "sim:fixture", "--platform", "ios", "--scope", "simulator", "--stable-window", "0.5", "--timeout", "2", "--json"])
        #expect(settle.device == "sim:fixture")
        #expect(settle.scope == .simulator)
        #expect(settle.timeout == 2)
    }

    @Test("visual difference measures changed area rather than exact hashes")
    func differenceArea() throws {
        let unchanged = try VisualRaster(width: 10, height: 10, rgba: [UInt8](repeating: 0, count: 400))
        var bytes = unchanged.rgba
        for pixel in 0..<10 { bytes[pixel * 4] = 255 }
        let changed = try VisualRaster(width: 10, height: 10, rgba: bytes)
        #expect(try visualChangedAreaFraction(unchanged, changed, pixelThreshold: 0.04) == 0.1)
        bytes = unchanged.rgba
        bytes[0] = 1
        #expect(try visualChangedAreaFraction(unchanged, VisualRaster(width: 10, height: 10, rgba: bytes), pixelThreshold: 0.04) == 0)
    }

    @Test("dimension changes are visual changes even if sampled pixel data matches")
    func dimensionChanges() throws {
        let first = try VisualRaster(width: 1, height: 2, rgba: [UInt8](repeating: 0, count: 8))
        let second = try VisualRaster(width: 2, height: 1, rgba: [UInt8](repeating: 0, count: 8))
        #expect(try visualChangedAreaFraction(first, second, pixelThreshold: 0.04) == 1)
    }

    @Test("settle requires consecutive stable frames for the entire window")
    func stableWindow() async throws {
        let clock = VisualFixtureClock()
        let frames = VisualFixtureFrames([try visualFixtureFrame(0), try visualFixtureFrame(255), try visualFixtureFrame(255)])
        let result = await runVisualSettle(
            configuration: try VisualSettleConfiguration(changeThreshold: 0.01, pixelThreshold: 0.04, stableWindow: 0.2, interval: 0.1, timeout: 1),
            capture: { _ in try frames.next() }, now: { clock.time }, sleep: { clock.time += $0 }
        )
        #expect(result.state == .settled)
        #expect(result.sampleCount >= 4)
        #expect(result.elapsedMs >= 300)
        #expect(!result.businessVerified)
    }

    @Test("continuous visual motion times out without business verification")
    func continuousMotion() async throws {
        let clock = VisualFixtureClock()
        let frames = VisualFixtureFrames([try visualFixtureFrame(0), try visualFixtureFrame(255)], repeating: true)
        let result = await runVisualSettle(
            configuration: try VisualSettleConfiguration(stableWindow: 0.2, interval: 0.1, timeout: 0.5),
            capture: { _ in try frames.next() }, now: { clock.time }, sleep: { clock.time += $0 }
        )
        #expect(result.state == .timeout)
        #expect(result.reason == "visual_motion_timeout")
        #expect(!result.ok)
        #expect(!result.businessVerified)
    }

    @Test("small per-frame changes cannot hide accumulated drift across the stable window")
    func accumulatedDrift() async throws {
        let clock = VisualFixtureClock()
        var generation = 0
        let result = await runVisualSettle(configuration: try VisualSettleConfiguration(changeThreshold: 0.11, pixelThreshold: 0.04, stableWindow: 0.3, interval: 0.1, timeout: 0.8), capture: { _ in
            var rgba = [UInt8](repeating: 0, count: 40)
            for pixel in 0..<min(10, generation) { rgba[pixel * 4] = 255 }
            generation += 1
            return VisualScreenshotFrame(raster: try VisualRaster(width: 10, height: 1, rgba: rgba), capturedAt: "fixture", source: "fixture", pixelWidth: 10, pixelHeight: 1, scale: nil)
        }, now: { clock.time }, sleep: { clock.time += $0 })
        #expect(result.state == .timeout)
        #expect(!result.businessVerified)
    }

    @Test("screenshot failure becomes unknown and never settled")
    func captureFailure() async throws {
        let result = await runVisualSettle(configuration: try VisualSettleConfiguration(), capture: { _ in
            throw RuntimeError("fixture capture failed")
        })
        #expect(result.state == .unknown)
        #expect(result.reason == "screenshot_unavailable")
        #expect(!result.businessVerified)
    }

    @Test("a stale comparison result cannot settle after its screenshot deadline")
    func lateCapture() async throws {
        let clock = VisualFixtureClock()
        let frame = try visualFixtureFrame(0)
        let result = await runVisualSettle(configuration: try VisualSettleConfiguration(stableWindow: 0.2, timeout: 0.5), capture: { _ in
            clock.time += 0.6
            return frame
        }, now: { clock.time }, sleep: { clock.time += $0 })
        #expect(result.state == .unknown)
        #expect(result.reason == "screenshot_deadline_exceeded")
    }

    @Test("settle options reject NaN, unlimited waits and impossible sampling windows")
    func finiteOptions() throws {
        #expect(throws: VisualFeedbackError.self) { try VisualSettleConfiguration(changeThreshold: .nan) }
        #expect(throws: VisualFeedbackError.self) { try VisualSettleConfiguration(timeout: .infinity) }
        #expect(throws: VisualFeedbackError.self) { try VisualSettleConfiguration(interval: 0) }
        #expect(throws: VisualFeedbackError.self) { try VisualSettleConfiguration(stableWindow: 2, timeout: 1) }
        #expect(throws: VisualFeedbackError.self) { try VisualSettleConfiguration(interval: 5, timeout: 1) }
        #expect(throws: VisualFeedbackError.self) { try JSONDecoder().decode(VisualSettleConfiguration.self, from: Data("{\"timeout\":-1}".utf8)) }
    }

    @Test("provider setup and capture time count toward the same deadline")
    func setupCountsTowardDeadline() async throws {
        let clock = VisualFixtureClock()
        clock.time = 0.4
        let frame = try visualFixtureFrame(0)
        let result = await runVisualSettle(configuration: try VisualSettleConfiguration(stableWindow: 0.1, timeout: 0.5), capture: { remaining in
            #expect(remaining <= 0.100001)
            clock.time += 0.2
            return frame
        }, startedAt: 0, now: { clock.time }, sleep: { clock.time += $0 })
        #expect(result.state == .unknown)
        #expect(result.reason == "screenshot_deadline_exceeded")
        #expect(result.elapsedMs >= 600)
        #expect(result.sampleCount == 1)
    }

    @Test("OCR maps Vision bottom-left boxes to top-left pixels and optional points")
    func coordinateMapping() throws {
        let bounds = try visualOCRBounds(normalized: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1), pixelWidth: 1000, pixelHeight: 2000, scale: 2)
        #expect(abs(bounds.pixels.x - 100) < 0.0001)
        #expect(abs(bounds.pixels.y - 1400) < 0.0001)
        #expect(bounds.points?.width == 150)
        #expect(abs((bounds.points?.y ?? 0) - 700) < 0.0001)
        #expect(try visualOCRBounds(normalized: .zero, pixelWidth: 100, pixelHeight: 100, scale: nil).points == nil)
        #expect(throws: VisualFeedbackError.self) { try visualOCRBounds(normalized: .zero, pixelWidth: 100, pixelHeight: 100, scale: 0) }
        #expect(throws: VisualFeedbackError.self) { try visualOCRBounds(normalized: CGRect(x: -1, y: 0, width: 1, height: 1), pixelWidth: 100, pixelHeight: 100, scale: nil) }
    }

    @Test("OCR candidates remain nonsemantic and have no object identifier")
    func candidateContract() throws {
        let node = VisualOCRCandidate(text: "Fixture", confidence: 0.8, framePixels: TKRect(x: 1, y: 2, width: 3, height: 4), framePoints: nil)
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(node)) as? [String: Any])
        #expect(object["candidateOnly"] as? Bool == true)
        #expect(object["source"] as? String == "host-vision-ocr")
        #expect(object["targetOID"] == nil)
        #expect(object["nodeID"] == nil)
    }

    @Test("structure-unavailable fallback must carry an explicit reason")
    func policyValidation() throws {
        #expect(throws: VisualFeedbackError.self) { try validateVisualOCRPolicy(.structureUnavailable, reason: nil) }
        try validateVisualOCRPolicy(.structureUnavailable, reason: "ax_unavailable")
        try validateVisualOCRPolicy(.explicit, reason: nil)
    }

    @Test("host Vision recognizes a generated screenshot and reports bounded coordinates")
    func visionImageFixture() throws {
        let data = try visualTextImageFixture()
        let output = try recognizeVisualText(data: data, capturedAt: "fixture", screenshotSource: "fixture", scale: 2, minimumConfidence: 0)
        #expect(output.candidates.contains { $0.text.contains("TRITON PROBE 192") })
        #expect(output.coordinates.pixelWidth == 900)
        #expect(output.coordinates.pixelHeight == 200)
        #expect(output.coordinates.pointsAvailable)
        #expect(output.coordinates.appliedRotationDegrees == 0)
        for candidate in output.candidates {
            #expect(candidate.framePixels.x >= 0)
            #expect(candidate.framePixels.y >= 0)
            #expect(candidate.framePixels.x + candidate.framePixels.width <= 900.001)
            #expect(candidate.framePixels.y + candidate.framePixels.height <= 200.001)
            #expect(candidate.candidateOnly)
        }
        let frame = try visualScreenshotFrame(data: data, capturedAt: "fixture", source: "fixture", scale: 2)
        #expect(frame.raster.width <= 384)
        #expect(frame.raster.height <= 384)
        #expect(frame.pixelWidth == 900)
    }

    @Test("local image modification time is not claimed to be screenshot capture freshness")
    func localFileFreshness() throws {
        let output = try recognizeVisualText(data: visualTextImageFixture(), capturedAt: "2020-01-01T00:00:00Z", screenshotSource: "image-file-modification-time")
        #expect(output.freshness == "unknown")
        #expect(output.captureTimeSource == "file-modification-time-not-capture")
    }
}

private final class VisualFixtureClock {
    var time: TimeInterval = 0
}

private final class VisualFixtureFrames {
    private var index = 0
    let frames: [VisualScreenshotFrame]
    let repeating: Bool
    init(_ frames: [VisualScreenshotFrame], repeating: Bool = false) { self.frames = frames; self.repeating = repeating }
    func next() throws -> VisualScreenshotFrame {
        defer { index += 1 }
        return frames[repeating ? index % frames.count : min(index, frames.count - 1)]
    }
}

private func visualFixtureFrame(_ value: UInt8) throws -> VisualScreenshotFrame {
    let rgba: [UInt8] = [value, value, value, 255]
    return VisualScreenshotFrame(raster: try VisualRaster(width: 1, height: 1, rgba: rgba), capturedAt: "fixture", source: "fixture", pixelWidth: 1, pixelHeight: 1, scale: nil)
}

private func visualTextImageFixture() throws -> Data {
    let context = try #require(CGContext(data: nil, width: 900, height: 200, bitsPerComponent: 8, bytesPerRow: 900 * 4,
                                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 900, height: 200))
    let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 56, nil),
                                                   NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "TRITON PROBE 192", attributes: attributes) as CFAttributedString)
    context.textPosition = CGPoint(x: 35, y: 80)
    CTLineDraw(line, context)
    let image = try #require(context.makeImage())
    let bytes = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(bytes as CFMutableData, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return bytes as Data
}
