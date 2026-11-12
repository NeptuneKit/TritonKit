import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("P2 host mutation shared receipts")
struct HostActionReceiptTests {
    @Test("readonly app commands never receive mutation admission")
    func readonlyAppCommandsAreNotMutations() {
        for operation in ["app.list", "app.info", "app.inspect", "app.container", "app.unknown"] {
            #expect(!isUnifiedHostMutation(operation))
        }
    }

    @Test("receipt projection supports explicit app and HID operation identities")
    func sharedReceiptIdentity() throws {
        for action in ["app.launch", "app.open-url", "app.terminate", "sim.tap", "sim.swipe", "sim.press"] {
            #expect(isUnifiedHostMutation(action))
            let command = TKHostCommand(executable: "fixture", arguments: [action, "--device", "sim-fixture"], defaultTimeoutSeconds: 1)
            let context = try makeHostActionContext(action: action, target: "sim:fixture/app:demo.app", runtimeScope: "host-simulator", command: command)
            let coordinator = TKActionAdmissionCoordinator()
            let handle = try coordinator.admit(context: context)
            let result = HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0,
                sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false,
                stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
            let receipt = try makeHostActionReceipt(context: context, handle: handle, result: result)
            #expect(receipt.operation == action)
            #expect(receipt.target == context.target)
            #expect(receipt.delivery == .delivered)
            #expect(receipt.outcome == .settled)
            #expect(receipt.executed == true)
            #expect(receipt.postcondition == .unverified)
            try receipt.validate()
        }
    }

    @Test("host failure preserves unknown delivery in shared receipt")
    func failedHostReceiptIsUncertain() throws {
        let command = TKHostCommand(executable: "fixture", arguments: ["app.open-url", "private://url"], defaultTimeoutSeconds: 1)
        let context = try makeHostActionContext(action: "app.open-url", target: "sim:fixture", runtimeScope: "host-simulator", command: command)
        let handle = try TKActionAdmissionCoordinator().admit(context: context)
        let result = HostProcessResult(stdoutData: Data(), stderrData: Data("failed".utf8), exitCode: 7,
            sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false,
            stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 6)
        let receipt = try makeHostActionReceipt(context: context, handle: handle, result: result)
        #expect(receipt.delivery == .unknown)
        #expect(receipt.outcome == .uncertain)
        #expect(receipt.executed == nil)
        #expect(receipt.failureCode == "host_action_failed")
        try receipt.validate()
    }
}
