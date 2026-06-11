import Foundation

public enum TKHarmonyHDCCommand {
    public static func version(executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-v"])
    }

    public static func listTargets(executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["list", "targets", "-v"])
    }

    public static func listTargetsPlain(executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["list", "targets"])
    }

    public static func bootCompleted(target: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "param", "get", "bootevent.boot.completed"], riskLevel: .readonly, requiredConfig: [.target, .timeout])
    }

    public static func shellProbe(target: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "echo", "triton-shell-ready"], riskLevel: .readonly, requiredConfig: [.target, .timeout])
    }

    public static func paramListRecursive(target: String, name: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "param", "ls", "-r", name], riskLevel: .readonly, requiredConfig: [.target, .timeout])
    }

    public static func appInspect(target: String, bundleName: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "bm", "dump", "-n", bundleName], riskLevel: .readonly, requiredConfig: [.target, .timeout])
    }

    public static func appLaunch(target: String, bundleName: String, abilityName: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "aa", "start", "-b", bundleName, "-a", abilityName], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func installHap(target: String, hapPath: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "install", "-r", hapPath], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func forceStop(target: String, bundleName: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "aa", "force-stop", bundleName], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func appOpenURL(target: String, bundleName: String, abilityName: String, url: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "aa", "start", "-a", abilityName, "-b", bundleName, "-U", url], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func forwardPort(target: String, localPort: Int, remotePort: Int, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "fport", "tcp:\(localPort)", "tcp:\(remotePort)"], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func inputText(target: String, text: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "uitest", "uiInput", "text", text], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func inputTextAt(target: String, x: Int, y: Int, text: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "uitest", "uiInput", "inputText", "\(x)", "\(y)", text], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func dumpLayout(target: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "uitest", "dumpLayout"], riskLevel: .evidence, requiredConfig: [.target, .timeout, .auditRecord], capturesArtifacts: true, sensitiveOutput: true)
    }

    public static func recvFile(target: String, remotePath: String, localPath: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "file", "recv", remotePath, localPath], riskLevel: .evidence, requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord], capturesArtifacts: true, sensitiveOutput: true)
    }

    public static func tapCoordinate(target: String, x: Int, y: Int, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "uitest", "uiInput", "click", "\(x)", "\(y)"], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func swipeCoordinate(target: String, startX: Int, startY: Int, endX: Int, endY: Int, velocity: Int? = nil, executable: String = "hdc") -> TKHostCommand {
        var arguments = ["-t", target, "shell", "uitest", "uiInput", "swipe", "\(startX)", "\(startY)", "\(endX)", "\(endY)"]
        if let velocity {
            arguments.append("\(velocity)")
        }
        return TKHostCommand(executable: executable, arguments: arguments, riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func keyEvent(target: String, key: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "uitest", "uiInput", "keyEvent", key], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord])
    }

    public static func screenshot(target: String, remotePath: String, executable: String = "hdc") -> TKHostCommand {
        TKHostCommand(executable: executable, arguments: ["-t", target, "shell", "snapshot_display", "-f", remotePath], riskLevel: .evidence, requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord], capturesArtifacts: true, sensitiveOutput: true)
    }
}

public enum TKHarmonyDumpLayoutParserError: Error, Equatable {
    case remotePathNotFound
}

public enum TKHarmonyDumpLayoutParser {
    public static func remotePath(from output: String) throws -> String {
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = trimmed.range(of: "DumpLayout saved to:") {
                let path = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty {
                    return path
                }
            }
        }
        throw TKHarmonyDumpLayoutParserError.remotePathNotFound
    }
}

public struct TKHarmonyLayoutTextMatch: Codable, Equatable {
    public let text: String
    public let bounds: TKRect

    public init(text: String, bounds: TKRect) {
        self.text = text
        self.bounds = bounds
    }

    public var centerX: Int { Int(bounds.centerX.rounded()) }
    public var centerY: Int { Int(bounds.centerY.rounded()) }
}

public struct TKHarmonyLayoutNodeSummary: Codable, Equatable {
    public let nodeID: String
    public let type: String?
    public let text: String?
    public let originalText: String?
    public let identifier: String?
    public let key: String?
    public let accessibilityID: String?
    public let bounds: TKRect?
    public let clickable: Bool?
    public let enabled: Bool?
    public let focused: Bool?
    public let scrollable: Bool?
    public let visible: Bool?
    public let depth: Int
    public let childCount: Int

    public init(
        nodeID: String,
        type: String?,
        text: String?,
        originalText: String?,
        identifier: String?,
        key: String?,
        accessibilityID: String?,
        bounds: TKRect?,
        clickable: Bool?,
        enabled: Bool?,
        focused: Bool?,
        scrollable: Bool?,
        visible: Bool?,
        depth: Int,
        childCount: Int
    ) {
        self.nodeID = nodeID
        self.type = type
        self.text = text
        self.originalText = originalText
        self.identifier = identifier
        self.key = key
        self.accessibilityID = accessibilityID
        self.bounds = bounds
        self.clickable = clickable
        self.enabled = enabled
        self.focused = focused
        self.scrollable = scrollable
        self.visible = visible
        self.depth = depth
        self.childCount = childCount
    }
}

public enum TKHarmonyLayoutParser {
    public static func firstTextMatch(in data: Data, text: String) throws -> TKHarmonyLayoutTextMatch? {
        try nodeSummaries(in: data)
            .first { $0.text == text && $0.bounds != nil }
            .map { TKHarmonyLayoutTextMatch(text: text, bounds: $0.bounds ?? TKRect(x: 0, y: 0, width: 0, height: 0)) }
    }

    public static func nodeSummaries(in data: Data) throws -> [TKHarmonyLayoutNodeSummary] {
        let json = try JSONSerialization.jsonObject(with: data)
        return nodeSummaries(in: json, depth: 0, fallbackPath: "0")
    }

    public static func bounds(from rawBounds: String) -> TKRect? {
        let pattern = #"^\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\]\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\]$"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(rawBounds.startIndex..<rawBounds.endIndex, in: rawBounds)
        guard let match = expression.firstMatch(in: rawBounds, range: range), match.numberOfRanges == 5 else {
            return nil
        }
        let values = (1..<5).compactMap { index -> Double? in
            guard let valueRange = Range(match.range(at: index), in: rawBounds) else {
                return nil
            }
            return Double(rawBounds[valueRange])
        }
        guard values.count == 4 else {
            return nil
        }
        let x1 = values[0]
        let y1 = values[1]
        let x2 = values[2]
        let y2 = values[3]
        return TKRect(x: min(x1, x2), y: min(y1, y2), width: abs(x2 - x1), height: abs(y2 - y1))
    }

    private static func nodeSummaries(in value: Any, depth: Int, fallbackPath: String) -> [TKHarmonyLayoutNodeSummary] {
        if let dictionary = value as? [String: Any] {
            var result: [TKHarmonyLayoutNodeSummary] = []
            let children = dictionary["children"] as? [Any] ?? []
            if let attributes = dictionary["attributes"] as? [String: Any] {
                let hierarchy = cleanString(attributes["hierarchy"])
                let accessibilityID = cleanString(attributes["accessibilityId"])
                let hashcode = cleanString(attributes["hashcode"])
                let nodeID = hierarchy ?? accessibilityID ?? hashcode ?? fallbackPath
                result.append(TKHarmonyLayoutNodeSummary(
                    nodeID: nodeID,
                    type: cleanString(attributes["type"]),
                    text: cleanString(attributes["text"]),
                    originalText: cleanString(attributes["originalText"]),
                    identifier: cleanString(attributes["id"]),
                    key: cleanString(attributes["key"]),
                    accessibilityID: accessibilityID,
                    bounds: cleanString(attributes["bounds"]).flatMap(bounds),
                    clickable: boolValue(attributes["clickable"]),
                    enabled: boolValue(attributes["enabled"]),
                    focused: boolValue(attributes["focused"]),
                    scrollable: boolValue(attributes["scrollable"]),
                    visible: boolValue(attributes["visible"]),
                    depth: depth,
                    childCount: children.count
                ))
            }
            for (index, child) in children.enumerated() {
                result.append(contentsOf: nodeSummaries(in: child, depth: depth + 1, fallbackPath: "\(fallbackPath).\(index)"))
            }
            return result
        } else if let array = value as? [Any] {
            return array.enumerated().flatMap { index, item in
                nodeSummaries(in: item, depth: depth, fallbackPath: "\(fallbackPath).\(index)")
            }
        }
        return []
    }

    private static func cleanString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        guard let string = value as? String else { return nil }
        switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes":
            return true
        case "false", "0", "no":
            return false
        default:
            return nil
        }
    }
}

public enum TKHarmonyDeviceScope: String, Codable, Equatable {
    case emulator
    case real
}

public struct TKHarmonyTarget: Codable, Equatable {
    public let id: String
    public let target: String
    public let state: String
    public let transport: String
    public let isConnected: Bool
    public let scope: TKHarmonyDeviceScope
    public let kind: String
    public let blockedReasons: [String]
    public let source: String

    public init(target: String, state: String, transport: String = "hdc", source: String = "hdc") {
        let scope = TKHarmonyTarget.inferredScope(target: target, transport: transport)
        self.id = TKHarmonyTarget.targetID(target: target, scope: scope)
        self.target = target
        self.state = state
        self.transport = transport
        self.isConnected = state.lowercased() == "connected"
        self.scope = scope
        self.kind = scope == .real ? "real-device" : "emulator"
        self.blockedReasons = TKHarmonyTarget.blockedReasons(state: state)
        self.source = source
    }

    public var isReady: Bool {
        isConnected && blockedReasons.isEmpty
    }

    private static func inferredScope(target: String, transport: String) -> TKHarmonyDeviceScope {
        let lowerTarget = target.lowercased()
        let lowerTransport = transport.lowercased()
        if lowerTarget.hasPrefix("127.0.0.1:")
            || lowerTarget.hasPrefix("localhost:")
            || lowerTarget.hasPrefix("[::1]:")
            || lowerTarget.hasPrefix("::1:")
        {
            return .emulator
        }
        if lowerTransport == "tcp", lowerTarget.contains("127.0.0.1") || lowerTarget.contains("localhost") {
            return .emulator
        }
        return .real
    }

    private static func targetID(target: String, scope: TKHarmonyDeviceScope) -> String {
        switch scope {
        case .emulator:
            return "harmony:\(target)"
        case .real:
            return "harmony-real:\(stableRedactedTargetHash(target))"
        }
    }

    private static func blockedReasons(state: String) -> [String] {
        switch state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "connected":
            return []
        case "unauthorized":
            return ["unauthorized"]
        case "offline", "disconnected":
            return ["offline"]
        case "no", "no permissions", "nopermissions", "debugging-disabled":
            return ["debugging-disabled"]
        default:
            return state.isEmpty ? ["offline"] : [state]
        }
    }

    private static func stableRedactedTargetHash(_ target: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in target.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}

public enum TKHdcTargetListParser {
    public static func parse(_ text: String) -> [TKHarmonyTarget] {
        text.split(whereSeparator: \.isNewline)
            .compactMap { line -> TKHarmonyTarget? in
                let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard let target = parts.first, isLikelyTargetIdentifier(target) else { return nil }
                guard parts[0].lowercased() != "connectkey" else { return nil }
                if parts.count >= 3, isKnownTransport(parts[1]), isKnownState(parts[2]) {
                    return TKHarmonyTarget(target: parts[0], state: parts[2], transport: parts[1])
                }
                if parts.count >= 2, isKnownState(parts[1]) {
                    return TKHarmonyTarget(target: parts[0], state: parts[1])
                }
                if parts.count == 1 {
                    return TKHarmonyTarget(target: parts[0], state: "Connected")
                }
                return nil
            }
    }

    public static func defaultTarget(from targets: [TKHarmonyTarget]) -> TKHarmonyTarget? {
        let connected = targets.filter(\.isConnected)
        return connected.count == 1 ? connected[0] : nil
    }

    public static func targets(_ targets: [TKHarmonyTarget], matching scope: TKHarmonyDeviceScope?) -> [TKHarmonyTarget] {
        guard let scope else { return targets }
        return targets.filter { $0.scope == scope }
    }

    private static func isKnownTransport(_ value: String) -> Bool {
        switch value.lowercased() {
        case "tcp", "usb", "bt", "uart":
            return true
        default:
            return false
        }
    }

    private static func isKnownState(_ value: String) -> Bool {
        switch value.lowercased() {
        case "connected", "offline", "unauthorized", "unknown":
            return true
        default:
            return false
        }
    }

    private static func isLikelyTargetIdentifier(_ value: String) -> Bool {
        let lowered = value.lowercased()
        if ["connectkey", "connect", "list", "target", "targets", "empty", "error"].contains(lowered) {
            return false
        }
        return value.rangeOfCharacter(from: .alphanumerics) != nil
    }
}

public enum TKHarmonyBootCompletedParser {
    public static func isReady(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
}

public enum TKHarmonyShellProbeParser {
    public static func isAvailable(stdout: String, stderr _: String, exitCode: Int32) -> Bool {
        exitCode == 0 && stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "triton-shell-ready"
    }
}

public struct TKHarmonyHDCFakeResult: Equatable {
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

public enum TKHarmonyHDCFakeFixture: Equatable {
    case version
    case targetsSingleRealConnected
    case targetsMultipleRealConnected
    case targetsMixedEmulatorAndReal
    case targetsRealOffline
    case targetsRealUnauthorized
    case targetsRealConnected(target: String)
    case bootCompletedTrue(target: String)
    case bootCompletedFalse(target: String)
    case bootCompletedUnavailable(target: String)
    case shellAvailable(target: String)
    case shellUnavailable(target: String)

    var name: String {
        switch self {
        case .version: return "harmony-hdc-version"
        case .targetsSingleRealConnected: return "harmony-hdc-targets-single-real-connected"
        case .targetsMultipleRealConnected: return "harmony-hdc-targets-multiple-real-connected"
        case .targetsMixedEmulatorAndReal: return "harmony-hdc-targets-mixed-emulator-real"
        case .targetsRealOffline: return "harmony-hdc-targets-real-offline"
        case .targetsRealUnauthorized: return "harmony-hdc-targets-real-unauthorized"
        case .targetsRealConnected: return "harmony-hdc-targets-real-connected"
        case .bootCompletedTrue: return "harmony-boot-completed-true"
        case .bootCompletedFalse: return "harmony-boot-completed-false"
        case .bootCompletedUnavailable: return "harmony-boot-completed-unavailable"
        case .shellAvailable: return "harmony-shell-available"
        case .shellUnavailable: return "harmony-shell-unavailable"
        }
    }

    var argv: [String] {
        switch self {
        case .version:
            return ["-v"]
        case .targetsSingleRealConnected, .targetsMultipleRealConnected, .targetsMixedEmulatorAndReal, .targetsRealOffline, .targetsRealUnauthorized, .targetsRealConnected:
            return ["list", "targets", "-v"]
        case .bootCompletedTrue(let target), .bootCompletedFalse(let target), .bootCompletedUnavailable(let target):
            return ["-t", target, "shell", "param", "get", "bootevent.boot.completed"]
        case .shellAvailable(let target), .shellUnavailable(let target):
            return ["-t", target, "shell", "echo", "triton-shell-ready"]
        }
    }

    var result: TKHarmonyHDCFakeResult {
        switch self {
        case .version:
            return makeResult("Ver: 3.1.0\n")
        case .targetsSingleRealConnected:
            return makeResult("""
            HDCREAL001        USB     Connected
            """)
        case .targetsMultipleRealConnected:
            return makeResult("""
            HDCREAL001        USB     Connected
            HDCREAL002        USB     Connected
            """)
        case .targetsMixedEmulatorAndReal:
            return makeResult("""
            127.0.0.1:10100   TCP     Connected       localhost
            HDCREAL001        USB     Connected
            HDCREAL002        USB     Unauthorized
            """)
        case .targetsRealOffline:
            return makeResult("""
            HDCREAL001        USB     Offline
            """)
        case .targetsRealUnauthorized:
            return makeResult("""
            HDCREAL001        USB     Unauthorized
            """)
        case .targetsRealConnected(let target):
            return makeResult("\(target)        USB     Connected\n")
        case .bootCompletedTrue:
            return makeResult("true\n")
        case .bootCompletedFalse:
            return makeResult("false\n")
        case .bootCompletedUnavailable:
            return makeResult("", stderr: "param service unavailable\n", exitCode: 1)
        case .shellAvailable:
            return makeResult("triton-shell-ready\n")
        case .shellUnavailable:
            return makeResult("", stderr: "shell service unavailable\n", exitCode: 1)
        }
    }

    private func makeResult(_ stdout: String, stderr: String = "", exitCode: Int32 = 0) -> TKHarmonyHDCFakeResult {
        TKHarmonyHDCFakeResult(
            fixtureName: name,
            stdout: Data(stdout.utf8),
            stderr: Data(stderr.utf8),
            exitCode: exitCode
        )
    }
}

public struct TKHarmonyHDCFakeRunner {
    private let fixtures: [TKHarmonyHDCFakeFixture]

    public init(fixtures: [TKHarmonyHDCFakeFixture]) {
        self.fixtures = fixtures
    }

    public func run(_ command: TKHostCommand) throws -> TKHarmonyHDCFakeResult {
        guard let fixture = fixtures.first(where: { $0.argv == command.argv }) else {
            throw TKHarmonyHDCFakeRunnerError.fixtureNotFound(command.argv)
        }
        return fixture.result
    }
}

public enum TKHarmonyHDCFakeRunnerError: Error, Equatable {
    case fixtureNotFound([String])
}
