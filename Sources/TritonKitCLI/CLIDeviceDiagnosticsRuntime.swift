import Darwin
import Foundation
import TritonKitShared

func validateDeviceDiagnosticsBudget(timeout: Double, maximumBytes: Int, maximumEntries: Int) throws {
    guard timeout.isFinite, (0.1...300).contains(timeout), (1...16_777_216).contains(maximumBytes), (1...10_000).contains(maximumEntries) else { throw DeviceDiagnosticsError.invalidRequest }
}
func validateDeviceCrashName(_ name: String) throws {
    guard name.utf8.count <= 255, !name.isEmpty, !name.hasPrefix("-"), name != ".", name != "..",
          name.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._- ").contains($0) }) else { throw DeviceDiagnosticsError.invalidRequest }
}
func deviceDiagnosticsLogCommand(platform: HostDevicePlatform, scope: String?, target: String, timeout: Double, lastSeconds: Int, adb: String, hdc: String, idevicesyslog: String) throws -> TKHostCommand {
    guard (1...86_400).contains(lastSeconds), timeout.isFinite, timeout > 0 else { throw DeviceDiagnosticsError.invalidRequest }
    switch platform {
    case .ios:
        if scope == "real" { return TKHostCommand(executable: idevicesyslog, arguments: ["-u", target], defaultTimeoutSeconds: timeout + 3) }
        return TKHostCommand(executable: "/usr/bin/xcrun", arguments: ["simctl", "spawn", target, "log", "show", "--style", "json", "--last", "\(lastSeconds)s"], defaultTimeoutSeconds: timeout)
    case .android: return TKHostCommand(executable: adb, arguments: ["-s", target, "logcat", "-d", "-v", "threadtime", "-t", "10000"], defaultTimeoutSeconds: timeout)
    case .harmony: return TKHostCommand(executable: hdc, arguments: ["-t", target, "shell", "hilog", "-x"], defaultTimeoutSeconds: timeout)
    }
}
private func diagnosticsProcess(_ command: TKHostCommand, maximumBytes: Int, interruptAfter: Double? = nil) throws -> HostProcessResult {
    do { return try runHostCommand(command, interruptAfter: interruptAfter, maximumOutputBytes: maximumBytes) }
    catch HostCommandRunError.nonZeroExit(_, let result) where interruptAfter != nil && result.stdoutBytes > 0 { return result }
    catch HostCommandRunError.launchFailed { throw DeviceDiagnosticsError.unavailable("Selected source executable is not installed or cannot launch; iOS real system logs require libimobiledevice idevicesyslog.") }
    catch HostCommandRunError.timeout { throw DeviceDiagnosticsError.unavailable("Source query timed out; no complete body is claimed.") }
    catch { throw DeviceDiagnosticsError.unavailable("Source query failed or access was denied; no alternate device/backend was used.") }
}
private func diagnosticsArtifact(_ data: Data, workspace: String, name: String) throws -> String {
    let path = workspace + "/" + name
    try data.write(to: URL(fileURLWithPath: path), options: .withoutOverwriting)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    return path
}
func captureDeviceLogs(selection: HostDeviceSelectionResult, timeout: Double = 10, maximumBytes: Int = 1_048_576, lastSeconds: Int = 60, includeContent: Bool = false, adb: String = "adb", hdc: String = "hdc", idevicesyslog: String = "idevicesyslog") throws -> DeviceDiagnosticsOutput {
    try validateDeviceDiagnosticsBudget(timeout: timeout, maximumBytes: maximumBytes, maximumEntries: 1)
    var target = selection.target.rawTarget
    let physicalIOS = selection.platform == .ios && selection.target.scope == "real"
    if physicalIOS {
        // CoreDevice identifier is not necessarily the USB UDID accepted by libimobiledevice.
        let candidates = ([target] + selection.target.rawTargetAliases).filter { $0.range(of: #"^([0-9A-Fa-f]{40}|[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16})$"#, options: .regularExpression) != nil }
        guard let udid = candidates.first else { throw DeviceDiagnosticsError.unavailable("Selected physical device has no verified USB UDID alias for idevicesyslog; no guessed identity is used.") }
        target = udid
    }
    let command = try deviceDiagnosticsLogCommand(platform: selection.platform, scope: selection.target.scope, target: target, timeout: timeout, lastSeconds: lastSeconds, adb: adb, hdc: hdc, idevicesyslog: idevicesyslog)
    let result = try diagnosticsProcess(command, maximumBytes: maximumBytes, interruptAfter: physicalIOS ? timeout : nil)
    let workspace = try makeDeviceAdministrationWorkspace()
    let artifact = try diagnosticsArtifact(result.stdoutData, workspace: workspace, name: "device.log")
    let source = physicalIOS ? "libimobiledevice-system-log-live-sample" : (selection.platform == .ios ? "simulator-unified-log" : (selection.platform == .android ? "android-logcat" : "harmony-hilog"))
    return .init(action: "device.logs", target: selection.target, source: source, sourceCommands: [hostSourceCommand(command)], artifacts: [artifact], bytes: result.stdoutData.count, maximumBytes: maximumBytes, partial: result.stdoutTruncated || physicalIOS, limitations: [physicalIOS ? "Live bounded sample only; idevicesyslog is an optional external dependency for readonly physical iOS system logs. No app is launched." : "Historical platform log buffer only; Android -t 10000 bounds record count and Harmony uses native buffer dump. lastSeconds applies only to Simulator unified logs.", "Diagnostic contents may contain sensitive application data; artifact is owner-only. Output byte budget bounds accepted content, not native log completeness."], entries: [], content: includeContent ? String(decoding: result.stdoutData, as: UTF8.self) : nil)
}

private func localCrashReportRoot() -> String { FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Logs/DiagnosticReports" }
private func readLocalDiagnosticReport(root: String, name: String, maximumBytes: Int) throws -> Data {
    try validateDeviceCrashName(name)
    var fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { throw DeviceDiagnosticsError.unsafeArtifact }
    defer { close(fd) }
    for part in try validatedDeviceFSComponents(root: root) {
        let next = openat(fd, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard next >= 0 else { throw DeviceDiagnosticsError.unsafeArtifact }; close(fd); fd = next
    }
    let child = openat(fd, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
    guard child >= 0 else { throw DeviceDiagnosticsError.unsafeArtifact }
    let handle = FileHandle(fileDescriptor: child, closeOnDealloc: true); defer { try? handle.close() }
    var info = stat()
    guard fstat(child, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid(), info.st_size >= 0, info.st_size <= maximumBytes else { throw DeviceDiagnosticsError.unsafeArtifact }
    let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
    guard data.count <= maximumBytes else { throw DeviceDiagnosticsError.unsafeArtifact }; return data
}
func simulatorCrashBodyMatchesTarget(_ data: Data, udid: String) -> Bool {
    // .ips starts with a JSON header, followed by a JSON report. Bind parsed procPath to
    // the exact Simulator data directory; host crashes and ambiguous reports are excluded.
    guard UUID(uuidString: udid) != nil, let text = String(data: data, encoding: .utf8) else { return false }
    let records = [text, text.components(separatedBy: "\n").dropFirst().joined(separator: "\n")]
    for record in records {
        guard let object = try? JSONSerialization.jsonObject(with: Data(record.utf8)) as? [String: Any], let path = object["procPath"] as? String else { continue }
        let parts = path.split(separator: "/").map(String.init)
        for index in parts.indices where parts[index] == "Devices" && index + 2 < parts.count {
            if UUID(uuidString: parts[index + 1]) == UUID(uuidString: udid), parts[index + 2] == "data" { return true }
        }
    }
    return false
}

func listDeviceCrashes(selection: HostDeviceSelectionResult, timeout: Double = 10, maximumBytes: Int = 1_048_576, maximumEntries: Int = 1000, adb: String = "adb", hdc: String = "hdc") throws -> DeviceDiagnosticsOutput {
    try validateDeviceDiagnosticsBudget(timeout: timeout, maximumBytes: maximumBytes, maximumEntries: maximumEntries)
    if selection.platform == .ios, selection.target.scope == "real" {
        let metadata = try makeIOSDeviceFilesOutput(selection: selection, request: TKDevicectlFilesRequest(domain: "systemCrashLogs"), includeSensitive: true, timeout: timeout, maximumJSONBytes: maximumBytes, maximumEntries: maximumEntries)
        let entries = metadata.entries.compactMap { value -> DeviceDiagnosticsEntry? in
            guard let name = value.name, (try? validateDeviceCrashName(name)) != nil, value.kind == "non-directory" else { return nil }
            return .init(name: name, source: "coredevice-systemCrashLogs", sizeBytes: value.sizeBytes)
        }
        return .init(action: "device.crashes.list", target: selection.target, source: "coredevice-systemCrashLogs-metadata", sourceCommands: metadata.sourceCommands, artifacts: metadata.artifacts, bytes: 0, maximumBytes: maximumBytes, partial: false, limitations: ["List returns native systemCrashLogs metadata; get explicitly copies and validates the report body."], entries: entries, content: nil)
    }
    if selection.platform == .ios {
        let root = localCrashReportRoot()
        let metadata = try readDeviceFSShallowMetadata(root: root, maximumEntries: maximumEntries, requiredOwner: getuid())
        var entries: [DeviceDiagnosticsEntry] = []; var partial = false
        for entry in metadata where entry.kind == "regular-file" && entry.name.hasSuffix(".ips") {
            guard let data = try? readLocalDiagnosticReport(root: root, name: entry.name, maximumBytes: maximumBytes) else { partial = true; continue }
            if simulatorCrashBodyMatchesTarget(data, udid: selection.target.rawTarget) { entries.append(.init(name: entry.name, source: "host-simulator-ips", sizeBytes: entry.sizeBytes)) }
        }
        return .init(action: "device.crashes.list", target: selection.target, source: "host-simulator-ips-procPath-bound", sourceCommands: [], artifacts: [], bytes: 0, maximumBytes: maximumBytes, partial: partial, limitations: ["Only .ips reports whose parsed procPath identifies the exact Simulator data directory; legacy .crash and ambiguous host reports are excluded."], entries: entries, content: nil)
    }
    let android = selection.platform == .android
    let root = android ? "/data/tombstones" : "/data/log/faultlog/faultlogger"
    let command = TKHostCommand(executable: android ? adb : hdc, arguments: [android ? "-s" : "-t", selection.target.rawTarget, "shell", "ls", "-1", root], defaultTimeoutSeconds: timeout)
    var entries = android ? [DeviceDiagnosticsEntry(name: "crash-buffer", source: "android-logcat-crash-buffer", sizeBytes: nil)] : []
    var partial = false
    if let result = try? diagnosticsProcess(command, maximumBytes: maximumBytes) {
        partial = result.stdoutTruncated
        for name in result.stdout.split(separator: "\n").map(String.init) where (try? validateDeviceCrashName(name)) != nil {
            if entries.count >= maximumEntries { partial = true; break }
            entries.append(.init(name: name, source: android ? "android-tombstone" : "harmony-faultlogger", sizeBytes: nil))
        }
    } else { partial = true }
    return .init(action: "device.crashes.list", target: selection.target, source: android ? "android-crash-buffer-and-tombstones" : "harmony-faultlogger", sourceCommands: [hostSourceCommand(command)], artifacts: [], bytes: 0, maximumBytes: maximumBytes, partial: partial, limitations: ["Tombstone/faultlogger access depends on native device permissions. Denied listing is partial; no root, remount, permission change or log clearing is attempted."], entries: entries, content: nil)
}

func getDeviceCrash(selection: HostDeviceSelectionResult, name: String, timeout: Double = 10, maximumBytes: Int = 1_048_576, adb: String = "adb", hdc: String = "hdc") throws -> DeviceDiagnosticsOutput {
    try validateDeviceCrashName(name)
    try validateDeviceDiagnosticsBudget(timeout: timeout, maximumBytes: maximumBytes, maximumEntries: 1000)
    let listed = try listDeviceCrashes(selection: selection, timeout: timeout, maximumBytes: maximumBytes, adb: adb, hdc: hdc)
    guard let entry = listed.entries.first(where: { $0.name == name }), entry.sizeBytes == nil || entry.sizeBytes! <= maximumBytes else { throw DeviceDiagnosticsError.unavailable("Report absent from fresh target-bound listing or exceeds byte budget.") }
    let workspace = try makeDeviceAdministrationWorkspace()
    var commands = listed.sourceCommands, artifacts = listed.artifacts, partial = false
    let data: Data
    if selection.platform == .ios, selection.target.scope == "real" {
        let destination = workspace + "/report.body", json = workspace + "/copy.json", log = workspace + "/copy.log"
        let command = TKHostCommand(executable: "/usr/bin/xcrun", arguments: ["devicectl", "device", "copy", "from", "--device", selection.target.rawTarget, "--source", name, "--destination", destination, "--domain-type", "systemCrashLogs", "--json-output", json, "--log-output", log], defaultTimeoutSeconds: timeout)
        _ = try diagnosticsProcess(command, maximumBytes: maximumBytes)
        for path in [destination, json, log] { hardenPrivateArtifact(path: path) }
        let receipt = try readBoundedDeviceFilesJSON(json, maximumBytes: maximumBytes)
        guard let root = try JSONSerialization.jsonObject(with: receipt) as? [String: Any], let info = root["info"] as? [String: Any],
              info["outcome"] as? String == "success", info["commandType"] as? String == "devicectl.device.copy.from",
              let arguments = info["arguments"] as? [String], root["error"] == nil || root["error"] is NSNull else { throw DeviceDiagnosticsError.invalidReceipt }
        for (flag, value) in [("--device", selection.target.rawTarget), ("--source", name), ("--destination", destination), ("--domain-type", "systemCrashLogs")] {
            let indexes = arguments.indices.filter { arguments[$0] == flag }
            guard indexes.count == 1, let index = indexes.first, index + 1 < arguments.count, arguments[index + 1] == value else { throw DeviceDiagnosticsError.invalidReceipt }
        }
        guard !arguments.contains("--domain-identifier") else { throw DeviceDiagnosticsError.invalidReceipt }
        data = try readBoundedDeviceFilesJSON(destination, maximumBytes: maximumBytes)
        commands.append(hostSourceCommand(command)); artifacts += [json, log]
    } else if selection.platform == .ios {
        data = try readLocalDiagnosticReport(root: localCrashReportRoot(), name: name, maximumBytes: maximumBytes)
        guard simulatorCrashBodyMatchesTarget(data, udid: selection.target.rawTarget) else { throw DeviceDiagnosticsError.invalidReceipt }
    } else {
        let android = selection.platform == .android
        let arguments: [String]
        if android && name == "crash-buffer" { arguments = ["-s", selection.target.rawTarget, "logcat", "-b", "crash", "-d", "-v", "threadtime"] }
        else {
            // Remote shell receives a quoted validated component, never interpolated shell syntax.
            let root = android ? "/data/tombstones/" : "/data/log/faultlog/faultlogger/"
            arguments = [android ? "-s" : "-t", selection.target.rawTarget, "shell", "cat '" + root + name + "'"]
        }
        let command = TKHostCommand(executable: android ? adb : hdc, arguments: arguments, defaultTimeoutSeconds: timeout)
        let result = try diagnosticsProcess(command, maximumBytes: maximumBytes)
        data = result.stdoutData; partial = result.stdoutTruncated; commands.append(hostSourceCommand(command))
    }
    let artifact = try diagnosticsArtifact(data, workspace: workspace, name: "crash.txt"); artifacts.append(artifact)
    return .init(action: "device.crashes.get", target: selection.target, source: entry.source, sourceCommands: commands, artifacts: artifacts, bytes: data.count, maximumBytes: maximumBytes, partial: partial, limitations: ["Sensitive report body explicitly requested; retained artifacts are owner-only.", "Native copy size is accepted after collection, not a remote transport/peak disk hard bound. Android crash-buffer is a buffer snapshot, not a tombstone file."], entries: [entry], content: String(decoding: data, as: UTF8.self))
}
