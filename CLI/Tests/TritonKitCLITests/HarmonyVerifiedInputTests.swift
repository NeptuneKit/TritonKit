import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct HarmonyVerifiedInputTests {
    private func layout(_ text: String = "", focused: Bool = true, extra: [String: Any] = [:], duplicate: Bool = false) throws -> Data {
        var attributes: [String: Any] = ["id": "editor", "type": "TextArea", "text": text, "focused": focused, "enabled": true, "visible": true, "password": false, "bounds": "[0,0][100,100]"]
        attributes.merge(extra) { _, new in new }
        let node: [String: Any] = ["attributes": attributes]
        return try JSONSerialization.data(withJSONObject: ["children": duplicate ? [node, node] : [node]])
    }

    @Test func exactWhitespaceAndOneSend() throws {
        var captures = 0
        var sends = 0
        var clock = 0.0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: " x ", expected: " x ", timeout: 1, capture: { _ in
            captures += 1
            return try layout(captures > 2 ? " x " : "")
        }, tap: { _, _, _ in Issue.record("unexpected tap") }, send: { _, _ in sends += 1 }, now: { clock }, sleep: { clock += $0 })
        #expect(result.ok)
        #expect(result.submission == "submitted")
        #expect(result.verification == "match")
        #expect(sends == 1)
        #expect(captures == 3)
        let json = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        #expect(json.contains(" x "))
        #expect(result.observedValue == " x ")
    }

    @Test("output transformation is explicit and cannot veto submission")
    func explicitOutputTransformation() throws {
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "alice@example.test", expected: "alice@example.test", timeout: 1,
            capture: { _ in try layout("alice@example.test") }, tap: { _, _, _ in Issue.record("already focused") }, send: { _, _ in })
        #expect(result.ok && result.observedValue == "alice@example.test")
        let secured = harmonyVerifiedInputOutput(result, secure: true)
        #expect(secured.ok && secured.submission == "submitted")
        #expect(secured.observedValue == nil && secured.redacted)
        #expect(harmonyVerifiedInputOutput(result, secure: false).observedValue == result.observedValue)
    }

    @Test("asterisks are ordinary provider text, not inferred privacy")
    func literalMaskCharacters() throws {
        var sends = 0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "***", expected: "***", timeout: 1,
            capture: { _ in try layout("***") }, tap: { _, _, _ in }, send: { _, _ in sends += 1 })
        #expect(sends == 1 && result.ok && result.observedValue == "***")
    }

    @Test func duplicateNeverSends() throws {
        var sends = 0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "secret", expected: "secret", timeout: 1, capture: { _ in try layout(duplicate: true) }, tap: { _, _, _ in Issue.record("unexpected tap") }, send: { _, _ in sends += 1 })
        #expect(result.code == "harmony_input_ambiguous")
        #expect(result.submission == "not-sent")
        #expect(sends == 0)
    }

    @Test func focusTapRequiresObservedFocus() throws {
        var captures = 0
        var taps = 0
        var sends = 0
        var clock = 0.0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 1, capture: { _ in
            captures += 1
            return try layout(captures > 3 ? "a" : "", focused: captures > 2)
        }, tap: { x, y, _ in taps += 1; #expect(x == 50 && y == 50) }, send: { _, _ in sends += 1 }, now: { clock }, sleep: { clock += $0 })
        #expect(result.ok)
        #expect(taps == 1 && sends == 1)
    }

    @Test func focusFailureNeverSends() throws {
        var clock = 0.0
        var taps = 0
        var sends = 0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 0.3, capture: { _ in try layout(focused: false) }, tap: { _, _, _ in taps += 1 }, send: { _, _ in sends += 1 }, now: { clock }, sleep: { clock += $0 })
        #expect(result.code == "harmony_input_focus_timeout")
        #expect(taps == 1 && sends == 0)
    }

    @Test func unknownSendNeverReplaysAndRedactsError() throws {
        var sends = 0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "PRIVATE", expected: "PRIVATE", timeout: 1, capture: { _ in try layout() }, tap: { _, _, _ in }, send: { _, _ in sends += 1; throw NSError(domain: "PRIVATE", code: 1) })
        #expect(result.submission == "unknown")
        #expect(sends == 1)
        #expect(!String(decoding: try JSONEncoder().encode(result), as: UTF8.self).contains("PRIVATE"))
    }

    @Test func unsafeAndUnavailableFieldsNeverSend() throws {
        let cases: [[String: Any]] = [["focused": NSNull()], ["enabled": false]]
        for extra in cases {
            var sends = 0
            let result = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 1, capture: { _ in try layout(extra: extra) }, tap: { _, _, _ in Issue.record("unexpected tap") }, send: { _, _ in sends += 1 })
            #expect(!result.ok)
            #expect(sends == 0)
        }
    }

    @Test func canonicallyEquivalentUnicodeIsNotAnExactRawMatch() throws {
        var clock = 0.0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "é", expected: "é", timeout: 0.2, capture: { _ in try layout("e\u{301}") }, tap: { _, _, _ in }, send: { _, _ in }, now: { clock }, sleep: { clock += $0 })
        #expect(!result.ok)
        #expect(result.verification == "mismatch")
    }

    @Test func mismatchAndChangedIdentityCannotPass() throws {
        var clock = 0.0
        let mismatch = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 0.3, capture: { _ in try layout("b") }, tap: { _, _, _ in }, send: { _, _ in }, now: { clock }, sleep: { clock += $0 })
        #expect(mismatch.verification == "mismatch")
        var count = 0
        let changed = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 1, capture: { _ in count += 1; return try layout("a", extra: count > 1 ? ["type": "TextInput"] : [:]) }, tap: { _, _, _ in }, send: { _, _ in })
        #expect(changed.code == "harmony_input_identity_changed")
        #expect(!changed.ok)
    }

    @Test func remoteShellQuoteIsSingleSafeArgument() {
        let command = harmonyVerifiedTextCommand(target: "device", text: "a'\";$(touch /tmp/no)\n空 格", hdc: "hdc", timeout: 1)
        #expect(command.arguments.last == "'a'\\''\";$(touch /tmp/no)\n空 格'")
        #expect(command.sensitiveOutput)
    }

    @Test func parserExposesOptInWithoutChangingDefaults() throws {
        let value = try TypeText.parse(["--platform", "harmony", "--verify", "--selector", "id:editor", "--expect-value", "", "--text", "", "--timeout", "1"])
        #expect(value.verify)
        #expect(value.expectValue == "")
        #expect(try !TypeText.parse(["--text", "a"]).verify)
    }
}

@Suite(.serialized)
struct HarmonyVerifiedInputBoundaryTests {
    private func data(_ attributes: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["attributes": attributes])
    }
    private var attributes: [String: Any] {
        ["id": "editor", "type": "TextArea", "text": "", "focused": false, "enabled": true, "visible": true, "bounds": "[0,0][100,100]"]
    }
    @Test func rawDecoderPreservesEmptyAndRejectsNumericBooleans() throws {
        let empty = try harmonyInputField(in: data(attributes), selector: "id:editor")
        #expect(empty.text == "")
        var bad = attributes; bad["focused"] = 1
        #expect(throws: HarmonyInputFailure.self) { try harmonyInputField(in: data(bad), selector: "id:editor") }
        bad = attributes; bad["type"] = "TextInput"
        let input = try harmonyInputField(in: data(bad), selector: "id:editor")
        #expect(input.text == "")
    }
    @Test func movingFieldNeverReceivesFocusTap() throws {
        var captures = 0
        var taps = 0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 1, capture: { _ in
            captures += 1
            var a = attributes
            if captures > 1 { a["bounds"] = "[50,0][150,100]" }
            return try data(a)
        }, tap: { _, _, _ in taps += 1 }, send: { _, _ in Issue.record("unexpected send") })
        #expect(result.code == "harmony_input_identity_changed")
        #expect(taps == 0)
    }
    @Test func captureFailureAfterSubmissionCannotBecomeSuccess() throws {
        var count = 0
        var a = attributes; a["focused"] = true
        let layout = try data(a)
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "private", expected: "private", timeout: 1, capture: { _ in
            count += 1
            if count > 1 { throw NSError(domain: "private", code: 1) }
            return layout
        }, tap: { _, _, _ in }, send: { _, _ in })
        #expect(result.submission == "submitted")
        #expect(result.verification == "unavailable")
        #expect(!result.ok)
    }
    @Test func deadlineRejectsLateReadAndUnknownFocusTap() throws {
        var clock = 0.0
        let late = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 1, capture: { _ in clock = 2; return try data(attributes) }, tap: { _, _, _ in Issue.record("unexpected tap") }, send: { _, _ in Issue.record("unexpected send") }, now: { clock })
        #expect(late.code == "harmony_input_timeout")
        let tapUnknown = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 1, capture: { _ in try data(attributes) }, tap: { _, _, _ in throw NSError(domain: "private", code: 1) }, send: { _, _ in Issue.record("unexpected send") })
        #expect(tapUnknown.focus == "unknown")
        #expect(tapUnknown.code == "harmony_input_focus_unknown")
    }
    @Test func layoutBudgetsNeverProducePartialUniqueMatch() throws {
        let oversized = Data(repeating: 32, count: 10 * 1024 * 1024 + 1)
        #expect(throws: HarmonyInputFailure.self) { try harmonyInputField(in: oversized, selector: "id:editor") }
        var node: [String: Any] = ["attributes": attributes]
        for _ in 0..<70 { node = ["children": [node]] }
        let deep = try JSONSerialization.data(withJSONObject: node)
        #expect(throws: HarmonyInputFailure.self) { try harmonyInputField(in: deep, selector: "id:editor") }
    }
}

@Suite(.serialized)
struct HarmonyVerifiedInputTimeoutTests {
    @Test func lastMismatchSurvivesReadDeadline() throws {
        var clock = 0.0
        var reads = 0
        let raw = Data(#"{"attributes":{"id":"editor","type":"TextArea","text":"wrong","focused":true,"enabled":true,"visible":true,"bounds":"[0,0][100,100]"}}"#.utf8)
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "a", expected: "a", timeout: 0.3, capture: { _ in
            reads += 1
            if reads > 2 { clock = 1 }
            return raw
        }, tap: { _, _, _ in }, send: { _, _ in }, now: { clock }, sleep: { clock += $0 })
        #expect(!result.ok)
        #expect(result.submission == "submitted")
        #expect(result.verification == "mismatch")
        #expect(result.code == "harmony_input_value_mismatch")
        #expect(result.timedOut)
    }

    @Test func hostTimeoutIsTypedWithoutRawErrorOrReplay() throws {
        let command = TKHostCommand(arguments: ["PRIVATE"], defaultTimeoutSeconds: 0.2)
        let error = HostCommandRunError.timeout(command: command, timeoutSeconds: 0.2, stdoutLogPath: "PRIVATE", stderrLogPath: "PRIVATE")
        let raw = Data(#"{"attributes":{"id":"editor","type":"TextArea","text":"","focused":true,"enabled":true,"visible":true,"bounds":"[0,0][100,100]"}}"#.utf8)
        let before = runHarmonyVerifiedInput(selector: "id:editor", text: "PRIVATE", expected: "PRIVATE", timeout: 1, capture: { _ in throw error }, tap: { _, _, _ in }, send: { _, _ in Issue.record("unexpected send") })
        #expect(before.code == "harmony_input_timeout")
        #expect(before.submission == "not-sent")
        let sending = runHarmonyVerifiedInput(selector: "id:editor", text: "PRIVATE", expected: "PRIVATE", timeout: 1, capture: { _ in raw }, tap: { _, _, _ in }, send: { _, _ in throw error })
        #expect(sending.code == "harmony_input_submission_unknown")
        #expect(sending.submission == "unknown")
        var count = 0
        let after = runHarmonyVerifiedInput(selector: "id:editor", text: "PRIVATE", expected: "PRIVATE", timeout: 1, capture: { _ in count += 1; if count > 1 { throw error }; return raw }, tap: { _, _, _ in }, send: { _, _ in })
        #expect(after.code == "harmony_input_timeout")
        #expect(after.submission == "submitted")
        #expect(after.verification == "timeout")
        for result in [before, sending, after] {
            #expect(!String(decoding: try JSONEncoder().encode(result), as: UTF8.self).contains("PRIVATE"))
        }
    }
}

@Suite(.serialized)
struct HarmonyVerifiedInputNativeDumpTests {
    // Actual owned API22 HVD editor attributes captured 2026-11-02, reduced to
    // relevant public layout keys. Empty password TextInput has no secure key.
    @Test func capturedNativeTextAreaAndEmptyPassword() throws {
        let area = Data(#"{"attributes":{"id":"editor","key":"editor","type":"TextArea","accessibilityId":"22","hashcode":"33:22","bounds":"[56,768][1264,1153]","text":"","originalText":"","enabled":"true","visible":"true","focused":"false"}}"#.utf8)
        let field = try harmonyInputField(in: area, selector: "id:editor")
        #expect(field.text == "")
        #expect(!field.focused)
        #expect(field.x == 660 && field.y == 960)
        let password = Data(#"{"attributes":{"id":"editor","type":"TextInput","bounds":"[56,768][1264,1013]","text":"••••","password":"true","enabled":"true","visible":"true","focused":"true"}}"#.utf8)
        var sends = 0
        let result = runHarmonyVerifiedInput(selector: "id:editor", text: "sample", expected: "sample", timeout: 1,
            capture: { _ in password }, tap: { _, _, _ in Issue.record("already focused") }, send: { _, _ in sends += 1 })
        #expect(result.code == "harmony_input_value_unavailable")
        #expect(result.submission == "submitted")
        #expect(result.verification == "unavailable")
        #expect(result.observedValue == "••••")
        #expect(!result.ok && !result.timedOut)
        #expect(sends == 1)
    }
}

@Suite(.serialized)
struct HarmonyVerifiedInputEnumerationTests {
    private func emptyResult() -> HostProcessResult {
        HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: "hdc list targets", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
    }

    @Test func plainEnumerationTimeoutIsNotAnEmptyTargetList() throws {
        var calls = 0
        var timeoutObserved = false
        do {
            _ = try harmonyVerifiedTargets(hdc: "hdc", deadline: 1, runner: { command in
                calls += 1
                if calls == 2 { throw HostCommandRunError.timeout(command: command, timeoutSeconds: command.defaultTimeoutSeconds, stdoutLogPath: nil, stderrLogPath: nil) }
                return emptyResult()
            }, now: { 0 })
        } catch HostCommandRunError.timeout {
            timeoutObserved = true
        }
        #expect(calls == 2)
        #expect(timeoutObserved)
    }

    @Test func deadlineBeforePlainEnumerationIsNotSwallowed() throws {
        var clock = 0.0
        var calls = 0
        var timeoutObserved = false
        do {
            _ = try harmonyVerifiedTargets(hdc: "hdc", deadline: 1, runner: { _ in
                calls += 1
                clock = 2
                return emptyResult()
            }, now: { clock })
        } catch let failure as HarmonyInputFailure {
            timeoutObserved = failure.code == "harmony_input_timeout"
        }
        #expect(calls == 1)
        #expect(timeoutObserved)
    }
}
