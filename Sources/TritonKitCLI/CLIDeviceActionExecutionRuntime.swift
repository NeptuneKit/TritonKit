import Foundation
import TritonKitShared

func makeDeviceActionContext(_ payload: DeviceActionPayload, selected: HostDeviceTarget, leaseID: String?, frozenText: String? = nil, inputDigestKey: Data? = nil) throws -> (TKActionContext, String) {
    let geometry: TKJSONValue = payload.geometry.map { .object(["width": .double($0.width), "height": .double($0.height), "orientation": .string($0.orientation)]) } ?? .null
    let text = try frozenText ?? payload.textFile.map { try String(contentsOfFile: $0, encoding: .utf8) }
    let textDigest = try text.map {
        try TKActionArgumentsDigest.make(arguments: ["text": .string($0)], algorithm: .hmacSHA256,
            key: inputDigestKey ?? Data(UUID().uuidString.utf8), redactionProfile: "private-input")
    }
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
        "inputDigest": textDigest.map { .string($0.digest) } ?? .null
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
        observationID: payload.observationID,
        coordinateSpace: payload.geometry == nil ? nil : "observed-device-pixels",
        policyDecision: .allow,
        createdAt: ISO8601DateFormatter().string(from: Date())
    )
    try context.validate()
    return (context, try context.contextDigest())
}

/// Compatibility projection is derived from validated provider facts. It cannot
/// turn nested errors, unknown delivery or submitted-only responses into success.
func deviceActionReceipt(
    _ data: Data, context: TKActionContext, contextDigest: String,
    admissionID: String?, generation: UInt64? = nil
) throws -> TKActionReceipt {
    guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let ok = object["ok"] as? Bool else { throw DeviceActionError.invalidResult }
    let provider = object["result"] as? [String: Any] ?? object
    let topError = object["error"] as? [String: Any]
    let nestedError = provider["error"] as? [String: Any]
    let errorCode = safeActionFailureCode((topError ?? nestedError)?["code"] as? String)
    let hasError = [object["error"], provider["error"]].contains { $0 != nil && !($0 is NSNull) }
    let rawStatus = provider["outcome"] as? String ?? provider["status"] as? String
    let status = safeActionFailureCode(rawStatus)
    let invalidStatus = rawStatus != nil && status == nil
    let completionStates = ["settled", "executed", "success", "completed"]
    let acceptedStates = ["submitted", "pending"]
    let knownUnknown = invalidStatus || (status.map { !completionStates.contains($0) && !acceptedStates.contains($0) } ?? false)
    let pendingState = status.map { acceptedStates.contains($0) } ?? false
    let succeeded = ok && !hasError && provider["ok"] as? Bool != false && !knownUnknown
    let explicitFalse = provider["executed"] as? Bool == false
    let verified = succeeded && !explicitFalse && !pendingState && provider["postconditionVerified"] as? Bool == true
    let flatHostSuccess = succeeded && object["result"] == nil && context.provider != "ios"
    let confirmed = succeeded && !explicitFalse && !pendingState && (verified || provider["executed"] as? Bool == true || flatHostSuccess)
    let submitted = succeeded && !explicitFalse && (provider["submitted"] as? Bool == true || pendingState)
    let delivery: TKActionDelivery = confirmed ? .delivered : (submitted ? .submitted : .unknown)
    let outcome: TKActionOutcome = confirmed ? .settled : (submitted ? .pending : .uncertain)
    let receipt = TKActionReceipt(actionID: context.actionID, operation: context.operation, target: context.target,
        leaseID: context.leaseID, admissionID: admissionID, contextDigest: contextDigest, generation: generation,
        delivery: delivery, outcome: outcome, executed: confirmed ? true : nil,
        originalStatus: errorCode ?? (knownUnknown ? status : nil) ?? (confirmed ? "settled" : (submitted ? "submitted" : "unknown")),
        terminalStatus: outcome.rawValue, postcondition: verified ? .verified : .unverified,
        failureCode: errorCode ?? (outcome == .uncertain ? "device_action_result_invalid" : nil))
    try receipt.validate()
    return receipt
}

func safeActionFailureCode(_ code: String?) -> String? {
    guard let code, code.utf8.count <= 128,
          code.range(of: "^[a-z][a-z0-9_]*$", options: .regularExpression) != nil else { return nil }
    return code
}

func projectDeviceActionResult(_ data: Data, receipt: TKActionReceipt) throws -> Data {
    var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    // Preserve provider payload/error; only derive the compatibility success flag.
    object["ok"] = receipt.outcome == .settled || receipt.outcome == .pending
    object["actionID"] = receipt.actionID
    object["admissionID"] = receipt.admissionID ?? NSNull() as Any
    object["contextDigest"] = receipt.contextDigest ?? NSNull() as Any
    object["delivery"] = receipt.delivery.rawValue
    object["outcome"] = receipt.outcome.rawValue
    object["executed"] = receipt.executed.map { $0 as Any } ?? NSNull()
    object["originalStatus"] = receipt.originalStatus ?? NSNull() as Any
    object["terminalStatus"] = receipt.terminalStatus ?? NSNull() as Any
    object["postcondition"] = receipt.postcondition.rawValue
    object["evidencePersistence"] = receipt.evidencePersistence.rawValue
    object["actionReceipt"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt))
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

func decorateDeviceActionResult(
    _ data: Data, context: TKActionContext, contextDigest: String, admissionID: String,
    generationStore: TKActionGenerationStore, generationToken: TKActionGenerationToken
) throws -> Data {
    guard generationStore.isCurrent(generationToken) else { throw DeviceActionError.generationStale }
    return try projectDeviceActionResult(data, receipt: deviceActionReceipt(data, context: context,
        contextDigest: contextDigest, admissionID: admissionID, generation: generationToken.generation))
}

func executeDeviceAction(
    _ payload: DeviceActionPayload, common: DeviceActionCommonOptions,
    admissionStore: TKActionAdmissionStore = TKActionAdmissionStore(),
    generationStore: TKActionGenerationStore = TKActionGenerationStore(),
    targetResolver: ((DeviceActionCommonOptions) throws -> HostDeviceTarget)? = nil,
    hostRunner: ((TKHostCommand) throws -> HostProcessResult)? = nil,
    iosRunner: ((Data) async throws -> Data)? = nil,
    leaseGate: (() async throws -> Void)? = nil
) async throws -> Data {
    let selected = try targetResolver?(common) ?? resolveHostDeviceSelection(request: .init(device: common.device,
        platform: HostDevicePlatform(rawValue: common.platform), ready: true), hdc: common.hdc, adb: common.adb).target
    let frozenText = try payload.textFile.map { try String(contentsOfFile: $0, encoding: .utf8) }
    let (context, digest) = try makeDeviceActionContext(payload, selected: selected, leaseID: common.leaseID, frozenText: frozenText)
    let evidence = try common.evidenceDir.map { try ActionEvidenceSession(directory: $0, context: context, platform: selected.platform) }
    let coordinator = TKActionAdmissionCoordinator(admissions: admissionStore, generations: generationStore)
    var handle: TKActionAdmissionHandle?
    var submitted = false
    var completedSubmissions = 0
    var response = Data()
    var rawArtifacts: [ActionRawArtifact] = []
    var hostAttempts = 0
    var receipt: TKActionReceipt
    do {
        if let leaseID = common.leaseID {
            if let leaseGate { try await leaseGate() }
            else { try await enforceTargetLease(host: common.host, port: common.port, target: selected.target, leaseID: leaseID) }
        }
        if selected.platform == "ios", payload.bundleID == nil || common.sessionRoot == nil { throw DeviceActionError.invalidSelector }
        try Task.checkCancellation()
        let admitted = try coordinator.admit(context: context)
        handle = admitted
        response = try await performDeviceAction(payload, selected: selected, common: common, frozenText: frozenText,
            hostRunner: { command in
                try Task.checkCancellation()
                guard coordinator.isCurrent(admitted) else { throw DeviceActionError.generationStale }
                submitted = true
                hostAttempts += 1
                let result: HostProcessResult
                do { result = try hostRunner?(command) ?? runHostCommand(command) }
                catch HostCommandRunError.nonZeroExit(let command, let failed) {
                    rawArtifacts += actionHostRawArtifacts(failed, attempt: hostAttempts)
                    throw HostCommandRunError.nonZeroExit(command: command, result: failed)
                } catch {
                    let coverage = try JSONSerialization.data(withJSONObject: ["attempt": hostAttempts,
                        "stdoutAvailable": false, "stderrAvailable": false, "reason": "host_runner_returned_no_output_bytes"])
                    rawArtifacts.append(ActionRawArtifact(name: "provider-\(hostAttempts)-coverage.json", data: coverage,
                        contentType: "application/json", unavailable: true, fidelity: "capture-coverage"))
                    throw error
                }
                rawArtifacts += actionHostRawArtifacts(result, attempt: hostAttempts)
                guard result.exitCode == 0 else { throw HostCommandRunError.nonZeroExit(command: command, result: result) }
                completedSubmissions += 1
                return result
            }, iosRunner: { request in
                submitted = true
                let output: Data
                if let iosRunner { output = try await iosRunner(request) }
                else { output = try IOSRunnerService().execute(operation: "request", payload: request) }
                rawArtifacts.append(ActionRawArtifact(name: "provider-response.json", data: output, contentType: "application/json"))
                return output
            })
        guard coordinator.isCurrent(admitted) else { throw DeviceActionError.generationStale }
        let facts = try deviceActionReceipt(response, context: context, contextDigest: digest,
            admissionID: admitted.admission.admissionID, generation: admitted.generation.generation)
        receipt = try coordinator.receipt(admitted, delivery: facts.delivery, outcome: facts.outcome,
            executed: facts.executed, originalStatus: facts.originalStatus, terminalStatus: facts.terminalStatus,
            postcondition: facts.postcondition, failureCode: facts.failureCode)
    } catch {
        if handle == nil && evidence == nil { throw error } // Keep preflight error compatibility.
        let code: String
        if let failure = error as? HostCommandRunError {
            switch failure {
            case .timeout: code = "host_command_timeout"
            case .nonZeroExit: code = "host_command_failed"
            case .launchFailed:
                code = "host_command_launch_failed"
                if completedSubmissions == 0 { submitted = false }
            default: code = "device_action_failed"
            }
        } else if let failure = error as? IOSRunnerFailure { code = safeActionFailureCode(failure.code) ?? "device_action_failed" }
        else if let failure = error as? CLIHTTPError,
            let envelope = (try? JSONSerialization.jsonObject(with: failure.data)) as? [String: Any],
            let detail = envelope["error"] as? [String: Any] {
            code = safeActionFailureCode(detail["code"] as? String) ?? "target_lease_conflict"
        }
        else if let failure = error as? HostApplePlatformControlError { code = safeActionFailureCode(failure.code) ?? "target_lease_conflict" }
        else if error as? DeviceActionError == .generationStale || error as? TKActionAdmissionCoordinatorError == .staleGeneration { code = "device_action_generation_stale" }
        else if error is CancellationError { code = "device_action_cancelled" }
        else { code = "device_action_result_invalid" }
        receipt = TKActionReceipt(actionID: context.actionID, operation: context.operation, target: context.target,
            leaseID: context.leaseID, admissionID: handle?.admission.admissionID, contextDigest: digest,
            generation: handle?.generation.generation, delivery: submitted ? .unknown : .notStarted,
            outcome: submitted ? .uncertain : .blocked, executed: submitted ? nil : false,
            originalStatus: code, terminalStatus: submitted ? "uncertain" : "blocked", postcondition: .unverified,
            failureCode: code)
        try receipt.validate()
        if let failure = error as? CLIHTTPError,
           let envelope = (try? JSONSerialization.jsonObject(with: failure.data)) as? [String: Any],
           envelope["ok"] as? Bool == false {
            response = failure.data
        } else {
            response = try JSONSerialization.data(withJSONObject: ["ok": false, "action": context.operation,
                "target": context.target, "error": ["code": code, "message": "Action did not complete with a verified provider result; observe before planning another input."]])
        }
    }
    if let evidence {
        if !rawArtifacts.contains(where: { $0.name == "provider-response.json" }) && !response.isEmpty {
            rawArtifacts.append(ActionRawArtifact(name: "provider-response.json", data: response, contentType: "application/json", fidelity: "derived-host-envelope"))
        }
        receipt = evidence.finish(receipt, rawArtifacts: rawArtifacts)
    }
    return try projectDeviceActionResult(response, receipt: receipt)
}

private func performDeviceAction(
    _ payload: DeviceActionPayload, selected: HostDeviceTarget, common: DeviceActionCommonOptions, frozenText: String?,
    hostRunner: (TKHostCommand) throws -> HostProcessResult,
    iosRunner: (Data) async throws -> Data
) async throws -> Data {
    func dispatch(_ command: TKHostCommand) throws -> HostProcessResult { try hostRunner(command) }
    if selected.platform == "android" {
        let command: TKHostCommand
        switch payload.action {
        case .tap: command = TKAndroidADBCommand.tapCoordinate(serial: selected.target, x: Int(payload.x!.rounded()), y: Int(payload.y!.rounded()), executable: common.adb)
        case .doubleTap:
            command = TKAndroidADBCommand.tapCoordinate(serial: selected.target, x: Int(payload.x!.rounded()), y: Int(payload.y!.rounded()), executable: common.adb)
        case .swipe: command = TKAndroidADBCommand.swipeCoordinate(serial: selected.target, startX: Int(payload.x!.rounded()), startY: Int(payload.y!.rounded()), endX: Int(payload.endX!.rounded()), endY: Int(payload.endY!.rounded()), durationMs: Int((payload.duration! * 1000).rounded()), executable: common.adb)
        case .press: command = TKAndroidADBCommand.keyEvent(serial: selected.target, keyCode: androidKeyEventName(for: payload.button!), executable: common.adb)
        case .type:
            let text = frozenText!
            command = TKAndroidADBCommand.inputText(serial: selected.target, text: text, executable: common.adb)
        }
        let first = try dispatch(command)
        if payload.action == .doubleTap { usleep(80_000); _ = try dispatch(command) }
        let resultData = try JSONSerialization.data(withJSONObject: ["ok": true, "action": "device.\(payload.action.rawValue)", "target": selected.id, "sourceCommand": first.sourceCommand, "postconditionVerified": false], options: [.sortedKeys])
        return resultData
    }
    if selected.platform == "harmony" {
        let command: TKHostCommand
        switch payload.action {
        case .tap: command = TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: Int(payload.x!.rounded()), y: Int(payload.y!.rounded()), executable: common.hdc)
        case .doubleTap: command = TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: Int(payload.x!.rounded()), y: Int(payload.y!.rounded()), executable: common.hdc)
        case .swipe: command = TKHarmonyHDCCommand.swipeCoordinate(target: selected.target, startX: Int(payload.x!.rounded()), startY: Int(payload.y!.rounded()), endX: Int(payload.endX!.rounded()), endY: Int(payload.endY!.rounded()), velocity: harmonySwipeVelocity(startX: payload.x!, startY: payload.y!, endX: payload.endX!, endY: payload.endY!, duration: payload.duration), executable: common.hdc)
        case .press: command = TKHarmonyHDCCommand.keyEvent(target: selected.target, key: harmonyKeyEventName(for: payload.button!), executable: common.hdc)
        case .type:
            let text = frozenText!
            command = TKHarmonyHDCCommand.inputText(target: selected.target, text: text, executable: common.hdc)
        }
        let first = try dispatch(command)
        if payload.action == .doubleTap { usleep(80_000); _ = try dispatch(command) }
        let resultData = try JSONSerialization.data(withJSONObject: ["ok": true, "action": "device.\(payload.action.rawValue)", "target": selected.id, "sourceCommand": first.sourceCommand, "postconditionVerified": false], options: [.sortedKeys])
        return resultData
    }
    guard let bundle = payload.bundleID, let sessionRoot = common.sessionRoot else { throw DeviceActionError.invalidSelector }
    let operation: String = payload.action == .tap ? "coordinateTap" : payload.action == .doubleTap ? "coordinateDoubleTap" : payload.action == .swipe ? "coordinateSwipe" : payload.action == .press ? "press" : "typeText"
    var body: [String: Any] = ["app": "target", "expectedBundle": bundle, "operation": operation]
    if let id = payload.observationID { body["observationID"] = id }; if let geometry = payload.geometry { body["geometry"] = ["width": geometry.width, "height": geometry.height, "orientation": geometry.orientation] }
    if let x = payload.x { body["x"] = x }; if let y = payload.y { body["y"] = y }; if let endX = payload.endX { body["endX"] = endX }; if let endY = payload.endY { body["endY"] = endY }; if let duration = payload.duration { body["duration"] = duration }; if let button = payload.button { body["button"] = button }
    if payload.action == .type { body["text"] = frozenText! }
    if let identifier = payload.identifier { body["selector"] = ["kind": "identifier", "value": identifier] } else if let label = payload.label { body["selector"] = ["kind": "label", "value": label] }
    let request: [String: Any] = ["device": selected.scope == "simulator" ? "sim:\(selected.rawTarget)" : selected.id, "sessionRoot": sessionRoot, "timeout": 60, "route": "/crossApp", "body": body, "requestID": payload.requestID]
    let data = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
    let result: Data
    result = try await iosRunner(data)
    return result
}

private func actionHostRawArtifacts(_ result: HostProcessResult, attempt: Int) -> [ActionRawArtifact] {
    [ActionRawArtifact(name: "provider-\(attempt)-stdout.bin", data: result.stdoutData, contentType: "application/octet-stream", truncated: result.stdoutTruncated, observedBytes: result.stdoutBytes),
     ActionRawArtifact(name: "provider-\(attempt)-stderr.bin", data: result.stderrData, contentType: "application/octet-stream", truncated: result.stderrTruncated, observedBytes: result.stderrBytes)]
}
