import Darwin
import Foundation
import Hummingbird
import NIOCore
import TritonKitShared

enum WebDependencyInstallMode: String {
    case auto
    case always
    case never
}

enum WebCommandError: Error, Equatable, CustomStringConvertible {
    case webRootNotFound(currentDirectory: String, explicitRoot: String?)
    case bundledWebRootNotFound(path: String?)
    case conflictingInstallOptions
    case processFailed(command: String, exitCode: Int32)

    var description: String {
        switch self {
        case .webRootNotFound(let currentDirectory, let explicitRoot):
            let root = explicitRoot.map { " explicit root: \($0);" } ?? ""
            return "Triton Web root was not found;\(root) current directory: \(currentDirectory). Expected a Web/package.json and Vite config in a TritonKit checkout, or a bundled web/index.html beside the triton executable."
        case .bundledWebRootNotFound(let path):
            let location = path.map { " at \($0)" } ?? ""
            return "Bundled Triton Web static assets were not found\(location). Expected web/index.html."
        case .conflictingInstallOptions:
            return "Use only one of --install or --no-install."
        case .processFailed(let command, let exitCode):
            return "Command failed with exit code \(exitCode): \(command)"
        }
    }

    var code: String {
        switch self {
        case .webRootNotFound:
            return "web_root_not_found"
        case .bundledWebRootNotFound:
            return "bundled_web_root_not_found"
        case .conflictingInstallOptions:
            return "validation_failed"
        case .processFailed:
            return "web_start_failed"
        }
    }

    var hint: String {
        switch self {
        case .webRootNotFound:
            return "Run from the TritonKit checkout, pass --root /path/to/TritonKit, or install a release package that includes the web/ directory."
        case .bundledWebRootNotFound:
            return "Reinstall the release package, or pass --root /path/to/TritonKit to use checkout dev mode."
        case .conflictingInstallOptions:
            return "Choose --install to force npm install, or --no-install to skip it."
        case .processFailed:
            return "Inspect npm output above, then retry `triton web --print-command --json` to verify the launch plan."
        }
    }
}

struct WebLaunchCommand: Codable, Equatable {
    let executable: String
    let arguments: [String]

    var display: String {
        ([executable] + arguments).map(shellQuote).joined(separator: " ")
    }
}

struct WebLaunchPlan: Codable, Equatable {
    let ok: Bool
    let action: String
    let mode: String
    let repoRoot: String?
    let webRoot: String?
    let bundledWebRoot: String?
    let tritonBin: String
    let host: String
    let port: Int
    let url: String
    let readonly: Bool
    let installCommand: WebLaunchCommand?
    let command: WebLaunchCommand
    let environment: [String: String]
}

func makeWebLaunchPlan(
    explicitRoot: String?,
    currentDirectory: String,
    explicitTritonBin: String?,
    currentExecutable: String,
    host: String,
    port: Int,
    installMode: WebDependencyInstallMode,
    environment: [String: String],
    explicitBundledWebRoot: String? = nil
) throws -> WebLaunchPlan {
    let tritonBin = explicitTritonBin ?? environment["TRITONKIT_TRITON_BIN"] ?? currentExecutable
    if let roots = discoverWebRoots(explicitRoot: explicitRoot, currentDirectory: currentDirectory) {
        return try makeDevWebLaunchPlan(
            roots: roots,
            tritonBin: tritonBin,
            host: host,
            port: port,
            installMode: installMode
        )
    }

    if explicitRoot != nil {
        throw WebCommandError.webRootNotFound(currentDirectory: currentDirectory, explicitRoot: explicitRoot)
    }

    let bundledRoot = try explicitBundledWebRoot.map { root in
        let url = URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL
        guard isValidBundledWebRoot(url) else {
            throw WebCommandError.bundledWebRootNotFound(path: root)
        }
        return url
    } ?? discoverBundledWebRoot(currentExecutable: currentExecutable, environment: environment)

    guard let bundledRoot else {
        throw WebCommandError.webRootNotFound(currentDirectory: currentDirectory, explicitRoot: explicitRoot)
    }

    return makePackagedWebLaunchPlan(
        bundledWebRoot: bundledRoot,
        tritonBin: tritonBin,
        currentExecutable: currentExecutable,
        host: host,
        port: port
    )
}

private func makeDevWebLaunchPlan(
    roots: (repoRoot: URL, webRoot: URL),
    tritonBin: String,
    host: String,
    port: Int,
    installMode: WebDependencyInstallMode
) throws -> WebLaunchPlan {
    let nodeModules = roots.webRoot.appendingPathComponent("node_modules", isDirectory: true)
    let shouldInstall = switch installMode {
    case .always:
        true
    case .auto:
        !FileManager.default.fileExists(atPath: nodeModules.path)
    case .never:
        false
    }
    let installCommand = shouldInstall
        ? WebLaunchCommand(executable: "npm", arguments: ["--prefix", roots.webRoot.path, "install"])
        : nil
    let command = WebLaunchCommand(executable: "npm", arguments: [
        "--prefix", roots.webRoot.path,
        "run", "dev",
        "--",
        "--host", host,
        "--port", String(port),
    ])

    return WebLaunchPlan(
        ok: true,
        action: "web.start",
        mode: "dev",
        repoRoot: roots.repoRoot.path,
        webRoot: roots.webRoot.path,
        bundledWebRoot: nil,
        tritonBin: tritonBin,
        host: host,
        port: port,
        url: "http://\(host):\(port)/",
        readonly: true,
        installCommand: installCommand,
        command: command,
        environment: ["TRITONKIT_TRITON_BIN": tritonBin]
    )
}

private func makePackagedWebLaunchPlan(
    bundledWebRoot: URL,
    tritonBin: String,
    currentExecutable: String,
    host: String,
    port: Int
) -> WebLaunchPlan {
    let command = WebLaunchCommand(executable: currentExecutable, arguments: [
        "web",
        "--host", host,
        "--port", String(port),
        "--bundled-web-root", bundledWebRoot.path,
        "--triton-bin", tritonBin,
    ])
    return WebLaunchPlan(
        ok: true,
        action: "web.start",
        mode: "packaged",
        repoRoot: bundledWebRoot.deletingLastPathComponent().path,
        webRoot: nil,
        bundledWebRoot: bundledWebRoot.path,
        tritonBin: tritonBin,
        host: host,
        port: port,
        url: "http://\(host):\(port)/",
        readonly: true,
        installCommand: nil,
        command: command,
        environment: ["TRITONKIT_TRITON_BIN": tritonBin]
    )
}

func renderWebLaunchPlanText(_ plan: WebLaunchPlan) -> String {
    var lines = [
        "url: \(plan.url)",
        "mode: \(plan.mode)",
        "repoRoot: \(plan.repoRoot ?? "n/a")",
        "webRoot: \(plan.webRoot ?? "n/a")",
        "bundledWebRoot: \(plan.bundledWebRoot ?? "n/a")",
        "tritonBin: \(plan.tritonBin)",
        "readonly: \(plan.readonly)",
    ]
    if let installCommand = plan.installCommand {
        lines.append("install: \(installCommand.display)")
    } else {
        lines.append("install: skipped")
    }
    lines.append("command: \(plan.command.display)")
    return lines.joined(separator: "\n")
}

func runWebLaunchPlan(_ plan: WebLaunchPlan) async throws {
    if plan.mode == "packaged" {
        try await runPackagedWebServer(plan)
        return
    }
    guard let repoRoot = plan.repoRoot else {
        throw WebCommandError.webRootNotFound(currentDirectory: FileManager.default.currentDirectoryPath, explicitRoot: nil)
    }
    if let installCommand = plan.installCommand {
        try runWebProcess(installCommand, environment: plan.environment, currentDirectory: repoRoot)
    }
    print("Triton Web Device Hub: \(plan.url)")
    try runWebProcess(plan.command, environment: plan.environment, currentDirectory: repoRoot)
}

func currentExecutablePath() -> String {
    var size = UInt32(0)
    _ = _NSGetExecutablePath(nil, &size)
    var buffer = [CChar](repeating: 0, count: Int(size) + 1)
    if _NSGetExecutablePath(&buffer, &size) == 0 {
        return FileManager.default
            .string(withFileSystemRepresentation: buffer, length: Int(strlen(buffer)))
    }
    return ProcessInfo.processInfo.arguments.first ?? "triton"
}

private func discoverWebRoots(explicitRoot: String?, currentDirectory: String) -> (repoRoot: URL, webRoot: URL)? {
    if let explicitRoot {
        return webRoots(for: URL(fileURLWithPath: explicitRoot).standardizedFileURL)
    }

    var cursor = URL(fileURLWithPath: currentDirectory).standardizedFileURL
    while true {
        if let roots = webRoots(for: cursor) {
            return roots
        }
        let parent = cursor.deletingLastPathComponent()
        if parent.path == cursor.path {
            return nil
        }
        cursor = parent
    }
}

private func discoverBundledWebRoot(currentExecutable: String, environment: [String: String]) -> URL? {
    if let root = environment["TRITONKIT_WEB_ROOT"] {
        let url = URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL
        if isValidBundledWebRoot(url) {
            return url
        }
    }

    let executable = URL(fileURLWithPath: currentExecutable).standardizedFileURL
    let executableDir = executable.deletingLastPathComponent()
    let candidates = [
        executableDir.appendingPathComponent("web", isDirectory: true),
        executableDir.deletingLastPathComponent()
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("triton", isDirectory: true)
            .appendingPathComponent("web", isDirectory: true),
    ]
    return candidates.first(where: isValidBundledWebRoot)
}

private func webRoots(for root: URL) -> (repoRoot: URL, webRoot: URL)? {
    if isValidWebRoot(root) {
        return (repoRoot: root.deletingLastPathComponent(), webRoot: root)
    }

    let web = root.appendingPathComponent("Web", isDirectory: true)
    if isValidWebRoot(web) {
        return (repoRoot: root, webRoot: web)
    }

    return nil
}

private func isValidWebRoot(_ url: URL) -> Bool {
    let packageJSON = url.appendingPathComponent("package.json")
    guard FileManager.default.fileExists(atPath: packageJSON.path) else {
        return false
    }
    let viteConfigs = [
        "vite.config.ts",
        "vite.config.js",
        "vite.config.mjs",
    ]
    return viteConfigs.contains { name in
        FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path)
    }
}

private func isValidBundledWebRoot(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.appendingPathComponent("index.html").path)
}

struct PackagedWebStaticResponse: Equatable {
    let data: Data
    let contentType: String
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

private func webReadonlyInputResponse() -> TKCLIErrorResponse {
    TKCLIErrorResponse(error: TKCLIErrorDetail(
        code: "web_host_input_readonly",
        message: "Bundled Triton Web is a readonly device hub and does not execute input actions.",
        endpoint: "/web/host-input",
        hint: "Use Triton CLI action commands for explicit control flows."
    ))
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
    let source: String
    let readonly: Bool
}

private struct WebHostTargetsBridgeResponse: Codable, Equatable {
    let ok: Bool
    let capturedAt: String
    let source: WebBridgeSource
    let targets: [WebHostTarget]
    let commandOutputs: [WebBridgeCommandOutput]
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
    let platforms: [(HostDevicePlatform, String)] = [
        (.ios, "triton sim list --json"),
        (.android, "triton device list --platform android --json"),
        (.harmony, "triton device list --platform harmony --json"),
    ]
    var targets: [WebHostTarget] = []
    var outputs: [WebBridgeCommandOutput] = []
    for (platform, command) in platforms {
        do {
            let discovered = try hostDeviceTargets(platform: platform, scope: webHostDeviceScope(for: platform), hdc: hdc, adb: adb).targets
            targets.append(contentsOf: discovered.filter { $0.ready }.map(webHostTarget(from:)))
            outputs.append(WebBridgeCommandOutput(
                id: platform.rawValue,
                platform: platform.rawValue,
                command: command,
                ok: true,
                exitCode: 0,
                stdout: "",
                stderr: ""
            ))
        } catch {
            outputs.append(WebBridgeCommandOutput(
                id: platform.rawValue,
                platform: platform.rawValue,
                command: command,
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
        source: WebBridgeSource(command: nil, commands: platforms.map(\.1), runtimeScope: "host-emulator", readonly: true),
        targets: targets.sorted { $0.id < $1.id },
        commandOutputs: outputs
    )
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

private func makeWebHostScreenshotBridgeResponse(platform: String, target: String) throws -> WebHostScreenshotBridgeResponse {
    guard let hostPlatform = HostDevicePlatform(rawValue: platform) else {
        throw RuntimeError("Unsupported host platform: \(platform).")
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

private func runPackagedWebServer(_ plan: WebLaunchPlan) async throws {
    guard let webRoot = plan.bundledWebRoot else {
        throw WebCommandError.bundledWebRootNotFound(path: nil)
    }

    let router = Router(context: BasicRequestContext.self)
    router.get("/") { request, _ -> Response in
        packagedWebResponse(webRoot: webRoot, requestPath: request.uri.path)
    }
    router.get("/web/host-targets") { _, _ -> Response in
        jsonResponse(makeWebHostTargetsBridgeResponse())
    }
    router.get("/web/ios-simulator/targets") { _, _ -> Response in
        jsonResponse(makeWebIOSSimulatorTargetsBridgeResponse())
    }
    router.get("/web/host-screenshot") { request, _ -> Response in
        let platform = request.uri.queryParameters.get("platform") ?? ""
        let target = request.uri.queryParameters.get("target") ?? ""
        guard !platform.isEmpty, !target.isEmpty else {
            return jsonError(code: "invalid_query", message: "platform and target are required.", endpoint: "/web/host-screenshot", status: .badRequest)
        }
        do {
            return jsonResponse(try makeWebHostScreenshotBridgeResponse(platform: platform, target: target))
        } catch {
            return jsonError(code: "web_host_screenshot_failed", message: "\(error)", endpoint: "/web/host-screenshot", status: .conflict)
        }
    }
    router.get("/web/ios-simulator/screenshot") { request, _ -> Response in
        let simulator = request.uri.queryParameters.get("simulator") ?? ""
        guard !simulator.isEmpty else {
            return jsonError(code: "invalid_query", message: "simulator is required.", endpoint: "/web/ios-simulator/screenshot", status: .badRequest)
        }
        do {
            return jsonResponse(try makeWebHostScreenshotBridgeResponse(platform: HostDevicePlatform.ios.rawValue, target: simulator))
        } catch {
            return jsonError(code: "web_ios_simulator_screenshot_failed", message: "\(error)", endpoint: "/web/ios-simulator/screenshot", status: .conflict)
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
            return jsonResponse(try makeWebHostLogsBridgeResponse(tritonBin: plan.tritonBin, platform: platform, target: target))
        } catch {
            return jsonError(code: "web_host_logs_failed", message: "\(error)", endpoint: "/web/host-logs", status: .conflict)
        }
    }
    router.post("/web/host-input") { _, _ -> Response in
        jsonResponse(webReadonlyInputResponse(), status: .methodNotAllowed)
    }
    router.get("/web/host-input") { _, _ -> Response in
        jsonResponse(webReadonlyInputResponse(), status: .methodNotAllowed)
    }
    router.get("/**") { request, _ -> Response in
        packagedWebResponse(webRoot: webRoot, requestPath: request.uri.path)
    }

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
        return jsonError(code: "web_static_asset_failed", message: "\(error)", status: .notFound)
    }
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
        source: target.source,
        readonly: true
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
        return "triton sim screenshot --simulator \(shellQuote(target)) --output <artifact> --json"
    case .android:
        return "triton device screenshot --platform android --target \(shellQuote(target)) --output <artifact> --json"
    case .harmony:
        return "triton device screenshot --platform harmony --target \(shellQuote(target)) --output <artifact> --json"
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


private func runWebProcess(
    _ command: WebLaunchCommand,
    environment: [String: String],
    currentDirectory: String
) throws {
    let process = Process()
    if command.executable.contains("/") {
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command.executable] + command.arguments
    }
    process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory, isDirectory: true)
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw WebCommandError.processFailed(command: command.display, exitCode: process.terminationStatus)
    }
}

private func shellQuote(_ value: String) -> String {
    guard !value.isEmpty else {
        return "''"
    }
    let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-")
    if value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
        return value
    }
    return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
