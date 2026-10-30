import Foundation
import Hummingbird
import NIOCore
import TritonKitShared

struct PackagedWebStaticResponse: Equatable {
    let data: Data
    let contentType: String
}

struct PackagedWebIOSSimulatorMjpegRequest: Equatable {
    let udid: String
    let fps: Int
    let targetIntervalSeconds: Double
    let boundary: String
}

func makePackagedWebIOSSimulatorMjpegRequest(
    target: String?,
    udid: String?,
    fps: String?
) throws -> PackagedWebIOSSimulatorMjpegRequest {
    guard let rawTarget = [target, udid].compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) else {
        throw RuntimeError("Missing target or udid parameter.")
    }
    let resolvedUDID: String
    if rawTarget.hasPrefix("host:ios:") {
        resolvedUDID = String(rawTarget.dropFirst("host:ios:".count))
    } else if rawTarget.hasPrefix("triton:ios-simulator:") {
        resolvedUDID = String(rawTarget.dropFirst("triton:ios-simulator:".count))
    } else {
        resolvedUDID = rawTarget
    }
    let requestedFps = fps.flatMap(Int.init) ?? 15
    let normalizedFps = min(120, max(1, requestedFps))
    return PackagedWebIOSSimulatorMjpegRequest(
        udid: resolvedUDID,
        fps: normalizedFps,
        targetIntervalSeconds: Double(1000 / normalizedFps) / 1000.0,
        boundary: "tritonboundary"
    )
}

func makePackagedWebStaticResponse(webRoot: String, requestPath: String) throws -> PackagedWebStaticResponse {
    let root = URL(fileURLWithPath: webRoot, isDirectory: true).standardizedFileURL
    guard isValidBundledWebRoot(root) else {
        throw WebCommandError.bundledWebRootNotFound(path: webRoot)
    }

    let decodedPath = (requestPath.removingPercentEncoding ?? requestPath)
    let trimmed = decodedPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? decodedPath
    var relative = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if relative.isEmpty {
        relative = "index.html"
    }
    let components = relative.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    let hasTraversal = components.contains { $0 == "." || $0 == ".." }
    let candidate = root.appendingPathComponent(components.joined(separator: "/")).standardizedFileURL
    let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
    let isInsideRoot = candidate.path == root.path || candidate.path.hasPrefix(rootPath)
    let selected: URL
    if !hasTraversal,
       isInsideRoot,
       FileManager.default.fileExists(atPath: candidate.path),
       (try? candidate.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true {
        selected = candidate
    } else {
        selected = root.appendingPathComponent("index.html")
    }

    return PackagedWebStaticResponse(
        data: try Data(contentsOf: selected),
        contentType: packagedWebStaticContentType(path: selected.path)
    )
}

func packagedWebStaticContentType(path: String) -> String {
    switch URL(fileURLWithPath: path).pathExtension.lowercased() {
    case "html":
        return "text/html; charset=utf-8"
    case "css":
        return "text/css; charset=utf-8"
    case "js", "mjs":
        return "text/javascript; charset=utf-8"
    case "json":
        return "application/json; charset=utf-8"
    case "svg":
        return "image/svg+xml"
    case "png":
        return "image/png"
    case "jpg", "jpeg":
        return "image/jpeg"
    case "webp":
        return "image/webp"
    case "ico":
        return "image/x-icon"
    case "woff":
        return "font/woff"
    case "woff2":
        return "font/woff2"
    default:
        return "application/octet-stream"
    }
}

func webHostLogsUnsupportedResponse(platform: String) -> TKCLIErrorResponse {
    TKCLIErrorResponse(error: TKCLIErrorDetail(
        code: "web_host_logs_platform_not_supported",
        message: "Host logs are only exposed for iOS Simulator in the bundled Web bridge; requested platform: \(platform).",
        endpoint: "/web/host-logs",
        hint: "Use CLI-native platform log commands for Android or Harmony when they are available."
    ))
}

func webReadonlyWriteResponse(endpoint: String) -> TKCLIErrorResponse {
    let code: String
    let hint: String
    switch endpoint {
    case "/web/host-input":
        code = "web_host_input_readonly"
        hint = "Use `triton act … --json` or another explicit CLI control command for the selected target."
    case "/web/node-property":
        code = "web_node_property_readonly"
        hint = "Use `triton debug patch-node … --json` for an explicit, auditable node patch."
    case "/web/input":
        code = "web_input_readonly"
        hint = "Use `triton act … --json` or the explicit runtime HTTP control contract."
    default:
        code = "web_write_readonly"
        hint = "Use an explicit Triton CLI or HTTP control contract instead."
    }
    return TKCLIErrorResponse(error: TKCLIErrorDetail(
        code: code,
        message: "Triton Web is a readonly device hub and does not execute browser write actions.",
        endpoint: endpoint,
        hint: hint
    ))
}

func registerWebReadonlyPostRoute<Context: RequestContext>(
    on router: Router<Context>,
    endpoint: String
) {
    router.post(RouterPath(endpoint)) { _, _ -> Response in
        jsonResponse(webReadonlyWriteResponse(endpoint: endpoint), status: .methodNotAllowed)
    }
}

func registerWebReadonlyGetRoute<Context: RequestContext>(
    on router: Router<Context>,
    endpoint: String
) {
    router.get(RouterPath(endpoint)) { _, _ -> Response in
        jsonResponse(webReadonlyWriteResponse(endpoint: endpoint), status: .methodNotAllowed)
    }
}

private struct WebBridgeSource: Codable, Equatable {
    let command: String?
    let commands: [String]?
    let runtimeScope: String
    let readonly: Bool
}

private struct WebBridgeCommandOutput: Codable, Equatable {
    let id: String
    let platform: String
    let command: String
    let ok: Bool
    let exitCode: Int?
    let stdout: String
    let stderr: String
}

private struct WebHostTarget: Codable, Equatable {
    let id: String
    let target: String
    let name: String
    let platform: String
    let appName: String?
    let bundleIdentifier: String?
    let runtime: String
    let state: String
    let statusLabel: String
    let ready: Bool
    let scope: String
    let kind: String
    let transport: String?
    let source: String
    let readonly: Bool
    let blockedReasons: [String]
    let sensitive: Bool
}

private struct WebHostTargetsBridgeResponse: Codable, Equatable {
    let ok: Bool
    let capturedAt: String
    let source: WebBridgeSource
    let targets: [WebHostTarget]
    let commandOutputs: [WebBridgeCommandOutput]
}

private struct WebHostTargetDiscoveryPlan {
    let platform: HostDevicePlatform
    let scope: HostDeviceScope
    let command: String
}

private struct WebIOSSimulatorTarget: Codable, Equatable {
    let id: String
    let udid: String
    let name: String
    let platform: String
    let runtime: String
    let runtimeIdentifier: String
    let deviceTypeIdentifier: String
    let state: String
    let statusLabel: String
    let isAvailable: Bool
    let isBooted: Bool
    let canScreenshot: Bool
    let source: String
    let readonly: Bool
}

private struct WebIOSSimulatorTargetsBridgeResponse: Codable, Equatable {
    let ok: Bool
    let capturedAt: String
    let source: WebBridgeSource
    let simulators: [WebIOSSimulatorTarget]
}

private struct WebHostScreenshotBridgeResponse: Codable, Equatable {
    let ok: Bool
    let simulator: String
    let source: WebBridgeSource
    let artifact: String
    let pixelWidth: Int?
    let pixelHeight: Int?
    let dataUrl: String
}

private struct WebHostLogEntry: Codable, Equatable {
    let id: String
    let time: String
    let level: String
    let message: String
}

private struct WebHostLogsBridgeResponse: Codable, Equatable {
    let ok: Bool
    let capturedAt: String
    let source: WebBridgeSource
    let entries: [WebHostLogEntry]
}

private func makeWebHostTargetsBridgeResponse(hdc: String = "hdc", adb: String = "adb") -> WebHostTargetsBridgeResponse {
    let plans = webHostTargetDiscoveryPlans()
    var targets: [WebHostTarget] = []
    var outputs: [WebBridgeCommandOutput] = []
    for plan in plans {
        do {
            let discovered = try hostDeviceTargets(platform: plan.platform, scope: plan.scope, hdc: hdc, adb: adb).targets
            targets.append(contentsOf: discovered.filter(shouldExposeWebHostTarget).map(webHostTarget(from:)))
            outputs.append(WebBridgeCommandOutput(
                id: "\(plan.platform.rawValue)-\(plan.scope.rawValue)",
                platform: plan.platform.rawValue,
                command: plan.command,
                ok: true,
                exitCode: 0,
                stdout: "",
                stderr: ""
            ))
        } catch {
            outputs.append(WebBridgeCommandOutput(
                id: "\(plan.platform.rawValue)-\(plan.scope.rawValue)",
                platform: plan.platform.rawValue,
                command: plan.command,
                ok: false,
                exitCode: nil,
                stdout: "",
                stderr: "\(error)"
            ))
        }
    }
    return WebHostTargetsBridgeResponse(
        ok: outputs.contains(where: \.ok),
        capturedAt: isoTimestamp(),
        source: WebBridgeSource(command: nil, commands: plans.map(\.command), runtimeScope: "host-device", readonly: true),
        targets: targets.sorted { $0.id < $1.id },
        commandOutputs: outputs
    )
}

func makeWebTargetRegistryBridgeResponse(
    runtimeTargets: [TKTargetSummary],
    hostTargets: [HostDeviceTarget],
    usbTunnelAdapterAvailable: Bool = webIOSTunnelAdapterAvailable()
) -> TKWebTargetRegistryResponse {
    makeWebTargetRegistry(
        runtimeTargets: runtimeTargets,
        hostTargets: hostTargets,
        usbTunnelAdapterAvailable: usbTunnelAdapterAvailable
    )
}

private func makePackagedWebTargetRegistryBridgeResponse(dependencies: PackagedWebDependencies) async -> TKWebTargetRegistryResponse {
    let runtimeTargets = await dependencies.runtimeTargets()
    return makeWebTargetRegistryBridgeResponse(
        runtimeTargets: runtimeTargets,
        hostTargets: dependencies.hostTargets(dependencies.hdcPath, dependencies.adbPath)
    )
}

private func webHostTargetDiscoveryPlans() -> [WebHostTargetDiscoveryPlan] {
    [
        WebHostTargetDiscoveryPlan(platform: .ios, scope: .simulator, command: "triton sim list --json"),
        WebHostTargetDiscoveryPlan(platform: .ios, scope: .real, command: "triton device list --platform ios --scope real --json"),
        WebHostTargetDiscoveryPlan(platform: .android, scope: .emulator, command: "triton device list --platform android --scope emulator --json"),
        WebHostTargetDiscoveryPlan(platform: .android, scope: .real, command: "triton device list --platform android --scope real --json"),
        WebHostTargetDiscoveryPlan(platform: .harmony, scope: .emulator, command: "triton device list --platform harmony --scope emulator --json"),
        WebHostTargetDiscoveryPlan(platform: .harmony, scope: .real, command: "triton device list --platform harmony --scope real --json"),
    ]
}

private func shouldExposeWebHostTarget(_ target: HostDeviceTarget) -> Bool {
    if target.scope == HostDeviceScope.real.rawValue || target.kind == "real-device" {
        return target.ready && hasDirectWebRealDeviceConnection(target)
    }
    return target.ready
}

private func hasDirectWebRealDeviceConnection(_ target: HostDeviceTarget) -> Bool {
    let transport = target.transport?.lowercased()
    return transport == "wired" || transport == "usb"
}

private func makeWebIOSSimulatorTargetsBridgeResponse() -> WebIOSSimulatorTargetsBridgeResponse {
    let targets = (try? hostDeviceTargets(platform: .ios, scope: .simulator, hdc: "hdc").targets) ?? []
    return WebIOSSimulatorTargetsBridgeResponse(
        ok: true,
        capturedAt: isoTimestamp(),
        source: WebBridgeSource(command: "triton sim list --json", commands: nil, runtimeScope: "host-ios-simulator", readonly: true),
        simulators: targets.map(webIOSSimulatorTarget(from:)).sorted { $0.id < $1.id }
    )
}

private func makeWebHostScreenshotBridgeResponse(
    platform: String,
    target: String,
    scope: String? = nil,
    kind: String? = nil,
    source: String? = nil
) async throws -> WebHostScreenshotBridgeResponse {
    guard let hostPlatform = HostDevicePlatform(rawValue: platform) else {
        throw RuntimeError("Unsupported host platform: \(platform).")
    }
    if isWebIOSRuntimeMirror(platform: hostPlatform, scope: scope, kind: kind, source: source) {
        var client = TritonKitHTTPClient(host: "127.0.0.1", port: 19421)
        let runtimeTargets: TKTargetsResponse = try await client.getJSON("/targets")
        let hostID = webHostDeviceTargetID(HostDeviceTarget(
            platform: platform,
            id: target,
            target: target,
            state: "Ready",
            ready: true,
            source: "host",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: scope ?? HostDeviceScope.real.rawValue,
            kind: kind ?? "real-device"
        ))
        if let runtimeTarget = webRuntimeInputFallbackTargetID(forHostID: hostID, runtimeTargets: runtimeTargets.targets) {
            client.target = runtimeTarget
        }
        let data = try await client.request(type: "screenshot")
        let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: data)
        let imageData = try await screenshotImageData(screenshot, client: client)
        let imageFormat = try validateRuntimeScreenshotPayload(imageData, declaredFormat: screenshot.format)
        return WebHostScreenshotBridgeResponse(
            ok: true,
            simulator: target,
            source: WebBridgeSource(
                command: "triton screenshot --output <artifact> --json",
                commands: nil,
                runtimeScope: "app-runtime",
                readonly: true
            ),
            artifact: "",
            pixelWidth: Int(screenshot.width.rounded()),
            pixelHeight: Int(screenshot.height.rounded()),
            dataUrl: "data:image/\(imageFormat);base64,\(imageData.base64EncodedString())"
        )
    }
    let id = webHostDeviceTargetID(HostDeviceTarget(
        platform: platform,
        id: target,
        target: target,
        state: "Ready",
        ready: true,
        source: "host",
        name: nil,
        runtime: nil,
        transport: nil,
        scope: webHostDeviceScope(for: hostPlatform).rawValue,
        kind: hostPlatform == .ios ? "simulator" : "emulator"
    ))
    let screenshot = try captureWebHostDeviceScreenshotPayload(id: id)
    return WebHostScreenshotBridgeResponse(
        ok: true,
        simulator: target,
        source: WebBridgeSource(
            command: hostScreenshotCommand(platform: hostPlatform, target: target),
            commands: nil,
            runtimeScope: "host-\(platform)",
            readonly: true
        ),
        artifact: "",
        pixelWidth: screenshot.width,
        pixelHeight: screenshot.height,
        dataUrl: "data:\(screenshot.contentType);base64,\(screenshot.data.base64EncodedString())"
    )
}

func makeWebHostHierarchyBridgeCommand(
    tritonBin: String,
    platform: String,
    target: String,
    output: String
) -> WebLaunchCommand {
    WebLaunchCommand(executable: tritonBin, arguments: [
        "debug", "hierarchy",
        "--platform", platform,
        "--target", target,
        "--json",
        "--output", output,
    ])
}

private func makeWebHostHierarchyBridgeResponse(tritonBin: String, platform: String, target: String) throws -> TKHostHierarchyResponse {
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-web-host-hierarchy-\(UUID().uuidString).json")
        .path
    defer { try? FileManager.default.removeItem(atPath: output) }
    let command = makeWebHostHierarchyBridgeCommand(tritonBin: tritonBin, platform: platform, target: target, output: output)
    try runWebProcess(command, environment: [:], currentDirectory: FileManager.default.currentDirectoryPath)
    let data = try Data(contentsOf: URL(fileURLWithPath: output))
    return try JSONDecoder().decode(TKHostHierarchyResponse.self, from: data)
}

private func isWebIOSRuntimeMirror(
    platform: HostDevicePlatform,
    scope: String?,
    kind: String?,
    source: String?
) -> Bool {
    platform == .ios && (
        source == "runtime"
            || scope == HostDeviceScope.real.rawValue
            || kind == "real-device"
    )
}

private func makeWebHostLogsBridgeResponse(tritonBin: String, platform: String, target: String) throws -> WebHostLogsBridgeResponse {
    guard platform == HostDevicePlatform.ios.rawValue else {
        throw RuntimeError(webHostLogsUnsupportedResponse(platform: platform).error.message)
    }
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-web-host-logs-\(UUID().uuidString).ndjson")
        .path
    defer { try? FileManager.default.removeItem(atPath: output) }
    let command = WebLaunchCommand(executable: tritonBin, arguments: [
        "sim", "logs",
        "--simulator", target,
        "--output", output,
        "--duration", "2",
        "--style", "ndjson",
        "--json",
    ])
    try runWebProcess(command, environment: [:], currentDirectory: FileManager.default.currentDirectoryPath)
    let text = (try? String(contentsOfFile: output, encoding: .utf8)) ?? ""
    return WebHostLogsBridgeResponse(
        ok: true,
        capturedAt: isoTimestamp(),
        source: WebBridgeSource(command: command.display, commands: nil, runtimeScope: "host-ios-simulator", readonly: true),
        entries: webHostLogEntries(from: text)
    )
}

private func makePackagedWebIOSSimulatorFrameResponse(_ streamRequest: PackagedWebIOSSimulatorMjpegRequest) async -> Response {
    do { try assertIOSSimulatorResizeCaptureAllowed(target: streamRequest.udid) }
    catch let error as IOSSimulatorResizeCaptureError {
        return jsonError(code: error.detail.code, message: error.detail.message, endpoint: "/web/ios-simulator/frame", hint: error.detail.hint, status: .conflict)
    } catch {
        return jsonError(code: "ios_simulator_resize_capture_state_unknown", message: "Capture routing could not be verified.", endpoint: "/web/ios-simulator/frame", status: .conflict)
    }

    guard CLIHostSimulatorFramebufferService.shared.startStreaming(udid: streamRequest.udid) else {
        return jsonError(
            code: "web_ios_simulator_frame_unavailable",
            message: "Unable to start host framebuffer capture for simulator \(streamRequest.udid).",
            endpoint: "/web/ios-simulator/frame",
            hint: "Verify the simulator is booted and available with `triton sim list --json`.",
            status: .conflict
        )
    }
    defer {
        CLIHostSimulatorFramebufferService.shared.stopStreaming(udid: streamRequest.udid)
    }

    for _ in 0..<30 {
        if let (jpegData, _) = CLIHostSimulatorFramebufferService.shared.getLatestFrameWithVersion(udid: streamRequest.udid) {
            return Response(
                status: .ok,
                headers: [.contentType: "image/jpeg"],
                body: .init(byteBuffer: ByteBuffer(data: jpegData))
            )
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    return jsonError(
        code: "web_ios_simulator_frame_timeout",
        message: "Host framebuffer capture started but did not produce a frame for simulator \(streamRequest.udid).",
        endpoint: "/web/ios-simulator/frame",
        hint: "Keep the Simulator window active and retry the Web stream.",
        status: .requestTimeout
    )
}

func runPackagedWebServer(_ plan: WebLaunchPlan) async throws {
    guard let webRoot = plan.bundledWebRoot else {
        throw WebCommandError.bundledWebRootNotFound(path: nil)
    }
    guard isValidBundledWebRoot(URL(fileURLWithPath: webRoot, isDirectory: true).standardizedFileURL) else {
        throw WebCommandError.bundledWebRootNotFound(path: webRoot)
    }

    let router = makePackagedWebRouter(webRoot: webRoot, tritonBin: plan.tritonBin)

    let app = Application(
        router: router,
        configuration: .init(address: .hostname(plan.host, port: plan.port))
    )
    print("Triton Web Device Hub: \(plan.url)")
    print("mode: packaged")
    try await app.runService()
}

private func packagedWebResponse(webRoot: String, requestPath: String) -> Response {
    do {
        let payload = try makePackagedWebStaticResponse(webRoot: webRoot, requestPath: requestPath)
        return Response(
            status: .ok,
            headers: [.contentType: payload.contentType],
            body: .init(byteBuffer: ByteBuffer(data: payload.data))
        )
    } catch {
        if shouldRenderPackagedWebStaticDiagnosticHTML(requestPath: requestPath) {
            let html = makePackagedWebStaticDiagnosticHTML(webRoot: webRoot)
            return Response(
                status: .notFound,
                headers: [.contentType: "text/html; charset=utf-8"],
                body: .init(byteBuffer: ByteBuffer(string: html))
            )
        }
        return jsonError(code: "web_static_asset_failed", message: "\(error)", status: .notFound)
    }
}

func makePackagedWebStaticDiagnosticHTML(webRoot: String) -> String {
    let escapedRoot = htmlEscape(webRoot)
    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Triton Web assets are missing</title>
      <style>
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #0b1020; color: #e5e7eb; font: 14px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
        main { max-width: 760px; margin: 32px; padding: 28px; border: 1px solid rgba(148, 163, 184, .35); border-radius: 18px; background: rgba(15, 23, 42, .92); box-shadow: 0 24px 80px rgba(0, 0, 0, .35); }
        h1 { margin: 0 0 12px; font-size: 22px; }
        p { margin: 10px 0; color: #cbd5e1; line-height: 1.55; }
        code { color: #bfdbfe; background: rgba(30, 41, 59, .9); padding: 2px 6px; border-radius: 6px; }
        .path { word-break: break-all; }
      </style>
    </head>
    <body>
      <main>
        <h1>Triton Web assets are missing</h1>
        <p><code>web_static_asset_failed</code>: bundled static assets were not found at <code class="path">\(escapedRoot)</code>. Expected <code>web/index.html</code>.</p>
        <p>Run <code>triton web --print-command --json</code> to inspect whether this CLI is using a source checkout or packaged Web assets.</p>
        <p>For Homebrew or release installs, reinstall/update the package so <code>share/triton/web/index.html</code> is present. For checkout development, run <code>triton web --root /path/to/TritonKit</code>.</p>
      </main>
    </body>
    </html>
    """
}

func shouldRenderPackagedWebStaticDiagnosticHTML(requestPath: String) -> Bool {
    let decodedPath = requestPath.removingPercentEncoding ?? requestPath
    let pathOnly = decodedPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? decodedPath
    if pathOnly == "/web" || pathOnly.hasPrefix("/web/") {
        return false
    }
    let ext = URL(fileURLWithPath: pathOnly).pathExtension.lowercased()
    return pathOnly == "/" || pathOnly.isEmpty || ext.isEmpty || ext == "html"
}

private func webHostTarget(from target: HostDeviceTarget) -> WebHostTarget {
    WebHostTarget(
        id: webHostDeviceTargetID(target),
        target: target.target,
        name: target.name ?? target.target,
        platform: target.platform,
        appName: target.appName,
        bundleIdentifier: target.bundleIdentifier,
        runtime: target.runtime ?? target.platform,
        state: target.state,
        statusLabel: target.ready ? "Ready" : target.state,
        ready: target.ready,
        scope: target.scope ?? "",
        kind: target.kind ?? "",
        transport: target.transport,
        source: target.source,
        readonly: true,
        blockedReasons: target.blockedReasons,
        sensitive: target.sensitive
    )
}

private func webIOSSimulatorTarget(from target: HostDeviceTarget) -> WebIOSSimulatorTarget {
    WebIOSSimulatorTarget(
        id: "triton:ios-simulator:\(target.target)",
        udid: target.target,
        name: target.name ?? target.target,
        platform: HostDevicePlatform.ios.rawValue,
        runtime: target.runtime ?? "iOS Simulator",
        runtimeIdentifier: "",
        deviceTypeIdentifier: "",
        state: target.state,
        statusLabel: target.ready ? "Booted" : target.state,
        isAvailable: true,
        isBooted: target.ready,
        canScreenshot: target.ready,
        source: target.source,
        readonly: true
    )
}

private func hostScreenshotCommand(platform: HostDevicePlatform, target: String) -> String {
    switch platform {
    case .ios:
        return "triton sim screenshot --simulator \(webShellQuote(target)) --output <artifact> --json"
    case .android:
        return "triton device screenshot --platform android --target \(webShellQuote(target)) --output <artifact> --json"
    case .harmony:
        return "triton device screenshot --platform harmony --target \(webShellQuote(target)) --output <artifact> --json"
    }
}

private func webHostLogEntries(from text: String) -> [WebHostLogEntry] {
    text.split(whereSeparator: \.isNewline).prefix(200).enumerated().map { index, line in
        let raw = String(line)
        var time = isoTimestamp()
        var level = "info"
        var message = raw
        if let data = raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            time = (object["timestamp"] as? String)
                ?? (object["time"] as? String)
                ?? (object["date"] as? String)
                ?? time
            message = (object["eventMessage"] as? String)
                ?? (object["message"] as? String)
                ?? (object["composedMessage"] as? String)
                ?? raw
            let rawLevel = ((object["messageType"] as? String) ?? (object["level"] as? String) ?? "").lowercased()
            if rawLevel.contains("fault") || rawLevel.contains("error") {
                level = "error"
            } else if rawLevel.contains("warn") || rawLevel.contains("default") {
                level = "warn"
            }
        }
        return WebHostLogEntry(id: "\(index + 1)", time: time, level: level, message: message)
    }
}

private func isoTimestamp(_ date: Date = Date()) -> String {
    ISO8601DateFormatter().string(from: date)
}


private func htmlEscape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

func makePackagedWebRouter(
    webRoot: String,
    tritonBin: String,
    dependencies: PackagedWebDependencies = .init()
) -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)
    router.get("/") { request, _ -> Response in
        packagedWebResponse(webRoot: webRoot, requestPath: request.uri.path)
    }
    router.get("/web/host-targets") { _, _ -> Response in
        jsonResponse(makeWebHostTargetsBridgeResponse(hdc: dependencies.hdcPath, adb: dependencies.adbPath))
    }
    router.get("/web/target-registry") { _, _ -> Response in
        jsonResponse(await makePackagedWebTargetRegistryBridgeResponse(dependencies: dependencies))
    }
    router.get("/web/ios-simulator/targets") { _, _ -> Response in
        jsonResponse(makeWebIOSSimulatorTargetsBridgeResponse())
    }
    router.get("/web/host-screenshot") { request, _ -> Response in
        let platform = request.uri.queryParameters.get("platform") ?? ""
        let target = request.uri.queryParameters.get("target") ?? ""
        let scope = request.uri.queryParameters.get("scope")
        let kind = request.uri.queryParameters.get("kind")
        let source = request.uri.queryParameters.get("source")
        guard !platform.isEmpty, !target.isEmpty else {
            return jsonError(code: "invalid_query", message: "platform and target are required.", endpoint: "/web/host-screenshot", status: .badRequest)
        }
        do {
            return jsonResponse(try await makeWebHostScreenshotBridgeResponse(platform: platform, target: target, scope: scope, kind: kind, source: source))
        } catch {
            return jsonError(code: "web_host_screenshot_failed", message: "\(error)", endpoint: "/web/host-screenshot", status: .conflict)
        }
    }
    router.get("/web/host-hierarchy") { request, _ -> Response in
        let platform = request.uri.queryParameters.get("platform") ?? ""
        let target = request.uri.queryParameters.get("target") ?? ""
        guard [HostDevicePlatform.ios.rawValue, HostDevicePlatform.android.rawValue, HostDevicePlatform.harmony.rawValue].contains(platform) else {
            return jsonError(code: "web_host_hierarchy_platform_not_supported", message: "Readonly host hierarchy is not available for platform: \(platform)", endpoint: "/web/host-hierarchy", status: .notImplemented)
        }
        guard !target.isEmpty else {
            return jsonError(code: "invalid_query", message: "target is required.", endpoint: "/web/host-hierarchy", status: .badRequest)
        }
        do {
            return jsonResponse(try makeWebHostHierarchyBridgeResponse(tritonBin: tritonBin, platform: platform, target: target))
        } catch {
            return jsonError(code: "web_host_hierarchy_failed", message: "\(error)", endpoint: "/web/host-hierarchy", status: .conflict)
        }
    }
    router.get("/web/ios-simulator/screenshot") { request, _ -> Response in
        let simulator = request.uri.queryParameters.get("simulator") ?? ""
        guard !simulator.isEmpty else {
            return jsonError(code: "invalid_query", message: "simulator is required.", endpoint: "/web/ios-simulator/screenshot", status: .badRequest)
        }
        do {
            return jsonResponse(try await makeWebHostScreenshotBridgeResponse(platform: HostDevicePlatform.ios.rawValue, target: simulator, scope: HostDeviceScope.simulator.rawValue, kind: "simulator", source: "host"))
        } catch {
            return jsonError(code: "web_ios_simulator_screenshot_failed", message: "\(error)", endpoint: "/web/ios-simulator/screenshot", status: .conflict)
        }
    }
    registerPackagedWebFramebufferRoutes(on: router, dependencies: dependencies)
    router.get("/web/ios-simulator/mjpeg") { request, _ -> Response in
        do {
            let streamRequest = try makePackagedWebIOSSimulatorMjpegRequest(
                target: request.uri.queryParameters.get("target"),
                udid: request.uri.queryParameters.get("udid"),
                fps: request.uri.queryParameters.get("fps")
            )
            return makePackagedWebIOSSimulatorMjpegResponse(streamRequest, request: request, capture: dependencies.iosFramebuffer)
        } catch {
            return jsonError(code: "invalid_query", message: "\(error)", endpoint: "/web/ios-simulator/mjpeg", status: .badRequest)
        }
    }
    router.get("/web/ios-simulator/frame") { request, _ -> Response in
        do {
            let streamRequest = try makePackagedWebIOSSimulatorMjpegRequest(
                target: request.uri.queryParameters.get("target"),
                udid: request.uri.queryParameters.get("udid"),
                fps: request.uri.queryParameters.get("fps")
            )
            return await makePackagedWebIOSSimulatorFrameResponse(streamRequest)
        } catch {
            return jsonError(code: "invalid_query", message: "\(error)", endpoint: "/web/ios-simulator/frame", status: .badRequest)
        }
    }
    router.get("/web/host-logs") { request, _ -> Response in
        let platform = request.uri.queryParameters.get("platform") ?? ""
        let target = request.uri.queryParameters.get("target") ?? ""
        guard platform == HostDevicePlatform.ios.rawValue else {
            return jsonResponse(webHostLogsUnsupportedResponse(platform: platform), status: .notImplemented)
        }
        guard !target.isEmpty else {
            return jsonError(code: "invalid_query", message: "target is required.", endpoint: "/web/host-logs", status: .badRequest)
        }
        do {
            return jsonResponse(try makeWebHostLogsBridgeResponse(tritonBin: tritonBin, platform: platform, target: target))
        } catch {
            return jsonError(code: "web_host_logs_failed", message: "\(error)", endpoint: "/web/host-logs", status: .conflict)
        }
    }
    registerWebReadonlyPostRoute(on: router, endpoint: "/web/host-input")
    registerWebReadonlyGetRoute(on: router, endpoint: "/web/host-input")
    registerWebReadonlyPostRoute(on: router, endpoint: "/web/node-property")
    registerWebReadonlyGetRoute(on: router, endpoint: "/web/node-property")
    router.get("/**") { request, _ -> Response in
        packagedWebResponse(webRoot: webRoot, requestPath: request.uri.path)
    }

    return router
}
