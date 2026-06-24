import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct TestRecorderContractTests {
    @Test("testrec schema exposes inspect contract")
    func testrecSchemaExposesInspectContract() throws {
        let schema = try #require(commandSchemaMap()["testrec"])

        #expect(schema.summary.contains(".tritontestcase"))
        #expect(schema.subcommands.map(\.name).contains("start"))
        #expect(schema.subcommands.map(\.name).contains("event"))
        #expect(schema.subcommands.map(\.name).contains("stop"))
        #expect(schema.subcommands.map(\.name).contains("inspect"))
        #expect(schema.subcommands.map(\.name).contains("compile"))
        #expect(schema.subcommands.map(\.name).contains("proposals"))
        #expect(schema.subcommands.map(\.name).contains("match-page"))
        #expect(schema.subcommands.map(\.name).contains("replay"))
        #expect(schema.subcommands.map(\.name).contains("matrix"))
        #expect(schema.providedCapabilities.contains("testrec-session-start"))
        #expect(schema.providedCapabilities.contains("testrec-event-ingest"))
        #expect(schema.providedCapabilities.contains("testrec-session-stop"))
        #expect(schema.providedCapabilities.contains("testrec-inspect"))
        #expect(schema.providedCapabilities.contains("testrec-compile"))
        #expect(schema.providedCapabilities.contains("testrec-proposals-inspect"))
        #expect(schema.providedCapabilities.contains("testrec-page-match"))
        #expect(schema.providedCapabilities.contains("testrec-replay-dry-run"))
        #expect(schema.providedCapabilities.contains("testrec-replay-local-simulated"))
        #expect(schema.providedCapabilities.contains("testrec-matrix"))
        #expect(schema.artifacts.contains("tritontestcase"))
        #expect(schema.artifacts.contains("compiled-contract"))
        #expect(schema.artifacts.contains("action-map"))
        #expect(schema.artifacts.contains("page-map"))
        #expect(schema.artifacts.contains("network-map"))
        #expect(schema.artifacts.contains("compile-proposals"))
        #expect(schema.artifacts.contains("evidence-bundle"))
        #expect(schema.subcommands.first { $0.name == "start" }?.artifacts.contains("tritontestcase") == true)
        #expect(schema.subcommands.first { $0.name == "compile" }?.artifacts.contains("compiled-contract") == true)
        #expect(schema.subcommands.first { $0.name == "replay" }?.artifacts.contains("evidence-bundle") == true)
        #expect(schema.usageForms.contains { $0.form == "start --platform <platform> --case <name> --output <case.tritontestcase> --json" })
        #expect(schema.usageForms.contains { $0.form == "event --session <session-id> --kind action --payload-json <json> --json" })
        #expect(schema.usageForms.contains { $0.form == "stop --session <session-id> --json" })
        #expect(schema.usageForms.contains { $0.form == "inspect <case.tritontestcase> --json" })
        #expect(schema.usageForms.contains { $0.form == "compile <case.tritontestcase> --json" })
        #expect(schema.usageForms.contains { $0.form == "proposals <case.tritontestcase> --json" })
        #expect(schema.usageForms.contains { $0.form == "match-page <case.tritontestcase> --page <page> --candidate-json <json> --json" })
        #expect(schema.usageForms.contains { $0.form == "replay <case.tritontestcase> --platform <platform> --dry-run --json" })
        #expect(schema.usageForms.contains { $0.form == "replay <case.tritontestcase> --platform <platform> --executor local-simulated --target-fingerprints-json <json> --evidence-dir <dir.tritonevidence> --json" })
        #expect(schema.usageForms.contains { $0.form == "matrix <case.tritontestcase> --targets ios:sim-a,android:emu-a --json" })
        expectContract(schema, selector: "testrec.session-start", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "sessionId",
            "casePath",
            "manifest",
            "manifest.tritonKitVersion",
            "manifest.capabilitiesRef",
            "manifest.redactionStatus",
            "manifest.truncationStatus",
            "capabilities",
            "suggestedCommands",
        ])
        expectContract(schema, selector: "testrec.event", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "sessionId",
            "casePath",
            "eventKind",
            "eventPath",
            "eventCount",
            "suggestedCommands",
        ])
        expectContract(schema, selector: "testrec.session-stop", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "sessionId",
            "casePath",
            "eventCount",
            "artifacts",
            "suggestedCommands",
        ])
        expectContract(schema, selector: "testrec.inspect", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "path",
            "manifest",
            "manifest.name",
            "manifest.tritonKitVersion",
            "manifest.capabilitiesRef",
            "manifest.redactionStatus",
            "manifest.truncationStatus",
            "capabilities",
            "capabilities.actions",
            "capabilities.pages",
            "capabilities.network",
            "lifecycle",
            "lifecycle.stage",
            "lifecycle.health",
            "unsupportedCapabilities",
            "artifacts",
            "artifacts[].byteCount",
            "artifacts[].digestAlgorithm",
            "artifacts[].digest",
        ])
        expectContract(schema, selector: "testrec.compile", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "path",
            "status",
            "summary",
            "compiledContract",
            "compiledContract.compiler.mode",
            "compiledContract.compiler.llmUsed",
            "compiledContract.compiler.vlmUsed",
            "compiledContract.network.requests",
            "compiledContract.pages.routes",
            "compiledContract.pages.fingerprints",
            "compiledContract.qualityFindings",
            "compiledContract.qualityFindings[].proposalKind",
            "contractArtifact",
            "contractArtifact.path",
            "actionMapArtifact",
            "actionMapArtifact.path",
            "networkMapArtifact",
            "networkMapArtifact.path",
            "pageMapArtifact",
            "pageMapArtifact.path",
            "proposalArtifact",
            "proposalArtifact.path",
            "warnings",
            "suggestedCommands",
        ])
        expectContract(schema, selector: "testrec.proposals", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "path",
            "proposalCount",
            "proposals",
            "proposals[].proposalKind",
            "proposals[].status",
            "suggestedCommands",
        ])
        expectContract(schema, selector: "testrec.page-match", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "path",
            "page",
            "source",
            "candidate",
            "policy",
            "policy.scorer",
            "policy.llmDecisionAuthority",
            "score",
            "decision",
            "components",
            "components[].name",
            "evidence",
            "llmUsed",
            "llmDecisionAuthority",
            "suggestedCommands",
        ])
        expectContract(schema, selector: "testrec.replay-dry-run", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "dryRun",
            "platform",
            "status",
            "contractRef",
            "contractRef.path",
            "contractRef.digestAlgorithm",
            "contractRef.digest",
            "pageChecks",
            "pageChecks[].argv",
            "pageChecks[].expectedArtifacts",
            "pageChecks[].stopConditions",
            "executorProfiles",
            "executorProfiles[].id",
            "executorProfiles[].status",
            "executorProfiles[].requirements",
            "executorProfiles[].requirements[].name",
            "plannedSteps",
            "plannedSteps[].command",
            "plannedSteps[].argv",
            "plannedSteps[].workflowCategories",
            "plannedSteps[].expectedArtifacts",
            "plannedSteps[].stopConditions",
            "blockers",
            "suggestedCommands",
        ])
        expectContract(schema, selector: "testrec.replay-result", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "dryRun",
            "executor",
            "platform",
            "status",
            "contractRef",
            "contractRef.path",
            "contractRef.digestAlgorithm",
            "contractRef.digest",
            "evidenceDir",
            "artifactRefs",
            "execution",
            "execution.mode",
            "execution.requiresDevice",
            "execution.deviceCommandsExecuted",
            "execution.llmUsed",
            "execution.vlmUsed",
            "execution.networkPolicyMode",
            "execution.stepStatusTaxonomy",
            "execution.executorRequirements",
            "execution.executorRequirements[].name",
            "execution.executorRequirements[].required",
            "execution.executorRequirements[].status",
            "execution.executorRequirements[].evidence",
            "execution.evidence",
            "evidenceSummary",
            "evidenceSummary.expectedEventCount",
            "evidenceSummary.pageEventCount",
            "evidenceSummary.networkEventCount",
            "evidenceSummary.stepEventCount",
            "evidenceSummary.artifactRefCount",
            "evidenceSummary.pageArtifactRefCount",
            "evidenceSummary.networkArtifactRefCount",
            "evidenceSummary.stepArtifactRefCount",
            "evidenceSummary.blockerCount",
            "evidenceSummary.statusConsistent",
            "pageResults",
            "pageResults[].status",
            "pageResults[].matchScore",
            "pageResults[].matchDecision",
            "pageResults[].artifactRefs",
            "pageResults[].evidence",
            "networkResults",
            "networkResults[].strategy",
            "networkResults[].redactionRequired",
            "networkResults[].fixturePath",
            "networkResults[].artifactRefs",
            "networkResults[].evidence",
            "steps",
            "steps[].status",
            "steps[].argv",
            "steps[].deviceCommandExecuted",
            "steps[].artifactRefs",
            "steps[].evidence",
            "steps[].failure",
            "steps[].failure.code",
            "steps[].failure.artifactRefs",
            "steps[].failure.recoveryCommands",
            "blockers",
            "suggestedCommands",
        ])
        expectContract(schema, selector: "testrec.matrix", fields: [
            "ok",
            "schemaVersion",
            "kind",
            "path",
            "executor",
            "evidenceRoot",
            "status",
            "targetCount",
            "readyCount",
            "passedCount",
            "blockedCount",
            "results",
            "results[].target",
            "results[].platform",
            "results[].device",
            "results[].status",
            "results[].dryRun",
            "results[].plannedStepCount",
            "results[].evidenceDir",
            "results[].blockers",
            "suggestedCommands",
        ])

        let inspectContract = try #require(schema.outputContracts.first { $0.selector == "testrec.inspect" })
        let capabilitiesRef = try #require(inspectContract.fields.first { $0.name == "manifest.capabilitiesRef" })
        #expect(capabilitiesRef.description.contains("inside the .tritontestcase package"))

        let dryRunContract = try #require(schema.outputContracts.first { $0.selector == "testrec.replay-dry-run" })
        let dryRunRequirementStatus = try #require(dryRunContract.fields.first { $0.name == "executorProfiles[].requirements[].status" })
        for status in ["satisfied", "missing", "optional", "not-required", "simulated", "not-present", "not-requested"] {
            #expect(dryRunRequirementStatus.description.contains(status))
        }

        let replayContract = try #require(schema.outputContracts.first { $0.selector == "testrec.replay-result" })
        let replayRequirementStatus = try #require(replayContract.fields.first { $0.name == "execution.executorRequirements[].status" })
        for status in ["satisfied", "missing", "optional", "not-required", "simulated", "not-present", "not-requested"] {
            #expect(replayRequirementStatus.description.contains(status))
        }
    }

    @Test("start event stop creates an inspectable explicit-event case")
    func startEventStopCreatesInspectableExplicitEventCase() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-testrec-session-\(UUID().uuidString)", isDirectory: true)
        let caseURL = root.appendingPathComponent("login.tritontestcase", isDirectory: true)
        let sessionStore = root.appendingPathComponent("sessions", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let started = try startTritonTestRecorderSession(
            caseName: "login-flow",
            sourcePlatform: "ios",
            outputPath: caseURL.path,
            sessionStoreRoot: sessionStore
        )
        let action = try appendTritonTestRecorderEvent(
            sessionID: started.sessionId,
            eventKind: "action",
            payloadJSON: #"{"id":"a1","kind":"tap","target":{"label":"登录"}}"#,
            sessionStoreRoot: sessionStore
        )
        let page = try appendTritonTestRecorderEvent(
            sessionID: started.sessionId,
            eventKind: "page-route",
            payloadJSON: #"{"id":"p1","route":"login"}"#,
            sessionStoreRoot: sessionStore
        )
        let stopped = try stopTritonTestRecorderSession(sessionID: started.sessionId, sessionStoreRoot: sessionStore)
        let inspected = try inspectTritonTestCase(path: caseURL.path)

        #expect(started.ok == true)
        #expect(started.kind == "triton.testrec.session-start")
        #expect(started.casePath == caseURL.path)
        #expect(started.manifest.name == "login-flow")
        #expect(started.manifest.sourcePlatform == "ios")
        #expect(started.manifest.tritonKitVersion == TritonKitBuildInfo.cliVersion)
        #expect(started.manifest.capabilitiesRef == "contract-capabilities.json")
        #expect(started.manifest.redactionStatus == "pending")
        #expect(started.manifest.truncationStatus == "not-truncated")
        #expect(action.kind == "triton.testrec.event")
        #expect(action.eventKind == "action")
        #expect(action.eventPath == "actions.jsonl")
        #expect(action.eventCount == 1)
        #expect(page.eventPath == "pages/route-events.jsonl")
        #expect(stopped.kind == "triton.testrec.session-stop")
        #expect(stopped.eventCount == 2)
        #expect(stopped.artifacts.contains { $0.kind == "actions" && $0.present })
        #expect(stopped.artifacts.contains { $0.kind == "page-route-events" && $0.present })
        #expect(inspected.manifest.name == "login-flow")
        #expect(inspected.artifacts.contains { $0.kind == "actions" && $0.present })
        #expect(inspected.artifacts.contains { $0.kind == "page-route-events" && $0.present })
    }

    @Test("event rejects invalid JSON payload before mutating case")
    func eventRejectsInvalidJSONPayloadBeforeMutatingCase() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-testrec-invalid-event-\(UUID().uuidString)", isDirectory: true)
        let caseURL = root.appendingPathComponent("login.tritontestcase", isDirectory: true)
        let sessionStore = root.appendingPathComponent("sessions", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let started = try startTritonTestRecorderSession(
            caseName: "login-flow",
            sourcePlatform: "ios",
            outputPath: caseURL.path,
            sessionStoreRoot: sessionStore
        )

        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try appendTritonTestRecorderEvent(
                sessionID: started.sessionId,
                eventKind: "action",
                payloadJSON: "{not-json",
                sessionStoreRoot: sessionStore
            )
        }

        #expect(failure?.detail.code == "invalid_json")
        #expect(failure?.detail.path == "--payload-json")
        #expect(!FileManager.default.fileExists(atPath: caseURL.appendingPathComponent("actions.jsonl").path))
    }

    @Test("HTTP session event stop handlers mirror explicit event CLI recording")
    func httpSessionEventStopHandlersMirrorExplicitEventCLIRecording() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-testrec-http-\(UUID().uuidString)", isDirectory: true)
        let caseURL = root.appendingPathComponent("login.tritontestcase", isDirectory: true)
        let sessionStore = root.appendingPathComponent("sessions", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let started = try handleTestRecorderHTTPSessionCreate(
            body: Data("""
            {"platform":"ios","caseName":"login-flow","output":"\(caseURL.path)"}
            """.utf8),
            sessionStoreRoot: sessionStore
        )
        let event = try handleTestRecorderHTTPEvent(
            sessionID: started.sessionId,
            body: Data("""
            {"kind":"action","payload":{"id":"a1","kind":"tap","target":{"label":"登录"}}}
            """.utf8),
            sessionStoreRoot: sessionStore
        )
        let stopped = try handleTestRecorderHTTPSessionStop(sessionID: started.sessionId, sessionStoreRoot: sessionStore)
        let inspected = try inspectTritonTestCase(path: caseURL.path)

        #expect(started.kind == "triton.testrec.session-start")
        #expect(event.kind == "triton.testrec.event")
        #expect(event.eventPath == "actions.jsonl")
        #expect(stopped.kind == "triton.testrec.session-stop")
        #expect(stopped.eventCount == 1)
        #expect(inspected.artifacts.contains { $0.kind == "actions" && $0.present })
    }

    @Test("HTTP session create rejects invalid payload without creating case")
    func httpSessionCreateRejectsInvalidPayloadWithoutCreatingCase() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-testrec-http-invalid-\(UUID().uuidString)", isDirectory: true)
        let caseURL = root.appendingPathComponent("login.tritontestcase", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try handleTestRecorderHTTPSessionCreate(
                body: Data("""
                {"platform":"ios","caseName":"login-flow","output":""}
                """.utf8),
                sessionStoreRoot: root.appendingPathComponent("sessions", isDirectory: true)
            )
        }

        #expect(failure?.detail.code == "invalid_payload")
        #expect(!FileManager.default.fileExists(atPath: caseURL.path))
    }

    @Test("HTTP case handlers inspect compile proposals and replay dry-run")
    func httpCaseHandlersInspectCompileProposalsAndReplayDryRun() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let evidenceURL = caseURL.deletingLastPathComponent().appendingPathComponent("http-login.tritonevidence", isDirectory: true)
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreamsWithSensitiveNetworkBody(to: caseURL)

        let pathBody = Data("""
        {"path":"\(caseURL.path)"}
        """.utf8)
        let inspected = try handleTestRecorderHTTPInspect(body: pathBody)
        let compiled = try handleTestRecorderHTTPCompile(body: pathBody)
        let proposals = try handleTestRecorderHTTPProposals(body: pathBody)
        let replay = try handleTestRecorderHTTPReplayDryRun(body: Data("""
        {"path":"\(caseURL.path)","platform":"android","device":"emulator-a","dryRun":true}
        """.utf8))
        let run = try handleTestRecorderHTTPReplay(body: Data("""
        {"path":"\(caseURL.path)","platform":"android","device":"emulator-a","executor":"local-simulated","evidenceDir":"\(evidenceURL.path)","targetFingerprints":{"pages":[{"pageId":"login","route":"login","kind":"mock","hash":"abc123"}]}}
        """.utf8))
        let localDeviceRun = try handleTestRecorderHTTPReplay(body: Data("""
        {"path":"\(caseURL.path)","platform":"android","device":"missing-emulator","executor":"local-device"}
        """.utf8))
        let matrix = try handleTestRecorderHTTPMatrix(body: Data("""
        {"path":"\(caseURL.path)","targets":"android:emulator-a,harmony:dev-a"}
        """.utf8))

        #expect(inspected.kind == "triton.testrec.inspect")
        #expect(compiled.kind == "triton.testrec.compile")
        #expect(compiled.status == "compiled")
        #expect(compiled.contractArtifact?.path == "compiled-contract.json")
        #expect(proposals.kind == "triton.testrec.proposals")
        #expect(proposals.proposalCount == 0)
        #expect(replay.kind == "triton.testrec.replay-dry-run")
        #expect(replay.pageChecks.count == 1)
        #expect(replay.pageChecks[0].argv.prefix(3) == ["triton", "testrec", "match-page"])
        #expect(replay.plannedSteps.count >= 2)
        #expect(replay.plannedSteps.first?.argv.prefix(3) == ["triton", "act", "tap"])
        #expect(run.kind == "triton.testrec.replay-result")
        #expect(run.ok == true)
        #expect(run.executor == "local-simulated")
        #expect(run.steps.map(\.status) == ["simulated-passed", "simulated-passed"])
        #expect(run.pageResults[0].matchDecision == "matched")
        #expect(run.pageResults[0].artifactRefs == ["pages/target-fingerprints.json"])
        #expect(run.networkResults[0].fixturePath == "network/fixtures/n1.json")
        #expect(run.networkResults[0].artifactRefs == ["network/fixtures/n1.json"])
        #expect(run.artifactRefs.contains("pages/target-fingerprints.json"))
        #expect(run.artifactRefs.contains("network/fixtures/n1.json"))
        #expect(localDeviceRun.ok == false)
        #expect(localDeviceRun.executor == "local-device")
        #expect(localDeviceRun.blockers.map(\.code).contains("target_not_found"))
        #expect(localDeviceRun.steps.allSatisfy { $0.deviceCommandExecuted == false })
        #expect(matrix.kind == "triton.testrec.matrix")
        #expect(matrix.status == "ready")
        #expect(matrix.targetCount == 2)
        #expect(matrix.results.map(\.target) == ["android:emulator-a", "harmony:dev-a"])
        #expect(matrix.results.allSatisfy { $0.dryRun })
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("pages/target-fingerprints.json").path))
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("network/fixtures/n1.json").path))
        let httpManifest = try JSONDecoder().decode(
            TKEvidenceManifest.self,
            from: Data(contentsOf: evidenceURL.appendingPathComponent("manifest.json"))
        )
        let httpRunMetadata = try JSONDecoder().decode(
            TKTestRunMetadata.self,
            from: Data(contentsOf: evidenceURL.appendingPathComponent("run/run.json"))
        )
        #expect(httpManifest.run?.summary?.runID == httpRunMetadata.runID)
        #expect(httpManifest.run?.summary?.verdict == .success)
        #expect(httpManifest.run?.summary?.stepCount == run.steps.count)
        #expect(httpManifest.run?.summary?.frictionCount == run.blockers.count)
        #expect(httpManifest.artifacts.contains {
            $0.kind == "testrec.page.target-fingerprints" && $0.path == "pages/target-fingerprints.json"
        })
        #expect(httpManifest.artifacts.contains {
            $0.kind == "testrec.network.fixture" && $0.path == "network/fixtures/n1.json"
        })
        let events = try String(contentsOf: evidenceURL.appendingPathComponent("run/events.jsonl"), encoding: .utf8)
        #expect(events.contains(#""event":"testrec.replay.network""#))
        #expect(events.contains(#"network\/fixtures\/n1.json"#))
    }


    @Test("HTTP matrix local simulated writes per target evidence bundles")
    func httpMatrixLocalSimulatedWritesPerTargetEvidenceBundles() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let evidenceRoot = caseURL.deletingLastPathComponent().appendingPathComponent("http-matrix-evidence", isDirectory: true)
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try handleTestRecorderHTTPMatrix(body: Data("""
        {"path":"\(caseURL.path)","targets":"android:emulator-a,harmony:dev-a","executor":"local-simulated","evidenceRoot":"\(evidenceRoot.path)","targetFingerprints":{"pages":[{"pageId":"login","route":"login","kind":"mock","hash":"abc123"}]}}
        """.utf8))

        #expect(response.status == "passed")
        #expect(response.executor == "local-simulated")
        #expect(response.evidenceRoot == evidenceRoot.path)
        #expect(response.passedCount == 2)
        let androidEvidence = evidenceRoot.appendingPathComponent("android-emulator-a", isDirectory: true).path
        let harmonyEvidence = evidenceRoot.appendingPathComponent("harmony-dev-a", isDirectory: true).path
        #expect(response.results.map(\.evidenceDir) == [androidEvidence, harmonyEvidence])
        #expect(response.suggestedCommands.contains("triton evidence summary \(shellQuotedEvidencePath(androidEvidence)) --json"))
        #expect(response.suggestedCommands.contains("triton evidence summary \(shellQuotedEvidencePath(harmonyEvidence)) --json"))
        #expect(FileManager.default.fileExists(atPath: evidenceRoot.appendingPathComponent("android-emulator-a/run/replay-result.json").path))
        #expect(FileManager.default.fileExists(atPath: evidenceRoot.appendingPathComponent("harmony-dev-a/run/events.jsonl").path))
    }

    @Test("HTTP replay rejects non dry run execution")
    func httpReplayRejectsNonDryRunExecution() throws {
        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try handleTestRecorderHTTPReplayDryRun(body: Data("""
            {"path":"/tmp/login.tritontestcase","platform":"android","dryRun":false}
            """.utf8))
        }

        #expect(failure?.detail.code == "dry_run_required")
        #expect(failure?.detail.path == "$.dryRun")
    }

    @Test("HTTP replay rejects unknown executor")
    func httpReplayRejectsUnknownExecutor() throws {
        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try handleTestRecorderHTTPReplay(body: Data("""
            {"path":"/tmp/login.tritontestcase","platform":"android","executor":"device"}
            """.utf8))
        }

        #expect(failure?.detail.code == "unsupported_replay_executor")
        #expect(failure?.detail.path == "--executor")
        #expect(failure?.detail.hint?.contains("live-target-device") == true)
    }

    @Test("inspect valid tritontestcase reads manifest and contract capabilities")
    func inspectValidCaseReadsManifestAndCapabilities() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)

        let response = try inspectTritonTestCase(path: caseURL.path)

        #expect(response.ok == true)
        #expect(response.kind == "triton.testrec.inspect")
        #expect(response.manifest.name == "login-flow")
        #expect(response.manifest.tritonKitVersion == "unknown")
        #expect(response.manifest.capabilitiesRef == "contract-capabilities.json")
        #expect(response.manifest.redactionStatus == "pending")
        #expect(response.manifest.truncationStatus == "not-truncated")
        #expect(response.capabilities.actions == ["tap", "type", "scroll"])
        #expect(response.capabilities.pages == ["route", "ax", "fingerprint"])
        #expect(response.capabilities.network == ["fixture", "passthrough"])
        #expect(response.unsupportedCapabilities.isEmpty)
        #expect(response.lifecycle.stage == "raw")
        #expect(response.lifecycle.health == "needs-compile")
        #expect(response.suggestedCommands == ["triton schema --command testrec --json"])
        let manifestArtifact = try #require(response.artifacts.first { $0.kind == "manifest" && $0.path == "manifest.json" })
        let capabilitiesArtifact = try #require(response.artifacts.first { $0.kind == "contract-capabilities" && $0.path == "contract-capabilities.json" })
        let compiledArtifact = try #require(response.artifacts.first { $0.kind == "compiled-contract" && $0.path == "compiled-contract.json" })
        #expect(manifestArtifact.byteCount ?? 0 > 0)
        #expect(manifestArtifact.digestAlgorithm == "fnv1a64")
        #expect(manifestArtifact.digest?.isEmpty == false)
        #expect(capabilitiesArtifact.byteCount ?? 0 > 0)
        #expect(capabilitiesArtifact.digestAlgorithm == "fnv1a64")
        #expect(capabilitiesArtifact.digest?.isEmpty == false)
        #expect(compiledArtifact.present == false)
        #expect(compiledArtifact.byteCount == nil)
        #expect(compiledArtifact.digestAlgorithm == nil)
        #expect(compiledArtifact.digest == nil)
    }

    @Test("inspect reads capabilities from manifest capabilitiesRef")
    func inspectReadsCapabilitiesFromManifestCapabilitiesRef() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try """
        {
          "schemaVersion": 1,
          "kind": "triton.testcase.v1",
          "name": "custom-capabilities",
          "sourcePlatform": "ios",
          "capabilitiesRef": "contracts/caps.json"
        }
        """.write(to: caseURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        let contractsURL = caseURL.appendingPathComponent("contracts", isDirectory: true)
        try FileManager.default.createDirectory(at: contractsURL, withIntermediateDirectories: true)
        try """
        {
          "schemaVersion": 1,
          "actions": ["tap"],
          "pages": ["route"],
          "network": ["passthrough"]
        }
        """.write(to: contractsURL.appendingPathComponent("caps.json"), atomically: true, encoding: .utf8)

        let response = try inspectTritonTestCase(path: caseURL.path)

        #expect(response.manifest.capabilitiesRef == "contracts/caps.json")
        #expect(response.capabilities.actions == ["tap"])
        #expect(response.capabilities.pages == ["route"])
        #expect(response.capabilities.network == ["passthrough"])
        #expect(response.artifacts.first { $0.kind == "contract-capabilities" }?.path == "contracts/caps.json")
        #expect(response.artifacts.first { $0.path == "contracts/caps.json" }?.present == true)
    }

    @Test("inspect rejects capabilitiesRef outside case package")
    func inspectRejectsCapabilitiesRefOutsideCasePackage() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try """
        {
          "schemaVersion": 1,
          "kind": "triton.testcase.v1",
          "name": "bad-capabilities-ref",
          "sourcePlatform": "ios",
          "capabilitiesRef": "../contract-capabilities.json"
        }
        """.write(to: caseURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try inspectTritonTestCase(path: caseURL.path)
        }

        #expect(failure?.detail.code == "invalid_capabilities_ref")
        #expect(failure?.detail.path == "manifest.json.capabilitiesRef")
    }

    @Test("inspect rejects invalid manifest JSON with validation envelope")
    func inspectRejectsInvalidManifestJSON() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try "{".write(to: caseURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try writeValidCapabilities(to: caseURL)

        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try inspectTritonTestCase(path: caseURL.path)
        }

        #expect(failure?.detail.code == "invalid_json")
        #expect(failure?.detail.path == "manifest.json")
        #expect(failure?.detail.hint?.contains(".tritontestcase v1 schema") == true)
    }

    @Test("inspect reports hand written contract artifacts with identity")
    func inspectReportsHandWrittenContractArtifacts() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try FileManager.default.createDirectory(at: caseURL.appendingPathComponent("actions"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caseURL.appendingPathComponent("network"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caseURL.appendingPathComponent("pages"), withIntermediateDirectories: true)
        try #"{"kind":"tap","target":{"label":"Login"}}"#
            .write(to: caseURL.appendingPathComponent("actions.jsonl"), atomically: true, encoding: .utf8)
        try #"{"assertions":[{"kind":"text-exists","text":"Home"}]}"#
            .write(to: caseURL.appendingPathComponent("assertions.json"), atomically: true, encoding: .utf8)
        try #"{"rules":[{"id":"login","strategy":"mock-candidate"}]}"#
            .write(to: caseURL.appendingPathComponent("network/map-rules.json"), atomically: true, encoding: .utf8)
        try #"{"pages":[{"pageId":"login","route":"/login"}]}"#
            .write(to: caseURL.appendingPathComponent("pages/page-map.json"), atomically: true, encoding: .utf8)

        let response = try inspectTritonTestCase(path: caseURL.path)
        let artifacts = Dictionary(uniqueKeysWithValues: response.artifacts.map { ($0.kind, $0) })

        for kind in ["actions", "assertions", "network-map", "page-map"] {
            let artifact = try #require(artifacts[kind])
            #expect(artifact.present == true)
            #expect(artifact.byteCount ?? 0 > 0)
            #expect(artifact.digestAlgorithm == "fnv1a64")
            #expect(artifact.digest?.isEmpty == false)
        }
    }

    @Test("inspect reports lifecycle stage for compiled and proposed cases")
    func inspectReportsLifecycleStageForCompiledAndProposedCases() throws {
        let compiledCaseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: compiledCaseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: compiledCaseURL)
        try writeValidCapabilities(to: compiledCaseURL)
        try writeRawStreams(to: compiledCaseURL)
        _ = try compileTritonTestCase(path: compiledCaseURL.path, writeContract: true)

        let compiled = try inspectTritonTestCase(path: compiledCaseURL.path)

        #expect(compiled.lifecycle.stage == "compiled")
        #expect(compiled.lifecycle.health == "ready")
        #expect(compiled.lifecycle.hasCompiledContract == true)
        #expect(compiled.lifecycle.hasCompileProposals == false)

        let proposedCaseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: proposedCaseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: proposedCaseURL)
        try writeValidCapabilities(to: proposedCaseURL)
        try writeNoisyRawStreams(to: proposedCaseURL)
        _ = try compileTritonTestCase(path: proposedCaseURL.path, writeContract: true)

        let proposed = try inspectTritonTestCase(path: proposedCaseURL.path)

        #expect(proposed.lifecycle.stage == "proposed")
        #expect(proposed.lifecycle.health == "review-proposals")
        #expect(proposed.lifecycle.hasCompiledContract == true)
        #expect(proposed.lifecycle.hasCompileProposals == true)
    }

    @Test("inspect rejects missing contract capabilities")
    func inspectRejectsMissingContractCapabilities() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)

        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try inspectTritonTestCase(path: caseURL.path)
        }

        #expect(failure?.detail.code == "missing_required_file")
        #expect(failure?.detail.path == "contract-capabilities.json")
    }

    @Test("inspect reports unsupported capabilities without treating them as pass")
    func inspectReportsUnsupportedCapabilities() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try """
        {
          "schemaVersion": 1,
          "actions": ["tap", "drag"],
          "pages": ["route", "fingerprint", "quantum-page"],
          "network": ["fixture", "websocket-fixture"]
        }
        """.write(to: caseURL.appendingPathComponent("contract-capabilities.json"), atomically: true, encoding: .utf8)

        let response = try inspectTritonTestCase(path: caseURL.path)

        #expect(response.unsupportedCapabilities.map(\.name) == ["drag", "quantum-page", "websocket-fixture"])
        #expect(response.unsupportedCapabilities.map(\.domain) == ["actions", "pages", "network"])
    }

    @Test("compile summarizes raw stream counts without executing replay")
    func compileSummarizesRawStreamCounts() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)

        let response = try compileTritonTestCase(path: caseURL.path)

        #expect(response.ok == true)
        #expect(response.kind == "triton.testrec.compile")
        #expect(response.status == "compiled")
        #expect(response.summary.actionEventCount == 2)
        #expect(response.summary.networkEventCount == 1)
        #expect(response.summary.pageRouteEventCount == 1)
        #expect(response.summary.pageFingerprintCount == 1)
        #expect(response.warnings.isEmpty)
        #expect(response.suggestedCommands == ["triton testrec inspect \(caseURL.path) --json"])
    }

    @Test("compile writes deterministic compiled contract artifact when raw streams are complete")
    func compileWritesDeterministicCompiledContractArtifact() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)

        let response = try compileTritonTestCase(path: caseURL.path, writeContract: true)
        let contractURL = caseURL.appendingPathComponent("compiled-contract.json")
        let actionMapURL = caseURL.appendingPathComponent("actions/action-map.json")
        let networkMapURL = caseURL.appendingPathComponent("network/map-rules.json")
        let pageMapURL = caseURL.appendingPathComponent("pages/page-map.json")
        let decoded = try JSONDecoder().decode(
            TKTestRecorderCompiledContract.self,
            from: Data(contentsOf: contractURL)
        )
        let networkMap = try JSONDecoder().decode(
            TKTestRecorderNetworkMap.self,
            from: Data(contentsOf: networkMapURL)
        )
        let actionMap = try JSONDecoder().decode(
            TKTestRecorderActionMap.self,
            from: Data(contentsOf: actionMapURL)
        )
        let pageMap = try JSONDecoder().decode(
            TKTestRecorderPageMap.self,
            from: Data(contentsOf: pageMapURL)
        )

        #expect(response.status == "compiled")
        #expect(response.contractArtifact?.path == "compiled-contract.json")
        #expect(response.contractArtifact?.written == true)
        #expect(response.actionMapArtifact?.path == "actions/action-map.json")
        #expect(response.actionMapArtifact?.written == true)
        #expect(response.networkMapArtifact?.path == "network/map-rules.json")
        #expect(response.networkMapArtifact?.written == true)
        #expect(response.pageMapArtifact?.path == "pages/page-map.json")
        #expect(response.pageMapArtifact?.written == true)
        #expect(response.compiledContract?.kind == "triton.testrec.compiled-contract")
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.caseName == "login-flow")
        #expect(decoded.compiler.mode == "deterministic-offline")
        #expect(decoded.compiler.llmUsed == false)
        #expect(decoded.compiler.vlmUsed == false)
        #expect(decoded.actions.map(\.action) == ["tap", "type"])
        #expect(decoded.actions[0].targetText == "登录")
        #expect(decoded.actions[1].targetText == "用户名")
        #expect(decoded.actions[1].inputText == "alice")
        #expect(actionMap.kind == "triton.testrec.action-map")
        #expect(actionMap.rules.count == 2)
        #expect(actionMap.rules[0].action == "tap")
        #expect(actionMap.rules[0].target.label == "登录")
        #expect(actionMap.rules[0].strategy == "semantic-target")
        #expect(actionMap.rules[0].requiresReview == false)
        #expect(actionMap.rules[0].redactionRequired == false)
        #expect(actionMap.rules[0].evidence == ["source-action", "target-text"])
        #expect(actionMap.rules[1].action == "type")
        #expect(actionMap.rules[1].target.label == "用户名")
        #expect(actionMap.rules[1].evidence == ["source-action", "target-text", "input-text"])
        #expect(decoded.network.eventCount == 1)
        #expect(decoded.network.requests[0].sourcePath == "network/capture.ndjson:1")
        #expect(decoded.network.requests[0].method == "POST")
        #expect(decoded.network.requests[0].url == "/api/login")
        #expect(networkMap.kind == "triton.testrec.network-map")
        #expect(networkMap.rules.count == 1)
        #expect(networkMap.rules[0].strategy == "mock-candidate")
        #expect(networkMap.rules[0].nonBlocking == false)
        #expect(networkMap.rules[0].redactionRequired == true)
        #expect(networkMap.rules[0].match.url == "/api/login")
        #expect(pageMap.kind == "triton.testrec.page-map")
        #expect(pageMap.matchPolicy.scorer == "deterministic-fingerprint-matcher-v1")
        #expect(pageMap.pages.count == 1)
        #expect(pageMap.pages[0].id == "login")
        #expect(pageMap.pages[0].route == "login")
        #expect(pageMap.pages[0].routeSourcePath == "pages/route-events.jsonl:1")
        #expect(pageMap.pages[0].fingerprintSourcePath == "pages/fingerprints.jsonl:1")
        #expect(pageMap.pages[0].fingerprintHash == "abc123")
        #expect(pageMap.pages[0].evidence == ["route", "fingerprint", "fingerprint-hash"])
        #expect(decoded.pages.routeEventCount == 1)
        #expect(decoded.pages.fingerprintCount == 1)
        #expect(decoded.pages.matchPolicy.scorer == "deterministic-fingerprint-matcher-v1")
        #expect(decoded.pages.matchPolicy.thresholds.matched == 0.82)
        #expect(decoded.pages.matchPolicy.thresholds.assistedMatched == 0.70)
        #expect(decoded.pages.matchPolicy.thresholds.needsReview == 0.55)
        #expect(decoded.pages.matchPolicy.llmDecisionAuthority == false)
        #expect(decoded.pages.matchPolicy.vlmRole == "produce-structured-page-fingerprint")
        #expect(decoded.pages.matchPolicy.llmRole == "explain-boundary-cases-and-propose-aliases-only")
        #expect(decoded.pages.routes[0].route == "login")
        #expect(decoded.pages.routes[0].sourcePath == "pages/route-events.jsonl:1")
        #expect(decoded.pages.fingerprints[0].pageId == "login")
        #expect(decoded.pages.fingerprints[0].kind == "mock")
        #expect(decoded.pages.fingerprints[0].hash == "abc123")
        #expect(decoded.pages.fingerprints[0].sourcePath == "pages/fingerprints.jsonl:1")
    }

    @Test("match page returns deterministic evidence without LLM authority")
    func matchPageReturnsDeterministicEvidenceWithoutLLMAuthority() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try matchTritonTestCasePageFingerprint(
            path: caseURL.path,
            page: "login",
            candidateJSON: #"{"pageId":"login","route":"login","kind":"mock","hash":"abc123"}"#
        )

        #expect(response.ok == true)
        #expect(response.kind == "triton.testrec.page-fingerprint-match")
        #expect(response.scorer == "deterministic-fingerprint-matcher-v1")
        #expect(response.score == 1.0)
        #expect(response.decision == "matched")
        #expect(response.components.count == 4)
        #expect(response.components.map(\.name) == ["hash", "route", "pageId", "kind"])
        #expect(response.evidence.contains("llm:unused"))
        #expect(response.llmUsed == false)
        #expect(response.llmDecisionAuthority == false)
        #expect(response.suggestedCommands == [
            "triton testrec inspect \(shellQuotedEvidencePath(caseURL.path)) --json",
            "triton testrec proposals \(shellQuotedEvidencePath(caseURL.path)) --json",
            "triton testrec compile \(shellQuotedEvidencePath(caseURL.path)) --json",
        ])
    }

    @Test("match page downgrades weak candidate to not matched")
    func matchPageDowngradesWeakCandidateToNotMatched() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try matchTritonTestCasePageFingerprint(
            path: caseURL.path,
            page: "login",
            candidateJSON: #"{"pageId":"login","route":"login","kind":"native","hash":"different"}"#
        )

        #expect(response.score == 0.45)
        #expect(response.decision == "not-matched")
        #expect(response.components.first { $0.name == "hash" }?.evidence == "hash differs")
        #expect(response.llmDecisionAuthority == false)
    }

    @Test("match page rejects missing compiled contract")
    func matchPageRejectsMissingCompiledContract() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)

        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try matchTritonTestCasePageFingerprint(
                path: caseURL.path,
                page: "login",
                candidateJSON: #"{"pageId":"login","route":"login","kind":"mock","hash":"abc123"}"#
            )
        }

        #expect(failure?.detail.code == "missing_compiled_contract")
        #expect(failure?.detail.path == "compiled-contract.json")
    }

    @Test("HTTP match page mirrors CLI matcher")
    func httpMatchPageMirrorsCLIMatcher() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try handleTestRecorderHTTPMatchPage(body: Data("""
        {"path":"\(caseURL.path)","page":"login","candidate":{"pageId":"login","route":"login","kind":"mock","hash":"abc123"}}
        """.utf8))

        #expect(response.score == 1.0)
        #expect(response.decision == "matched")
        #expect(response.llmUsed == false)
        #expect(response.suggestedCommands == [
            "triton testrec inspect \(shellQuotedEvidencePath(caseURL.path)) --json",
            "triton testrec proposals \(shellQuotedEvidencePath(caseURL.path)) --json",
            "triton testrec compile \(shellQuotedEvidencePath(caseURL.path)) --json",
        ])
    }

    @Test("compile reports needs input when raw streams are absent")
    func compileReportsNeedsInputWithoutRawStreams() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)

        let response = try compileTritonTestCase(path: caseURL.path)

        #expect(response.status == "needs-input")
        #expect(response.summary.actionEventCount == 0)
        #expect(response.warnings.map(\.code).contains("missing_actions"))
        #expect(response.warnings.map(\.code).contains("missing_page_events"))
    }

    @Test("compile flags privacy transient network weak selector and fixed wait findings")
    func compileFlagsRawStreamQualityFindings() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeNoisyRawStreams(to: caseURL)

        let response = try compileTritonTestCase(path: caseURL.path, writeContract: true)
        let decoded = try JSONDecoder().decode(
            TKTestRecorderCompiledContract.self,
            from: Data(contentsOf: caseURL.appendingPathComponent("compiled-contract.json"))
        )
        let warningCodes = response.warnings.map(\.code)
        let findingCodes = decoded.qualityFindings.map(\.code)
        let proposals = try readCompileProposals(from: caseURL)
        let proposalKinds = proposals.map(\.proposalKind)
        let compiledContent = try String(contentsOf: caseURL.appendingPathComponent("compiled-contract.json"), encoding: .utf8)
        let replay = try replayTritonTestCaseDryRun(path: caseURL.path, platform: "android", device: nil)
        let simulatedReplay = try replayTritonTestCaseLocalSimulated(path: caseURL.path, platform: "android", device: nil)
        let matrix = try matrixTritonTestCase(
            path: caseURL.path,
            targets: "android:emulator-a,harmony:dev-a",
            executor: nil,
            targetFingerprints: nil
        )
        let simulatedMatrix = try matrixTritonTestCase(
            path: caseURL.path,
            targets: "android:emulator-a,harmony:dev-a",
            executor: "local-simulated",
            targetFingerprints: nil
        )
        let networkMap = try JSONDecoder().decode(
            TKTestRecorderNetworkMap.self,
            from: Data(contentsOf: caseURL.appendingPathComponent("network/map-rules.json"))
        )

        #expect(response.status == "compiled")
        #expect(response.networkMapArtifact?.path == "network/map-rules.json")
        #expect(response.proposalArtifact?.path == "compile-proposals.jsonl")
        #expect(response.proposalArtifact?.written == true)
        #expect(warningCodes.contains("privacy_candidate"))
        #expect(warningCodes.contains("transient_network_request"))
        #expect(warningCodes.contains("weak_selector"))
        #expect(warningCodes.contains("fixed_wait"))
        #expect(findingCodes.contains("privacy_candidate"))
        #expect(findingCodes.contains("transient_network_request"))
        #expect(findingCodes.contains("weak_selector"))
        #expect(findingCodes.contains("fixed_wait"))
        #expect(proposalKinds.contains("contract.redaction"))
        #expect(decoded.actions[0].inputText == nil)
        #expect(compiledContent.contains("secret@example.com") == false)
        #expect(replay.plannedSteps.flatMap(\.argv).contains("secret@example.com") == false)
        #expect(replay.status == "blocked")
        #expect(replay.blockers.map(\.code).contains("redaction_review_required"))
        #expect(simulatedReplay.status == "blocked")
        #expect(simulatedReplay.blockers.map(\.code).contains("redaction_review_required"))
        #expect(simulatedReplay.steps.allSatisfy { $0.status == "not-run" })
        #expect(matrix.status == "blocked")
        #expect(matrix.blockedCount == 2)
        #expect(matrix.results.allSatisfy { $0.blockers.map(\.code).contains("redaction_review_required") })
        #expect(simulatedMatrix.status == "blocked")
        #expect(simulatedMatrix.blockedCount == 2)
        #expect(simulatedMatrix.results.allSatisfy { $0.blockers.map(\.code).contains("redaction_review_required") })
        #expect(proposalKinds.contains("contract.network"))
        #expect(proposalKinds.contains("contract.selector"))
        #expect(proposalKinds.contains("contract.wait"))
        #expect(proposals.allSatisfy { $0.status == "proposed" })
        #expect(networkMap.rules.count == 1)
        #expect(networkMap.rules[0].strategy == "passthrough")
        #expect(networkMap.rules[0].nonBlocking == true)
        #expect(networkMap.rules[0].redactionRequired == false)
    }

    @Test("compile writes redacted network fixtures for business requests")
    func compileWritesRedactedNetworkFixturesForBusinessRequests() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreamsWithSensitiveNetworkBody(to: caseURL)

        let response = try compileTritonTestCase(path: caseURL.path, writeContract: true)
        let networkMap = try JSONDecoder().decode(
            TKTestRecorderNetworkMap.self,
            from: Data(contentsOf: caseURL.appendingPathComponent("network/map-rules.json"))
        )
        let rule = try #require(networkMap.rules.first)
        let fixturePath = try #require(rule.fixturePath)
        let fixtureURL = caseURL.appendingPathComponent(fixturePath)
        let fixture = try JSONDecoder().decode(
            [String: String].self,
            from: Data(contentsOf: fixtureURL)
        )
        let compiledContent = try String(
            contentsOf: caseURL.appendingPathComponent("compiled-contract.json"),
            encoding: .utf8
        )

        #expect(response.status == "compiled")
        #expect(rule.strategy == "mock-candidate")
        #expect(rule.redactionRequired == true)
        #expect(rule.fixturePath == "network/fixtures/n1.json")
        #expect(fixture["id"] == "n1")
        #expect(fixture["method"] == "POST")
        #expect(fixture["url"] == "/api/login")
        #expect(fixture["body"]?.contains("alice@example.com") == false)
        #expect(fixture["body"]?.contains("secret-token") == false)
        #expect(fixture["body"]?.contains("<redacted:email>") == true)
        #expect(fixture["body"]?.contains("<redacted:token>") == true)
        #expect(compiledContent.contains("alice@example.com") == false)
        #expect(compiledContent.contains("secret-token") == false)
        #expect(compiledContent.contains("responseBody") == false)
    }

    @Test("proposals reads compile proposal JSONL without applying changes")
    func proposalsReadsCompileProposalJSONLWithoutApplyingChanges() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeNoisyRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try inspectTritonTestCaseProposals(path: caseURL.path)

        #expect(response.ok == true)
        #expect(response.kind == "triton.testrec.proposals")
        #expect(response.proposalCount == 5)
        #expect(response.proposals.map(\.proposalKind).contains("contract.redaction"))
        #expect(response.proposals.map(\.proposalKind).contains("contract.network"))
        #expect(response.proposals.map(\.proposalKind).contains("contract.selector"))
        #expect(response.proposals.map(\.proposalKind).contains("contract.wait"))
        #expect(response.proposals.allSatisfy { $0.status == "proposed" })
        #expect(response.suggestedCommands == ["triton testrec inspect \(caseURL.path) --json"])
    }

    @Test("proposals returns empty list before compile proposals exist")
    func proposalsReturnsEmptyListBeforeCompileProposalsExist() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)

        let response = try inspectTritonTestCaseProposals(path: caseURL.path)

        #expect(response.proposalCount == 0)
        #expect(response.proposals.isEmpty)
    }

    @Test("replay dry run creates a plan without executing device actions")
    func replayDryRunCreatesPlanWithoutExecutingDeviceActions() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)
        try FileManager.default.removeItem(at: caseURL.appendingPathComponent("actions.jsonl"))

        let response = try replayTritonTestCaseDryRun(path: caseURL.path, platform: "android", device: "emulator-a")

        #expect(response.ok == true)
        #expect(response.kind == "triton.testrec.replay-dry-run")
        #expect(response.dryRun == true)
        #expect(response.platform == "android")
        #expect(response.device == "emulator-a")
        #expect(response.status == "ready")
        let contractRef = try #require(response.contractRef)
        #expect(contractRef.path == "compiled-contract.json")
        #expect(contractRef.digestAlgorithm == "fnv1a64")
        #expect(!contractRef.digest.isEmpty)
        #expect(response.pageChecks.count == 1)
        #expect(response.pageChecks[0].pageId == "login")
        #expect(response.pageChecks[0].route == "login")
        #expect(response.pageChecks[0].status == "planned")
        #expect(response.pageChecks[0].sourcePath == "compiled-contract.json:pages.fingerprints[0]")
        #expect(response.pageChecks[0].command == "testrec")
        #expect(response.pageChecks[0].argv == ["triton", "testrec", "match-page", caseURL.path, "--page", "login", "--candidate-json", "<target-fingerprint-json>", "--json"])
        #expect(response.pageChecks[0].expectedArtifacts == ["page-fingerprint-match"])
        #expect(response.pageChecks[0].stopConditions == ["page_not_matched", "page_needs_review", "page_match_conflict"])
        #expect(response.executorProfiles.map(\.id) == ["local-simulated", "local-device"])
        #expect(response.executorProfiles[0].status == "available")
        let localDevice = response.executorProfiles[1]
        #expect(localDevice.status == "unsupported")
        #expect(localDevice.mode == "device-execution")
        #expect(localDevice.nextCommand == "triton schema --command testrec --json")
        #expect(localDevice.requirements.map(\.name) == [
            "compiled-contract",
            "live-target-device",
            "device-action-execution",
            "evidence-artifact-capture",
            "network-policy-application",
        ])
        #expect(localDevice.requirements.map(\.required) == [true, true, true, true, true])
        #expect(localDevice.requirements.map(\.status) == [
            "satisfied",
            "missing",
            "missing",
            "missing",
            "missing",
        ])
        #expect(localDevice.requirements.map(\.evidence) == [
            ["compiled-contract"],
            ["target-readiness:not-wired"],
            ["act-runner:not-wired"],
            ["artifact-writer:not-wired"],
            ["network-policy:not-wired"],
        ])
        #expect(response.plannedSteps.map(\.action) == ["tap", "type"])
        #expect(response.plannedSteps.allSatisfy { $0.status == "planned" })
        #expect(response.plannedSteps[0].sourcePath == "compiled-contract.json:actions[0]")
        #expect(response.plannedSteps[0].command == "act")
        #expect(response.plannedSteps[0].argv == ["triton", "act", "tap", "--text", "登录", "--platform", "android", "--device", "emulator-a", "--json"])
        #expect(response.plannedSteps[1].argv == ["triton", "act", "type", "alice", "--platform", "android", "--device", "emulator-a", "--json"])
        #expect(response.plannedSteps[0].workflowCategories == ["action", "evidence"])
        #expect(response.blockers.isEmpty)
    }

    @Test("matrix fans out dry-run plans across targets without device commands")
    func matrixFansOutDryRunPlansAcrossTargetsWithoutDeviceCommands() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try matrixTritonTestCase(
            path: caseURL.path,
            targets: "android:emulator-a,harmony:dev-a",
            executor: nil,
            targetFingerprints: nil
        )

        #expect(response.ok == true)
        #expect(response.kind == "triton.testrec.matrix")
        #expect(response.executor == nil)
        #expect(response.status == "ready")
        #expect(response.targetCount == 2)
        #expect(response.readyCount == 2)
        #expect(response.passedCount == 0)
        #expect(response.blockedCount == 0)
        #expect(response.results.map(\.target) == ["android:emulator-a", "harmony:dev-a"])
        #expect(response.results.map(\.platform) == ["android", "harmony"])
        #expect(response.results.map(\.device) == ["emulator-a", "dev-a"])
        #expect(response.results.allSatisfy { $0.dryRun })
        #expect(response.results.allSatisfy { $0.plannedStepCount == 2 })
        #expect(response.results.allSatisfy { $0.pageCheckCount == 1 })
        #expect(response.results.allSatisfy { $0.blockers.isEmpty })
        #expect(response.results[0].suggestedCommand == "triton testrec replay \(shellQuotedEvidencePath(caseURL.path)) --platform android --device 'emulator-a' --dry-run --json")
        #expect(response.results[1].suggestedCommand == "triton testrec replay \(shellQuotedEvidencePath(caseURL.path)) --platform harmony --device 'dev-a' --dry-run --json")
        #expect(response.suggestedCommands == ["triton testrec matrix \(caseURL.path) --targets android:emulator-a,harmony:dev-a --json"])
    }


    @Test("matrix blocks unsupported capabilities instead of counting them as ready")
    func matrixBlocksUnsupportedCapabilitiesInsteadOfCountingThemAsReady() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try """
        {
          "schemaVersion": 1,
          "actions": ["tap", "drag"],
          "pages": ["route", "fingerprint"],
          "network": ["fixture"]
        }
        """.write(to: caseURL.appendingPathComponent("contract-capabilities.json"), atomically: true, encoding: .utf8)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try matrixTritonTestCase(
            path: caseURL.path,
            targets: "android:emulator-a,harmony:dev-a",
            executor: nil,
            targetFingerprints: nil
        )

        #expect(response.ok == false)
        #expect(response.status == "blocked")
        #expect(response.readyCount == 0)
        #expect(response.passedCount == 0)
        #expect(response.blockedCount == 2)
        #expect(response.results.allSatisfy { $0.status == "blocked" })
        #expect(response.results.allSatisfy {
            $0.blockers.contains { $0.code == "unsupported_capability" && $0.path == "contract-capabilities.json.actions" }
        })
    }

    @Test("matrix local simulated writes per target evidence bundles")
    func matrixLocalSimulatedWritesPerTargetEvidenceBundles() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let evidenceRoot = caseURL.deletingLastPathComponent().appendingPathComponent("matrix-evidence", isDirectory: true)
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try matrixTritonTestCase(
            path: caseURL.path,
            targets: "android:emulator-a,harmony:dev-a",
            executor: "local-simulated",
            evidenceRoot: evidenceRoot.path,
            targetFingerprints: [
                try TKJSONValue.fromJSONObject([
                    "pageId": "login",
                    "route": "login",
                    "kind": "mock",
                    "hash": "abc123",
                ]),
            ]
        )

        #expect(response.ok == true)
        #expect(response.status == "passed")
        #expect(response.executor == "local-simulated")
        #expect(response.evidenceRoot == evidenceRoot.path)
        #expect(response.passedCount == 2)
        let androidEvidence = evidenceRoot.appendingPathComponent("android-emulator-a", isDirectory: true).path
        let harmonyEvidence = evidenceRoot.appendingPathComponent("harmony-dev-a", isDirectory: true).path
        #expect(response.results.map(\.evidenceDir) == [
            androidEvidence,
            harmonyEvidence,
        ])
        #expect(response.results[0].suggestedCommand == "triton testrec replay \(shellQuotedEvidencePath(caseURL.path)) --platform android --device 'emulator-a' --executor local-simulated --evidence-dir \(shellQuotedEvidencePath(androidEvidence)) --json")
        #expect(response.results[1].suggestedCommand == "triton testrec replay \(shellQuotedEvidencePath(caseURL.path)) --platform harmony --device 'dev-a' --executor local-simulated --evidence-dir \(shellQuotedEvidencePath(harmonyEvidence)) --json")
        #expect(response.suggestedCommands.contains("triton evidence summary \(shellQuotedEvidencePath(androidEvidence)) --json"))
        #expect(response.suggestedCommands.contains("triton evidence summary \(shellQuotedEvidencePath(harmonyEvidence)) --json"))
        #expect(FileManager.default.fileExists(atPath: evidenceRoot.appendingPathComponent("android-emulator-a/run/replay-result.json").path))
        #expect(FileManager.default.fileExists(atPath: evidenceRoot.appendingPathComponent("harmony-dev-a/run/events.jsonl").path))
    }

    @Test("replay without executor requires dry run")
    func replayWithoutExecutorRequiresDryRun() throws {
        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try replayTritonTestCase(path: "/tmp/missing.tritontestcase", platform: "android", device: nil, dryRun: false)
        }

        #expect(failure?.detail.code == "dry_run_required")
        #expect(failure?.detail.path == "--dry-run")
    }

    @Test("replay local device blocks when Triton schema cannot execute platform action")
    func replayLocalDeviceBlocksWhenTritonSchemaCannotExecutePlatformAction() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let evidenceURL = caseURL.deletingLastPathComponent().appendingPathComponent("local-device-readiness-blocked.tritonevidence", isDirectory: true)
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try replayTritonTestCaseLocalDevice(
            path: caseURL.path,
            platform: "ios",
            device: "booted",
            evidenceDirectory: evidenceURL.path
        )

        #expect(response.ok == false)
        #expect(response.executor == "local-device")
        #expect(response.platform == "ios")
        #expect(response.device == "booted")
        #expect(response.status == "blocked")
        #expect(response.execution.deviceCommandsExecuted == false)
        #expect(response.execution.executorRequirements.contains {
            $0.name == "device-action-execution" && $0.required && $0.status == "missing" && $0.evidence.contains("target_capability_missing")
        })
        #expect(response.execution.executorRequirements.contains {
            $0.name == "live-target-device" && $0.required && $0.status == "not-requested" && $0.evidence.contains("blocked-before-target-resolve")
        })
        #expect(response.execution.evidence.contains("target_capability_missing"))
        #expect(response.blockers.contains {
            $0.code == "target_capability_missing" && $0.path == "triton.schema.act"
        })
        #expect(response.blockers.map(\.code).contains("target_not_found") == false)
        #expect(response.steps.allSatisfy { $0.deviceCommandExecuted == false })
        #expect(response.steps.allSatisfy { $0.failure?.code == "target_capability_missing" })
        #expect(response.pageResults.map(\.status) == ["not-run"])
        #expect(response.evidenceDir == evidenceURL.path)
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("manifest.json").path))
        let result = try JSONDecoder().decode(
            TKTestRecorderReplayRunResponse.self,
            from: Data(contentsOf: evidenceURL.appendingPathComponent("run/replay-result.json"))
        )
        #expect(result.blockers.map(\.code).contains("target_capability_missing"))
        let events = try String(contentsOf: evidenceURL.appendingPathComponent("run/events.jsonl"), encoding: .utf8)
        #expect(events.contains(#""event":"testrec.replay.started""#))
        #expect(events.contains(#""local-device""#))
        #expect(events.contains(#""failureCode":"target_capability_missing""#))
        #expect(events.contains("target_capability_missing"))
    }

    @Test("replay local device blocks when target is not resolved")
    func replayLocalDeviceBlocksWhenTargetIsNotResolved() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let evidenceURL = caseURL.deletingLastPathComponent().appendingPathComponent("local-device-blocked.tritonevidence", isDirectory: true)
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try replayTritonTestCaseLocalDevice(
            path: caseURL.path,
            platform: "android",
            device: "missing-emulator",
            evidenceDirectory: evidenceURL.path
        )

        #expect(response.ok == false)
        #expect(response.kind == "triton.testrec.replay-result")
        #expect(response.dryRun == false)
        #expect(response.executor == "local-device")
        #expect(response.platform == "android")
        #expect(response.device == "missing-emulator")
        #expect(response.status == "blocked")
        #expect(response.execution.mode == "device-execution")
        #expect(response.execution.requiresDevice == true)
        #expect(response.execution.deviceCommandsExecuted == false)
        #expect(response.execution.llmUsed == false)
        #expect(response.execution.vlmUsed == false)
        #expect(response.execution.networkPolicyMode == "not-applied")
        #expect(response.execution.executorRequirements.contains {
            $0.name == "live-target-device" && $0.required && $0.status == "missing" && $0.evidence.contains("target_not_found")
        })
        #expect(response.execution.executorRequirements.contains {
            $0.name == "device-action-execution"
                && $0.required
                && $0.status == "missing"
                && $0.evidence.contains("observe-schema:platform-android-ready")
                && $0.evidence.contains("act-schema:platform-android-ready")
        })
        #expect(response.execution.evidence.contains("target_not_found"))
        #expect(response.blockers.contains {
            $0.code == "target_not_found" && $0.path == "--device"
        })
        #expect(response.blockers.map(\.code).contains("target_capability_missing") == false)
        #expect(response.steps.map(\.status) == ["not-run", "not-run"])
        #expect(response.steps.allSatisfy { $0.deviceCommandExecuted == false })
        #expect(response.steps.allSatisfy { $0.failure?.code == "target_not_found" })
        #expect(response.pageResults.map(\.status) == ["not-run"])
        #expect(response.evidenceDir == evidenceURL.path)
        #expect(response.artifactRefs == ["run/replay-result.json", "run/events.jsonl", "run/run.json"])
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("run/replay-result.json").path))
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("run/events.jsonl").path))
        let manifest = try JSONDecoder().decode(
            TKEvidenceManifest.self,
            from: Data(contentsOf: evidenceURL.appendingPathComponent("manifest.json"))
        )
        let runMetadata = try JSONDecoder().decode(
            TKTestRunMetadata.self,
            from: Data(contentsOf: evidenceURL.appendingPathComponent("run/run.json"))
        )
        #expect(manifest.ok == false)
        #expect(manifest.run?.eventsPath == "run/events.jsonl")
        #expect(manifest.run?.eventCount == response.evidenceSummary.expectedEventCount)
        #expect(manifest.run?.summary?.runID == runMetadata.runID)
        #expect(manifest.run?.summary?.verdict == .blocked)
        #expect(manifest.run?.summary?.stepCount == response.steps.count)
        #expect(manifest.run?.summary?.frictionCount == response.blockers.count)
        let result = try JSONDecoder().decode(
            TKTestRecorderReplayRunResponse.self,
            from: Data(contentsOf: evidenceURL.appendingPathComponent("run/replay-result.json"))
        )
        #expect(result.executor == "local-device")
        #expect(result.blockers.map(\.code).contains("target_not_found"))
        let events = try String(contentsOf: evidenceURL.appendingPathComponent("run/events.jsonl"), encoding: .utf8)
        #expect(events.contains(#""event":"testrec.replay.finished""#))
        #expect(events.contains(#""failureCode":"target_not_found""#))
        #expect(events.contains("target_not_found"))
        #expect(events.contains("observe-schema:platform-android-ready"))
        #expect(events.contains("act-schema:platform-android-ready"))
    }

    @Test("replay local simulated executor produces replay result without device commands")
    func replayLocalSimulatedExecutorProducesReplayResult() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let evidenceURL = caseURL.deletingLastPathComponent().appendingPathComponent("login.tritonevidence", isDirectory: true)
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreamsWithSensitiveNetworkBody(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try replayTritonTestCaseLocalSimulated(
            path: caseURL.path,
            platform: "android",
            device: "emulator-a",
            evidenceDirectory: evidenceURL.path,
            targetFingerprints: [
                try TKJSONValue.fromJSONObject([
                    "pageId": "login",
                    "route": "login",
                    "kind": "mock",
                    "hash": "abc123",
                ]),
            ]
        )

        #expect(response.ok == true)
        #expect(response.kind == "triton.testrec.replay-result")
        #expect(response.dryRun == false)
        #expect(response.executor == "local-simulated")
        #expect(response.status == "passed")
        let contractRef = try #require(response.contractRef)
        #expect(contractRef.path == "compiled-contract.json")
        #expect(contractRef.digestAlgorithm == "fnv1a64")
        #expect(!contractRef.digest.isEmpty)
        #expect(response.evidenceDir == evidenceURL.path)
        #expect(response.artifactRefs == [
            "run/replay-result.json",
            "run/events.jsonl",
            "run/run.json",
            "pages/target-fingerprints.json",
            "network/fixtures/n1.json",
        ])
        #expect(response.execution.mode == "offline-simulated")
        #expect(response.execution.requiresDevice == false)
        #expect(response.execution.deviceCommandsExecuted == false)
        #expect(response.execution.llmUsed == false)
        #expect(response.execution.vlmUsed == false)
        #expect(response.execution.networkPolicyMode == "simulated-projection")
        #expect(response.execution.stepStatusTaxonomy == ["executed", "failed", "skipped", "blocked", "not-run", "simulated-passed"])
        #expect(response.execution.executorRequirements.contains {
            $0.name == "compiled-contract" && $0.required && $0.status == "satisfied"
        })
        #expect(response.execution.executorRequirements.contains {
            $0.name == "live-target-device" && !$0.required && $0.status == "not-required"
        })
        #expect(response.execution.executorRequirements.contains {
            $0.name == "device-action-execution" && !$0.required && $0.status == "not-required"
        })
        #expect(response.execution.executorRequirements.contains {
            $0.name == "evidence-artifact-capture" && !$0.required && $0.status == "satisfied"
        })
        #expect(response.execution.evidence.contains("no-device-command-executed"))
        #expect(response.execution.evidence.contains("network-map-simulated"))
        #expect(response.evidenceSummary.expectedEventCount == 6)
        #expect(response.evidenceSummary.pageEventCount == 1)
        #expect(response.evidenceSummary.networkEventCount == 1)
        #expect(response.evidenceSummary.stepEventCount == 2)
        #expect(response.evidenceSummary.artifactRefCount == 5)
        #expect(response.evidenceSummary.pageArtifactRefCount == 1)
        #expect(response.evidenceSummary.networkArtifactRefCount == 1)
        #expect(response.evidenceSummary.stepArtifactRefCount == 0)
        #expect(response.evidenceSummary.blockerCount == 0)
        #expect(response.evidenceSummary.statusConsistent == true)
        #expect(response.pageResults.count == 1)
        #expect(response.pageResults[0].status == "matched")
        #expect(response.pageResults[0].matchDecision == "matched")
        #expect(response.pageResults[0].matchScore == 1.0)
        #expect(response.pageResults[0].artifactRefs == ["pages/target-fingerprints.json"])
        #expect(response.pageResults[0].evidence.contains("llm:unused"))
        #expect(response.networkResults.count == 1)
        #expect(response.networkResults[0].status == "simulated-mock-candidate")
        #expect(response.networkResults[0].strategy == "mock-candidate")
        #expect(response.networkResults[0].redactionRequired == true)
        #expect(response.networkResults[0].fixturePath == "network/fixtures/n1.json")
        #expect(response.networkResults[0].artifactRefs == ["network/fixtures/n1.json"])
        #expect(response.networkResults[0].evidence.contains("network-map"))
        #expect(response.networkResults[0].evidence.contains("network-fixture"))
        #expect(response.steps.map(\.action) == ["tap", "type"])
        #expect(response.steps.allSatisfy { $0.status == "simulated-passed" })
        #expect(response.steps.allSatisfy { $0.deviceCommandExecuted == false })
        #expect(response.steps.allSatisfy { $0.artifactRefs.isEmpty })
        #expect(response.steps.allSatisfy { $0.failure == nil })
        #expect(response.steps[0].argv == ["triton", "act", "tap", "--text", "登录", "--platform", "android", "--device", "emulator-a", "--json"])
        #expect(response.steps[0].evidence.contains("no-device-command-executed"))
        #expect(response.blockers.isEmpty)
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("run/replay-result.json").path))
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("run/events.jsonl").path))
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("pages/target-fingerprints.json").path))
        #expect(FileManager.default.fileExists(atPath: evidenceURL.appendingPathComponent("network/fixtures/n1.json").path))
        let manifest = try JSONDecoder().decode(
            TKEvidenceManifest.self,
            from: Data(contentsOf: evidenceURL.appendingPathComponent("manifest.json"))
        )
        let runMetadata = try JSONDecoder().decode(
            TKTestRunMetadata.self,
            from: Data(contentsOf: evidenceURL.appendingPathComponent("run/run.json"))
        )
        #expect(manifest.ok == true)
        #expect(manifest.run?.eventsPath == "run/events.jsonl")
        #expect(manifest.run?.eventCount == response.evidenceSummary.expectedEventCount)
        #expect(manifest.run?.summary?.runID == runMetadata.runID)
        #expect(manifest.run?.summary?.verdict == .success)
        #expect(manifest.run?.summary?.stepCount == response.steps.count)
        #expect(manifest.run?.summary?.frictionCount == response.blockers.count)
        #expect(manifest.artifacts.map(\.path).contains("run/replay-result.json"))
        #expect(manifest.artifacts.contains {
            $0.kind == "testrec.page.target-fingerprints" && $0.path == "pages/target-fingerprints.json"
        })
        #expect(manifest.artifacts.contains {
            $0.kind == "testrec.network.fixture" && $0.path == "network/fixtures/n1.json" && $0.redactionStatus == "redacted"
        })
        let summary = try summarizeEvidenceBundle(input: evidenceURL.path)
        #expect(summary.ok == true)
        #expect(summary.run?.summary?.verdict == .success)
        #expect(summary.run?.summary?.stepCount == response.steps.count)
        #expect(summary.artifacts.map(\.path).contains("run/replay-result.json"))
        #expect(summary.artifacts.map(\.path).contains("network/fixtures/n1.json"))
        let targetFingerprints = try String(contentsOf: evidenceURL.appendingPathComponent("pages/target-fingerprints.json"), encoding: .utf8)
        #expect(targetFingerprints.contains(#""kind" : "triton.testrec.target-fingerprints""#))
        #expect(targetFingerprints.contains(#""hash" : "abc123""#))
        let events = try String(contentsOf: evidenceURL.appendingPathComponent("run/events.jsonl"), encoding: .utf8)
        #expect(events.contains("testrec.replay.step"))
        #expect(events.contains("testrec.replay.network"))
        #expect(events.contains("testrec.replay.finished"))
        #expect(events.contains(#""category":"step""#))
        #expect(events.contains(#""category":"network""#))
        #expect(events.contains(#"pages\/target-fingerprints.json"#))
        #expect(events.contains(#"network\/fixtures\/n1.json"#))
        #expect(events.contains(#""contractRef""#))
        #expect(events.contains(contractRef.digest))
        #expect(events.contains(#""subjectID":"a1""#))
        #expect(events.contains(#""timestamp":"#))
        #expect(events.contains("matched"))
    }

    @Test("replay local simulated rejects missing network fixture artifact")
    func replayLocalSimulatedRejectsMissingNetworkFixtureArtifact() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        let evidenceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-testrec-evidence-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        defer { try? FileManager.default.removeItem(at: evidenceURL) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreamsWithSensitiveNetworkBody(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)
        try FileManager.default.removeItem(at: caseURL.appendingPathComponent("network/fixtures/n1.json"))

        let failure = #expect(throws: TKTestRecorderValidationFailure.self) {
            _ = try replayTritonTestCaseLocalSimulated(
                path: caseURL.path,
                platform: "android",
                device: nil,
                evidenceDirectory: evidenceURL.path
            )
        }

        #expect(failure?.detail.code == "missing_network_fixture")
        #expect(failure?.detail.path == "network/fixtures/n1.json")
    }

    @Test("replay local simulated blocks when target fingerprint does not match")
    func replayLocalSimulatedBlocksWhenTargetFingerprintDoesNotMatch() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)

        let response = try replayTritonTestCaseLocalSimulated(
            path: caseURL.path,
            platform: "android",
            device: nil,
            targetFingerprints: [
                try TKJSONValue.fromJSONObject([
                    "pageId": "home",
                    "route": "home",
                    "kind": "native",
                    "hash": "different",
                ]),
            ]
        )

        #expect(response.ok == false)
        #expect(response.status == "blocked")
        #expect(response.pageResults[0].status == "not-matched")
        #expect(response.pageResults[0].matchDecision == "not-matched")
        #expect(response.blockers.map(\.code).contains("page_not_matched"))
        #expect(response.steps.allSatisfy { $0.status == "not-run" })
    }

    @Test("replay dry run blocks when compiled contract is absent")
    func replayDryRunBlocksWithoutCompiledContract() throws {
        let caseURL = try makeTemporaryCaseDirectory()
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeValidManifest(to: caseURL)
        try writeValidCapabilities(to: caseURL)
        try writeRawStreams(to: caseURL)

        let response = try replayTritonTestCaseDryRun(path: caseURL.path, platform: "android", device: nil)

        #expect(response.status == "blocked")
        #expect(response.pageChecks.isEmpty)
        #expect(response.plannedSteps.isEmpty)
        #expect(response.blockers.map(\.code).contains("missing_compiled_contract"))
    }
}

private func writeNoisyRawStreams(to caseURL: URL) throws {
    try """
    {"id":"a1","kind":"type","target":{"selector":"#input"},"text":"secret@example.com"}
    {"id":"a2","kind":"tap","target":{"selector":"div:nth-child(3)"}}
    {"id":"a3","kind":"wait","durationMs":5000}
    """.write(to: caseURL.appendingPathComponent("actions.jsonl"), atomically: true, encoding: .utf8)

    let networkURL = caseURL.appendingPathComponent("network", isDirectory: true)
    try FileManager.default.createDirectory(at: networkURL, withIntermediateDirectories: true)
    try """
    {"id":"n1","url":"/analytics/pixel?session=123","method":"GET"}
    """.write(to: networkURL.appendingPathComponent("capture.ndjson"), atomically: true, encoding: .utf8)

    let pagesURL = caseURL.appendingPathComponent("pages", isDirectory: true)
    try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
    try """
    {"id":"p1","route":"login"}
    """.write(to: pagesURL.appendingPathComponent("route-events.jsonl"), atomically: true, encoding: .utf8)
    try """
    {"pageId":"login","route":"login","fingerprint":{"kind":"mock","hash":"abc123"}}
    """.write(to: pagesURL.appendingPathComponent("fingerprints.jsonl"), atomically: true, encoding: .utf8)
}

private func readCompileProposals(from caseURL: URL) throws -> [TKTestRecorderCompileProposal] {
    let data = try Data(contentsOf: caseURL.appendingPathComponent("compile-proposals.jsonl"))
    let content = String(data: data, encoding: .utf8) ?? ""
    return try content
        .split(whereSeparator: { $0.isNewline })
        .map { line in
            try JSONDecoder().decode(TKTestRecorderCompileProposal.self, from: Data(line.utf8))
        }
}

private func makeTemporaryCaseDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-testrec-\(UUID().uuidString)", isDirectory: true)
    let caseURL = root.appendingPathComponent("login.tritontestcase", isDirectory: true)
    try FileManager.default.createDirectory(at: caseURL, withIntermediateDirectories: true)
    return caseURL
}

private func writeValidManifest(to caseURL: URL) throws {
    try """
    {
      "schemaVersion": 1,
      "kind": "triton.testcase.v1",
      "name": "login-flow",
      "sourcePlatform": "ios"
    }
    """.write(to: caseURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
}

private func writeValidCapabilities(to caseURL: URL) throws {
    try """
    {
      "schemaVersion": 1,
      "actions": ["tap", "type", "scroll"],
      "pages": ["route", "ax", "fingerprint"],
      "network": ["fixture", "passthrough"]
    }
    """.write(to: caseURL.appendingPathComponent("contract-capabilities.json"), atomically: true, encoding: .utf8)
}

private func writeRawStreams(to caseURL: URL) throws {
    try """
    {"id":"a1","type":"tap","target":{"label":"登录"}}
    {"id":"a2","kind":"type","target":{"label":"用户名"},"text":"alice"}
    """.write(to: caseURL.appendingPathComponent("actions.jsonl"), atomically: true, encoding: .utf8)

    let networkURL = caseURL.appendingPathComponent("network", isDirectory: true)
    try FileManager.default.createDirectory(at: networkURL, withIntermediateDirectories: true)
    try """
    {"id":"n1","url":"/api/login","method":"POST"}
    """.write(to: networkURL.appendingPathComponent("capture.ndjson"), atomically: true, encoding: .utf8)

    let pagesURL = caseURL.appendingPathComponent("pages", isDirectory: true)
    try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
    try """
    {"id":"p1","route":"login"}
    """.write(to: pagesURL.appendingPathComponent("route-events.jsonl"), atomically: true, encoding: .utf8)
    try """
    {"pageId":"login","route":"login","fingerprint":{"kind":"mock","hash":"abc123"}}
    """.write(to: pagesURL.appendingPathComponent("fingerprints.jsonl"), atomically: true, encoding: .utf8)
}

private func writeRawStreamsWithSensitiveNetworkBody(to caseURL: URL) throws {
    try writeRawStreams(to: caseURL)
    let networkURL = caseURL.appendingPathComponent("network", isDirectory: true)
    try """
    {"id":"n1","url":"/api/login","method":"POST","statusCode":200,"responseBody":"email=alice@example.com token=secret-token name=Alice"}
    """.write(to: networkURL.appendingPathComponent("capture.ndjson"), atomically: true, encoding: .utf8)
}
