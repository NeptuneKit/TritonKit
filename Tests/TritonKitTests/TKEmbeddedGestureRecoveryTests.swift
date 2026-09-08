import Foundation
import Testing
@testable import TritonKit
import TritonKitShared

@Suite
struct TKEmbeddedGestureRecoveryTests {
    @Test("unsupported embedded gestures preserve target evidence and executable discovery")
    func unsupportedGestureEnvelope() throws {
        for request in [
            TKInputRequest.longPress(x: 80, y: 50, duration: 6),
            TKInputRequest.swipe(startX: 80, startY: 50, endX: 80, endY: 10),
        ] {
            let result = unsupportedEmbeddedGesture(
                request, strategy: "fixture-unsupported",
                matchedOID: 41, matchedClassName: "FixtureLabel",
                activationOID: 42, activationClassName: "FixtureControl"
            )
            #expect(!result.ok)
            #expect(result.action == request.type.rawValue)
            #expect(result.error?.code == "unsupported_capability")
            #expect(result.targetOID == 42)
            #expect(result.matchedOID == 41)
            #expect(result.activationOID == 42)
            #expect(result.error?.nextAction?.command == "snapshot")
            #expect(result.error?.nextAction?.args == ["--include", "semantic", "--json"])
            #expect(result.error?.suggestedCommands?.contains("triton snapshot --include semantic --json") == true)
            #expect(result.error?.hint?.contains("app-owned") == true)
            #expect(result.error?.hint?.contains("host") == true)
            #expect(result.source == nil)
            #expect(result.sourceCommands == nil)
            let data = try JSONEncoder().encode(result)
            let decoded = try JSONDecoder().decode(TKInputResult.self, from: data)
            #expect(decoded == result)
        }
    }

    @Test("long press recovery never recommends a tap that discards duration")
    func longPressRecoveryDoesNotInventHostHold() {
        let result = unsupportedEmbeddedGesture(.longPress(x: 80, y: 50, duration: 6), strategy: "embedded-long-press-unsupported")
        #expect(result.error?.hint?.contains("tap --duration") == true)
        #expect(result.error?.suggestedCommands?.contains(where: { $0.contains("tap ") || $0.contains("long-press ") }) == false)
    }
}
