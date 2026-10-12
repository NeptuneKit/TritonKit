import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct SimulatorSwipeTests {
    private func target(ready: Bool = true) -> HostDeviceTarget {
        HostDeviceTarget(platform: "ios", id: "sim:SIM-1", target: "SIM-1", state: ready ? "Booted" : "Shutdown", ready: ready, source: "simctl", name: nil, runtime: nil, transport: nil, scope: "simulator", kind: "simulator")
    }

    @Test func hostOnlySubmissionIncludesOfflineVerification() throws {
        var calls = 0
        let request = TKInputRequest.swipe(startX: 900, startY: 1200, endX: 200, endY: 1200, width: 1200, height: 2400, duration: 0.35)
        let result = try runSimulatorSwipe(selected: target(), input: request) { id, input in
            calls += 1
            #expect(id == "host:ios:SIM-1")
            let lifecycle = try webIOSBaguetteSwipeLifecycle(input: input, udid: "SIM-1", screen: .init(width: 400, height: 800))
            #expect(lifecycle.events.first?.x == 300)
            #expect(lifecycle.events.last?.x == 67)
            #expect(lifecycle.events.last?.type == "touch1-up")
            return .success(action: "swipe", strategy: "host-hid-swipe", source: "host-hid", sourceCommands: [hostSourceCommand(lifecycle.command)])
        }
        #expect(calls == 1)
        #expect(result.ok)
        #expect(result.verification?.required == true)
        #expect(result.verification?.status == "not-verified")
        #expect(result.verification?.suggestedCommands.allSatisfy { $0.contains("SIM-1") && $0.contains("triton sim") } == true)
    }

    @Test func offlineTargetAndMissingAdapterFailClosed() throws {
        let input = TKInputRequest.swipe(startX: 300, startY: 400, endX: 100, endY: 400)
        let stopped = try runSimulatorSwipe(selected: target(ready: false), input: input) { _, _ in
            Issue.record("Shutdown target must never dispatch input")
            return .success(action: "swipe")
        }
        #expect(!stopped.ok)
        #expect(stopped.error?.code == "simulator_not_booted")
        let unavailable = try runSimulatorSwipe(selected: target(), input: input) { _, _ in
            throw HostCommandRunError.launchFailed("fixture missing adapter")
        }
        #expect(!unavailable.ok)
        #expect(unavailable.error?.code == "unsupported_host_input")
    }

    @Test func offlineCapabilityAndParserAreDiscoverable() throws {
        let capability = try #require(runtimeCapabilities(host: "127.0.0.1", port: 1, serverReachable: false, connected: false).first { $0.name == "ios-simulator-host-swipe" })
        #expect(capability.supported)
        #expect(capability.nextAction?.command == "sim")
        #expect(capability.nextAction?.requiresLongRunningProcess != true)
        let command = try TritonKitCLI.parseAsRoot(["sim", "swipe", "--start-x", "300", "--start-y", "400", "--end-x", "100", "--end-y", "400", "--width", "400", "--height", "800", "--json"])
        #expect(command is SimSwipe)
        #expect(SimSwipe.helpMessage().contains("without an embedded server"))
    }
}
