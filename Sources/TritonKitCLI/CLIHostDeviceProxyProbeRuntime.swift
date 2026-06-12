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
