import CoreGraphics
import Foundation
import Hummingbird
import HummingbirdTesting
import ImageIO
import Testing
@testable import TritonKitCLI

@Suite("Encoded framebuffer formats", .serialized)
struct FramebufferPNGStreamingTests {
    @Test func androidPreservesPNGBytesAndVersionWithoutJPEGConversion() async throws {
        let fixture = try EncodedFramebufferFixture()
        defer { fixture.remove() }
        let session = AndroidSession(serial: "fixture", adbPath: fixture.adb.path)
        defer { session.stop() }
        session.start()
        let frame = try await awaitEncodedFrame(session)
        #expect(session.imageFormat == .png)
        #expect(frame.0 == fixture.png)
        #expect(frame.1 == 1)
        try await awaitCaptureCount(fixture, atLeast: 3)
        #expect(session.getLatestFrameWithVersion()?.1 == 1, "Repeated identical PNG must not publish another version")
        session.stop()
        #expect(!session.running)
        #expect(session.getLatestFrameWithVersion() == nil)
        #expect(frame.0 == fixture.png, "An acquired frame remains valid after session cleanup")
    }

    @Test func androidSubscribersSharePNGAndLastReleaseClearsCapture() async throws {
        let fixture = try EncodedFramebufferFixture()
        defer { fixture.remove() }
        let service = CLIAndroidFramebufferService()
        let first = service.subscribe(serial: "fixture", adbPath: fixture.adb.path)
        let second = service.subscribe(serial: "fixture", adbPath: fixture.adb.path)
        defer { first.cancel(); second.cancel() }
        #expect(first.session === second.session)
        let frame = try await awaitEncodedFrame(first.session)
        #expect(frame.0 == fixture.png)
        first.cancel()
        #expect(second.session.running)
        #expect(second.session.getLatestFrameWithVersion()?.0 == fixture.png)
        second.cancel()
        #expect(!second.session.running)
        #expect(second.session.getLatestFrameWithVersion() == nil)
    }

    @Test(arguments: ["text", "jpeg", "truncated", "missing-iend", "trailing-bytes", "oversized-chunk"])
    func invalidAndroidOutputIsNeverPublishedAsPNG(kind: String) async throws {
        let fixture = try EncodedFramebufferFixture()
        defer { fixture.remove() }
        let invalid: Data
        switch kind {
        case "jpeg": invalid = fixture.jpeg
        case "truncated": invalid = Data(fixture.png.prefix(40))
        case "missing-iend": invalid = Data(fixture.png.dropLast(12))
        case "trailing-bytes": invalid = fixture.png + Data("unexpected trailing data".utf8)
        case "oversized-chunk":
            var bytes = fixture.png
            bytes.replaceSubrange(8..<12, with: [0xff, 0xff, 0xff, 0xff])
            invalid = bytes
        default: invalid = Data("adb: capture failed\n".utf8)
        }
        try fixture.replaceAndroidOutput(invalid)
        let session = AndroidSession(serial: "fixture", adbPath: fixture.adb.path)
        defer { session.stop() }
        session.start()
        try await awaitCaptureCount(fixture, atLeast: 2)
        #expect(session.getLatestFrameWithVersion() == nil)
        session.stop()
        #expect(session.getLatestFrameWithVersion() == nil)
    }

    @Test func invalidCaptureKeepsLastValidPNGWithoutIncrementingVersion() async throws {
        let fixture = try EncodedFramebufferFixture()
        defer { fixture.remove() }
        let session = AndroidSession(serial: "fixture", adbPath: fixture.adb.path)
        defer { session.stop() }
        session.start()
        let valid = try await awaitEncodedFrame(session)
        try fixture.replaceAndroidOutput(fixture.jpeg)
        try await awaitCaptureCount(fixture, atLeast: fixture.captureCount + 3)
        #expect(session.getLatestFrameWithVersion()?.0 == fixture.png)
        #expect(session.getLatestFrameWithVersion()?.1 == valid.1)
    }

    @Test(arguments: ["android", "harmony"], ["direct", "packaged"])
    func multipartPartMIMEMatchesActualEncodedBytes(platform: String, route: String) async throws {
        let fixture = try EncodedFramebufferFixture()
        defer { fixture.remove() }
        let base: any FramebufferCaptureSession = platform == "android"
            ? AndroidSession(serial: "fixture", adbPath: fixture.adb.path)
            : HarmonySession(target: "fixture", hdcPath: fixture.hdc.path)
        defer { base.stop() }
        base.start()
        let frame = try await awaitEncodedFrame(base)
        let capture = OneEncodedFrame(base: base, frame: frame)
        let subscription = FramebufferStreamSubscription(session: capture) { capture.stop(); base.stop() }
        let router = Router()
        let endpoint: String
        if route == "packaged" {
            endpoint = "/web/\(platform)/mjpeg"
            registerPackagedWebFramebufferRoutes(on: router, dependencies: PackagedWebDependencies(
                resolveTarget: { _, target, _, _ in target },
                subscribeAndroid: { _, _ in subscription },
                subscribeHarmony: { _, _ in subscription }
            ))
        } else {
            // The direct routes use this same response writer after target resolution.
            endpoint = "/web/\(platform)/framebuffer"
            router.get(RouterPath(endpoint)) { request, _ in
                framebufferStreamingResponse(request: request, framesPerSecond: 30) { subscription }
            }
        }
        let bytes = platform == "android" ? fixture.png : fixture.jpeg
        let mime = platform == "android" ? "image/png" : "image/jpeg"
        try await Application(router: router).test(.router) { client in
            let response = try await client.execute(uri: "\(endpoint)?target=fixture", method: .get)
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "multipart/x-mixed-replace; boundary=tritonboundary")
            var expected = Data("--tritonboundary\r\nContent-Type: \(mime)\r\nContent-Length: \(bytes.count)\r\n\r\n".utf8)
            expected.append(bytes)
            expected.append(Data("\r\n".utf8))
            #expect(Data(buffer: response.body) == expected)
        }
        #expect(!base.running)
        #expect(base.getLatestFrameWithVersion() == nil)
    }

    @Test func existingCaptureSessionsDefaultToJPEG() {
        let fixture = DefaultJPEGFormatCapture()
        #expect(fixture.imageFormat == .jpeg)
        #expect(HarmonySession(target: "fixture", hdcPath: "/unused").imageFormat == .jpeg)
    }
}

private final class OneEncodedFrame: FramebufferCaptureSession, @unchecked Sendable {
    let base: any FramebufferCaptureSession
    let frame: (Data, UInt64)
    private let lock = NSLock()
    private var active = true
    init(base: any FramebufferCaptureSession, frame: (Data, UInt64)) { self.base = base; self.frame = frame }
    var imageFormat: FramebufferImageFormat { base.imageFormat }
    var running: Bool { lock.withLock { active } }
    func start() {}
    func stop() { lock.withLock { active = false } }
    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        lock.withLock { guard active else { return nil }; active = false; return frame }
    }
}

private final class DefaultJPEGFormatCapture: FramebufferCaptureSession, @unchecked Sendable {
    var running: Bool { false }
    func start() {}
    func stop() {}
    func getLatestFrameWithVersion() -> (Data, UInt64)? { nil }
}

private func awaitEncodedFrame(_ session: any FramebufferCaptureSession) async throws -> (Data, UInt64) {
    for _ in 0..<300 {
        if let frame = session.getLatestFrameWithVersion() { return frame }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw RuntimeError("Fixture capture did not publish a frame within three seconds")
}

private func awaitCaptureCount(_ fixture: EncodedFramebufferFixture, atLeast count: Int) async throws {
    for _ in 0..<300 {
        if fixture.captureCount >= count { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw RuntimeError("Fixture capture count did not reach \(count)")
}

private struct EncodedFramebufferFixture: Sendable {
    let directory: URL
    let adb: URL
    let hdc: URL
    let png: Data
    let jpeg: Data

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-encoded-frame-\(UUID().uuidString)")
        adb = directory.appendingPathComponent("adb")
        hdc = directory.appendingPathComponent("hdc")
        png = try Self.image(type: "public.png")
        jpeg = try Self.image(type: "public.jpeg")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try png.write(to: directory.appendingPathComponent("frame.png"))
        try jpeg.write(to: directory.appendingPathComponent("frame.jpeg"))
        try """
        #!/bin/sh
        fixture_dir=$(/usr/bin/dirname "$0")
        printf 'capture\\n' >> "$fixture_dir/captures"
        exec /bin/cat "$fixture_dir/frame.png"
        """.write(to: adb, atomically: true, encoding: .utf8)
        try """
        #!/bin/sh
        fixture_dir=$(/usr/bin/dirname "$0")
        case "$3:$4" in
          shell:snapshot_display) ;;
          file:recv) /bin/cp "$fixture_dir/frame.jpeg" "$6" ;;
          shell:rm) printf cleanup > "$fixture_dir/cleanup" ;;
          *) exit 2 ;;
        esac
        """.write(to: hdc, atomically: true, encoding: .utf8)
        for helper in [adb, hdc] { try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path) }
    }

    var captureCount: Int {
        ((try? String(contentsOf: directory.appendingPathComponent("captures"), encoding: .utf8)) ?? "").split(separator: "\n").count
    }
    func replaceAndroidOutput(_ data: Data) throws { try data.write(to: directory.appendingPathComponent("frame.png"), options: .atomic) }
    func remove() { try? FileManager.default.removeItem(at: directory) }

    private static func image(type: String) throws -> Data {
        let context = try #require(CGContext(data: nil, width: 6, height: 4, bitsPerComponent: 8, bytesPerRow: 24,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.1, green: 0.7, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 6, height: 4))
        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 2))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data as CFMutableData, type as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
