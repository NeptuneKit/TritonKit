import Foundation
import Testing
@testable import TritonKitCLI

@Suite("P15 action provider parser")
struct ActionProviderParserTests {
    @Test("UI-TARS click parses into tap primitive preview")
    func uiTarsClickParsesIntoTapPreview() throws {
        let response = try parseActionProviderOutput(
            provider: .uiTars,
            input: "Thought: tap primary action\nAction: click(start_box='(500,330)')"
        )

        #expect(response.ok)
        #expect(response.provider == "ui-tars")
        #expect(response.primitive == "tap")
        #expect(response.coordinateSystem == "normalized_0_1000")
        #expect(response.point?.x == 500)
        #expect(response.point?.y == 330)
        #expect(response.commandPreview == ["triton", "tap", "--x", "500", "--y", "330", "--json"])
    }

    @Test("UI-TARS swipe parses start and end points")
    func uiTarsSwipeParsesStartAndEndPoints() throws {
        let response = try parseActionProviderOutput(
            provider: .uiTars,
            input: "Action: swipe(start_box='(500,800)', end_box='(500,200)')"
        )

        #expect(response.primitive == "swipe")
        #expect(response.point?.y == 800)
        #expect(response.endPoint?.y == 200)
        #expect(response.commandPreview.contains("--end-y"))
    }

    @Test("AgentCPM-GUI POINT parses into tap primitive preview")
    func agentCPMPointParsesIntoTapPreview() throws {
        let response = try parseActionProviderOutput(
            provider: .agentCPMGUI,
            input: #"{"action":"POINT","point":[250,750]}"#
        )

        #expect(response.provider == "agentcpm-gui")
        #expect(response.sourceFormat == "agentcpm-gui-json")
        #expect(response.primitive == "tap")
        #expect(response.point?.x == 250)
        #expect(response.point?.y == 750)
    }

    @Test("AgentCPM-GUI TYPE parses text without execution")
    func agentCPMTypeParsesTextWithoutExecution() throws {
        let response = try parseActionProviderOutput(
            provider: .agentCPMGUI,
            input: #"{"action":"TYPE","text":"hello"}"#
        )

        #expect(response.primitive == "type")
        #expect(response.text == "hello")
        #expect(response.commandPreview == ["triton", "type", "hello", "--json"])
    }

    @Test("unsupported provider action fails with stable code")
    func unsupportedActionFailsWithStableCode() throws {
        let failure = #expect(throws: TKActionProviderParseFailure.self) {
            _ = try parseActionProviderOutput(provider: .agentCPMGUI, input: #"{"action":"DRAG"}"#)
        }

        #expect(failure?.code == "action_provider_parse_failed")
    }
}
