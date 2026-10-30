import Foundation
import Hummingbird
import TritonKitShared

struct PackagedWebDependencies: Sendable {
    var adbPath = findAdbExecutable()
    var hdcPath = findHdcExecutable()
    var hostTargets: @Sendable (String, String) -> [HostDeviceTarget] = { hdc, adb in
        discoverWebHostDeviceTargets(hdc: hdc, adb: adb)
    }
    var runtimeTargets: @Sendable () async -> [TKTargetSummary] = {
        ((try? await TritonKitHTTPClient(host: "127.0.0.1", port: 19421).getJSON("/targets")) as TKTargetsResponse?)?.targets ?? []
    }
    var resolveTarget: @Sendable (HostDevicePlatform, String, String, String) throws -> String = { platform, target, hdc, adb in
        try resolvePackagedWebFramebufferTarget(platform: platform, target: target, hdc: hdc, adb: adb)
    }
    var iosFramebuffer = PackagedWebIOSFramebufferDependencies()
    var subscribeAndroid: @Sendable (String, String) -> FramebufferStreamSubscription = { target, adb in
        CLIAndroidFramebufferService.shared.subscribe(serial: target, adbPath: adb)
    }
    var subscribeHarmony: @Sendable (String, String) -> FramebufferStreamSubscription = { target, hdc in
        CLIHarmonyFramebufferService.shared.subscribe(target: target, hdcPath: hdc)
    }
}

struct PackagedWebFramebufferRequest: Equatable {
    let target: String
    let fps: Int
}

func makePackagedWebFramebufferRequest(platform: HostDevicePlatform, target: String?, serial: String?, udid: String?, fps: String?) throws -> PackagedWebFramebufferRequest {
    guard var target = [target, serial, udid].compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) else {
        throw RuntimeError("Missing target, serial, or udid parameter.")
    }
    if target.hasPrefix("host:") {
        guard let hostTarget = parseWebHostTargetID(target), hostTarget.platform == platform else {
            throw RuntimeError("Target does not identify a \(platform.rawValue) device.")
        }
        target = hostTarget.selector.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard !target.isEmpty, target.rangeOfCharacter(from: .controlCharacters) == nil else {
        throw RuntimeError("Target must be a nonempty device selector without control characters.")
    }
    let requestedFps: Int
    if let fps {
        guard let value = Int(fps) else { throw RuntimeError("fps must be an integer.") }
        requestedFps = value
    } else {
        requestedFps = platform == .android ? 15 : 10
    }
    return PackagedWebFramebufferRequest(target: target, fps: min(platform == .android ? 30 : 15, max(1, requestedFps)))
}

func resolvePackagedWebFramebufferTarget(platform: HostDevicePlatform, target: String, hdc: String, adb: String) throws -> String {
    try resolveFramebufferTarget(platform: platform, target: target, hdc: hdc, adb: adb, liveCurrentResolver: {
        try resolveHostDeviceSelection(request: .init(device: "current", platform: platform), hdc: hdc, adb: adb)
    })
}

func registerPackagedWebFramebufferRoutes<Context: RequestContext>(on router: Router<Context>, dependencies: PackagedWebDependencies) {
    for platform in [HostDevicePlatform.android, .harmony] {
        let endpoint = "/web/\(platform.rawValue)/mjpeg"
        router.get(RouterPath(endpoint)) { request, _ -> Response in
            do {
                let stream = try makePackagedWebFramebufferRequest(
                    platform: platform,
                    target: request.uri.queryParameters.get("target"),
                    serial: request.uri.queryParameters.get("serial"),
                    udid: request.uri.queryParameters.get("udid"),
                    fps: request.uri.queryParameters.get("fps")
                )
                let target = try dependencies.resolveTarget(platform, stream.target, dependencies.hdcPath, dependencies.adbPath)
                return framebufferStreamingResponse(request: request, framesPerSecond: stream.fps) {
                    switch platform {
                    case .android: return dependencies.subscribeAndroid(target, dependencies.adbPath)
                    case .harmony: return dependencies.subscribeHarmony(target, dependencies.hdcPath)
                    case .ios: preconditionFailure("iOS has its own framebuffer route")
                    }
                }
            } catch {
                return jsonError(code: "invalid_query", message: "\(error)", endpoint: endpoint, status: .badRequest)
            }
        }
    }
}

struct PackagedWebIOSFramebufferDependencies: Sendable {
    var validateCapture: @Sendable (String) throws -> Void = { try assertIOSSimulatorResizeCaptureAllowed(target: $0) }
    var start: @Sendable (String) -> Bool = { CLIHostSimulatorFramebufferService.shared.startStreaming(udid: $0) }
    var stop: @Sendable (String) -> Void = { CLIHostSimulatorFramebufferService.shared.stopStreaming(udid: $0) }
    var running: @Sendable (String) -> Bool = { _ in true }
    var frame: @Sendable (String) -> (Data, UInt64)? = { CLIHostSimulatorFramebufferService.shared.getLatestFrameWithVersion(udid: $0) }
}

func makePackagedWebIOSSimulatorMjpegResponse(
    _ streamRequest: PackagedWebIOSSimulatorMjpegRequest,
    request: Request,
    capture: PackagedWebIOSFramebufferDependencies = .init()
) -> Response {
    do { try capture.validateCapture(streamRequest.udid) }
    catch let error as IOSSimulatorResizeCaptureError {
        return jsonError(code: error.detail.code, message: error.detail.message, endpoint: "/web/ios-simulator/mjpeg", hint: error.detail.hint, status: .conflict)
    } catch {
        return jsonError(code: "ios_simulator_resize_capture_state_unknown", message: "Capture routing could not be verified.", endpoint: "/web/ios-simulator/mjpeg", status: .conflict)
    }

    guard let subscription = startIOSFramebufferSubscription(target: streamRequest.udid, capture: capture) else {
        return jsonError(
            code: "web_ios_simulator_mjpeg_unavailable",
            message: "Unable to start host framebuffer streaming for simulator \(streamRequest.udid).",
            endpoint: "/web/ios-simulator/mjpeg",
            hint: "Verify the simulator is booted and available with `triton sim list --json`.",
            status: .conflict
        )
    }

    return framebufferStreamingResponse(request: request, framesPerSecond: streamRequest.fps) { subscription }
}

/// Start synchronously so routes preserve their startup-failure response, while
/// owning a successful reference even if the HTTP response body never executes.
func startIOSFramebufferSubscription(
    target: String,
    capture: PackagedWebIOSFramebufferDependencies
) -> FramebufferStreamSubscription? {
    guard capture.start(target) else { return nil }
    let session = PackagedWebIOSFramebufferSession(target: target, capture: capture)
    return FramebufferStreamSubscription(session: session) { session.stop() }
}

private final class PackagedWebIOSFramebufferSession: FramebufferCaptureSession, @unchecked Sendable {
    private let lock = NSLock()
    private var active = true
    private let target: String
    private let capture: PackagedWebIOSFramebufferDependencies

    init(target: String, capture: PackagedWebIOSFramebufferDependencies) {
        self.target = target
        self.capture = capture
    }

    var running: Bool { lock.withLock { active } && capture.running(target) }
    // The native capture was already acquired by the synchronous startup guard.
    func start() {}
    func stop() {
        let release = lock.withLock {
            guard active else { return false }
            active = false
            return true
        }
        if release { capture.stop(target) }
    }
    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        running ? capture.frame(target) : nil
    }
}
