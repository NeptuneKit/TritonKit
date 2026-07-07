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
        #expect(run.status == "paused")
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
            "run.paused",
        ])

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-001",
            runsDirectory: root.path
        )
        #expect(inspected.run.runID == "run-workspace-001")
        #expect(inspected.run.status == "paused")
        #expect(inspected.summary.status == .paused)
        #expect(inspected.summary.eventCount == 7)
        #expect(inspected.latestBootstrap?.phase == "provider_missing")
        #expect(inspected.latestPause?.phase == "provider_missing")
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
        #expect(optionNames.contains("--observation-fixture"))
        #expect(optionNames.contains("--observe-live"))
        #expect(optionNames.contains("--observe-kind"))
        #expect(optionNames.contains("--observe-max-nodes"))
        #expect(optionNames.contains("--observe-host"))
        #expect(optionNames.contains("--observe-port"))
        #expect(optionNames.contains("--hdc"))
        #expect(optionNames.contains("--business-ready-text"))
        #expect(optionNames.contains("--app-mode"))
        #expect(optionNames.contains("--bundle-id"))
        #expect(optionNames.contains("--package-name"))
        #expect(optionNames.contains("--activity"))
        #expect(optionNames.contains("--bundle"))
        #expect(optionNames.contains("--ability"))
        #expect(optionNames.contains("--adb"))

        let run = try #require(schema.subcommands.first { $0.name == "run" })
        #expect(run.optionalOptions.contains("--max-steps"))
        #expect(run.optionalOptions.contains("--allowed-action"))
        #expect(run.optionalOptions.contains("--stop-condition"))
        #expect(run.optionalOptions.contains("--observation-fixture"))
        #expect(run.optionalOptions.contains("--observe-live"))
        #expect(run.optionalOptions.contains("--observe-kind"))
        #expect(run.optionalOptions.contains("--observe-max-nodes"))
        #expect(run.optionalOptions.contains("--observe-host"))
        #expect(run.optionalOptions.contains("--observe-port"))
        #expect(run.optionalOptions.contains("--hdc"))
        #expect(run.optionalOptions.contains("--business-ready-text"))
        #expect(run.optionalOptions.contains("--app-mode"))
        #expect(run.optionalOptions.contains("--bundle-id"))
        #expect(run.optionalOptions.contains("--package-name"))
        #expect(run.optionalOptions.contains("--activity"))
        #expect(run.optionalOptions.contains("--bundle"))
        #expect(run.optionalOptions.contains("--ability"))
        #expect(run.optionalOptions.contains("--adb"))
    }

    @Test("workspace run seeds atlas from observation fixture")
    func workspaceRunSeedsAtlasFromObservationFixture() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)

        _ = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-observation-fixture",
            target: "current",
            app: "com.example.demo",
            goal: "Seed from observation",
            actionPolicy: "explore",
            observationFixture: fixture.path
        ))

        let runDir = root.appendingPathComponent("run-workspace-observation-fixture", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("evidence/observations/0000.json").path))

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let observation = try #require(parsed.events.first { $0.type == .observationCaptured })
        #expect(observation.artifacts?.screenshot == "fixtures/login.png")
        #expect(observation.screenCandidate?.screenshotSha256 == "sha-login-screen")
        #expect(observation.screenCandidate?.visibleTexts == ["Login", "Continue"])
        #expect(observation.changed == true)

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let screen = (atlas?["screens"] as? [[String: Any]])?.first
        #expect(screen?["signature"] as? String == "sha-login-screen:ax-login-text:hier-login-tree")
        #expect(screen?["dominantTexts"] as? [String] == ["Login", "Continue"])
        let evidenceRefs = screen?["evidenceRefs"] as? [String]
        #expect(evidenceRefs?.contains("evidence/observations/0000.json") == true)
        #expect(evidenceRefs?.contains("fixtures/login.png") == true)
    }

    @Test("workspace run seeds atlas from observe output fixture")
    func workspaceRunSeedsAtlasFromObserveOutputFixture() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObserveOutputFixture(in: root)

        _ = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-observe-output",
            target: "current",
            app: "com.example.demo",
            goal: "Seed from observe output",
            actionPolicy: "explore",
            observationFixture: fixture.path
        ))

        let runDir = root.appendingPathComponent("run-workspace-observe-output", isDirectory: true)
        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let observation = try #require(parsed.events.first { $0.type == .observationCaptured })
        #expect(observation.artifacts?.screenshot == "fixtures/login-screenshot.png")
        #expect(observation.artifacts?.hierarchy == "fixtures/observe-tree.json")
        #expect(observation.artifacts?.ax == "fixtures/login-ax.json")
        #expect(observation.screenCandidate?.screenshotSha256.count == 64)
        #expect(observation.screenCandidate?.axTextHash.count == 64)
        #expect(observation.screenCandidate?.hierarchySha256.count == 64)
        #expect(observation.screenCandidate?.visibleTexts == ["Login", "Continue"])

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let screen = (atlas?["screens"] as? [[String: Any]])?.first
        #expect(screen?["dominantTexts"] as? [String] == ["Login", "Continue"])
        let evidenceRefs = screen?["evidenceRefs"] as? [String]
        #expect(evidenceRefs?.contains("evidence/observations/0000.json") == true)
        #expect(evidenceRefs?.contains("fixtures/login-screenshot.png") == true)
        #expect(evidenceRefs?.contains("fixtures/observe-tree.json") == true)
    }

    @Test("workspace run captures live observe seed when enabled")
    func workspaceRunCapturesLiveObserveSeedWhenEnabled() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        var observedRequest: TKWorkspaceLiveObserveRequest?

        _ = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-live-observe",
                target: "booted",
                platform: "ios",
                scope: "simulator",
                app: "com.example.demo",
                goal: "Seed from live observe",
                actionPolicy: "explore",
                observeLive: true,
                observeKind: "tree",
                observeMaxNodes: 25
            ),
            observeProvider: { request in
                observedRequest = request
                return fakeLiveObserveOutput(for: request)
            }
        )

        #expect(observedRequest?.action == "observe.tree")
        #expect(observedRequest?.platform == .ios)
        #expect(observedRequest?.target == "booted")
        #expect(observedRequest?.maxNodes == 25)

        let runDir = root.appendingPathComponent("run-workspace-live-observe", isDirectory: true)
        let observationURL = runDir.appendingPathComponent("evidence/observations/0000.json")
        #expect(FileManager.default.fileExists(atPath: observationURL.path))
        let rawObservation = try JSONSerialization.jsonObject(with: Data(contentsOf: observationURL)) as? [String: Any]
        #expect(rawObservation?["action"] as? String == "observe.tree")
        #expect((rawObservation?["nodes"] as? [[String: Any]])?.count == 2)

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let observation = try #require(parsed.events.first { $0.type == .observationCaptured })
        #expect(observation.artifacts?.screenshot == "fixtures/live-screenshot.png")
        #expect(observation.artifacts?.hierarchy == "fixtures/live-tree.json")
        #expect(observation.screenCandidate?.visibleTexts == ["Login", "Continue"])
        #expect(observation.screenCandidate?.screenshotSha256.count == 64)

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let screen = (atlas?["screens"] as? [[String: Any]])?.first
        #expect(screen?["dominantTexts"] as? [String] == ["Login", "Continue"])
        let evidenceRefs = screen?["evidenceRefs"] as? [String]
        #expect(evidenceRefs?.contains("evidence/observations/0000.json") == true)
        #expect(evidenceRefs?.contains("fixtures/live-tree.json") == true)
    }

    @Test("workspace HTTP run captures live observe seed when enabled")
    func workspaceHTTPRunCapturesLiveObserveSeedWhenEnabled() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        var observedRequest: TKWorkspaceLiveObserveRequest?

        let body = try JSONEncoder().encode(TKWorkspaceHTTPRunRequest(
            runsDir: root.path,
            runID: "run-workspace-http-live-observe",
            target: "booted",
            platform: "ios",
            scope: "simulator",
            app: "com.example.demo",
            goal: "HTTP live observe",
            actionPolicy: "explore",
            observeLive: true,
            observeKind: "current",
            observeMaxNodes: 7
        ))
        let run = try await handleWorkspaceHTTPRunAsync(body: body, observeProvider: { request in
            observedRequest = request
            return fakeLiveObserveOutput(for: request)
        })

        #expect(run.runID == "run-workspace-http-live-observe")
        #expect(observedRequest?.action == "observe.current")
        #expect(observedRequest?.maxNodes == 7)

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: root
                .appendingPathComponent("run-workspace-http-live-observe", isDirectory: true)
                .appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type == .observationCaptured }?.screenCandidate?.visibleTexts == ["Login", "Continue"])
    }

    @Test("workspace run records app launch evidence when enabled")
    func workspaceRunRecordsAppLaunchEvidenceWhenEnabled() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        var lifecycleRequest: TKWorkspaceAppLifecycleRequest?

        _ = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-app-launch",
                target: "booted",
                platform: "ios",
                scope: "simulator",
                app: "com.example.demo",
                goal: "Launch app",
                actionPolicy: "explore",
                appMode: "launch",
                bundleID: "com.example.demo"
            ),
            appLifecycleProvider: { request in
                lifecycleRequest = request
                return fakeAppLaunchEvidence(for: request)
            }
        )

        #expect(lifecycleRequest?.mode == "launch")
        #expect(lifecycleRequest?.platform == "ios")
        #expect(lifecycleRequest?.scope == "simulator")
        #expect(lifecycleRequest?.target == "booted")
        #expect(lifecycleRequest?.app == "com.example.demo")
        #expect(lifecycleRequest?.bundleID == "com.example.demo")

        let runDir = root.appendingPathComponent("run-workspace-app-launch", isDirectory: true)
        let appReady = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/actions/app-ready.json"))
        ) as? [String: Any]
        #expect(appReady?["mode"] as? String == "launch")
        #expect(appReady?["phase"] as? String == "launch_submitted")
        #expect(appReady?["action"] as? String == "app.launch")
        #expect(appReady?["ready"] as? Bool == false)
        #expect(appReady?["businessReady"] as? Bool == false)
        #expect(appReady?["runtimeScope"] as? String == "host-simulator")
        #expect(appReady?["sourceCommands"] as? [String] == [
            "triton app launch --platform ios --device booted --bundle-id com.example.demo --json",
        ])

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let appReadyEvent = try #require(parsed.events.first { $0.type == .appReady })
        #expect(appReadyEvent.phase == "launch_submitted")
        #expect(appReadyEvent.ref == "evidence/actions/app-ready.json")
    }

    @Test("workspace run records launch observed readiness when live observe follows launch")
    func workspaceRunRecordsLaunchObservedReadinessWhenLiveObserveFollowsLaunch() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-launch-observed",
                target: "booted",
                platform: "ios",
                scope: "simulator",
                app: "com.example.demo",
                goal: "Launch and observe",
                actionPolicy: "explore",
                appMode: "launch",
                bundleID: "com.example.demo",
                observeLive: true,
                observeKind: "tree"
            ),
            observeProvider: { request in
                fakeLiveObserveOutput(for: request)
            },
            appLifecycleProvider: { request in
                fakeAppLaunchEvidence(for: request)
            }
        )

        let runDir = root.appendingPathComponent("run-workspace-launch-observed", isDirectory: true)
        let appReady = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/actions/app-ready.json"))
        ) as? [String: Any]
        #expect(appReady?["mode"] as? String == "launch")
        #expect(appReady?["phase"] as? String == "launch_observed")
        #expect(appReady?["ready"] as? Bool == true)
        #expect(appReady?["businessReady"] as? Bool == false)
        #expect(appReady?["observedAfterLifecycle"] as? Bool == true)
        #expect(appReady?["observationRef"] as? String == "events.jsonl#observation.captured")
        let observation = appReady?["observation"] as? [String: Any]
        #expect(observation?["visibleTextCount"] as? Int == 2)
        #expect(observation?["screenshot"] as? String == "fixtures/live-screenshot.png")
        #expect(observation?["hierarchy"] as? String == "fixtures/live-tree.json")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type == .appReady }?.phase == "launch_observed")
        #expect(parsed.events.first { $0.type == .observationCaptured }?.screenCandidate?.visibleTexts == ["Login", "Continue"])
    }

    @Test("workspace run completes when business ready text is observed")
    func workspaceRunCompletesWhenBusinessReadyTextIsObserved() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)

        let run = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-business-ready",
            target: "current",
            app: "com.example.demo",
            goal: "Open login screen",
            actionPolicy: "explore",
            llmProvider: "mock",
            vlmProvider: "mock",
            observationFixture: fixture.path,
            businessReadyText: "Continue"
        ))

        #expect(run.status == "passed")
        #expect(run.business?.ready == true)
        #expect(run.business?.status == "passed")
        #expect(run.business?.query == "Continue")
        #expect(run.business?.ref == "evidence/business/ready.json")
        #expect(run.nextActions.isEmpty)

        let runDir = root.appendingPathComponent("run-workspace-business-ready", isDirectory: true)
        let businessReady = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/business/ready.json"))
        ) as? [String: Any]
        #expect(businessReady?["ready"] as? Bool == true)
        #expect(businessReady?["businessReady"] as? Bool == true)
        #expect(businessReady?["phase"] as? String == "text_matched")
        #expect(businessReady?["query"] as? String == "Continue")
        #expect(businessReady?["matchedTexts"] as? [String] == ["Continue"])
        #expect(businessReady?["observationRef"] as? String == "events.jsonl#observation.captured")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let eventTypes = parsed.events.map(\.type.rawValue)
        #expect(eventTypes.contains("business.ready"))
        #expect(eventTypes.contains("model.decided") == false)
        #expect(parsed.events.first { $0.type.rawValue == "business.ready" }?.status == .passed)
        #expect(parsed.events.first { $0.type == .verifyChecked }?.status == .passed)
        #expect(parsed.events.last?.type == .runFinished)
        #expect(parsed.summary.status == .passed)

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-business-ready",
            runsDirectory: root.path
        )
        #expect(inspected.run.status == "passed")
        #expect(inspected.run.business?.ready == true)
        #expect(inspected.latestPause == nil)
    }

    @Test("workspace HTTP run records app launch evidence when enabled")
    func workspaceHTTPRunRecordsAppLaunchEvidenceWhenEnabled() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        var lifecycleRequest: TKWorkspaceAppLifecycleRequest?

        let body = try JSONEncoder().encode(TKWorkspaceHTTPRunRequest(
            runsDir: root.path,
            runID: "run-workspace-http-app-launch",
            target: "emulator-5554",
            platform: "android",
            scope: "emulator",
            app: "com.example.demo",
            goal: "HTTP app launch",
            actionPolicy: "explore",
            appMode: "launch",
            packageName: "com.example.demo",
            activity: ".MainActivity"
        ))
        let run = try await handleWorkspaceHTTPRunAsync(body: body, appLifecycleProvider: { request in
            lifecycleRequest = request
            return fakeAppLaunchEvidence(for: request)
        })

        #expect(run.runID == "run-workspace-http-app-launch")
        #expect(lifecycleRequest?.platform == "android")
        #expect(lifecycleRequest?.scope == "emulator")
        #expect(lifecycleRequest?.target == "emulator-5554")
        #expect(lifecycleRequest?.packageName == "com.example.demo")
        #expect(lifecycleRequest?.activity == ".MainActivity")

        let appReady = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root
                .appendingPathComponent("run-workspace-http-app-launch", isDirectory: true)
                .appendingPathComponent("evidence/actions/app-ready.json"))
        ) as? [String: Any]
        #expect(appReady?["mode"] as? String == "launch")
        #expect(appReady?["runtimeScope"] as? String == "host-android")
        #expect(appReady?["sourceCommands"] as? [String] == [
            "triton app launch --platform android --device emulator-5554 --package-name com.example.demo --activity .MainActivity --json",
        ])
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
        let bootstrap = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/bootstrap-000.json"))
        ) as? [String: Any]
        #expect(bootstrap?["state"] as? String == "provider_ready")
        #expect(bootstrap?["proposal"] as? String == "candidate_available")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type == .providerChecked }?.phase == "ready")
        let eventTypes = parsed.events.map(\.type.rawValue)
        #expect(eventTypes.contains("flow.bootstrap.proposed"))
        #expect(eventTypes.contains("model.decided"))
        #expect(eventTypes.contains("policy.checked"))
        #expect(eventTypes.contains("action.executed"))
        #expect(eventTypes.contains("verify.checked"))
        #expect(eventTypes.contains("atlas.updated"))
        #expect(eventTypes.contains("flow.updated"))
        #expect(eventTypes.last == "run.stopped")
        let decisionRequest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/decision-000-request.redacted.json"))
        ) as? [String: Any]
        #expect(decisionRequest?["mode"] as? String == "mock-provider")

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-ai-ready",
            runsDirectory: root.path
        )
        #expect(inspected.latestBootstrap?.phase == "provider_ready")
        #expect(inspected.latestBootstrapProposal?.command == ["triton", "act", "tap", "Continue", "--json"])
        #expect(inspected.atlas.transitionCount == 1)
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
        #expect(eventTypes.contains("flow.bootstrap.proposed"))
        #expect(eventTypes.contains("policy.checked"))
        #expect(eventTypes.contains("action.executed"))
        #expect(eventTypes.contains("verify.checked"))
        #expect(eventTypes.contains("atlas.updated"))
        #expect(eventTypes.contains("flow.updated"))

        let runDir = root.appendingPathComponent("run-workspace-decision", isDirectory: true)
        let decision = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/decision-000.json"))
        ) as? [String: Any]
        let decisionArtifacts = decision?["artifacts"] as? [String: String]
        #expect(decisionArtifacts?["request"] == "evidence/model/decision-000-request.redacted.json")
        #expect(decisionArtifacts?["response"] == "evidence/model/decision-000-response.raw.txt")
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("evidence/model/decision-000-request.redacted.json").path))
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("evidence/model/decision-000-response.raw.txt").path))
        let bootstrapProposal = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/bootstrap-proposal-000.json"))
        ) as? [String: Any]
        let bootstrapArtifacts = bootstrapProposal?["artifacts"] as? [String: String]
        #expect(bootstrapArtifacts?["request"] == "evidence/model/bootstrap-proposal-000-request.redacted.json")
        #expect(bootstrapArtifacts?["response"] == "evidence/model/bootstrap-proposal-000-response.raw.txt")

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
        #expect(inspected.latestBootstrapProposal?.command == ["triton", "act", "tap", "Continue", "--json"])
    }

    @Test("workspace dry fixture policy rejects actions outside runner allowlist")
    func workspaceDryFixturePolicyRejectsActionsOutsideRunnerAllowlist() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let run = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-policy-reject",
            target: "current",
            app: "com.example.demo",
            goal: "Reject disallowed tap",
            actionPolicy: "explore",
            dryModelFixture: true,
            llmProvider: "mock",
            vlmProvider: "mock",
            allowedActions: ["wait"],
            stopConditions: ["policy_rejected"]
        ))
        #expect(run.status == "paused")
        #expect(run.nextActions.contains { $0.code == "review_policy_rejection" })

        let runDir = root.appendingPathComponent("run-workspace-policy-reject", isDirectory: true)
        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let eventTypes = parsed.events.map(\.type.rawValue)

        #expect(eventTypes.contains("model.decided"))
        #expect(eventTypes.contains("policy.checked"))
        #expect(eventTypes.contains("action.executed") == false)
        #expect(eventTypes.contains("verify.checked") == false)
        #expect(eventTypes.contains("atlas.updated") == false)
        #expect(eventTypes.last == "run.paused")
        #expect(parsed.events.first { $0.type == .policyChecked }?.status == .failed)
        #expect(parsed.events.last?.phase == "policy_rejected")
        #expect(parsed.summary.status == .paused)

        let policy = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/policy-000.json"))
        ) as? [String: Any]
        #expect(policy?["allowed"] as? Bool == false)
        #expect(policy?["stopReason"] as? String == "policy_rejected")
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("evidence/actions/action-000.json").path) == false)

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-policy-reject",
            runsDirectory: root.path
        )
        #expect(inspected.atlas.transitionCount == 0)
        #expect(inspected.atlas.deltaRef == nil)
        #expect(inspected.run.status == "paused")
        #expect(inspected.latestPause?.phase == "policy_rejected")
    }

    @Test("workspace mock provider loop rejects actions outside runner allowlist")
    func workspaceMockProviderLoopRejectsActionsOutsideRunnerAllowlist() throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let run = try runWorkspaceRun(TKWorkspaceRunRequest(
            runsDirectory: root.path,
            runID: "run-workspace-mock-policy-reject",
            target: "current",
            app: "com.example.demo",
            goal: "Reject mock provider tap",
            actionPolicy: "explore",
            llmProvider: "mock",
            vlmProvider: "mock",
            allowedActions: ["wait"],
            stopConditions: ["policy_rejected"]
        ))
        #expect(run.status == "paused")
        #expect(run.nextActions.contains { $0.code == "review_policy_rejection" })

        let runDir = root.appendingPathComponent("run-workspace-mock-policy-reject", isDirectory: true)
        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let eventTypes = parsed.events.map(\.type.rawValue)

        #expect(eventTypes.contains("flow.bootstrap.proposed"))
        #expect(eventTypes.contains("model.decided"))
        #expect(eventTypes.contains("policy.checked"))
        #expect(eventTypes.contains("action.executed") == false)
        #expect(eventTypes.contains("verify.checked") == false)
        #expect(eventTypes.contains("atlas.updated") == false)
        #expect(eventTypes.last == "run.paused")
        #expect(parsed.events.first { $0.type == .policyChecked }?.status == .failed)
        #expect(parsed.events.last?.phase == "policy_rejected")

        let policy = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/policy-000.json"))
        ) as? [String: Any]
        #expect(policy?["allowed"] as? Bool == false)
        #expect(policy?["stopReason"] as? String == "policy_rejected")
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("atlas/deltas.jsonl").path) == false)

        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-mock-policy-reject",
            runsDirectory: root.path
        )
        #expect(inspected.atlas.transitionCount == 0)
        #expect(inspected.latestPause?.phase == "policy_rejected")
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
        let fixture = try writeObservationFixture(in: root)

        let runResult = try runWorkspaceCLI([
            "workspace", "run",
            "--target", "current",
            "--platform", "ios",
            "--scope", "simulator",
            "--app", "com.example.demo",
            "--goal", "Explore login",
            "--runs-dir", root.path,
            "--run-id", "run-workspace-cli",
            "--observation-fixture", fixture.path,
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
        #expect(inspected.summary.eventCount == 17)
        let runDir = root.appendingPathComponent("run-workspace-cli", isDirectory: true)
        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type == .observationCaptured }?.screenCandidate?.visibleTexts == ["Login", "Continue"])

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
        let fixture = try writeObservationFixture(in: root)

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
            stopConditions: ["provider_missing"],
            observationFixture: fixture.path
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
        #expect(inspected.summary.eventCount == 17)
        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: root
                .appendingPathComponent("run-workspace-http", isDirectory: true)
                .appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type == .observationCaptured }?.screenCandidate?.visibleTexts == ["Login", "Continue"])

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

    private func writeObservationFixture(in root: URL) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = root.appendingPathComponent("observation-fixture.json")
        try """
        {
          "schemaVersion": 1,
          "kind": "triton.workspace.observation-fixture",
          "artifacts": {
            "screenshot": "fixtures/login.png",
            "ax": "fixtures/login-ax.json",
            "hierarchy": "fixtures/login-hierarchy.json"
          },
          "screenCandidate": {
            "screenshotSha256": "sha-login-screen",
            "axTextHash": "ax-login-text",
            "hierarchySha256": "hier-login-tree",
            "visibleTexts": ["Login", "Continue"]
          },
          "sourceCommands": ["triton observe current --json"],
          "changed": true
        }
        """.write(to: fixture, atomically: true, encoding: .utf8)
        return fixture
    }

    private func writeObserveOutputFixture(in root: URL) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = root.appendingPathComponent("observe-output.json")
        try """
        {
          "ok": true,
          "action": "observe.current",
          "platform": "ios",
          "capturedAt": "2026-07-07T00:00:00Z",
          "partial": false,
          "target": "sim:booted",
          "primarySource": {
            "name": "host-layout",
            "available": true,
            "reason": null,
            "artifact": "fixtures/observe-tree.json",
            "sourceCommands": ["triton observe current --platform ios --device booted --json"]
          },
          "sources": [
            {
              "name": "host-layout",
              "available": true,
              "reason": null,
              "artifact": "fixtures/observe-tree.json",
              "sourceCommands": ["triton observe current --platform ios --device booted --json"]
            }
          ],
          "nodes": [
            {
              "nodeID": "ios-host:1",
              "source": "host-layout",
              "role": "button",
              "text": "Login",
              "identifier": "login-button",
              "enabled": true,
              "focused": false,
              "hidden": false,
              "candidateOnly": false,
              "confidence": 0.96,
              "capabilities": ["tap"],
              "missingCapabilities": []
            },
            {
              "nodeID": "ios-host:2",
              "source": "host-layout",
              "role": "button",
              "text": "Continue",
              "identifier": "continue-button",
              "enabled": true,
              "focused": false,
              "hidden": false,
              "candidateOnly": false,
              "confidence": 0.93,
              "capabilities": ["tap"],
              "missingCapabilities": []
            }
          ],
          "artifacts": ["fixtures/login-screenshot.png", "fixtures/observe-tree.json", "fixtures/login-ax.json"],
          "sourceCommands": ["triton observe current --platform ios --device booted --json"],
          "note": "observe output fixture"
        }
        """.write(to: fixture, atomically: true, encoding: .utf8)
        return fixture
    }

    private func fakeLiveObserveOutput(for request: TKWorkspaceLiveObserveRequest) -> ObserveOutput {
        ObserveOutput(
            ok: true,
            action: request.action,
            platform: request.platform.rawValue,
            capturedAt: "2026-07-07T00:00:00Z",
            partial: false,
            target: "sim:\(request.target)",
            primarySource: ObserveSourceOutput(
                name: "host-layout",
                available: true,
                reason: nil,
                artifact: "fixtures/live-tree.json",
                sourceCommands: ["triton sim ax --device \(request.target) --json"]
            ),
            sources: [
                ObserveSourceOutput(
                    name: "host-layout",
                    available: true,
                    reason: nil,
                    artifact: "fixtures/live-tree.json",
                    sourceCommands: ["triton sim ax --device \(request.target) --json"]
                ),
            ],
            nodes: [
                ObserveNodeOutput(
                    nodeID: "ios-host:1",
                    source: "host-layout",
                    role: "button",
                    text: "Login",
                    identifier: "login-button",
                    frame: nil,
                    enabled: true,
                    focused: false,
                    hidden: false,
                    candidateOnly: false,
                    confidence: 0.96,
                    capabilities: ["visible", "tap"],
                    missingCapabilities: []
                ),
                ObserveNodeOutput(
                    nodeID: "ios-host:2",
                    source: "host-layout",
                    role: "button",
                    text: "Continue",
                    identifier: "continue-button",
                    frame: nil,
                    enabled: true,
                    focused: false,
                    hidden: false,
                    candidateOnly: false,
                    confidence: 0.93,
                    capabilities: ["visible", "tap"],
                    missingCapabilities: []
                ),
            ],
            artifacts: ["fixtures/live-screenshot.png", "fixtures/live-tree.json"],
            sourceCommands: ["triton sim ax --device \(request.target) --json"],
            note: "fake live observe"
        )
    }

    private func fakeAppLaunchEvidence(for request: TKWorkspaceAppLifecycleRequest) -> TKWorkspaceAppLifecycleEvidence {
        let runtimeScope: String
        switch request.platform {
        case "android":
            runtimeScope = "host-android"
        case "harmony":
            runtimeScope = "host-harmony"
        default:
            runtimeScope = "host-simulator"
        }
        return TKWorkspaceAppLifecycleEvidence(
            mode: request.mode,
            phase: "launch_submitted",
            action: "app.launch",
            app: request.app,
            platform: request.platform,
            scope: request.scope,
            target: request.target,
            runtimeScope: runtimeScope,
            ready: false,
            businessReady: false,
            submitted: true,
            sourceCommands: [fakeAppLaunchCommand(for: request)],
            artifacts: [],
            note: "fake app launch"
        )
    }

    private func fakeAppLaunchCommand(for request: TKWorkspaceAppLifecycleRequest) -> String {
        var parts = ["triton", "app", "launch"]
        if let platform = request.platform {
            parts += ["--platform", platform]
        }
        parts += ["--device", request.target]
        if let bundleID = request.bundleID {
            parts += ["--bundle-id", bundleID]
        }
        if let packageName = request.packageName {
            parts += ["--package-name", packageName]
        }
        if let activity = request.activity {
            parts += ["--activity", activity]
        }
        if let bundle = request.bundle {
            parts += ["--bundle", bundle]
        }
        if let ability = request.ability {
            parts += ["--ability", ability]
        }
        parts.append("--json")
        return parts.joined(separator: " ")
    }

    private func runWorkspaceCLI(_ arguments: [String]) throws -> WorkspaceCLIRunResult {
        let process = Process()
        process.executableURL = try tritonExecutableURL()
        process.arguments = arguments

        let captureDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-workspace-cli-capture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: captureDir) }

        let stdoutURL = captureDir.appendingPathComponent("stdout.txt")
        let stderrURL = captureDir.appendingPathComponent("stderr.txt")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdout.close()
            try? stderr.close()
        }
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()
        try stdout.close()
        try stderr.close()

        return WorkspaceCLIRunResult(
            exitCode: process.terminationStatus,
            stdout: try String(contentsOf: stdoutURL, encoding: .utf8),
            stderr: try String(contentsOf: stderrURL, encoding: .utf8)
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
