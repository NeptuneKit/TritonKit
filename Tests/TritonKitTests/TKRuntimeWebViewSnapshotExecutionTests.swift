import Foundation
import Testing
import TritonKitShared
@testable import TritonKit
#if canImport(JavaScriptCore)
import JavaScriptCore

@Suite
struct TKRuntimeWebViewSnapshotExecutionTests {
    @Test("actual snapshot script parses and executes for default and forms-only includes")
    func executesGeneratedScript() throws {
        for includes in [TKWebViewSnapshotRequest().include, ["forms"]] {
            let context = try #require(JSContext())
            context.evaluateScript(Self.fixture)
            let script = try runtimeWebViewSnapshotScript(include: includes, maxDOMNodes: 1, maxTextBytes: 4)
            let result = context.evaluateScript(script)
            try #require(context.exception == nil, "Generated JavaScript failed: \(context.exception?.toString() ?? "unknown")")
            let json = try #require(result?.toString())
            let payload = try decodeRuntimeWebViewSnapshotPayload(json)
            #expect(payload.forms.count == 1)
            #expect(payload.forms.first?.selector == "[name=\"email\"]")
            #expect(payload.forms.first?.valueLength == 13)
            #expect(!json.contains("secret-value!"))
            #expect(payload.truncation.truncated)
            #expect(payload.dom.count == (includes.contains("dom") ? 1 : 0))
            #expect(payload.text == (includes.contains("text") ? ["Hell"] : []))
        }
    }

    private static let fixture = #"""
    var window = this;
    window.getComputedStyle = function() { return {}; };
    function field(name) {
      return { id: '', tagName: 'INPUT', value: 'secret-value!', textContent: '',
        getAttribute: function(k) { return k === 'name' ? name : k === 'type' ? 'password' : null; },
        getBoundingClientRect: function() { return {x:0,y:0,width:100,height:30}; }
      };
    }
    var fields = [field('email'), field('other')];
    var document = { body: { innerText: 'Hello world' }, activeElement: fields[0],
      querySelectorAll: function() { return fields; }, getElementsByTagName: function() { return []; }
    };
    """#
}
#endif
