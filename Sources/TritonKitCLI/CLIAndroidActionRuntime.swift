import Foundation
import TritonKitShared

struct AndroidTapResolution {
    let x: Int
    let y: Int
    let match: HostAndroidTapMatch
    let sourceCommands: [String]
}

func androidTextSourceCommand(_ command: TKHostCommand, text: String, secure: Bool) -> String {
    guard secure else {
        return hostSourceCommand(command)
    }
    let redacted = "<redacted:length=\(text.count)>"
    return ([command.executable] + command.arguments.map { $0 == text ? redacted : $0 })
        .map(shellEscaped)
        .joined(separator: " ")
}

func androidKeyEventName(for button: String) -> String {
    switch button.lowercased() {
    case "home":
        return "KEYCODE_HOME"
    case "back":
        return "KEYCODE_BACK"
    case "power", "lock":
        return "KEYCODE_POWER"
    case "enter":
        return "KEYCODE_ENTER"
    case "menu":
        return "KEYCODE_MENU"
    case "volume-up":
        return "KEYCODE_VOLUME_UP"
    case "volume-down":
        return "KEYCODE_VOLUME_DOWN"
    default:
        return button.uppercased().hasPrefix("KEYCODE_") ? button.uppercased() : button
    }
}

func printAndroidTextInput(_ response: HostAndroidTextInputOutput, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("\(response.action): insertedLength=\(response.insertedLength)")
    }
}

func resolveAndroidActionSelection(target: String, adb: String) throws -> HostDeviceTarget {
    let request = HostDeviceSelectionRequest(
        device: target == TKLocalTargetID ? nil : target,
        platform: .android,
        ready: true
    )
    return try resolveHostDeviceSelection(request: request, hdc: "hdc", adb: adb).target
}

func observeAndroidNodes(selected: HostDeviceTarget, adb: String) throws -> ([TKAndroidUIAutomatorNodeSummary], [String]) {
    let dumpCommand = TKAndroidADBCommand.uiautomatorDump(serial: selected.target, remotePath: "/sdcard/window_dump.xml", executable: adb)
    let dumpResult = try runHostCommand(dumpCommand)
    let readCommand = TKAndroidADBCommand.readFile(serial: selected.target, remotePath: "/sdcard/window_dump.xml", executable: adb)
    let readResult = try runHostCommand(readCommand)
    let nodes = try TKAndroidUIAutomatorXMLParser.nodeSummaries(in: readResult.stdoutData)
    return (nodes, [dumpResult.sourceCommand, readResult.sourceCommand])
}

func androidTapMatch(from node: TKAndroidUIAutomatorNodeSummary) -> HostAndroidTapMatch {
    HostAndroidTapMatch(
        text: node.text,
        identifier: node.resourceID,
        label: node.contentDescription,
        role: node.className,
        bounds: node.bounds
    )
}

func observeAndroidTextMatch(
    selected: HostDeviceTarget,
    query: String,
    adb: String
) throws -> (HostAndroidTapMatch?, [String]) {
    let (nodes, commands) = try observeAndroidNodes(selected: selected, adb: adb)
    let lowered = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let match = nodes.first { node in
        [node.text, node.contentDescription, node.resourceID].compactMap { $0 }.contains {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(lowered)
        }
    }.map(androidTapMatch(from:))
    return (match, commands)
}

func resolveAndroidTapQuery(
    selected: HostDeviceTarget,
    query: String,
    adb: String
) throws -> AndroidTapResolution {
    let (nodes, sourceCommands) = try observeAndroidNodes(selected: selected, adb: adb)
    let lowered = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    guard let node = nodes.first(where: { node in
        [node.text, node.contentDescription, node.resourceID].compactMap { $0 }.contains {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(lowered)
        }
    }) else {
        throw HostCommandRunError.layoutTextNotFound(query)
    }
    guard let bounds = node.bounds else {
        throw RuntimeError("Android host tap matched \(query) but the node has no bounds.")
    }
    let x = Int((bounds.x + (bounds.width / 2)).rounded())
    let y = Int((bounds.y + (bounds.height / 2)).rounded())
    return AndroidTapResolution(
        x: x,
        y: y,
        match: androidTapMatch(from: node),
        sourceCommands: sourceCommands
    )
}
