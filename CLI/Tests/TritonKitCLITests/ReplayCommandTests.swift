import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct ReplayCommandTests {
    @Test("invalid dry-run JSON replay emits one error envelope")
    func invalidDryRunJSONReplayEmitsOneErrorEnvelope() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-replay-invalid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let planURL = temp.appendingPathComponent("ambiguous-tap.tritonplan")
        try """
        {
          "schemaVersion": 1,
          "name": "invalid-ambiguous-tap",
          "variables": [],
          "steps": [
            { "action": "tap", "text": "login", "oid": 42 }
          ]
        }
        """.write(to: planURL, atomically: true, encoding: .utf8)

        let result = try runTriton(["replay", planURL.path, "--dry-run", "--json"])
        let nonEmptyStreams = [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let output = try #require(nonEmptyStreams.first)
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.utf8))

        #expect(result.exitCode != 0)
        #expect(nonEmptyStreams.count == 1)
        #expect(response.ok == false)
        #expect(response.error.code == "validation_failed")
        #expect(response.error.message.contains("Replay tap step requires exactly one selector"))
    }

    @Test("dry-run replay preserves network proxy session evidence argv")
    func dryRunReplayPreservesNetworkProxySessionEvidenceArgv() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-replay-proxy-session-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let planURL = temp.appendingPathComponent("network.tritonplan")
        try """
        {
          "schemaVersion": 1,
          "name": "network-flow",
          "variables": ["platform"],
          "steps": [
            {
              "action": "evidence",
              "name": "network-capture",
              "output": "\(temp.path)/network.tritonevidence",
              "include": "network.proxy-session",
              "proxySession": "\(temp.path)/${platform}-proxy"
            }
          ]
        }
        """.write(to: planURL, atomically: true, encoding: .utf8)

        let result = try runTriton(["replay", planURL.path, "--dry-run", "--var", "platform=android", "--json"])
        let response = try JSONDecoder().decode(TKReplayResult.self, from: Data(result.stdout.utf8))
        let step = try #require(response.steps.first)

        #expect(result.exitCode == 0)
        #expect(step.argv.contains("--proxy-session"))
        #expect(step.argv.contains("\(temp.path)/android-proxy"))
        #expect(step.expectedArtifacts.contains("network.proxy-session"))
        #expect(step.expectedArtifacts.contains("network-capture"))
    }

    @Test("dry-run replay preserves network proxy lifecycle argv")
    func dryRunReplayPreservesNetworkProxyLifecycleArgv() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-replay-proxy-lifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let planURL = temp.appendingPathComponent("network-lifecycle.tritonplan")
        try """
        {
          "schemaVersion": 1,
          "name": "network-lifecycle",
          "variables": ["platform", "device", "certificate", "auditRecord"],
          "steps": [
            {
              "action": "proxy-probe",
              "platform": "${platform}",
              "device": "${device}"
            },
            {
              "action": "proxy-cert-plan",
              "platform": "${platform}",
              "device": "${device}",
              "certificate": "${certificate}"
            },
            {
              "action": "proxy-cert-install",
              "platform": "${platform}",
              "device": "${device}",
              "certificate": "${certificate}",
              "auditRecord": "${auditRecord}"
            },
            {
              "action": "proxy-serve",
              "proxy": "127.0.0.1:19431",
              "mode": "mock",
              "output": "\(temp.path)/${platform}-proxy",
              "mockRules": "\(temp.path)/${platform}-mock-rules.json",
              "policyRules": "\(temp.path)/${platform}-policy-rules.json"
            },
            {
              "action": "proxy-start",
              "platform": "${platform}",
              "device": "${device}",
              "proxy": "127.0.0.1:19431",
              "mode": "mock",
              "output": "\(temp.path)/${platform}-proxy"
            },
            {
              "action": "proxy-serve",
              "proxy": "127.0.0.1:19432",
              "mode": "throttle",
              "output": "\(temp.path)/${platform}-throttle-proxy",
              "throttleMs": 250
            },
            {
              "action": "proxy-status",
              "platform": "${platform}",
              "device": "${device}"
            },
            {
              "action": "proxy-stop",
              "platform": "${platform}",
              "device": "${device}",
              "restore": true
            }
          ]
        }
        """.write(to: planURL, atomically: true, encoding: .utf8)

        let plan = try readReplayPlan(from: planURL.path)
        let response = try await runReplayPlan(
            plan,
            variables: [
                "platform": "android",
                "device": "emulator-5554",
                "certificate": "/tmp/triton-proxy-ca.cer",
                "auditRecord": "ticket-123",
            ],
            dryRun: true,
            target: "triton:local",
            host: "127.0.0.1",
            port: 19421
        )

        #expect(response.steps.map(\.action) == [
            "proxy-probe",
            "proxy-cert-plan",
            "proxy-cert-install",
            "proxy-serve",
            "proxy-start",
            "proxy-serve",
            "proxy-status",
            "proxy-stop",
        ])
        #expect(response.steps[0].argv == [
            "triton", "device", "proxy", "probe",
            "--platform", "android",
            "--device", "emulator-5554",
            "--plan-only",
            "--json",
        ])
        #expect(response.steps[0].expectedArtifacts.contains("host-device-proxy"))
        #expect(response.steps[1].argv == [
            "triton", "device", "proxy", "cert", "plan",
            "--platform", "android",
            "--device", "emulator-5554",
            "--certificate", "/tmp/triton-proxy-ca.cer",
            "--json",
        ])
        #expect(response.steps[1].expectedArtifacts.contains("proxy-certificate"))
        #expect(response.steps[2].argv == [
            "triton", "device", "proxy", "cert", "install",
            "--platform", "android",
            "--device", "emulator-5554",
            "--certificate", "/tmp/triton-proxy-ca.cer",
            "--confirm",
            "--audit-record", "ticket-123",
            "--execute-runner",
            "--json",
        ])
        #expect(response.steps[2].expectedArtifacts.contains("proxy-certificate"))
        #expect(response.steps[3].argv == [
            "triton", "device", "proxy", "serve",
            "--listen", "127.0.0.1:19431",
            "--output", "\(temp.path)/android-proxy",
            "--mode", "mock",
            "--mock-rules", "\(temp.path)/android-mock-rules.json",
            "--policy-rules", "\(temp.path)/android-policy-rules.json",
            "--jsonl",
        ])
        #expect(response.steps[4].argv.contains("--plan-only"))
        #expect(response.steps[4].argv.contains("emulator-5554"))
        #expect(response.steps[4].argv.contains("--mock-rules") == false)
        #expect(response.steps[4].argv.contains("--policy-rules") == false)
        #expect(response.steps[5].argv == [
            "triton", "device", "proxy", "serve",
            "--listen", "127.0.0.1:19432",
            "--output", "\(temp.path)/android-throttle-proxy",
            "--mode", "throttle",
            "--throttle-ms", "250",
            "--jsonl",
        ])
        #expect(response.steps[6].argv == [
            "triton", "device", "proxy", "status",
            "--platform", "android",
            "--device", "emulator-5554",
            "--json",
        ])
        #expect(response.steps[6].expectedArtifacts.contains("host-device-proxy"))
        #expect(response.steps[6].argv.contains("--plan-only") == false)
        #expect(response.steps[7].argv.contains("--restore"))
    }

    @Test("replay archives proxy session evidence after a failed step")
    func replayArchivesProxySessionEvidenceAfterFailedStep() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-replay-proxy-failure-archive-\(UUID().uuidString)", isDirectory: true)
        let session = temp.appendingPathComponent("android-proxy", isDirectory: true)
        let output = temp.appendingPathComponent("failure-network.tritonevidence", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)

        let captureURL = session.appendingPathComponent("requests.ndjson")
        try Data(#"{"event":"proxy.serve.request","method":"GET","url":"https://example.test/failure","redaction":"headers-names-only"}"#.utf8)
            .write(to: captureURL, options: .atomic)
        let state = NetworkProxySessionStatePayload(
            schemaVersion: "triton.proxy.session.v1",
            platform: "android",
            target: "emulator-5554",
            captureMode: "block",
            proxyEndpoint: "127.0.0.1:19431",
            configured: true,
            visibility: .partial,
            limitations: ["proxy_visibility_limited"],
            artifacts: [NetworkProxyArtifact(kind: "network-capture", path: captureURL.path, bytes: nil)],
            restoreSnapshotPath: nil,
            sourceCommands: ["adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:19431"]
        )
        try prettyEncodedData(state).write(to: session.appendingPathComponent("session-state.json"), options: .atomic)

        let plan = TKReplayPlan(
            name: "android-network-failure",
            steps: [
                TKReplayPlanStep(action: .wait, text: "Home", timeout: 1),
                TKReplayPlanStep(action: .tap, text: "Retry"),
                TKReplayPlanStep(
                    action: .evidence,
                    name: "network-after-failure",
                    output: output.path,
                    include: "status,network.proxy-session,screenshot",
                    proxySession: session.path
                ),
            ]
        )

        let archive = try #require(await replayProxyStateArchiveAfterFailure(
            plan: plan,
            variables: [:],
            failedStepIndex: 1,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1
        ))

        #expect(archive.index == 3)
        #expect(archive.action == "evidence")
        #expect(archive.ok)
        #expect(archive.argv == [
            "triton", "evidence", "capture",
            "--case", "network-after-failure",
            "--output", output.path,
            "--include", "network.proxy-session",
            "--proxy-session", session.path,
            "--note", "Replay failed; archived existing proxy session state only.",
            "--json",
        ])

        let manifest = try #require(archive.evidence)
        #expect(manifest.artifacts.map(\.kind) == ["network.proxy-session", "network-capture"])
        #expect(manifest.primaryArtifacts.map(\.kind).first == "network-capture")
        #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("artifacts/network/session-state.json").path))
        #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("artifacts/network/requests.ndjson").path))
    }

    @Test("replay suggested commands route failed waits to find snapshot and evidence summary")
    func replaySuggestedCommandsRouteWaitFailures() {
        let priorEvidence = TKEvidenceManifest(
            ok: true,
            createdAt: "2026-05-31T00:00:00Z",
            output: "/tmp/login.tritonevidence",
            artifacts: [
                TKEvidenceArtifact(kind: "status", path: "status.json", contentType: "application/json"),
                TKEvidenceArtifact(kind: "screenshot", path: "screenshot.png", contentType: "image/png"),
            ],
            cli: TKEvidenceCLI(version: "test")
        )
        let steps = [
            TKReplayStepResult(
                index: 1,
                action: "evidence",
                ok: true,
                dryRun: false,
                elapsedMs: 5,
                command: ["triton", "evidence", "capture", "--case", "login", "--output", "/tmp/login.tritonevidence", "--json"],
                evidence: priorEvidence
            ),
            TKReplayStepResult(
                index: 2,
                action: "wait",
                ok: false,
                dryRun: false,
                elapsedMs: 10,
                command: ["triton", "wait", "--text", "Home", "--json"],
                wait: TKWaitResult(
                    ok: false,
                    matched: false,
                    condition: "text",
                    query: "Home",
                    timedOut: true,
                    elapsedMs: 10,
                    pollCount: 2,
                    timeoutSeconds: 5,
                    intervalSeconds: 1
                )
            ),
        ]

        let commands = replaySuggestedCommands(
            steps: steps,
            failedStepIndex: 2
        )
        let failureCode = replayFailureCode(
            steps: steps,
            failedStepIndex: 2
        )
        let failureRecoveryCategories = replayFailureRecoveryCategories(
            steps: steps,
            failedStepIndex: 2
        )
        let failureError = replayFailureError(
            steps: steps,
            failedStepIndex: 2
        )
        let recovery = replayRecoveryCommands(
            steps: steps,
            failedStepIndex: 2
        )

        #expect(failureCode == "timeout")
        #expect(failureError == nil)
        #expect(failureRecoveryCategories == ["verify"])
        #expect(commands == [
            "triton act find 'Home' --all --json",
            "triton debug snapshot --json",
            "triton evidence summary '/tmp/login.tritonevidence' --json",
            "triton evidence inspect '/tmp/login.tritonevidence' --json",
        ])
        #expect(recovery.map(\.category) == ["act", "diagnose", "archive", "archive"])
    }

    @Test("replay result exposes recovery proposal for failed wait steps")
    func replayResultExposesRecoveryProposalForFailedWaitSteps() throws {
        let priorEvidence = TKEvidenceManifest(
            ok: true,
            createdAt: "2026-05-31T00:00:00Z",
            output: "/tmp/login.tritonevidence",
            artifacts: [
                TKEvidenceArtifact(kind: "status", path: "status.json", contentType: "application/json"),
                TKEvidenceArtifact(kind: "screenshot", path: "screenshot.png", contentType: "image/png"),
            ],
            cli: TKEvidenceCLI(version: "test")
        )
        let steps = [
            TKReplayStepResult(
                index: 1,
                action: "evidence",
                ok: true,
                dryRun: false,
                elapsedMs: 5,
                command: ["triton", "evidence", "capture", "--case", "login", "--output", "/tmp/login.tritonevidence", "--json"],
                evidence: priorEvidence
            ),
            TKReplayStepResult(
                index: 2,
                action: "wait",
                ok: false,
                dryRun: false,
                elapsedMs: 10,
                command: ["triton", "wait", "--text", "Home", "--json"],
                wait: TKWaitResult(
                    ok: false,
                    matched: false,
                    condition: "text",
                    query: "Home",
                    timedOut: true,
                    elapsedMs: 10,
                    pollCount: 2,
                    timeoutSeconds: 5,
                    intervalSeconds: 1
                )
            ),
        ]
        let result = TKReplayResult(
            ok: false,
            dryRun: false,
            planName: "login-flow",
            stepCount: 2,
            executedCount: 2,
            failedStepIndex: 2,
            elapsedMs: 15,
            steps: steps,
            suggestedCommands: replaySuggestedCommands(steps: steps, failedStepIndex: 2),
            recoveryCommands: replayRecoveryCommands(steps: steps, failedStepIndex: 2)
        )

        let proposal = try #require(result.recoveryProposal)
        #expect(proposal.schemaVersion == 1)
        #expect(proposal.kind == "triton.replay.recovery-proposal")
        #expect(proposal.trigger == "replay_step_failed")
        #expect(proposal.planName == "login-flow")
        #expect(proposal.failedStepIndex == 2)
        #expect(proposal.failureCode == "timeout")
        #expect(proposal.diagnosis.type == "timeout")
        #expect(proposal.diagnosis.phase == "wait")
        #expect(proposal.diagnosis.evidenceRefs == [
            "steps[2]",
            "steps[2].wait",
            "steps[1].evidence",
            "failurePrimaryArtifacts[]",
        ])
        #expect(proposal.proposal.action == "inspect_recovery_commands")
        #expect(proposal.proposal.policyDecision == "requires_review")
        #expect(proposal.proposal.command == ["stop"])
        #expect(proposal.nextActions.map(\.category) == ["act", "diagnose", "archive", "archive"])
        #expect(proposal.nextActions.first?.code == "run_recovery_command")
        #expect(proposal.nextActions.first?.command == "triton act find 'Home' --all --json")
        #expect(proposal.evidenceRefs == proposal.diagnosis.evidenceRefs)

        let encoded = try JSONEncoder().encode(result)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "recoveryProposal")
        let legacyJSON = try JSONSerialization.data(withJSONObject: json)
        let legacyResult = try JSONDecoder().decode(TKReplayResult.self, from: legacyJSON)

        #expect(legacyResult.recoveryProposal == proposal)
    }

    @Test("replay failure helper preserves underlying error codes")
    func replayFailureHelperPreservesUnderlyingErrorCodes() throws {
        let serverDetail = TKCLIErrorDetail(
            code: "target_unavailable",
            message: "Target disconnected",
            hint: "Reconnect target"
        )
        let serverError = CLIHTTPError(
            statusCode: 503,
            data: try JSONEncoder().encode(TKCLIErrorResponse(error: serverDetail))
        )
        let runtimeStep = TKReplayPlanStep(action: .tap, text: "Home")
        let runtimeFailure = replayFailureStepResult(
            step: runtimeStep,
            index: 1,
            command: ["triton", "tap", "Home", "--json"],
            error: serverError,
            startedAt: Date(timeIntervalSince1970: 0),
            host: "127.0.0.1",
            port: 19421
        )

        #expect(runtimeFailure.failureCode == "target_unavailable")
        #expect(runtimeFailure.message == "Target disconnected")
        #expect(runtimeFailure.error?.code == "target_unavailable")

        let artifactStep = TKReplayPlanStep(action: .screenshot, output: "/root/denied.png")
        let artifactFailure = replayFailureStepResult(
            step: artifactStep,
            index: 2,
            command: ["triton", "screenshot", "--output", "/root/denied.png", "--json"],
            error: CocoaError(.fileWriteNoPermission),
            startedAt: Date(timeIntervalSince1970: 0),
            host: "127.0.0.1",
            port: 19421
        )

        #expect(artifactFailure.failureCode == "artifact_write_failed")
        #expect(artifactFailure.error?.code == "artifact_write_failed")

        let timeoutStep = TKReplayPlanStep(action: .wait, text: "Home")
        let timeoutFailure = replayFailureStepResult(
            step: timeoutStep,
            index: 3,
            command: ["triton", "wait", "--text", "Home", "--json"],
            error: RuntimeRequestTimeoutError(requestType: "accessibility"),
            startedAt: Date(timeIntervalSince1970: 0),
            host: "127.0.0.1",
            port: 19421
        )

        #expect(timeoutFailure.failureCode == "timeout")
        #expect(timeoutFailure.error?.code == "timeout")

        let failureError = replayFailureError(
            steps: [runtimeFailure],
            failedStepIndex: 1
        )
        #expect(failureError?.code == "target_unavailable")
    }

    @Test("replay recovery commands include failureError nextAction when present")
    func replayRecoveryCommandsIncludeFailureErrorNextAction() {
        let step = TKReplayStepResult(
            index: 1,
            action: "tap",
            ok: false,
            dryRun: false,
            elapsedMs: 10,
            command: ["triton", "tap", "Home", "--json"],
            failureCode: "server_unavailable",
            error: TKCLIErrorDetail(
                code: "server_unavailable",
                message: "Connection refused",
                endpoint: "http://127.0.0.1:19421/runtime/input",
                hint: "Start server",
                nextAction: TKCLINextAction(
                    command: "serve",
                    args: ["--host", "127.0.0.1", "--port", "19421"],
                    requiresLongRunningProcess: true
                )
            )
        )

        let suggested = replaySuggestedCommands(
            steps: [step],
            failedStepIndex: 1
        )
        let recovery = replayRecoveryCommands(
            steps: [step],
            failedStepIndex: 1
        )

        #expect(suggested.first == "triton serve --host 127.0.0.1 --port 19421")
        #expect(recovery.map(\.command).contains("triton serve --host 127.0.0.1 --port 19421"))
        #expect(recovery.map(\.category).contains("diagnose"))
        #expect(replayFailureRecoveryCategories(steps: [step], failedStepIndex: 1).contains("diagnose"))
    }

    @Test("replay failureError nextAction category stays aligned with failure recovery categories")
    func replayFailureErrorNextActionCategoryStaysAligned() {
        let step = TKReplayStepResult(
            index: 1,
            action: "tap",
            ok: false,
            dryRun: false,
            elapsedMs: 10,
            command: ["triton", "tap", "Home", "--json"],
            failureCode: "server_unavailable",
            error: TKCLIErrorDetail(
                code: "server_unavailable",
                message: "Connection refused",
                endpoint: "http://127.0.0.1:19421/runtime/input",
                hint: "Start server",
                nextAction: TKCLINextAction(
                    command: "serve",
                    args: ["--host", "127.0.0.1", "--port", "19421"],
                    requiresLongRunningProcess: true
                )
            )
        )

        let result = TKReplayResult(
            ok: false,
            dryRun: false,
            planName: "tap-home",
            stepCount: 1,
            executedCount: 1,
            failedStepIndex: 1,
            elapsedMs: 10,
            steps: [step],
            suggestedCommands: replaySuggestedCommands(steps: [step], failedStepIndex: 1),
            recoveryCommands: replayRecoveryCommands(steps: [step], failedStepIndex: 1)
        )

        let nextAction = try! #require(result.failureError?.nextAction)
        #expect(result.failurePrimaryRecoveryCategory == nextAction.category)
        #expect(result.failurePrimaryHint == "Start server")
        #expect(result.failurePrimaryEndpoint == "http://127.0.0.1:19421/runtime/input")
        #expect(result.failurePrimaryNextAction == nextAction)
        #expect(result.failurePrimarySuggestedCommand == "triton serve --host 127.0.0.1 --port 19421")
        #expect(result.failurePrimaryRecoveryCommand?.command == "triton serve --host 127.0.0.1 --port 19421")
        #expect(result.failureRecoveryCategories.contains(nextAction.category))
        #expect(result.recoveryCommands.map(\.category).contains(nextAction.category))
    }

    @Test("replay failure recovery categories absorb nextAction category when failure code mapping is narrower")
    func replayFailureRecoveryCategoriesAbsorbNextActionCategory() {
        let step = TKReplayStepResult(
            index: 1,
            action: "tap",
            ok: false,
            dryRun: false,
            elapsedMs: 10,
            command: ["triton", "tap", "Home", "--json"],
            failureCode: "validation_failed",
            error: TKCLIErrorDetail(
                code: "validation_failed",
                message: "Replay selector invalid",
                hint: "Try a direct action command",
                nextAction: TKCLINextAction(
                    command: "tap",
                    args: ["Home", "--json"]
                )
            )
        )

        let categories = replayFailureRecoveryCategories(
            steps: [step],
            failedStepIndex: 1
        )

        #expect(categories.contains("act"))
    }

    @Test("replay nextAction becomes the first recovery path when categories already exist")
    func replayNextActionBecomesFirstRecoveryPath() {
        let step = TKReplayStepResult(
            index: 1,
            action: "tap",
            ok: false,
            dryRun: false,
            elapsedMs: 10,
            command: ["triton", "tap", "Home", "--json"],
            failureCode: "target_unavailable",
            error: TKCLIErrorDetail(
                code: "target_unavailable",
                message: "Target disconnected",
                hint: "Start server first",
                nextAction: TKCLINextAction(
                    command: "serve",
                    args: ["--host", "127.0.0.1", "--port", "19421"],
                    requiresLongRunningProcess: true
                )
            )
        )

        let categories = replayFailureRecoveryCategories(
            steps: [step],
            failedStepIndex: 1
        )
        let suggested = replaySuggestedCommands(
            steps: [step],
            failedStepIndex: 1
        )
        let recovery = replayRecoveryCommands(
            steps: [step],
            failedStepIndex: 1
        )

        #expect(categories.first == "diagnose")
        #expect(categories == ["diagnose", "prepare-target"])
        #expect(suggested.first == "triton serve --host 127.0.0.1 --port 19421")
        #expect(recovery.first?.command == "triton serve --host 127.0.0.1 --port 19421")
        #expect(recovery.first?.category == "diagnose")
    }

    @Test("replay failure recovery categories keep actionable stages ahead of family remainder")
    func replayFailureRecoveryCategoriesKeepActionableStagesAheadOfFamilyRemainder() {
        let step = TKReplayStepResult(
            index: 1,
            action: "tap",
            ok: false,
            dryRun: false,
            elapsedMs: 10,
            command: ["triton", "tap", "Home", "--json"],
            failureCode: "target_unavailable",
            error: TKCLIErrorDetail(
                code: "target_unavailable",
                message: "Target disconnected",
                hint: "Start server first",
                nextAction: TKCLINextAction(
                    command: "serve",
                    args: ["--host", "127.0.0.1", "--port", "19421"],
                    requiresLongRunningProcess: true
                )
            ),
            input: .failure(action: "tap", message: "Activation point missing")
        )

        let categories = replayFailureRecoveryCategories(
            steps: [step],
            failedStepIndex: 1
        )

        #expect(categories == ["diagnose", "archive", "prepare-target"])
    }

    @Test("replay step helpers derive structured errors for non-throw failures")
    func replayStepHelpersDeriveStructuredErrorsForNonThrowFailures() {
        let waitResult = TKWaitResult(
            ok: false,
            matched: false,
            condition: "text",
            query: "Home",
            timedOut: true,
            elapsedMs: 5000,
            pollCount: 5,
            timeoutSeconds: 5,
            intervalSeconds: 1
        )
        let waitError = replayStepError(
            for: TKReplayPlanStep(action: .wait, text: "Home"),
            wait: waitResult,
            host: "127.0.0.1",
            port: 19421
        )
        #expect(waitError?.code == "timeout")

        let inputError = replayStepError(
            for: TKReplayPlanStep(action: .tap, text: "Home"),
            input: .failure(action: "tap", message: "Activation point missing"),
            host: "127.0.0.1",
            port: 19421
        )
        #expect(inputError?.code == "action_failed")

        let evidenceError = replayStepError(
            for: TKReplayPlanStep(action: .evidence, output: "/tmp/run.tritonevidence"),
            evidence: TKEvidenceManifest(
                ok: false,
                createdAt: "2026-05-31T00:00:00Z",
                output: "/tmp/run.tritonevidence",
                artifacts: [],
                cli: TKEvidenceCLI(version: "test")
            ),
            host: "127.0.0.1",
            port: 19421
        )
        #expect(evidenceError?.code == "request_failed")
    }

    private func runTriton(_ arguments: [String]) throws -> CLIRunResult {
        let process = Process()
        process.executableURL = try tritonExecutableURL()
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        return CLIRunResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }

    private func tritonExecutableURL() throws -> URL {
        let fileManager = FileManager.default
        var searchURL = Bundle.main.bundleURL.deletingLastPathComponent()
        while searchURL.path != "/" {
            let candidate = searchURL.appendingPathComponent("triton")
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
            searchURL.deleteLastPathComponent()
        }

        if let override = ProcessInfo.processInfo.environment["TRITON_CLI_PATH"], fileManager.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }

        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildRoot = packageRoot.appendingPathComponent(".build", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: buildRoot,
            includingPropertiesForKeys: [.isExecutableKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ReplayCommandTestError.missingExecutable(buildRoot.path)
        }
        for case let candidate as URL in enumerator where candidate.lastPathComponent == "triton" {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        throw ReplayCommandTestError.missingExecutable(buildRoot.path)
    }
}

private struct CLIRunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private enum ReplayCommandTestError: Error, CustomStringConvertible {
    case missingExecutable(String)

    var description: String {
        switch self {
        case let .missingExecutable(path):
            return "Could not locate built triton executable under \(path)"
        }
    }
}
