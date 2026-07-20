import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct IOSHostWaitRuntimeTests {
    private let target = HostDeviceTarget(
        platform: "ios",
        id: "sim:ABC-149",
        target: "ABC-149",
        state: "Booted",
        ready: true,
        source: "simctl",
        name: "Issue 149 Simulator",
        runtime: "iOS 26.5",
        transport: nil,
        scope: "simulator",
        kind: "simulator"
    )

    @Test("iOS host wait matches text and role from the Simulator AX observer")
    func matchesHostAXTextAndRole() async throws {
        let result = try await waitForIOSHostText(
            selected: target,
            text: "directory debug",
            role: "AXStaticText",
            timeout: 0.2,
            interval: 0.01,
            observe: { target in
                iosHostObservation(
                    target: target,
                    nodes: [iosHostNode(text: "Remote Directory Debug", role: "AXStaticText")]
                )
            }
        )

        #expect(result.ok)
        #expect(result.platform == "ios")
        #expect(result.target == target)
        #expect(result.condition == "text")
        #expect(result.matched)
        #expect(!result.timedOut)
        #expect(result.pollCount == 1)
        #expect(result.match?.text == "Remote Directory Debug")
        #expect(result.sourceCommands == ["triton sim ax --device ABC-149 --json"])
    }

    @Test("iOS host gone waits for a successful AX poll that confirms absence")
    func goneWaitUsesSuccessfulAbsence() async throws {
        var polls = 0
        let result = try await waitForIOSHostText(
            selected: target,
            text: "Loading",
            role: nil,
            timeout: 0.2,
            interval: 0.01,
            gone: true,
            observe: { target in
                polls += 1
                return iosHostObservation(
                    target: target,
                    nodes: polls == 1 ? [iosHostNode(text: "Loading")] : [iosHostNode(text: "Ready")]
                )
            }
        )

        #expect(result.ok)
        #expect(result.condition == "gone")
        #expect(result.pollCount == 2)
        #expect(result.match == nil)
    }

    @Test("iOS host wait returns the normal timeout envelope")
    func missingTextTimesOut() async throws {
        let startedAt = Date()
        let result = try await waitForIOSHostText(
            selected: target,
            text: "Never",
            role: nil,
            timeout: 0.04,
            interval: 0.005,
            observe: { target in iosHostObservation(target: target, nodes: []) }
        )

        #expect(!result.ok)
        #expect(!result.matched)
        #expect(result.timedOut)
        #expect(result.pollCount > 0)
        #expect(Date().timeIntervalSince(startedAt) < 0.3)
    }

    @Test("iOS host wait selection is simulator-only and treats local as automatic")
    func selectionRequestIsSimulatorOnly() {
        #expect(iosHostWaitSelectionRequest(target: TKLocalTargetID) == HostDeviceSelectionRequest(
            device: nil,
            platform: .ios,
            scope: .simulator,
            ready: true
        ))
        #expect(iosHostWaitSelectionRequest(target: "sim:ABC-149") == HostDeviceSelectionRequest(
            device: "sim:ABC-149",
            platform: .ios,
            scope: .simulator,
            ready: true
        ))
    }
}

private func iosHostObservation(target: String, nodes: [ObserveNodeOutput]) -> ObserveOutput {
    ObserveOutput(
        ok: true,
        action: "observe.tree",
        platform: "ios",
        capturedAt: "2026-07-20T00:00:00Z",
        partial: true,
        target: "sim:\(target)",
        sources: [
            ObserveSourceOutput(
                name: "host-layout",
                available: true,
                reason: nil,
                artifact: nil,
                sourceCommands: ["triton sim ax --device \(target) --json"]
            ),
        ],
        nodes: nodes,
        artifacts: [],
        sourceCommands: ["triton sim ax --device \(target) --json"],
        note: "host AX"
    )
}

private func iosHostNode(text: String, role: String = "AXStaticText") -> ObserveNodeOutput {
    ObserveNodeOutput(
        nodeID: "ios-host:\(text)",
        source: "host-layout",
        role: role,
        text: text,
        identifier: nil,
        frame: TKRect(x: 0, y: 0, width: 100, height: 40),
        enabled: true,
        focused: false,
        hidden: false,
        candidateOnly: false,
        confidence: 0.9,
        capabilities: ["visible", "tap"],
        missingCapabilities: []
    )
}
