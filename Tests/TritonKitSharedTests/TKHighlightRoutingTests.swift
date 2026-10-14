import Testing
import TritonKitShared

@Suite struct TKHighlightRoutingTests {
    @Test func aliasesAndHTTPRoutesUseIndependentRequests() {
        #expect(TKCLICommandRequest(type: "highlight.apply").requestType == .highlightApply)
        #expect(TKCLICommandRequest(type: "highlight.status").requestType == .highlightStatus)
        #expect(TKCLICommandRequest(type: "highlight.clear").requestType == .highlightClear)
        #expect(TKCLICommandRequest(type: "highlight.capabilities").requestType == .highlightCapabilities)
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .highlightApply)?.method == .post)
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .highlightCapabilities)?.method == .get)
    }
}
