import Testing
@testable import TritonKitCLI

@Suite
struct EmbeddedGestureSchemaTests {
    @Test("action schema distinguishes unsupported recognizer injection from semantic updates")
    func gestureBoundaryIsDiscoverable() throws {
        let act = try #require(actionCommandSchemas().first { $0.name == "act" })
        let swipe = try #require(actionCommandSchemas().first { $0.name == "swipe" })
        #expect(act.outputSemantics?.contains("longPress") == true)
        #expect(act.outputSemantics?.contains("unsupported_capability") == true)
        #expect(act.outputSemantics?.contains("snapshot --include semantic") == true)
        #expect(swipe.outputSemantics?.contains("UIScrollView/UISlider") == true)
        #expect(swipe.outputSemantics?.contains("embedded-swipe-gesture-unsupported") == true)
        #expect(swipe.failureCodes.contains("unsupported_capability"))
    }

    @Test("tap duration schema never advertises host hold support")
    func tapDurationBoundaryIsDiscoverable() throws {
        let tap = try #require(actionCommandSchemas().first { $0.name == "tap" })
        let duration = try #require(tap.options.first { $0.name == "--duration" })
        #expect(duration.description.contains("unsupported_capability"))
        #expect(tap.outputSemantics?.contains("tap --duration") == true)
    }
}
