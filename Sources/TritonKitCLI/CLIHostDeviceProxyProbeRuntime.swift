import Foundation
import TritonKitShared

struct NetworkProxyProbeCommand {
    let name: String
    let command: TKHostCommand
}

func networkProxyProbeCommands(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    hdc: String = "hdc",
    adb: String = "adb"
) -> [NetworkProxyProbeCommand] {
    switch platform {
    case .ios:
        return networkSetupProxySnapshotCommands(service: "Wi-Fi").enumerated().map { index, command in
            NetworkProxyProbeCommand(name: "ios.networksetup.snapshot.\(index + 1)", command: command)
        }
    case .android:
        return adbProxySnapshotCommands(serial: target.rawTarget, executable: adb).map {
            NetworkProxyProbeCommand(name: "android.adb.http-proxy.snapshot", command: $0)
        }
    case .harmony:
        return [
            NetworkProxyProbeCommand(name: "harmony.boot-completed", command: TKHarmonyHDCCommand.bootCompleted(target: target.rawTarget, executable: hdc)),
            NetworkProxyProbeCommand(name: "harmony.shell", command: TKHarmonyHDCCommand.shellProbe(target: target.rawTarget, executable: hdc)),
            NetworkProxyProbeCommand(name: "harmony.param.proxy", command: TKHarmonyHDCCommand.paramListRecursive(target: target.rawTarget, name: "proxy", executable: hdc)),
            NetworkProxyProbeCommand(name: "harmony.param.http", command: TKHarmonyHDCCommand.paramListRecursive(target: target.rawTarget, name: "http", executable: hdc)),
        ]
    }
}

func makeNetworkProxyProbePlanSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    hdc: String = "hdc",
    adb: String = "adb"
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .probe, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    let commands = networkProxyProbeCommands(platform: platform, target: target, hdc: hdc, adb: adb)
    return NetworkProxySession(
        ok: true,
        surface: "host.device-proxy",
        action: NetworkProxyAction.probe.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: networkProxyConservativeCertificate(platform: platform),
        visibility: .unknown,
        limitations: networkProxyDoctorLimitations(platform: platform) + networkProxyProbeLimitations(platform: platform, results: nil) + ["proxy_plan_only:not_executed"],
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: commands.map { hostSourceCommand($0.command) },
        error: nil
    )
}

func makeNetworkProxyProbeSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    hdc: String = "hdc",
    adb: String = "adb",
    runner: NetworkProxyCommandRunner
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .probe, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    let commands = networkProxyProbeCommands(platform: platform, target: target, hdc: hdc, adb: adb)
    let results = commands.map { runNetworkProxyProbeCommand($0, runner: runner) }
    let findings = networkProxyProbeFindings(platform: platform, results: results)
    let ok: Bool
    switch platform {
    case .harmony:
        ok = results.contains { $0.name == "harmony.boot-completed" && $0.ok }
            && results.contains { $0.name == "harmony.shell" && $0.ok }
    case .ios, .android:
        ok = results.allSatisfy(\.ok)
    }
    return NetworkProxySession(
        ok: ok,
        surface: "host.device-proxy",
        action: NetworkProxyAction.probe.rawValue,
        platform: platform.rawValue,
        target: target,
        lane: .hostProxy,
        captureMode: nil,
        proxyEndpoint: nil,
        configured: false,
        cert: networkProxyConservativeCertificate(platform: platform),
        visibility: .unknown,
        limitations: networkProxyDoctorLimitations(platform: platform) + networkProxyProbeLimitations(platform: platform, results: results),
        artifacts: [],
        restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
        sourceCommands: commands.map { hostSourceCommand($0.command) },
        error: ok ? nil : TKCLIErrorDetail(
            code: "proxy_probe_failed",
            message: "Host-side proxy capability probe failed for \(platform.rawValue) target \(target.target).",
            hint: "Inspect probeResults and host tool readiness before planning proxy start.",
            nextAction: TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", platform.rawValue, "--json"], category: "diagnose")
        ),
        probeResults: results,
        probeFindings: findings.isEmpty ? nil : findings
    )
}

func makeNetworkProxyStatusProbeSession(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    hdc: String = "hdc",
    adb: String = "adb",
    runner: NetworkProxyCommandRunner
) throws -> NetworkProxySession {
    if let rejected = makeNetworkProxyRealDeviceNotSupportedSession(action: .status, platform: platform, target: target, captureMode: nil) {
        return rejected
    }
    let commands = networkProxyProbeCommands(platform: platform, target: target, hdc: hdc, adb: adb)
    let results = commands.map { runNetworkProxyProbeCommand($0, runner: runner) }
    let findings = networkProxyProbeFindings(platform: platform, results: results)
    do {
        let status = try networkProxyReadonlyStatus(platform: platform, target: target, results: results)
        return NetworkProxySession(
            ok: status.ok,
            surface: "host.device-proxy",
            action: NetworkProxyAction.status.rawValue,
            platform: platform.rawValue,
            target: target,
            lane: .hostProxy,
            captureMode: nil,
            proxyEndpoint: status.proxyEndpoint,
            configured: status.configured,
            cert: networkProxyConservativeCertificate(platform: platform),
            visibility: status.visibility,
            limitations: status.limitations,
            artifacts: [],
            restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
            sourceCommands: commands.map { hostSourceCommand($0.command) },
            error: status.ok ? nil : networkProxyStatusProbeError(platform: platform, target: target, summary: status.errorSummary),
            probeResults: results,
            probeFindings: findings.isEmpty ? nil : findings
        )
    } catch {
        return NetworkProxySession(
            ok: false,
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
            limitations: networkProxyDoctorLimitations(platform: platform) + networkProxyProbeLimitations(platform: platform, results: results) + [
                "proxy_status_probe_failed:\(networkProxyErrorSummaryString(String(describing: error)))",
                "proxy_status_readonly:not_mutated",
            ],
            artifacts: [],
            restore: NetworkProxyRestore(available: false, snapshotPath: nil, restored: nil),
            sourceCommands: commands.map { hostSourceCommand($0.command) },
            error: networkProxyStatusProbeError(platform: platform, target: target, summary: networkProxyErrorSummaryString(String(describing: error))),
            probeResults: results,
            probeFindings: findings.isEmpty ? nil : findings
        )
    }
}

private struct NetworkProxyReadonlyStatus {
    let ok: Bool
    let configured: Bool
    let proxyEndpoint: String?
    let visibility: NetworkProxyVisibility
    let limitations: [String]
    let errorSummary: String?
}

private func networkProxyReadonlyStatus(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    results: [NetworkProxyProbeResult]
) throws -> NetworkProxyReadonlyStatus {
    let baseLimitations = networkProxyDoctorLimitations(platform: platform)
        + networkProxyProbeLimitations(platform: platform, results: results)
        + ["proxy_status_readonly:not_mutated"]
    switch platform {
    case .ios:
        guard results.count == 4, results.allSatisfy(\.ok) else {
            return networkProxyFailedReadonlyStatus(limitations: baseLimitations, results: results)
        }
        let snapshot = try parseNetworkSetupServiceSnapshot(
            service: "Wi-Fi",
            httpOutput: results[0].stdoutPreview ?? "",
            httpsOutput: results[1].stdoutPreview ?? "",
            socksOutput: results[2].stdoutPreview ?? "",
            bypassOutput: results[3].stdoutPreview ?? ""
        )
        let endpoint = networkProxyEndpointDescription(snapshot: snapshot)
        return NetworkProxyReadonlyStatus(
            ok: true,
            configured: endpoint != nil,
            proxyEndpoint: endpoint,
            visibility: endpoint == nil ? .unknown : .partial,
            limitations: baseLimitations + (endpoint == nil ? ["proxy_status_no_platform_proxy_detected"] : ["proxy_status_platform_proxy_detected:readonly_snapshot"]),
            errorSummary: nil
        )
    case .android:
        guard let result = results.first, result.ok else {
            return networkProxyFailedReadonlyStatus(limitations: baseLimitations, results: results)
        }
        let endpoint = result.stdoutPreview.flatMap(parseADBHTTPProxySetting)
        return NetworkProxyReadonlyStatus(
            ok: true,
            configured: endpoint != nil,
            proxyEndpoint: endpoint,
            visibility: endpoint == nil ? .unknown : .partial,
            limitations: baseLimitations + (endpoint == nil ? ["proxy_status_no_platform_proxy_detected"] : ["proxy_status_platform_proxy_detected:readonly_snapshot"]),
            errorSummary: nil
        )
    case .harmony:
        let ok = results.contains { $0.name == "harmony.boot-completed" && $0.ok }
            && results.contains { $0.name == "harmony.shell" && $0.ok }
        guard ok else {
            return networkProxyFailedReadonlyStatus(limitations: baseLimitations, results: results)
        }
        return NetworkProxyReadonlyStatus(
            ok: true,
            configured: false,
            proxyEndpoint: nil,
            visibility: .unknown,
            limitations: baseLimitations + [
                "proxy_session_not_running",
                "proxy_harmony_status_probe_only:no_verified_proxy_mutation",
            ],
            errorSummary: nil
        )
    }
}

private func networkProxyFailedReadonlyStatus(
    limitations: [String],
    results: [NetworkProxyProbeResult]
) -> NetworkProxyReadonlyStatus {
    let summary = networkProxyProbeFailureSummary(results)
    return NetworkProxyReadonlyStatus(
        ok: false,
        configured: false,
        proxyEndpoint: nil,
        visibility: .unknown,
        limitations: limitations + ["proxy_status_probe_failed:\(summary)"],
        errorSummary: summary
    )
}

private func networkProxyEndpointDescription(snapshot: HostNetworkProxyServiceSnapshot) -> String? {
    if snapshot.httpEnabled, !snapshot.httpHost.isEmpty, snapshot.httpPort > 0 {
        return "\(snapshot.httpHost):\(snapshot.httpPort)"
    }
    if snapshot.httpsEnabled, !snapshot.httpsHost.isEmpty, snapshot.httpsPort > 0 {
        return "\(snapshot.httpsHost):\(snapshot.httpsPort)"
    }
    if snapshot.socksEnabled, !snapshot.socksHost.isEmpty, snapshot.socksPort > 0 {
        return "\(snapshot.socksHost):\(snapshot.socksPort)"
    }
    return nil
}

private func networkProxyProbeFailureSummary(_ results: [NetworkProxyProbeResult]) -> String {
    guard let failed = results.first(where: { !$0.ok }) else { return "unknown" }
    if let error = failed.error, !error.isEmpty {
        return networkProxyErrorSummaryString(error)
    }
    if let stderr = failed.stderrPreview, !stderr.isEmpty {
        return networkProxyErrorSummaryString(stderr)
    }
    if let exitCode = failed.exitCode {
        return "exit_\(exitCode)"
    }
    return failed.name
}

private func networkProxyStatusProbeError(
    platform: HostDevicePlatform,
    target: HostDeviceTarget,
    summary: String?
) -> TKCLIErrorDetail {
    let suffix = summary.map { " Last probe failure: \($0)." } ?? ""
    return TKCLIErrorDetail(
        code: "proxy_status_probe_failed",
        message: "Readonly host-side proxy status probe failed for \(platform.rawValue) target \(target.target).",
        hint: "Inspect probeResults and run a readonly proxy probe before planning proxy start.\(suffix)",
        nextAction: TKCLINextAction(command: "device", args: ["proxy", "probe", "--platform", platform.rawValue, "--device", target.target, "--json"], category: "diagnose")
    )
}

private func networkProxyErrorSummaryString(_ value: String) -> String {
    let scalars = value.unicodeScalars.map { scalar -> Character in
        CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "_"
    }
    let normalized = String(scalars)
        .split(separator: "_")
        .joined(separator: "_")
        .lowercased()
    return normalized.isEmpty ? "unknown" : String(normalized.prefix(120))
}

private func runNetworkProxyProbeCommand(
    _ probe: NetworkProxyProbeCommand,
    runner: NetworkProxyCommandRunner
) -> NetworkProxyProbeResult {
    do {
        let result = try runner(probe.command)
        return networkProxyProbeResult(name: probe.name, command: probe.command, result: result, error: nil)
    } catch HostCommandRunError.nonZeroExit(_, let result) {
        return networkProxyProbeResult(name: probe.name, command: probe.command, result: result, error: nil)
    } catch {
        return NetworkProxyProbeResult(
            name: probe.name,
            command: hostSourceCommand(probe.command),
            ok: false,
            exitCode: nil,
            stdoutPreview: nil,
            stderrPreview: nil,
            stdoutTruncated: false,
            stderrTruncated: false,
            error: String(describing: error)
        )
    }
}

private func networkProxyProbeResult(
    name: String,
    command: TKHostCommand,
    result: HostProcessResult,
    error: String?
) -> NetworkProxyProbeResult {
    NetworkProxyProbeResult(
        name: name,
        command: hostSourceCommand(command),
        ok: result.exitCode == 0,
        exitCode: Int(result.exitCode),
        stdoutPreview: networkProxyProbePreview(result.stdout),
        stderrPreview: networkProxyProbePreview(result.stderr),
        stdoutTruncated: result.stdoutTruncated,
        stderrTruncated: result.stderrTruncated,
        error: error
    )
}

private func networkProxyProbePreview(_ value: String, limit: Int = 1_000) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.count <= limit {
        return trimmed
    }
    return String(trimmed.prefix(limit))
}

private func networkProxyProbeFindings(
    platform: HostDevicePlatform,
    results: [NetworkProxyProbeResult]
) -> [NetworkProxyProbeFinding] {
    guard platform == .harmony else { return [] }
    var seen: Set<String> = []
    var findings: [NetworkProxyProbeFinding] = []
    for result in results where result.ok && result.name.hasPrefix("harmony.param.") {
        for line in (result.stdoutPreview ?? "").split(whereSeparator: \.isNewline) {
            guard let parameter = harmonyProbeParameterName(from: String(line)) else { continue }
            let lowercased = parameter.lowercased()
            guard lowercased.contains("proxy") || lowercased.contains("http") else { continue }
            let key = "\(result.name)\u{0}\(parameter)"
            guard seen.insert(key).inserted else { continue }
            findings.append(NetworkProxyProbeFinding(
                platform: "harmony",
                source: result.name,
                category: "harmony.proxy-parameter-candidate",
                name: parameter,
                verifiedMutation: false,
                requiredAction: "manual_verification_required"
            ))
        }
    }
    return findings
}

private func harmonyProbeParameterName(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let candidate: String
    if trimmed.hasPrefix("["),
       let end = trimmed.dropFirst().firstIndex(of: "]") {
        candidate = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
    } else if let equals = trimmed.firstIndex(of: "=") {
        candidate = String(trimmed[..<equals])
    } else {
        candidate = String(trimmed.split(whereSeparator: \.isWhitespace).first ?? "")
    }

    let name = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "[]'\" "))
    guard !name.isEmpty else { return nil }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-:"))
    guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
    return name
}

private func networkProxyProbeLimitations(
    platform: HostDevicePlatform,
    results: [NetworkProxyProbeResult]?
) -> [String] {
    var limitations = ["proxy_probe_readonly:not_mutated"]
    if platform == .harmony {
        limitations.append("proxy_harmony_probe_only:no_verified_proxy_mutation")
        limitations.append("proxy_harmony_param_probe:readonly_param_ls_only")
        if let results {
            if !networkProxyProbeFindings(platform: platform, results: results).isEmpty {
                limitations.append("proxy_harmony_candidate_parameters_found:manual_verification_required")
            } else {
                limitations.append("proxy_harmony_no_verified_proxy_parameter:no_mutation_command")
            }
        }
    }
    return limitations
}
