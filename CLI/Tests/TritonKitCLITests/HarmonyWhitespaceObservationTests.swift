import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Harmony whitespace observation")
struct HarmonyWhitespaceObservationTests {
    @Test(arguments: ["   ", "\t\n", " test "])
    func parserToObservationJSONPreservesContent(_ text: String) throws {
        for useFallback in [false, true] {
            let attributes: [String: Any] = ["text": useFallback ? "" : text, "originalText": useFallback ? text : "fallback", "type": "TextArea", "focused": true]
            let layout = try JSONSerialization.data(withJSONObject: ["attributes": attributes])
            let node = try #require(TKHarmonyLayoutParser.nodeSummaries(in: layout).first)
            let output = observeNode(fromHarmony: node)
            let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(output)) as? [String: Any])
            #expect(json["text"] as? String == text)
            #expect(output.focused == true)
        }
    }

    @Test(arguments: ["   ", " test "])
    func waitUsesExactContent(_ text: String) throws {
        let layout = try JSONSerialization.data(withJSONObject: ["attributes": ["text": text, "type": "TextArea", "bounds": "[0,0][40,20]"]])
        #expect(try harmonyWaitTextMatch(in: layout, text: text, role: "TextArea") != nil)
        #expect(try harmonyWaitTextMatch(in: layout, text: "test", role: "TextArea") == nil)
    }

    @Test(arguments: ["   ", " test "])
    func findUsesExactContent(_ text: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["attributes": ["text": text, "type": "TextArea", "bounds": "[0,0][40,20]"]])
        let target = TKHarmonyTarget(target: "fixture", state: "Connected", transport: "TCP")
        let capture: (TKHarmonyTarget, String) throws -> HarmonyLayoutCapture = { _, _ in
            HarmonyLayoutCapture(localPath: "synthetic", remotePath: "synthetic", sourceCommands: [], data: data)
        }
        let result = try resolveHostHarmonyFind(text, selected: target, hdc: "fake-hdc", captureLayout: capture)
        #expect(result.label == text)
        let error = try #require(throws: Error.self) {
            _ = try resolveHostHarmonyFind("test", selected: target, hdc: "fake-hdc", captureLayout: capture)
        }
        #expect(cliErrorDetail(for: error, endpoint: "/request", host: "127.0.0.1", port: 19421).code == "text_not_found")
    }

}
