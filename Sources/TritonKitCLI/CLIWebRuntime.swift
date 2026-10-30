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
        ([executable] + arguments).map(webShellQuote).joined(separator: " ")
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
        managedServeHost: "127.0.0.1"
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

func isValidBundledWebRoot(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.appendingPathComponent("index.html").path)
}

func runWebProcess(
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

func webShellQuote(_ value: String) -> String {
    guard !value.isEmpty else {
        return "''"
    }
    let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-")
    if value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
        return value
    }
    return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
