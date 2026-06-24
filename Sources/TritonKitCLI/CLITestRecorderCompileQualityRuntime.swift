import Foundation

func compileQualityFindings(caseURL: URL) throws -> [TKTestRecorderQualityFinding] {
    var findings: [TKTestRecorderQualityFinding] = []
    let actionRows = try readTestRecorderJSONLines(
        from: caseURL.appendingPathComponent("actions.jsonl"),
        relativePath: "actions.jsonl"
    )
    for row in actionRows {
        let action = stringValue(row.object, "kind") ?? stringValue(row.object, "type") ?? stringValue(row.object, "action") ?? "unknown"
        let inputText = stringValue(row.object, "text")
            ?? stringValue(row.object, "value")
            ?? stringValue(row.object, "input")
        if let inputText, testRecorderLooksSensitive(inputText) {
            findings.append(TKTestRecorderQualityFinding(
                code: "privacy_candidate",
                path: row.sourcePath,
                severity: "review",
                message: "Action input looks like private or user-specific data and should be redacted before replay.",
                proposalKind: "contract.redaction"
            ))
        }
        if let selector = actionSelector(in: row.object), isWeakSelector(selector) {
            findings.append(TKTestRecorderQualityFinding(
                code: "weak_selector",
                path: row.sourcePath,
                severity: "review",
                message: "Action target uses a weak selector; prefer role, label, accessibility id, or page fingerprint evidence.",
                proposalKind: "contract.selector"
            ))
        }
        if action == "wait", fixedWaitDurationMs(in: row.object) != nil {
            findings.append(TKTestRecorderQualityFinding(
                code: "fixed_wait",
                path: row.sourcePath,
                severity: "review",
                message: "Action uses a fixed wait; prefer waiting for page, network, or UI evidence.",
                proposalKind: "contract.wait"
            ))
        }
    }

    let networkRows = try readTestRecorderJSONLines(
        from: caseURL.appendingPathComponent("network/capture.ndjson"),
        relativePath: "network/capture.ndjson"
    )
    for row in networkRows {
        guard let url = stringValue(row.object, "url"), isTransientNetworkURL(url) else {
            continue
        }
        findings.append(TKTestRecorderQualityFinding(
            code: "transient_network_request",
            path: row.sourcePath,
            severity: "review",
            message: "Network request looks transient or analytics-like and should not become a hard replay dependency.",
            proposalKind: "contract.network"
        ))
    }
    return findings
}

func compileWarnings(inspect: TKTestRecorderInspectResponse, summary: TKTestRecorderCompileSummary, qualityFindings: [TKTestRecorderQualityFinding]) -> [TKTestRecorderCompileWarning] {
    var warnings: [TKTestRecorderCompileWarning] = []
    if summary.actionEventCount == 0 {
        warnings.append(TKTestRecorderCompileWarning(
            code: "missing_actions",
            path: "actions.jsonl",
            message: "No action events were found; compile can only produce a preflight summary."
        ))
    }
    if summary.pageRouteEventCount == 0 && summary.pageFingerprintCount == 0 {
        warnings.append(TKTestRecorderCompileWarning(
            code: "missing_page_events",
            path: "pages/",
            message: "No route events or page fingerprints were found; replay page matching will need review."
        ))
    }
    if summary.networkEventCount == 0 && !inspect.artifacts.contains(where: { $0.kind == "network-map" && $0.present }) {
        warnings.append(TKTestRecorderCompileWarning(
            code: "missing_network_capture",
            path: "network/",
            message: "No network capture or map rules were found; replay will run without a network contract."
        ))
    }
    warnings.append(contentsOf: inspect.unsupportedCapabilities.map {
        TKTestRecorderCompileWarning(
            code: "unsupported_capability",
            path: "contract-capabilities.json.\($0.domain)",
            message: "Capability '\($0.name)' is not supported by the current compiler preflight."
        )
    })
    warnings.append(contentsOf: qualityFindings.map {
        TKTestRecorderCompileWarning(
            code: $0.code,
            path: $0.path,
            message: $0.message
        )
    })
    return warnings
}

func compileStatus(summary: TKTestRecorderCompileSummary, warnings: [TKTestRecorderCompileWarning]) -> String {
    if warnings.contains(where: { $0.code == "missing_actions" || $0.code == "missing_page_events" }) {
        return "needs-input"
    }
    if warnings.contains(where: { $0.code == "unsupported_capability" }) {
        return "needs-review"
    }
    return "compiled"
}

private func actionSelector(in object: [String: Any]) -> String? {
    if let selector = stringValue(object, "selector") {
        return selector
    }
    if let target = object["target"] as? [String: Any] {
        return stringValue(target, "selector")
            ?? stringValue(target, "css")
            ?? stringValue(target, "xpath")
    }
    return nil
}

private func fixedWaitDurationMs(in object: [String: Any]) -> Int? {
    intValue(object, keys: ["durationMs", "timeoutMs", "ms"])
}

func testRecorderLooksSensitive(_ value: String) -> Bool {
    let lowercased = value.lowercased()
    if lowercased.contains("password") || lowercased.contains("token") || lowercased.contains("secret") {
        return true
    }
    if value.range(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.regularExpression, .caseInsensitive]) != nil {
        return true
    }
    if value.range(of: #"\b\d{11,}\b"#, options: .regularExpression) != nil {
        return true
    }
    return false
}

private func isWeakSelector(_ selector: String) -> Bool {
    let lowercased = selector.lowercased()
    return lowercased.contains("nth-child")
        || lowercased.contains("/html/")
        || lowercased == "#input"
        || lowercased == "input"
        || lowercased == "button"
}
