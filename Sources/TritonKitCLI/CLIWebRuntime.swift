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
    case portInUse(host: String, port: Int)
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
        case .portInUse(let host, let port):
            return "Triton Web port \(host):\(port) is already in use."
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
        case .portInUse:
            return "web_port_in_use"
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
        case .portInUse(_, let port):
            return "Find the existing listener with lsof -nP -iTCP:\(port) -sTCP:LISTEN, stop stale triton web / Vite processes, or choose a free port with triton web --port <port>."
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
    let discovery: WebAutoDiscoveryPlan
    let installCommand: WebLaunchCommand?
    let command: WebLaunchCommand
    let environment: [String: String]
}

struct WebAutoDiscoveryOptions: Equatable {
    let simulatorOnly: Bool
    let usb: Bool
    let lan: Bool

    init(simulatorOnly: Bool = false, usb: Bool = true, lan: Bool = true) {
        self.simulatorOnly = simulatorOnly
        self.usb = usb
        self.lan = lan
    }
}

struct WebAutoDiscoveryPlan: Codable, Equatable {
    let simulator: String
    let realDevice: String
    let transportPriority: [String]
    let registry: String
    let targetRegistryEndpoint: String
    let managedServeHost: String
}

struct WebServiceProbe: Codable, Equatable {
    let url: String
    let reachable: Bool
    let statusCode: Int?
    let contentType: String?
    let serviceKind: String?
    let detectedCode: String?
    let message: String?
}

struct WebStatusResponse: Codable, Equatable {
    let ok: Bool
    let action: String
    let host: String
    let port: Int
    let url: String
    let portListening: Bool
    let probe: WebServiceProbe?
    let recommendedActions: [String]
}

struct WebDoctorCheck: Codable, Equatable {
    let id: String
    let status: String
    let message: String
}

struct WebDoctorResponse: Codable, Equatable {
    let ok: Bool
    let action: String
    let healthy: Bool
    let status: WebStatusResponse
    let checks: [WebDoctorCheck]
    let recommendedActions: [String]
}

func makeWebStatusResponse(
    host: String,
    port: Int,
    portListening: Bool,
    probe: WebServiceProbe?
) -> WebStatusResponse {
    var actions: [String] = []
    if portListening {
        actions.append("lsof -nP -iTCP:\(port) -sTCP:LISTEN")
        actions.append("triton web --port <port>")
    } else {
        actions.append("triton web")
    }
    if probe?.detectedCode == "web_static_asset_failed" {
        actions.append("Reinstall or update the packaged Triton release.")
        actions.append("triton web --root /path/to/TritonKit")
    }
    return WebStatusResponse(
        ok: true,
        action: "web.status",
        host: host,
        port: port,
        url: webDeviceHubURL(host: host, port: port),
        portListening: portListening,
        probe: probe,
        recommendedActions: uniqueOrdered(actions)
    )
}

func makeWebDoctorResponse(status: WebStatusResponse) -> WebDoctorResponse {
    var checks: [WebDoctorCheck] = [
        WebDoctorCheck(
            id: "web-port",
            status: status.portListening ? "warning" : "passed",
            message: status.portListening
                ? "Web Device Hub port is already listening."
                : "Web Device Hub port is available."
        ),
    ]
    if status.probe?.detectedCode == "web_static_asset_failed" {
        checks.append(WebDoctorCheck(
            id: "web-static-assets",
            status: "failed",
            message: "Bundled Web static assets are missing."
        ))
    } else if status.probe?.reachable == true {
        checks.append(WebDoctorCheck(
            id: "web-service",
            status: "passed",
            message: "Existing Web service is reachable."
        ))
    } else if status.portListening {
        checks.append(WebDoctorCheck(
            id: "web-service",
            status: "warning",
            message: "A listener exists but did not return a recognizable Web response."
        ))
    }
    let healthy = !checks.contains { $0.status == "failed" }
    return WebDoctorResponse(
        ok: true,
        action: "web.doctor",
        healthy: healthy,
        status: status,
        checks: checks,
        recommendedActions: status.recommendedActions
    )
}

func webDeviceHubURL(host: String, port: Int) -> String {
    "http://\(host):\(port)/"
}

func makeWebStatusResponse(host: String, port: Int) async -> WebStatusResponse {
    let listening = isTCPPortListening(host: host, port: port)
    let probe = listening ? await probeWebService(host: host, port: port) : nil
    return makeWebStatusResponse(host: host, port: port, portListening: listening, probe: probe)
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
    explicitBundledWebRoot: String? = nil,
    discoveryOptions: WebAutoDiscoveryOptions = WebAutoDiscoveryOptions()
) throws -> WebLaunchPlan {
    let tritonBin = explicitTritonBin ?? environment["TRITONKIT_TRITON_BIN"] ?? currentExecutable
    let discovery = makeWebAutoDiscoveryPlan(options: discoveryOptions)
    if let roots = discoverWebRoots(explicitRoot: explicitRoot, currentDirectory: currentDirectory) {
        return try makeDevWebLaunchPlan(
            roots: roots,
            tritonBin: tritonBin,
            host: host,
            port: port,
            installMode: installMode,
            discovery: discovery
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
        port: port,
        discovery: discovery
    )
}

func makeWebAutoDiscoveryPlan(options: WebAutoDiscoveryOptions) -> WebAutoDiscoveryPlan {
    var priority: [String] = []
    if !options.simulatorOnly && options.usb {
        priority.append("usb")
    }
    if !options.simulatorOnly && options.lan {
        priority.append("bonjour")
    }
    priority.append("manual")
    return WebAutoDiscoveryPlan(
        simulator: "auto",
        realDevice: options.simulatorOnly ? "disabled" : "auto",
        transportPriority: priority,
        registry: "serve-owned",
        targetRegistryEndpoint: "http://127.0.0.1:19421/web/target-registry",
        managedServeHost: "0.0.0.0"
    )
}

private func makeDevWebLaunchPlan(
    roots: (repoRoot: URL, webRoot: URL),
    tritonBin: String,
    host: String,
    port: Int,
    installMode: WebDependencyInstallMode,
    discovery: WebAutoDiscoveryPlan
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
        discovery: discovery,
        installCommand: installCommand,
        command: command,
        environment: [
            "TRITONKIT_TRITON_BIN": tritonBin,
            "TRITONKIT_WEB_MANAGED_SERVE_HOST": discovery.managedServeHost,
        ]
    )
}

private func makePackagedWebLaunchPlan(
    bundledWebRoot: URL,
    tritonBin: String,
    currentExecutable: String,
    host: String,
    port: Int,
    discovery: WebAutoDiscoveryPlan
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
        discovery: discovery,
        installCommand: nil,
        command: command,
        environment: [
            "TRITONKIT_TRITON_BIN": tritonBin,
            "TRITONKIT_WEB_MANAGED_SERVE_HOST": discovery.managedServeHost,
        ]
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
        "discovery: simulator=\(plan.discovery.simulator) realDevice=\(plan.discovery.realDevice) transport=\(plan.discovery.transportPriority.joined(separator: ",")) managedServeHost=\(plan.discovery.managedServeHost)",
        "targetRegistryEndpoint: \(plan.discovery.targetRegistryEndpoint)",
    ]
    if let installCommand = plan.installCommand {
        lines.append("install: \(installCommand.display)")
    } else {
        lines.append("install: skipped")
    }
    lines.append("command: \(plan.command.display)")
    return lines.joined(separator: "\n")
}

func renderWebStatusText(_ status: WebStatusResponse) -> String {
    var lines = [
        "url: \(status.url)",
        "portListening: \(status.portListening)",
    ]
    if let probe = status.probe {
        lines.append("probeReachable: \(probe.reachable)")
        if let statusCode = probe.statusCode {
            lines.append("probeStatusCode: \(statusCode)")
        }
        if let detectedCode = probe.detectedCode {
            lines.append("detectedCode: \(detectedCode)")
        }
        if let serviceKind = probe.serviceKind {
            lines.append("serviceKind: \(serviceKind)")
        }
    }
    lines.append("recommendedActions:")
    lines.append(contentsOf: status.recommendedActions.map { "- \($0)" })
    return lines.joined(separator: "\n")
}

func renderWebDoctorText(_ doctor: WebDoctorResponse) -> String {
    var lines = [
        "healthy: \(doctor.healthy)",
        "url: \(doctor.status.url)",
        "checks:",
    ]
    lines.append(contentsOf: doctor.checks.map { "- \($0.id): \($0.status) - \($0.message)" })
    lines.append("recommendedActions:")
    lines.append(contentsOf: doctor.recommendedActions.map { "- \($0)" })
    return lines.joined(separator: "\n")
}

func webDiagnosticOutputFormat(
    _ format: ClientOutputFormat,
    json: Bool,
    arguments: [String] = ProcessInfo.processInfo.arguments
) -> ClientOutputFormat {
    if json || arguments.contains("--json") {
        return .json
    }
    for (index, argument) in arguments.enumerated()
        where argument == "--format" && arguments.indices.contains(index + 1) && arguments[index + 1] == "json" {
        return .json
    }
    return format
}

func runWebLaunchPlan(_ plan: WebLaunchPlan) async throws {
    try ensureWebPortAvailable(host: plan.host, port: plan.port)
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

    let executableCandidates = executableURLs(for: currentExecutable)
    let candidates = executableCandidates.flatMap { executable -> [URL] in
        let executableDir = executable.deletingLastPathComponent()
        return [
            executableDir.appendingPathComponent("web", isDirectory: true),
            executableDir.deletingLastPathComponent()
                .appendingPathComponent("share", isDirectory: true)
                .appendingPathComponent("triton", isDirectory: true)
                .appendingPathComponent("web", isDirectory: true),
        ]
    }
    return candidates.first(where: isValidBundledWebRoot)
}

private func executableURLs(for currentExecutable: String) -> [URL] {
    let executable = URL(fileURLWithPath: currentExecutable)
    let candidates = [
        executable.standardizedFileURL,
        executable.resolvingSymlinksInPath().standardizedFileURL,
    ]
    return candidates.reduce(into: [URL]()) { unique, candidate in
        guard !unique.contains(where: { $0.path == candidate.path }) else {
            return
        }
        unique.append(candidate)
    }
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

private func makePackagedWebTargetRegistryBridgeResponse() async -> TKWebTargetRegistryResponse {
    let runtimeTargets = ((try? await TritonKitHTTPClient(host: "127.0.0.1", port: 19421).getJSON("/targets")) as TKTargetsResponse?)?.targets ?? []
    return makeWebTargetRegistryBridgeResponse(
        runtimeTargets: runtimeTargets,
        hostTargets: discoverWebHostDeviceTargets()
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

enum WebHostInputBridgeRoute: Equatable {
    case runtimeMirror
    case host(id: String)
    case unsupported
}

func webHostInputBridgeRoute(
    platform: String,
    target: String,
    scope: String?,
    kind: String?,
    source: String?
) -> WebHostInputBridgeRoute {
    guard let hostPlatform = HostDevicePlatform(rawValue: platform), !target.isEmpty else {
        return .unsupported
    }
    if isWebIOSRuntimeMirror(
        platform: hostPlatform,
        scope: scope,
        kind: kind,
        source: source,
        target: target
    ) {
        return .runtimeMirror
    }
    guard source == "host"
            || scope == HostDeviceScope.simulator.rawValue
            || scope == HostDeviceScope.emulator.rawValue
            || kind == "simulator"
            || kind == "emulator" else {
        return .unsupported
    }
    return .host(id: "host:\(platform):\(target)")
}

private func makeWebHostInputBridgeResponse(
    platform: String,
    target: String,
    scope: String? = nil,
    kind: String? = nil,
    source: String? = nil,
    input: TKInputRequest
) async throws -> TKInputResult {
    switch webHostInputBridgeRoute(
        platform: platform,
        target: target,
        scope: scope,
        kind: kind,
        source: source
    ) {
    case .host(let id):
        return try runWebHostDeviceInput(id: id, input: input)
    case .unsupported:
        return .unsupported(
            action: input.type.rawValue,
            message: "Web host input requires an iOS App runtime mirror or a supported iOS, Android, or Harmony host target."
        )
    case .runtimeMirror:
        break
    }
    var client = TritonKitHTTPClient(host: "127.0.0.1", port: 19421)
    let runtimeTargets: TKTargetsResponse = try await client.getJSON("/targets")
    let resolvedScope = scope ?? (kind == "simulator" || target.hasPrefix("sim:") ? HostDeviceScope.simulator.rawValue : HostDeviceScope.real.rawValue)
    let resolvedKind = kind ?? (resolvedScope == HostDeviceScope.simulator.rawValue ? "simulator" : "real-device")
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
        scope: resolvedScope,
        kind: resolvedKind
    ))
    if let runtimeTarget = webRuntimeInputFallbackTargetID(forHostID: hostID, runtimeTargets: runtimeTargets.targets) {
        client.target = runtimeTarget
    }
    return try await executeInputRequest(input, client: client)
}

private func isWebIOSRuntimeMirror(
    platform: HostDevicePlatform,
    scope: String?,
    kind: String?,
    source: String?,
    target: String? = nil
) -> Bool {
    platform == .ios && (
        source == "runtime"
            || scope == HostDeviceScope.real.rawValue
            || kind == "real-device"
            || target?.hasPrefix("ios-real:") == true
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

private func makePackagedWebIOSSimulatorMjpegResponse(_ streamRequest: PackagedWebIOSSimulatorMjpegRequest) -> Response {
    guard CLIHostSimulatorFramebufferService.shared.startStreaming(udid: streamRequest.udid) else {
        return jsonError(
            code: "web_ios_simulator_mjpeg_unavailable",
            message: "Unable to start host framebuffer streaming for simulator \(streamRequest.udid).",
            endpoint: "/web/ios-simulator/mjpeg",
            hint: "Verify the simulator is booted and available with `triton sim list --json`.",
            status: .conflict
        )
    }

    let headers: HTTPFields = [
        .contentType: "multipart/x-mixed-replace; boundary=\(streamRequest.boundary)",
        .cacheControl: "no-cache, no-store, must-revalidate",
        .connection: "close"
    ]
    let responseBody = ResponseBody { writer in
        defer {
            CLIHostSimulatorFramebufferService.shared.stopStreaming(udid: streamRequest.udid)
        }

        var lastSentVersion: UInt64 = 0
        var lastWriteTime = Date().timeIntervalSince1970
        while true {
            if let (jpegData, version) = CLIHostSimulatorFramebufferService.shared.getLatestFrameWithVersion(udid: streamRequest.udid) {
                let now = Date().timeIntervalSince1970
                if version != lastSentVersion || (now - lastWriteTime) >= 1.0 {
                    lastSentVersion = version
                    lastWriteTime = now

                    var buffer = ByteBuffer()
                    buffer.writeString("--\(streamRequest.boundary)\r\n")
                    buffer.writeString("Content-Type: image/jpeg\r\n")
                    buffer.writeString("Content-Length: \(jpegData.count)\r\n\r\n")
                    buffer.writeBytes(jpegData)
                    buffer.writeString("\r\n")

                    do {
                        try await writer.write(buffer)
                    } catch {
                        break
                    }
                }
            }

            try await Task.sleep(nanoseconds: UInt64(streamRequest.targetIntervalSeconds * 1_000_000_000))
        }

        try? await writer.finish(nil)
    }

    return Response(status: .ok, headers: headers, body: responseBody)
}

private func makePackagedWebIOSSimulatorFrameResponse(_ streamRequest: PackagedWebIOSSimulatorMjpegRequest) async -> Response {
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

private func runPackagedWebServer(_ plan: WebLaunchPlan) async throws {
    guard let webRoot = plan.bundledWebRoot else {
        throw WebCommandError.bundledWebRootNotFound(path: nil)
    }
    guard isValidBundledWebRoot(URL(fileURLWithPath: webRoot, isDirectory: true).standardizedFileURL) else {
        throw WebCommandError.bundledWebRootNotFound(path: webRoot)
    }

    let router = Router(context: BasicRequestContext.self)
    router.get("/") { request, _ -> Response in
        packagedWebResponse(webRoot: webRoot, requestPath: request.uri.path)
    }
    router.get("/web/host-targets") { _, _ -> Response in
        jsonResponse(makeWebHostTargetsBridgeResponse())
    }
    router.get("/web/target-registry") { _, _ -> Response in
        jsonResponse(await makePackagedWebTargetRegistryBridgeResponse())
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
            return jsonResponse(try makeWebHostHierarchyBridgeResponse(tritonBin: plan.tritonBin, platform: platform, target: target))
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
    router.get("/web/ios-simulator/mjpeg") { request, _ -> Response in
        do {
            let streamRequest = try makePackagedWebIOSSimulatorMjpegRequest(
                target: request.uri.queryParameters.get("target"),
                udid: request.uri.queryParameters.get("udid"),
                fps: request.uri.queryParameters.get("fps")
            )
            return makePackagedWebIOSSimulatorMjpegResponse(streamRequest)
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
            return jsonResponse(try makeWebHostLogsBridgeResponse(tritonBin: plan.tritonBin, platform: platform, target: target))
        } catch {
            return jsonError(code: "web_host_logs_failed", message: "\(error)", endpoint: "/web/host-logs", status: .conflict)
        }
    }
    router.post("/web/host-input") { request, _ -> Response in
        let platform = request.uri.queryParameters.get("platform") ?? ""
        let target = request.uri.queryParameters.get("target") ?? ""
        let scope = request.uri.queryParameters.get("scope")
        let kind = request.uri.queryParameters.get("kind")
        let source = request.uri.queryParameters.get("source")
        var bodyData = Data()
        for try await chunk in request.body {
            bodyData.append(Data(buffer: chunk))
        }
        guard let input = try? JSONDecoder().decode(TKInputRequest.self, from: bodyData) else {
            return jsonError(code: "invalid_payload", message: "Unsupported input payload", endpoint: "/web/host-input", status: .badRequest)
        }
        do {
            return jsonResponse(try await makeWebHostInputBridgeResponse(platform: platform, target: target, scope: scope, kind: kind, source: source, input: input))
        } catch {
            return jsonError(code: "web_host_input_failed", message: "\(error)", endpoint: "/web/host-input", status: .conflict)
        }
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

private func ensureWebPortAvailable(host: String, port: Int) throws {
    if isTCPPortListening(host: host, port: port) {
        throw WebCommandError.portInUse(host: host, port: port)
    }
}

func isTCPPortListening(host: String, port: Int) -> Bool {
    var hints = addrinfo(
        ai_flags: AI_NUMERICSERV,
        ai_family: AF_UNSPEC,
        ai_socktype: SOCK_STREAM,
        ai_protocol: 0,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil
    )
    var result: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(host, String(port), &hints, &result) == 0, let result else {
        return false
    }
    defer { freeaddrinfo(result) }

    var cursor: UnsafeMutablePointer<addrinfo>? = result
    while let info = cursor {
        let fd = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
        if fd >= 0 {
            let connected = connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen) == 0
            close(fd)
            if connected {
                return true
            }
        }
        cursor = info.pointee.ai_next
    }
    return false
}

private func probeWebService(host: String, port: Int) async -> WebServiceProbe {
    let urlString = webDeviceHubURL(host: host, port: port)
    guard let url = URL(string: urlString) else {
        return WebServiceProbe(
            url: urlString,
            reachable: false,
            statusCode: nil,
            contentType: nil,
            serviceKind: nil,
            detectedCode: "invalid_url",
            message: "Invalid Web Device Hub URL."
        )
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 1.0
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let body = String(data: data, encoding: .utf8) ?? ""
        let detectedCode = webProbeDetectedCode(body: body)
        return WebServiceProbe(
            url: urlString,
            reachable: true,
            statusCode: http?.statusCode,
            contentType: http?.value(forHTTPHeaderField: "Content-Type"),
            serviceKind: webProbeServiceKind(body: body, detectedCode: detectedCode),
            detectedCode: detectedCode,
            message: webProbeMessage(body: body, detectedCode: detectedCode)
        )
    } catch {
        return WebServiceProbe(
            url: urlString,
            reachable: false,
            statusCode: nil,
            contentType: nil,
            serviceKind: nil,
            detectedCode: nil,
            message: "\(error)"
        )
    }
}

private func webProbeDetectedCode(body: String) -> String? {
    if body.contains("web_static_asset_failed") {
        return "web_static_asset_failed"
    }
    return nil
}

private func webProbeServiceKind(body: String, detectedCode: String?) -> String? {
    if detectedCode == "web_static_asset_failed" || body.contains("Triton Web") || body.contains("TritonKit") {
        return "triton-web"
    }
    return nil
}

private func webProbeMessage(body: String, detectedCode: String?) -> String? {
    if detectedCode == "web_static_asset_failed" {
        return "Bundled Triton Web static assets were not found."
    }
    return body.isEmpty ? nil : String(body.prefix(240))
}

private func uniqueOrdered(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for value in values where !seen.contains(value) {
        seen.insert(value)
        result.append(value)
    }
    return result
}

private func htmlEscape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
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
