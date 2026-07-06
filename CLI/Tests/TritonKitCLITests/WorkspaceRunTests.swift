import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct WorkspaceRunTests {
    @Test("workspace run writes first facts and inspect reads them")
    func workspaceRunWritesFirstFactsAndInspectReadsThem() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let run = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-001",
            target: "current",
            app: "com.example.demo",
            goal: "Explore login",
            actionPolicy: "explore"
        ))

        #expect(run.kind == "triton.workspace.run")
        #expect(run.runID == "run-workspace-001")
        #expect(run.status == "stopped")
        #expect(run.ai.llmEnabled)
        #expect(run.ai.vlmEnabled)
        #expect(run.ai.providersReady == false)
        #expect(run.nextActions.contains { $0.code == "configure_ai_provider" })
        #expect(run.runner?.actionPolicy == "explore")
        #expect(run.runner?.maxSteps == 20)
        #expect(run.runner?.allowedActions == ["tap", "swipe", "type", "wait", "verify", "stop"])
        #expect(run.runner?.stopConditions.contains("max_steps_reached") == true)

        let runDir = root.appendingPathComponent("run-workspace-001", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("run.json").path))
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("events.jsonl").path))
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("config.yaml").path))
        let config = try String(contentsOf: runDir.appendingPathComponent("config.yaml"), encoding: .utf8)
        #expect(config.contains("maxSteps: 20"))
        #expect(config.contains("  - tap"))
        #expect(config.contains("  - max_steps_reached"))

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        #expect(atlas?["kind"] as? String == "triton.workspace.atlas")
        #expect(atlas?["runId"] as? String == "run-workspace-001")
        let screens = atlas?["screens"] as? [[String: Any]]
        let states = atlas?["states"] as? [[String: Any]]
        let coverage = atlas?["coverage"] as? [String: Any]
        #expect(screens?.count == 1)
        #expect(states?.count == 1)
        #expect(coverage?["screenCount"] as? Int == 1)
        #expect(coverage?["stateCount"] as? Int == 1)
        #expect(coverage?["transitionCount"] as? Int == 0)
        #expect(screens?.first?["screenId"] as? String == "screen_0000")
        let evidenceRefs = screens?.first?["evidenceRefs"] as? [String]
        #expect(evidenceRefs?.contains("events.jsonl#observation.captured") == true)
        #expect(evidenceRefs?.contains("evidence/screenshots/0000.txt") == true)

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.map(\.type.rawValue) == [
            "run.started",
            "target.resolved",
            "provider.checked",
            "app.ready",
            "observation.captured",
            "flow.bootstrap.checked",
            "run.stopped",
        ])

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-001",
            runsDirectory: root.path
        )
        #expect(inspected.run.runID == "run-workspace-001")
        #expect(inspected.summary.eventCount == 7)
        #expect(inspected.latestBootstrap?.phase == "provider_missing")
        #expect(inspected.atlas.screenCount == 1)
        #expect(inspected.atlas.stateCount == 1)
        #expect(inspected.atlas.transitionCount == 0)
        #expect(inspected.atlas.coverageStatus == "seeded")
        #expect(inspected.atlas.atlasRef == "atlas/atlas.json")
    }

    @Test("workspace run records bounded runner config")
    func workspaceRunRecordsBoundedRunnerConfig() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let run = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-runner-bounds",
            target: "current",
            app: "com.example.demo",
            goal: "Bounded exploration",
            actionPolicy: "planFirst",
            maxSteps: 3,
            allowedActions: ["tap", "wait"],
            stopConditions: ["max_steps_reached", "policy_rejected"]
        ))

        #expect(run.runner?.actionPolicy == "planFirst")
        #expect(run.runner?.maxSteps == 3)
        #expect(run.runner?.allowedActions == ["tap", "wait"])
        #expect(run.runner?.stopConditions == ["max_steps_reached", "policy_rejected"])

        let runDir = root.appendingPathComponent("run-workspace-runner-bounds", isDirectory: true)
        let config = try String(contentsOf: runDir.appendingPathComponent("config.yaml"), encoding: .utf8)
        #expect(config.contains("actionPolicy: planFirst"))
        #expect(config.contains("maxSteps: 3"))
        #expect(config.contains("  - policy_rejected"))

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-runner-bounds",
            runsDirectory: root.path
        )
        #expect(inspected.run.runner?.maxSteps == 3)
        #expect(inspected.run.runner?.allowedActions == ["tap", "wait"])
    }

    @Test("workspace run rejects invalid runner bounds")
    func workspaceRunRejectsInvalidRunnerBounds() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(throws: RuntimeError.self) {
            try runWorkspaceRun(TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-invalid-runner",
                target: "current",
                app: "com.example.demo",
                goal: "Invalid bounds",
                actionPolicy: "explore",
                maxSteps: 0
            ))
        }
    }

    @Test("workspace schema exposes bounded runner options")
    func workspaceSchemaExposesBoundedRunnerOptions() throws {
        let schema = try #require(workspaceCommandSchemas().first)
        let optionNames = Set(schema.options.map(\.name))
        #expect(optionNames.contains("--max-steps"))
        #expect(optionNames.contains("--allowed-action"))
        #expect(optionNames.contains("--stop-condition"))

        let run = try #require(schema.subcommands.first { $0.name == "run" })
        #expect(run.optionalOptions.contains("--max-steps"))
        #expect(run.optionalOptions.contains("--allowed-action"))
        #expect(run.optionalOptions.contains("--stop-condition"))
    }

    @Test("workspace run records explicit VLM provider preflight")
    func workspaceRunRecordsExplicitVLMProviderPreflight() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let run = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-vlm-provider",
            target: "current",
            app: "com.example.demo",
            goal: "Explore login",
            actionPolicy: "explore",
            vlmProvider: "mock"
        ))

        #expect(run.ai.providersReady == false)
        #expect(run.ai.providerStatus == "partial")
        #expect(run.ai.llmProviderStatus == "missing")
        #expect(run.ai.vlmProvider == "mock")
        #expect(run.ai.vlmProviderStatus == "ready")
        #expect(run.nextActions.contains { $0.code == "configure_llm_provider" })

        let runDir = root.appendingPathComponent("run-workspace-vlm-provider", isDirectory: true)
        let provider = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/provider-check.json"))
        ) as? [String: Any]
        #expect(provider?["providerStatus"] as? String == "partial")
        #expect(provider?["vlmProvider"] as? String == "mock")
        #expect(provider?["vlmProviderStatus"] as? String == "ready")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type == .providerChecked }?.phase == "vlm_ready_llm_missing")

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-vlm-provider",
            runsDirectory: root.path
        )
        #expect(inspected.latestBootstrap?.phase == "llm_missing")
    }

    @Test("workspace run marks providers ready when LLM and VLM preflight pass")
    func workspaceRunMarksProvidersReadyWhenLLMAndVLMPreflightPass() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let run = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-ai-ready",
            target: "current",
            app: "com.example.demo",
            goal: "Explore login",
            actionPolicy: "explore",
            llmProvider: "mock",
            vlmProvider: "mock"
        ))

        #expect(run.ai.providersReady)
        #expect(run.ai.providerStatus == "ready")
        #expect(run.ai.llmProvider == "mock")
        #expect(run.ai.llmProviderStatus == "ready")
        #expect(run.ai.vlmProvider == "mock")
        #expect(run.ai.vlmProviderStatus == "ready")
        #expect(run.nextActions.isEmpty)

        let runDir = root.appendingPathComponent("run-workspace-ai-ready", isDirectory: true)
        let provider = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/provider-check.json"))
        ) as? [String: Any]
        #expect(provider?["providersReady"] as? Bool == true)
        #expect(provider?["providerStatus"] as? String == "ready")
        #expect(provider?["llmProvider"] as? String == "mock")
        #expect(provider?["vlmProvider"] as? String == "mock")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type == .providerChecked }?.phase == "ready")

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-ai-ready",
            runsDirectory: root.path
        )
        #expect(inspected.latestBootstrap?.phase == "provider_ready")
    }

    @Test("workspace run records explicit target platform and scope")
    func workspaceRunRecordsExplicitTargetPlatformAndScope() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let run = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-target",
            target: "local-ios-sim",
            platform: "ios",
            scope: "simulator",
            app: "com.example.demo",
            goal: "Target facts",
            actionPolicy: "explore"
        ))

        #expect(run.target.id == "local-ios-sim")
        #expect(run.target.platform == "ios")
        #expect(run.target.scope == "simulator")
        #expect(run.target.capabilities.contains("screenshot"))

        let target = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root
                .appendingPathComponent("run-workspace-target", isDirectory: true)
                .appendingPathComponent("evidence/model/target.json"))
        ) as? [String: Any]
        #expect(target?["platform"] as? String == "ios")
        #expect(target?["scope"] as? String == "simulator")
    }

    @Test("workspace stop is idempotent")
    func workspaceStopIsIdempotent() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-stop",
            target: "current",
            app: "com.example.demo",
            goal: "Stop run",
            actionPolicy: "explore"
        ))

        let stopped = try stopWorkspaceRun(runID: "run-workspace-stop", runsDirectory: root.path)
        let stoppedAgain = try stopWorkspaceRun(runID: "run-workspace-stop", runsDirectory: root.path)

        #expect(stopped.run.status == "stopped")
        #expect(stoppedAgain.summary.eventCount == stopped.summary.eventCount)
    }

    @Test("workspace run can write dry decision fixture events")
    func workspaceRunCanWriteDryDecisionFixtureEvents() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-decision",
            target: "current",
            app: "com.example.demo",
            goal: "Dry decision",
            actionPolicy: "explore",
            dryModelFixture: true
        ))

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: root
                .appendingPathComponent("run-workspace-decision", isDirectory: true)
                .appendingPathComponent("events.jsonl"))
        )
        let eventTypes = parsed.events.map(\.type.rawValue)

        #expect(eventTypes.contains("model.decided"))
        #expect(eventTypes.contains("policy.checked"))
        #expect(eventTypes.contains("action.executed"))
        #expect(eventTypes.contains("verify.checked"))
        #expect(eventTypes.contains("atlas.updated"))
        #expect(eventTypes.contains("flow.updated"))

        let runDir = root.appendingPathComponent("run-workspace-decision", isDirectory: true)
        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let transitions = atlas?["transitions"] as? [[String: Any]]
        let coverage = atlas?["coverage"] as? [String: Any]
        #expect(transitions?.count == 1)
        #expect(coverage?["transitionCount"] as? Int == 1)
        let transition = transitions?.first
        #expect(transition?["transitionId"] as? String == "transition_0000")
        #expect(transition?["fromScreenId"] as? String == "screen_0000")
        #expect(transition?["toScreenId"] as? String == "screen_0000")
        #expect(transition?["status"] as? String == "candidate_failed")
        let evidenceRefs = transition?["evidenceRefs"] as? [String]
        #expect(evidenceRefs?.contains("events.jsonl#action.executed") == true)
        #expect(evidenceRefs?.contains("evidence/model/decision-000.json") == true)

        let delta = try String(contentsOf: runDir.appendingPathComponent("atlas/deltas.jsonl"), encoding: .utf8)
        #expect(delta.contains(#""transitionId":"transition_0000""#))
        #expect(delta.contains(#""status":"candidate_failed""#))

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-decision",
            runsDirectory: root.path
        )
        #expect(inspected.atlas.screenCount == 1)
        #expect(inspected.atlas.stateCount == 1)
        #expect(inspected.atlas.transitionCount == 1)
        #expect(inspected.atlas.deltaRef == "atlas/deltas.jsonl")
    }

    @Test("workspace export flow writes a seed")
    func workspaceExportFlowWritesASeed() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-flow",
            target: "current",
            app: "com.example.demo",
            goal: "Export flow",
            actionPolicy: "explore"
        ))

        let output = root.appendingPathComponent("flow.tritonflow.yaml")
        let response = try exportWorkspaceFlow(
            runID: "run-workspace-flow",
            runsDirectory: root.path,
            output: output.path
        )
        let yaml = try String(contentsOf: output, encoding: .utf8)

        #expect(response.output == output.path)
        #expect(yaml.contains("kind: triton.workspace.flow"))
        #expect(yaml.contains("runId: run-workspace-flow"))
        #expect(yaml.contains("evidenceRef: events.jsonl#app.ready"))
    }

    @Test("workspace export flow includes dry action steps")
    func workspaceExportFlowIncludesDryActionSteps() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-flow-action",
            target: "current",
            app: "com.example.demo",
            goal: "Export action flow",
            actionPolicy: "explore",
            dryModelFixture: true
        ))

        let output = root.appendingPathComponent("action-flow.tritonflow.yaml")
        let response = try exportWorkspaceFlow(
            runID: "run-workspace-flow-action",
            runsDirectory: root.path,
            output: output.path
        )
        let yaml = try String(contentsOf: output, encoding: .utf8)

        #expect(response.stepCount == 4)
        #expect(yaml.contains("action: tap"))
        #expect(yaml.contains("target: \"Continue\""))
        #expect(yaml.contains("evidenceRef: events.jsonl#action.executed"))
        #expect(yaml.contains("modelEvidenceRef: evidence/model/decision-000.json"))
    }

    @Test("workspace CLI run inspect and export flow")
    func workspaceCLIRunInspectAndExportFlow() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let runResult = try runWorkspaceCLI([
            "workspace", "run",
            "--target", "current",
            "--platform", "ios",
            "--scope", "simulator",
            "--app", "com.example.demo",
            "--goal", "Explore login",
            "--runs-dir", root.path,
            "--run-id", "run-workspace-cli",
            "--llm-provider", "mock",
            "--vlm-provider", "mock",
            "--max-steps", "5",
            "--allowed-action", "tap",
            "--allowed-action", "wait",
            "--stop-condition", "max_steps_reached",
            "--json",
        ])
        let run = try JSONDecoder().decode(TKWorkspaceRunResponse.self, from: Data(runResult.stdout.utf8))

        #expect(runResult.exitCode == 0)
        #expect(run.runID == "run-workspace-cli")
        #expect(run.target.platform == "ios")
        #expect(run.target.scope == "simulator")
        #expect(run.ai.llmEnabled)
        #expect(run.ai.vlmEnabled)
        #expect(run.ai.providersReady)
        #expect(run.ai.llmProvider == "mock")
        #expect(run.ai.llmProviderStatus == "ready")
        #expect(run.ai.vlmProvider == "mock")
        #expect(run.ai.vlmProviderStatus == "ready")
        #expect(run.runner?.maxSteps == 5)
        #expect(run.runner?.allowedActions == ["tap", "wait"])
        #expect(run.runner?.stopConditions == ["max_steps_reached"])

        let inspectResult = try runWorkspaceCLI([
            "workspace", "inspect",
            "run-workspace-cli",
            "--runs-dir", root.path,
            "--json",
        ])
        let inspected = try JSONDecoder().decode(TKWorkspaceInspectResponse.self, from: Data(inspectResult.stdout.utf8))

        #expect(inspectResult.exitCode == 0)
        #expect(inspected.summary.eventCount == 7)

        let output = root.appendingPathComponent("cli-flow.tritonflow.yaml")
        let exportResult = try runWorkspaceCLI([
            "workspace", "export-flow",
            "run-workspace-cli",
            "--runs-dir", root.path,
            "--output", output.path,
            "--json",
        ])
        let exported = try JSONDecoder().decode(TKWorkspaceExportFlowResponse.self, from: Data(exportResult.stdout.utf8))

        #expect(exportResult.exitCode == 0)
        #expect(exported.output == output.path)
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    @Test("workspace HTTP handlers share the run runtime")
    func workspaceHTTPHandlersShareTheRunRuntime() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let runBody = try JSONEncoder().encode(TKWorkspaceHTTPRunRequest(
            runsDir: root.path,
            runID: "run-workspace-http",
            target: "current",
            platform: "android",
            scope: "emulator",
            app: "com.example.demo",
            goal: "HTTP run",
            actionPolicy: nil,
            llmProvider: "mock",
            vlmProvider: "mock",
            maxSteps: 4,
            allowedActions: ["tap"],
            stopConditions: ["provider_missing"]
        ))
        let run = try handleWorkspaceHTTPRun(body: runBody)

        #expect(run.runID == "run-workspace-http")
        #expect(run.target.platform == "android")
        #expect(run.target.scope == "emulator")
        #expect(run.ai.llmEnabled)
        #expect(run.ai.vlmEnabled)
        #expect(run.ai.providersReady)
        #expect(run.ai.llmProvider == "mock")
        #expect(run.ai.llmProviderStatus == "ready")
        #expect(run.ai.vlmProvider == "mock")
        #expect(run.ai.vlmProviderStatus == "ready")
        #expect(run.runner?.maxSteps == 4)
        #expect(run.runner?.allowedActions == ["tap"])
        #expect(run.runner?.stopConditions == ["provider_missing"])

        let inspected = try handleWorkspaceHTTPInspect(runID: "run-workspace-http", runsDir: root.path)
        #expect(inspected.summary.eventCount == 7)

        let output = root.appendingPathComponent("http-flow.tritonflow.yaml")
        let exported = try handleWorkspaceHTTPExportFlow(
            runID: "run-workspace-http",
            body: try JSONEncoder().encode(TKWorkspaceHTTPExportFlowRequest(
                runsDir: root.path,
                output: output.path
            ))
        )

        #expect(exported.output == output.path)
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    private func temporaryRunsDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-workspace-runs-\(UUID().uuidString)", isDirectory: true)
    }

    private func runWorkspaceCLI(_ arguments: [String]) throws -> WorkspaceCLIRunResult {
        let process = Process()
        process.executableURL = try tritonExecutableURL()
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return WorkspaceCLIRunResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func tritonExecutableURL() throws -> URL {
        let fileManager = FileManager.default
        if let override = ProcessInfo.processInfo.environment["TRITON_CLI_PATH"],
           fileManager.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let debugCandidate = packageRoot
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("debug", isDirectory: true)
            .appendingPathComponent("triton")
        if fileManager.isExecutableFile(atPath: debugCandidate.path) {
            return debugCandidate
        }
        let repositoryRoot = packageRoot.deletingLastPathComponent()
        for scratchPath in [".build/cli-test", ".build/cli"] {
            let buildRoot = repositoryRoot.appendingPathComponent(scratchPath, isDirectory: true)
            if let candidate = try findTritonExecutable(under: buildRoot, fileManager: fileManager) {
                return candidate
            }
        }
        let buildRoot = packageRoot.appendingPathComponent(".build", isDirectory: true)
        if let candidate = try findTritonExecutable(under: buildRoot, fileManager: fileManager) {
            return candidate
        }
        throw NSError(
            domain: "TritonKitCLITests.WorkspaceRunTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing triton executable for workspace CLI test"]
        )
    }

    private func findTritonExecutable(under buildRoot: URL, fileManager: FileManager) throws -> URL? {
        guard fileManager.fileExists(atPath: buildRoot.path) else { return nil }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isExecutableKey, .nameKey]
        guard let enumerator = fileManager.enumerator(at: buildRoot, includingPropertiesForKeys: Array(keys)) else {
            return nil
        }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            if values.name == "triton",
               values.isRegularFile == true,
               values.isExecutable == true {
                return url
            }
        }
        return nil
    }
}

private struct WorkspaceCLIRunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
