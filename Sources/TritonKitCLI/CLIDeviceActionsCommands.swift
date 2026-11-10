import ArgumentParser
import Foundation
import TritonKitShared

/// Standalone typed action parsers. Registration into the existing `device`
/// tree is intentionally owned by the integration agent.
struct DeviceActionCommonOptions: ParsableArguments {
    @Option(help: "Explicit target selector") var device: String
    @Option(help: "Target platform: ios, android, or harmony") var platform: String
    @Option(help: "Latest observation geometry width") var width: Double?
    @Option(help: "Latest observation geometry height") var height: Double?
    @Option(help: "Latest observation orientation") var orientation: String?
    @Option(help: "Latest observation identifier") var observationID: String?
    @Option(help: "Idempotency request identifier") var requestID: String = UUID().uuidString
    @Option(help: "Bundle ID for iOS Runner actions") var bundleID: String?
    @Option(help: "Latest observed element identifier") var identifier: String?
    @Option(help: "Latest observed element label") var label: String?
    @Option(help: "ADB executable") var adb: String = "adb"
    @Option(help: "HDC executable") var hdc: String = "hdc"
    @Option(help: "Private iOS Runner session root") var sessionRoot: String?
    @Option(name: .customLong("lease"), help: "Optional target lease token") var leaseID: String?
    @Option(help: "Server host for target lease check") var host: String = "127.0.0.1"
    @Option(help: "Server port for target lease check") var port: Int = 19421
}

struct DeviceTap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tap")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option var x: Double
    @Option var y: Double
    func payload() throws -> DeviceActionPayload { try common.make(.tap, x: x, y: y) }
}
struct DeviceDoubleTap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "double-tap")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option var x: Double
    @Option var y: Double
    func payload() throws -> DeviceActionPayload { try common.make(.doubleTap, x: x, y: y) }
}
struct DeviceSwipe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "swipe")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option var x: Double
    @Option var y: Double
    @Option var endX: Double
    @Option var endY: Double
    @Option var duration: Double
    func payload() throws -> DeviceActionPayload { try common.make(.swipe, x: x, y: y, endX: endX, endY: endY, duration: duration) }
}
struct DevicePress: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "press")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option var button: String
    func payload() throws -> DeviceActionPayload { try common.make(.press, button: button) }
}
struct DeviceType: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "type")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option(help: "Private UTF-8 text file") var textFile: String
    func payload() throws -> DeviceActionPayload { try common.make(.type, textFile: textFile) }
}
private extension DeviceActionCommonOptions {
    func make(_ action: DeviceActionKind, x: Double? = nil, y: Double? = nil, endX: Double? = nil, endY: Double? = nil, duration: Double? = nil, button: String? = nil, textFile: String? = nil) throws -> DeviceActionPayload {
        let geometry: DeviceActionGeometry?
        if let width, let height, let orientation { geometry = try DeviceActionGeometry(width: width, height: height, orientation: orientation) } else { geometry = nil }
        return try makeDeviceActionPayload(action: action, device: device, platform: platform, requestID: requestID, geometry: geometry, observationID: observationID, x: x, y: y, endX: endX, endY: endY, duration: duration, button: button, bundleID: bundleID, textFile: textFile, identifier: identifier, label: label)
    }
}

func makeDeviceActionContext(_ payload: DeviceActionPayload, selected: HostDeviceTarget, leaseID: String?) throws -> (TKActionContext, String) {
    let geometry: TKJSONValue = payload.geometry.map { .object(["width": .double($0.width), "height": .double($0.height), "orientation": .string($0.orientation)]) } ?? .null
    let arguments: [String: TKJSONValue] = [
        "action": .string(payload.action.rawValue),
        "device": .string(selected.id),
        "platform": .string(payload.platform),
        "requestID": .string(payload.requestID),
        "observationID": payload.observationID.map(TKJSONValue.string) ?? .null,
        "geometry": geometry,
        "x": payload.x.map(TKJSONValue.double) ?? .null,
        "y": payload.y.map(TKJSONValue.double) ?? .null,
        "endX": payload.endX.map(TKJSONValue.double) ?? .null,
        "endY": payload.endY.map(TKJSONValue.double) ?? .null,
        "duration": payload.duration.map(TKJSONValue.double) ?? .null,
        "button": payload.button.map(TKJSONValue.string) ?? .null,
        "bundleID": payload.bundleID.map(TKJSONValue.string) ?? .null,
        "identifier": payload.identifier.map(TKJSONValue.string) ?? .null,
        "label": payload.label.map(TKJSONValue.string) ?? .null,
        "textFile": payload.textFile == nil ? .null : .string("<private>")
    ]
    let digest = try TKActionArgumentsDigest.make(arguments: arguments, redactionProfile: "private-paths-and-input")
    let context = TKActionContext(
        actionID: payload.requestID,
        target: TKNormalizeTargetLeaseKey(selected.id),
        targetIdentity: selected.id,
        operation: "device.\(payload.action.rawValue)",
        provider: selected.platform,
        argsDigest: digest.digest,
        argsDigestAlgorithm: digest.algorithm,
        argsCanonicalizationVersion: digest.canonicalizationVersion,
        argsRedactionProfile: digest.redactionProfile,
        leaseID: leaseID,
        policyDecision: .allow,
        createdAt: ISO8601DateFormatter().string(from: Date())
    )
    try context.validate()
    return (context, try context.contextDigest())
}

func decorateDeviceActionResult(
    _ data: Data,
    context: TKActionContext,
    contextDigest: String,
    admissionID: String,
    generationStore: TKActionGenerationStore,
    generationToken: TKActionGenerationToken
) throws -> Data {
    guard generationStore.isCurrent(generationToken) else {
        throw DeviceActionError.generationStale
    }
    guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw DeviceActionError.invalidResult
    }
    object["actionID"] = context.actionID
    object["admissionID"] = admissionID
    object["contextDigest"] = contextDigest
    object["delivery"] = "delivered"
    object["outcome"] = "settled"
    object["executed"] = true
    object["originalStatus"] = "settled"
    object["terminalStatus"] = "settled"
    object["postcondition"] = object["postconditionVerified"] as? Bool == true ? "verified" : "unverified"
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

func executeDeviceAction(
    _ payload: DeviceActionPayload,
    common: DeviceActionCommonOptions,
    admissionStore: TKActionAdmissionStore = TKActionAdmissionStore(),
    generationStore: TKActionGenerationStore = TKActionGenerationStore(),
    targetResolver: ((DeviceActionCommonOptions) throws -> HostDeviceTarget)? = nil,
    hostRunner: ((TKHostCommand) throws -> HostProcessResult)? = nil,
    iosRunner: ((Data) async throws -> Data)? = nil,
    leaseGate: (() async throws -> Void)? = nil
) async throws -> Data {
    let selected = try targetResolver?(common) ?? resolveHostDeviceSelection(request: .init(device: common.device, platform: HostDevicePlatform(rawValue: common.platform), ready: true), hdc: common.hdc, adb: common.adb).target
    if let leaseID = common.leaseID {
        if let leaseGate { try await leaseGate() }
        else { try await enforceTargetLease(host: common.host, port: common.port, target: selected.target, leaseID: leaseID) }
    }
    let (context, contextDigest) = try makeDeviceActionContext(payload, selected: selected, leaseID: common.leaseID)
    let generation = generationStore.begin(target: selected.id, actionID: payload.requestID)
    let admission = try admissionStore.issue(actionID: context.actionID, contextDigest: contextDigest, target: context.target, leaseID: context.leaseID, now: Date())
    _ = try admissionStore.consume(admissionID: admission.admissionID, contextDigest: contextDigest, target: context.target, leaseID: context.leaseID, now: Date())
    if selected.platform == "android" {
        let command: TKHostCommand
        switch payload.action {
        case .tap: command = TKAndroidADBCommand.tapCoordinate(serial: selected.target, x: Int(payload.x!.rounded()), y: Int(payload.y!.rounded()), executable: common.adb)
        case .doubleTap:
            command = TKAndroidADBCommand.tapCoordinate(serial: selected.target, x: Int(payload.x!.rounded()), y: Int(payload.y!.rounded()), executable: common.adb)
        case .swipe: command = TKAndroidADBCommand.swipeCoordinate(serial: selected.target, startX: Int(payload.x!.rounded()), startY: Int(payload.y!.rounded()), endX: Int(payload.endX!.rounded()), endY: Int(payload.endY!.rounded()), durationMs: Int((payload.duration! * 1000).rounded()), executable: common.adb)
        case .press: command = TKAndroidADBCommand.keyEvent(serial: selected.target, keyCode: androidKeyEventName(for: payload.button!), executable: common.adb)
        case .type:
            let text = try String(contentsOf: URL(fileURLWithPath: payload.textFile!), encoding: .utf8)
            command = TKAndroidADBCommand.inputText(serial: selected.target, text: text, executable: common.adb)
        }
        let first = try hostRunner?(command) ?? runHostCommand(command)
        if payload.action == .doubleTap { usleep(80_000); _ = try hostRunner?(command) ?? runHostCommand(command) }
        let resultData = try JSONSerialization.data(withJSONObject: ["ok": true, "action": "device.\(payload.action.rawValue)", "target": selected.id, "sourceCommand": first.sourceCommand, "postconditionVerified": false], options: [.sortedKeys])
        return try decorateDeviceActionResult(resultData, context: context, contextDigest: contextDigest, admissionID: admission.admissionID, generationStore: generationStore, generationToken: generation)
    }
    if selected.platform == "harmony" {
        let command: TKHostCommand
        switch payload.action {
        case .tap: command = TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: Int(payload.x!.rounded()), y: Int(payload.y!.rounded()), executable: common.hdc)
        case .doubleTap: command = TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: Int(payload.x!.rounded()), y: Int(payload.y!.rounded()), executable: common.hdc)
        case .swipe: command = TKHarmonyHDCCommand.swipeCoordinate(target: selected.target, startX: Int(payload.x!.rounded()), startY: Int(payload.y!.rounded()), endX: Int(payload.endX!.rounded()), endY: Int(payload.endY!.rounded()), velocity: harmonySwipeVelocity(startX: payload.x!, startY: payload.y!, endX: payload.endX!, endY: payload.endY!, duration: payload.duration), executable: common.hdc)
        case .press: command = TKHarmonyHDCCommand.keyEvent(target: selected.target, key: harmonyKeyEventName(for: payload.button!), executable: common.hdc)
        case .type:
            let text = try String(contentsOf: URL(fileURLWithPath: payload.textFile!), encoding: .utf8)
            command = TKHarmonyHDCCommand.inputText(target: selected.target, text: text, executable: common.hdc)
        }
        let first = try hostRunner?(command) ?? runHostCommand(command)
        if payload.action == .doubleTap { usleep(80_000); _ = try hostRunner?(command) ?? runHostCommand(command) }
        let resultData = try JSONSerialization.data(withJSONObject: ["ok": true, "action": "device.\(payload.action.rawValue)", "target": selected.id, "sourceCommand": first.sourceCommand, "postconditionVerified": false], options: [.sortedKeys])
        return try decorateDeviceActionResult(resultData, context: context, contextDigest: contextDigest, admissionID: admission.admissionID, generationStore: generationStore, generationToken: generation)
    }
    guard let bundle = payload.bundleID, let sessionRoot = common.sessionRoot else { throw DeviceActionError.invalidSelector }
    let operation: String = payload.action == .tap ? "coordinateTap" : payload.action == .doubleTap ? "coordinateDoubleTap" : payload.action == .swipe ? "coordinateSwipe" : payload.action == .press ? "press" : "typeText"
    var body: [String: Any] = ["app": "target", "expectedBundle": bundle, "operation": operation]
    if let id = payload.observationID { body["observationID"] = id }; if let geometry = payload.geometry { body["geometry"] = ["width": geometry.width, "height": geometry.height, "orientation": geometry.orientation] }
    if let x = payload.x { body["x"] = x }; if let y = payload.y { body["y"] = y }; if let endX = payload.endX { body["endX"] = endX }; if let endY = payload.endY { body["endY"] = endY }; if let duration = payload.duration { body["duration"] = duration }; if let button = payload.button { body["button"] = button }
    if payload.action == .type { body["text"] = try String(contentsOf: URL(fileURLWithPath: payload.textFile!), encoding: .utf8) }
    if let identifier = payload.identifier { body["selector"] = ["kind": "identifier", "value": identifier] } else if let label = payload.label { body["selector"] = ["kind": "label", "value": label] }
    let request: [String: Any] = ["device": selected.scope == "simulator" ? "sim:\(selected.rawTarget)" : selected.id, "sessionRoot": sessionRoot, "timeout": 60, "route": "/crossApp", "body": body, "requestID": payload.requestID]
    let data = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
    let result = try await (iosRunner?(data) ?? IOSRunnerService().execute(operation: "request", payload: data))
    return try decorateDeviceActionResult(result, context: context, contextDigest: contextDigest, admissionID: admission.admissionID, generationStore: generationStore, generationToken: generation)
}
private func printDeviceActionResult(_ payload: DeviceActionPayload, common: DeviceActionCommonOptions) async throws {
    do { print(String(decoding: try await executeDeviceAction(payload, common: common), as: UTF8.self)) }
    catch let error as DeviceActionError {
        let code: String
        switch error {
        case .generationStale: code = "device_action_generation_stale"
        case .invalidResult: code = "device_action_result_invalid"
        default: code = "device_action_invalid"
        }
        try failHostValidation(code: code, message: "\(error)", hint: "Refresh target/observation and use a supported platform action.", outputFormat: .json)
    }
    catch { try failHostCommand(error, outputFormat: .json) }
}
extension DeviceTap { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
extension DeviceDoubleTap { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
extension DeviceSwipe { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
extension DevicePress { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
extension DeviceType { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
