import Darwin
import Foundation
import TritonKitShared

enum NetworkProxyAction: String {
    case doctor = "proxy.doctor"
    case certDoctor = "proxy.cert.doctor"
    case certPlan = "proxy.cert.plan"
    case certInstall = "proxy.cert.install"
    case probe = "proxy.probe"
    case start = "proxy.start"
    case status = "proxy.status"
    case export = "proxy.export"
    case stop = "proxy.stop"
}

enum NetworkProxyLane: String, Codable, Equatable {
    case hostProxy = "host-proxy"
    case appRuntime = "app-runtime"
}

enum NetworkProxyVisibility: String, Codable, Equatable {
    case full
    case partial
    case none
    case unknown
}

struct NetworkProxyCertificate: Encodable, Equatable {
    let installed: Bool
    let trusted: Bool
    let scope: String
}

struct NetworkProxyRestore: Codable, Equatable {
    let available: Bool
    let snapshotPath: String?
    let restored: Bool?
}

struct NetworkProxyArtifact: Codable, Equatable {
    let kind: String
    let path: String
    let bytes: Int?
}

struct NetworkProxyProbeResult: Encodable, Equatable {
    let name: String
    let command: String
    let ok: Bool
    let exitCode: Int?
    let stdoutPreview: String?
    let stderrPreview: String?
    let stdoutTruncated: Bool
    let stderrTruncated: Bool
    let error: String?
}

struct NetworkProxySession: Encodable, Equatable {
    let ok: Bool
    let surface: String
    let action: String
    let platform: String
    let target: HostDeviceTarget?
    let lane: NetworkProxyLane
    let captureMode: String?
    let proxyEndpoint: String?
    let configured: Bool
    let cert: NetworkProxyCertificate?
    let visibility: NetworkProxyVisibility
    let limitations: [String]
    let artifacts: [NetworkProxyArtifact]
    let restore: NetworkProxyRestore?
    let sourceCommands: [String]
    let error: TKCLIErrorDetail?
    let redaction: String?
    let requestCount: Int?
    let truncation: String?
    let probeResults: [NetworkProxyProbeResult]?

    init(
        ok: Bool,
        surface: String,
        action: String,
        platform: String,
        target: HostDeviceTarget?,
        lane: NetworkProxyLane,
        captureMode: String?,
        proxyEndpoint: String?,
        configured: Bool,
        cert: NetworkProxyCertificate?,
        visibility: NetworkProxyVisibility,
        limitations: [String],
        artifacts: [NetworkProxyArtifact],
        restore: NetworkProxyRestore?,
        sourceCommands: [String],
        error: TKCLIErrorDetail?,
        redaction: String? = nil,
        requestCount: Int? = nil,
        truncation: String? = nil,
        probeResults: [NetworkProxyProbeResult]? = nil
    ) {
        self.ok = ok
        self.surface = surface
        self.action = action
        self.platform = platform
        self.target = target
        self.lane = lane
        self.captureMode = captureMode
        self.proxyEndpoint = proxyEndpoint
        self.configured = configured
        self.cert = cert
        self.visibility = visibility
        self.limitations = limitations
        self.artifacts = artifacts
        self.restore = restore
        self.sourceCommands = sourceCommands
        self.error = error
        self.redaction = redaction
        self.requestCount = requestCount
        self.truncation = truncation
        self.probeResults = probeResults
    }
}

struct NetworkProxyEndpoint: Equatable {
    let host: String
    let port: Int

    init(host: String, port: Int) throws {
        guard (1...65_535).contains(port), !host.isEmpty else {
            throw HostDeviceSelectionError.parameterConflict("Proxy endpoint must be host:port with a port between 1 and 65535.")
        }
        self.host = host
        self.port = port
    }

    init(_ value: String) throws {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let parsedPort = Int(parts[1]), (1...65_535).contains(parsedPort), !parts[0].isEmpty else {
            throw HostDeviceSelectionError.parameterConflict("Proxy endpoint must be host:port with a port between 1 and 65535.")
        }
        host = String(parts[0])
        port = parsedPort
    }
}

struct HostNetworkProxyServiceSnapshot: Codable, Equatable {
    let service: String
    let httpEnabled: Bool
    let httpHost: String
    let httpPort: Int
    let httpsEnabled: Bool
    let httpsHost: String
    let httpsPort: Int
    let socksEnabled: Bool
    let socksHost: String
    let socksPort: Int
    let bypassDomains: [String]
}

struct NetworkProxyStartRequest: Equatable {
    let platform: HostDevicePlatform
    let target: HostDeviceTarget
    let captureMode: String
    let outputDirectory: String
}

struct NetworkProxyExportRequest: Equatable {
    let platform: HostDevicePlatform
    let target: HostDeviceTarget
    let outputPath: String
}

struct NetworkProxyStopRequest: Equatable {
    let platform: HostDevicePlatform
    let target: HostDeviceTarget
    let restore: Bool
}

typealias NetworkProxyCommandRunner = (TKHostCommand) throws -> HostProcessResult
typealias NetworkProxyEndpointPreflight = (NetworkProxyEndpoint) throws -> Bool

struct NetworkProxyRestoreSnapshotPayload: Codable, Equatable {
    let schemaVersion: String
    let platform: String
    let target: String
    let proxyEndpoint: String?
    let auditRecord: String
    let snapshotCommands: [TKHostCommand]
    let startCommands: [TKHostCommand]
    let restoreCommands: [TKHostCommand]
    let snapshotSourceCommands: [String]
    let sourceCommands: [String]
    let restoreSourceCommands: [String]
    let services: [String]
    let serviceSnapshots: [HostNetworkProxyServiceSnapshot]
    let androidOriginalHTTPProxy: String?
}

struct NetworkProxySessionStatePayload: Codable, Equatable {
    let schemaVersion: String
    let platform: String
    let target: String
    let captureMode: String?
    let proxyEndpoint: String?
    let configured: Bool
    let visibility: NetworkProxyVisibility
    let limitations: [String]
    let artifacts: [NetworkProxyArtifact]
    let restoreSnapshotPath: String?
    let sourceCommands: [String]
}

struct NetworkProxyRestoreFailurePayload: Codable, Equatable {
    let schemaVersion: String
    let platform: String
    let target: String
    let action: String
    let auditRecord: String
    let restoreSnapshotPath: String
    let restoreSourceCommands: [String]
    let errorCode: String
    let errorSummary: String
    let capturedAt: String
}

private struct NetworkProxyCapturePayload: Encodable {
    let schemaVersion: String
    let platform: String
    let target: String
    let requestCount: Int
    let redaction: String
    let visibility: String
    let events: [String]
}

struct NetworkProxyCaptureExportSummary: Equatable {
    let requestCount: Int
    let redaction: String
    let truncation: String
}

private struct NetworkProxyCapturedRestorePlan {
    let snapshotCommands: [TKHostCommand]
    let restoreCommands: [TKHostCommand]
    let serviceSnapshots: [HostNetworkProxyServiceSnapshot]
    let androidOriginalHTTPProxy: String?
}

final class FakeNetworkProxyHostAdapter {
    private var activeSession: NetworkProxySession?
    private let proxyEndpoint = "127.0.0.1:19431"

    func start(_ request: NetworkProxyStartRequest) throws -> NetworkProxySession {
        if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .start, platform: request.platform, target: request.target, captureMode: request.captureMode) {
            return rejected
        }
        let outputURL = URL(fileURLWithPath: request.outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let restoreURL = outputURL.appendingPathComponent("restore-state.json")
        let captureURL = outputURL.appendingPathComponent("requests.ndjson")
        try JSONEncoder().encode(NetworkProxyRestoreSnapshotPayload(
            schemaVersion: "triton.proxy.restore.v1",
            platform: request.platform.rawValue,
            target: request.target.target,
            proxyEndpoint: proxyEndpoint,
            auditRecord: "fake-adapter",
            snapshotCommands: [],
            startCommands: [],
            restoreCommands: [],
            snapshotSourceCommands: [],
            sourceCommands: [],
            restoreSourceCommands: [],
            services: [],
            serviceSnapshots: [],
            androidOriginalHTTPProxy: nil
        )).write(to: restoreURL)
        try Data().write(to: captureURL)
        let session = NetworkProxySession(
            ok: true,
            surface: "host.device-proxy",
            action: NetworkProxyAction.start.rawValue,
            platform: request.platform.rawValue,
            target: request.target,
            lane: .hostProxy,
            captureMode: request.captureMode,
            proxyEndpoint: proxyEndpoint,
            configured: true,
            cert: NetworkProxyCertificate(installed: false, trusted: false, scope: "simulator"),
            visibility: .partial,
            limitations: networkProxyDoctorLimitations(platform: request.platform),
            artifacts: [NetworkProxyArtifact(kind: "network-capture", path: captureURL.path, bytes: 0)],
            restore: NetworkProxyRestore(available: true, snapshotPath: restoreURL.path, restored: nil),
            sourceCommands: [],
            error: nil
        )
        activeSession = session
        return session
    }

    func status(platform: HostDevicePlatform, target: HostDeviceTarget) -> NetworkProxySession {
        if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .status, platform: platform, target: target, captureMode: nil) {
            return rejected
        }
        guard let activeSession, activeSession.platform == platform.rawValue, activeSession.target == target else {
            return makeNetworkProxyStatusSession(platform: platform, target: target)
        }
        return NetworkProxySession(
            ok: true,
            surface: activeSession.surface,
            action: NetworkProxyAction.status.rawValue,
            platform: activeSession.platform,
            target: target,
            lane: activeSession.lane,
            captureMode: activeSession.captureMode,
            proxyEndpoint: activeSession.proxyEndpoint,
            configured: activeSession.configured,
            cert: activeSession.cert,
            visibility: activeSession.visibility,
            limitations: activeSession.limitations,
            artifacts: activeSession.artifacts,
            restore: activeSession.restore,
            sourceCommands: activeSession.sourceCommands,
            error: nil
        )
    }

    func export(_ request: NetworkProxyExportRequest) throws -> NetworkProxySession {
        if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .export, platform: request.platform, target: request.target, captureMode: nil) {
            return rejected
        }
        guard let activeSession, activeSession.platform == request.platform.rawValue, activeSession.target == request.target else {
            return makeNetworkProxyNotRunningSession(action: .export, platform: request.platform, target: request.target)
        }
        let outputURL = URL(fileURLWithPath: request.outputPath)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = try JSONEncoder().encode(NetworkProxyCapturePayload(
            schemaVersion: "triton.network.v1",
            platform: request.platform.rawValue,
            target: request.target.target,
            requestCount: 0,
            redaction: "default",
            visibility: NetworkProxyVisibility.partial.rawValue,
            events: []
        ))
        data.append(0x0A)
        try data.write(to: outputURL)
        return NetworkProxySession(
            ok: true,
            surface: activeSession.surface,
            action: NetworkProxyAction.export.rawValue,
            platform: activeSession.platform,
            target: request.target,
            lane: activeSession.lane,
            captureMode: activeSession.captureMode,
            proxyEndpoint: activeSession.proxyEndpoint,
            configured: activeSession.configured,
            cert: activeSession.cert,
            visibility: activeSession.visibility,
            limitations: activeSession.limitations,
            artifacts: [NetworkProxyArtifact(kind: "network-capture", path: outputURL.path, bytes: data.count)],
            restore: activeSession.restore,
            sourceCommands: activeSession.sourceCommands,
            error: nil
        )
    }

    func stop(_ request: NetworkProxyStopRequest) -> NetworkProxySession {
        if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .stop, platform: request.platform, target: request.target, captureMode: nil) {
            return rejected
        }
        let session = activeSession
        activeSession = nil
        return NetworkProxySession(
            ok: true,
            surface: "host.device-proxy",
            action: NetworkProxyAction.stop.rawValue,
            platform: request.platform.rawValue,
            target: request.target,
            lane: .hostProxy,
            captureMode: session?.captureMode,
            proxyEndpoint: session?.proxyEndpoint,
            configured: false,
            cert: session?.cert,
            visibility: .unknown,
            limitations: request.restore ? [] : ["proxy_restore_skipped"],
            artifacts: session?.artifacts ?? [],
            restore: NetworkProxyRestore(available: session?.restore?.available ?? false, snapshotPath: session?.restore?.snapshotPath, restored: request.restore),
            sourceCommands: session?.sourceCommands ?? [],
            error: nil
        )
    }
}

func networkSetupProxyOverrideCommands(service: String, endpoint: NetworkProxyEndpoint) -> [TKHostCommand] {
    [
        networkSetupCommand(["-setwebproxy", service, endpoint.host, String(endpoint.port)]),
        networkSetupCommand(["-setwebproxystate", service, "on"]),
        networkSetupCommand(["-setsecurewebproxy", service, endpoint.host, String(endpoint.port)]),
        networkSetupCommand(["-setsecurewebproxystate", service, "on"]),
        networkSetupCommand(["-setsocksfirewallproxystate", service, "off"]),
    ]
}

func networkSetupProxySnapshotCommands(service: String) -> [TKHostCommand] {
    [
        networkSetupReadonlyCommand(["-getwebproxy", service]),
        networkSetupReadonlyCommand(["-getsecurewebproxy", service]),
        networkSetupReadonlyCommand(["-getsocksfirewallproxy", service]),
        networkSetupReadonlyCommand(["-getproxybypassdomains", service]),
    ]
}

func networkSetupProxyRestoreCommands(snapshot: HostNetworkProxyServiceSnapshot) -> [TKHostCommand] {
    var commands: [TKHostCommand] = [
        networkSetupCommand(["-setwebproxystate", snapshot.service, "off"]),
        networkSetupCommand(["-setsecurewebproxystate", snapshot.service, "off"]),
        networkSetupCommand(["-setsocksfirewallproxystate", snapshot.service, "off"]),
    ]
    if snapshot.httpEnabled {
        commands.append(networkSetupCommand(["-setwebproxy", snapshot.service, snapshot.httpHost, String(snapshot.httpPort)]))
        commands.append(networkSetupCommand(["-setwebproxystate", snapshot.service, "on"]))
    }
    if snapshot.httpsEnabled {
        commands.append(networkSetupCommand(["-setsecurewebproxy", snapshot.service, snapshot.httpsHost, String(snapshot.httpsPort)]))
        commands.append(networkSetupCommand(["-setsecurewebproxystate", snapshot.service, "on"]))
    }
    if snapshot.socksEnabled {
        commands.append(networkSetupCommand(["-setsocksfirewallproxy", snapshot.service, snapshot.socksHost, String(snapshot.socksPort)]))
    }
    commands.append(networkSetupCommand(["-setsocksfirewallproxystate", snapshot.service, snapshot.socksEnabled ? "on" : "off"]))
    commands.append(networkSetupCommand(["-setproxybypassdomains", snapshot.service] + (snapshot.bypassDomains.isEmpty ? ["Empty"] : snapshot.bypassDomains)))
    return commands
}

func parseNetworkSetupServiceSnapshot(
    service: String,
    httpOutput: String,
    httpsOutput: String,
    socksOutput: String,
    bypassOutput: String
) throws -> HostNetworkProxyServiceSnapshot {
    let http = try parseNetworkSetupProxyOutput(httpOutput)
    let https = try parseNetworkSetupProxyOutput(httpsOutput)
    let socks = try parseNetworkSetupProxyOutput(socksOutput)
    return HostNetworkProxyServiceSnapshot(
        service: service,
        httpEnabled: http.enabled,
        httpHost: http.host,
        httpPort: http.port,
        httpsEnabled: https.enabled,
        httpsHost: https.host,
        httpsPort: https.port,
        socksEnabled: socks.enabled,
        socksHost: socks.host,
        socksPort: socks.port,
        bypassDomains: parseNetworkSetupBypassDomains(bypassOutput)
    )
}

private func parseNetworkSetupProxyOutput(_ output: String) throws -> (enabled: Bool, host: String, port: Int) {
    var values: [String: String] = [:]
    for line in output.split(whereSeparator: \.isNewline) {
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { continue }
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        values[key] = value
    }
    let enabled = (values["Enabled"] ?? "No").lowercased() == "yes"
    let host = values["Server"] ?? ""
    let portValue = values["Port"] ?? "0"
    guard let port = Int(portValue) else {
        throw HostDeviceSelectionError.parameterConflict("Unable to parse networksetup proxy port: \(portValue)")
    }
    return (enabled, host, port)
}

private func parseNetworkSetupBypassDomains(_ output: String) -> [String] {
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    if trimmed.lowercased().contains("aren't any bypass domains") {
        return []
    }
    return output
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

func networkSetupProxyClearCommands(service: String) -> [TKHostCommand] {
    [
        networkSetupCommand(["-setwebproxystate", service, "off"]),
        networkSetupCommand(["-setsecurewebproxystate", service, "off"]),
        networkSetupCommand(["-setsocksfirewallproxystate", service, "off"]),
    ]
}

private func networkSetupReadonlyCommand(_ arguments: [String]) -> TKHostCommand {
    TKHostCommand(
        executable: "/usr/sbin/networksetup",
        arguments: arguments,
        riskLevel: .readonly,
        requiredConfig: [.timeout],
        defaultTimeoutSeconds: 10
    )
}

private func networkSetupCommand(_ arguments: [String]) -> TKHostCommand {
    TKHostCommand(
        executable: "/usr/sbin/networksetup",
        arguments: arguments,
        riskLevel: .breakGlass,
        requiredConfig: [.auditRecord, .timeout],
        defaultTimeoutSeconds: 10
    )
}

func adbProxyOverrideCommands(serial: String, endpoint: NetworkProxyEndpoint, executable: String = "adb") -> [TKHostCommand] {
    let emulatorEndpoint = androidEmulatorProxyEndpoint(from: endpoint)
    return [
        adbProxyCommand(["-s", serial, "shell", "settings", "put", "global", "http_proxy", "\(emulatorEndpoint.host):\(emulatorEndpoint.port)"], executable: executable),
    ]
}

func adbProxySnapshotCommands(serial: String, executable: String = "adb") -> [TKHostCommand] {
    [
        adbProxyReadonlyCommand(["-s", serial, "shell", "settings", "get", "global", "http_proxy"], executable: executable),
    ]
}

func adbProxyRestoreCommands(serial: String, originalHTTPProxy: String? = nil, executable: String = "adb") -> [TKHostCommand] {
    if let originalHTTPProxy = originalHTTPProxy?.trimmingCharacters(in: .whitespacesAndNewlines),
       !originalHTTPProxy.isEmpty,
       originalHTTPProxy.lowercased() != "null" {
        return [
            adbProxyCommand(["-s", serial, "shell", "settings", "put", "global", "http_proxy", originalHTTPProxy], executable: executable),
        ]
    }
    return [
        adbProxyCommand(["-s", serial, "shell", "settings", "delete", "global", "http_proxy"], executable: executable),
    ]
}

private func adbProxyCommand(_ arguments: [String], executable: String) -> TKHostCommand {
    TKHostCommand(
        executable: executable,
        arguments: arguments,
        riskLevel: .breakGlass,
        requiredConfig: [.target, .timeout, .auditRecord],
        defaultTimeoutSeconds: 10
    )
}

private func adbProxyReadonlyCommand(_ arguments: [String], executable: String) -> TKHostCommand {
    TKHostCommand(
        executable: executable,
        arguments: arguments,
        riskLevel: .readonly,
        requiredConfig: [.target, .timeout],
        defaultTimeoutSeconds: 10
    )
}

func parseADBHTTPProxySetting(stdout: String) -> String? {
    let value = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.lowercased() != "null" else {
        return nil
    }
    return value
}

func harmonyProxyProbeCommands(target: String, executable: String = "hdc") -> [TKHostCommand] {
    [
        TKHarmonyHDCCommand.bootCompleted(target: target, executable: executable),
        TKHarmonyHDCCommand.shellProbe(target: target, executable: executable),
    ]
}

func androidEmulatorProxyEndpoint(from endpoint: NetworkProxyEndpoint) -> NetworkProxyEndpoint {
    let normalizedHost = endpoint.host.lowercased()
    guard ["127.0.0.1", "localhost", "::1"].contains(normalizedHost) else {
        return endpoint
    }
    return (try? NetworkProxyEndpoint(host: "10.0.2.2", port: endpoint.port)) ?? endpoint
}

func makeNetworkProxyStartPlanSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    captureMode: String,
    endpoint: NetworkProxyEndpoint
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .start, platform: platform, target: target, captureMode: captureMode) {
        return rejected
    }
    let commands = networkProxyStartPlanCommands(platform: platform, target: target, endpoint: endpoint)
    return NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.start.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: captureMode,
        proxyEndpoint: "\(endpoint.host):\(endpoint.port)",
        configured: false,
        cert: NetworkProxyCertificate(installed: false, trusted: false, scope: "simulator"),
        visibility: .partial,
        limitations: networkProxyDoctorLimitations(platform: platform) + ["proxy_plan_only:not_executed"],
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: commands.map(hostSourceCommand),
        error: nil
    )
}

func networkProxyStartPlanCommands(platform: HostDevicePlatform, target: HostDeviceTarget, endpoint: NetworkProxyEndpoint) -> [TKHostCommand] {
    switch platform {
    case .ios:
        return networkSetupProxyOverrideCommands(service: "Wi-Fi", endpoint: endpoint)
    case .android:
        return adbProxyOverrideCommands(serial: target.rawTarget, endpoint: endpoint)
    case .harmony:
        return harmonyProxyProbeCommands(target: target.rawTarget)
    }
}

func makeNetworkProxyStopPlanSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    restore: Bool,
    restoreSnapshotPath: String? = nil
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .stop, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    let snapshot = try restoreSnapshotPath.map(loadNetworkProxyRestoreSnapshot)
    let commands = snapshot?.restoreCommands ?? networkProxyStopPlanCommands(platform: platform, target: target, restore: restore)
    var limitations = networkProxyDoctorLimitations(platform: platform) + ["proxy_plan_only:not_executed"]
    if snapshot != nil {
        limitations.append("proxy_restore_snapshot_plan:original_value_ledger")
    }
    if platform == .harmony {
        limitations.append("proxy_restore_probe_only:no_verified_harmony_proxy_mutation")
    }
    return NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.stop.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: .unknown,
        limitations: limitations,
        artifacts: [],
        restore: NetworkProxyRestore(
            available: restore || snapshot != nil,
            snapshotPath: restoreSnapshotPath,
            restored: false
        ),
        sourceCommands: commands.map(hostSourceCommand),
        error: nil
    )
}

func networkProxyStopPlanCommands(platform: HostDevicePlatform, target: HostDeviceTarget, restore: Bool) -> [TKHostCommand] {
    guard restore else { return [] }
    switch platform {
    case .ios:
        return networkSetupProxyClearCommands(service: "Wi-Fi")
    case .android:
        return adbProxyRestoreCommands(serial: target.rawTarget)
    case .harmony:
        return harmonyProxyProbeCommands(target: target.rawTarget)
    }
}

func makeNetworkProxyExportPlanSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    outputPath: String
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .export, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    return NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.export.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: .unknown,
        limitations: networkProxyDoctorLimitations(platform: platform) + [
            "proxy_plan_only:not_executed",
            "proxy_export_plan_only:artifact_not_written",
        ],
        artifacts: [NetworkProxyArtifact(kind: "network-capture", path: outputPath, bytes: nil)],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: [],
        error: nil
    )
}

func makeNetworkProxyExportPlanOutputPath(_ output: String?) throws -> String {
    guard let output, !output.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("device proxy export --plan-only requires --output so the evidence artifact path is explicit.")
    }
    return output
}

func makeNetworkProxyExecutionPolicyRequiredSession(
    action: NetworkProxyAction,
    platform: HostDevicePlatform,
    target: HostDeviceTarget?,
    captureMode: String?,
    confirm: Bool,
    auditRecord: String?,
    executeRunner: Bool
) throws -> NetworkProxySession {
    let args = networkProxyPolicyNextActionArgs(
        action: action,
        platform: platform,
        target: target?.target ?? "<selector>",
        captureMode: captureMode
    )
    return NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: action.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: captureMode,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: .none,
        limitations: networkProxyDoctorLimitations(platform: platform) + [
            "proxy_execution_policy_required:confirm=\(confirm)",
            "proxy_execution_policy_required:auditRecord=\((auditRecord?.isEmpty == false) ? "present" : "missing")",
            "proxy_execution_policy_required:executeRunner=\(executeRunner)",
        ],
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: [],
        error: TKCLIErrorDetail(
            code: "destructive_action_requires_policy",
            message: "Host-side proxy \(action.rawValue) requires --confirm, --audit-record, and --execute-runner before any break-glass proxy mutation can run.",
            hint: "Inspect `--plan-only` output first, then rerun with `--confirm --audit-record <id> --execute-runner` only when the target and restore plan are intentional.",
            nextAction: TKCLINextAction(command: "device", args: args, category: "plan")
        )
    )
}

func makeNetworkProxyRunnerNotConfiguredSession(
    action: NetworkProxyAction,
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    captureMode: String?,
    sourceCommands: [String],
    auditRecord: String
) throws -> NetworkProxySession {
    return NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: action.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: captureMode,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: action == .start ? .partial : .unknown,
        limitations: networkProxyDoctorLimitations(platform: platform) + [
            "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
            "proxy_runner_not_configured:not_executed",
        ],
        artifacts: [],
        restore: NetworkProxyRestore(available: action == .stop, snapshotPath: nil, restored: action == .stop ? false : nil),
        sourceCommands: sourceCommands,
        error: TKCLIErrorDetail(
            code: "proxy_runner_not_configured",
            message: "Host-side proxy \(action.rawValue) has an accepted break-glass policy, but the real proxy command runner is not wired yet.",
            hint: "Use `--plan-only` for audit evidence, or continue with the platform runner implementation before executing proxy mutations.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", platform.rawValue, "--json"], category: "diagnose")
        )
    )
}

func makeNetworkProxyStartExecutedSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    captureMode: String,
    endpoint: NetworkProxyEndpoint,
    auditRecord: String,
    runner: NetworkProxyCommandRunner,
    endpointPreflight: NetworkProxyEndpointPreflight = { endpoint in canConnectNetworkProxyEndpoint(endpoint) },
    outputDirectory: String? = nil
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .start, platform: platform, target: target, captureMode: captureMode) {
        return rejected
    }
    if platform == .harmony {
        return try makeNetworkProxyUnverifiedPlatformSession(
            action: .start,
            platform: platform,
            target: target,
            captureMode: captureMode,
            auditRecord: auditRecord
        )
    }
    let commands = networkProxyStartPlanCommands(platform: platform, target: target, endpoint: endpoint)
    let sourceCommands = commands.map(hostSourceCommand)
    guard try endpointPreflight(endpoint) else {
        return makeNetworkProxyEndpointUnreachableSession(
            platform: platform,
            target: target,
            captureMode: captureMode,
            endpoint: endpoint,
            auditRecord: auditRecord,
            sourceCommands: sourceCommands
        )
    }
    var restoreSnapshotPath: String?
    do {
        let capturedRestorePlan: NetworkProxyCapturedRestorePlan
        if outputDirectory != nil {
            capturedRestorePlan = try captureNetworkProxyRestorePlan(platform: platform, target: target, runner: runner)
        } else {
            capturedRestorePlan = NetworkProxyCapturedRestorePlan(
                snapshotCommands: [],
                restoreCommands: networkProxyStopPlanCommands(platform: platform, target: target, restore: true),
                serviceSnapshots: [],
                androidOriginalHTTPProxy: nil
            )
        }
        restoreSnapshotPath = try writeNetworkProxyRestoreSnapshot(
            platform: platform,
            target: target,
            endpoint: endpoint,
            auditRecord: auditRecord,
            snapshotCommands: capturedRestorePlan.snapshotCommands,
            startCommands: commands,
            restoreCommands: capturedRestorePlan.restoreCommands,
            serviceSnapshots: capturedRestorePlan.serviceSnapshots,
            androidOriginalHTTPProxy: capturedRestorePlan.androidOriginalHTTPProxy,
            outputDirectory: outputDirectory
        )
        let captureArtifact = try writeNetworkProxyCapturePlaceholder(
            platform: platform,
            target: target,
            outputDirectory: outputDirectory
        )
        try runNetworkProxyCommands(commands, runner: runner)
        var limitations = networkProxyDoctorLimitations(platform: platform) + [
            "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
            "proxy_runner_executed:break_glass",
        ]
        if restoreSnapshotPath != nil {
            limitations.append("proxy_restore_snapshot_written")
        } else {
            limitations.append("proxy_restore_snapshot_pending:clear_only")
        }
        if outputDirectory != nil {
            limitations.append("proxy_session_state_written")
        }
        let session = NetworkProxySession(
            ok: true,
            surface: "host.device-proxy",
            action: NetworkProxyAction.start.rawValue,
            platform: platform.rawValue,
            target: target,
            lane: .hostProxy,
            captureMode: captureMode,
            proxyEndpoint: "\(endpoint.host):\(endpoint.port)",
            configured: true,
            cert: NetworkProxyCertificate(installed: false, trusted: false, scope: networkProxyCertificateScope(platform: platform)),
            visibility: .partial,
            limitations: limitations,
            artifacts: captureArtifact.map { [$0] } ?? [],
            restore: NetworkProxyRestore(available: true, snapshotPath: restoreSnapshotPath, restored: nil),
            sourceCommands: sourceCommands,
            error: nil
        )
        try writeNetworkProxySessionState(session, outputDirectory: outputDirectory)
        return session
    } catch {
        return makeNetworkProxyExecutionFailedSession(
            action: .start,
            platform: platform,
            target: target,
            captureMode: captureMode,
            auditRecord: auditRecord,
            sourceCommands: sourceCommands,
            restoreSnapshotPath: restoreSnapshotPath,
            errorCode: "proxy_start_failed",
            error: error
        )
    }
}

func writeNetworkProxyCapturePlaceholder(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    outputDirectory: String?
) throws -> NetworkProxyArtifact? {
    guard let outputDirectory, !outputDirectory.isEmpty else {
        return nil
    }
    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let captureURL = outputURL.appendingPathComponent("requests.ndjson")
    if !FileManager.default.fileExists(atPath: captureURL.path) {
        var data = try JSONEncoder().encode(NetworkProxyCapturePayload(
            schemaVersion: "triton.network.v1",
            platform: platform.rawValue,
            target: target.target,
            requestCount: 0,
            redaction: "default",
            visibility: NetworkProxyVisibility.partial.rawValue,
            events: []
        ))
        data.append(0x0A)
        try data.write(to: captureURL)
    }
    let bytes = (try? FileManager.default.attributesOfItem(atPath: captureURL.path)[.size] as? NSNumber)?.intValue
    return NetworkProxyArtifact(kind: "network-capture", path: captureURL.path, bytes: bytes)
}

func writeNetworkProxySessionState(_ session: NetworkProxySession, outputDirectory: String?) throws {
    guard let outputDirectory, !outputDirectory.isEmpty else {
        return
    }
    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let payload = NetworkProxySessionStatePayload(
        schemaVersion: "triton.proxy.session.v1",
        platform: session.platform,
        target: session.target?.target ?? "",
        captureMode: session.captureMode,
        proxyEndpoint: session.proxyEndpoint,
        configured: session.configured,
        visibility: session.visibility,
        limitations: session.limitations,
        artifacts: session.artifacts,
        restoreSnapshotPath: session.restore?.snapshotPath,
        sourceCommands: session.sourceCommands
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(payload).write(to: networkProxySessionStateURL(directory: outputDirectory))
}

func loadNetworkProxySessionState(directory: String) throws -> NetworkProxySessionStatePayload {
    let data = try Data(contentsOf: networkProxySessionStateURL(directory: directory))
    let payload = try JSONDecoder().decode(NetworkProxySessionStatePayload.self, from: data)
    guard payload.schemaVersion == "triton.proxy.session.v1" else {
        throw HostDeviceSelectionError.parameterConflict("Unsupported proxy session schema: \(payload.schemaVersion).")
    }
    return payload
}

func networkProxySessionStateURL(directory: String) -> URL {
    URL(fileURLWithPath: directory, isDirectory: true).appendingPathComponent("session-state.json")
}

private func captureNetworkProxyRestorePlan(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    runner: NetworkProxyCommandRunner
) throws -> NetworkProxyCapturedRestorePlan {
    switch platform {
    case .ios:
        let service = "Wi-Fi"
        let snapshotCommands = networkSetupProxySnapshotCommands(service: service)
        let results = try snapshotCommands.map { command -> HostProcessResult in
            let result = try runner(command)
            if result.exitCode != 0 {
                throw HostCommandRunError.nonZeroExit(command: command, result: result)
            }
            return result
        }
        let serviceSnapshot = try parseNetworkSetupServiceSnapshot(
            service: service,
            httpOutput: results[0].stdout,
            httpsOutput: results[1].stdout,
            socksOutput: results[2].stdout,
            bypassOutput: results[3].stdout
        )
        return NetworkProxyCapturedRestorePlan(
            snapshotCommands: snapshotCommands,
            restoreCommands: networkSetupProxyRestoreCommands(snapshot: serviceSnapshot),
            serviceSnapshots: [serviceSnapshot],
            androidOriginalHTTPProxy: nil
        )
    case .android:
        let snapshotCommands = adbProxySnapshotCommands(serial: target.rawTarget)
        let result = try runner(snapshotCommands[0])
        if result.exitCode != 0 {
            throw HostCommandRunError.nonZeroExit(command: snapshotCommands[0], result: result)
        }
        let originalHTTPProxy = parseADBHTTPProxySetting(stdout: result.stdout)
        return NetworkProxyCapturedRestorePlan(
            snapshotCommands: snapshotCommands,
            restoreCommands: adbProxyRestoreCommands(serial: target.rawTarget, originalHTTPProxy: originalHTTPProxy),
            serviceSnapshots: [],
            androidOriginalHTTPProxy: originalHTTPProxy
        )
    case .harmony:
        return NetworkProxyCapturedRestorePlan(
            snapshotCommands: [],
            restoreCommands: harmonyProxyProbeCommands(target: target.rawTarget),
            serviceSnapshots: [],
            androidOriginalHTTPProxy: nil
        )
    }
}

func canConnectNetworkProxyEndpoint(_ endpoint: NetworkProxyEndpoint, timeoutSeconds: TimeInterval = 1) -> Bool {
    var hints = addrinfo()
    hints.ai_socktype = SOCK_STREAM
    hints.ai_protocol = IPPROTO_TCP

    var result: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(endpoint.host, String(endpoint.port), &hints, &result) == 0, let result else {
        return false
    }
    defer { freeaddrinfo(result) }

    var cursor: UnsafeMutablePointer<addrinfo>? = result
    while let current = cursor {
        let fd = socket(current.pointee.ai_family, current.pointee.ai_socktype, current.pointee.ai_protocol)
        guard fd >= 0 else {
            cursor = current.pointee.ai_next
            continue
        }
        defer { close(fd) }

        let flags = fcntl(fd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }

        if connect(fd, current.pointee.ai_addr, current.pointee.ai_addrlen) == 0 {
            return true
        }

        if errno == EINPROGRESS {
            var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let timeoutMilliseconds = Int32(max(1, timeoutSeconds * 1_000))
            if poll(&descriptor, 1, timeoutMilliseconds) > 0 {
                var socketError: Int32 = 0
                var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
                if getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &socketErrorLength) == 0, socketError == 0 {
                    return true
                }
            }
        }

        cursor = current.pointee.ai_next
    }
    return false
}

private func makeNetworkProxyEndpointUnreachableSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    captureMode: String,
    endpoint: NetworkProxyEndpoint,
    auditRecord: String,
    sourceCommands: [String]
) -> NetworkProxySession {
    NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: NetworkProxyAction.start.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: captureMode,
        proxyEndpoint: "\(endpoint.host):\(endpoint.port)",
        configured: false,
        cert: nil,
        visibility: .none,
        limitations: networkProxyDoctorLimitations(platform: platform) + [
            "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
            "proxy_endpoint_unreachable:not_mutated",
        ],
        artifacts: [],
        restore: NetworkProxyRestore(available: true, snapshotPath: nil, restored: nil),
        sourceCommands: sourceCommands,
        error: TKCLIErrorDetail(
            code: "proxy_endpoint_unreachable",
            message: "Host-side proxy endpoint \(endpoint.host):\(endpoint.port) is not reachable, so TritonKit will not mutate simulator or emulator proxy settings.",
            hint: "Start the local proxy listener or pass a reachable --proxy host:port, then inspect --plan-only output before retrying --execute-runner.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", platform.rawValue, "--json"], category: "diagnose")
        )
    )
}

func makeNetworkProxyStopExecutedSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    restore: Bool,
    auditRecord: String,
    runner: NetworkProxyCommandRunner,
    restoreSnapshotPath: String? = nil
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .stop, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    if platform == .harmony {
        return try makeNetworkProxyUnverifiedPlatformSession(
            action: .stop,
            platform: platform,
            target: target,
            captureMode: nil,
            auditRecord: auditRecord
        )
    }
    let snapshot = try restoreSnapshotPath.map(loadNetworkProxyRestoreSnapshot)
    let commands = snapshot?.restoreCommands ?? networkProxyStopPlanCommands(platform: platform, target: target, restore: restore)
    let sourceCommands = commands.map(hostSourceCommand)
    do {
        try runNetworkProxyCommands(commands, runner: runner)
        var limitations = networkProxyDoctorLimitations(platform: platform) + [
            "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
            "proxy_runner_executed:break_glass",
        ]
        if snapshot != nil {
            limitations.append("proxy_restore_snapshot_used")
        }
        return NetworkProxySession(
            ok: true,
            surface: "host.device-proxy",
            action: NetworkProxyAction.stop.rawValue,
            platform: platform.rawValue,
            target: target,
            lane: .hostProxy,
            captureMode: nil,
            proxyEndpoint: nil,
            configured: false,
            cert: nil,
            visibility: .unknown,
            limitations: limitations,
            artifacts: [],
            restore: NetworkProxyRestore(available: restore || snapshot != nil, snapshotPath: restoreSnapshotPath, restored: (restore || snapshot != nil) ? true : nil),
            sourceCommands: sourceCommands,
            error: nil
        )
    } catch {
        let failureArtifact = writeNetworkProxyRestoreFailureArtifact(
            platform: platform,
            target: target,
            action: .stop,
            auditRecord: auditRecord,
            restoreSnapshotPath: restoreSnapshotPath,
            sourceCommands: sourceCommands,
            errorCode: "proxy_restore_failed",
            error: error
        )
        return makeNetworkProxyExecutionFailedSession(
            action: .stop,
            platform: platform,
            target: target,
            captureMode: nil,
            auditRecord: auditRecord,
            sourceCommands: sourceCommands,
            restoreSnapshotPath: restoreSnapshotPath,
            artifacts: Array(failureArtifact.map { [$0] } ?? []),
            errorCode: "proxy_restore_failed",
            error: error
        )
    }
}

private func runNetworkProxyCommands(_ commands: [TKHostCommand], runner: NetworkProxyCommandRunner) throws {
    for command in commands {
        let result = try runner(command)
        if result.exitCode != 0 {
            throw HostCommandRunError.nonZeroExit(command: command, result: result)
        }
    }
}

private func makeNetworkProxyExecutionFailedSession(
    action: NetworkProxyAction,
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    captureMode: String?,
    auditRecord: String,
    sourceCommands: [String],
    restoreSnapshotPath: String? = nil,
    artifacts: [NetworkProxyArtifact] = [],
    errorCode: String,
    error: Error
) -> NetworkProxySession {
    NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: action.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: captureMode,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: .none,
        limitations: networkProxyDoctorLimitations(platform: platform) + [
            "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
            "\(errorCode):\(networkProxyErrorSummary(error))",
        ] + (artifacts.isEmpty ? [] : ["proxy_restore_failure_artifact_written"]),
        artifacts: artifacts,
        restore: NetworkProxyRestore(available: action == .stop || restoreSnapshotPath != nil, snapshotPath: restoreSnapshotPath, restored: action == .stop ? false : nil),
        sourceCommands: sourceCommands,
        error: TKCLIErrorDetail(
            code: errorCode,
            message: "Host-side proxy \(action.rawValue) failed for \(platform.rawValue) target \(target.target).",
            hint: "Inspect sourceCommands, restore state, and platform doctor output before retrying the break-glass proxy action.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", platform.rawValue, "--json"], category: "diagnose")
        )
    )
}

private func writeNetworkProxyRestoreFailureArtifact(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    action: NetworkProxyAction,
    auditRecord: String,
    restoreSnapshotPath: String?,
    sourceCommands: [String],
    errorCode: String,
    error: Error
) -> NetworkProxyArtifact? {
    guard let restoreSnapshotPath, !restoreSnapshotPath.isEmpty else {
        return nil
    }
    let snapshotURL = URL(fileURLWithPath: restoreSnapshotPath)
    let outputURL = snapshotURL.deletingLastPathComponent().appendingPathComponent("restore-failure.json")
    let payload = NetworkProxyRestoreFailurePayload(
        schemaVersion: "triton.proxy.restore-failure.v1",
        platform: platform.rawValue,
        target: target.target,
        action: action.rawValue,
        auditRecord: auditRecord,
        restoreSnapshotPath: restoreSnapshotPath,
        restoreSourceCommands: sourceCommands,
        errorCode: errorCode,
        errorSummary: networkProxyErrorSummary(error),
        capturedAt: ISO8601DateFormatter().string(from: Date())
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: outputURL)
        let bytes = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.intValue
        return NetworkProxyArtifact(kind: "proxy-restore", path: outputURL.path, bytes: bytes)
    } catch {
        return nil
    }
}

func writeNetworkProxyRestoreSnapshot(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    endpoint: NetworkProxyEndpoint,
    auditRecord: String,
    snapshotCommands: [TKHostCommand] = [],
    startCommands: [TKHostCommand],
    restoreCommands: [TKHostCommand],
    serviceSnapshots: [HostNetworkProxyServiceSnapshot] = [],
    androidOriginalHTTPProxy: String? = nil,
    outputDirectory: String?
) throws -> String? {
    guard let outputDirectory, !outputDirectory.isEmpty else {
        return nil
    }
    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    let restoreURL = outputURL.appendingPathComponent("restore-state.json")
    let payload = NetworkProxyRestoreSnapshotPayload(
        schemaVersion: "triton.proxy.restore.v1",
        platform: platform.rawValue,
        target: target.target,
        proxyEndpoint: "\(endpoint.host):\(endpoint.port)",
        auditRecord: auditRecord,
        snapshotCommands: snapshotCommands,
        startCommands: startCommands,
        restoreCommands: restoreCommands,
        snapshotSourceCommands: snapshotCommands.map(hostSourceCommand),
        sourceCommands: startCommands.map(hostSourceCommand),
        restoreSourceCommands: restoreCommands.map(hostSourceCommand),
        services: serviceSnapshots.map(\.service),
        serviceSnapshots: serviceSnapshots,
        androidOriginalHTTPProxy: androidOriginalHTTPProxy
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(payload).write(to: restoreURL)
    return restoreURL.path
}

func loadNetworkProxyRestoreSnapshot(path: String) throws -> NetworkProxyRestoreSnapshotPayload {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let payload = try JSONDecoder().decode(NetworkProxyRestoreSnapshotPayload.self, from: data)
    guard payload.schemaVersion == "triton.proxy.restore.v1" else {
        throw HostDeviceSelectionError.parameterConflict("Unsupported proxy restore snapshot schema: \(payload.schemaVersion).")
    }
    return payload
}

private func networkProxyCertificateScope(platform: HostDevicePlatform) -> String {
    switch platform {
    case .ios:
        return "simulator"
    case .android, .harmony:
        return "emulator"
    }
}

func networkProxyConservativeCertificate(platform: HostDevicePlatform) -> NetworkProxyCertificate {
    NetworkProxyCertificate(installed: false, trusted: false, scope: networkProxyCertificateScope(platform: platform))
}

func networkProxyCertificatePlanCommands(platform: HostDevicePlatform, target: HostDeviceTarget, certificatePath: String) -> [TKHostCommand] {
    switch platform {
    case .ios:
        return [
            TKHostCommand(
                executable: "xcrun",
                arguments: ["simctl", "keychain", target.target, "add-root-cert", certificatePath],
                riskLevel: .breakGlass,
                requiredConfig: [.target, .timeout, .auditRecord]
            ),
        ]
    case .android:
        let remotePath = "/sdcard/Download/tritonkit-proxy-ca.cer"
        return [
            TKHostCommand(
                executable: "adb",
                arguments: ["-s", target.target, "push", certificatePath, remotePath],
                riskLevel: .breakGlass,
                requiredConfig: [.target, .timeout, .auditRecord],
                capturesArtifacts: true
            ),
            TKHostCommand(
                executable: "adb",
                arguments: [
                    "-s", target.target,
                    "shell", "am", "start",
                    "-a", "android.credentials.INSTALL",
                    "-t", "application/x-x509-ca-cert",
                    "-d", "file://\(remotePath)",
                ],
                riskLevel: .breakGlass,
                requiredConfig: [.target, .timeout, .auditRecord]
            ),
        ]
    case .harmony:
        return []
    }
}

private func networkProxyCertificateLimitations(platform: HostDevicePlatform) -> [String] {
    switch platform {
    case .ios:
        return [
            "proxy_cert_untrusted:plan_only_simulator_root_certificate_requires_manual_review",
            "proxy_tls_visibility_limited:host_proxy_records_metadata_until_certificate_trust_is_explicitly_installed",
        ]
    case .android:
        return [
            "proxy_cert_untrusted:plan_only_android_certificate_install_prompt_requires_manual_user_trust",
            "proxy_tls_visibility_limited:host_proxy_records_metadata_until_certificate_trust_is_explicitly_installed",
        ]
    case .harmony:
        return [
            "proxy_cert_untrusted:harmony_emulator_certificate_trust_command_not_verified",
            "proxy_cert_harmony_probe_only:no_verified_harmony_certificate_install_or_trust_mutation",
            "proxy_tls_visibility_limited:host_proxy_records_metadata_until_certificate_trust_is_explicitly_installed",
        ]
    }
}

private func networkProxyCertificateInstallLimitations(platform: HostDevicePlatform, auditRecord: String) -> [String] {
    let shared = [
        "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
        "proxy_cert_runner_executed:break_glass",
    ]
    switch platform {
    case .ios:
        return shared + [
            "proxy_cert_installed:simulator_root_trusted",
            "proxy_tls_visibility_limited:certificate_pinning_custom_transport_still_may_bypass_proxy",
        ]
    case .android:
        return shared + [
            "proxy_cert_install_prompt_opened:manual_user_trust_required",
            "proxy_tls_visibility_limited:android_user_ca_and_network_security_config_may_limit_https_visibility",
        ]
    case .harmony:
        return shared + networkProxyCertificateLimitations(platform: platform)
    }
}

private func networkProxyErrorSummary(_ error: Error) -> String {
    let raw = String(describing: error)
    let scalars = raw.unicodeScalars.map { scalar -> Character in
        CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "_"
    }
    let normalized = String(scalars)
        .split(separator: "_")
        .joined(separator: "_")
        .lowercased()
    return normalized.isEmpty ? "unknown" : String(normalized.prefix(120))
}

func makeNetworkProxyUnverifiedPlatformSession(
    action: NetworkProxyAction,
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    captureMode: String?,
    auditRecord: String
) throws -> NetworkProxySession {
    let sourceCommands = harmonyProxyProbeCommands(target: target.rawTarget).map(hostSourceCommand)
    return NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: action.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: captureMode,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: .none,
        limitations: networkProxyDoctorLimitations(platform: platform) + [
            "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
            "proxy_harmony_probe_only:no_verified_proxy_mutation",
        ],
        artifacts: [],
        restore: NetworkProxyRestore(available: action == .stop, snapshotPath: nil, restored: action == .stop ? false : nil),
        sourceCommands: sourceCommands,
        error: TKCLIErrorDetail(
            code: "proxy_unverified_platform_proxy",
            message: "Harmony / DevEco Emulator proxy mutation is not verified yet, so TritonKit will not execute inferred proxy commands.",
            hint: "Run doctor/status and keep Harmony on the probe-only path until a real DevEco proxy setting command is verified.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", "harmony", "--json"], category: "diagnose")
        )
    )
}

func makeNetworkProxyUnverifiedCertificatePlatformSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    auditRecord: String
) throws -> NetworkProxySession {
    let sourceCommands = harmonyProxyProbeCommands(target: target.rawTarget).map(hostSourceCommand)
    return NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: NetworkProxyAction.certInstall.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: networkProxyConservativeCertificate(platform: platform),
        visibility: .none,
        limitations: networkProxyCertificateLimitations(platform: platform) + [
            "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
        ],
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: sourceCommands,
        error: TKCLIErrorDetail(
            code: "proxy_unverified_platform_proxy",
            message: "Harmony / DevEco Emulator certificate trust mutation is not verified yet, so TritonKit will not execute inferred certificate install commands.",
            hint: "Run proxy cert doctor/plan and keep Harmony on the probe-only path until a real DevEco certificate trust command is verified.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "cert", "doctor", "--platform", "harmony", "--json"], category: "diagnose")
        )
    )
}

private func networkProxyPolicyNextActionArgs(action: NetworkProxyAction, platform: HostDevicePlatform, target: String, captureMode: String?) -> [String] {
    switch action {
    case .certDoctor:
        return ["proxy", "cert", "doctor", "--platform", platform.rawValue, "--json"]
    case .certPlan:
        return ["proxy", "cert", "plan", "--platform", platform.rawValue, "--device", target, "--certificate", "<path.cer>", "--json"]
    case .certInstall:
        return ["proxy", "cert", "install", "--platform", platform.rawValue, "--device", target, "--certificate", "<path.cer>", "--confirm", "--audit-record", "<id>", "--execute-runner", "--json"]
    case .probe:
        return ["proxy", "probe", "--platform", platform.rawValue, "--device", target, "--json"]
    case .start:
        return ["proxy", "start", "--platform", platform.rawValue, "--device", target, "--mode", captureMode ?? "record", "--confirm", "--audit-record", "<id>", "--execute-runner", "--json"]
    case .stop:
        return ["proxy", "stop", "--platform", platform.rawValue, "--device", target, "--restore", "--confirm", "--audit-record", "<id>", "--execute-runner", "--json"]
    case .export:
        return ["proxy", "export", "--platform", platform.rawValue, "--device", target, "--output", "<path.har|path.ndjson>", "--json"]
    case .doctor:
        return ["proxy", "doctor", "--platform", platform.rawValue, "--json"]
    case .status:
        return ["proxy", "status", "--platform", platform.rawValue, "--device", target, "--json"]
    }
}

func makeNetworkProxyPlanTarget(platform: HostDevicePlatform, device: String?) throws -> HostDeviceTarget {
    guard let device, !device.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("device proxy --plan-only requires --device so the platform plan can bind a target.")
    }
    let resolved = try resolveNetworkProxyPlanDevice(platform: platform, selector: device)
    if resolved.isRealDevice {
        return makeNetworkProxyRealDevicePlanTarget(platform: platform, device: resolved.target)
    }
    switch platform {
    case .ios:
        return makeSimulatorProxyTarget(simulator: resolved.target)
    case .android:
        return HostDeviceTarget(
            platform: "android",
            id: "android:\(resolved.target)",
            target: resolved.target,
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )
    case .harmony:
        return HostDeviceTarget(
            platform: "harmony",
            id: "harmony:\(resolved.target)",
            target: resolved.target,
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )
    }
}

private struct NetworkProxyPlanDeviceResolution {
    let target: String
    let isRealDevice: Bool
}

private func resolveNetworkProxyPlanDevice(
    platform: HostDevicePlatform,
    selector: String
) throws -> NetworkProxyPlanDeviceResolution {
    let aliases = try loadHostTargetAliasStore()
    return try resolveNetworkProxyPlanDevice(
        platform: platform,
        selector: selector,
        aliases: aliases,
        visited: []
    )
}

private func resolveNetworkProxyPlanDevice(
    platform: HostDevicePlatform,
    selector: String,
    aliases: HostTargetAliasStore,
    visited: Set<String>
) throws -> NetworkProxyPlanDeviceResolution {
    if selector == "current" {
        guard let current = aliases.current, !visited.contains(current) else {
            throw HostDeviceSelectionError.targetNotFound("current")
        }
        return try resolveNetworkProxyPlanDevice(
            platform: platform,
            selector: current,
            aliases: aliases,
            visited: visited.union([selector])
        )
    }

    if let alias = aliases.aliases[selector] {
        guard alias.platform == platform else {
            throw HostDeviceSelectionError.platformMismatch(
                selector: selector,
                expected: platform,
                actual: alias.platform
            )
        }
        let isReal = alias.scope == .real || alias.kind == "real-device" || isNetworkProxyRealDeviceSelector(alias.target)
        let target = isReal ? alias.target : normalizeNetworkProxyPlanTarget(platform: platform, target: alias.target)
        return NetworkProxyPlanDeviceResolution(target: target, isRealDevice: isReal)
    }

    return NetworkProxyPlanDeviceResolution(
        target: normalizeNetworkProxyPlanTarget(platform: platform, target: selector),
        isRealDevice: isNetworkProxyRealDeviceSelector(selector)
    )
}

private func normalizeNetworkProxyPlanTarget(platform: HostDevicePlatform, target: String) -> String {
    switch platform {
    case .ios:
        return target.removingNetworkProxyPrefix("sim:")
    case .android:
        return target.removingNetworkProxyPrefix("android:")
    case .harmony:
        return target.removingNetworkProxyPrefix("harmony:")
    }
}

private extension String {
    func removingNetworkProxyPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return String(dropFirst(prefix.count))
    }
}

private func isNetworkProxyRealDeviceSelector(_ device: String) -> Bool {
    ["ios-real:", "android-real:", "harmony-real:"].contains { device.hasPrefix($0) }
}

private func makeNetworkProxyRealDevicePlanTarget(platform: HostDevicePlatform, device: String) -> HostDeviceTarget {
    HostDeviceTarget(
        platform: platform.rawValue,
        id: device,
        target: device,
        state: "Unknown",
        ready: false,
        source: "proxy-plan",
        name: nil,
        runtime: nil,
        transport: nil,
        scope: "real",
        kind: "real-device",
        sensitive: true,
        rawTarget: device
    )
}

func makeNetworkProxyDoctorSession(platform: HostDevicePlatform) -> NetworkProxySession {
    NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.doctor.rawValue,
        platform: platform.rawValue,
        target: nil,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: networkProxyConservativeCertificate(platform: platform),
        visibility: .partial,
        limitations: networkProxyDoctorLimitations(platform: platform),
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: [],
        error: nil
    )
}

func makeNetworkProxyCertificateDoctorSession(platform: HostDevicePlatform) -> NetworkProxySession {
    NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.certDoctor.rawValue,
        platform: platform.rawValue,
        target: nil,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: networkProxyConservativeCertificate(platform: platform),
        visibility: .partial,
        limitations: networkProxyCertificateLimitations(platform: platform),
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: [],
        error: nil
    )
}

func makeNetworkProxyCertificatePlanSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    certificatePath: String
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .certPlan, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    let commands = networkProxyCertificatePlanCommands(platform: platform, target: target, certificatePath: certificatePath)
    return NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.certPlan.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: networkProxyConservativeCertificate(platform: platform),
        visibility: .partial,
        limitations: networkProxyCertificateLimitations(platform: platform),
        artifacts: [NetworkProxyArtifact(kind: "proxy-certificate", path: certificatePath, bytes: nil)],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: commands.map(hostSourceCommand),
        error: nil
    )
}

func makeNetworkProxyCertificateInstallExecutedSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    certificatePath: String,
    auditRecord: String,
    runner: NetworkProxyCommandRunner
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .certInstall, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    if platform == .harmony {
        return try makeNetworkProxyUnverifiedCertificatePlatformSession(
            platform: platform,
            target: target,
            auditRecord: auditRecord
        )
    }

    let commands = networkProxyCertificatePlanCommands(platform: platform, target: target, certificatePath: certificatePath)
    let sourceCommands = commands.map(hostSourceCommand)
    let certificateURL = URL(fileURLWithPath: certificatePath)
    let artifact = NetworkProxyArtifact(kind: "proxy-certificate", path: certificatePath, bytes: networkProxyFileByteCount(certificateURL))
    do {
        try runNetworkProxyCommands(commands, runner: runner)
        return NetworkProxySession(
            ok: true,
            surface: "host.device-proxy",
            action: NetworkProxyAction.certInstall.rawValue,
            platform: platform.rawValue,
            target: target,
            lane: .hostProxy,
            captureMode: nil,
            proxyEndpoint: nil,
            configured: false,
            cert: platform == .ios
                ? NetworkProxyCertificate(installed: true, trusted: true, scope: networkProxyCertificateScope(platform: platform))
                : networkProxyConservativeCertificate(platform: platform),
            visibility: .partial,
            limitations: networkProxyCertificateInstallLimitations(platform: platform, auditRecord: auditRecord),
            artifacts: [artifact],
            restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
            sourceCommands: sourceCommands,
            error: nil
        )
    } catch {
        return NetworkProxySession(
            ok: false,
            surface: "host.device-proxy",
            action: NetworkProxyAction.certInstall.rawValue,
            platform: platform.rawValue,
            target: target,
            lane: .hostProxy,
            captureMode: nil,
            proxyEndpoint: nil,
            configured: false,
            cert: networkProxyConservativeCertificate(platform: platform),
            visibility: .none,
            limitations: networkProxyCertificateLimitations(platform: platform) + [
                "proxy_execution_policy_accepted:auditRecord=\(auditRecord)",
                "proxy_cert_install_failed:\(networkProxyErrorSummary(error))",
            ],
            artifacts: [artifact],
            restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
            sourceCommands: sourceCommands,
            error: TKCLIErrorDetail(
                code: "proxy_cert_install_failed",
                message: "Host-side proxy certificate install failed for \(platform.rawValue) target \(target.target).",
                hint: "Inspect sourceCommands and platform certificate doctor output before retrying the break-glass certificate action.",
                nextAction: TKCLINextAction(command: "device", args: ["proxy", "cert", "doctor", "--platform", platform.rawValue, "--json"], category: "diagnose")
            )
        )
    }
}

func makeNetworkProxyStatusSession(platform: HostDevicePlatform, target: HostDeviceTarget?) -> NetworkProxySession {
    if let target, let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .status, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    return NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.status.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: networkProxyConservativeCertificate(platform: platform),
        visibility: .unknown,
        limitations: ["proxy_session_not_running"],
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: [],
        error: nil
    )
}

func makeNetworkProxyStatusSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    sessionDirectory: String?
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .status, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    guard let sessionDirectory, !sessionDirectory.isEmpty else {
        return makeNetworkProxyStatusSession(platform: platform, target: target)
    }
    let state = try loadNetworkProxySessionState(directory: sessionDirectory)
    try validateNetworkProxySessionState(state, platform: platform, target: target)
    let artifacts = networkProxySessionArtifactsIncludingRestoreFailure(
        state: state,
        sessionDirectory: sessionDirectory
    )
    return NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.status.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: state.captureMode,
        proxyEndpoint: state.proxyEndpoint,
        configured: state.configured,
        cert: NetworkProxyCertificate(installed: false, trusted: false, scope: networkProxyCertificateScope(platform: platform)),
        visibility: state.visibility,
        limitations: state.limitations,
        artifacts: artifacts,
        restore: NetworkProxyRestore(available: state.restoreSnapshotPath != nil, snapshotPath: state.restoreSnapshotPath, restored: nil),
        sourceCommands: state.sourceCommands,
        error: nil
    )
}

private func networkProxySessionArtifactsIncludingRestoreFailure(
    state: NetworkProxySessionStatePayload,
    sessionDirectory: String
) -> [NetworkProxyArtifact] {
    if state.artifacts.contains(where: { $0.kind == "proxy-restore" }) {
        return state.artifacts
    }
    guard let restoreFailureURL = networkProxyRestoreFailureURL(
        state: state,
        sessionDirectory: sessionDirectory
    ) else {
        return state.artifacts
    }
    var artifacts = state.artifacts
    artifacts.append(NetworkProxyArtifact(
        kind: "proxy-restore",
        path: restoreFailureURL.path,
        bytes: networkProxyFileByteCount(restoreFailureURL)
    ))
    return artifacts
}

private func networkProxyRestoreFailureURL(
    state: NetworkProxySessionStatePayload,
    sessionDirectory: String
) -> URL? {
    var candidates: [URL] = []
    if let restoreSnapshotPath = state.restoreSnapshotPath, !restoreSnapshotPath.isEmpty {
        candidates.append(URL(fileURLWithPath: restoreSnapshotPath).deletingLastPathComponent().appendingPathComponent("restore-failure.json"))
    }
    candidates.append(URL(fileURLWithPath: sessionDirectory, isDirectory: true).appendingPathComponent("restore-failure.json"))

    var seen = Set<String>()
    for candidate in candidates where seen.insert(candidate.path).inserted {
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
    }
    return nil
}

private func networkProxyFileByteCount(_ url: URL) -> Int? {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
}

func makeNetworkProxyExportSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    sessionDirectory: String?,
    outputPath: String?
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .export, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    guard let sessionDirectory, !sessionDirectory.isEmpty else {
        return makeNetworkProxyUnsupportedSession(action: .export, platform: platform, target: target)
    }
    guard let outputPath, !outputPath.isEmpty else {
        throw HostDeviceSelectionError.parameterConflict("device proxy export requires --output so the network artifact path is explicit.")
    }
    let state = try loadNetworkProxySessionState(directory: sessionDirectory)
    try validateNetworkProxySessionState(state, platform: platform, target: target)
    guard let sourceArtifact = state.artifacts.first(where: { $0.kind == "network-capture" }) else {
        return makeNetworkProxyNotRunningSession(action: .export, platform: platform, target: target)
    }
    let sourceURL = URL(fileURLWithPath: sourceArtifact.path)
    let outputURL = URL(fileURLWithPath: outputPath)
    let byteCount: Int
    let exportSummary: NetworkProxyCaptureExportSummary
    do {
        exportSummary = try summarizeNetworkProxyCaptureArtifact(sourceURL: sourceURL)
        byteCount = try exportNetworkProxyCaptureArtifact(sourceURL: sourceURL, outputURL: outputURL)
    } catch {
        return makeNetworkProxyArtifactWriteFailedSession(
            platform: platform,
            target: target,
            state: state,
            outputPath: outputPath,
            error: error
        )
    }
    return NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.export.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: state.captureMode,
        proxyEndpoint: state.proxyEndpoint,
        configured: state.configured,
        cert: NetworkProxyCertificate(installed: false, trusted: false, scope: networkProxyCertificateScope(platform: platform)),
        visibility: state.visibility,
        limitations: state.limitations,
        artifacts: [NetworkProxyArtifact(kind: "network-capture", path: outputURL.path, bytes: byteCount)],
        restore: NetworkProxyRestore(available: state.restoreSnapshotPath != nil, snapshotPath: state.restoreSnapshotPath, restored: nil),
        sourceCommands: state.sourceCommands,
        error: nil,
        redaction: exportSummary.redaction,
        requestCount: exportSummary.requestCount,
        truncation: exportSummary.truncation
    )
}

private func makeNetworkProxyArtifactWriteFailedSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    state: NetworkProxySessionStatePayload,
    outputPath: String,
    error: Error
) -> NetworkProxySession {
    NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: NetworkProxyAction.export.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: state.captureMode,
        proxyEndpoint: state.proxyEndpoint,
        configured: state.configured,
        cert: NetworkProxyCertificate(installed: false, trusted: false, scope: networkProxyCertificateScope(platform: platform)),
        visibility: .none,
        limitations: state.limitations + [
            "proxy_artifact_write_failed:\(networkProxyErrorSummary(error))",
        ],
        artifacts: [NetworkProxyArtifact(kind: "network-capture", path: outputPath, bytes: nil)],
        restore: NetworkProxyRestore(available: state.restoreSnapshotPath != nil, snapshotPath: state.restoreSnapshotPath, restored: nil),
        sourceCommands: state.sourceCommands,
        error: TKCLIErrorDetail(
            code: "proxy_artifact_write_failed",
            message: "Host-side proxy export could not write the requested network capture artifact.",
            hint: "Choose a writable --output path, then rerun proxy export with the same --session directory.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "export", "--platform", platform.rawValue, "--device", target.target, "--session", "<dir>", "--output", "<path.har|path.ndjson>", "--json"], category: "archive")
        )
    )
}

private func validateNetworkProxySessionState(
    _ state: NetworkProxySessionStatePayload,
    platform: HostDevicePlatform,
    target: HostDeviceTarget
) throws {
    guard state.platform == platform.rawValue else {
        throw HostDeviceSelectionError.parameterConflict("Proxy session platform \(state.platform) does not match requested platform \(platform.rawValue).")
    }
    guard state.target == target.target else {
        throw HostDeviceSelectionError.parameterConflict("Proxy session target \(state.target) does not match requested target \(target.target).")
    }
}

func makeNetworkProxyRealDeviceNotSupportedSession(
    action: NetworkProxyAction,
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    captureMode: String?
) -> NetworkProxySession? {
    guard isNetworkProxyRealDeviceTarget(target) else {
        return nil
    }
    return NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: action.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: captureMode,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: .none,
        limitations: networkProxyDoctorLimitations(platform: platform) + [
            "proxy_scope_emulator_only:real_device_not_supported",
        ],
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: [],
        error: TKCLIErrorDetail(
            code: "proxy_real_device_not_supported",
            message: "Host-side proxy \(action.rawValue) is scoped to local simulators and emulators; real-device proxy takeover is outside the current TritonKit boundary.",
            hint: "Select an iOS Simulator, Android Emulator, or Harmony / DevEco Emulator target, or create a separate real-device network takeover space before changing this boundary.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", platform.rawValue, "--json"], category: "diagnose")
        )
    )
}

private func isNetworkProxyRealDeviceTarget(_ target: HostDeviceTarget) -> Bool {
    target.scope == "real" || target.kind == "real-device"
}

func makeNetworkProxyUnsupportedSession(
    action: NetworkProxyAction,
    platform: HostDevicePlatform,
    target: HostDeviceTarget? = nil,
    captureMode: String? = nil
) -> NetworkProxySession {
    NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: action.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: captureMode,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: .none,
        limitations: networkProxyDoctorLimitations(platform: platform),
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: [],
        error: TKCLIErrorDetail(
            code: "proxy_platform_not_supported",
            message: "Host-side proxy \(action.rawValue) is not implemented for \(platform.rawValue) yet.",
            hint: "Run `triton device proxy doctor --platform \(platform.rawValue) --json` to inspect the current contract, or continue with the planned platform adapter slice.",
            nextAction: TKCLINextAction(command: "plan", args: ["--format", "json"])
        )
    )
}

func makeNetworkProxyNotRunningSession(
    action: NetworkProxyAction,
    platform: HostDevicePlatform,
    target: HostDeviceTarget
) -> NetworkProxySession {
    NetworkProxySession(
        ok: false,
        surface: "host.device-proxy",
        action: action.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: nil,
        visibility: .none,
        limitations: ["proxy_session_not_running"],
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: [],
        error: TKCLIErrorDetail(
            code: "proxy_not_running",
            message: "No host-side proxy session is running for \(platform.rawValue) target \(target.target).",
            hint: "Start a proxy session before exporting captured network traffic.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "start", "--platform", platform.rawValue, "--device", target.target, "--mode", "record", "--json"])
        )
    )
}

func makeSimulatorProxyTarget(simulator: String) -> HostDeviceTarget {
    HostDeviceTarget(
        platform: HostDevicePlatform.ios.rawValue,
        id: "sim:\(simulator)",
        target: simulator,
        state: simulator == "booted" ? "Booted" : "Unknown",
        ready: simulator == "booted",
        source: "sim-proxy-alias",
        name: nil,
        runtime: nil,
        transport: nil,
        scope: "simulator",
        kind: "simulator",
        blockedReasons: []
    )
}

func networkProxyDoctorLimitations(platform: HostDevicePlatform) -> [String] {
    switch platform {
    case .ios:
        return [
            "proxy_visibility_limited: Certificate pinning, custom sockets, private encrypted protocols, and unsupported QUIC paths may bypass host-side proxy visibility.",
            "proxy_runtime_not_required: App-internal network capture remains an explicit opt-in lane and is not required for host-side proxy takeover.",
        ]
    case .android:
        return [
            "proxy_visibility_limited: Android user CA trust, network security config, certificate pinning, custom sockets, and private encrypted protocols may limit HTTPS visibility.",
            "proxy_runtime_not_required: App-internal interceptors remain explicit opt-in and are not installed by TritonKit.",
        ]
    case .harmony:
        return [
            "proxy_visibility_limited: DevEco/Harmony proxy and certificate configuration still require real emulator verification before start can be supported.",
            "proxy_runtime_not_required: Harmony app-runtime network providers remain explicit opt-in and are not required for host-side doctor/status.",
        ]
    }
}
