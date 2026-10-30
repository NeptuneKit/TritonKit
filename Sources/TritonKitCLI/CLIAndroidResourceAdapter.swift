import Foundation
import TritonKitShared

struct AndroidResourceAdapter: EmulatorResourceAdapter {
    private let device: String
    private let executable: String
    private let runner: EmulatorResourceRunner
    private static let outputLimit = 1_048_576

    init(device: String, executable: String = "adb", runner: @escaping EmulatorResourceRunner = { try runHostCommand($0) }) {
        self.device = device
        self.executable = executable
        self.runner = runner
    }

    func identity() throws -> EmulatorResourceIdentity {
        let serial = try serial()
        guard try execute(["get-state"]).trimmingCharacters(in: .whitespacesAndNewlines) == "device" else {
            throw EmulatorResourceError("resource_target_not_ready", "Android emulator is not in device state")
        }
        let kernel = try property("ro.kernel.qemu")
        let boot = try property("ro.boot.qemu")
        guard [kernel, boot].allSatisfy({ $0.isEmpty || $0 == "1" }), kernel == "1" || boot == "1" else {
            throw EmulatorResourceError("resource_invalid_target", "Android target did not prove it is a local emulator")
        }
        let instance = try identityField(property("ro.boot.qemu.avd_name"), maximumLength: 256)
        let image = try identityField(property("ro.build.fingerprint"), maximumLength: 1024)
        let rawBootID = try identityField(execute(["shell", "cat", "/proc/sys/kernel/random/boot_id"]), maximumLength: 36)
        guard let bootID = UUID(uuidString: rawBootID), bootID.uuidString.lowercased() == rawBootID.lowercased(),
              rawBootID != "00000000-0000-0000-0000-000000000000" else {
            throw EmulatorResourceError("resource_identity_unavailable", "Android boot identity is invalid")
        }
        return .init(platform: .android, target: serial, instance: instance, image: image, bootID: bootID.uuidString.lowercased())
    }

    func read(_ item: EmulatorResourceItem) throws -> EmulatorResourceState {
        try EmulatorResourceCatalog.validate(item, platform: .android, value: item.disabledValue)
        switch item.kind {
        case .package:
            return try packageState(item)
        case .bluetooth:
            return try bluetoothState(item)
        case .service:
            throw EmulatorResourceError("resource_invalid_item", "Android service is outside the managed allowlist")
        }
    }

    func write(_ item: EmulatorResourceItem, value: String) throws {
        try EmulatorResourceCatalog.validate(item, platform: .android, value: value)
        switch item.kind {
        case .package:
            let states: [String: (String, String)] = [
                "0": ("default-state", "default"), "1": ("enable", "enabled"),
                "2": ("disable", "disabled"), "3": ("disable-user", "disabled-user"),
                "4": ("disable-until-used", "disabled-until-used")
            ]
            guard let state = states[value] else { throw EmulatorResourceError("resource_invalid_state", "Invalid package state") }
            let output = try execute(["shell", "pm", state.0, "--user", "0", item.id], mutation: true)
            guard output.trimmingCharacters(in: .whitespacesAndNewlines) == "Package \(item.id) new state: \(state.1)" else {
                throw EmulatorResourceError("resource_write_unconfirmed", "Android package manager did not acknowledge the requested state")
            }
        case .bluetooth:
            let action = value == "on" ? "enable" : "disable"
            let output = try execute(["shell", "cmd", "bluetooth_manager", action], mutation: true)
            let acknowledgement = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let actionAcknowledgement = "BluetoothShellCommand: Exec \(action)\n\(action): Success"
            guard ["", "true", actionAcknowledgement].contains(acknowledgement) else {
                throw EmulatorResourceError("resource_write_unconfirmed", "Android Bluetooth command returned an unexpected acknowledgement")
            }
        case .service:
            throw EmulatorResourceError("resource_invalid_item", "Android service is outside the managed allowlist")
        }
    }

    func measure() throws -> EmulatorResourceGuestMemory {
        let output = try execute(["shell", "dumpsys", "meminfo", "--oom"], sensitiveOutput: true)
        var inside = false
        var selectedSection: String?
        var sectionCounts: [String: Int] = [:]
        var categoryCount = 0
        var insideCategory = false
        var closed = false
        var partial = false
        var seenPIDs = Set<Int32>()
        var processes: [EmulatorResourceProcessMemory] = []
        let oomCategories: Set<String> = ["Native", "System", "Persistent", "Persistent Service", "Foreground", "Visible",
            "Perceptible", "Perceptible Low", "Perceptible Medium", "Heavy Weight", "Backup", "A Services", "Home", "Previous", "B Services", "Cached"]
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if ["Total PSS by process:", "Total PSS by OOM adjustment:"].contains(line) {
                sectionCounts[line, default: 0] += 1
                if sectionCounts[line, default: 0] > 1 { partial = true }
                if selectedSection == nil {
                    selectedSection = line
                    inside = true
                } else {
                    if inside { closed = true }
                    inside = false
                }
                continue
            }
            if line.hasPrefix("Total ") || ["Free RAM:", "Used RAM:", "Lost RAM:", "ZRAM:", "KSM:", "Tuning:"].contains(where: { line.hasPrefix($0) }) {
                if inside { closed = true }
                inside = false
                continue
            }
            guard inside, !line.isEmpty else { continue }
            guard line.utf8.count <= 4096 else { partial = true; continue }
            if selectedSection == "Total PSS by OOM adjustment:" {
                if !line.contains("(pid") {
                    // Numeric fields are right-aligned, so whitespace does not identify OOM bucket totals.
                    guard let category = captures(#"^([0-9]+|[1-9][0-9]{0,2}(?:,[0-9]{3})+)K: ([^()]+)$"#, line),
                          oomCategories.contains(category[1]),
                          let kilobytes = UInt64(category[0].replacingOccurrences(of: ",", with: "")),
                          kilobytes <= UInt64.max / 1024 else {
                        partial = true
                        insideCategory = false
                        continue
                    }
                    categoryCount += 1
                    insideCategory = true
                    continue
                }
                guard insideCategory else { partial = true; continue }
            }
            guard let groups = captures(#"^([0-9]+|[1-9][0-9]{0,2}(?:,[0-9]{3})+)K: ([^\s]+) \(pid ([0-9]+)(?: / [^)]+)?\)$"#, line),
                  let kibibytes = UInt64(groups[0].replacingOccurrences(of: ",", with: "")),
                  kibibytes <= UInt64.max / 1024,
                  let pid = Int32(groups[2]), pid > 0 else {
                partial = true
                continue
            }
            guard seenPIDs.insert(pid).inserted else { partial = true; continue }
            let name = groups[1]
            guard isManagedProcess(name) else { continue }
            processes.append(.init(pid: pid, name: name, pssBytes: kibibytes * 1024))
        }
        partial = partial || selectedSection == nil || !closed || (selectedSection == "Total PSS by OOM adjustment:" && categoryCount == 0)
        return .init(metric: "guest_pss_bytes", processes: processes, partial: partial,
                     reason: partial ? "Android PSS process section was missing, incomplete, or contained invalid entries" : nil)
    }

    private func packageState(_ item: EmulatorResourceItem) throws -> EmulatorResourceState {
        let output = try execute(["shell", "dumpsys", "package", item.id])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "Unable to find package: \(item.id)" || trimmed == "Package \(item.id) was not found." {
            return .init(item: item, value: nil, available: false, reason: "Package is not installed")
        }
        var packageSectionCount = 0
        var insidePackages = false
        var matchedPackageCount = 0
        var insidePackage = false
        var userLines: [String] = []
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if rawLine.first?.isWhitespace == false {
                insidePackages = line == "Packages:"
                insidePackage = false
                if insidePackages { packageSectionCount += 1 }
                continue
            }
            // Queries and hidden system packages have their own User 0 entries, outside this top-level section.
            guard insidePackages else { continue }
            if let groups = captures(#"^Package \[([^\]]+)\] \([^)]*\):$"#, line) {
                insidePackage = groups[0] == item.id
                if insidePackage { matchedPackageCount += 1 }
                continue
            }
            if insidePackage, line.hasPrefix("User 0:") { userLines.append(line) }
        }
        guard packageSectionCount == 1, matchedPackageCount == 1, userLines.count == 1,
              let installed = singleToken("installed", in: userLines[0]), ["true", "false"].contains(installed),
              let enabled = singleToken("enabled", in: userLines[0]), ["0", "1", "2", "3", "4"].contains(enabled) else {
            throw EmulatorResourceError("resource_state_unavailable", "Android package User 0 state is missing, invalid, or ambiguous")
        }
        if installed == "false" {
            return .init(item: item, value: nil, available: false, reason: "Package is not installed for User 0")
        }
        return .init(item: item, value: enabled)
    }

    private func bluetoothState(_ item: EmulatorResourceItem) throws -> EmulatorResourceState {
        let output = try execute(["shell", "dumpsys", "bluetooth_manager"])
        var sectionCount = 0
        var inside = false
        var enabled: [String] = []
        var states: [String] = []
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line == "Bluetooth Status" {
                sectionCount += 1
                inside = sectionCount == 1
                continue
            }
            guard inside else { continue }
            // Current state is the first indented status block. Logs later in the dump are historical.
            guard !line.isEmpty, rawLine.first?.isWhitespace == true else { inside = false; continue }
            if line.hasSuffix(":") { inside = false; continue }
            if line.hasPrefix("enabled:") { enabled.append(String(line.dropFirst("enabled:".count)).trimmingCharacters(in: .whitespaces)) }
            if line.hasPrefix("state:") { states.append(String(line.dropFirst("state:".count)).trimmingCharacters(in: .whitespaces)) }
        }
        let unknown = EmulatorResourceState(item: item, value: nil, available: false, reason: "Current Bluetooth state is unavailable, conflicting, or transitional")
        guard sectionCount == 1, enabled.count <= 1, states.count <= 1, !enabled.isEmpty || !states.isEmpty else { return unknown }
        let enabledState: String?
        if let value = enabled.first {
            guard value == "true" || value == "false" else { return unknown }
            enabledState = value == "true" ? "on" : "off"
        } else { enabledState = nil }
        let adapterState: String?
        if let value = states.first {
            guard value == "ON" || value == "OFF" else { return unknown }
            adapterState = value == "ON" ? "on" : "off"
        } else { adapterState = nil }
        if let enabledState, let adapterState, enabledState != adapterState { return unknown }
        return .init(item: item, value: adapterState ?? enabledState)
    }

    private func serial() throws -> String {
        let serial = device.hasPrefix("android:") ? String(device.dropFirst("android:".count)) : device
        guard let groups = captures(#"^emulator-([1-9][0-9]{3,4})$"#, serial),
              let port = Int(groups[0]), port >= 1024, port <= 65534, port.isMultiple(of: 2) else {
            throw EmulatorResourceError("resource_invalid_target", "Use an explicit local emulator-<evenport> Android target")
        }
        return serial
    }

    private func property(_ name: String) throws -> String {
        try execute(["shell", "getprop", name]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func identityField(_ raw: String, maximumLength: Int) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= maximumLength,
              !["unknown", "null", "(null)"].contains(value.lowercased()),
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && !CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            throw EmulatorResourceError("resource_identity_unavailable", "Android emulator identity field is missing or invalid")
        }
        return value
    }

    private func execute(_ arguments: [String], mutation: Bool = false, sensitiveOutput: Bool = false) throws -> String {
        let command = TKHostCommand(executable: executable, arguments: ["-s", try serial()] + arguments,
            riskLevel: mutation ? .automation : .readonly, defaultTimeoutSeconds: 30, sensitiveOutput: sensitiveOutput)
        let result = try runner(command)
        guard result.exitCode == 0 else { throw EmulatorResourceError("resource_command_failed", "Android command failed") }
        guard !result.stdoutTruncated, !result.stderrTruncated,
              result.stdoutData.count <= Self.outputLimit, result.stderrData.count <= Self.outputLimit,
              let stdout = String(data: result.stdoutData, encoding: .utf8),
              let stderr = String(data: result.stderrData, encoding: .utf8) else {
            throw EmulatorResourceError("resource_output_invalid", "Android command output is truncated, oversized, or invalid UTF-8")
        }
        let failure = #"(?im)^\s*(?:error\b|failure\b|failed\b|exception\b|securityexception\b|permission denial\b|permission denied\b|unknown command\b|cmd:\s*(?:failure|can't|cannot|unknown|error)|/system/bin/sh:|(?:java\.[\w.]+Exception)\b|can't find service\b|cannot find service\b)"#
        guard !matches(failure, stdout), !matches(failure, stderr) else {
            throw EmulatorResourceError("resource_command_failed", "Android command reported an error")
        }
        return stdout
    }

    private func singleToken(_ name: String, in line: String) -> String? {
        let tokens = line.split(whereSeparator: \.isWhitespace).filter { $0.hasPrefix(name + "=") }
        guard tokens.count == 1 else { return nil }
        return String(tokens[0].dropFirst(name.count + 1))
    }

    private func isManagedProcess(_ name: String) -> Bool {
        let packages = EmulatorResourceCatalog.items(.android).filter { $0.kind == .package }.map(\.id) + ["com.android.bluetooth"]
        if packages.contains(where: { name == $0 || name.hasPrefix($0 + ":") }) { return true }
        return matches(#"^android\.hardware\.bluetooth(?:@[0-9]+\.[0-9]+-service|-service)(?:\.[A-Za-z0-9_-]+)?$"#, name)
    }

    private func matches(_ pattern: String, _ value: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    private func captures(_ pattern: String, _ value: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: value).map { String(value[$0]) }
        }
    }
}
