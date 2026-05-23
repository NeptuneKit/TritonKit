import Foundation
import TritonKitShared

struct IOSSmokeOptions {
    let simulator: String
    let target: String
    let bundleID: String
    let openURL: String
    let waitText: String
    let assertText: String?
    let screenshot: String?
    let evidence: String
    let evidenceName: String?
    let evidenceNote: String?
    let host: String
    let port: Int
    let timeout: Double
    let interval: Double
}

struct HarmonySmokeOptions {
    let target: String
    let hdc: String
    let bundle: String
    let ability: String
    let openURL: String?
    let waitText: String
    let tapText: String?
    let postTapWaitText: String?
    let screenshot: String?
    let evidence: String
    let evidenceName: String?
    let evidenceNote: String?
    let timeout: Double
    let interval: Double
}

protocol SmokeRuntimeClient {
    func wait(_ request: WaitRequest) async throws -> TKWaitResult
    func assert(_ query: String) async throws -> TKUIAssertResult
}

struct HarmonySmokeDependencies {
    var resolveTarget: (String, String) throws -> TKHarmonyTarget
    var waitReady: (TKHarmonyTarget, String, Double, Double) async throws -> HostDeviceReadyEvent
    var appInspect: (TKHarmonyTarget, String, String) throws -> HostActionOutput
    var appLaunch: (TKHarmonyTarget, String, String, String) throws -> HostActionOutput
    var appOpenURL: (TKHarmonyTarget, String, String, String, String) throws -> HostActionOutput
    var waitText: (TKHarmonyTarget, String, String, Double, Double) async throws -> HostHarmonyWaitOutput
    var tapText: (TKHarmonyTarget, String, String) throws -> HostHarmonyTapOutput
    var captureLayout: (TKHarmonyTarget, String, String) throws -> HostHarmonyArtifactOutput
    var captureScreenshot: (TKHarmonyTarget, String, String) throws -> HostHarmonyArtifactOutput
    var captureEvidence: (String, TKHarmonyTarget, [SmokeArtifactSummary], [String], String?, String?) throws -> TKEvidenceManifest

    static func live() -> HarmonySmokeDependencies {
        HarmonySmokeDependencies(
            resolveTarget: { target, hdc in
                try resolveHarmonyTarget(target: target, hdc: hdc)
            },
            waitReady: { selected, hdc, timeout, interval in
                try await waitForHarmonyTargetReady(selected: selected, hdc: hdc, timeout: timeout, interval: interval)
            },
            appInspect: { selected, bundle, hdc in
                try hostAppInspectHarmony(selected: selected, bundle: bundle, hdc: hdc)
            },
            appLaunch: { selected, bundle, ability, hdc in
                try hostAppLaunchHarmony(selected: selected, bundle: bundle, ability: ability, hdc: hdc)
            },
            appOpenURL: { selected, bundle, ability, url, hdc in
                try hostAppOpenURLHarmony(selected: selected, bundle: bundle, ability: ability, url: url, hdc: hdc)
            },
            waitText: { selected, hdc, text, timeout, interval in
                try await waitForHarmonyText(selected: selected, hdc: hdc, text: text, timeout: timeout, interval: interval)
            },
            tapText: { selected, hdc, text in
                try hostTapHarmony(selected: selected, hdc: hdc, text: text)
            },
            captureLayout: { selected, hdc, output in
                try hostCaptureHarmonyLayout(selected: selected, hdc: hdc, output: output)
            },
            captureScreenshot: { selected, hdc, output in
                try hostCaptureHarmonyScreenshot(selected: selected, hdc: hdc, output: output)
            },
            captureEvidence: { output, target, artifacts, sourceCommands, name, note in
                try captureHarmonyEvidenceBundle(output: output, target: target, artifacts: artifacts, sourceCommands: sourceCommands, name: name, note: note)
            }
        )
    }
}

struct LiveSmokeRuntimeClient: SmokeRuntimeClient {
    let client: TritonKitHTTPClient

    func wait(_ request: WaitRequest) async throws -> TKWaitResult {
        try await performWait(request, client: client)
    }

    func assert(_ query: String) async throws -> TKUIAssertResult {
        let status: TKStatusResponse = try await client.getJSON("/status")
        let accessibilityData = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
        let request = TKUIAssertRequest(condition: .textExists, query: query)
        return TKUIAssertEvaluate(
            request,
            nodes: nodes,
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState
        )
    }
}

struct IOSSmokeDependencies {
    var makeRuntimeClient: (String, String, Int) async throws -> any SmokeRuntimeClient
    var openURL: (String, String) throws -> String
    var screenshot: (String, String) throws -> String
    var captureEvidence: (String, [String], String?, String?, String, String, Int, Bool) async throws -> TKEvidenceManifest

    static func live() -> IOSSmokeDependencies {
        IOSSmokeDependencies(
            makeRuntimeClient: { target, host, port in
                let resolved = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
                return LiveSmokeRuntimeClient(client: resolved.client)
            },
            openURL: { simulator, url in
                let command = TKSimctlCommand.openURL(udid: simulator, url: url)
                let result = try runHostCommand(command)
                return result.sourceCommand
            },
            screenshot: { simulator, output in
                let result = try runHostCommand(TKSimctlCommand.screenshot(udid: simulator, output: output))
                return result.sourceCommand
            },
            captureEvidence: captureEvidenceBundle
        )
    }
}

func runIOSSmoke(
    options: IOSSmokeOptions,
    dependencies: IOSSmokeDependencies = .live()
) async throws -> SmokeRunSummary {
    let startedAtDate = Date()
    let startedAt = ISO8601DateFormatter().string(from: startedAtDate)
    var steps: [SmokeStepSummary] = []
    var assertions: [SmokeAssertionSummary] = []
    var artifacts: [SmokeArtifactSummary] = []
    var failure: SmokeFailureSummary?
    var evidenceManifest: TKEvidenceManifest?

    func makeFail(step: String, code: String, error: Error, hint: String? = nil) -> SmokeRunSummary {
        failure = SmokeFailureSummary(step: step, code: code, message: "\(error)", hint: hint)
        return SmokeRunSummary(
            ok: false,
            action: "smoke.ios",
            platform: .ios,
            status: .fail,
            target: SmokeTargetSummary(
                simulator: options.simulator,
                runtimeTarget: options.target,
                bundleID: options.bundleID,
                bundleName: nil,
                abilityName: nil
            ),
            steps: steps,
            assertions: assertions,
            artifacts: artifacts,
            evidence: evidenceManifest,
            failure: failure,
            startedAt: startedAt,
            endedAt: ISO8601DateFormatter().string(from: Date()),
            elapsedMs: Int(Date().timeIntervalSince(startedAtDate) * 1000)
        )
    }

    do {
        let openURLStartedAt = Date()
        let openURLSourceCommand = try dependencies.openURL(options.simulator, options.openURL)
        steps.append(SmokeStepSummary(
            name: "app.open-url",
            status: .pass,
            sourceCommand: [openURLSourceCommand],
            elapsedMs: Int(Date().timeIntervalSince(openURLStartedAt) * 1000),
            target: "sim:\(options.simulator)",
            artifacts: [],
            message: "URL was submitted to the simulator."
        ))

        let runtime: any SmokeRuntimeClient
        do {
            runtime = try await dependencies.makeRuntimeClient(options.target, options.host, options.port)
        } catch {
            return makeFail(
                step: "runtime.connect",
                code: "runtime_not_connected",
                error: error,
                hint: "Check the local runtime service, target connectivity, and `triton status`."
            )
        }

        let waitStartedAt = Date()
        let waitRequest = WaitRequest(condition: .text, query: options.waitText, predicate: nil, role: nil, timeout: options.timeout, interval: options.interval)
        let waitResult: TKWaitResult
        do {
            waitResult = try await runtime.wait(waitRequest)
        } catch {
            return makeFail(
                step: "runtime.wait",
                code: "smoke_step_failed",
                error: error,
                hint: "Check host actions, runtime target connectivity, and evidence directory permissions."
            )
        }
        steps.append(SmokeStepSummary(
            name: "runtime.wait",
            status: waitResult.ok ? .pass : .fail,
            sourceCommand: [],
            elapsedMs: max(waitResult.elapsedMs, Int(Date().timeIntervalSince(waitStartedAt) * 1000)),
            target: options.target,
            artifacts: [],
            message: waitResult.ok ? nil : "Expected text to exist: \(waitResult.query ?? options.waitText)"
        ))
        guard waitResult.ok else {
            return makeFail(step: "runtime.wait", code: "text_not_found", error: RuntimeError("Expected text to exist: \(waitResult.query ?? options.waitText)"), hint: "Use `triton observe current --json` or `triton screenshot --json` to inspect current state.")
        }

        let assertQuery = options.assertText ?? options.waitText
        let assertStartedAt = Date()
        let assertResult: TKUIAssertResult
        do {
            assertResult = try await runtime.assert(assertQuery)
        } catch {
            return makeFail(
                step: "runtime.assert",
                code: "smoke_step_failed",
                error: error,
                hint: "Use `triton observe current --json` or `triton screenshot --json` to inspect current state."
            )
        }
        assertions.append(SmokeAssertionSummary(
            condition: assertResult.condition,
            query: assertResult.query,
            ok: assertResult.ok,
            count: assertResult.count,
            message: assertResult.message
        ))
        steps.append(SmokeStepSummary(
            name: "runtime.assert",
            status: assertResult.ok ? .pass : .fail,
            sourceCommand: [],
            elapsedMs: Int(Date().timeIntervalSince(assertStartedAt) * 1000),
            target: options.target,
            artifacts: [],
            message: assertResult.message
        ))
        guard assertResult.ok else {
            return makeFail(step: "runtime.assert", code: "text_not_found", error: RuntimeError(assertResult.message ?? "assert failed"), hint: "Use `triton observe current --json` or `triton screenshot --json` to inspect current state.")
        }

        if let screenshot = options.screenshot {
            let screenshotStartedAt = Date()
            let screenshotSourceCommand: String
            do {
                screenshotSourceCommand = try dependencies.screenshot(options.simulator, screenshot)
            } catch {
                return makeFail(
                    step: "sim.screenshot",
                    code: "artifact_write_failed",
                    error: error,
                    hint: "Check screenshot output directory permissions and available disk space."
                )
            }
            artifacts.append(SmokeArtifactSummary(kind: "screenshot", path: screenshot))
            steps.append(SmokeStepSummary(
                name: "sim.screenshot",
                status: .pass,
                sourceCommand: [screenshotSourceCommand],
                elapsedMs: Int(Date().timeIntervalSince(screenshotStartedAt) * 1000),
                target: "sim:\(options.simulator)",
                artifacts: [SmokeArtifactSummary(kind: "screenshot", path: screenshot)],
                message: "Host-side simulator screenshot was written."
            ))
        }

        let evidenceStartedAt = Date()
        do {
            evidenceManifest = try await dependencies.captureEvidence(
                options.evidence,
                ["status", "list", "version", "hierarchy", "ax", "screenshot"],
                options.evidenceName,
                options.evidenceNote,
                options.target,
                options.host,
                options.port,
                true
            )
        } catch {
            return makeFail(
                step: "evidence.capture",
                code: "artifact_write_failed",
                error: error,
                hint: "Check evidence output directory permissions and available disk space."
            )
        }
        let evidenceArtifact = SmokeArtifactSummary(kind: "evidence", path: options.evidence)
        artifacts.append(evidenceArtifact)
        steps.append(SmokeStepSummary(
            name: "evidence.capture",
            status: .pass,
            sourceCommand: [],
            elapsedMs: Int(Date().timeIntervalSince(evidenceStartedAt) * 1000),
            target: options.target,
            artifacts: [evidenceArtifact],
            message: "Evidence bundle was written."
        ))

        return SmokeRunSummary(
            ok: true,
            action: "smoke.ios",
            platform: .ios,
            status: .pass,
            target: SmokeTargetSummary(
                simulator: options.simulator,
                runtimeTarget: options.target,
                bundleID: options.bundleID,
                bundleName: nil,
                abilityName: nil
            ),
            steps: steps,
            assertions: assertions,
            artifacts: artifacts,
            evidence: evidenceManifest,
            failure: nil,
            startedAt: startedAt,
            endedAt: ISO8601DateFormatter().string(from: Date()),
            elapsedMs: Int(Date().timeIntervalSince(startedAtDate) * 1000)
        )
    } catch {
        return makeFail(
            step: steps.isEmpty ? "app.open-url" : "smoke.ios",
            code: "smoke_step_failed",
            error: error,
            hint: "Check host actions, runtime target connectivity, and evidence directory permissions."
        )
    }
}

func runHarmonySmoke(
    options: HarmonySmokeOptions,
    dependencies: HarmonySmokeDependencies = .live()
) async throws -> SmokeRunSummary {
    let startedAtDate = Date()
    let startedAt = ISO8601DateFormatter().string(from: startedAtDate)
    var steps: [SmokeStepSummary] = []
    var assertions: [SmokeAssertionSummary] = []
    var artifacts: [SmokeArtifactSummary] = []
    var sourceCommands: [String] = []
    var failure: SmokeFailureSummary?
    var evidenceManifest: TKEvidenceManifest?
    var selectedTarget: TKHarmonyTarget?

    func targetSummary() -> SmokeTargetSummary {
        SmokeTargetSummary(
            simulator: nil,
            runtimeTarget: selectedTarget?.target ?? options.target,
            bundleID: nil,
            bundleName: options.bundle,
            abilityName: options.ability
        )
    }

    func makeFail(step: String, code: String, error: Error, hint: String? = nil) -> SmokeRunSummary {
        failure = SmokeFailureSummary(step: step, code: code, message: "\(error)", hint: hint)
        return SmokeRunSummary(
            ok: false,
            action: "smoke.harmony",
            platform: .harmony,
            status: .fail,
            target: targetSummary(),
            steps: steps,
            assertions: assertions,
            artifacts: artifacts,
            evidence: evidenceManifest,
            failure: failure,
            startedAt: startedAt,
            endedAt: ISO8601DateFormatter().string(from: Date()),
            elapsedMs: Int(Date().timeIntervalSince(startedAtDate) * 1000)
        )
    }

    do {
        let selected = try dependencies.resolveTarget(options.target, options.hdc)
        selectedTarget = selected

        let readyStartedAt = Date()
        do {
            let ready = try await dependencies.waitReady(selected, options.hdc, options.timeout, options.interval)
            sourceCommands.append(ready.sourceCommand)
            steps.append(SmokeStepSummary(
                name: "device.wait-ready",
                status: ready.ready ? .pass : .fail,
                sourceCommand: [ready.sourceCommand],
                elapsedMs: Int(Date().timeIntervalSince(readyStartedAt) * 1000),
                target: selected.target,
                artifacts: [],
                message: ready.ready ? nil : "Harmony target was not ready."
            ))
            guard ready.ready else {
                return makeFail(step: "device.wait-ready", code: "device_not_ready", error: RuntimeError("Harmony target was not ready."), hint: "Check emulator boot state or increase --timeout.")
            }
        } catch {
            return makeFail(step: "device.wait-ready", code: "device_not_ready", error: error, hint: "Check emulator boot state, target id, and hdc availability.")
        }

        let inspectStartedAt = Date()
        do {
            let inspect = try dependencies.appInspect(selected, options.bundle, options.hdc)
            sourceCommands.append(inspect.sourceCommand)
            steps.append(SmokeStepSummary(
                name: "app.inspect",
                status: .pass,
                sourceCommand: [inspect.sourceCommand],
                elapsedMs: Int(Date().timeIntervalSince(inspectStartedAt) * 1000),
                target: inspect.target,
                artifacts: [],
                message: "Harmony app metadata was inspected."
            ))
        } catch {
            return makeFail(step: "app.inspect", code: "app_info_not_available", error: error, hint: "Verify the Harmony bundle is installed on the target.")
        }

        let openStartedAt = Date()
        do {
            let action: HostActionOutput
            let stepName: String
            if let openURL = options.openURL {
                action = try dependencies.appOpenURL(selected, options.bundle, options.ability, openURL, options.hdc)
                stepName = "app.open-url"
            } else {
                action = try dependencies.appLaunch(selected, options.bundle, options.ability, options.hdc)
                stepName = "app.launch"
            }
            sourceCommands.append(action.sourceCommand)
            steps.append(SmokeStepSummary(
                name: stepName,
                status: .pass,
                sourceCommand: [action.sourceCommand],
                elapsedMs: Int(Date().timeIntervalSince(openStartedAt) * 1000),
                target: action.target,
                artifacts: [],
                message: action.note
            ))
        } catch {
            let code = options.openURL == nil ? "app_launch_failed" : "host_open_url_failed"
            return makeFail(step: options.openURL == nil ? "app.launch" : "app.open-url", code: code, error: error, hint: "Verify the Harmony bundle, ability, target, and deep link URL.")
        }

        let waitStartedAt = Date()
        do {
            let wait = try await dependencies.waitText(selected, options.hdc, options.waitText, options.timeout, options.interval)
            sourceCommands.append(contentsOf: wait.sourceCommands)
            assertions.append(SmokeAssertionSummary(
                condition: "text-exists",
                query: options.waitText,
                ok: wait.matched,
                count: wait.matched ? 1 : 0,
                message: wait.matched ? nil : "Expected text to exist: \(options.waitText)"
            ))
            steps.append(SmokeStepSummary(
                name: "harmony.wait",
                status: wait.matched ? .pass : .fail,
                sourceCommand: wait.sourceCommands,
                elapsedMs: max(wait.elapsedMs, Int(Date().timeIntervalSince(waitStartedAt) * 1000)),
                target: selected.target,
                artifacts: [],
                message: wait.matched ? nil : "Expected text to exist: \(options.waitText)"
            ))
            guard wait.matched else {
                return makeFail(step: "harmony.wait", code: "text_not_found", error: RuntimeError("Expected text to exist: \(options.waitText)"), hint: "Run `triton ax --platform harmony --target \(selected.target) --json` to inspect current layout text.")
            }
        } catch {
            return makeFail(step: "harmony.wait", code: "text_not_found", error: error, hint: "Run `triton ax --platform harmony --target \(selected.target) --json` to inspect current layout text.")
        }

        if let tapText = options.tapText {
            let tapStartedAt = Date()
            do {
                let tap = try dependencies.tapText(selected, options.hdc, tapText)
                sourceCommands.append(contentsOf: tap.sourceCommands)
                steps.append(SmokeStepSummary(
                    name: "harmony.tap",
                    status: .pass,
                    sourceCommand: tap.sourceCommands,
                    elapsedMs: Int(Date().timeIntervalSince(tapStartedAt) * 1000),
                    target: selected.target,
                    artifacts: [],
                    message: tap.note
                ))
            } catch {
                return makeFail(step: "harmony.tap", code: "text_not_found", error: error, hint: "Run `triton ax --platform harmony --target \(selected.target) --json` to inspect tappable text.")
            }
        }

        if let postTapWaitText = options.postTapWaitText {
            let waitStartedAt = Date()
            do {
                let wait = try await dependencies.waitText(selected, options.hdc, postTapWaitText, options.timeout, options.interval)
                sourceCommands.append(contentsOf: wait.sourceCommands)
                assertions.append(SmokeAssertionSummary(
                    condition: "text-exists",
                    query: postTapWaitText,
                    ok: wait.matched,
                    count: wait.matched ? 1 : 0,
                    message: wait.matched ? nil : "Expected text to exist: \(postTapWaitText)"
                ))
                steps.append(SmokeStepSummary(
                    name: "harmony.post-tap-wait",
                    status: wait.matched ? .pass : .fail,
                    sourceCommand: wait.sourceCommands,
                    elapsedMs: max(wait.elapsedMs, Int(Date().timeIntervalSince(waitStartedAt) * 1000)),
                    target: selected.target,
                    artifacts: [],
                    message: wait.matched ? nil : "Expected text to exist: \(postTapWaitText)"
                ))
                guard wait.matched else {
                    return makeFail(step: "harmony.post-tap-wait", code: "text_not_found", error: RuntimeError("Expected text to exist: \(postTapWaitText)"), hint: "Run `triton ax --platform harmony --target \(selected.target) --json` to inspect current layout text.")
                }
            } catch {
                return makeFail(step: "harmony.post-tap-wait", code: "text_not_found", error: error, hint: "Run `triton ax --platform harmony --target \(selected.target) --json` to inspect current layout text.")
            }
        }

        let layoutPath = URL(fileURLWithPath: options.evidence)
            .appendingPathComponent("artifacts/harmony/layout.json")
            .path
        let layoutStartedAt = Date()
        do {
            let layout = try dependencies.captureLayout(selected, options.hdc, layoutPath)
            sourceCommands.append(contentsOf: layout.sourceCommands)
            let artifact = SmokeArtifactSummary(kind: "harmony.layout", path: layout.artifact)
            artifacts.append(artifact)
            steps.append(SmokeStepSummary(
                name: "harmony.layout",
                status: .pass,
                sourceCommand: layout.sourceCommands,
                elapsedMs: Int(Date().timeIntervalSince(layoutStartedAt) * 1000),
                target: selected.target,
                artifacts: [artifact],
                message: layout.note
            ))
        } catch {
            return makeFail(step: "harmony.layout", code: "artifact_write_failed", error: error, hint: "Check evidence output directory permissions and uitest dumpLayout availability.")
        }

        if let screenshot = options.screenshot {
            let screenshotStartedAt = Date()
            do {
                let output = try dependencies.captureScreenshot(selected, options.hdc, screenshot)
                sourceCommands.append(contentsOf: output.sourceCommands)
                let artifact = SmokeArtifactSummary(kind: "harmony.screenshot", path: output.artifact)
                artifacts.append(artifact)
                steps.append(SmokeStepSummary(
                    name: "harmony.screenshot",
                    status: .pass,
                    sourceCommand: output.sourceCommands,
                    elapsedMs: Int(Date().timeIntervalSince(screenshotStartedAt) * 1000),
                    target: selected.target,
                    artifacts: [artifact],
                    message: output.note
                ))
            } catch {
                return makeFail(step: "harmony.screenshot", code: "artifact_write_failed", error: error, hint: "Check screenshot output path and snapshot_display support.")
            }
        }

        let evidenceStartedAt = Date()
        do {
            evidenceManifest = try dependencies.captureEvidence(
                options.evidence,
                selected,
                artifacts,
                sourceCommands,
                options.evidenceName,
                options.evidenceNote
            )
            let evidenceArtifact = SmokeArtifactSummary(kind: "evidence", path: options.evidence)
            artifacts.append(evidenceArtifact)
            steps.append(SmokeStepSummary(
                name: "evidence.capture",
                status: .pass,
                sourceCommand: [],
                elapsedMs: Int(Date().timeIntervalSince(evidenceStartedAt) * 1000),
                target: selected.target,
                artifacts: [evidenceArtifact],
                message: "Harmony evidence bundle was written."
            ))
        } catch {
            return makeFail(step: "evidence.capture", code: "artifact_write_failed", error: error, hint: "Check evidence output directory permissions and available disk space.")
        }

        return SmokeRunSummary(
            ok: true,
            action: "smoke.harmony",
            platform: .harmony,
            status: .pass,
            target: targetSummary(),
            steps: steps,
            assertions: assertions,
            artifacts: artifacts,
            evidence: evidenceManifest,
            failure: nil,
            startedAt: startedAt,
            endedAt: ISO8601DateFormatter().string(from: Date()),
            elapsedMs: Int(Date().timeIntervalSince(startedAtDate) * 1000)
        )
    } catch {
        return makeFail(step: steps.isEmpty ? "device.wait-ready" : "smoke.harmony", code: "smoke_step_failed", error: error, hint: "Check Harmony target, bundle, ability, HDC, and evidence directory permissions.")
    }
}

func waitForHarmonyTargetReady(
    selected: TKHarmonyTarget,
    hdc: String,
    timeout: Double,
    interval: Double
) async throws -> HostDeviceReadyEvent {
    let deadline = Date().addingTimeInterval(timeout)
    var attempt = 0
    while true {
        attempt += 1
        let command = TKHarmonyHDCCommand.bootCompleted(target: selected.target, executable: hdc)
        let result = try runHostCommand(command)
        let ready = TKHarmonyBootCompletedParser.isReady(result.stdout)
        let event = HostDeviceReadyEvent(
            ok: ready,
            platform: "harmony",
            target: selected,
            ready: ready,
            attempt: attempt,
            sourceCommand: result.sourceCommand,
            error: nil
        )
        if ready { return event }
        if Date() >= deadline {
            throw HostCommandRunError.deviceNotReady(target: selected.target, timeoutSeconds: timeout)
        }
        let remaining = deadline.timeIntervalSinceNow
        let sleepSeconds = max(0.01, min(interval, remaining))
        try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
    }
}

func hostAppInspectHarmony(selected: TKHarmonyTarget, bundle: String, hdc: String) throws -> HostActionOutput {
    try hostActionOutput(
        action: "app.inspect",
        target: "harmony:\(selected.target)/app:\(bundle)",
        command: TKHarmonyHDCCommand.appInspect(target: selected.target, bundleName: bundle, executable: hdc),
        note: "Harmony app metadata was inspected with bm dump."
    )
}

func hostAppLaunchHarmony(selected: TKHarmonyTarget, bundle: String, ability: String, hdc: String) throws -> HostActionOutput {
    try hostActionOutput(
        action: "app.launch",
        target: "harmony:\(selected.target)/app:\(bundle)",
        command: TKHarmonyHDCCommand.appLaunch(target: selected.target, bundleName: bundle, abilityName: ability, executable: hdc),
        note: "Harmony app launch was requested; verify readiness with wait, ax, or screenshot."
    )
}

func hostAppOpenURLHarmony(selected: TKHarmonyTarget, bundle: String, ability: String, url: String, hdc: String) throws -> HostActionOutput {
    try hostActionOutput(
        action: "app.open-url",
        target: "harmony:\(selected.target)/app:\(bundle)",
        command: TKHarmonyHDCCommand.appOpenURL(target: selected.target, bundleName: bundle, abilityName: ability, url: url, executable: hdc),
        note: "Harmony deep link was submitted; verify business completion with wait, ax, or screenshot."
    )
}

func hostActionOutput(action: String, target: String, command: TKHostCommand, note: String) throws -> HostActionOutput {
    let result = try runHostCommand(command)
    let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    return HostActionOutput(
        ok: true,
        action: action,
        runtimeScope: "host-harmony",
        target: target,
        tool: command.executable,
        exitCode: result.exitCode,
        riskLevel: command.riskLevel.rawValue,
        sourceCommand: result.sourceCommand,
        stdoutTruncated: result.stdoutTruncated,
        stderrTruncated: result.stderrTruncated,
        stdout: stdout.isEmpty ? nil : stdout,
        stderr: stderr.isEmpty ? nil : stderr,
        artifacts: [],
        note: note
    )
}

func waitForHarmonyText(
    selected: TKHarmonyTarget,
    hdc: String,
    text: String,
    timeout: Double,
    interval: Double
) async throws -> HostHarmonyWaitOutput {
    let startedAt = Date()
    let deadline = startedAt.addingTimeInterval(timeout)
    var pollCount = 0
    var lastMatch: TKHarmonyLayoutTextMatch?
    var sourceCommands: [String] = []
    while true {
        pollCount += 1
        let layout = try dumpHarmonyLayout(selected: selected, hdc: hdc, output: nil)
        sourceCommands.append(contentsOf: layout.sourceCommands)
        lastMatch = try TKHarmonyLayoutParser.firstTextMatch(in: layout.data, text: text)
        if lastMatch != nil {
            return HostHarmonyWaitOutput(
                ok: true,
                action: "wait",
                platform: "harmony",
                target: selected,
                condition: "text",
                query: text,
                matched: true,
                timedOut: false,
                elapsedMs: elapsedMilliseconds(since: startedAt),
                pollCount: pollCount,
                match: lastMatch,
                sourceCommands: sourceCommands
            )
        }
        if Date() >= deadline {
            return HostHarmonyWaitOutput(
                ok: false,
                action: "wait",
                platform: "harmony",
                target: selected,
                condition: "text",
                query: text,
                matched: false,
                timedOut: true,
                elapsedMs: elapsedMilliseconds(since: startedAt),
                pollCount: pollCount,
                match: lastMatch,
                sourceCommands: sourceCommands
            )
        }
        let remaining = deadline.timeIntervalSinceNow
        let sleepSeconds = max(0.01, min(interval, remaining))
        try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
    }
}

func hostTapHarmony(selected: TKHarmonyTarget, hdc: String, text: String) throws -> HostHarmonyTapOutput {
    let layout = try dumpHarmonyLayout(selected: selected, hdc: hdc, output: nil)
    guard let resolved = try TKHarmonyLayoutParser.firstTextMatch(in: layout.data, text: text) else {
        throw HostCommandRunError.layoutTextNotFound(text)
    }
    let tapResult = try runHostCommand(TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: resolved.centerX, y: resolved.centerY, executable: hdc))
    return HostHarmonyTapOutput(
        ok: true,
        action: "tap",
        platform: "harmony",
        target: selected,
        query: text,
        x: resolved.centerX,
        y: resolved.centerY,
        match: resolved,
        sourceCommands: layout.sourceCommands + [tapResult.sourceCommand],
        note: "Harmony tap was submitted through uitest; verify business state with wait, ax, or screenshot."
    )
}

func hostCaptureHarmonyLayout(selected: TKHarmonyTarget, hdc: String, output: String) throws -> HostHarmonyArtifactOutput {
    let layout = try dumpHarmonyLayout(selected: selected, hdc: hdc, output: output)
    return HostHarmonyArtifactOutput(
        ok: true,
        action: "ax",
        platform: "harmony",
        target: selected,
        artifact: layout.localPath,
        sourceCommands: layout.sourceCommands,
        note: "Harmony layout was dumped with uitest and written locally."
    )
}

func hostCaptureHarmonyScreenshot(selected: TKHarmonyTarget, hdc: String, output: String) throws -> HostHarmonyArtifactOutput {
    let capture = try captureHarmonyScreenshot(selected: selected, hdc: hdc, output: output)
    return HostHarmonyArtifactOutput(
        ok: true,
        action: "screenshot",
        platform: "harmony",
        target: selected,
        artifact: output,
        sourceCommands: capture.sourceCommands,
        note: "Harmony screenshot was captured through snapshot_display using remote artifact \(capture.remotePath)."
    )
}

func captureHarmonyEvidenceBundle(
    output: String,
    target: TKHarmonyTarget,
    artifacts: [SmokeArtifactSummary],
    sourceCommands: [String],
    name: String?,
    note: String?
) throws -> TKEvidenceManifest {
    let outputURL = URL(fileURLWithPath: output)
    try prepareEvidenceOutputDirectory(outputURL)
    var evidenceArtifacts: [TKEvidenceArtifact] = []
    for artifact in artifacts {
        let sourceURL = URL(fileURLWithPath: artifact.path)
        let relativePath = "artifacts/harmony/\(sanitizedPathComponent(artifact.kind))/\(sourceURL.lastPathComponent)"
        let destinationURL = outputURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if sourceURL.path != destinationURL.path {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let bytes = attributes[.size] as? Int
        evidenceArtifacts.append(TKEvidenceArtifact(
            kind: artifact.kind,
            path: relativePath,
            contentType: artifact.kind.contains("screenshot") ? "image/jpeg" : "application/json",
            bytes: bytes,
            freshness: TKEvidenceFreshness(capturedAt: ISO8601DateFormatter().string(from: Date()), source: "host-harmony"),
            platform: "harmony",
            riskLevel: artifact.kind.contains("screenshot") ? "private" : "summary",
            policy: "harmony-private",
            redactionStatus: artifact.kind.contains("screenshot") ? "excluded-from-summary" : "included",
            sourceCommand: sourceCommands.joined(separator: "\n"),
            target: target.id
        ))
    }
    let manifest = TKEvidenceManifest(
        ok: true,
        name: name,
        note: note,
        createdAt: ISO8601DateFormatter().string(from: Date()),
        output: outputURL.path,
        artifacts: evidenceArtifacts,
        target: TKEvidenceTarget(
            id: target.id,
            connected: target.isConnected,
            appName: nil,
            bundleIdentifier: nil,
            deviceDescription: target.transport,
            osDescription: target.state,
            identityState: target.isConnected ? "connected" : "disconnected",
            targetConnectionState: target.state,
            hierarchyCacheState: nil
        ),
        cli: TKEvidenceCLI(version: TritonKitBuildInfo.cliVersion)
    )
    try prettyEncodedData(manifest).write(to: outputURL.appendingPathComponent("manifest.json"), options: .atomic)
    let summary = summarizeEvidenceManifest(manifest, input: outputURL.path, profile: "harmony-private")
    try prettyEncodedData(summary).write(to: outputURL.appendingPathComponent("summary.json"), options: .atomic)
    return manifest
}

func summarizeEvidenceManifest(_ manifest: TKEvidenceManifest, input: String, profile: String) -> TKEvidenceSummaryResponse {
    TKEvidenceSummaryResponse(
        action: "evidence.summary",
        input: input,
        profile: profile,
        createdAt: manifest.createdAt,
        name: manifest.name,
        note: manifest.note,
        output: manifest.output,
        artifactCount: manifest.artifacts.count,
        sensitiveArtifactCount: manifest.artifacts.filter(evidenceArtifactIsSensitive).count,
        skippedCount: manifest.skipped.count,
        target: manifest.target,
        cli: manifest.cli,
        artifacts: manifest.artifacts.map(evidenceArtifactSummary),
        skipped: manifest.skipped,
        suggestedCommands: []
    )
}
