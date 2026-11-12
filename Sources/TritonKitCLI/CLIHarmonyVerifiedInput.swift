import Foundation
import CoreFoundation
import TritonKitShared

/// Observed field values are raw provider data unless the caller requests secure output.
struct HarmonyVerifiedInputResult: Codable {
    var ok = false
    let action = "type"
    let platform = "harmony"
    var submission = "not-sent"
    var focus = "unknown"
    var verification = "unavailable"
    var code = "harmony_input_unavailable"
    var durations: [String: Double] = [:]
    var polls = 0
    var timedOut = false
    var redacted = false
    var observedValue: String?
    let note = "Submission receipt and observed full value are separate evidence. Match proves a postcondition, not that this command caused it."
}

/// Explicit caller output transformation; never controls whether input may run.
func harmonyVerifiedInputOutput(_ result: HarmonyVerifiedInputResult, secure: Bool) -> HarmonyVerifiedInputResult {
    var output = result
    output.redacted = secure
    if secure { output.observedValue = nil }
    return output
}

struct HarmonyInputField {
    let identity: String
    let text: String?
    let canVerifyText: Bool
    let focused: Bool
    let x: Int
    let y: Int
    let bounds: TKRect
}

struct HarmonyInputFailure: Error {
    let code: String
}

/// Decode raw layout, rejecting oversized or incomplete traversals rather than
/// deriving uniqueness/value evidence from the lossy shared display summaries.
func harmonyInputField(in data: Data, selector: String) throws -> HarmonyInputField {
    func fail(_ code: String) throws -> Never { throw HarmonyInputFailure(code: code) }
    guard selector.hasPrefix("id:"), selector.count > 3 else { try fail("harmony_input_invalid_selector") }
    guard data.count <= 10 * 1024 * 1024 else { try fail("harmony_input_layout_budget") }
    let root: Any
    do { root = try JSONSerialization.jsonObject(with: data) }
    catch { try fail("harmony_input_layout_invalid") }
    let id = String(selector.dropFirst(3))
    var matches: [[String: Any]] = []
    var nodes = 0
    func visit(_ value: Any, depth: Int) throws {
        nodes += 1
        guard nodes <= 10_000, depth <= 64 else { try fail("harmony_input_layout_budget") }
        if let array = value as? [Any] {
            for element in array { try visit(element, depth: depth + 1) }
        } else if let node = value as? [String: Any] {
            if let attributes = node["attributes"] as? [String: Any], attributes["id"] as? String == id {
                matches.append(attributes)
            }
            if let children = node["children"] { try visit(children, depth: depth + 1) }
        } else { try fail("harmony_input_layout_invalid") }
    }
    try visit(root, depth: 0)
    guard !matches.isEmpty else { try fail("harmony_input_not_found") }
    guard matches.count == 1 else { try fail("harmony_input_ambiguous") }
    let a = matches[0]
    func boolean(_ name: String) -> Bool? {
        if let value = a[name] as? String {
            if value == "true" { return true }; if value == "false" { return false }
            return nil
        }
        guard let number = a[name] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
    guard let type = a["type"] as? String, ["TextInput", "TextArea"].contains(type),
          boolean("visible") == true, boolean("enabled") == true else { try fail("harmony_input_not_editable") }
    // Provider masking is a limitation on verification, not permission to input.
    // Do not guess privacy from the characters in the observed value.
    let secureMarkers = ["password", "isPassword", "secure", "isSecure", "masked"]
    let providerMasksValue = secureMarkers.contains { a[$0] != nil && boolean($0) != false }
        || (a["inputType"] as? String)?.lowercased().contains("password") == true
    let text = a["text"] as? String
    guard let focused = boolean("focused") else { try fail("harmony_input_focus_unavailable") }
    guard let rawBounds = a["bounds"] as? String, let bounds = TKHarmonyLayoutParser.bounds(from: rawBounds),
          bounds.width > 0, bounds.height > 0 else { try fail("harmony_input_bounds_unavailable") }
    let x = bounds.x + bounds.width / 2
    let y = bounds.y + bounds.height / 2
    guard x.isFinite, y.isFinite, x >= 0, y >= 0, x < 1_000_000, y < 1_000_000 else { try fail("harmony_input_bounds_unavailable") }
    // Stable id is the user-facing identity. Type and provider identity detect
    // replacement when the platform supplies them; no object identity is invented.
    let identity = [id, type, a["accessibilityId"] as? String ?? "", a["hashcode"] as? String ?? ""].joined(separator: "\u{0}")
    return HarmonyInputField(identity: identity, text: text, canVerifyText: text != nil && !providerMasksValue, focused: focused, x: Int(x), y: Int(y), bounds: bounds)
}

func runHarmonyVerifiedInput(
    selector: String, text: String, expected: String, timeout: Double,
    capture: (Double) throws -> Data,
    tap: (Int, Int, Double) throws -> Void,
    send: (String, Double) throws -> Void,
    now: () -> Double = { ProcessInfo.processInfo.systemUptime },
    sleep: (Double) -> Void = { Thread.sleep(forTimeInterval: $0) }
) -> HarmonyVerifiedInputResult {
    var result = HarmonyVerifiedInputResult()
    let start = now()
    let deadline = start + timeout
    var phase = "resolve"
    var phaseStart = start
    func finishPhase() { result.durations[phase] = max(0, now() - phaseStart) }
    func remaining() throws -> Double {
        let budget = deadline - now()
        guard budget > 0 else { throw HarmonyInputFailure(code: "harmony_input_timeout") }
        return budget
    }
    func read() throws -> HarmonyInputField {
        let data = try capture(remaining())
        _ = try remaining() // A late capture cannot prove a timely result.
        result.polls += 1
        let field = try harmonyInputField(in: data, selector: selector)
        _ = try remaining()
        return field
    }
    func wait() { sleep(min(0.1, max(0, deadline - now()))) }
    do {
        guard timeout.isFinite, timeout > 0, timeout <= 60, !text.contains("\0") else { throw HarmonyInputFailure(code: "harmony_input_invalid_options") }
        var field = try read()
        result.observedValue = field.text
        let identity = field.identity
        finishPhase()
        phase = "focus"; phaseStart = now()
        result.focus = field.focused ? "confirmed" : "not-focused"
        if !field.focused {
            let beforeTap = try read()
            guard beforeTap.identity == identity, beforeTap.bounds == field.bounds else {
                throw HarmonyInputFailure(code: "harmony_input_identity_changed")
            }
            field = beforeTap
            if !field.focused {
                result.focus = "unknown"
                try tap(field.x, field.y, remaining())
            }
            while now() < deadline {
                field = try read()
                guard field.identity == identity else { throw HarmonyInputFailure(code: "harmony_input_identity_changed") }
                if field.focused { result.focus = "confirmed"; break }
                result.focus = "not-focused"
                wait()
            }
            guard result.focus == "confirmed" else { throw HarmonyInputFailure(code: "harmony_input_focus_timeout") }
        }
        finishPhase()
        phase = "send"; phaseStart = now()
        let sendBudget = try remaining()
        result.submission = "unknown" // No retry after crossing this boundary.
        try send(text, sendBudget)
        result.submission = "submitted"
        finishPhase()
        phase = "verify"; phaseStart = now()
        result.verification = "timeout"
        while now() < deadline {
            field = try read()
            guard field.identity == identity else { throw HarmonyInputFailure(code: "harmony_input_identity_changed") }
            result.observedValue = field.text
            result.focus = field.focused ? "confirmed" : "not-focused"
            guard field.canVerifyText, let observed = field.text else {
                result.verification = "unavailable"
                result.code = "harmony_input_value_unavailable"
                break
            }
            if observed.utf8.elementsEqual(expected.utf8) {
                result.ok = true; result.verification = "match"; result.code = "harmony_input_verified"
                break
            }
            result.verification = "mismatch"
            wait()
        }
        if !result.ok && result.verification != "unavailable" {
            result.timedOut = true
            result.code = result.verification == "mismatch" ? "harmony_input_value_mismatch" : "harmony_input_timeout"
        }
    } catch {
        if phase == "send", result.submission == "unknown" {
            result.code = "harmony_input_submission_unknown"
        } else if phase == "focus", result.focus == "unknown" {
            result.code = "harmony_input_focus_unknown"
        } else if case HostCommandRunError.timeout = error {
            result.code = phase == "focus" ? "harmony_input_focus_timeout" : "harmony_input_timeout"
        } else {
            result.code = (error as? HarmonyInputFailure)?.code ?? "harmony_input_capture_unavailable"
        }
        if case HostCommandRunError.timeout = error { result.timedOut = true }
        if let failure = error as? HarmonyInputFailure, ["harmony_input_timeout", "harmony_input_focus_timeout"].contains(failure.code) { result.timedOut = true }
        if phase == "verify" {
            if result.timedOut, result.verification == "mismatch" {
                // Keep the last actual observation; expiry cannot erase it.
                result.code = "harmony_input_value_mismatch"
            } else {
                result.verification = result.timedOut ? "timeout" : "unavailable"
            }
        }
    }
    finishPhase()
    result.durations["total"] = max(0, now() - start)
    return result
}

func harmonyVerifiedTextCommand(target: String, text: String, hdc: String, timeout: Double) -> TKHostCommand {
    let quoted = "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    return TKHostCommand(executable: hdc, arguments: ["-t", target, "shell", "uitest", "uiInput", "text", quoted], redactedArgumentIndexes: [6], riskLevel: .automation, requiredConfig: [.target, .timeout, .auditRecord], defaultTimeoutSeconds: timeout, sensitiveOutput: true)
}

func harmonyVerifiedTargets(
    hdc: String, deadline: Double,
    runner: HostDeviceCommandRunner = { try runHostCommand($0) },
    now: () -> Double = { ProcessInfo.processInfo.systemUptime }
) throws -> [TKHarmonyTarget] {
    var enumerationTimeout: Error?
    let targets = try harmonyTargets(hdc: hdc, runner: { command in
        do {
            let budget = deadline - now()
            guard budget > 0 else { throw HarmonyInputFailure(code: "harmony_input_timeout") }
            return try runner(command.withTimeout(budget))
        } catch {
            // The legacy plain-list fallback intentionally swallows errors.
            // Preserve timeout evidence only for this verified-input caller.
            if case HostCommandRunError.timeout = error { enumerationTimeout = error }
            if let failure = error as? HarmonyInputFailure, failure.code == "harmony_input_timeout" { enumerationTimeout = error }
            throw error
        }
    }).targets
    if let enumerationTimeout { throw enumerationTimeout }
    return targets
}

func executeHarmonyVerifiedInput(target: String, hdc: String, selector: String, text: String, expected: String, timeout: Double) -> HarmonyVerifiedInputResult {
    let started = ProcessInfo.processInfo.systemUptime
    let selected: TKHarmonyTarget
    do {
        let targets = try harmonyVerifiedTargets(hdc: hdc, deadline: started + timeout)
        let candidate = target == TKLocalTargetID ? TKHdcTargetListParser.defaultTarget(from: targets) : targets.first { $0.target == target || $0.id == target }
        guard let candidate, candidate.isConnected else { throw HarmonyInputFailure(code: "harmony_input_target_unavailable") }
        selected = candidate
    } catch {
        var result = HarmonyVerifiedInputResult()
        if case HostCommandRunError.timeout = error {
            result.code = "harmony_input_timeout"
            result.timedOut = true
        } else {
            result.code = (error as? HarmonyInputFailure)?.code ?? "harmony_input_target_unavailable"
        }
        if result.code == "harmony_input_timeout" { result.timedOut = true }
        result.durations["resolveTarget"] = ProcessInfo.processInfo.systemUptime - started
        result.durations["total"] = result.durations["resolveTarget"]
        return result
    }
    let selectionDuration = ProcessInfo.processInfo.systemUptime - started
    guard selectionDuration < timeout else {
        var result = HarmonyVerifiedInputResult(); result.code = "harmony_input_timeout"; result.timedOut = true
        result.durations["total"] = selectionDuration; return result
    }
    var result = runHarmonyVerifiedInput(selector: selector, text: text, expected: expected, timeout: timeout - selectionDuration, capture: { budget in
        let path = temporaryHarmonyArtifactPath(prefix: "triton-verified-input", extension: "json")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let captureDeadline = ProcessInfo.processInfo.systemUptime + budget
        return try dumpHarmonyLayout(selected: selected, hdc: hdc, output: path, timeout: budget, commandRunner: { command in
            let remaining = captureDeadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw HarmonyInputFailure(code: "harmony_input_timeout") }
            return try runHostCommand(command.withTimeout(min(command.defaultTimeoutSeconds, remaining)))
        }).data
    }, tap: { x, y, budget in
        _ = try runHostCommand(TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: x, y: y, executable: hdc).withTimeout(budget))
    }, send: { value, budget in
        _ = try runHostCommand(harmonyVerifiedTextCommand(target: selected.target, text: value, hdc: hdc, timeout: budget))
    })
    result.durations["resolveTarget"] = selectionDuration
    result.durations["total"] = ProcessInfo.processInfo.systemUptime - started
    return result
}
