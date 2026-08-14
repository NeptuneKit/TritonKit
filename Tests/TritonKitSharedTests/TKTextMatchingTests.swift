import Foundation
import Testing
@testable import TritonKitShared

/// Contract tests for the single text-normalization + matching helper shared by
/// the iOS embedded-runtime text-query surfaces (`wait --text`, `act find`, and
/// `observe tree`/`observe current` text exposure). Every surface must agree on
/// trimming, case folding, diacritic folding, and substring semantics so that a
/// node visible in `observe` is also matchable by `wait` and `act find`.
@Suite
struct TKTextMatchingTests {
    @Test("normalization trims whitespace and folds case and diacritics")
    func normalization() {
        #expect(TKNormalizeQueryText("  Login \n") == "login")
        #expect(TKNormalizeQueryText("Café") == "cafe")
        #expect(TKNormalizeQueryText("  登录  ") == "登录")
        #expect(TKNormalizeQueryText("") == "")
    }

    @Test("substring matching is trimmed, case-insensitive, and diacritic-insensitive")
    func substringMatching() {
        #expect(TKTextMatches("Complex harness: 1", query: "harness"))
        #expect(TKTextMatches("Complex harness: 1", query: "  HARNESS "))
        #expect(TKTextMatches("登录", query: " 登录 "))
        #expect(TKTextMatches("Login", query: "login"))
        #expect(TKTextMatches("Café", query: "CAFE"))
        #expect(!TKTextMatches("Login", query: "Register"))
        #expect(!TKTextMatches("Login", query: ""))
        #expect(!TKTextMatches("", query: "login"))
    }

    @Test("exact matching shares the same normalization")
    func exactMatching() {
        #expect(TKTextMatches("Login", query: "  login ", mode: .exact))
        #expect(TKTextMatches("Café", query: "cafe", mode: .exact))
        #expect(!TKTextMatches("Login Screen", query: "login", mode: .exact))
    }

    @Test("AX node matching covers label, title, value, and identifier with optional value")
    func axNodeMatching() {
        let node = TKAXNode(
            role: "textField",
            label: nil,
            value: "alice",
            identifier: "username-field",
            title: nil,
            frame: TKRect(x: 0, y: 0, width: 100, height: 40),
            enabled: true,
            focused: false,
            hidden: false,
            targetOID: 1,
            className: "UITextField",
            children: []
        )
        #expect(TKAXNodeMatchesText(node, query: "alice"))
        #expect(TKAXNodeMatchesText(node, query: "ALICE"))
        #expect(TKAXNodeMatchesText(node, query: "username"))
        #expect(TKAXNodeMatchesText(node, query: "user"))
        #expect(!TKAXNodeMatchesText(node, query: "alice", includeValue: false))
        #expect(TKAXNodeMatchesText(node, query: "username-field", includeValue: false))
    }
}
