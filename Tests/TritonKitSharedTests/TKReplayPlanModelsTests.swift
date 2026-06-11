import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKReplayPlanModelsTests {
    @Test("plan decodes issue login flow shape")
    func decodesLoginFlowShape() throws {
        let json = """
        {
          "schemaVersion": 1,
          "name": "dxyer-login",
          "variables": ["username", "password"],
          "steps": [
            { "action": "tap", "text": "登录" },
            { "action": "tap", "x": 180, "y": 250 },
            { "action": "paste", "value": "${username}" },
            { "action": "wait", "gone": "登录", "timeout": 15 },
            { "action": "evidence", "name": "login-success" }
          ]
        }
        """

        let plan = try JSONDecoder().decode(TKReplayPlan.self, from: Data(json.utf8))

        #expect(plan.schemaVersion == 1)
        #expect(plan.name == "dxyer-login")
        #expect(plan.variables == ["username", "password"])
        #expect(plan.steps.count == 5)
        #expect(plan.steps[0].action == .tap)
        #expect(plan.steps[0].text == "登录")
        #expect(plan.steps[1].x == 180)
        #expect(plan.steps[2].value == "${username}")
        #expect(plan.steps[3].waitCondition == .gone)
        #expect(plan.steps[3].timeout == 15)
        #expect(plan.steps[4].name == "login-success")
    }

    @Test("variable substitution reports missing values")
    func substitutesVariables() throws {
        #expect(try TKReplaySubstituteVariables("hello ${username}", variables: ["username": "alice"]) == "hello alice")
        #expect(throws: TKReplayVariableError.self) {
            _ = try TKReplaySubstituteVariables("${password}", variables: [:])
        }
    }

    @Test("secure replay step redacts value for summaries")
    func secureRedactedSummary() throws {
        let step = TKReplayPlanStep(action: .paste, value: "secret-123", secure: true)
        let nonSecureStep = TKReplayPlanStep(action: .paste, value: "alice", secure: false)

        #expect(step.redactedValue(substitutedValue: "secret-123") == "<redacted:10>")
        #expect(nonSecureStep.redactedValue(substitutedValue: "alice") == "alice")
    }

    @Test("record response states template only")
    func recordTemplateResponseShape() throws {
        let plan = TKReplayPlan.template(name: "login-flow")
        let response = TKRecordPlanResponse(
            ok: true,
            output: "/tmp/login-flow.tritonplan",
            templateOnly: true,
            message: "Created editable Triton replay plan template",
            plan: plan
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRecordPlanResponse.self, from: data)

        #expect(decoded.templateOnly)
        #expect(decoded.plan.steps.contains { $0.action == .evidence })
    }

    @Test("plan inspect summary exposes per-step execution metadata")
    func planInspectSummaryExposesStepExecutionMetadata() throws {
        let plan = TKReplayPlan(
            name: "login-flow",
            variables: ["username", "password"],
            steps: [
                TKReplayPlanStep(action: .tap, text: "登录"),
                TKReplayPlanStep(action: .paste, value: "${password}", secure: true),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )

        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/login-flow.tritonplan", plan: plan)

        #expect(summary.steps.count == 4)
        #expect(summary.steps[0].index == 1)
        #expect(summary.steps[0].action == "tap")
        #expect(summary.steps[0].category == "act")
        #expect(summary.steps[0].workflowCategories == ["action", "assert", "evidence"])
        #expect(summary.steps[0].argv == ["triton", "tap", "登录", "--json"])
        #expect(summary.steps[0].requires == ["cli.available", "server.reachable", "target.ready", "runtime.connected"])
        #expect(summary.steps[0].expectedArtifacts == ["stdout-json", "input-result"])
        #expect(summary.steps[0].stopConditions.contains("command.failed"))
        #expect(summary.steps[0].validationErrors.isEmpty)

        #expect(summary.steps[1].argv == ["triton", "paste", "--secure", "<redacted:11>", "--json"])
        #expect(summary.steps[2].category == "verify")
        #expect(summary.steps[2].workflowCategories == ["assert", "evidence", "observe"])
        #expect(summary.steps[2].expectedArtifacts.contains("wait-result"))
        #expect(summary.steps[2].stopConditions.contains("timeout"))
        #expect(summary.steps[3].category == "archive")
        #expect(summary.steps[3].workflowCategories == ["evidence", "replay"])
        #expect(summary.steps[3].expectedArtifacts.contains("evidence-bundle"))
        #expect(summary.steps[3].stopConditions.contains("artifact.write-failed"))
    }

    @Test("network proxy evidence step keeps explicit session in replay plan metadata")
    func networkProxyEvidenceStepKeepsExplicitSessionInReplayPlanMetadata() throws {
        let json = """
        {
          "schemaVersion": 1,
          "name": "network-flow",
          "variables": ["platform"],
          "steps": [
            {
              "action": "evidence",
              "name": "network-capture",
              "output": "/tmp/network.tritonevidence",
              "include": "network.proxy-session",
              "proxySession": "/tmp/${platform}-network"
            }
          ]
        }
        """

        let plan = try JSONDecoder().decode(TKReplayPlan.self, from: Data(json.utf8))
        let step = try #require(plan.steps.first)
        #expect(step.proxySession == "/tmp/${platform}-network")

        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/network-flow.tritonplan", plan: plan)
        let inspectedStep = try #require(summary.steps.first)
        #expect(inspectedStep.argv == [
            "triton", "evidence",
            "--output", "/tmp/network.tritonevidence",
            "--include", "network.proxy-session",
            "--proxy-session", "/tmp/${platform}-network",
            "--name", "network-capture",
            "--json",
        ])
        #expect(inspectedStep.expectedArtifacts == [
            "stdout-json",
            "evidence-bundle",
            "network.proxy-session",
            "network-capture",
        ])
        #expect(inspectedStep.stopConditions.contains("artifact.write-failed"))

        let replayArgv = try TKReplayStepExecution.argv(
            for: step,
            planName: plan.name,
            index: 1,
            variables: ["platform": "ios"]
        )
        #expect(replayArgv.contains("/tmp/ios-network"))
    }

    @Test("network proxy lifecycle steps expose replay dry-run argv")
    func networkProxyLifecycleStepsExposeReplayDryRunArgv() throws {
        let json = """
        {
          "schemaVersion": 1,
          "name": "network-proxy-flow",
          "variables": ["platform", "device"],
          "steps": [
            {
              "action": "proxy-serve",
              "proxy": "127.0.0.1:19431",
              "mode": "mock",
              "output": "/tmp/${platform}-proxy"
            },
            {
              "action": "proxy-start",
              "platform": "${platform}",
              "device": "${device}",
              "proxy": "127.0.0.1:19431",
              "mode": "mock",
              "output": "/tmp/${platform}-proxy"
            },
            {
              "action": "proxy-export",
              "platform": "${platform}",
              "device": "${device}",
              "output": "/tmp/${platform}-proxy/requests.ndjson"
            },
            {
              "action": "proxy-stop",
              "platform": "${platform}",
              "device": "${device}",
              "restore": true
            }
          ]
        }
        """

        let plan = try JSONDecoder().decode(TKReplayPlan.self, from: Data(json.utf8))
        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/network-proxy-flow.tritonplan", plan: plan)

        #expect(summary.actions == ["proxy-serve", "proxy-start", "proxy-export", "proxy-stop"])
        #expect(summary.steps[0].argv == [
            "triton", "device", "proxy", "serve",
            "--listen", "127.0.0.1:19431",
            "--output", "/tmp/${platform}-proxy",
            "--mode", "mock",
            "--jsonl",
        ])
        #expect(summary.steps[1].argv.contains("--plan-only"))
        #expect(summary.steps[2].expectedArtifacts.contains("network-capture"))
        #expect(summary.steps[3].argv.contains("--restore"))
        #expect(summary.steps.allSatisfy { $0.workflowCategories.contains("target") })

        let startArgv = try TKReplayStepExecution.argv(
            for: plan.steps[1],
            planName: plan.name,
            index: 2,
            variables: ["platform": "android", "device": "emulator-5554"]
        )
        #expect(startArgv == [
            "triton", "device", "proxy", "start",
            "--platform", "android",
            "--device", "emulator-5554",
            "--proxy", "127.0.0.1:19431",
            "--mode", "mock",
            "--output", "/tmp/android-proxy",
            "--plan-only",
            "--json",
        ])
    }

    @Test("plan inspect summary exposes step validation errors")
    func planInspectSummaryExposesStepValidationErrors() throws {
        let plan = TKReplayPlan(
            name: "invalid-flow",
            variables: ["username"],
            steps: [
                TKReplayPlanStep(action: .tap, text: "login", oid: 42),
                TKReplayPlanStep(action: .wait),
                TKReplayPlanStep(action: .paste, value: "${username}"),
            ]
        )

        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/invalid-flow.tritonplan", plan: plan)

        #expect(summary.steps[0].validationErrors == [
            TKReplayPlanStepValidationError(
                code: "ambiguous_tap_selector",
                message: "Replay tap step requires exactly one selector: text, oid, x/y, axOID, or axLabel",
                field: "selector"
            ),
        ])
        #expect(summary.steps[1].validationErrors.first?.code == "missing_wait_condition")
        #expect(summary.steps[1].validationErrors.first?.field == "condition")
        #expect(summary.steps[1].validationErrors.first?.severity == "error")
        #expect(summary.steps[2].validationErrors.isEmpty)
        #expect(summary.steps[2].argv == ["triton", "paste", "${username}", "--json"])

        let encoded = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(TKReplayPlanSummary.self, from: encoded)
        #expect(decoded.steps[0].validationErrors == summary.steps[0].validationErrors)

        let oldStepJSON = """
        {
          "index": 1,
          "action": "tap",
          "command": "triton tap login --json",
          "argv": ["triton", "tap", "login", "--json"],
          "category": "act",
          "requires": [],
          "expectedArtifacts": [],
          "stopConditions": []
        }
        """
        let oldStep = try JSONDecoder().decode(TKReplayPlanStepSummary.self, from: Data(oldStepJSON.utf8))
        #expect(oldStep.validationErrors.isEmpty)
    }

    @Test("replay step result derives execution metadata")
    func replayStepResultDerivesExecutionMetadata() throws {
        let waitStep = TKReplayStepResult(
            index: 1,
            action: "wait",
            ok: true,
            dryRun: true,
            elapsedMs: 0,
            command: ["triton", "wait", "--gone", "登录", "--json"],
            message: "dry-run"
        )

        #expect(waitStep.argv == ["triton", "wait", "--gone", "登录", "--json"])
        #expect(waitStep.category == "verify")
        #expect(waitStep.workflowCategories == ["assert", "evidence", "observe"])
        #expect(waitStep.requires == ["cli.available", "server.reachable", "target.ready", "runtime.connected"])
        #expect(waitStep.expectedArtifacts == ["stdout-json", "wait-result"])
        #expect(waitStep.stopConditions.contains("timeout"))

        let encoded = try JSONEncoder().encode(waitStep)
        let decoded = try JSONDecoder().decode(TKReplayStepResult.self, from: encoded)

        #expect(decoded.category == "verify")
        #expect(decoded.argv == decoded.command)
        #expect(decoded.expectedArtifacts.contains("wait-result"))

        let oldJSON = """
        {
          "index": 2,
          "action": "evidence",
          "ok": true,
          "dryRun": true,
          "elapsedMs": 0,
          "command": ["triton", "evidence", "--output", "/tmp/run.tritonevidence", "--json"],
          "message": "dry-run"
        }
        """

        let oldDecoded = try JSONDecoder().decode(TKReplayStepResult.self, from: Data(oldJSON.utf8))
        #expect(oldDecoded.argv == oldDecoded.command)
        #expect(oldDecoded.category == "archive")
        #expect(oldDecoded.expectedArtifacts.contains("evidence-bundle"))
        #expect(oldDecoded.stopConditions.contains("artifact.write-failed"))
        #expect(oldDecoded.failureCode == nil)
        #expect(oldDecoded.error == nil)
    }

    @Test("replay execution helper aligns inspect and result metadata")
    func replayExecutionHelperAlignsInspectAndResultMetadata() throws {
        let plan = TKReplayPlan(
            name: "login-flow",
            variables: ["username"],
            steps: [
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )
        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/login-flow.tritonplan", plan: plan)

        let replayArgv = try TKReplayStepExecution.argv(
            for: plan.steps[0],
            planName: plan.name,
            index: 1,
            variables: ["username": "alice"]
        )
        let replayMetadata = TKReplayStepExecution.metadata(argv: replayArgv, action: plan.steps[0].action.rawValue)
        let replayResult = TKReplayStepResult(
            index: 1,
            action: plan.steps[0].action.rawValue,
            ok: true,
            dryRun: true,
            elapsedMs: 0,
            command: replayArgv
        )

        #expect(summary.steps[0].argv == ["triton", "paste", "${username}", "--json"])
        #expect(replayArgv == ["triton", "paste", "alice", "--json"])
        #expect(replayResult.argv == replayArgv)
        #expect(replayResult.category == summary.steps[0].category)
        #expect(replayResult.category == replayMetadata.category)
        #expect(replayResult.workflowCategories == summary.steps[0].workflowCategories)
        #expect(replayResult.workflowCategories == replayMetadata.workflowCategories)
        #expect(replayResult.requires == summary.steps[0].requires)
        #expect(replayResult.requires == replayMetadata.requires)
        #expect(replayResult.expectedArtifacts == summary.steps[0].expectedArtifacts)
        #expect(replayResult.expectedArtifacts == replayMetadata.expectedArtifacts)
        #expect(replayResult.stopConditions == summary.steps[0].stopConditions)
        #expect(replayResult.stopConditions == replayMetadata.stopConditions)
    }

    @Test("replay result derives failure workflow and artifact routing")
    func replayResultDerivesFailureRouting() throws {
        let evidence = TKEvidenceManifest(
            ok: true,
            createdAt: "2026-05-31T00:00:00Z",
            output: "/tmp/login.tritonevidence",
            artifacts: [
                TKEvidenceArtifact(kind: "status", path: "status.json", contentType: "application/json"),
                TKEvidenceArtifact(kind: "screenshot", path: "screenshot.png", contentType: "image/png"),
            ],
            cli: TKEvidenceCLI(version: "test")
        )

        let result = TKReplayResult(
            ok: false,
            dryRun: false,
            planName: "login-flow",
            stepCount: 3,
            executedCount: 3,
            failedStepIndex: 3,
            elapsedMs: 42,
            steps: [
                TKReplayStepResult(
                    index: 1,
                    action: "evidence",
                    ok: true,
                    dryRun: false,
                    elapsedMs: 10,
                    command: ["triton", "evidence", "--output", "/tmp/login.tritonevidence", "--json"],
                    evidence: evidence
                ),
                TKReplayStepResult(
                    index: 2,
                    action: "screenshot",
                    ok: true,
                    dryRun: false,
                    elapsedMs: 5,
                    command: ["triton", "screenshot", "--output", "/tmp/failure.png", "--json"],
                    file: TKReplayFileArtifact(path: "/tmp/failure.png", bytes: 123, contentType: "image/png")
                ),
                TKReplayStepResult(
                    index: 3,
                    action: "wait",
                    ok: false,
                    dryRun: false,
                    elapsedMs: 27,
                    command: ["triton", "wait", "--text", "Home", "--json"],
                    error: TKCLIErrorDetail(
                        code: "timeout",
                        message: "Timed out waiting for text 'Home'",
                        hint: "Inspect the current UI state and retry with a narrower wait condition."
                    ),
                    wait: TKWaitResult(
                        ok: false,
                        matched: false,
                        condition: "text",
                        query: "Home",
                        timedOut: true,
                        elapsedMs: 27,
                        pollCount: 3,
                        timeoutSeconds: 5,
                        intervalSeconds: 1
                    )
                ),
            ]
        )

        #expect(result.failureWorkflowCategories == ["assert", "evidence", "observe"])
        #expect(result.failurePrimaryWorkflowCategory == "assert")
        #expect(result.failureCode == "timeout")
        #expect(result.failureError?.code == "timeout")
        #expect(result.failureRecoveryCategories == ["verify"])
        #expect(result.failurePrimaryRecoveryCategory == "verify")
        #expect(result.failurePrimaryHint == "Inspect the current UI state and retry with a narrower wait condition.")
        #expect(result.failurePrimaryEndpoint == nil)
        #expect(result.failurePrimaryNextAction == nil)
        #expect(result.failurePrimaryArtifact?.kind == "screenshot")
        #expect(result.failurePrimaryArtifact?.path == "/tmp/failure.png")
        #expect(result.failurePrimarySuggestedCommand == nil)
        #expect(result.failurePrimaryRecoveryCommand == nil)
        #expect(result.failurePrimaryArtifacts.map(\.kind) == ["screenshot", "screenshot", "status"])
        #expect(result.recoveryCommands.isEmpty)

        let oldJSON = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "login-flow",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "wait",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "wait", "--text", "Home", "--json"],
              "message": "timed out"
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(oldJSON.utf8))
        #expect(decoded.failureCode == "step_failed")
        #expect(decoded.failureError == nil)
        #expect(decoded.failureWorkflowCategories == ["assert", "evidence", "observe"])
        #expect(decoded.failurePrimaryWorkflowCategory == "assert")
        #expect(decoded.failureRecoveryCategories == ["act"])
        #expect(decoded.failurePrimaryRecoveryCategory == "act")
        #expect(decoded.failurePrimaryHint == nil)
        #expect(decoded.failurePrimaryEndpoint == nil)
        #expect(decoded.failurePrimaryNextAction == nil)
        #expect(decoded.failurePrimaryArtifact == nil)
        #expect(decoded.failurePrimarySuggestedCommand == nil)
        #expect(decoded.failurePrimaryRecoveryCommand == nil)
        #expect(decoded.failurePrimaryArtifacts.isEmpty)
        #expect(decoded.suggestedCommands.isEmpty)
        #expect(decoded.recoveryCommands.isEmpty)
    }

    @Test("replay result derives structured recovery commands from suggested commands")
    func replayResultDerivesStructuredRecoveryCommands() throws {
        let result = TKReplayResult(
            ok: false,
            dryRun: false,
            planName: "login-flow",
            stepCount: 1,
            executedCount: 1,
            failedStepIndex: 1,
            elapsedMs: 12,
            steps: [
                TKReplayStepResult(
                    index: 1,
                    action: "wait",
                    ok: false,
                    dryRun: false,
                    elapsedMs: 12,
                    command: ["triton", "wait", "--text", "Home", "--json"]
                ),
            ],
            suggestedCommands: [
                "triton find 'Home' --all --json",
                "triton snapshot --json",
                "triton evidence summary '/tmp/login.tritonevidence' --json",
            ]
        )

        #expect(result.recoveryCommands.map(\.category) == ["discover", "observe", "archive"])
        #expect(result.recoveryCommands.map(\.command) == result.suggestedCommands)
        #expect(result.failurePrimaryHint == nil)
        #expect(result.failurePrimaryEndpoint == nil)
        #expect(result.failurePrimaryNextAction == nil)
        #expect(result.failurePrimarySuggestedCommand == "triton find 'Home' --all --json")
        #expect(result.failurePrimaryRecoveryCommand?.command == "triton find 'Home' --all --json")
        #expect(result.failurePrimaryRecoveryCommand?.category == "discover")
        #expect(result.failureCode == "step_failed")
        #expect(result.failureError == nil)
        #expect(result.failureRecoveryCategories == ["act"])
    }

    @Test("replay result prepends nextAction into default recovery surfaces")
    func replayResultPrependsNextActionIntoDefaultRecoverySurfaces() {
        let result = TKReplayResult(
            ok: false,
            dryRun: false,
            planName: "tap-home",
            stepCount: 1,
            executedCount: 1,
            failedStepIndex: 1,
            elapsedMs: 10,
            steps: [
                TKReplayStepResult(
                    index: 1,
                    action: "tap",
                    ok: false,
                    dryRun: false,
                    elapsedMs: 10,
                    command: ["triton", "tap", "Home", "--json"],
                    error: TKCLIErrorDetail(
                        code: "validation_failed",
                        message: "Replay selector invalid",
                        hint: "Try a direct action command",
                        nextAction: TKCLINextAction(
                            command: "tap",
                            args: ["Home", "--json"]
                        )
                    )
                ),
            ]
        )

        #expect(result.failureCode == "validation_failed")
        #expect(result.failureRecoveryCategories == ["act"])
        #expect(result.failurePrimaryHint == "Try a direct action command")
        #expect(result.failurePrimaryEndpoint == nil)
        #expect(result.failurePrimaryNextAction?.command == "tap")
        #expect(result.failurePrimaryNextAction?.args == ["Home", "--json"])
        #expect(result.failurePrimaryNextAction?.category == "act")
        #expect(result.suggestedCommands == ["triton tap Home --json"])
        #expect(result.failurePrimarySuggestedCommand == "triton tap Home --json")
        #expect(result.failurePrimaryRecoveryCommand?.command == "triton tap Home --json")
        #expect(result.recoveryCommands.map(\.command) == ["triton tap Home --json"])
        #expect(result.recoveryCommands.map(\.category) == ["act"])
    }

    @Test("replay result decoder backfills nextAction into recovery surfaces")
    func replayResultDecoderBackfillsNextActionIntoRecoverySurfaces() throws {
        let oldJSON = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "tap-home",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "failureCode": "validation_failed",
          "failureError": {
            "code": "validation_failed",
            "message": "Replay selector invalid",
            "nextAction": {
              "command": "tap",
              "args": ["Home", "--json"]
            }
          },
          "failureRecoveryCategories": [],
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "tap",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "tap", "Home", "--json"]
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(oldJSON.utf8))

        #expect(decoded.failureRecoveryCategories == ["act"])
        #expect(decoded.failurePrimaryHint == nil)
        #expect(decoded.failurePrimaryEndpoint == nil)
        #expect(decoded.failurePrimaryNextAction?.command == "tap")
        #expect(decoded.failurePrimaryNextAction?.args == ["Home", "--json"])
        #expect(decoded.failurePrimaryNextAction?.category == "act")
        #expect(decoded.suggestedCommands == ["triton tap Home --json"])
        #expect(decoded.failurePrimarySuggestedCommand == "triton tap Home --json")
        #expect(decoded.failurePrimaryRecoveryCommand?.command == "triton tap Home --json")
        #expect(decoded.recoveryCommands.map(\.command) == ["triton tap Home --json"])
        #expect(decoded.recoveryCommands.map(\.category) == ["act"])
    }

    @Test("replay result prioritizes nextAction across explicit recovery surfaces")
    func replayResultPrioritizesNextActionAcrossExplicitRecoverySurfaces() {
        let result = TKReplayResult(
            ok: false,
            dryRun: false,
            planName: "tap-home",
            stepCount: 1,
            executedCount: 1,
            failedStepIndex: 1,
            failureCode: "target_unavailable",
            failureError: TKCLIErrorDetail(
                code: "target_unavailable",
                message: "Target disconnected",
                nextAction: TKCLINextAction(
                    command: "serve",
                    args: ["--host", "127.0.0.1", "--port", "19421"],
                    requiresLongRunningProcess: true
                )
            ),
            failureRecoveryCategories: ["prepare-target", "diagnose"],
            elapsedMs: 10,
            steps: [
                TKReplayStepResult(
                    index: 1,
                    action: "tap",
                    ok: false,
                    dryRun: false,
                    elapsedMs: 10,
                    command: ["triton", "tap", "Home", "--json"]
                ),
            ],
            suggestedCommands: [
                "triton target resolve <selector> --json",
                "triton serve --host 127.0.0.1 --port 19421"
            ],
            recoveryCommands: [
                TKCommandRecoveryCommand(command: "triton target resolve <selector> --json", category: "prepare-target"),
                TKCommandRecoveryCommand(command: "triton serve --host 127.0.0.1 --port 19421", category: "diagnose"),
            ]
        )

        #expect(result.failureRecoveryCategories == ["diagnose", "prepare-target"])
        #expect(result.failurePrimaryRecoveryCategory == "diagnose")
        #expect(result.failurePrimaryHint == nil)
        #expect(result.failurePrimaryEndpoint == nil)
        #expect(result.failurePrimaryNextAction?.command == "serve")
        #expect(result.failurePrimaryNextAction?.args == ["--host", "127.0.0.1", "--port", "19421"])
        #expect(result.failurePrimaryNextAction?.category == "diagnose")
        #expect(result.suggestedCommands.first == "triton serve --host 127.0.0.1 --port 19421")
        #expect(result.failurePrimarySuggestedCommand == "triton serve --host 127.0.0.1 --port 19421")
        #expect(result.failurePrimaryRecoveryCommand?.command == "triton serve --host 127.0.0.1 --port 19421")
        #expect(result.recoveryCommands.first?.command == "triton serve --host 127.0.0.1 --port 19421")
        #expect(result.recoveryCommands.first?.category == "diagnose")
    }

    @Test("replay result keeps actionable recovery categories ahead of remaining failure family categories")
    func replayResultKeepsActionableRecoveryCategoriesAheadOfFailureFamilyRemainder() {
        let result = TKReplayResult(
            ok: false,
            dryRun: false,
            planName: "tap-home",
            stepCount: 1,
            executedCount: 1,
            failedStepIndex: 1,
            failureCode: "target_unavailable",
            failureError: TKCLIErrorDetail(
                code: "target_unavailable",
                message: "Target disconnected",
                nextAction: TKCLINextAction(
                    command: "serve",
                    args: ["--host", "127.0.0.1", "--port", "19421"],
                    requiresLongRunningProcess: true
                )
            ),
            elapsedMs: 10,
            steps: [
                TKReplayStepResult(
                    index: 1,
                    action: "tap",
                    ok: false,
                    dryRun: false,
                    elapsedMs: 10,
                    command: ["triton", "tap", "Home", "--json"]
                ),
            ],
            suggestedCommands: [
                "triton snapshot --json",
                "triton screenshot --json"
            ]
        )

        #expect(result.suggestedCommands == [
            "triton serve --host 127.0.0.1 --port 19421",
            "triton snapshot --json",
            "triton screenshot --json",
        ])
        #expect(result.recoveryCommands.map(\.category) == ["diagnose", "observe", "archive"])
        #expect(result.failureRecoveryCategories == ["diagnose", "observe", "archive", "prepare-target"])
        #expect(result.failurePrimaryRecoveryCategory == "diagnose")
        #expect(result.failurePrimaryHint == nil)
        #expect(result.failurePrimaryEndpoint == nil)
        #expect(result.failurePrimaryNextAction?.command == "serve")
        #expect(result.failurePrimaryNextAction?.args == ["--host", "127.0.0.1", "--port", "19421"])
        #expect(result.failurePrimaryNextAction?.category == "diagnose")
        #expect(result.failurePrimarySuggestedCommand == "triton serve --host 127.0.0.1 --port 19421")
        #expect(result.failurePrimaryRecoveryCommand?.command == "triton serve --host 127.0.0.1 --port 19421")
    }

    @Test("replay result decoder backfills primary workflow and recovery categories")
    func replayResultDecoderBackfillsPrimaryLaneCategories() throws {
        let oldJSON = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "login-flow",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "failureWorkflowCategories": ["assert", "evidence", "observe"],
          "failureRecoveryCategories": ["verify", "archive"],
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "wait",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "wait", "--text", "Home", "--json"]
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(oldJSON.utf8))

        #expect(decoded.failurePrimaryWorkflowCategory == "assert")
        #expect(decoded.failurePrimaryRecoveryCategory == "verify")
        #expect(decoded.failurePrimaryHint == nil)
        #expect(decoded.failurePrimaryEndpoint == nil)
        #expect(decoded.failurePrimaryNextAction == nil)
        #expect(decoded.failurePrimarySuggestedCommand == nil)
        #expect(decoded.failurePrimaryRecoveryCommand == nil)
    }

    @Test("replay result decoder backfills primary artifact from artifact list")
    func replayResultDecoderBackfillsPrimaryArtifact() throws {
        let json = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "login-flow",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "failurePrimaryArtifacts": [
            { "kind": "screenshot", "path": "screenshot.png", "contentType": "image/png" },
            { "kind": "status", "path": "status.json", "contentType": "application/json" }
          ],
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "wait",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "wait", "--text", "Home", "--json"]
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(json.utf8))

        #expect(decoded.failurePrimaryHint == nil)
        #expect(decoded.failurePrimaryEndpoint == nil)
        #expect(decoded.failurePrimaryNextAction == nil)
        #expect(decoded.failurePrimarySuggestedCommand == nil)
        #expect(decoded.failurePrimaryArtifact?.kind == "screenshot")
        #expect(decoded.failurePrimaryArtifact?.path == "screenshot.png")
    }

    @Test("replay result decoder backfills primary hint from failure error")
    func replayResultDecoderBackfillsPrimaryHint() throws {
        let json = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "tap-home",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "failureError": {
            "code": "server_unavailable",
            "message": "Connection refused",
            "hint": "Start server first"
          },
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "tap",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "tap", "Home", "--json"]
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(json.utf8))

        #expect(decoded.failurePrimaryHint == "Start server first")
        #expect(decoded.failurePrimaryEndpoint == nil)
        #expect(decoded.failurePrimaryNextAction == nil)
    }

    @Test("replay result decoder backfills primary endpoint from failure error")
    func replayResultDecoderBackfillsPrimaryEndpoint() throws {
        let json = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "tap-home",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "failureError": {
            "code": "server_unavailable",
            "message": "Connection refused",
            "endpoint": "http://127.0.0.1:19421/runtime/input"
          },
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "tap",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "tap", "Home", "--json"]
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(json.utf8))

        #expect(decoded.failurePrimaryEndpoint == "http://127.0.0.1:19421/runtime/input")
    }

    @Test("replay result decoder backfills primary suggested command from suggested commands")
    func replayResultDecoderBackfillsPrimarySuggestedCommand() throws {
        let json = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "login-flow",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "suggestedCommands": [
            "triton snapshot --json",
            "triton screenshot --json"
          ],
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "wait",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "wait", "--text", "Home", "--json"]
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(json.utf8))

        #expect(decoded.failurePrimaryHint == nil)
        #expect(decoded.failurePrimaryEndpoint == nil)
        #expect(decoded.failurePrimaryNextAction == nil)
        #expect(decoded.failurePrimarySuggestedCommand == "triton snapshot --json")
        #expect(decoded.failurePrimaryRecoveryCommand?.command == "triton snapshot --json")
    }

    @Test("replay result decoder backfills primary next action from failure error")
    func replayResultDecoderBackfillsPrimaryNextAction() throws {
        let json = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "tap-home",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "failureError": {
            "code": "server_unavailable",
            "message": "Connection refused",
            "nextAction": {
              "command": "serve",
              "args": ["--host", "127.0.0.1", "--port", "19421"],
              "requiresLongRunningProcess": true
            }
          },
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "tap",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "tap", "Home", "--json"]
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(json.utf8))

        #expect(decoded.failurePrimaryEndpoint == nil)
        #expect(decoded.failurePrimaryNextAction?.command == "serve")
        #expect(decoded.failurePrimaryNextAction?.args == ["--host", "127.0.0.1", "--port", "19421"])
        #expect(decoded.failurePrimaryNextAction?.category == "diagnose")
        #expect(decoded.failurePrimaryNextAction?.requiresLongRunningProcess == true)
    }

    @Test("replay result decoder backfills primary recovery command from recovery commands")
    func replayResultDecoderBackfillsPrimaryRecoveryCommand() throws {
        let json = """
        {
          "ok": false,
          "dryRun": false,
          "planName": "login-flow",
          "stepCount": 1,
          "executedCount": 1,
          "failedStepIndex": 1,
          "recoveryCommands": [
            { "command": "triton snapshot --json", "category": "observe" },
            { "command": "triton screenshot --json", "category": "archive" }
          ],
          "elapsedMs": 10,
          "steps": [
            {
              "index": 1,
              "action": "wait",
              "ok": false,
              "dryRun": false,
              "elapsedMs": 10,
              "command": ["triton", "wait", "--text", "Home", "--json"]
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(TKReplayResult.self, from: Data(json.utf8))

        #expect(decoded.failurePrimaryHint == nil)
        #expect(decoded.failurePrimaryEndpoint == nil)
        #expect(decoded.failurePrimaryNextAction == nil)
        #expect(decoded.failurePrimarySuggestedCommand == nil)
        #expect(decoded.failurePrimaryRecoveryCommand?.command == "triton snapshot --json")
        #expect(decoded.failurePrimaryRecoveryCommand?.category == "observe")
    }

    @Test("replay step result derives failure codes from failed shapes")
    func replayStepResultDerivesFailureCodes() {
        let waitTimeout = TKReplayStepResult(
            index: 1,
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
        )
        let inputFailure = TKReplayStepResult(
            index: 2,
            action: "tap",
            ok: false,
            dryRun: false,
            elapsedMs: 5,
            command: ["triton", "tap", "Home", "--json"],
            error: TKCLIErrorDetail(code: "target_unavailable", message: "Target disconnected", hint: "Reconnect target"),
            input: .failure(action: "tap", message: "not found")
        )

        #expect(waitTimeout.failureCode == "timeout")
        #expect(inputFailure.failureCode == "target_unavailable")
        #expect(inputFailure.error?.code == "target_unavailable")
    }

    @Test("replay execution helper rejects ambiguous dry-run steps")
    func replayExecutionHelperRejectsAmbiguousDryRunSteps() throws {
        let ambiguousTap = TKReplayPlanStep(action: .tap, text: "登录", oid: 42)
        #expect(throws: TKReplayStepExecutionError.ambiguousTapSelector) {
            _ = try TKReplayStepExecution.argv(
                for: ambiguousTap,
                planName: "login-flow",
                index: 1,
                variables: [:]
            )
        }

        let ambiguousWait = TKReplayPlanStep(action: .wait, text: "Home", gone: "登录")
        #expect(throws: TKReplayStepExecutionError.ambiguousWaitCondition) {
            _ = try TKReplayStepExecution.argv(
                for: ambiguousWait,
                planName: "login-flow",
                index: 2,
                variables: [:]
            )
        }

        let missingText = TKReplayPlanStep(action: .paste)
        #expect(throws: TKReplayStepExecutionError.missingText(action: "paste")) {
            _ = try TKReplayStepExecution.argv(
                for: missingText,
                planName: "login-flow",
                index: 3,
                variables: [:]
            )
        }

        let missingWaitCondition = TKReplayPlanStep(action: .wait)
        #expect(throws: TKReplayStepExecutionError.missingWaitCondition) {
            _ = try TKReplayStepExecution.argv(
                for: missingWaitCondition,
                planName: "login-flow",
                index: 4,
                variables: [:]
            )
        }
    }
}
