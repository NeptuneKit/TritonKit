import Foundation
import TritonKitShared

struct IOSSmokeOptions {
    let simulator: String
    let hostTarget: HostDeviceTarget
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

    init(
        simulator: String,
        hostTarget: HostDeviceTarget? = nil,
        target: String,
        bundleID: String,
        openURL: String,
        waitText: String,
        assertText: String?,
        screenshot: String?,
        evidence: String,
        evidenceName: String?,
        evidenceNote: String?,
        host: String,
        port: Int,
        timeout: Double,
        interval: Double
    ) {
        self.simulator = simulator
        self.hostTarget = hostTarget ?? HostDeviceTarget(
            platform: "ios",
            id: simulator.hasPrefix("ios-real:") ? simulator : "sim:\(simulator)",
            target: simulator,
            state: "booted",
            ready: true,
            source: "simctl",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "simulator",
            kind: "simulator"
        )
        self.target = target
        self.bundleID = bundleID
        self.openURL = openURL
        self.waitText = waitText
        self.assertText = assertText
        self.screenshot = screenshot
        self.evidence = evidence
        self.evidenceName = evidenceName
        self.evidenceNote = evidenceNote
        self.host = host
        self.port = port
        self.timeout = timeout
        self.interval = interval
    }
}

struct IOSSmokeDependencies {
    var makeRuntimeClient: (String, String, Int) async throws -> any SmokeRuntimeClient
    var openURL: (HostDeviceTarget, String, String) throws -> HostActionOutput
    var screenshot: (String, String) throws -> String
    var captureEvidence: (String, [String], String?, String?, String, String, Int, Bool) async throws -> TKEvidenceManifest

    static func live() -> IOSSmokeDependencies {
        IOSSmokeDependencies(
            makeRuntimeClient: { target, host, port in
                let resolved = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
                return LiveSmokeRuntimeClient(client: resolved.client)
            },
            openURL: { selected, bundleID, url in
                if selected.scope == HostDeviceScope.real.rawValue {
                    let artifacts = try freshDevicectlArtifactPaths(action: "smoke-open-url")
                    return try hostActionOutput(
                        action: "app.open-url",
                        runtimeScope: "host-ios-real",
                        target: "\(selected.id)/app:\(bundleID)",
                        command: TKDevicectlCommand.launchApp(
                            identifier: selected.rawTarget,
                            bundleID: bundleID,
                            payloadURL: url,
                            jsonOutput: artifacts.json,
                            logOutput: artifacts.log
                        ),
                        note: "iOS real-device URL was submitted; business readiness must be proven by embedded runtime wait/assert or evidence."
                    )
                }
                return try hostActionOutput(
                    action: "app.open-url",
                    runtimeScope: "host-ios-simulator",
                    target: "sim:\(selected.target)/app:\(bundleID)",
                    command: TKSimctlCommand.openURL(udid: selected.target, url: url),
                    note: "URL was submitted to the simulator."
                )
            },
            screenshot: { simulator, output in
                let result = try runHostCommand(TKSimctlCommand.screenshot(udid: simulator, output: output))
                return result.sourceCommand
            },
            captureEvidence: { output, includes, name, note, target, host, port, refresh in
                try await captureEvidenceBundle(
                    output: output,
                    includes: includes,
                    name: name,
                    note: note,
                    target: target,
                    host: host,
                    port: port,
                    refresh: refresh,
                    xcodeSummaryPath: nil
                )
            }
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
        let openURLAction = try dependencies.openURL(options.hostTarget, options.bundleID, options.openURL)
        let openURLSourceCommands = redactedSmokeSourceCommands([openURLAction.sourceCommand], target: options.hostTarget)
        steps.append(SmokeStepSummary(
            name: "app.open-url",
            status: .pass,
            proofSource: .hostAction,
            businessReady: false,
            sourceCommand: openURLSourceCommands,
            elapsedMs: Int(Date().timeIntervalSince(openURLStartedAt) * 1000),
            target: openURLAction.target,
            artifacts: [],
            message: openURLAction.note
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
            proofSource: .runtime,
            businessReady: waitResult.ok,
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
            message: assertResult.message,
            proofSource: .runtime
        ))
        steps.append(SmokeStepSummary(
            name: "runtime.assert",
            status: assertResult.ok ? .pass : .fail,
            proofSource: .runtime,
            businessReady: assertResult.ok,
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
            proofSource: .evidence,
            businessReady: true,
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
