import Foundation
import Testing
@testable import TritonKitShared

@Suite("Harmony layout text fidelity")
struct TKHarmonyWhitespaceTests {
    private func layout(_ attributes: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["attributes": attributes])
    }

    @Test(arguments: ["   ", "\t\n", " test ", " 你好 ", "\u{00a0}"])
    func preservesContent(_ text: String) throws {
        let node = try #require(TKHarmonyLayoutParser.nodeSummaries(in: layout([
            "text": text, "originalText": text, "type": " TextArea ", "id": " input "
        ])).first)
        #expect(node.text == text)
        #expect(node.originalText == text)
        #expect(node.type == "TextArea")
        #expect(node.identifier == "input")
    }

    @Test func emptyMissingAndInvalidRemainAbsent() throws {
        for attributes: [String: Any] in [[:], ["text": "", "originalText": ""], ["text": NSNull(), "originalText": 3]] {
            let node = try #require(TKHarmonyLayoutParser.nodeSummaries(in: layout(attributes)).first)
            #expect(node.text == nil)
            #expect(node.originalText == nil)
        }
    }

    @Test(arguments: ["   ", " test "])
    func exactMatchUsesOriginalContent(_ text: String) throws {
        let data = try layout(["text": text, "bounds": "[0,0][40,20]"])
        #expect(try TKHarmonyLayoutParser.firstTextMatch(in: data, text: text)?.text == text)
        #expect(try TKHarmonyLayoutParser.firstTextMatch(in: data, text: "test") == nil)
    }
}
