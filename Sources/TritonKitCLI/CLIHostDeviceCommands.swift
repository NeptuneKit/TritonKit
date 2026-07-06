import ArgumentParser
import Foundation
import TritonKitShared

// MARK: - Cross-Platform Host Device Commands

struct Device: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "device",
        abstract: "Discover and inspect host-side devices and emulators",
        subcommands: [DeviceDoctor.self, DeviceBridge.self, DeviceProxy.self, DeviceList.self, DeviceAlias.self, DeviceUse.self, DeviceCurrent.self, DeviceResolve.self, DeviceWaitReady.self, DeviceScreenshot.self, DeviceRuntimeURL.self, DeviceStart.self, DeviceStop.self]
    )
}

struct DeviceBridge: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bridge",
        abstract: "Inspect Android Emulator strong-control bridge contract",
        subcommands: [DeviceBridgeStatus.self, DeviceBridgeProbe.self, DeviceBridgeInstall.self, DeviceBridgeForward.self]
    )
}

struct DeviceBridgeStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Return the Android bridge status probe plan")

    @Option(help: "Platform adapter, currently android only") var platform: HostDevicePlatform = .android
    @Option(help: "Android adb serial or alias") var device: String
    @Option(help: "ADB executable path") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printHostDeviceBridgeOutput(
            makeAndroidBridgeStatusOutput(platform: platform, device: device, adb: adb, runner: { command in try runHostCommand(command) }),
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct DeviceBridgeProbe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "probe", abstract: "Return the Android bridge local HTTP probe plan")

    @Option(help: "Platform adapter, currently android only") var platform: HostDevicePlatform = .android
    @Option(help: "Android adb serial or alias") var device: String
    @Option(help: "Local forwarded bridge port") var localPort: Int = 19422
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printHostDeviceBridgeOutput(
            makeAndroidBridgeProbeOutput(platform: platform, device: device, localPort: localPort, runner: { command in try runHostCommand(command) }),
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct DeviceBridgeInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Plan Android bridge APK installation")

    @Option(help: "Platform adapter, currently android only") var platform: HostDevicePlatform = .android
    @Option(help: "Android adb serial or alias") var device: String
    @Option(help: "Path to Triton Android bridge APK") var apk: String
    @Option(help: "ADB executable path") var adb: String = "adb"
    @Flag(help: "Confirm reviewed bridge mutation") var confirm = false
    @Option(help: "Audit record id required for bridge mutation") var auditRecord: String?
    @Flag(help: "Execute the bridge command runner after confirmation") var executeRunner = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printHostDeviceBridgeOutput(
            makeAndroidBridgeInstallOutput(
                platform: platform,
                device: device,
                apkPath: apk,
                adb: adb,
                confirm: confirm,
                auditRecord: auditRecord,
                executeRunner: executeRunner,
                runner: { command in try runHostCommand(command) }
            ),
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct DeviceBridgeForward: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "forward", abstract: "Plan Android bridge adb port forwarding")

    @Option(help: "Platform adapter, currently android only") var platform: HostDevicePlatform = .android
    @Option(help: "Android adb serial or alias") var device: String
    @Option(help: "ADB executable path") var adb: String = "adb"
    @Option(help: "Local forwarded bridge port") var localPort: Int = 19422
    @Option(help: "Remote bridge service port") var remotePort: Int = 8080
    @Flag(help: "Confirm reviewed bridge mutation") var confirm = false
    @Option(help: "Audit record id required for bridge mutation") var auditRecord: String?
    @Flag(help: "Execute the bridge command runner after confirmation") var executeRunner = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printHostDeviceBridgeOutput(
            makeAndroidBridgeForwardOutput(
                platform: platform,
                device: device,
                adb: adb,
                localPort: localPort,
                remotePort: remotePort,
                confirm: confirm,
                auditRecord: auditRecord,
                executeRunner: executeRunner,
                runner: { command in try runHostCommand(command) }
            ),
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct DeviceProxy: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "proxy",
        abstract: "Inspect host-side simulator and emulator proxy takeover",
        subcommands: [DeviceProxyDoctor.self, DeviceProxyCert.self, DeviceProxyProbe.self, DeviceProxyServe.self, DeviceProxyStart.self, DeviceProxyStatus.self, DeviceProxyExport.self, DeviceProxyStop.self]
    )
}

struct DeviceProxyCert: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cert",
        abstract: "Inspect, plan, or explicitly execute host-side proxy certificate trust setup",
        subcommands: [DeviceProxyCertDoctor.self, DeviceProxyCertPlan.self, DeviceProxyCertInstall.self]
    )
}

struct DeviceProxyCertDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Inspect certificate trust boundaries for host-side proxy visibility")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printNetworkProxySession(makeNetworkProxyCertificateDoctorSession(platform: platform), outputFormat: effectiveFormat(format, json: json))
    }
}

struct DeviceProxyCertPlan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "plan", abstract: "Return a certificate trust setup ledger without installing or trusting the certificate")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Unified host device selector") var device: String
    @Option(help: "Root certificate path, for example /tmp/triton-proxy-ca.cer") var certificate: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
        try printNetworkProxySession(
            try makeNetworkProxyCertificatePlanSession(platform: platform, target: target, certificatePath: certificate),
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct DeviceProxyCertInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Execute reviewed proxy certificate trust setup after break-glass confirmation")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Unified host device selector") var device: String
    @Option(help: "Root certificate path, for example /tmp/triton-proxy-ca.cer") var certificate: String
    @Flag(help: "Confirm break-glass certificate trust mutation after inspecting cert plan output") var confirm = false
    @Option(help: "Audit record id for the break-glass certificate mutation") var auditRecord: String?
    @Flag(help: "Actually execute the platform command runner") var executeRunner = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
        guard confirm, let auditRecord, !auditRecord.isEmpty, executeRunner else {
            try printNetworkProxySession(
                try makeNetworkProxyExecutionPolicyRequiredSession(
                    action: .certInstall,
                    platform: platform,
                    target: target,
                    captureMode: nil,
                    confirm: confirm,
                    auditRecord: auditRecord,
                    executeRunner: executeRunner
                ),
                outputFormat: outputFormat
            )
            return
        }
        try printNetworkProxySession(
            try makeNetworkProxyCertificateInstallExecutedSession(
                platform: platform,
                target: target,
                certificatePath: certificate,
                auditRecord: auditRecord,
                runner: { command in try runHostCommand(command) }
            ),
            outputFormat: outputFormat
        )
    }
}

struct DeviceProxyServe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "serve", abstract: "Run a local host-side capture proxy for simulator and emulator traffic")

    @Option(help: "Local proxy listen endpoint host:port") var listen: String = "127.0.0.1:19431"
    @Option(help: "Capture output directory") var output: String
    @Option(help: "Capture policy mode: record|mock|block|throttle") var mode: String = "record"
    @Option(help: "JSON mock rules file for --mode mock") var mockRules: String?
    @Option(help: "JSON per-request policy rules file for host-side mock/block/throttle/forward decisions") var policyRules: String?
    @Option(help: "Synthetic response delay in milliseconds for --mode throttle") var throttleMs: Int?
    @Option(help: .hidden) var maxConnections: Int?
    @Flag(help: "Emit compact JSON Lines for ready/request/final events") var jsonl = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let endpoint = try NetworkProxyEndpoint(listen)
        let summary = try runNetworkProxyCaptureServer(
            config: NetworkProxyServeConfig(listen: endpoint, outputDirectory: output, maxConnections: maxConnections, mode: mode, mockRulesPath: mockRules, policyRulesPath: policyRules, throttleDelayMs: throttleMs),
            eventWriter: jsonl ? { event in
                if let line = try? encodeCompactJSON(event) {
                    writeJSONLLine(line)
                }
            } : nil
        )
        if jsonl {
            writeJSONLLine(try encodeCompactJSON(summary))
            return
        }
        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(summary))
        case .text:
            print("\(summary.listen)\trequests=\(summary.requestCount)\tevents=\(summary.eventCount)\tfailures=\(summary.failureCount)\tcapture=\(summary.capturePath)")
        }
    }
}

struct DeviceProxyDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Probe host-side proxy takeover prerequisites")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printNetworkProxySession(makeNetworkProxyDoctorSession(platform: platform), outputFormat: effectiveFormat(format, json: json))
    }
}

struct DeviceProxyProbe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "probe", abstract: "Run readonly platform proxy capability probes")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Unified host device selector") var device: String
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Return readonly probe command ledger without running host tools") var planOnly = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
        if planOnly {
            try printNetworkProxySession(
                try makeNetworkProxyProbePlanSession(platform: platform, target: target, hdc: hdc, adb: adb),
                outputFormat: outputFormat
            )
            return
        }
        try printNetworkProxySession(
            try makeNetworkProxyProbeSession(
                platform: platform,
                target: target,
                hdc: hdc,
                adb: adb,
                runner: { command in try runHostCommand(command) }
            ),
            outputFormat: outputFormat
        )
    }
}

struct DeviceProxyStart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start", abstract: "Start a host-side proxy takeover session when supported")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Unified host device selector") var device: String?
    @Option(help: "Capture mode: record|mock|block|throttle") var mode: String = "record"
    @Option(help: "Capture output directory") var output: String?
    @Option(help: "Local proxy endpoint host:port") var proxy: String = "127.0.0.1:19431"
    @Flag(help: "Return platform host-command plan without changing proxy settings") var planOnly = false
    @Flag(help: "Confirm break-glass proxy mutation after inspecting --plan-only output") var confirm = false
    @Option(help: "Audit record id required for break-glass proxy mutation") var auditRecord: String?
    @Flag(help: "Execute the break-glass proxy command runner after plan review, confirmation, and audit metadata") var executeRunner = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if planOnly {
            let endpoint = try NetworkProxyEndpoint(proxy)
            let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
            try printNetworkProxySession(
                try makeNetworkProxyStartPlanSession(platform: platform, target: target, captureMode: mode, endpoint: endpoint),
                outputFormat: outputFormat
            )
            return
        }
        let endpoint = try NetworkProxyEndpoint(proxy)
        let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
        guard confirm, let auditRecord, !auditRecord.isEmpty, executeRunner else {
            try printNetworkProxySession(
                try makeNetworkProxyExecutionPolicyRequiredSession(action: .start, platform: platform, target: target, captureMode: mode, confirm: confirm, auditRecord: auditRecord, executeRunner: executeRunner),
                outputFormat: outputFormat
            )
            return
        }
        if platform == .harmony {
            try printNetworkProxySession(
                try makeNetworkProxyUnverifiedPlatformSession(action: .start, platform: platform, target: target, captureMode: mode, auditRecord: auditRecord),
                outputFormat: outputFormat
            )
            return
        }
        try printNetworkProxySession(
            try makeNetworkProxyStartExecutedSession(
                platform: platform,
                target: target,
                captureMode: mode,
                endpoint: endpoint,
                auditRecord: auditRecord,
                runner: { command in try runHostCommand(command) },
                outputDirectory: output
            ),
            outputFormat: outputFormat
        )
    }
}

struct DeviceProxyStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Inspect host-side proxy takeover state")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Unified host device selector") var device: String?
    @Option(help: "Proxy session directory produced by proxy start --output") var session: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        if let session, !session.isEmpty {
            let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
            try printNetworkProxySession(
                try makeNetworkProxyStatusSession(platform: platform, target: target, sessionDirectory: session),
                outputFormat: effectiveFormat(format, json: json)
            )
            return
        }
        let target: HostDeviceTarget?
        if let device, !device.isEmpty {
            let resolvedTarget = try makeNetworkProxyPlanTarget(platform: platform, device: device)
            try printNetworkProxySession(
                try makeNetworkProxyStatusProbeSession(
                    platform: platform,
                    target: resolvedTarget,
                    hdc: hdc,
                    adb: adb,
                    runner: { command in try runHostCommand(command) }
                ),
                outputFormat: effectiveFormat(format, json: json)
            )
            return
        } else {
            target = nil
        }
        try printNetworkProxySession(makeNetworkProxyStatusSession(platform: platform, target: target), outputFormat: effectiveFormat(format, json: json))
    }
}

struct DeviceProxyExport: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "export", abstract: "Export a host-side proxy capture when a session exists")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Unified host device selector") var device: String?
    @Option(help: "HAR or NDJSON output path") var output: String?
    @Option(help: "Proxy session directory produced by proxy start --output") var session: String?
    @Flag(help: "Return network capture artifact plan without writing files") var planOnly = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        if planOnly {
            let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
            let outputPath = try makeNetworkProxyExportPlanOutputPath(output)
            try printNetworkProxySession(
                try makeNetworkProxyExportPlanSession(platform: platform, target: target, outputPath: outputPath),
                outputFormat: effectiveFormat(format, json: json)
            )
            return
        }
        let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
        try printNetworkProxySession(
            try makeNetworkProxyExportSession(platform: platform, target: target, sessionDirectory: session, outputPath: output),
            outputFormat: effectiveFormat(format, json: json)
        )
    }
}

struct DeviceProxyStop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop a host-side proxy takeover session and restore settings")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Unified host device selector") var device: String?
    @Flag(help: "Restore platform proxy settings") var restore = false
    @Flag(help: "Return platform restore command plan without changing proxy settings") var planOnly = false
    @Flag(help: "Confirm break-glass proxy restore after inspecting --plan-only output") var confirm = false
    @Option(help: "Audit record id required for break-glass proxy restore") var auditRecord: String?
    @Flag(help: "Execute the break-glass proxy restore runner after plan review, confirmation, and audit metadata") var executeRunner = false
    @Option(help: "Restore snapshot path produced by proxy start") var restoreSnapshot: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if planOnly {
            let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
            try printNetworkProxySession(
                try makeNetworkProxyStopPlanSession(
                    platform: platform,
                    target: target,
                    restore: restore,
                    restoreSnapshotPath: restoreSnapshot
                ),
                outputFormat: outputFormat
            )
            return
        }
        let target = try makeNetworkProxyPlanTarget(platform: platform, device: device)
        guard confirm, let auditRecord, !auditRecord.isEmpty, executeRunner else {
            try printNetworkProxySession(
                try makeNetworkProxyExecutionPolicyRequiredSession(action: .stop, platform: platform, target: target, captureMode: nil, confirm: confirm, auditRecord: auditRecord, executeRunner: executeRunner),
                outputFormat: outputFormat
            )
            return
        }
        if platform == .harmony {
            try printNetworkProxySession(
                try makeNetworkProxyUnverifiedPlatformSession(action: .stop, platform: platform, target: target, captureMode: nil, auditRecord: auditRecord),
                outputFormat: outputFormat
            )
            return
        }
        try printNetworkProxySession(
            try makeNetworkProxyStopExecutedSession(
                platform: platform,
                target: target,
                restore: restore,
                auditRecord: auditRecord,
                runner: { command in try runHostCommand(command) },
                restoreSnapshotPath: restoreSnapshot
            ),
            outputFormat: outputFormat
        )
    }
}

func printNetworkProxySession(_ session: NetworkProxySession, outputFormat: ClientOutputFormat) throws {
    switch outputFormat {
    case .json:
        print(try encodeJSON(session))
    case .text:
        print("\(session.platform)\t\(session.action)\tconfigured=\(session.configured)\tvisibility=\(session.visibility.rawValue)")
        for limitation in session.limitations {
            print("limitation\t\(limitation)")
        }
    }
    if !session.ok {
        throw ExitCode.failure
    }
}

let androidBridgePackageName = "jp.lycorp.tritonkit.bridge"

func androidBridgeAuthToken(from stdout: String) -> String? {
    for line in stdout.components(separatedBy: .newlines) {
        guard let range = line.range(of: "result=") else { continue }
        let raw = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = raw.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = object["result"] as? String,
            !token.isEmpty
        else { continue }
        return token
    }
    return nil
}

func makeAndroidBridgeStatusOutput(platform: HostDevicePlatform, device: String, adb: String = "adb", runner: HostDeviceCommandRunner? = nil) -> HostDeviceBridgeOutput {
    let packageCommand = TKHostCommand(executable: adb, arguments: ["-s", device, "shell", "pm", "path", androidBridgePackageName])
    let tokenCommand = TKHostCommand(executable: adb, arguments: ["-s", device, "shell", "content", "query", "--uri", "content://\(androidBridgePackageName)/auth_token"], sensitiveOutput: true)
    guard let runner else {
        return makeAndroidBridgeOutput(
            action: "bridge.status",
            platform: platform,
            device: device,
            sourceCommands: [hostSourceCommand(packageCommand), hostSourceCommand(tokenCommand)],
            limitations: ["android_bridge_contract_only:not_executed"]
        )
    }
    var sourceCommands: [String] = []
    var installed = false
    var authTokenAvailable = false
    do {
        let packageResult = try runner(packageCommand)
        sourceCommands.append(packageResult.sourceCommand)
        installed = packageResult.stdout.contains("package:")
    } catch {
        sourceCommands.append(hostSourceCommand(packageCommand))
    }
    do {
        let tokenResult = try runner(tokenCommand)
        sourceCommands.append(tokenResult.sourceCommand)
        authTokenAvailable = androidBridgeAuthToken(from: tokenResult.stdout) != nil
    } catch {
        sourceCommands.append(hostSourceCommand(tokenCommand))
    }
    return makeAndroidBridgeOutput(
        action: "bridge.status",
        platform: platform,
        device: device,
        sourceCommands: sourceCommands,
        limitations: [
            installed ? nil : "android_bridge_not_installed",
            authTokenAvailable ? nil : "android_bridge_auth_token_missing",
        ].compactMap { $0 },
        installed: installed,
        authTokenAvailable: authTokenAvailable,
        error: installed && authTokenAvailable ? nil : TKCLIErrorDetail(
            code: installed ? "android_bridge_auth_token_missing" : "android_bridge_not_installed",
            message: installed ? "Android bridge auth token is not available." : "Android bridge package is not installed.",
            hint: "Run `triton device bridge install --platform android --device \(device) --apk <apk> --confirm --audit-record <id> --execute-runner --json`."
        )
    )
}

func makeAndroidBridgeProbeOutput(platform: HostDevicePlatform, device: String, localPort: Int = 19422, runner: HostDeviceCommandRunner? = nil) -> HostDeviceBridgeOutput {
    let endpoint = "http://127.0.0.1:\(localPort)"
    let command = TKHostCommand(executable: "/usr/bin/curl", arguments: ["-fsS", "--max-time", "3", "\(endpoint)/ping"])
    guard let runner else {
        return makeAndroidBridgeOutput(
            action: "bridge.probe",
            platform: platform,
            device: device,
            localEndpoint: endpoint,
            sourceCommands: ["GET \(endpoint)/ping"],
            limitations: ["android_bridge_contract_only:not_executed"]
        )
    }
    do {
        let result = try runner(command)
        return makeAndroidBridgeOutput(
            action: "bridge.probe",
            platform: platform,
            device: device,
            localEndpoint: endpoint,
            sourceCommands: [result.sourceCommand],
            limitations: [],
            probeReachable: true,
            responseSummary: String(result.stdout.prefix(240))
        )
    } catch {
        return makeAndroidBridgeOutput(
            action: "bridge.probe",
            platform: platform,
            device: device,
            localEndpoint: endpoint,
            sourceCommands: [hostSourceCommand(command)],
            limitations: ["android_bridge_probe_unreachable"],
            probeReachable: false,
            error: TKCLIErrorDetail(
                code: "android_bridge_probe_failed",
                message: "Android bridge /ping probe failed: \(error)",
                hint: "Confirm the bridge AccessibilityService is enabled and `triton device bridge forward` has run."
            )
        )
    }
}

func makeAndroidBridgeInstallOutput(
    platform: HostDevicePlatform,
    device: String,
    apkPath: String,
    adb: String = "adb",
    confirm: Bool,
    auditRecord: String?,
    executeRunner: Bool,
    runner: HostDeviceCommandRunner? = nil
) -> HostDeviceBridgeOutput {
    let command = TKAndroidADBCommand.installAPK(serial: device, apkPath: apkPath, executable: adb)
    return makeAndroidBridgeMutationOutput(
        action: "bridge.install",
        platform: platform,
        device: device,
        apkPath: apkPath,
        command: command,
        confirm: confirm,
        auditRecord: auditRecord,
        executeRunner: executeRunner,
        runner: runner,
        failureCode: "android_bridge_install_failed"
    )
}

func makeAndroidBridgeForwardOutput(
    platform: HostDevicePlatform,
    device: String,
    adb: String = "adb",
    localPort: Int = 19422,
    remotePort: Int = 8080,
    confirm: Bool,
    auditRecord: String?,
    executeRunner: Bool,
    runner: HostDeviceCommandRunner? = nil
) -> HostDeviceBridgeOutput {
    let command = TKHostCommand(
        executable: adb,
        arguments: ["-s", device, "forward", "tcp:\(localPort)", "tcp:\(remotePort)"],
        riskLevel: .automation,
        requiredConfig: [.target, .timeout, .auditRecord]
    )
    return makeAndroidBridgeMutationOutput(
        action: "bridge.forward",
        platform: platform,
        device: device,
        localEndpoint: "http://127.0.0.1:\(localPort)",
        remoteEndpoint: "tcp:\(remotePort)",
        command: command,
        confirm: confirm,
        auditRecord: auditRecord,
        executeRunner: executeRunner,
        runner: runner,
        failureCode: "android_bridge_forward_failed"
    )
}

private func makeAndroidBridgeMutationOutput(
    action: String,
    platform: HostDevicePlatform,
    device: String,
    apkPath: String? = nil,
    localEndpoint: String? = nil,
    remoteEndpoint: String? = nil,
    command: TKHostCommand,
    confirm: Bool,
    auditRecord: String?,
    executeRunner: Bool,
    runner: HostDeviceCommandRunner?,
    failureCode: String
) -> HostDeviceBridgeOutput {
    let sourceCommands = [hostSourceCommand(command)]
    guard confirm, let auditRecord, !auditRecord.isEmpty, executeRunner else {
        return makeAndroidBridgeOutput(
            action: action,
            platform: platform,
            device: device,
            apkPath: apkPath,
            localEndpoint: localEndpoint,
            remoteEndpoint: remoteEndpoint,
            sourceCommands: sourceCommands,
            limitations: [
                "android_bridge_execution_policy_required:confirm=\(confirm)",
                "android_bridge_execution_policy_required:executeRunner=\(executeRunner)",
            ],
            error: TKCLIErrorDetail(
                code: "destructive_action_requires_policy",
                message: "Android bridge mutation requires --confirm, --audit-record, and --execute-runner.",
                hint: "Inspect this command ledger first, then rerun with explicit audit metadata."
            )
        )
    }
    if let runner {
        do {
            let result = try runner(command)
            return makeAndroidBridgeOutput(
                action: action,
                platform: platform,
                device: device,
                apkPath: apkPath,
                localEndpoint: localEndpoint,
                remoteEndpoint: remoteEndpoint,
                sourceCommands: [result.sourceCommand],
                limitations: ["android_bridge_runner_executed:auditRecord=\(auditRecord)"]
            )
        } catch {
            return makeAndroidBridgeOutput(
                action: action,
                platform: platform,
                device: device,
                apkPath: apkPath,
                localEndpoint: localEndpoint,
                remoteEndpoint: remoteEndpoint,
                sourceCommands: sourceCommands,
                limitations: ["android_bridge_runner_failed:auditRecord=\(auditRecord)"],
                error: TKCLIErrorDetail(
                    code: failureCode,
                    message: "Android bridge command failed: \(error)",
                    hint: "Run `triton device doctor --platform android --json` and confirm the emulator is online."
                )
            )
        }
    }
    return makeAndroidBridgeOutput(
        action: action,
        platform: platform,
        device: device,
        apkPath: apkPath,
        localEndpoint: localEndpoint,
        remoteEndpoint: remoteEndpoint,
        sourceCommands: sourceCommands,
        limitations: ["android_bridge_runner_not_configured:not_executed", "android_bridge_execution_policy_accepted:auditRecord=\(auditRecord)"],
        error: TKCLIErrorDetail(
            code: "android_bridge_runner_not_configured",
            message: "Android bridge runner is not wired yet.",
            hint: "Implement the helper APK and runner in the Android bridge milestone before executing this mutation."
        )
    )
}

private func makeAndroidBridgeOutput(
    action: String,
    platform: HostDevicePlatform,
    device: String,
    apkPath: String? = nil,
    localEndpoint: String? = nil,
    remoteEndpoint: String? = nil,
    sourceCommands: [String],
    limitations: [String],
    installed: Bool? = nil,
    authTokenAvailable: Bool? = nil,
    probeReachable: Bool? = nil,
    responseSummary: String? = nil,
    error: TKCLIErrorDetail? = nil
) -> HostDeviceBridgeOutput {
    let unsupportedPlatform = platform != .android
    let resolvedError = unsupportedPlatform
        ? TKCLIErrorDetail(
            code: "unsupported_capability",
            message: "Android bridge commands only support --platform android.",
            hint: "Use existing iOS host probes or Harmony runtime commands for other platforms."
        )
        : error
    return HostDeviceBridgeOutput(
        ok: resolvedError == nil,
        surface: "host.device-bridge",
        action: action,
        platform: platform.rawValue,
        device: device,
        packageName: androidBridgePackageName,
        apkPath: apkPath,
        localEndpoint: localEndpoint,
        remoteEndpoint: remoteEndpoint,
        planOnly: true,
        installed: installed,
        authTokenAvailable: authTokenAvailable,
        probeReachable: probeReachable,
        responseSummary: responseSummary,
        limitations: unsupportedPlatform ? limitations + ["android_bridge_platform_only"] : limitations,
        sourceCommands: sourceCommands,
        error: resolvedError,
        nextAction: TKCLINextAction(command: "device", args: ["bridge", "status", "--platform", "android", "--device", device, "--json"], category: "diagnose")
    )
}

func printHostDeviceBridgeOutput(_ output: HostDeviceBridgeOutput, outputFormat: ClientOutputFormat) throws {
    switch outputFormat {
    case .json:
        print(try encodeJSON(output))
    case .text:
        print("\(output.platform)\t\(output.action)\tdevice=\(output.device)\tplanOnly=\(output.planOnly)")
        for command in output.sourceCommands {
            print("command\t\(command)")
        }
    }
    if !output.ok {
        throw ExitCode.failure
    }
}

struct DeviceDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Probe platform host tools")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Optional path to DevEco Emulator executable") var emulator: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let output: HostDeviceDoctorOutput
        switch platform {
        case .ios:
            let simctlProbe = probeHostTool(name: "simctl", command: TKHostCommand(executable: "xcrun", arguments: ["simctl", "help"]))
            let devicectlProbe = probeHostTool(name: "devicectl", command: TKHostCommand(executable: "xcrun", arguments: ["devicectl", "--help"]))
            let xcodebuildProbe = probeHostTool(name: "xcodebuild", command: TKHostCommand(executable: "xcodebuild", arguments: ["-version"]))
            let idbProbe = probeHostTool(name: "idb", command: TKHostCommand(executable: "idb", arguments: ["--version"]))
            let tools: [HostToolProbeOutput]
            let ok: Bool
            if scope == .real {
                tools = [devicectlProbe, xcodebuildProbe]
                ok = devicectlProbe.available && xcodebuildProbe.available
            } else if scope == .all {
                tools = [simctlProbe, devicectlProbe, xcodebuildProbe]
                ok = simctlProbe.available && xcodebuildProbe.available
            } else {
                tools = [simctlProbe, xcodebuildProbe]
                ok = simctlProbe.available && xcodebuildProbe.available
            }
            output = HostDeviceDoctorOutput(
                ok: ok,
                platform: platform.rawValue,
                tools: tools,
                capabilities: ["device.list", "device.use", "device.wait-ready", "device.screenshot", "ios.simctl-targets", "ios.real-device", "ios.devicectl", "ios-host-ax", "ios-host-hid"],
                strongControl: iosStrongControlProbes(idbProbe: idbProbe),
                artifactsSaved: false
            )
        case .harmony:
            let hdcProbe = probeHostTool(name: "hdc", command: TKHarmonyHDCCommand.version(executable: hdc))
            let emulatorProbe = emulator.map { path in
                probeHostTool(name: "emulator", command: TKHostCommand(executable: path, arguments: ["-version"]))
            }
            output = HostDeviceDoctorOutput(
                ok: hdcProbe.available && (emulatorProbe?.available ?? true),
                platform: platform.rawValue,
                tools: [hdcProbe] + Array(emulatorProbe.map { [$0] } ?? []),
                capabilities: ["device.list", "device.use", "device.wait-ready", "device.runtime-url", "device.screenshot", "harmony.hdc-targets"],
                strongControl: [],
                artifactsSaved: false
            )
        case .android:
            let adbProbe = probeHostTool(name: "adb", command: TKHostCommand(executable: adb, arguments: ["version"]))
            let emulatorProbe = emulator.map { path in
                probeHostTool(name: "emulator", command: TKHostCommand(executable: path, arguments: ["-version"]))
            }
            output = HostDeviceDoctorOutput(
                ok: adbProbe.available && (emulatorProbe?.available ?? true),
                platform: platform.rawValue,
                tools: [adbProbe] + Array(emulatorProbe.map { [$0] } ?? []),
                capabilities: ["device.list", "device.use", "device.wait-ready", "device.screenshot", "android.adb-targets", "android.real-device", "android.emulator-scope"],
                strongControl: [],
                artifactsSaved: false
            )
        }
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            for tool in output.tools {
                print("\(tool.name)\t\(tool.available ? "available" : "unavailable")\t\(tool.path)")
            }
        }
    }
}

func iosStrongControlProbes(idbProbe: HostToolProbeOutput) -> [TKHostStrongControlCapability] {
    ["ios-host-ax", "ios-host-hid"].map { name in
        TKHostStrongControlCapability(
            name: name,
            platform: "ios",
            runtimeScope: "host-simulator",
            available: idbProbe.available,
            reason: idbProbe.available ? nil : "idb_not_available",
            dependency: "idb/FBSimulatorControl",
            limitations: ["private_framework_dependency", "simulator_only", "xcode_version_coupled"],
            fallbackCapability: "embedded-runtime-or-public-simctl",
            sourceCommand: idbProbe.sourceCommand,
            nextAction: idbProbe.available ? nil : TKCLINextAction(command: "device", args: ["doctor", "--platform", "ios", "--json"], category: "diagnose")
        )
    }
}

struct DeviceList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List platform targets")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try hostDeviceTargets(platform: platform, scope: scope, hdc: hdc, adb: adb)
            let output = HostDeviceListOutput(
                ok: true,
                platform: platform.rawValue,
                targets: result.targets,
                defaultTarget: selectHostDeviceTarget(target: nil, candidates: result.targets),
                sourceCommand: result.sourceCommand,
                nextAction: result.targets.isEmpty ? hostDeviceEmptyListNextAction(platform: platform) : nil
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for target in result.targets {
                    switch platform {
                    case .ios:
                        print("\(target.target)\t\(target.state)\t\(target.runtime ?? "-")\t\(target.name ?? "-")")
                    case .harmony:
                        print("\(target.target)\t\(target.state)\t\(target.transport ?? "-")")
                    case .android:
                        print("\(target.target)\t\(target.state)\t\(target.name ?? "-")")
                    }
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceUse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Set the current agent host target")

    @Argument(help: "Target selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var selector: String?
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if selector != nil && target != nil {
                throw HostDeviceSelectionError.parameterConflict("device use accepts either <selector> or --target, not both.")
            }
            let selected = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: selector ?? target, platform: platform, scope: scope, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc,
                adb: adb
            )
            var store = try loadHostTargetAliasStore()
            store.current = hostDeviceCurrentSelector(explicitSelector: selector, explicitTarget: target, selected: selected)
            let defaultsPath = try saveHostTargetAliasStore(store)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceUseOutput(ok: true, platform: selected.platform.rawValue, target: selected.target, defaultsPath: defaultsPath, selection: selected)))
            case .text:
                print(selected.target.target)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceCurrent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current", abstract: "Show the current agent host target")

    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let store = try loadHostTargetAliasStore()
            let path = HostTargetAliasStore.filePath(workspace: FileManager.default.currentDirectoryPath)
            let selection = try store.current.map {
                try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: $0), hdc: hdc, adb: adb)
            }
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceCurrentOutput(ok: true, current: store.current, selection: selection, path: path)))
            case .text:
                print(selection?.target.target ?? "")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceResolve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "resolve", abstract: "Resolve one host target selector without executing an action")

    @Argument(help: "Target selector: alias, sim:<udid>, android:<serial>, harmony:<target>, raw id, booted, or current") var selector: String?
    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if selector != nil && device != nil {
                throw HostDeviceSelectionError.parameterConflict("device resolve accepts either <selector> or --device, not both.")
            }
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: selector ?? device, platform: platform, scope: scope, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc,
                adb: adb
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceResolveOutput(ok: true, selection: selection)))
            case .text:
                print(selection.target.target)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceAlias: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "alias",
        abstract: "Manage stable host target aliases",
        subcommands: [DeviceAliasList.self, DeviceAliasSet.self, DeviceAliasRemove.self]
    )
}

struct DeviceAliasList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List host target aliases")

    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let store = try loadHostTargetAliasStore()
            let path = HostTargetAliasStore.filePath(workspace: FileManager.default.currentDirectoryPath)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceAliasListOutput(ok: true, current: store.current, aliases: store.aliases, path: path)))
            case .text:
                for name in store.aliases.keys.sorted() {
                    if let alias = store.aliases[name] {
                        print("\(name)\t\(alias.platform.rawValue)\t\(alias.target)")
                    }
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceAliasSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set a host target alias")

    @Argument(help: "Alias name") var name: String
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Raw platform target id: iOS UDID, Android adb serial, or Harmony HDC target") var target: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"#, options: .regularExpression) != nil else {
                throw HostDeviceSelectionError.parameterConflict("Alias name must be 1-64 characters and use letters, digits, dot, underscore, or hyphen.")
            }
            var store = try loadHostTargetAliasStore()
            let alias = HostTargetAlias(platform: platform, target: target)
            store.aliases[name] = alias
            let path = try saveHostTargetAliasStore(store)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceAliasMutationOutput(ok: true, action: "device.alias.set", name: name, alias: alias, path: path)))
            case .text:
                print(name)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceAliasRemove: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove a host target alias")

    @Argument(help: "Alias name") var name: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            var store = try loadHostTargetAliasStore()
            let removed = store.aliases.removeValue(forKey: name)
            if store.current == name {
                store.current = nil
            }
            let path = try saveHostTargetAliasStore(store)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceAliasMutationOutput(ok: true, action: "device.alias.remove", name: name, alias: removed, path: path)))
            case .text:
                print(name)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceWaitReady: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "wait-ready", abstract: "Wait until a platform target is ready")

    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets before waiting") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Timeout in seconds") var timeout: Double = 30
    @Option(help: "Polling interval in seconds") var interval: Double = 1
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if device != nil && target != nil {
                throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
            }
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: device ?? target, platform: platform, scope: scope, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc,
                adb: adb
            )
            let event = try await waitForHostDeviceReady(
                platform: selection.platform,
                selected: selection.target,
                hdc: hdc,
                adb: adb,
                timeout: timeout,
                interval: interval
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(event))
            case .text:
                print("\(event.target.target)\tready=\(event.ready)")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceScreenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screenshot", abstract: "Capture a host-side device screenshot")

    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Output image path") var output: String
    @Option(help: "Host command timeout in seconds") var timeout: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if device != nil && target != nil {
                throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
            }
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: device ?? target, platform: platform, scope: scope, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc,
                adb: adb
            )
            let artifact = try captureHostDeviceScreenshot(platform: selection.platform, target: selection.target, selection: selection, hdc: hdc, adb: adb, output: output, timeout: timeout)
            switch outputFormat {
            case .json:
                print(try encodeJSON(artifact))
            case .text:
                print(output)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceRuntimeURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "runtime-url", abstract: "Prepare and print a Harmony embedded runtime base URL")

    @Option(help: "Platform adapter: harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Unified host device selector: alias, harmony:<target>, raw id, or current") var device: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Device name filter when available") var name: String?
    @Option(help: "Runtime filter when available") var runtime: String?
    @Option(help: "Target state filter, for example connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Local TCP port for host-side runtime access") var localPort: Int = TKHarmonyRuntimeDefaults.hostAccessPort
    @Option(help: "Remote TCP port where the Harmony embedded runtime listens") var remotePort: Int = TKHarmonyRuntimeDefaults.hostAccessPort
    @Flag(help: "Skip HDC fport setup and only print the local base URL") var noForward = false
    @Flag(help: "Probe /v2/runtime/manifest after preparing the base URL") var probeManifest = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard platform == .harmony else {
                try failHostUnsupportedCapability(
                    message: "device runtime-url only supports Harmony targets.",
                    hint: "Use `triton device wait-ready --platform android --device <selector> --json` and Android host actions instead.",
                    nextAction: TKCLINextAction(command: "schema", args: ["--command", "device", "--json"], category: "plan"),
                    outputFormat: outputFormat
                )
            }
            if device != nil && target != nil {
                throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
            }
            try validateTCPPort(localPort, name: "--local-port")
            try validateTCPPort(remotePort, name: "--remote-port")
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(
                    device: device ?? target,
                    platform: .harmony,
                    name: name,
                    runtime: runtime,
                    state: state,
                    ready: ready
                ),
                hdc: hdc
            )
            let selected = harmonyTarget(from: selection.target)
            let baseURL = "http://127.0.0.1:\(localPort)"
            var sourceCommand: String?
            var forwarded = false
            if !noForward {
                let result = try runHostCommand(TKHarmonyHDCCommand.forwardPort(target: selected.target, localPort: localPort, remotePort: remotePort, executable: hdc))
                sourceCommand = result.sourceCommand
                forwarded = true
            }
            let manifest: TKRuntimeManifestResponse?
            if probeManifest {
                let data = try await EmbeddedRuntimeHTTPClient(baseURL: baseURL).request(.runtimeManifest)
                manifest = try JSONDecoder().decode(TKRuntimeManifestResponse.self, from: data)
            } else {
                manifest = nil
            }
            let output = HostRuntimeURLOutput(
                ok: true,
                platform: platform.rawValue,
                target: selected,
                localPort: localPort,
                remotePort: remotePort,
                baseURL: baseURL,
                forwarded: forwarded,
                sourceCommand: sourceCommand,
                manifest: manifest,
                note: "Use `--runtime-base-url \(baseURL)` with runtime, state, snapshot, ledger, and semantic action commands."
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print(baseURL)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceStart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start", abstract: "Start a host-side Android or Harmony emulator with a machine-readable launch ledger")

    @Option(help: "Platform adapter: android|harmony") var platform: HostDevicePlatform = .android
    @Option(help: "Android AVD name, for example Dxyer_API_34") var avd: String?
    @Option(help: "Harmony HVD name, for example Codex Test Phone") var hvd: String?
    @Option(help: "DevEco deployed emulator path, for example ~/.Huawei/Emulator/deployed") var path: String?
    @Option(help: "Android emulator or DevEco Emulator executable path") var emulator: String?
    @Option(help: "HDC executable path for Harmony tconn follow-up") var hdc: String = "hdc"
    @Option(help: "Harmony HDC bridge port") var hdcPort: Int = 10100
    @Option(help: "Harmony boot mode passed to DevEco Emulator") var bootmode: String = "coldboot"
    @Option(help: "Expected Android adb serial after first emulator launch") var adbSerial: String = "emulator-5554"
    @Flag(help: "Run Android emulator without a visible window") var headless = false
    @Option(help: "Android emulator GPU mode, for example swiftshader_indirect") var gpu: String?
    @Option(help: "Android emulator memory in MB") var memory: Int?
    @Flag(help: "Pass -no-snapshot-load to Android emulator") var noSnapshotLoad = false
    @Flag(help: "Pass -no-audio to Android emulator") var noAudio = false
    @Flag(help: "Pass -no-boot-anim to Android emulator") var noBootAnim = false
    @Flag(inversion: .prefixedNo, help: "Include Harmony hdc tconn follow-up command in sourceCommands") var connectAfterLaunch = true
    @Flag(help: "Return the launch ledger without starting an emulator") var planOnly = false
    @Option(help: "Optional stdout log path for detached emulator launch") var stdoutLog: String?
    @Option(help: "Optional stderr log path for detached emulator launch") var stderrLog: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let plan = try makePlan()
            let detached: HostDetachedProcessResult?
            if planOnly {
                detached = nil
            } else {
                detached = try runHostCommandDetached(
                    plan.commands[0],
                    stdoutLogPath: stdoutLog,
                    stderrLogPath: stderrLog
                )
                if platform == .harmony, let detached {
                    try failIfHarmonyLicenseAgreementBlocked(detached, outputFormat: outputFormat)
                }
            }
            let nextAction = TKCLINextAction(
                command: "device",
                args: plan.waitReadyArgs,
                category: "wait"
            )
            let output = HostDeviceStartOutput(
                ok: true,
                action: plan.action,
                platform: plan.platform,
                name: plan.name,
                target: plan.target,
                deployedPath: plan.deployedPath,
                emulator: plan.emulator,
                hdc: plan.hdc,
                hdcPort: plan.hdcPort,
                planOnly: planOnly,
                started: detached != nil,
                pid: detached?.pid,
                sourceCommands: plan.commands.map(hostSourceCommand),
                executedSourceCommands: detached.map { [$0.sourceCommand] } ?? [],
                stdoutLogPath: detached?.stdoutLogPath,
                stderrLogPath: detached?.stderrLogPath,
                nextAction: nextAction,
                note: plan.note
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print(output.note)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }

    private func failIfHarmonyLicenseAgreementBlocked(
        _ detached: HostDetachedProcessResult,
        outputFormat: ClientOutputFormat
    ) throws {
        guard detached.stdoutLogPath != nil || detached.stderrLogPath != nil else {
            return
        }
        Thread.sleep(forTimeInterval: 0.3)
        let stdout = detached.stdoutLogPath.flatMap { try? String(contentsOfFile: $0, encoding: .utf8) } ?? ""
        let stderr = detached.stderrLogPath.flatMap { try? String(contentsOfFile: $0, encoding: .utf8) } ?? ""
        guard harmonyEmulatorLicenseAgreementDetected(stdout: stdout, stderr: stderr) else {
            return
        }
        let detail = harmonyEmulatorLicenseAgreementErrorDetail(
            stdoutLogPath: detached.stdoutLogPath,
            stderrLogPath: detached.stderrLogPath
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(TKCLIErrorResponse(error: detail)))
        case .text:
            print(detail.message)
            if let hint = detail.hint {
                print("hint: \(hint)")
            }
        }
        throw ExitCode.failure
    }

    private func makePlan() throws -> HostDeviceStartPlan {
        switch platform {
        case .android:
            return try androidEmulatorStartPlan(
                avd: avd ?? "",
                emulator: emulator ?? "emulator",
                headless: headless,
                gpu: gpu,
                memory: memory,
                noSnapshotLoad: noSnapshotLoad,
                noAudio: noAudio,
                noBootAnim: noBootAnim,
                adbSerial: adbSerial
            )
        case .harmony:
            return try harmonyEmulatorStartPlan(
                hvd: hvd ?? "",
                deployedPath: path ?? "",
                emulator: emulator ?? "/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator",
                hdc: hdc,
                hdcPort: hdcPort,
                bootmode: bootmode,
                connectAfterLaunch: connectAfterLaunch
            )
        case .ios:
            throw HostDeviceSelectionError.parameterConflict("iOS Simulator lifecycle uses `triton sim boot <udid> --wait --json`, not `triton device start`.")
        }
    }
}

struct DeviceStop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop a host-side device or emulator")

    @Option(help: "Platform adapter: android|harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Android adb serial or alias") var device: String?
    @Option(help: "ADB executable path") var adb: String = "adb"
    @Option(help: "Harmony HVD name, for example Codex Test Phone") var hvd: String?
    @Option(help: "DevEco deployed emulator path, for example ~/.Huawei/Emulator/deployed") var path: String?
    @Option(help: "Path to DevEco Emulator executable") var emulator: String = "/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
    @Option(help: "Triton launchd job label to unload before stopping") var launchdLabel: String = "triton-harmony-emulator"
    @Option(help: "launchd domain, defaults to gui/<uid>") var launchdDomain: String = defaultLaunchdDomain()
    @Flag(help: "Skip launchd print/bootout and only run Emulator -stop") var skipLaunchd = false
    @Flag(help: "Confirm stopping the emulator and unloading Triton launchd supervision") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            switch platform {
            case .android:
                let selection = try resolveHostDeviceSelection(
                    request: HostDeviceSelectionRequest(device: device, platform: .android, scope: .emulator),
                    hdc: "hdc",
                    adb: adb
                )
                guard selection.target.scope == HostDeviceScope.emulator.rawValue else {
                    throw HostDeviceSelectionError.parameterConflict("Android device stop supports emulator targets only.")
                }
                guard confirm else {
                    throw HostDeviceSelectionError.parameterConflict("device stop requires --confirm.")
                }
                let command = TKAndroidADBCommand.killEmulator(serial: selection.target.rawTarget, executable: adb)
                let result = try runHostCommand(command)
                let output = HostDeviceStopOutput(
                    ok: true,
                    action: "device.stop",
                    platform: "android",
                    target: selection.target.id,
                    adb: adb,
                    hvd: nil,
                    deployedPath: nil,
                    emulator: nil,
                    launchdLabel: nil,
                    launchdDomain: nil,
                    sourceCommands: [result.sourceCommand],
                    note: "Android emulator stop completed. Verify with `triton device list --platform android --json`; the target should be absent or offline."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(output))
                case .text:
                    print(output.note)
                }
            case .harmony:
                let plan = try harmonyEmulatorStopPlan(
                    hvd: hvd ?? "",
                    deployedPath: path ?? "",
                    emulator: emulator,
                    launchdLabel: launchdLabel,
                    launchdDomain: launchdDomain,
                    includeLaunchd: !skipLaunchd,
                    confirmed: confirm
                )
                var sourceCommands: [String] = []
                for command in plan.commands {
                    let result = try runHostCommand(command)
                    sourceCommands.append(result.sourceCommand)
                }
                let output = HostDeviceStopOutput(
                    ok: true,
                    action: plan.action,
                    platform: plan.platform,
                    target: nil,
                    adb: nil,
                    hvd: plan.hvd,
                    deployedPath: plan.deployedPath,
                    emulator: plan.emulator,
                    launchdLabel: plan.launchdLabel,
                    launchdDomain: plan.launchdDomain,
                    sourceCommands: sourceCommands,
                    note: "Harmony emulator stop completed. Verify with `triton device list --platform harmony --json`; the target should remain disconnected or absent."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(output))
                case .text:
                    print(output.note)
                }
            case .ios:
                try failHostUnsupportedCapability(
                    message: "device stop does not stop iOS Simulators.",
                    hint: "Use `triton sim shutdown <udid-or-booted> --json` for iOS Simulator lifecycle.",
                    nextAction: TKCLINextAction(command: "sim", args: ["shutdown", "<udid-or-booted>", "--json"], category: "prepare-target"),
                    outputFormat: outputFormat
                )
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
