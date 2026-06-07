import Foundation

public enum TKAndroidADBCommand {
    private static func command(
        _ arguments: [String],
        executable: String,
        riskLevel: TKHostRiskLevel = .readonly,
        requiredConfig: Set<TKHostRequiredConfig> = [.timeout],
        defaultTimeoutSeconds: Double = 30,
        capturesArtifacts: Bool = false,
        sensitiveOutput: Bool = false
    ) -> TKHostCommand {
        TKHostCommand(
            executable: executable,
            arguments: arguments,
            riskLevel: riskLevel,
            requiredConfig: requiredConfig,
            defaultTimeoutSeconds: defaultTimeoutSeconds,
            capturesArtifacts: capturesArtifacts,
            sensitiveOutput: sensitiveOutput
        )
    }

    public static func version(executable: String = "adb") -> TKHostCommand {
        command(["version"], executable: executable)
    }

    public static func listDevices(executable: String = "adb") -> TKHostCommand {
        command(["devices", "-l"], executable: executable)
    }

    public static func bootCompleted(serial: String, executable: String = "adb") -> TKHostCommand {
        command(["-s", serial, "shell", "getprop", "sys.boot_completed"], executable: executable, requiredConfig: [.target, .timeout])
    }

    public static func screenshot(serial: String, executable: String = "adb") -> TKHostCommand {
        command(["-s", serial, "exec-out", "screencap", "-p"], executable: executable, riskLevel: .evidence, requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord], capturesArtifacts: true, sensitiveOutput: true)
    }

    public static func installAPK(serial: String, apkPath: String, executable: String = "adb") -> TKHostCommand {
        command(["-s", serial, "install", "-r", apkPath], executable: executable, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord], defaultTimeoutSeconds: 120)
    }

    public static func uninstall(serial: String, packageName: String, executable: String = "adb") -> TKHostCommand {
        command(["-s", serial, "uninstall", packageName], executable: executable, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord], defaultTimeoutSeconds: 60)
    }

    public static func launch(serial: String, packageName: String, activity: String? = nil, executable: String = "adb") -> TKHostCommand {
        if let activity, !activity.isEmpty {
            return command(["-s", serial, "shell", "am", "start", "-n", "\(packageName)/\(activity)"], executable: executable, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
        }
        return command(["-s", serial, "shell", "monkey", "-p", packageName, "-c", "android.intent.category.LAUNCHER", "1"], executable: executable, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func readFile(serial: String, remotePath: String, executable: String = "adb") -> TKHostCommand {
        command(["-s", serial, "shell", "cat", remotePath], executable: executable, riskLevel: .readonly, requiredConfig: [.target, .timeout])
    }

    public static func forceStop(serial: String, packageName: String, executable: String = "adb") -> TKHostCommand {
        command(["-s", serial, "shell", "am", "force-stop", packageName], executable: executable, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func openURL(serial: String, url: String, packageName: String? = nil, executable: String = "adb") -> TKHostCommand {
        var arguments = ["-s", serial, "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", url]
        if let packageName, !packageName.isEmpty {
            arguments += ["-p", packageName]
        }
        return command(arguments, executable: executable, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func listPackages(serial: String, userOnly: Bool = false, executable: String = "adb") -> TKHostCommand {
        var arguments = ["-s", serial, "shell", "pm", "list", "packages"]
        if userOnly {
            arguments.append("-3")
        }
        return command(arguments, executable: executable)
    }

    public static func dumpsysPackage(serial: String, packageName: String, executable: String = "adb") -> TKHostCommand {
        command(["-s", serial, "shell", "dumpsys", "package", packageName], executable: executable, sensitiveOutput: true)
    }
}

public struct TKAndroidTarget: Codable, Equatable {
    public let id: String
    public let serial: String
    public let state: String
    public let isReady: Bool
    public let source: String
    public let product: String?
    public let model: String?
    public let device: String?
    public let transportID: String?

    public init(
        serial: String,
        state: String,
        source: String = "adb",
        product: String? = nil,
        model: String? = nil,
        device: String? = nil,
        transportID: String? = nil
    ) {
        self.id = "android:\(serial)"
        self.serial = serial
        self.state = state
        self.isReady = state.lowercased() == "device"
        self.source = source
        self.product = product
        self.model = model
        self.device = device
        self.transportID = transportID
    }
}

public enum TKAdbDeviceListParser {
    public static func parse(_ text: String) -> [TKAndroidTarget] {
        text.split(whereSeparator: \.isNewline)
            .compactMap { line -> TKAndroidTarget? in
                let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count >= 2 else { return nil }
                guard parts[0].lowercased() != "list" else { return nil }
                let metadata = Dictionary(uniqueKeysWithValues: parts.dropFirst(2).compactMap(parseMetadata))
                return TKAndroidTarget(
                    serial: parts[0],
                    state: parts[1],
                    product: metadata["product"],
                    model: metadata["model"],
                    device: metadata["device"],
                    transportID: metadata["transport_id"]
                )
            }
    }

    public static func defaultTarget(from targets: [TKAndroidTarget]) -> TKAndroidTarget? {
        let ready = targets.filter(\.isReady)
        return ready.count == 1 ? ready[0] : nil
    }

    private static func parseMetadata(_ value: String) -> (String, String)? {
        guard let separator = value.firstIndex(of: ":") else { return nil }
        let key = String(value[..<separator])
        let rawValue = String(value[value.index(after: separator)...])
        guard !key.isEmpty, !rawValue.isEmpty else { return nil }
        return (key, rawValue)
    }
}

public enum TKAndroidBootCompletedParser {
    public static func isReady(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }
}

public enum TKAndroidPackageListParser {
    public static func parse(_ stdout: String) -> [TKHostInstalledApp] {
        stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("package:") else { return nil }
                let packageName = String(trimmed.dropFirst("package:".count))
                return packageName.isEmpty ? nil : packageName
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { packageName in
                TKHostInstalledApp(bundleID: packageName, info: [
                    "CFBundleIdentifier": packageName,
                    "ApplicationType": "Android",
                ])
            }
    }
}

public enum TKAndroidPackageInfoParser {
    public static func parse(_ stdout: String, packageName: String) -> TKHostInstalledApp {
        var info: [String: Any] = [
            "CFBundleIdentifier": packageName,
            "ApplicationType": "Android",
        ]
        for rawLine in stdout.split(whereSeparator: \.isNewline).map(String.init) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("versionName=") {
                info["CFBundleVersion"] = String(line.dropFirst("versionName=".count))
            } else if line.hasPrefix("codePath=") {
                info["Path"] = String(line.dropFirst("codePath=".count))
            } else if line.hasPrefix("resourcePath=") {
                info["Bundle"] = String(line.dropFirst("resourcePath=".count))
            } else if line.hasPrefix("dataDir=") {
                info["DataContainer"] = String(line.dropFirst("dataDir=".count))
            }
        }
        return TKHostInstalledApp(bundleID: packageName, info: info)
    }
}

public struct TKAndroidADBFakeResult: Equatable {
    public let fixtureName: String
    public let stdout: Data
    public let stderr: Data
    public let exitCode: Int32

    public var stdoutString: String {
        String(data: stdout, encoding: .utf8) ?? ""
    }

    public var stderrString: String {
        String(data: stderr, encoding: .utf8) ?? ""
    }
}

public enum TKAndroidADBFakeFixture: Equatable {
    case version
    case devicesEmpty
    case devicesSingleReady
    case devicesMultipleReady
    case devicesMixedStates
    case bootCompletedFalse(serial: String)
    case bootCompletedTrue(serial: String)
    case bootCompletedError(serial: String)
    case screenshotPNG(serial: String)
    case screenshotFailure(serial: String)
    case installSuccess(serial: String, apkPath: String)
    case resolveActivitySuccess(serial: String, packageName: String, component: String)
    case amStartSuccess(serial: String, component: String)
    case uiautomatorDump(serial: String, remotePath: String)
    case readFileXML(serial: String, remotePath: String)

    var name: String {
        switch self {
        case .version: return "adb-version"
        case .devicesEmpty: return "android-adb-devices-empty"
        case .devicesSingleReady: return "android-adb-devices-single-ready"
        case .devicesMultipleReady: return "android-adb-devices-multiple-ready"
        case .devicesMixedStates: return "android-adb-devices-mixed-states"
        case .bootCompletedFalse: return "android-boot-completed-false"
        case .bootCompletedTrue: return "android-boot-completed-true"
        case .bootCompletedError: return "android-boot-completed-error"
        case .screenshotPNG: return "android-screencap-success"
        case .screenshotFailure: return "android-screencap-failure"
        case .installSuccess: return "android-install-success"
        case .resolveActivitySuccess: return "android-resolve-activity-success"
        case .amStartSuccess: return "android-am-start-success"
        case .uiautomatorDump: return "android-uiautomator-layout-basic"
        case .readFileXML: return "android-read-file-xml"
        }
    }

    var argv: [String] {
        switch self {
        case .version:
            return ["version"]
        case .devicesEmpty, .devicesSingleReady, .devicesMultipleReady, .devicesMixedStates:
            return ["devices", "-l"]
        case .bootCompletedFalse(let serial), .bootCompletedTrue(let serial), .bootCompletedError(let serial):
            return ["-s", serial, "shell", "getprop", "sys.boot_completed"]
        case .screenshotPNG(let serial), .screenshotFailure(let serial):
            return ["-s", serial, "exec-out", "screencap", "-p"]
        case .installSuccess(let serial, let apkPath):
            return ["-s", serial, "install", "-r", apkPath]
        case .resolveActivitySuccess(let serial, let packageName, _):
            return ["-s", serial, "shell", "cmd", "package", "resolve-activity", "--brief", packageName]
        case .amStartSuccess(let serial, let component):
            return ["-s", serial, "shell", "am", "start", "-n", component]
        case .uiautomatorDump(let serial, let remotePath):
            return ["-s", serial, "shell", "uiautomator", "dump", remotePath]
        case .readFileXML(let serial, let remotePath):
            return ["-s", serial, "shell", "cat", remotePath]
        }
    }

    var result: TKAndroidADBFakeResult {
        switch self {
        case .version:
            return makeResult("""
            Android Debug Bridge version 1.0.41
            Version 35.0.2-12147458
            Installed as /opt/android-sdk/platform-tools/adb
            """)
        case .devicesEmpty:
            return makeResult("List of devices attached\n")
        case .devicesSingleReady:
            return makeResult("""
            List of devices attached
            emulator-5554          device product:sdk_gphone64_arm64 model:Pixel_8 device:emu64a transport_id:1
            """)
        case .devicesMultipleReady:
            return makeResult("""
            List of devices attached
            emulator-5554          device product:sdk_gphone64_arm64 model:Pixel_8 device:emu64a transport_id:1
            emulator-5556          device product:sdk_gphone64_x86_64 model:Pixel_7 device:emu64x transport_id:2
            """)
        case .devicesMixedStates:
            return makeResult("""
            List of devices attached
            emulator-5554          device product:sdk_gphone64_arm64 model:Pixel_8 device:emu64a transport_id:1
            emulator-5556          offline transport_id:2
            emulator-5558          unauthorized transport_id:3
            """)
        case .bootCompletedFalse:
            return makeResult("0\n")
        case .bootCompletedTrue:
            return makeResult("1\n")
        case .bootCompletedError:
            return makeResult("", stderr: "device offline\n", exitCode: 1)
        case .screenshotPNG:
            return TKAndroidADBFakeResult(
                fixtureName: name,
                stdout: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
                stderr: Data(),
                exitCode: 0
            )
        case .screenshotFailure:
            return makeResult("", stderr: "screencap failed\n", exitCode: 1)
        case .installSuccess:
            return makeResult("Success\n")
        case .resolveActivitySuccess(_, _, let component):
            return makeResult("""
            priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=true
            \(component)
            """)
        case .amStartSuccess(_, let component):
            return makeResult("""
            Starting: Intent { cmp=\(component) }
            Status: ok
            """)
        case .uiautomatorDump(_, let remotePath):
            return makeResult("UI hierchary dumped to: \(remotePath)\n")
        case .readFileXML(_, let remotePath):
            return makeResult("""
            <?xml version="1.0" encoding="UTF-8"?>
            <hierarchy rotation="0" dumpPath="\(remotePath)">
              <node index="0" text="" resource-id="android:id/content" class="android.widget.FrameLayout" package="com.example.demo" content-desc="" clickable="false" enabled="true" bounds="[0,0][240,320]" />
              <node index="1" text="Login" resource-id="com.example.demo:id/login" class="android.widget.Button" package="com.example.demo" content-desc="Login button" clickable="true" enabled="true" bounds="[24,120][216,192]" />
            </hierarchy>
            """)
        }
    }

    private func makeResult(_ stdout: String, stderr: String = "", exitCode: Int32 = 0) -> TKAndroidADBFakeResult {
        TKAndroidADBFakeResult(
            fixtureName: name,
            stdout: Data(stdout.utf8),
            stderr: Data(stderr.utf8),
            exitCode: exitCode
        )
    }
}

public struct TKAndroidADBFakeRunner {
    private let fixtures: [TKAndroidADBFakeFixture]

    public init(fixtures: [TKAndroidADBFakeFixture]) {
        self.fixtures = fixtures
    }

    public func run(_ command: TKHostCommand) throws -> TKAndroidADBFakeResult {
        guard let fixture = fixtures.first(where: { $0.argv == command.argv }) else {
            throw TKAndroidADBFakeRunnerError.fixtureNotFound(command.argv)
        }
        return fixture.result
    }
}

public enum TKAndroidADBFakeRunnerError: Error, Equatable {
    case fixtureNotFound([String])
}

public struct TKAndroidADBVersion: Equatable {
    public let androidDebugBridgeVersion: String
    public let version: String
    public let installedAs: String
}

public enum TKAndroidADBVersionParser {
    public static func parse(_ stdout: String) throws -> TKAndroidADBVersion {
        var bridgeVersion: String?
        var version: String?
        var installedAs: String?

        for line in stdout.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("Android Debug Bridge version ") {
                bridgeVersion = String(line.dropFirst("Android Debug Bridge version ".count))
            } else if line.hasPrefix("Version ") {
                version = String(line.dropFirst("Version ".count))
            } else if line.hasPrefix("Installed as ") {
                installedAs = String(line.dropFirst("Installed as ".count))
            }
        }

        guard let bridgeVersion, let version, let installedAs else {
            throw TKAndroidADBParserError.invalidVersion(stdout)
        }
        return TKAndroidADBVersion(
            androidDebugBridgeVersion: bridgeVersion,
            version: version,
            installedAs: installedAs
        )
    }
}

public enum TKAndroidBootCompletedStatus: Equatable {
    case ready
    case notReady
    case failed(String)
}

public extension TKAndroidBootCompletedParser {
    static func parse(_ stdout: String, stderr: String, exitCode: Int32) -> TKAndroidBootCompletedStatus {
        guard exitCode == 0 else {
            return .failed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return isReady(stdout) ? .ready : .notReady
    }
}

public struct TKAndroidCommandStatus: Equatable {
    public let ok: Bool
    public let error: String?
    public let component: String?
}

public enum TKAndroidScreenshotParser {
    public static func parse(stdout: Data, stderr: String, exitCode: Int32) -> TKAndroidCommandStatus {
        let ok = exitCode == 0 && stdout.starts(with: Data([0x89, 0x50, 0x4E, 0x47]))
        return TKAndroidCommandStatus(
            ok: ok,
            error: ok ? nil : trimmedError(stderr),
            component: nil
        )
    }
}

public enum TKAndroidInstallParser {
    public static func parse(_ stdout: String, stderr: String, exitCode: Int32) -> TKAndroidCommandStatus {
        let ok = exitCode == 0 && stdout.split(whereSeparator: \.isNewline).contains("Success")
        return TKAndroidCommandStatus(
            ok: ok,
            error: ok ? nil : trimmedError(stderr.isEmpty ? stdout : stderr),
            component: nil
        )
    }
}

public enum TKAndroidActivityStartParser {
    public static func parse(_ stdout: String, stderr: String, exitCode: Int32) -> TKAndroidCommandStatus {
        let component = extractActivityComponent(from: stdout)
        let ok = exitCode == 0 && component != nil
        return TKAndroidCommandStatus(
            ok: ok,
            error: ok ? nil : trimmedError(stderr.isEmpty ? stdout : stderr),
            component: component
        )
    }

    private static func extractActivityComponent(from stdout: String) -> String? {
        guard let range = stdout.range(of: "cmp=") else { return nil }
        let suffix = stdout[range.upperBound...]
        let component = suffix.prefix { !$0.isWhitespace && $0 != "}" }
        return component.isEmpty ? nil : String(component)
    }
}

public enum TKAndroidResolveActivityParser {
    public static func parse(_ stdout: String, stderr: String, exitCode: Int32) -> TKAndroidCommandStatus {
        let component = extractResolvedComponent(from: stdout)
        let ok = exitCode == 0 && component != nil
        return TKAndroidCommandStatus(
            ok: ok,
            error: ok ? nil : trimmedError(stderr.isEmpty ? stdout : stderr),
            component: component
        )
    }

    private static func extractResolvedComponent(from stdout: String) -> String? {
        let lines = stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.last { $0.contains("/") }
    }
}

public extension TKAndroidADBCommand {
    static func resolveActivity(serial: String, packageName: String, executable: String = "adb") -> TKHostCommand {
        TKHostCommand(
            executable: executable,
            arguments: ["-s", serial, "shell", "cmd", "package", "resolve-activity", "--brief", packageName],
            riskLevel: .readonly,
            requiredConfig: [.target, .timeout]
        )
    }

    static func launch(serial: String, component: String, executable: String = "adb") -> TKHostCommand {
        TKHostCommand(
            executable: executable,
            arguments: ["-s", serial, "shell", "am", "start", "-n", component],
            riskLevel: .automation,
            requiredConfig: [.target, .timeout, .auditRecord]
        )
    }

    static func uiautomatorDump(serial: String, remotePath: String, executable: String = "adb") -> TKHostCommand {
        TKHostCommand(
            executable: executable,
            arguments: ["-s", serial, "shell", "uiautomator", "dump", remotePath],
            riskLevel: .readonly,
            requiredConfig: [.target, .timeout]
        )
    }

    static func tapCoordinate(serial: String, x: Int, y: Int, executable: String = "adb") -> TKHostCommand {
        TKHostCommand(
            executable: executable,
            arguments: ["-s", serial, "shell", "input", "tap", String(x), String(y)],
            riskLevel: .automation,
            requiredConfig: [.target, .timeout, .auditRecord]
        )
    }

    static func swipeCoordinate(
        serial: String,
        startX: Int,
        startY: Int,
        endX: Int,
        endY: Int,
        durationMs: Int? = nil,
        executable: String = "adb"
    ) -> TKHostCommand {
        var arguments = [
            "-s", serial, "shell", "input", "swipe",
            String(startX), String(startY), String(endX), String(endY),
        ]
        if let durationMs {
            arguments.append(String(durationMs))
        }
        return TKHostCommand(
            executable: executable,
            arguments: arguments,
            riskLevel: .automation,
            requiredConfig: [.target, .timeout, .auditRecord]
        )
    }

    static func inputText(serial: String, text: String, executable: String = "adb") -> TKHostCommand {
        TKHostCommand(
            executable: executable,
            arguments: ["-s", serial, "shell", "input", "text", text],
            riskLevel: .automation,
            requiredConfig: [.target, .timeout, .auditRecord]
        )
    }

    static func keyEvent(serial: String, keyCode: String, executable: String = "adb") -> TKHostCommand {
        TKHostCommand(
            executable: executable,
            arguments: ["-s", serial, "shell", "input", "keyevent", keyCode],
            riskLevel: .automation,
            requiredConfig: [.target, .timeout, .auditRecord]
        )
    }
}

public enum TKAndroidUIAutomatorDumpParser {
    public static func remotePath(from stdout: String) throws -> String {
        if let path = extractAttribute("dumpPath", from: stdout) {
            return path
        }
        if let range = stdout.range(of: "dumped to:") {
            let rawPath = stdout[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawPath.isEmpty {
                return rawPath
            }
        }
        throw TKAndroidADBParserError.remotePathNotFound
    }
}

public struct TKAndroidUIAutomatorNodeSummary: Equatable {
    public let text: String?
    public let resourceID: String?
    public let contentDescription: String?
    public let className: String?
    public let clickable: Bool
    public let enabled: Bool
    public let bounds: TKRect?
}

public enum TKAndroidUIAutomatorXMLParser {
    public static func nodeSummaries(in data: Data) throws -> [TKAndroidUIAutomatorNodeSummary] {
        let delegate = AndroidUIAutomatorXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? TKAndroidADBParserError.invalidUIAutomatorXML
        }
        return delegate.nodes
    }
}

private final class AndroidUIAutomatorXMLDelegate: NSObject, XMLParserDelegate {
    var nodes: [TKAndroidUIAutomatorNodeSummary] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "node" else { return }
        nodes.append(TKAndroidUIAutomatorNodeSummary(
            text: emptyToNil(attributeDict["text"]),
            resourceID: emptyToNil(attributeDict["resource-id"]),
            contentDescription: emptyToNil(attributeDict["content-desc"]),
            className: emptyToNil(attributeDict["class"]),
            clickable: attributeDict["clickable"] == "true",
            enabled: attributeDict["enabled"] != "false",
            bounds: parseAndroidBounds(attributeDict["bounds"])
        ))
    }
}

public enum TKAndroidADBParserError: Error, Equatable {
    case invalidVersion(String)
    case remotePathNotFound
    case invalidUIAutomatorXML
}

private func trimmedError(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "android command failed" : trimmed
}

private func emptyToNil(_ text: String?) -> String? {
    guard let text, !text.isEmpty else { return nil }
    return text
}

private func extractAttribute(_ name: String, from text: String) -> String? {
    guard let range = text.range(of: "\(name)=\"") else { return nil }
    let suffix = text[range.upperBound...]
    guard let end = suffix.firstIndex(of: "\"") else { return nil }
    let value = String(suffix[..<end])
    return value.isEmpty ? nil : value
}

private func parseAndroidBounds(_ text: String?) -> TKRect? {
    guard let text else { return nil }
    let parts = text
        .split { character in
            character == "[" || character == "]" || character == ","
        }
        .compactMap { Double($0) }
    guard parts.count == 4 else { return nil }
    return TKRect(x: parts[0], y: parts[1], width: parts[2] - parts[0], height: parts[3] - parts[1])
}
