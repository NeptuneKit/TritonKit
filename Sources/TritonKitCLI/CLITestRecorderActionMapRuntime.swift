import Foundation

func writeActionMapIfReady(_ contract: TKTestRecorderCompiledContract?, caseURL: URL) throws -> TKTestRecorderContractArtifact? {
    guard let contract, !contract.actions.isEmpty else {
        return nil
    }
    let actionMap = buildActionMap(from: contract)
    let outputURL = caseURL
        .appendingPathComponent("actions", isDirectory: true)
        .appendingPathComponent("action-map.json")
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(actionMap)
    try data.write(to: outputURL, options: .atomic)
    return TKTestRecorderContractArtifact(
        path: "actions/action-map.json",
        absolutePath: outputURL.path,
        contentType: "application/json",
        written: true,
        byteCount: data.count
    )
}

func buildActionMap(from contract: TKTestRecorderCompiledContract) -> TKTestRecorderActionMap {
    TKTestRecorderActionMap(
        schemaVersion: 1,
        kind: "triton.testrec.action-map",
        rules: contract.actions.map { action in
            let redactionRequired = action.inputText.map(testRecorderLooksSensitive) ?? false
            let hasTarget = action.targetText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            let supported = actionMapSupportedActions.contains(action.action)
            return TKTestRecorderActionMapRule(
                index: action.index,
                id: "action-\(action.index)",
                sourceEventID: action.sourceEventID,
                sourcePath: action.sourcePath,
                action: action.action,
                target: TKTestRecorderActionMapTarget(
                    label: action.targetText,
                    text: action.targetText,
                    selector: nil
                ),
                strategy: actionMapStrategy(supported: supported, hasTarget: hasTarget),
                requiresReview: !supported || !hasTarget || redactionRequired,
                redactionRequired: redactionRequired,
                evidence: actionMapEvidence(action: action, hasTarget: hasTarget, redactionRequired: redactionRequired)
            )
        }
    )
}

private let actionMapSupportedActions: Set<String> = [
    "tap", "type", "paste", "scroll", "swipe", "wait", "assert", "open-url", "screenshot", "evidence",
]

private func actionMapStrategy(supported: Bool, hasTarget: Bool) -> String {
    if !supported {
        return "unsupported-action"
    }
    if !hasTarget {
        return "needs-target-proposal"
    }
    return "semantic-target"
}

private func actionMapEvidence(action: TKTestRecorderCompiledAction, hasTarget: Bool, redactionRequired: Bool) -> [String] {
    var evidence = ["source-action"]
    if hasTarget {
        evidence.append("target-text")
    }
    if action.inputText != nil {
        evidence.append(redactionRequired ? "input-redaction-required" : "input-text")
    }
    return evidence
}
