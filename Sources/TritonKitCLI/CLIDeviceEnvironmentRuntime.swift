import Foundation
import Darwin
import TritonKitShared

func isValidEnvironmentCoordinate(_ value: String) -> Bool {
    let parts = value.split(separator: ",", omittingEmptySubsequences: false)
    guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]), lat.isFinite, lon.isFinite else { return false }
    return (-90...90).contains(lat) && (-180...180).contains(lon)
}

func environmentADB(target: HostDeviceTarget, adb: String, shell: [String], mutation: Bool = false, sensitive: Bool = false, stdin: Data? = nil) -> TKHostCommand {
    // adb shell concatenates argv remotely. Pass one independently escaped script.
    TKHostCommand(executable: adb, arguments: ["-s", target.target, "shell", shell.map(shellEscaped).joined(separator: " ")], riskLevel: mutation ? .automation : .readonly, sensitiveOutput: sensitive, stdinData: stdin)
}
func environmentGeoFix(target: HostDeviceTarget, latitude: Double, longitude: Double, adb: String) -> TKHostCommand {
    TKHostCommand(executable: adb, arguments: ["-s", target.target, "emu", "geo", "fix", String(longitude), String(latitude)], riskLevel: .automation)
}
func environmentClipboardCommand(target: HostDeviceTarget, adb: String, operation: String, text: String? = nil, remote: String = "/data/local/tmp/triton-clipboard.dex") -> TKHostCommand {
    environmentADB(target: target, adb: adb, shell: ["env", "CLASSPATH=\(remote)", "app_process", "/system/bin", "ClipboardBridge", operation], mutation: operation == "set", sensitive: true, stdin: text.map { Data($0.utf8) })
}
func environmentMatch(_ text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[range])
}
func parseAndroidDisplayRotation(_ text: String) -> Int? {
    if let degrees = environmentMatch(text, pattern: #"mRotation=ROTATION_(0|90|180|270)\b"#).flatMap(Int.init) { return degrees / 90 }
    return environmentMatch(text, pattern: #"(?:SurfaceOrientation:\s*|mRotation=)([0-3])\b"#).flatMap(Int.init)
}
struct AndroidForegroundIdentity {
    let bundleIdentifier: String
    /// Component exactly as reported by ActivityRecord (including shorthand).
    let component: String
    /// Activity class as reported, expanding only Android’s explicit leading-dot shorthand.
    let activity: String
}
func parseAndroidForegroundIdentity(_ text: String) -> AndroidForegroundIdentity? {
    let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
    // A present but malformed top record must never fall back to an older resumed record.
    let top = lines.filter { $0.range(of: #"^topResumedActivity\s*[:=]"#, options: .regularExpression) != nil }
    let records = top.isEmpty ? lines.filter { $0.range(of: #"^mResumedActivity\s*[:=]"#, options: .regularExpression) != nil } : top
    guard !records.isEmpty else { return nil }
    var components = Set<String>()
    for record in records {
        guard let component = environmentMatch(record, pattern: #"^(?:topResumedActivity|mResumedActivity)\s*[:=]\s*ActivityRecord\{[^\s{}]+\s+u[0-9]+\s+([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*/(?:\.?[A-Za-z_$][A-Za-z0-9_$]*(?:\.[A-Za-z_$][A-Za-z0-9_$]*)*))(?:\s+[^{}]*)?\}\s*$"#) else { return nil }
        components.insert(component)
    }
    guard components.count == 1, let component = components.first else { return nil }
    let parts = component.split(separator: "/", maxSplits: 1).map(String.init)
    let activity = parts[1].hasPrefix(".") ? parts[0] + parts[1] : parts[1]
    return AndroidForegroundIdentity(bundleIdentifier: parts[0], component: component, activity: activity)
}
func parseAndroidForeground(_ text: String) -> String? {
    parseAndroidForegroundIdentity(text)?.bundleIdentifier
}
private func environmentClipboardText(_ text: String) throws -> String {
    guard let line = text.components(separatedBy: .newlines).first(where: { $0.hasPrefix("TRITON_CLIPBOARD:") }), let data = Data(base64Encoded: String(line.dropFirst("TRITON_CLIPBOARD:".count))), data.count <= 65536, let value = String(data: data, encoding: .utf8) else { throw DeviceEnvironmentFailure(code: "clipboard_invalid_response", message: "Clipboard helper returned no bounded text observation") }
    return value
}
func environmentResourceDex() throws -> URL {
    let candidates = [Bundle.module.resourceURL?.appendingPathComponent("android-environment/clipboard.dex"), Bundle.main.resourceURL?.appendingPathComponent("android-environment/clipboard.dex"), URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("resources/android-environment/clipboard.dex")]
    guard let path = candidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { throw DeviceEnvironmentFailure(code: "clipboard_resource_missing", message: "Install a complete Triton release including the Android clipboard helper") }
    return path
}

func makeDeviceEnvironmentOutput(target: HostDeviceTarget, operation: DeviceEnvironmentOperation, value: String? = nil, angle: Double? = nil, adb: String = "adb", hdc: String = "hdc", runner: HostDeviceCommandRunner = { try runHostCommand($0) }, clipboardResource: () throws -> URL = environmentResourceDex) throws -> DeviceEnvironmentOutput {
    var output = DeviceEnvironmentOutput(action: "device.\(operation.rawValue)", target: target, source: target.platform == "android" ? "adb" : target.platform == "harmony" ? "hdc" : "simctl")
    func run(_ command: TKHostCommand) throws -> String {
        output.sourceCommands.append(hostSourceCommand(command))
        let result = try runner(command)
        guard result.exitCode == 0, !result.stdoutTruncated, !result.stderrTruncated else { throw DeviceEnvironmentFailure(code: "device_environment_backend_failed", message: "Environment adapter failed or returned truncated output") }
        guard !result.stdout.components(separatedBy: .newlines).contains(where: { $0.hasPrefix("KO:") }) else { throw DeviceEnvironmentFailure(code: "unsupported_device_environment", message: "Emulator rejected this environment operation") }
        return result.stdout
    }
    func android(_ arguments: [String], mutation: Bool = false, sensitive: Bool = false) throws -> String {
        try run(environmentADB(target: target, adb: adb, shell: arguments, mutation: mutation, sensitive: sensitive))
    }
    func unsupported(_ note: String) -> DeviceEnvironmentOutput {
        output.ok = false; output.supported = false
        output.error = DeviceEnvironmentFailure(code: "unsupported_device_environment", message: note)
        return output
    }
    do {
        switch operation {
        case .orientationGet, .orientationSet:
            guard target.platform == "android" else { return unsupported("Use the bound iOS Runner environment route for Apple orientation") }
            let originalRotation = parseAndroidDisplayRotation(try android(["dumpsys", "window", "displays"]))
            let acceleration = try android(["settings", "get", "system", "accelerometer_rotation"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let originalPreference = try android(["settings", "get", "system", "user_rotation"]).trimmingCharacters(in: .whitespacesAndNewlines)
            output.previous = ["orientation": originalRotation.flatMap(DeviceOrientationValue.from)?.rawValue ?? "unknown", "accelerometerRotation": acceleration, "userRotation": originalPreference]
            if operation == .orientationSet {
                guard let value, let orientation = DeviceOrientationValue(rawValue: value) else { throw DeviceEnvironmentFailure(code: "invalid_device_orientation", message: "Orientation must be a documented orientation value") }
                output.requested = ["orientation": value, "userRotation": String(orientation.rotation), "accelerometerRotation": "0"]
                _ = try android(["settings", "put", "system", "accelerometer_rotation", "0"], mutation: true)
                output.executed = true
                _ = try android(["settings", "put", "system", "user_rotation", String(orientation.rotation)], mutation: true)
                // Android 15+ keeps the effective display rotation in WindowManager;
                // lock it explicitly so a launcher or sensor policy cannot leave the
                // requested setting unapplied.
                _ = try android(["cmd", "window", "user-rotation", "lock", String(orientation.rotation)], mutation: true)
            }
            let observedRotation = parseAndroidDisplayRotation(try android(["dumpsys", "window", "displays"]))
            output.observed = ["orientation": observedRotation.flatMap(DeviceOrientationValue.from)?.rawValue ?? "unknown"]
            output.verified = observedRotation != nil && (operation == .orientationGet || output.observed?["orientation"] == value)
            output.note = "A locked App may keep a different display orientation. previous includes settings required to restore auto-rotation."
            if !output.verified { output.ok = false; output.error = DeviceEnvironmentFailure(code: "device_environment_not_verified", message: "Display rotation did not confirm the requested orientation") }
        case .fold:
            guard target.platform == "android", target.scope == "emulator", target.target.hasPrefix("emulator-") else {
                if target.platform == "ios" && target.scope == "simulator" { return unsupported("iOS Duo posture requires version-gated SimulatorKit host control; public simctl has no fold/hinge operation") }
                return unsupported("Fold control requires a compatible local Android foldable Emulator")
            }
            guard let value, let posture = DeviceFoldValue(rawValue: value), angle == nil || (angle!.isFinite && (0...180).contains(angle!)) else { throw DeviceEnvironmentFailure(code: "invalid_device_fold", message: "Use folded|half-open|open and angle 0...180") }
            let hinge = angle ?? (posture == .folded ? 0 : posture == .halfOpen ? 90 : 180)
            func console(_ args: [String], mutation: Bool = false) throws -> String { try run(TKHostCommand(executable: adb, arguments: ["-s", target.target, "emu"] + args, riskLevel: mutation ? .automation : .readonly)) }
            let previous = try console(["physics", "get", "hinge-angle0"])
            output.previous = ["hingeAngle": previous.trimmingCharacters(in: .whitespacesAndNewlines)]
            output.requested = ["posture": value, "hingeAngle": String(hinge)]
            _ = try console([posture == .folded ? "fold" : "unfold"], mutation: true); output.executed = true
            _ = try console(["physics", "set", "hinge-angle0", String(hinge)], mutation: true)
            let observed = try console(["physics", "get", "hinge-angle0"])
            output.observed = ["hingeAngle": observed.trimmingCharacters(in: .whitespacesAndNewlines)]
            let number = environmentMatch(observed, pattern: #"(?:=|:)\s*([-+]?[0-9]+(?:\.[0-9]+)?)"#).flatMap(Double.init)
            output.verified = number.map { abs($0 - hinge) < 0.5 } ?? false
            if !output.verified { output.ok = false; output.error = DeviceEnvironmentFailure(code: "device_environment_not_verified", message: "Emulator did not confirm the hinge angle") }
        case .clipboardGet, .clipboardSet:
            if target.platform == "ios", target.scope == "simulator" {
                let before = try run(TKSimctlCommand.pasteboardPaste(udid: target.target))
                output.previous = ["text": before]
                if operation == .clipboardSet { guard let value, value.utf8.count <= 65536 else { throw DeviceEnvironmentFailure(code: "invalid_clipboard_text", message: "Text must be at most 64KiB") }; _ = try run(TKSimctlCommand.pasteboardCopy(udid: target.target, text: value)); output.executed = true }
                let after = operation == .clipboardSet ? try run(TKSimctlCommand.pasteboardPaste(udid: target.target)) : before
                output.observed = ["text": after]; output.verified = operation == .clipboardGet || after == value
            } else if target.platform == "android" {
                let resource = try clipboardResource()
                let remote = "/data/local/tmp/triton-clipboard-\(UUID().uuidString).dex"
                _ = try run(TKHostCommand(executable: adb, arguments: ["-s", target.target, "push", resource.path, remote], riskLevel: .automation))
                defer { _ = try? runner(environmentADB(target: target, adb: adb, shell: ["rm", "-f", remote], mutation: true)) }
                let before = try environmentClipboardText(run(environmentClipboardCommand(target: target, adb: adb, operation: "get", remote: remote)))
                output.previous = ["text": before]
                var after = before
                if operation == .clipboardSet { guard let value, value.utf8.count <= 65536 else { throw DeviceEnvironmentFailure(code: "invalid_clipboard_text", message: "Text must be at most 64KiB") }; after = try environmentClipboardText(run(environmentClipboardCommand(target: target, adb: adb, operation: "set", text: value, remote: remote))); output.executed = true }
                output.observed = ["text": after]; output.verified = operation == .clipboardGet || after == value
            } else { return unsupported("System clipboard uses iOS Simulator simctl or Android shell helper; other platforms expose no supported host clipboard adapter") }
            output.note = "Clipboard text is sensitive. Staging is not typing, pasting, or App acceptance."
            if !output.verified { output.ok = false; output.error = DeviceEnvironmentFailure(code: "device_environment_not_verified", message: "Clipboard readback differs from requested text") }
        case .foreground:
            if target.platform == "android" {
                let text = try android(["dumpsys", "activity", "activities"])
                let identity = parseAndroidForegroundIdentity(text)
                output.observed = ["bundleIdentifier": identity?.bundleIdentifier ?? "unknown", "identityState": identity == nil ? "unknown" : "current", "scope": "resumed-activity"]
                if let identity {
                    output.observed?["component"] = identity.component
                    output.observed?["activity"] = identity.activity
                }
                output.verified = identity != nil
            } else if target.platform == "harmony" {
                let identity = TKHarmonyForegroundAppParser.parse(try run(TKHarmonyHDCCommand.foregroundApp(target: target.target, executable: hdc)))
                output.observed = ["bundleIdentifier": identity.bundleIdentifier ?? "unknown", "identityState": identity.identityState, "scope": "foreground-ability"]
                output.verified = identity.current
            } else { return unsupported("Use the bound iOS Runner environment route; its foreground observation is session-allowlist scoped") }
        case .locationSet, .locationClear:
            if target.platform == "ios", target.scope == "simulator" {
                output.previous = ["location": "unknown", "reason": "simctl has no location get primitive"]
                if operation == .locationSet { guard let value, isValidEnvironmentCoordinate(value) else { throw DeviceEnvironmentFailure(code: "invalid_location_value", message: "Coordinate must be latitude,longitude") }; output.requested = ["coordinate": value]; _ = try run(TKSimctlCommand.locationSet(udid: target.target, coordinate: value)) }
                else { _ = try run(TKSimctlCommand.locationClear(udid: target.target)) }
                output.executed = true
                output.observed = ["state": "host-command-acknowledged", "readback": "unavailable"]
                output.note = "Host acknowledged location configuration; verify GPS in the target App. simctl exposes no direct coordinate readback."
            } else if target.platform == "android" {
                let receipt = try environmentAndroidLocation(target: target, operation: operation, coordinate: value, adb: adb, runner: { try run($0) })
                output.previous = receipt.previous; output.requested = receipt.requested; output.observed = receipt.observed; output.executed = true; output.verified = receipt.verified
                output.note = "Uses a shell-owned GPS test provider, restores prior mock-location AppOp on clear; verify App consumption separately."
            } else { return unsupported("Host GPS configuration requires iOS Simulator or Android shell mock-location permission") }
        }
    } catch let failure as DeviceEnvironmentFailure {
        output.ok = false; output.error = failure
        if failure.code == "unsupported_device_environment" { output.supported = false }
    } catch {
        output.ok = false; output.error = DeviceEnvironmentFailure(code: "device_environment_backend_failed", message: "Environment adapter failed; inspect device readiness and permission")
    }
    return output
}

private struct EnvironmentLocationReceipt: Codable { let appOp: String; let coordinate: String }
private struct EnvironmentLocationResult { let previous: [String: String]; let requested: [String: String]; let observed: [String: String]; let verified: Bool }
private func environmentAndroidLocation(target: HostDeviceTarget, operation: DeviceEnvironmentOperation, coordinate: String?, adb: String, runner: (TKHostCommand) throws -> String) throws -> EnvironmentLocationResult {
    // Local receipt binds ownership to a canonical device ID. Never remove a mock
    // provider made by another tool; lock spans setup/clear and receipt publication.
    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".triton/environment-location", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let key = Data(target.id.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
    let lock = open(root.appendingPathComponent(key + ".lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
    guard lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else { if lock >= 0 { close(lock) }; throw DeviceEnvironmentFailure(code: "device_environment_busy", message: "Another location operation owns this target") }
    defer { flock(lock, LOCK_UN); close(lock) }
    let path = root.appendingPathComponent(key + ".json")
    let original = try? JSONDecoder().decode(EnvironmentLocationReceipt.self, from: Data(contentsOf: path))
    func command(_ args: [String], mutation: Bool = false) throws { _ = try runner(environmentADB(target: target, adb: adb, shell: args, mutation: mutation)) }
    // Reads use a direct bounded process result through the outer runner closure.
    // Returned observation is deliberately configuration acknowledgement: no last
    // cached location or arbitrary dumpsys text is relabelled as a live GPS fix.
    if operation == .locationClear {
        guard let original else { throw DeviceEnvironmentFailure(code: "location_ownership_missing", message: "No Triton GPS override exists for this target; refusing to clear another tool's provider") }
        try command(["cmd", "location", "providers", "remove-test-provider", "gps"], mutation: true)
        try command(["cmd", "appops", "set", "com.android.shell", "android:mock_location", original.appOp], mutation: true)
        try FileManager.default.removeItem(at: path)
        return EnvironmentLocationResult(previous: ["coordinate": original.coordinate, "mockLocationAppOp": original.appOp], requested: ["state": "clear"], observed: ["state": "host-command-acknowledged", "readback": "unavailable"], verified: false)
    }
    guard let coordinate, isValidEnvironmentCoordinate(coordinate) else { throw DeviceEnvironmentFailure(code: "invalid_location_value", message: "Coordinate must be latitude,longitude") }
    // Permission is changed only with a preserved observation, never blindly.
    // An existing receipt is owned and can be updated without provider replacement.
    var appOp = original?.appOp ?? "default"
    if original == nil {
        let observation = try runner(environmentADB(target: target, adb: adb, shell: ["cmd", "appops", "get", "com.android.shell", "android:mock_location"]))
        if !observation.contains("No operations") {
            guard let mode = environmentMatch(observation, pattern: #"(?:MOCK_LOCATION|mock_location):\s*(allow|ignore|deny|default|foreground)\b"#) else { throw DeviceEnvironmentFailure(code: "location_permission_observation_required", message: "Cannot preserve original mock-location permission") }
            appOp = mode
        }
        let providers = try runner(environmentADB(target: target, adb: adb, shell: ["dumpsys", "location"]))
        guard !providers.contains("MockProvider"), !providers.contains("mock=true") else { throw DeviceEnvironmentFailure(code: "location_ownership_conflict", message: "An existing mock location provider belongs to another tool") }
        try command(["cmd", "appops", "set", "com.android.shell", "android:mock_location", "allow"], mutation: true)
        // Publish ownership before the first provider write so a partial failure
        // can be cleared rather than orphaning a modified permission/provider.
        try JSONEncoder().encode(EnvironmentLocationReceipt(appOp: appOp, coordinate: coordinate)).write(to: path, options: [.atomic])
        try command(["cmd", "location", "providers", "add-test-provider", "gps", "--requiresSatellite", "--supportsAltitude", "--supportsSpeed", "--supportsBearing", "--powerRequirement", "3"], mutation: true)
        try command(["cmd", "location", "providers", "set-test-provider-enabled", "gps", "true"], mutation: true)
    }
    try command(["cmd", "location", "providers", "set-test-provider-location", "gps", "--location", coordinate], mutation: true)
    let next = EnvironmentLocationReceipt(appOp: appOp, coordinate: coordinate)
    try JSONEncoder().encode(next).write(to: path, options: [.atomic])
    return EnvironmentLocationResult(previous: ["coordinate": original?.coordinate ?? "unknown", "mockLocationAppOp": appOp], requested: ["coordinate": coordinate], observed: ["state": "host-command-acknowledged", "readback": "unavailable"], verified: false)
}
