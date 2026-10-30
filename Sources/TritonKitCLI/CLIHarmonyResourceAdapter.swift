import Foundation
import TritonKitShared

/// Service controls intentionally require an already privileged, readable shell.
/// This adapter never changes shell privileges or guest security policy.
struct HarmonyResourceAdapter: EmulatorResourceAdapter {
    let device: String
    let executable: String
    let runner: EmulatorResourceRunner

    init(device: String, executable: String = "hdc", runner: @escaping EmulatorResourceRunner = { try runHostCommand($0) }) {
        self.device = device
        self.executable = executable
        self.runner = runner
    }

    func identity() throws -> EmulatorResourceIdentity {
        let target = try target()
        let model = try shell(["param", "get", "const.product.model"])
        let name = try shell(["param", "get", "const.product.name"])
        let software = try shell(["param", "get", "const.product.software.version"])
        guard model == "emulator", name == "emulator",
              software.range(of: #"^emulator [A-Za-z0-9][A-Za-z0-9._()+-]{0,254}$"#, options: .regularExpression) != nil else {
            throw EmulatorResourceError("resource_invalid_identity", "Guest identity does not identify a supported Harmony emulator")
        }
        let bootID: String
        do {
            let output = try shell(["cat", "/proc/sys/kernel/random/boot_id"])
            guard output.count == 36, let uuid = UUID(uuidString: output) else {
                throw EmulatorResourceError("resource_identity_unavailable", "Harmony boot identity is not recognized")
            }
            bootID = uuid.uuidString.lowercased()
        } catch let error as EmulatorResourceError where error.code == "resource_permission_denied" {
            // Commercial images deny boot_id to the shell. Keep read-only status
            // useful, but no resource mutation is available without a boot token.
            bootID = "unavailable"
        }
        // These fields describe the observed endpoint and software version, not a
        // unique host HVD identifier or a cryptographic system-image fingerprint.
        return .init(platform: .harmony, target: target, instance: "\(target)|\(model)", image: software, bootID: bootID)
    }

    func read(_ item: EmulatorResourceItem) throws -> EmulatorResourceState {
        try EmulatorResourceCatalog.validate(item, platform: .harmony, value: "stopped")
        var value: String?
        do {
            value = try serviceState(item)
            try verifyControlCapability()
            guard try identity().bootID != "unavailable" else {
                throw EmulatorResourceError("resource_identity_unavailable", "Harmony boot identity is required for service control")
            }
            return .init(item: item, value: value)
        } catch let error as EmulatorResourceError {
            return .init(item: item, value: value, available: false, reason: error.code)
        } catch {
            return .init(item: item, value: value, available: false, reason: "resource_command_failed")
        }
    }

    func write(_ item: EmulatorResourceItem, value: String) throws {
        try EmulatorResourceCatalog.validate(item, platform: .harmony, value: value)
        let previous = try read(item)
        guard previous.available else {
            throw EmulatorResourceError(previous.reason ?? "resource_control_permission_unverified", "Harmony service control is unavailable")
        }
        if previous.value == value { return }
        let action = value == "stopped" ? "stop" : "start"
        let output = try shell(["begetctl", "service_control", action, item.id], mutation: true)
        guard output.isEmpty else {
            throw EmulatorResourceError("resource_invalid_output", "Harmony service control returned an unrecognized response")
        }
        // begetctl can exit zero even when the request fails. Readback is mandatory.
        for attempt in 0..<3 {
            if try serviceState(item) == value { return }
            if attempt < 2 { Thread.sleep(forTimeInterval: 0.05) }
        }
        throw EmulatorResourceError("resource_state_mismatch", "Harmony service did not reach the requested state")
    }

    func measure() throws -> EmulatorResourceGuestMemory {
        let output = try shell(["hidumper", "--mem", "--prune"])
        return try Self.parseMemory(output)
    }

    /// Format captured from DevEco emulator 6.0.0.130, HarmonyOS 6.0.2/API 22.
    /// `Total Pss` already carries the displayed SwapPss contribution.
    static func parseMemory(_ output: String) throws -> EmulatorResourceGuestMemory {
        func invalid() -> EmulatorResourceError {
            .init("resource_memory_invalid_output", "Harmony memory output is not recognized")
        }
        guard output.utf8.count <= 1_048_576 else { throw invalid() }
        let lines = output.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard let title = lines.firstIndex(of: "Total Memory Usage by PID:"),
              title + 1 < lines.count,
              lines.filter({ $0 == "Total Memory Usage by PID:" }).count == 1 else { throw invalid() }
        let header = #"^PID\s+Total Pss\(xxx in SwapPss\)\s+GL\s+AdjLabel\s+Name$"#
        guard lines[title + 1].range(of: header, options: .regularExpression) != nil else { throw invalid() }
        let row = try NSRegularExpression(pattern: #"^([1-9][0-9]*)\s+([0-9]+)\(([0-9]+) in SwapPss\) kB\s+([0-9]+) kB\s+(-?[0-9]+)\s+(\S+)$"#)
        let allowed = Set(EmulatorResourceCatalog.items(.harmony).map(\.id))
        var processes: [EmulatorResourceProcessMemory] = []
        var seenPIDs: Set<Int32> = []
        var totalBytes: UInt64 = 0
        for line in lines.dropFirst(title + 2) {
            guard let match = row.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { throw invalid() }
            func field(_ index: Int) -> String? {
                Range(match.range(at: index), in: line).map { String(line[$0]) }
            }
            guard let name = field(6), let rawPID = field(1), let pid = Int32(rawPID),
                  seenPIDs.insert(pid).inserted else { throw invalid() }
            guard allowed.contains(name) else { continue }
            guard let rawPSS = field(2), let pssKB = UInt64(rawPSS),
                  let rawSwap = field(3), UInt64(rawSwap) != nil else { throw invalid() }
            let (bytes, overflow) = pssKB.multipliedReportingOverflow(by: 1024)
            guard !overflow else { throw invalid() }
            let (total, totalOverflow) = totalBytes.addingReportingOverflow(bytes)
            guard !totalOverflow else { throw invalid() }
            totalBytes = total
            processes.append(.init(pid: pid, name: name, pssBytes: bytes))
        }
        guard !seenPIDs.isEmpty else { throw invalid() }
        return .init(metric: "guest_total_pss_bytes", processes: processes.sorted { $0.pid < $1.pid }, partial: false, reason: nil)
    }

    private func serviceState(_ item: EmulatorResourceItem) throws -> String {
        let output = try shell(["param", "get", "startup.service.ctl.\(item.id)"])
        guard output == "running" || output == "stopped" else {
            throw EmulatorResourceError("resource_invalid_output", "Harmony service state is not recognized")
        }
        return output
    }

    private func verifyControlCapability() throws {
        let uid = try shell(["id", "-u"])
        guard uid == "0" else {
            guard UInt32(uid) != nil else {
                throw EmulatorResourceError("resource_invalid_output", "Harmony shell identity is not recognized")
            }
            // Non-root may have vendor-specific rights, but reading a parameter does
            // not prove permission to write its separate service-control key.
            throw EmulatorResourceError("resource_control_permission_unverified", "Service control permission is not verified for this shell")
        }
        let help = try shell(["begetctl", "--help"])
        let lines = help.split(whereSeparator: \.isNewline).map { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
        guard lines.contains(where: { Array($0.prefix(3)) == ["service_control", "stop", "servicename"] }),
              lines.contains(where: { Array($0.prefix(3)) == ["service_control", "start", "servicename"] }) else {
            throw EmulatorResourceError("resource_unsupported_control", "Harmony service-control commands are unavailable")
        }
    }

    private func target() throws -> String {
        let value = device.hasPrefix("harmony:") ? String(device.dropFirst("harmony:".count)) : device
        let prefix = "127.0.0.1:"
        guard value.hasPrefix(prefix) else {
            throw EmulatorResourceError("resource_invalid_target", "Harmony resource controls require an explicit local emulator target")
        }
        let port = String(value.dropFirst(prefix.count))
        guard !port.isEmpty, port.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let number = UInt16(port), number > 0, String(number) == port else {
            throw EmulatorResourceError("resource_invalid_target", "Harmony resource target is invalid")
        }
        return value
    }

    private func shell(_ arguments: [String], mutation: Bool = false) throws -> String {
        let command = TKHostCommand(executable: executable,
            arguments: ["-t", try target(), "shell"] + arguments,
            redactedArgumentIndexes: [1], riskLevel: mutation ? .automation : .readonly,
            defaultTimeoutSeconds: 15, sensitiveOutput: true)
        let result: HostProcessResult
        do {
            result = try runner(command)
        } catch HostCommandRunError.nonZeroExit(_, let result) {
            throw Self.failure(result) ?? EmulatorResourceError("resource_command_failed", "Harmony command failed")
        } catch {
            throw EmulatorResourceError("resource_command_failed", "Harmony command could not complete")
        }
        if let failure = Self.failure(result) { throw failure }
        guard let stdout = String(data: result.stdoutData, encoding: .utf8),
              let stderr = String(data: result.stderrData, encoding: .utf8),
              stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmulatorResourceError("resource_invalid_output", "Harmony command output is not recognized")
        }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func failure(_ result: HostProcessResult) -> EmulatorResourceError? {
        if result.stdoutTruncated || result.stderrTruncated {
            return .init("resource_output_truncated", "Harmony command output is incomplete")
        }
        let text = (result.stdout + "\n" + result.stderr).lowercased()
        let denied = ["permission denied", "not permitted", "forbidden", "forbided", "avc: denied"].contains { text.contains($0) }
        let deniedCode = text.range(of: #"(?:^|[^0-9])100[12](?:[^0-9]|$)"#, options: .regularExpression) != nil
            && (text.contains("error") || text.contains("fail") || text.trimmingCharacters(in: .whitespacesAndNewlines) == "1002" || text.trimmingCharacters(in: .whitespacesAndNewlines) == "1001")
        if denied || deniedCode {
            return .init("resource_permission_denied", "Harmony denied access to the requested operation")
        }
        if result.exitCode != 0 || text.contains("[fail]") || text.hasPrefix("error:") || text.hasPrefix("failed") {
            return .init("resource_command_failed", "Harmony command failed")
        }
        return nil
    }
}
