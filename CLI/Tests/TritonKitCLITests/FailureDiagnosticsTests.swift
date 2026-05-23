import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct FailureDiagnosticsTests {
    @Test("assert failure includes nearest text and suggested commands")
    func assertFailureIncludesDiagnostics() {
        let result = TKUIAssertEvaluate(
            TKUIAssertRequest(condition: .textExists, query: "Go to lottery"),
            nodes: [
                TKAXNode(
                    role: "button",
                    label: "Lottery",
                    value: nil,
                    identifier: nil,
                    title: nil,
                    frame: TKRect(x: 0, y: 0, width: 100, height: 44),
                    enabled: true,
                    focused: false,
                    hidden: false,
                    targetOID: nil,
                    className: "UIButton",
                    children: []
                ),
            ]
        )

        #expect(result.ok == false)
        #expect(result.nearestText == ["Lottery"])
        #expect(result.suggestedCommands?.contains("triton find 'Go to lottery' --all --json") == true)
    }

    @Test("tap target failure maps to machine-readable CLI diagnostics")
    func tapTargetFailureMapsToCLIDiagnostics() {
        let failure = TKTapTargetResolutionFailure(
            query: "Go to lottery",
            message: "No tappable UI target matched query: Go to lottery",
            candidateCount: 0,
            nearestCandidates: ["Lottery"],
            suggestedCommands: ["triton find 'Go to lottery' --all --json", "triton screenshot --json"]
        )

        let detail = cliErrorDetail(for: failure, endpoint: "/request", host: "127.0.0.1", port: 19421)

        #expect(detail.code == "text_not_found")
        #expect(detail.nearestCandidates == ["Lottery"])
        #expect(detail.suggestedCommands == ["triton find 'Go to lottery' --all --json", "triton screenshot --json"])
        #expect(detail.candidateCount == 0)
    }
}
