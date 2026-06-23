import Foundation
import TritonKitShared

let testRecorderLocalSimulatedExecutor = "local-simulated"

func replayTritonTestCaseLocalSimulated(path: String, platform: String, device: String?, evidenceDirectory: String? = nil, targetFingerprints: [TKJSONValue]? = nil) throws -> TKTestRecorderReplayRunResponse {
    let plan = try replayTritonTestCaseDryRun(path: path, platform: platform, device: device)
    let executor = testRecorderLocalSimulatedExecutor
    let pageMatches = try replayPageMatches(plan: plan, targetFingerprints: targetFingerprints)
    let networkResults = try replayNetworkResults(casePath: plan.path)
    var blockers = plan.blockers
    blockers.append(contentsOf: replayPageMatchBlockers(pageMatches))
    let pageResults: [TKTestRecorderReplayPageResult] = plan.pageChecks.map { check in
        let match = pageMatches[check.index]
        return TKTestRecorderReplayPageResult(
            index: check.index,
            pageId: check.pageId,
            route: check.route,
            status: blockers.isEmpty ? (match?.decision ?? "simulated") : (match?.decision ?? "not-run"),
            matchScore: match?.score,
            matchDecision: match?.decision,
            sourcePath: check.sourcePath,
            evidence: match?.evidence ?? [
                "compiled-contract",
                "page-fingerprint-contract",
                executor,
                "no-target-device",
            ],
            expectedArtifacts: check.expectedArtifacts
        )
    }
    let steps = plan.plannedSteps.map { step in
        TKTestRecorderReplayStepResult(
            index: step.index,
            sourceEventID: step.sourceEventID,
            action: step.action,
            status: blockers.isEmpty ? "simulated-passed" : "not-run",
            sourcePath: step.sourcePath,
            command: step.command,
            argv: step.argv,
            deviceCommandExecuted: false,
            artifactRefs: [],
            evidence: [
                "compiled-contract",
                "action-map",
                executor,
                "no-device-command-executed",
            ],
            failure: nil,
            expectedArtifacts: step.expectedArtifacts,
            stopConditions: step.stopConditions
        )
    }
    let artifactRefs = evidenceDirectory == nil ? [] : [
        "run/replay-result.json",
        "run/events.jsonl",
        "run/run.json",
    ]
    let response = TKTestRecorderReplayRunResponse(
        plan: plan,
        executor: executor,
        evidenceDir: evidenceDirectory,
        artifactRefs: artifactRefs,
        pageResults: pageResults,
        networkResults: networkResults,
        steps: steps,
        blockers: blockers
    )
    if let evidenceDirectory {
        try writeTestRecorderReplayEvidence(response: response, evidenceDirectory: evidenceDirectory)
    }
    return response
}

func decodeTestRecorderTargetFingerprintsJSON(_ targetFingerprintsJSON: String?) throws -> [TKJSONValue]? {
    guard let targetFingerprintsJSON,
          !targetFingerprintsJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
        return nil
    }
    do {
        let object = try JSONSerialization.jsonObject(with: Data(targetFingerprintsJSON.utf8))
        let value = try TKJSONValue.fromJSONObject(object)
        return testRecorderTargetFingerprintCandidates(from: value)
    } catch {
        throw testRecorderValidationFailure(
            code: "invalid_json",
            message: "Could not decode --target-fingerprints-json: \(error)",
            path: "--target-fingerprints-json",
            hint: "Pass a target fingerprint object, an array of objects, or {\"pages\":[...]}."
        )
    }
}

func testRecorderTargetFingerprintCandidates(from value: TKJSONValue?) -> [TKJSONValue]? {
    guard let value else { return nil }
    switch value {
    case let .array(values):
        return values
    case let .object(object):
        if case let .array(pages)? = object["pages"] {
            return pages
        }
        return [value]
    default:
        return nil
    }
}

func validateTestRecorderReplayExecutor(_ executor: String?) throws -> String {
    guard let executor, !executor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testRecorderValidationFailure(
            code: "dry_run_required",
            message: "testrec replay execution requires --dry-run or --executor local-simulated.",
            path: "--dry-run",
            hint: "Use --dry-run for planning, or --executor local-simulated for the offline executor contract."
        )
    }
    guard executor == testRecorderLocalSimulatedExecutor else {
        throw testRecorderValidationFailure(
            code: "unsupported_replay_executor",
            message: "Unsupported testrec replay executor '\(executor)'.",
            path: "--executor",
            hint: "Use --executor local-simulated. A real local-device executor still requires live-target-device, device-action-execution, evidence-artifact-capture, and network-policy-application support."
        )
    }
    return executor
}

private struct TKTestRecorderReplayEvidenceEvent: Codable, Equatable {
    let schemaVersion: Int
    let event: String
    let runID: String
    let timestamp: String
    let contractRef: TKTestRecorderReplayContractRef?
    let category: String
    let subjectID: String?
    let index: Int?
    let status: String
    let action: String?
    let pageId: String?
    let route: String?
    let networkID: String?
    let strategy: String?
    let artifactRefs: [String]?
    let failureCode: String?
    let evidence: [String]
}

private func replayNetworkResults(casePath: String) throws -> [TKTestRecorderReplayNetworkResult] {
    let mapURL = URL(fileURLWithPath: casePath, isDirectory: true).appendingPathComponent("network/map-rules.json")
    guard FileManager.default.fileExists(atPath: mapURL.path) else {
        return []
    }
    let map = try JSONDecoder().decode(TKTestRecorderNetworkMap.self, from: Data(contentsOf: mapURL))
    return map.rules.map { rule in
        TKTestRecorderReplayNetworkResult(
            index: rule.index,
            id: rule.id,
            status: "simulated-\(rule.strategy)",
            strategy: rule.strategy,
            sourcePath: rule.sourcePath,
            method: rule.match.method,
            url: rule.match.url,
            nonBlocking: rule.nonBlocking,
            redactionRequired: rule.redactionRequired,
            fixturePath: rule.fixturePath,
            artifactRefs: rule.fixturePath.map { [$0] } ?? [],
            evidence: [
                "network-map",
                rule.strategy,
                rule.fixturePath == nil ? "network-fixture:not-present" : "network-fixture",
                rule.nonBlocking ? "non-blocking" : "blocking-policy",
                rule.redactionRequired ? "redaction-required" : "redaction-not-required",
            ]
        )
    }
}

private func replayPageMatches(plan: TKTestRecorderReplayDryRunResponse, targetFingerprints: [TKJSONValue]?) throws -> [Int: TKTestRecorderFingerprintMatchResponse] {
    guard let targetFingerprints, !targetFingerprints.isEmpty else {
        return [:]
    }
    var matches: [Int: TKTestRecorderFingerprintMatchResponse] = [:]
    for check in plan.pageChecks {
        let selector = check.pageId ?? check.route ?? String(check.index)
        let scored = try targetFingerprints.map {
            try matchTritonTestCasePageFingerprint(path: plan.path, page: selector, candidate: $0)
        }
        if let best = scored.max(by: { $0.score < $1.score }) {
            matches[check.index] = best
        }
    }
    return matches
}

private func replayPageMatchBlockers(_ matches: [Int: TKTestRecorderFingerprintMatchResponse]) -> [TKTestRecorderReplayBlocker] {
    matches.values.compactMap { match in
        switch match.decision {
        case "matched", "assisted-matched":
            return nil
        case "needs-review":
            return TKTestRecorderReplayBlocker(
                code: "page_needs_review",
                path: "compiled-contract.json.pages.fingerprints",
                message: "Target page fingerprint for '\(match.page)' needs review before replay actions execute."
            )
        default:
            return TKTestRecorderReplayBlocker(
                code: "page_not_matched",
                path: "compiled-contract.json.pages.fingerprints",
                message: "Target page fingerprint for '\(match.page)' did not match the compiled page contract."
            )
        }
    }
}

private func writeTestRecorderReplayEvidence(response: TKTestRecorderReplayRunResponse, evidenceDirectory: String) throws {
    let evidenceURL = URL(fileURLWithPath: evidenceDirectory, isDirectory: true)
    let runURL = evidenceURL.appendingPathComponent("run", isDirectory: true)
    try FileManager.default.createDirectory(at: runURL, withIntermediateDirectories: true)

    let runID = "testrec-replay-\(UUID().uuidString.lowercased())"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let run = TKTestRunMetadata(
        kind: "triton.testrec.replay",
        runID: runID,
        source: response.path,
        status: response.ok ? .passed : .blocked,
        startedAt: timestamp,
        endedAt: timestamp,
        durationMs: 0,
        planRef: "replay-result.json"
    )

    var events: [TKTestRecorderReplayEvidenceEvent] = [
        TKTestRecorderReplayEvidenceEvent(
            schemaVersion: 1,
            event: "testrec.replay.started",
            runID: runID,
            timestamp: timestamp,
            contractRef: response.contractRef,
            category: "run",
            subjectID: runID,
            index: nil,
            status: "started",
            action: nil,
            pageId: nil,
            route: nil,
            networkID: nil,
            strategy: nil,
            artifactRefs: nil,
            failureCode: nil,
            evidence: ["local-simulated", "compiled-contract"]
        ),
    ]
    events.append(contentsOf: response.pageResults.map { page in
        TKTestRecorderReplayEvidenceEvent(
            schemaVersion: 1,
            event: "testrec.replay.page",
            runID: runID,
            timestamp: timestamp,
            contractRef: response.contractRef,
            category: "page",
            subjectID: page.pageId ?? page.route ?? "page-(page.index)",
            index: page.index,
            status: page.status,
            action: nil,
            pageId: page.pageId,
            route: page.route,
            networkID: nil,
            strategy: nil,
            artifactRefs: nil,
            failureCode: nil,
            evidence: page.evidence
        )
    })
    events.append(contentsOf: response.networkResults.map { network in
        TKTestRecorderReplayEvidenceEvent(
            schemaVersion: 1,
            event: "testrec.replay.network",
            runID: runID,
            timestamp: timestamp,
            contractRef: response.contractRef,
            category: "network",
            subjectID: network.id,
            index: network.index,
            status: network.status,
            action: nil,
            pageId: nil,
            route: nil,
            networkID: network.id,
            strategy: network.strategy,
            artifactRefs: network.artifactRefs,
            failureCode: nil,
            evidence: network.evidence
        )
    })
    events.append(contentsOf: response.steps.map { step in
        TKTestRecorderReplayEvidenceEvent(
            schemaVersion: 1,
            event: "testrec.replay.step",
            runID: runID,
            timestamp: timestamp,
            contractRef: response.contractRef,
            category: "step",
            subjectID: step.sourceEventID ?? "step-(step.index)",
            index: step.index,
            status: step.status,
            action: step.action,
            pageId: nil,
            route: nil,
            networkID: nil,
            strategy: nil,
            artifactRefs: step.artifactRefs,
            failureCode: step.failure?.code,
            evidence: step.evidence
        )
    })
    events.append(TKTestRecorderReplayEvidenceEvent(
        schemaVersion: 1,
        event: "testrec.replay.finished",
        runID: runID,
        timestamp: timestamp,
        contractRef: response.contractRef,
        category: "run",
        subjectID: runID,
        index: nil,
        status: response.status,
        action: nil,
        pageId: nil,
        route: nil,
        networkID: nil,
        strategy: nil,
        artifactRefs: nil,
        failureCode: nil,
        evidence: response.ok ? ["passed"] : response.blockers.map(\.code)
    ))

    let resultData = try prettyEncodedData(response)
    let runData = try prettyEncodedData(run)
    let eventLines = try events.map { try encodeCompactJSON($0) }.joined(separator: "\n") + "\n"
    let eventData = Data(eventLines.utf8)

    try resultData.write(to: runURL.appendingPathComponent("replay-result.json"), options: .atomic)
    try runData.write(to: runURL.appendingPathComponent("run.json"), options: .atomic)
    try eventData.write(to: runURL.appendingPathComponent("events.jsonl"), options: Data.WritingOptions.atomic)

    let contractMetadata = testRecorderContractRefMetadata(response.contractRef)
    let artifacts = [
        TKEvidenceArtifact(kind: "testrec.replay.result", path: "run/replay-result.json", contentType: "application/json", bytes: resultData.count, metadata: contractMetadata),
        TKEvidenceArtifact(kind: "testrec.replay.events", path: "run/events.jsonl", contentType: "application/jsonl", bytes: eventData.count, metadata: contractMetadata),
        TKEvidenceArtifact(kind: "testrec.replay.run", path: "run/run.json", contentType: "application/json", bytes: runData.count, metadata: contractMetadata),
    ]
    let manifest = TKEvidenceManifest(
        ok: response.ok,
        name: "triton-testrec-replay",
        note: "local-simulated executor; no device commands executed",
        createdAt: timestamp,
        output: evidenceURL.path,
        artifacts: artifacts,
        cli: TKEvidenceCLI(version: TritonKitBuildInfo.cliVersion),
        run: TKEvidenceRunManifest(
            eventsPath: "run/events.jsonl",
            metaPath: "run/run.json",
            eventCount: events.count,
            observationCount: 0,
            status: .completed
        )
    )
    try prettyEncodedData(manifest).write(to: evidenceURL.appendingPathComponent("manifest.json"), options: .atomic)
}

private func testRecorderContractRefMetadata(_ contractRef: TKTestRecorderReplayContractRef?) -> [String: TKJSONValue]? {
    guard let contractRef else { return nil }
    return [
        "contractRef": .object([
            "path": .string(contractRef.path),
            "byteCount": .int(contractRef.byteCount),
            "digestAlgorithm": .string(contractRef.digestAlgorithm),
            "digest": .string(contractRef.digest),
        ]),
    ]
}
