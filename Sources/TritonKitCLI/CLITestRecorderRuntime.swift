import Foundation
import TritonKitShared

private let supportedTestRecorderActions: Set<String> = [
    "tap", "type", "paste", "scroll", "swipe", "wait", "assert", "open-url", "screenshot", "evidence",
]

private let supportedTestRecorderPages: Set<String> = [
    "route", "ax", "dom", "semantic", "fingerprint", "screenshot", "webview-url",
]

private let supportedTestRecorderNetwork: Set<String> = [
    "fixture", "passthrough", "mock", "block", "throttle", "map-local", "map-remote",
]

private struct TKTestRecorderSessionRecord: Codable, Equatable {
    let schemaVersion: Int
    let sessionId: String
    let casePath: String
    let status: String
    let eventCount: Int
}

func startTritonTestRecorderSession(caseName: String, sourcePlatform: String, outputPath: String, sessionStoreRoot: URL? = nil) throws -> TKTestRecorderSessionStartResponse {
    let caseURL = URL(fileURLWithPath: outputPath)
    let manifest = TKTestRecorderManifest(
        schemaVersion: 1,
        kind: "triton.testcase.v1",
        name: caseName,
        sourcePlatform: sourcePlatform,
        tritonKitVersion: TritonKitBuildInfo.cliVersion,
        capabilitiesRef: "contract-capabilities.json"
    )
    let capabilities = TKTestRecorderContractCapabilities(
        schemaVersion: 1,
        actions: ["tap", "type", "paste", "scroll", "swipe", "wait", "assert"],
        pages: ["route", "ax", "fingerprint", "screenshot"],
        network: ["fixture", "passthrough", "mock", "block", "throttle"]
    )
    try FileManager.default.createDirectory(at: caseURL, withIntermediateDirectories: true)
    try writeTestRecorderJSON(manifest, to: caseURL.appendingPathComponent("manifest.json"))
    try writeTestRecorderJSON(capabilities, to: caseURL.appendingPathComponent("contract-capabilities.json"))

    let sessionId = "testrec-" + UUID().uuidString.lowercased()
    let record = TKTestRecorderSessionRecord(
        schemaVersion: 1,
        sessionId: sessionId,
        casePath: caseURL.path,
        status: "recording",
        eventCount: 0
    )
    try writeTestRecorderSessionRecord(record, storeRoot: sessionStoreRoot)
    return TKTestRecorderSessionStartResponse(
        sessionId: sessionId,
        casePath: caseURL.path,
        manifest: manifest,
        capabilities: capabilities
    )
}

func appendTritonTestRecorderEvent(sessionID: String, eventKind: String, payloadJSON: String, sessionStoreRoot: URL? = nil) throws -> TKTestRecorderEventResponse {
    let record = try readTestRecorderSessionRecord(sessionID: sessionID, storeRoot: sessionStoreRoot)
    guard record.status == "recording" else {
        throw testRecorderValidationFailure(
            code: "session_not_recording",
            message: "Test recorder session is not recording.",
            path: "--session",
            hint: "Start a new session with triton testrec start."
        )
    }
    let eventPath = try testRecorderEventPath(for: eventKind)
    let payloadData = Data(payloadJSON.utf8)
    let object: Any
    do {
        object = try JSONSerialization.jsonObject(with: payloadData)
    } catch {
        throw testRecorderValidationFailure(
            code: "invalid_json",
            message: "Could not decode --payload-json: \(error)",
            path: "--payload-json",
            hint: "Pass a valid JSON object for the recorded event."
        )
    }
    guard JSONSerialization.isValidJSONObject(object), object is [String: Any] else {
        throw testRecorderValidationFailure(
            code: "invalid_json",
            message: "--payload-json must be a JSON object.",
            path: "--payload-json",
            hint: "Pass a single event object such as {\"kind\":\"tap\"}."
        )
    }

    let caseURL = URL(fileURLWithPath: record.casePath, isDirectory: true)
    let outputURL = caseURL.appendingPathComponent(eventPath)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let canonicalData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    let line = String(data: canonicalData, encoding: .utf8) ?? payloadJSON
    if FileManager.default.fileExists(atPath: outputURL.path) {
        let handle = try FileHandle(forWritingTo: outputURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((line + "\n").utf8))
    } else {
        try (line + "\n").write(to: outputURL, atomically: true, encoding: .utf8)
    }

    let updated = TKTestRecorderSessionRecord(
        schemaVersion: record.schemaVersion,
        sessionId: record.sessionId,
        casePath: record.casePath,
        status: record.status,
        eventCount: record.eventCount + 1
    )
    try writeTestRecorderSessionRecord(updated, storeRoot: sessionStoreRoot)
    return TKTestRecorderEventResponse(
        sessionId: updated.sessionId,
        casePath: updated.casePath,
        eventKind: eventKind,
        eventPath: eventPath,
        eventCount: updated.eventCount
    )
}

func stopTritonTestRecorderSession(sessionID: String, sessionStoreRoot: URL? = nil) throws -> TKTestRecorderSessionStopResponse {
    let record = try readTestRecorderSessionRecord(sessionID: sessionID, storeRoot: sessionStoreRoot)
    let stopped = TKTestRecorderSessionRecord(
        schemaVersion: record.schemaVersion,
        sessionId: record.sessionId,
        casePath: record.casePath,
        status: "stopped",
        eventCount: record.eventCount
    )
    try writeTestRecorderSessionRecord(stopped, storeRoot: sessionStoreRoot)
    let caseURL = URL(fileURLWithPath: record.casePath, isDirectory: true)
    let artifacts = testRecorderArtifacts(in: caseURL, fileManager: FileManager.default)
    return TKTestRecorderSessionStopResponse(
        sessionId: record.sessionId,
        casePath: record.casePath,
        eventCount: record.eventCount,
        artifacts: artifacts
    )
}

func handleTestRecorderHTTPSessionCreate(body: Data, sessionStoreRoot: URL? = nil) throws -> TKTestRecorderSessionStartResponse {
    let request = try decodeTestRecorderHTTPJSON(
        TKTestRecorderHTTPSessionCreateRequest.self,
        from: body,
        endpoint: "/v1/test-recorder/sessions"
    )
    guard !request.platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !request.caseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !request.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Test recorder session create payload requires platform, caseName, and output.",
            path: "$",
            hint: "Send JSON like {\"platform\":\"ios\",\"caseName\":\"login\",\"output\":\"/tmp/login.tritontestcase\"}."
        )
    }
    return try startTritonTestRecorderSession(
        caseName: request.caseName,
        sourcePlatform: request.platform,
        outputPath: request.output,
        sessionStoreRoot: sessionStoreRoot
    )
}

func handleTestRecorderHTTPEvent(sessionID: String, body: Data, sessionStoreRoot: URL? = nil) throws -> TKTestRecorderEventResponse {
    let request = try decodeTestRecorderHTTPJSON(
        TKTestRecorderHTTPEventRequest.self,
        from: body,
        endpoint: "/v1/test-recorder/sessions/{sessionId}/events"
    )
    let payloadData = try JSONEncoder.sortedTestRecorder.encode(request.payload)
    let payloadJSON = String(data: payloadData, encoding: .utf8) ?? "{}"
    return try appendTritonTestRecorderEvent(
        sessionID: sessionID,
        eventKind: request.kind,
        payloadJSON: payloadJSON,
        sessionStoreRoot: sessionStoreRoot
    )
}

func handleTestRecorderHTTPSessionStop(sessionID: String, sessionStoreRoot: URL? = nil) throws -> TKTestRecorderSessionStopResponse {
    try stopTritonTestRecorderSession(sessionID: sessionID, sessionStoreRoot: sessionStoreRoot)
}

func handleTestRecorderHTTPInspect(body: Data) throws -> TKTestRecorderInspectResponse {
    let request = try decodeTestRecorderHTTPJSON(
        TKTestRecorderHTTPCasePathRequest.self,
        from: body,
        endpoint: "/v1/test-recorder/cases/inspect"
    )
    guard !request.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Test recorder inspect payload requires path.",
            path: "$.path",
            hint: "Send JSON like {\"path\":\"/tmp/login.tritontestcase\"}."
        )
    }
    return try inspectTritonTestCase(path: request.path)
}

func handleTestRecorderHTTPCompile(body: Data) throws -> TKTestRecorderCompileResponse {
    let request = try decodeTestRecorderHTTPJSON(
        TKTestRecorderHTTPCompileRequest.self,
        from: body,
        endpoint: "/v1/test-recorder/cases/compile"
    )
    guard !request.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Test recorder compile payload requires path.",
            path: "$.path",
            hint: "Send JSON like {\"path\":\"/tmp/login.tritontestcase\"}; output is optional."
        )
    }
    return try compileTritonTestCase(path: request.path, writeContract: true, outputPath: request.output)
}

func handleTestRecorderHTTPProposals(body: Data) throws -> TKTestRecorderProposalsResponse {
    let request = try decodeTestRecorderHTTPJSON(
        TKTestRecorderHTTPCasePathRequest.self,
        from: body,
        endpoint: "/v1/test-recorder/cases/proposals"
    )
    guard !request.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Test recorder proposals payload requires path.",
            path: "$.path",
            hint: "Send JSON like {\"path\":\"/tmp/login.tritontestcase\"}."
        )
    }
    return try inspectTritonTestCaseProposals(path: request.path)
}

func handleTestRecorderHTTPReplayDryRun(body: Data) throws -> TKTestRecorderReplayDryRunResponse {
    let request = try decodeTestRecorderHTTPJSON(
        TKTestRecorderHTTPReplayRequest.self,
        from: body,
        endpoint: "/v1/test-recorder/cases/replay-dry-run"
    )
    guard !request.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !request.platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Test recorder replay dry-run payload requires path and platform.",
            path: "$",
            hint: "Send JSON like {\"path\":\"/tmp/login.tritontestcase\",\"platform\":\"android\",\"dryRun\":true}."
        )
    }
    guard request.dryRun ?? true else {
        throw testRecorderValidationFailure(
            code: "dry_run_required",
            message: "HTTP replay execution is not implemented yet; dryRun must be true.",
            path: "$.dryRun",
            hint: "Send dryRun=true or omit dryRun to generate a replay plan."
        )
    }
    return try replayTritonTestCaseDryRun(path: request.path, platform: request.platform, device: request.device)
}

func handleTestRecorderHTTPReplay(body: Data) throws -> TKTestRecorderReplayRunResponse {
    let request = try decodeTestRecorderHTTPJSON(
        TKTestRecorderHTTPReplayRequest.self,
        from: body,
        endpoint: "/v1/test-recorder/cases/replay"
    )
    guard !request.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !request.platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Test recorder replay payload requires path and platform.",
            path: "$",
            hint: "Send JSON like {\"path\":\"/tmp/login.tritontestcase\",\"platform\":\"android\",\"executor\":\"local-simulated\"}."
        )
    }
    if request.dryRun == true {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Use /v1/test-recorder/cases/replay-dry-run for dry-run planning.",
            path: "$.dryRun",
            hint: "Send dryRun=false or omit dryRun when using /v1/test-recorder/cases/replay."
        )
    }
    _ = try validateTestRecorderReplayExecutor(request.executor)
    return try replayTritonTestCaseLocalSimulated(
        path: request.path,
        platform: request.platform,
        device: request.device,
        evidenceDirectory: request.evidenceDir,
        targetFingerprints: testRecorderTargetFingerprintCandidates(from: request.targetFingerprints)
    )
}

func inspectTritonTestCase(path: String) throws -> TKTestRecorderInspectResponse {
    let fileManager = FileManager.default
    let caseURL = URL(fileURLWithPath: path)
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: caseURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw testRecorderValidationFailure(
            code: "invalid_case_directory",
            message: "Expected a .tritontestcase directory.",
            path: "$",
            hint: "Create a directory package ending in .tritontestcase."
        )
    }

    let manifestURL = caseURL.appendingPathComponent("manifest.json")
    let capabilitiesURL = caseURL.appendingPathComponent("contract-capabilities.json")
    guard fileManager.fileExists(atPath: manifestURL.path) else {
        throw testRecorderValidationFailure(
            code: "missing_required_file",
            message: "Missing manifest.json.",
            path: "manifest.json",
            hint: "Add manifest.json to the .tritontestcase package."
        )
    }
    guard fileManager.fileExists(atPath: capabilitiesURL.path) else {
        throw testRecorderValidationFailure(
            code: "missing_required_file",
            message: "Missing contract-capabilities.json.",
            path: "contract-capabilities.json",
            hint: "Add contract-capabilities.json with actions/pages/network capability arrays."
        )
    }

    let manifest: TKTestRecorderManifest = try decodeTestRecorderJSON(
        TKTestRecorderManifest.self,
        from: manifestURL,
        path: "manifest.json"
    )
    let capabilities: TKTestRecorderContractCapabilities = try decodeTestRecorderJSON(
        TKTestRecorderContractCapabilities.self,
        from: capabilitiesURL,
        path: "contract-capabilities.json"
    )

    guard manifest.schemaVersion == 1 else {
        throw testRecorderValidationFailure(
            code: "unsupported_schema_version",
            message: "Unsupported manifest schemaVersion \(manifest.schemaVersion).",
            path: "manifest.json.schemaVersion",
            hint: "Use schemaVersion 1."
        )
    }
    guard capabilities.schemaVersion == 1 else {
        throw testRecorderValidationFailure(
            code: "unsupported_schema_version",
            message: "Unsupported contract-capabilities schemaVersion \(capabilities.schemaVersion).",
            path: "contract-capabilities.json.schemaVersion",
            hint: "Use schemaVersion 1."
        )
    }

    let unsupported = unsupportedCapabilities(in: capabilities)
    let artifacts = testRecorderArtifacts(in: caseURL, fileManager: fileManager)
    return TKTestRecorderInspectResponse(
        path: caseURL.path,
        manifest: manifest,
        capabilities: capabilities,
        unsupportedCapabilities: unsupported,
        artifacts: artifacts
    )
}

func compileTritonTestCase(path: String, writeContract: Bool = false, outputPath: String? = nil) throws -> TKTestRecorderCompileResponse {
    let inspect = try inspectTritonTestCase(path: path)
    let caseURL = URL(fileURLWithPath: inspect.path)
    let summary = TKTestRecorderCompileSummary(
        actionEventCount: countJSONLines(at: caseURL.appendingPathComponent("actions.jsonl")),
        networkEventCount: countJSONLines(at: caseURL.appendingPathComponent("network/capture.ndjson")),
        pageRouteEventCount: countJSONLines(at: caseURL.appendingPathComponent("pages/route-events.jsonl")),
        pageFingerprintCount: countJSONLines(at: caseURL.appendingPathComponent("pages/fingerprints.jsonl"))
    )
    let qualityFindings = try compileQualityFindings(caseURL: caseURL)
    let warnings = compileWarnings(inspect: inspect, summary: summary, qualityFindings: qualityFindings)
    let status = compileStatus(summary: summary, warnings: warnings)
    let compiledContract = try status == "compiled"
        ? buildCompiledContract(inspect: inspect, summary: summary, warnings: warnings, qualityFindings: qualityFindings)
        : nil
    let contractArtifact = try writeContract
        ? writeCompiledContractIfReady(compiledContract, caseURL: caseURL, outputPath: outputPath)
        : nil
    let actionMapArtifact = try writeContract
        ? writeActionMapIfReady(compiledContract, caseURL: caseURL)
        : nil
    let networkMapArtifact = try writeContract
        ? writeNetworkMapIfReady(compiledContract, caseURL: caseURL)
        : nil
    let pageMapArtifact = try writeContract
        ? writePageMapIfReady(compiledContract, caseURL: caseURL)
        : nil
    let proposalArtifact = try writeContract
        ? writeCompileProposalsIfNeeded(qualityFindings: qualityFindings, caseURL: caseURL)
        : nil
    return TKTestRecorderCompileResponse(
        path: inspect.path,
        inspect: inspect,
        summary: summary,
        warnings: warnings,
        compiledContract: compiledContract,
        contractArtifact: contractArtifact,
        actionMapArtifact: actionMapArtifact,
        networkMapArtifact: networkMapArtifact,
        pageMapArtifact: pageMapArtifact,
        proposalArtifact: proposalArtifact
    )
}

func inspectTritonTestCaseProposals(path: String) throws -> TKTestRecorderProposalsResponse {
    let inspect = try inspectTritonTestCase(path: path)
    let caseURL = URL(fileURLWithPath: inspect.path)
    let proposals = try readCompileProposals(from: caseURL.appendingPathComponent("compile-proposals.jsonl"))
    return TKTestRecorderProposalsResponse(path: inspect.path, proposals: proposals)
}

func replayTritonTestCase(path: String, platform: String, device: String?, dryRun: Bool) throws -> TKTestRecorderReplayDryRunResponse {
    guard dryRun else {
        throw testRecorderValidationFailure(
            code: "dry_run_required",
            message: "testrec replay execution is not implemented yet; pass --dry-run to produce a replay plan.",
            path: "--dry-run",
            hint: "Use triton testrec replay <case.tritontestcase> --platform <platform> --dry-run --json."
        )
    }
    return try replayTritonTestCaseDryRun(path: path, platform: platform, device: device)
}

func replayTritonTestCaseDryRun(path: String, platform: String, device: String?) throws -> TKTestRecorderReplayDryRunResponse {
    let inspect = try inspectTritonTestCase(path: path)
    let caseURL = URL(fileURLWithPath: inspect.path)
    let compiled = try readCompiledContractForReplay(caseURL: caseURL)
    let contractRef = try testRecorderCompiledContractRef(caseURL: caseURL)
    let compile = try compileResponseForReplay(path: inspect.path, inspect: inspect, compiled: compiled)
    let plannedSteps = compiled.map {
        readReplayPlannedSteps(from: $0.contract, platform: platform, device: device)
    } ?? []
    let pageChecks = compiled.map {
        readReplayPageChecks(from: $0.contract, casePath: inspect.path)
    } ?? []
    var blockers = compiled == nil
        ? replayBlockersForMissingCompiledContract(compile: compile)
        : replayBlockers(compile: compile, plannedSteps: plannedSteps)
    if platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        blockers.append(TKTestRecorderReplayBlocker(
            code: "missing_platform",
            path: "--platform",
            message: "Replay dry-run requires an explicit target platform."
        ))
    }
    return TKTestRecorderReplayDryRunResponse(
        path: compile.path,
        platform: platform,
        device: device,
        compile: compile,
        contractRef: contractRef,
        pageChecks: blockers.contains(where: { $0.code == "missing_compiled_contract" }) ? [] : pageChecks,
        plannedSteps: blockers.contains(where: { $0.code == "missing_actions" }) ? [] : plannedSteps,
        blockers: blockers
    )
}

private func decodeTestRecorderJSON<T: Decodable>(_ type: T.Type, from url: URL, path: String) throws -> T {
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    } catch {
        throw testRecorderValidationFailure(
            code: "invalid_json",
            message: "Could not decode \(path): \(error)",
            path: path,
            hint: "Verify the file is valid JSON matching the .tritontestcase v1 schema."
        )
    }
}

private func writeTestRecorderJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let data = try JSONEncoder.prettySortedTestRecorder.encode(value)
    try data.write(to: url, options: .atomic)
}

private extension JSONEncoder {
    static var prettySortedTestRecorder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static var sortedTestRecorder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

func decodeTestRecorderHTTPJSON<T: Decodable>(_ type: T.Type, from data: Data, endpoint: String) throws -> T {
    do {
        return try JSONDecoder().decode(type, from: data)
    } catch {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Could not decode HTTP request body: \(error)",
            path: "$",
            hint: "Check the JSON body for endpoint \(endpoint)."
        )
    }
}

private func testRecorderSessionStoreRoot(_ override: URL?) throws -> URL {
    if let override {
        return override
    }
    if let env = ProcessInfo.processInfo.environment["TRITONKIT_TESTREC_SESSION_DIR"], !env.isEmpty {
        return URL(fileURLWithPath: env, isDirectory: true)
    }
    if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        return appSupport
            .appendingPathComponent("TritonKit", isDirectory: true)
            .appendingPathComponent("testrec-sessions", isDirectory: true)
    }
    return FileManager.default.temporaryDirectory
        .appendingPathComponent("tritonkit-testrec-sessions", isDirectory: true)
}

private func testRecorderSessionURL(sessionID: String, storeRoot: URL?) throws -> URL {
    guard sessionID.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
        throw testRecorderValidationFailure(
            code: "invalid_session_id",
            message: "Invalid test recorder session id.",
            path: "--session",
            hint: "Use the sessionId returned by triton testrec start."
        )
    }
    return try testRecorderSessionStoreRoot(storeRoot).appendingPathComponent("\(sessionID).json")
}

private func writeTestRecorderSessionRecord(_ record: TKTestRecorderSessionRecord, storeRoot: URL?) throws {
    let url = try testRecorderSessionURL(sessionID: record.sessionId, storeRoot: storeRoot)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try writeTestRecorderJSON(record, to: url)
}

private func readTestRecorderSessionRecord(sessionID: String, storeRoot: URL?) throws -> TKTestRecorderSessionRecord {
    let url = try testRecorderSessionURL(sessionID: sessionID, storeRoot: storeRoot)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw testRecorderValidationFailure(
            code: "session_not_found",
            message: "Test recorder session was not found.",
            path: "--session",
            hint: "Use the sessionId returned by triton testrec start."
        )
    }
    return try decodeTestRecorderJSON(TKTestRecorderSessionRecord.self, from: url, path: "--session")
}

private func testRecorderEventPath(for eventKind: String) throws -> String {
    switch eventKind {
    case "action":
        return "actions.jsonl"
    case "network":
        return "network/capture.ndjson"
    case "page-route":
        return "pages/route-events.jsonl"
    case "page-fingerprint":
        return "pages/fingerprints.jsonl"
    case "page-snapshot":
        return "pages/snapshots.jsonl"
    default:
        throw testRecorderValidationFailure(
            code: "unsupported_event_kind",
            message: "Unsupported test recorder event kind '\(eventKind)'.",
            path: "--kind",
            hint: "Use action, network, page-route, page-fingerprint, or page-snapshot."
        )
    }
}

private func unsupportedCapabilities(in capabilities: TKTestRecorderContractCapabilities) -> [TKTestRecorderUnsupportedCapability] {
    var unsupported: [TKTestRecorderUnsupportedCapability] = []
    unsupported.append(contentsOf: capabilities.actions
        .filter { !supportedTestRecorderActions.contains($0) }
        .map { TKTestRecorderUnsupportedCapability(domain: "actions", name: $0) })
    unsupported.append(contentsOf: capabilities.pages
        .filter { !supportedTestRecorderPages.contains($0) }
        .map { TKTestRecorderUnsupportedCapability(domain: "pages", name: $0) })
    unsupported.append(contentsOf: capabilities.network
        .filter { !supportedTestRecorderNetwork.contains($0) }
        .map { TKTestRecorderUnsupportedCapability(domain: "network", name: $0) })
    return unsupported
}

private func testRecorderArtifacts(in caseURL: URL, fileManager: FileManager) -> [TKTestRecorderArtifact] {
    let known: [(kind: String, path: String, required: Bool)] = [
        ("manifest", "manifest.json", true),
        ("contract-capabilities", "contract-capabilities.json", true),
        ("actions", "actions.jsonl", false),
        ("action-map", "actions/action-map.json", false),
        ("assertions", "assertions.json", false),
        ("network-capture", "network/capture.ndjson", false),
        ("network-map", "network/map-rules.json", false),
        ("page-map", "pages/page-map.json", false),
        ("compiled-contract", "compiled-contract.json", false),
        ("compile-proposals", "compile-proposals.jsonl", false),
        ("page-fingerprints", "pages/fingerprints.jsonl", false),
        ("page-route-events", "pages/route-events.jsonl", false),
        ("page-snapshots", "pages/snapshots.jsonl", false),
    ]
    return known.map { item in
        let artifactURL = caseURL.appendingPathComponent(item.path)
        guard fileManager.fileExists(atPath: artifactURL.path),
              let data = try? Data(contentsOf: artifactURL)
        else {
            return TKTestRecorderArtifact(
                kind: item.kind,
                path: item.path,
                required: item.required,
                present: false,
                byteCount: nil,
                digestAlgorithm: nil,
                digest: nil
            )
        }
        return TKTestRecorderArtifact(
            kind: item.kind,
            path: item.path,
            required: item.required,
            present: true,
            byteCount: data.count,
            digestAlgorithm: "fnv1a64",
            digest: fnv1a64Hex(data)
        )
    }
}

func testRecorderLifecycle(artifacts: [TKTestRecorderArtifact]) -> TKTestRecorderLifecycle {
    let hasCompiledContract = artifacts.contains { $0.kind == "compiled-contract" && $0.present }
    let hasCompileProposals = artifacts.contains { $0.kind == "compile-proposals" && $0.present }
    let stage: String
    let health: String
    if hasCompiledContract && hasCompileProposals {
        stage = "proposed"
        health = "review-proposals"
    } else if hasCompiledContract {
        stage = "compiled"
        health = "ready"
    } else {
        stage = "raw"
        health = "needs-compile"
    }
    return TKTestRecorderLifecycle(
        stage: stage,
        health: health,
        hasCompiledContract: hasCompiledContract,
        hasCompileProposals: hasCompileProposals
    )
}

private func countJSONLines(at url: URL) -> Int {
    guard let data = try? Data(contentsOf: url),
          let content = String(data: data, encoding: .utf8)
    else {
        return 0
    }
    return content
        .split(whereSeparator: { $0.isNewline })
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .count
}

private func readReplayPlannedSteps(from url: URL, platform: String, device: String?) throws -> [TKTestRecorderReplayPlannedStep] {
    guard let data = try? Data(contentsOf: url),
          let content = String(data: data, encoding: .utf8)
    else {
        return []
    }
    var steps: [TKTestRecorderReplayPlannedStep] = []
    for (offset, rawLine) in content.split(whereSeparator: { $0.isNewline }).enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { continue }
        let object = try decodeTestRecorderJSONObject(line, path: "actions.jsonl:\(offset + 1)")
        let action = object["kind"] as? String ?? object["type"] as? String ?? object["action"] as? String ?? "unknown"
        let eventID = object["id"] as? String
        let supported = supportedTestRecorderActions.contains(action)
        let command = replayCommandMapping(action: action, object: object, platform: platform, device: device)
        steps.append(TKTestRecorderReplayPlannedStep(
            index: steps.count + 1,
            sourceEventID: eventID,
            action: action,
            status: supported ? "planned" : "unsupported",
            sourcePath: "actions.jsonl:\(offset + 1)",
            command: command.command,
            argv: command.argv,
            workflowCategories: command.workflowCategories,
            expectedArtifacts: command.expectedArtifacts,
            stopConditions: command.stopConditions
        ))
    }
    return steps
}

private func readReplayPlannedSteps(from contract: TKTestRecorderCompiledContract, platform: String, device: String?) -> [TKTestRecorderReplayPlannedStep] {
    contract.actions.enumerated().map { offset, action in
        var object: [String: Any] = [
            "kind": action.action,
        ]
        if let targetText = action.targetText, !targetText.isEmpty {
            object["target"] = ["label": targetText]
        }
        if let inputText = action.inputText, !inputText.isEmpty {
            object["text"] = inputText
        }
        let supported = supportedTestRecorderActions.contains(action.action)
        let command = replayCommandMapping(action: action.action, object: object, platform: platform, device: device)
        return TKTestRecorderReplayPlannedStep(
            index: offset + 1,
            sourceEventID: action.sourceEventID,
            action: action.action,
            status: supported ? "planned" : "unsupported",
            sourcePath: "compiled-contract.json:actions[\(offset)]",
            command: command.command,
            argv: command.argv,
            workflowCategories: command.workflowCategories,
            expectedArtifacts: command.expectedArtifacts,
            stopConditions: command.stopConditions
        )
    }
}

private func readReplayPageChecks(from contract: TKTestRecorderCompiledContract, casePath: String) -> [TKTestRecorderReplayPageCheck] {
    contract.pages.fingerprints.enumerated().map { offset, fingerprint in
        let selector = fingerprint.pageId ?? fingerprint.route ?? String(fingerprint.index)
        let status = replayPageCheckStatus(fingerprint)
        return TKTestRecorderReplayPageCheck(
            index: offset + 1,
            pageId: fingerprint.pageId,
            route: fingerprint.route,
            status: status,
            sourcePath: "compiled-contract.json:pages.fingerprints[\(offset)]",
            command: "testrec",
            argv: [
                "triton",
                "testrec",
                "match-page",
                casePath,
                "--page",
                selector,
                "--candidate-json",
                "<target-fingerprint-json>",
                "--json",
            ],
            expectedArtifacts: ["page-fingerprint-match"],
            stopConditions: ["page_not_matched", "page_needs_review", "page_match_conflict"]
        )
    }
}

private func replayPageCheckStatus(_ fingerprint: TKTestRecorderCompiledPageFingerprint) -> String {
    if fingerprint.pageId == nil && fingerprint.route == nil {
        return "needs-review"
    }
    if fingerprint.hash == nil {
        return "planned-with-partial-fingerprint"
    }
    return "planned"
}

func readCompiledContractForReplay(caseURL: URL) throws -> (contract: TKTestRecorderCompiledContract, artifact: TKTestRecorderContractArtifact)? {
    let contractURL = caseURL.appendingPathComponent("compiled-contract.json")
    guard FileManager.default.fileExists(atPath: contractURL.path) else {
        return nil
    }
    let contract = try decodeTestRecorderJSON(
        TKTestRecorderCompiledContract.self,
        from: contractURL,
        path: "compiled-contract.json"
    )
    guard contract.schemaVersion == 1 else {
        throw testRecorderValidationFailure(
            code: "unsupported_schema_version",
            message: "Unsupported compiled contract schemaVersion \(contract.schemaVersion).",
            path: "compiled-contract.json.schemaVersion",
            hint: "Run triton testrec compile <case.tritontestcase> --json again."
        )
    }
    guard contract.kind == "triton.testrec.compiled-contract" else {
        throw testRecorderValidationFailure(
            code: "invalid_json",
            message: "Unexpected compiled contract kind '\(contract.kind)'.",
            path: "compiled-contract.json.kind",
            hint: "Run triton testrec compile <case.tritontestcase> --json again."
        )
    }
    let data = try Data(contentsOf: contractURL)
    return (
        contract,
        TKTestRecorderContractArtifact(
            path: "compiled-contract.json",
            absolutePath: contractURL.path,
            contentType: "application/json",
            written: true,
            byteCount: data.count
        )
    )
}

private func compileResponseForReplay(path: String, inspect: TKTestRecorderInspectResponse, compiled: (contract: TKTestRecorderCompiledContract, artifact: TKTestRecorderContractArtifact)?) throws -> TKTestRecorderCompileResponse {
    guard let compiled else {
        return try compileTritonTestCase(path: path, writeContract: false)
    }
    let summary = TKTestRecorderCompileSummary(
        actionEventCount: compiled.contract.actions.count,
        networkEventCount: compiled.contract.network.eventCount,
        pageRouteEventCount: compiled.contract.pages.routeEventCount,
        pageFingerprintCount: compiled.contract.pages.fingerprintCount
    )
    return TKTestRecorderCompileResponse(
        path: path,
        inspect: inspect,
        summary: summary,
        warnings: compiled.contract.warnings,
        compiledContract: compiled.contract,
        contractArtifact: compiled.artifact,
        actionMapArtifact: nil,
        networkMapArtifact: nil,
        pageMapArtifact: nil,
        proposalArtifact: nil
    )
}

private func buildCompiledContract(inspect: TKTestRecorderInspectResponse, summary: TKTestRecorderCompileSummary, warnings: [TKTestRecorderCompileWarning], qualityFindings: [TKTestRecorderQualityFinding]) throws -> TKTestRecorderCompiledContract {
    let caseURL = URL(fileURLWithPath: inspect.path)
    let networkRequests = try readCompiledNetworkRequests(from: caseURL.appendingPathComponent("network/capture.ndjson"))
    let pageRoutes = try readCompiledPageRoutes(from: caseURL.appendingPathComponent("pages/route-events.jsonl"))
    let pageFingerprints = try readCompiledPageFingerprints(from: caseURL.appendingPathComponent("pages/fingerprints.jsonl"))
    return TKTestRecorderCompiledContract(
        schemaVersion: 1,
        kind: "triton.testrec.compiled-contract",
        caseName: inspect.manifest.name,
        sourcePlatform: inspect.manifest.sourcePlatform,
        compiler: TKTestRecorderCompilerInfo(
            mode: "deterministic-offline",
            llmUsed: false,
            vlmUsed: false,
            proposalCount: 0
        ),
        capabilities: inspect.capabilities,
        actions: try readCompiledActions(from: caseURL.appendingPathComponent("actions.jsonl")),
        network: TKTestRecorderCompiledNetwork(
            eventCount: summary.networkEventCount,
            mode: summary.networkEventCount > 0 ? "capture" : "none",
            requests: networkRequests
        ),
        pages: TKTestRecorderCompiledPages(
            routeEventCount: summary.pageRouteEventCount,
            fingerprintCount: summary.pageFingerprintCount,
            matchingEvidence: summary.pageFingerprintCount > 0 ? ["fingerprint"] : [],
            matchPolicy: defaultFingerprintMatchPolicy(),
            routes: pageRoutes,
            fingerprints: pageFingerprints
        ),
        qualityFindings: qualityFindings,
        warnings: warnings
    )
}

private func defaultFingerprintMatchPolicy() -> TKTestRecorderFingerprintMatchPolicy {
    TKTestRecorderFingerprintMatchPolicy(
        scorer: "deterministic-fingerprint-matcher-v1",
        thresholds: TKTestRecorderFingerprintMatchThresholds(
            matched: 0.82,
            assistedMatched: 0.70,
            needsReview: 0.55
        ),
        requiredElementGate: "missing-required-element-caps-at-needs-review",
        conflictPolicy: "surface-ax-dom-route-conflicts-do-not-auto-pass",
        vlmRole: "produce-structured-page-fingerprint",
        llmRole: "explain-boundary-cases-and-propose-aliases-only",
        llmDecisionAuthority: false
    )
}

private func readCompiledActions(from url: URL) throws -> [TKTestRecorderCompiledAction] {
    guard let data = try? Data(contentsOf: url),
          let content = String(data: data, encoding: .utf8)
    else {
        return []
    }
    var actions: [TKTestRecorderCompiledAction] = []
    for (offset, rawLine) in content.split(whereSeparator: { $0.isNewline }).enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { continue }
        let object = try decodeTestRecorderJSONObject(line, path: "actions.jsonl:\(offset + 1)")
        let action = object["kind"] as? String ?? object["type"] as? String ?? object["action"] as? String ?? "unknown"
        actions.append(TKTestRecorderCompiledAction(
            index: actions.count + 1,
            sourceEventID: object["id"] as? String,
            action: action,
            sourcePath: "actions.jsonl:\(offset + 1)",
            targetText: compiledActionTargetText(action: action, object: object),
            inputText: compiledActionInputText(action: action, object: object)
        ))
    }
    return actions
}

private func compiledActionInputText(action: String, object: [String: Any]) -> String? {
    guard action == "type" || action == "paste" else {
        return nil
    }
    let input = replayInputText(from: object)
    return testRecorderLooksSensitive(input) ? nil : input
}

private func readCompiledNetworkRequests(from url: URL) throws -> [TKTestRecorderCompiledNetworkRequest] {
    try readTestRecorderJSONLines(from: url, relativePath: "network/capture.ndjson").map { row in
        TKTestRecorderCompiledNetworkRequest(
            index: row.index,
            sourcePath: row.sourcePath,
            id: stringValue(row.object, "id"),
            method: stringValue(row.object, "method"),
            url: stringValue(row.object, "url"),
            statusCode: intValue(row.object, keys: ["statusCode", "status", "code"]),
            responseBody: stringValue(row.object, "responseBody") ?? stringValue(row.object, "body")
        )
    }
}

private func readCompiledPageRoutes(from url: URL) throws -> [TKTestRecorderCompiledPageRoute] {
    try readTestRecorderJSONLines(from: url, relativePath: "pages/route-events.jsonl").map { row in
        TKTestRecorderCompiledPageRoute(
            index: row.index,
            sourcePath: row.sourcePath,
            id: stringValue(row.object, "id"),
            route: stringValue(row.object, "route"),
            url: stringValue(row.object, "url")
        )
    }
}

private func readCompiledPageFingerprints(from url: URL) throws -> [TKTestRecorderCompiledPageFingerprint] {
    try readTestRecorderJSONLines(from: url, relativePath: "pages/fingerprints.jsonl").map { row in
        let fingerprint = row.object["fingerprint"] as? [String: Any] ?? [:]
        return TKTestRecorderCompiledPageFingerprint(
            index: row.index,
            sourcePath: row.sourcePath,
            pageId: stringValue(row.object, "pageId") ?? stringValue(row.object, "id"),
            route: stringValue(row.object, "route"),
            kind: stringValue(fingerprint, "kind") ?? stringValue(row.object, "kind"),
            hash: stringValue(fingerprint, "hash") ?? stringValue(row.object, "hash")
        )
    }
}

func readTestRecorderJSONLines(from url: URL, relativePath: String) throws -> [(index: Int, sourcePath: String, object: [String: Any])] {
    guard let data = try? Data(contentsOf: url),
          let content = String(data: data, encoding: .utf8)
    else {
        return []
    }
    var rows: [(index: Int, sourcePath: String, object: [String: Any])] = []
    for (offset, rawLine) in content.split(whereSeparator: { $0.isNewline }).enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { continue }
        rows.append((
            index: rows.count + 1,
            sourcePath: "\(relativePath):\(offset + 1)",
            object: try decodeTestRecorderJSONObject(line, path: "\(relativePath):\(offset + 1)")
        ))
    }
    return rows
}

func stringValue(_ object: [String: Any], _ key: String) -> String? {
    if let value = object[key] as? String, !value.isEmpty {
        return value
    }
    if let value = object[key] as? CustomStringConvertible {
        let string = value.description
        return string.isEmpty ? nil : string
    }
    return nil
}

func intValue(_ object: [String: Any], keys: [String]) -> Int? {
    for key in keys {
        if let value = object[key] as? Int {
            return value
        }
        if let value = object[key] as? Double {
            return Int(value)
        }
        if let value = object[key] as? String, let int = Int(value) {
            return int
        }
    }
    return nil
}

private func writeCompiledContractIfReady(_ contract: TKTestRecorderCompiledContract?, caseURL: URL, outputPath: String?) throws -> TKTestRecorderContractArtifact? {
    guard let contract else { return nil }
    let outputURL = compiledContractOutputURL(caseURL: caseURL, outputPath: outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(contract)
    try data.write(to: outputURL, options: .atomic)
    return TKTestRecorderContractArtifact(
        path: compiledContractDisplayPath(outputURL: outputURL, caseURL: caseURL),
        absolutePath: outputURL.path,
        contentType: "application/json",
        written: true,
        byteCount: data.count
    )
}

private func writeNetworkMapIfReady(_ contract: TKTestRecorderCompiledContract?, caseURL: URL) throws -> TKTestRecorderContractArtifact? {
    guard let contract, !contract.network.requests.isEmpty else { return nil }
    let fixturePaths = try writeTestRecorderNetworkFixturesIfNeeded(for: contract.network.requests, caseURL: caseURL)
    let map = buildNetworkMap(from: contract, fixturePaths: fixturePaths)
    let outputURL = caseURL.appendingPathComponent("network/map-rules.json")
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(map)
    try data.write(to: outputURL, options: .atomic)
    return TKTestRecorderContractArtifact(
        path: "network/map-rules.json",
        absolutePath: outputURL.path,
        contentType: "application/json",
        written: true,
        byteCount: data.count
    )
}

private func buildNetworkMap(from contract: TKTestRecorderCompiledContract, fixturePaths: [Int: String] = [:]) -> TKTestRecorderNetworkMap {
    let rules = contract.network.requests.map { request in
        let transient = isTransientNetworkURL(request.url ?? "")
        return TKTestRecorderNetworkMapRule(
            index: request.index,
            id: request.id ?? "network-\(request.index)",
            sourcePath: request.sourcePath,
            match: TKTestRecorderNetworkMapMatch(
                method: request.method,
                url: request.url
            ),
            strategy: transient ? "passthrough" : "mock-candidate",
            nonBlocking: transient,
            reason: transient ? "transient-or-analytics-request" : "deterministic-business-request-candidate",
            fixturePath: fixturePaths[request.index],
            redactionRequired: !transient
        )
    }
    return TKTestRecorderNetworkMap(
        schemaVersion: 1,
        kind: "triton.testrec.network-map",
        rules: rules
    )
}

private func writeCompileProposalsIfNeeded(qualityFindings: [TKTestRecorderQualityFinding], caseURL: URL) throws -> TKTestRecorderContractArtifact? {
    guard !qualityFindings.isEmpty else { return nil }
    let proposals = compileProposals(from: qualityFindings)
    let outputURL = caseURL.appendingPathComponent("compile-proposals.jsonl")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let lines = try proposals.map { proposal -> String in
        let data = try encoder.encode(proposal)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    let data = Data((lines.joined(separator: "\n") + "\n").utf8)
    try data.write(to: outputURL, options: .atomic)
    return TKTestRecorderContractArtifact(
        path: "compile-proposals.jsonl",
        absolutePath: outputURL.path,
        contentType: "application/x-ndjson",
        written: true,
        byteCount: data.count
    )
}

private func readCompileProposals(from url: URL) throws -> [TKTestRecorderCompileProposal] {
    guard let data = try? Data(contentsOf: url),
          let content = String(data: data, encoding: .utf8)
    else {
        return []
    }
    var proposals: [TKTestRecorderCompileProposal] = []
    for (offset, rawLine) in content.split(whereSeparator: { $0.isNewline }).enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { continue }
        do {
            proposals.append(try JSONDecoder().decode(TKTestRecorderCompileProposal.self, from: Data(line.utf8)))
        } catch {
            throw testRecorderValidationFailure(
                code: "invalid_json",
                message: "Could not decode compile-proposals.jsonl:\(offset + 1): \(error)",
                path: "compile-proposals.jsonl:\(offset + 1)",
                hint: "Run triton testrec compile <case.tritontestcase> --json again."
            )
        }
    }
    return proposals
}

private func compileProposals(from qualityFindings: [TKTestRecorderQualityFinding]) -> [TKTestRecorderCompileProposal] {
    qualityFindings.enumerated().map { offset, finding in
        TKTestRecorderCompileProposal(
            schemaVersion: 1,
            id: "proposal-\(offset + 1)",
            proposalKind: finding.proposalKind,
            findingCode: finding.code,
            sourcePath: finding.path,
            status: "proposed",
            summary: finding.message,
            suggestedChange: suggestedChange(for: finding)
        )
    }
}

private func suggestedChange(for finding: TKTestRecorderQualityFinding) -> String {
    switch finding.code {
    case "privacy_candidate":
        return "Redact or parameterize the captured value before replay."
    case "transient_network_request":
        return "Mark the request as passthrough, ignore, or non-blocking unless an explicit assertion depends on it."
    case "weak_selector":
        return "Replace the selector with semantic role, label, accessibility identifier, or page fingerprint evidence."
    case "fixed_wait":
        return "Replace fixed delay with wait-for-page, wait-for-network, or wait-for-visible evidence."
    default:
        return "Review the finding and decide whether to update the contract."
    }
}

private func compiledContractOutputURL(caseURL: URL, outputPath: String?) -> URL {
    guard let outputPath, !outputPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return caseURL.appendingPathComponent("compiled-contract.json")
    }
    return URL(fileURLWithPath: outputPath)
}

private func compiledContractDisplayPath(outputURL: URL, caseURL: URL) -> String {
    let casePath = caseURL.path.hasSuffix("/") ? caseURL.path : caseURL.path + "/"
    if outputURL.path.hasPrefix(casePath) {
        return String(outputURL.path.dropFirst(casePath.count))
    }
    return outputURL.path
}

private func replayCommandMapping(action: String, object: [String: Any], platform: String, device: String?) -> (command: String, argv: [String], workflowCategories: [String], expectedArtifacts: [String], stopConditions: [String]) {
    let platformArgs = replayPlatformArgs(platform: platform)
    let deviceArgs = device.map { ["--device", $0] } ?? []
    switch action {
    case "tap":
        return (
            "act",
            ["triton", "act", "tap", "--text", replayTargetText(from: object)] + platformArgs + deviceArgs + ["--json"],
            ["action", "evidence"],
            ["input.result", "runtime-ledger"],
            ["action_failed", "text_not_found", "ambiguous_target"]
        )
    case "type":
        return (
            "act",
            ["triton", "act", "type", replayInputText(from: object)] + platformArgs + deviceArgs + ["--json"],
            ["action", "evidence"],
            ["input.result", "runtime-ledger"],
            ["action_failed", "target_unavailable"]
        )
    case "paste":
        return (
            "act",
            ["triton", "act", "paste", replayInputText(from: object)] + platformArgs + deviceArgs + ["--json"],
            ["action", "evidence"],
            ["input.result", "runtime-ledger"],
            ["action_failed", "target_unavailable"]
        )
    case "wait":
        return (
            "wait",
            ["triton", "wait", "--text", replayTargetText(from: object), "--json"],
            ["assert", "evidence"],
            ["wait.result"],
            ["timeout"]
        )
    case "assert":
        return (
            "verify",
            ["triton", "verify", "text-exists", replayTargetText(from: object), "--json"],
            ["assert", "evidence"],
            ["assert.result"],
            ["assertion_failed", "text_not_found"]
        )
    case "screenshot":
        return (
            "screenshot",
            ["triton", "screenshot", "--output", "<path.png>", "--json"],
            ["evidence"],
            ["screenshot-metadata", "screenshot"],
            ["artifact_write_failed"]
        )
    default:
        return (
            "schema",
            ["triton", "schema", "--command", "act", "--json"],
            ["plan"],
            ["command-schema"],
            ["unsupported_action"]
        )
    }
}

private func replayPlatformArgs(platform: String) -> [String] {
    switch platform {
    case "android", "harmony":
        return ["--platform", platform]
    default:
        return []
    }
}

private func replayTargetText(from object: [String: Any]) -> String {
    if let text = object["text"] as? String, !text.isEmpty {
        return text
    }
    if let label = object["label"] as? String, !label.isEmpty {
        return label
    }
    if let target = object["target"] as? [String: Any] {
        for key in ["label", "text", "name", "accessibilityLabel"] {
            if let value = target[key] as? String, !value.isEmpty {
                return value
            }
        }
    }
    return "<target>"
}

private func compiledActionTargetText(action: String, object: [String: Any]) -> String {
    if let target = object["target"] as? [String: Any] {
        for key in ["label", "text", "name", "accessibilityLabel"] {
            if let value = target[key] as? String, !value.isEmpty {
                return value
            }
        }
    }
    if let label = object["label"] as? String, !label.isEmpty {
        return label
    }
    if action != "type" && action != "paste", let text = object["text"] as? String, !text.isEmpty {
        return text
    }
    return "<target>"
}

private func replayInputText(from object: [String: Any]) -> String {
    for key in ["text", "value", "input"] {
        if let value = object[key] as? String, !value.isEmpty {
            return value
        }
    }
    return "<text>"
}

private func decodeTestRecorderJSONObject(_ line: String, path: String) throws -> [String: Any] {
    do {
        let data = Data(line.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw testRecorderValidationFailure(
                code: "invalid_json",
                message: "Expected \(path) to contain a JSON object.",
                path: path,
                hint: "Each JSONL row must be an object."
            )
        }
        return object
    } catch let failure as TKTestRecorderValidationFailure {
        throw failure
    } catch {
        throw testRecorderValidationFailure(
            code: "invalid_json",
            message: "Could not decode \(path): \(error)",
            path: path,
            hint: "Verify each JSONL row is valid JSON."
        )
    }
}

private func replayBlockers(compile: TKTestRecorderCompileResponse, plannedSteps: [TKTestRecorderReplayPlannedStep]) -> [TKTestRecorderReplayBlocker] {
    var blockers: [TKTestRecorderReplayBlocker] = []
    if plannedSteps.isEmpty {
        blockers.append(TKTestRecorderReplayBlocker(
            code: "missing_actions",
            path: "actions.jsonl",
            message: "No action stream is available to replay."
        ))
    }
    for warning in compile.warnings where warning.code == "unsupported_capability" {
        blockers.append(TKTestRecorderReplayBlocker(
            code: warning.code,
            path: warning.path,
            message: warning.message
        ))
    }
    if let finding = compile.compiledContract?.qualityFindings.first(where: { $0.proposalKind == "contract.redaction" }) {
        blockers.append(TKTestRecorderReplayBlocker(
            code: "redaction_review_required",
            path: finding.path,
            message: "Replay requires redaction review before executing a contract with privacy findings."
        ))
    }
    for step in plannedSteps where step.status == "unsupported" {
        blockers.append(TKTestRecorderReplayBlocker(
            code: "unsupported_action",
            path: step.sourcePath,
            message: "Action '\(step.action)' is not supported by replay dry-run planning."
        ))
    }
    return blockers
}

private func replayBlockersForMissingCompiledContract(compile: TKTestRecorderCompileResponse) -> [TKTestRecorderReplayBlocker] {
    var blockers = replayCompileBlockers(compile: compile)
    blockers.append(TKTestRecorderReplayBlocker(
        code: "missing_compiled_contract",
        path: "compiled-contract.json",
        message: "Replay dry-run requires compiled-contract.json; run testrec compile first."
    ))
    return blockers
}

private func replayCompileBlockers(compile: TKTestRecorderCompileResponse) -> [TKTestRecorderReplayBlocker] {
    compile.warnings
        .filter { $0.code == "unsupported_capability" }
        .map {
            TKTestRecorderReplayBlocker(
                code: $0.code,
                path: $0.path,
                message: $0.message
            )
        }
}

func isTransientNetworkURL(_ url: String) -> Bool {
    let lowercased = url.lowercased()
    return lowercased.contains("analytics")
        || lowercased.contains("pixel")
        || lowercased.contains("telemetry")
        || lowercased.contains("tracking")
        || lowercased.contains("session=")
        || lowercased.contains("cachebuster")
}

func testRecorderValidationFailure(code: String, message: String, path: String, hint: String? = nil) -> TKTestRecorderValidationFailure {
    TKTestRecorderValidationFailure(
        detail: TKTestRecorderValidationErrorDetail(
            type: "validation_error",
            message: message,
            path: path,
            code: code,
            hint: hint
        )
    )
}
