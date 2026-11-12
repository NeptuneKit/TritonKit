import Foundation
import TritonKitShared

func isUnifiedHostMutation(_ action: String) -> Bool {
    // Operation labels supported by this adapter, not evidence of command routing.
    ["app.install", "app.uninstall", "app.launch", "app.open-url", "app.terminate",
     "sim.tap", "sim.swipe", "sim.press"].contains(action)
}

func makeHostActionContext(action: String, target: String, runtimeScope: String, command: TKHostCommand) throws -> TKActionContext {
    let args = command.arguments.map(TKJSONValue.string)
    let digest = try TKActionArgumentsDigest.make(
        arguments: [
            "action": .string(action),
            "target": .string(target),
            "runtimeScope": .string(runtimeScope),
            "arguments": .array(args)
        ],
        redactionProfile: "host-command-arguments"
    )
    let context = TKActionContext(
        actionID: UUID().uuidString,
        target: target,
        operation: action,
        provider: runtimeScope,
        argsDigest: digest.digest,
        argsDigestAlgorithm: digest.algorithm,
        argsCanonicalizationVersion: digest.canonicalizationVersion,
        argsRedactionProfile: digest.redactionProfile,
        policyDecision: .allow,
        createdAt: ISO8601DateFormatter().string(from: Date())
    )
    try context.validate()
    return context
}

func makeHostActionReceipt(
    context: TKActionContext,
    handle: TKActionAdmissionHandle,
    result: HostProcessResult
) throws -> TKActionReceipt {
    let receipt = TKActionReceipt(
        schemaVersion: TKActionReceipt.currentSchemaVersion,
        actionID: handle.context.actionID,
        operation: handle.context.operation,
        target: handle.context.target,
        leaseID: handle.context.leaseID,
        admissionID: handle.admission.admissionID,
        contextDigest: handle.contextDigest,
        generation: handle.generation.generation,
        delivery: result.exitCode == 0 ? .delivered : .unknown,
        outcome: result.exitCode == 0 ? .settled : .uncertain,
        executed: result.exitCode == 0 ? true : nil,
        originalStatus: result.exitCode == 0 ? "host_exit_0" : "host_exit_\(result.exitCode)",
        terminalStatus: result.exitCode == 0 ? "settled" : "uncertain",
        postcondition: .unverified,
        failureCode: result.exitCode == 0 ? nil : "host_action_failed"
    )
    try receipt.validate()
    return receipt
}
