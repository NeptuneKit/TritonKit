import Foundation
import TritonKitShared

struct AndroidSmokeOptions {
    let target: HostDeviceTarget
    let adb: String
    let package: String
    let activity: String?
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


struct AndroidSmokeDependencies {
    var waitReady: (HostDeviceTarget, String, Double, Double) async throws -> HostDeviceReadyEvent
    var appLaunch: (HostDeviceTarget, String, String?, String) throws -> HostActionOutput
    var appOpenURL: (HostDeviceTarget, String, String?, String, String) throws -> HostActionOutput
    var waitText: (HostDeviceTarget, String, String, Double, Double) async throws -> HostAndroidWaitOutput
    var tapText: (HostDeviceTarget, String, String) throws -> HostAndroidTapOutput
    var captureLayout: (HostDeviceTarget, String, String) throws -> HostAndroidArtifactOutput
    var captureScreenshot: (HostDeviceTarget, String, String) throws -> HostAndroidArtifactOutput
    var captureEvidence: (String, HostDeviceTarget, [SmokeArtifactSummary], [String], String?, String?) throws -> TKEvidenceManifest

    static func live() -> AndroidSmokeDependencies {
        AndroidSmokeDependencies(
            waitReady: { selected, adb, timeout, interval in
                try await waitForAndroidTargetReady(selected: selected, adb: adb, timeout: timeout, interval: interval)
            },
            appLaunch: { selected, package, activity, adb in
                try hostAppLaunchAndroid(selected: selected, package: package, activity: activity, adb: adb)
            },
            appOpenURL: { selected, package, activity, url, adb in
                try hostAppOpenURLAndroid(selected: selected, package: package, activity: activity, url: url, adb: adb)
            },
            waitText: { selected, adb, text, timeout, interval in
                try await waitForAndroidText(selected: selected, adb: adb, text: text, timeout: timeout, interval: interval)
            },
            tapText: { selected, adb, text in
                try hostTapAndroid(selected: selected, adb: adb, text: text)
            },
            captureLayout: { selected, adb, output in
                try hostCaptureAndroidLayout(selected: selected, adb: adb, output: output)
            },
            captureScreenshot: { selected, adb, output in
                try hostCaptureAndroidScreenshot(selected: selected, adb: adb, output: output)
            },
            captureEvidence: { output, target, artifacts, sourceCommands, name, note in
                try captureAndroidEvidenceBundle(output: output, target: target, artifacts: artifacts, sourceCommands: sourceCommands, name: name, note: note)
            }
        )
    }
}

func runAndroidSmoke(
    options: AndroidSmokeOptions,
    dependencies: AndroidSmokeDependencies = .live()
) async throws -> SmokeRunSummary {
    let startedAtDate = Date()
    let startedAt = ISO8601DateFormatter().string(from: startedAtDate)
    var steps: [SmokeStepSummary] = []
    var assertions: [SmokeAssertionSummary] = []
    var artifacts: [SmokeArtifactSummary] = []
    var sourceCommands: [String] = []
    var failure: SmokeFailureSummary?
    var evidenceManifest: TKEvidenceManifest?

    func targetSummary() -> SmokeTargetSummary {
        SmokeTargetSummary(
            simulator: nil,
            runtimeTarget: options.target.id,
            bundleID: options.package,
            bundleName: nil,
            abilityName: options.activity
        )
    }

    func makeFail(step: String, code: String, error: Error, hint: String? = nil) -> SmokeRunSummary {
        failure = SmokeFailureSummary(step: step, code: code, message: "\(error)", hint: hint)
        return SmokeRunSummary(
            ok: false,
            action: "smoke.android",
            platform: .android,
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

    let readyStartedAt = Date()
    do {
        let ready = try await dependencies.waitReady(options.target, options.adb, options.timeout, options.interval)
        let readySourceCommands = redactedSmokeSourceCommands([ready.sourceCommand], target: options.target)
        sourceCommands.append(contentsOf: readySourceCommands)
        steps.append(SmokeStepSummary(
            name: "device.wait-ready",
            status: ready.ready ? .pass : .fail,
            sourceCommand: readySourceCommands,
            elapsedMs: Int(Date().timeIntervalSince(readyStartedAt) * 1000),
            target: options.target.target,
            artifacts: [],
            message: ready.ready ? nil : "Android target was not ready."
        ))
        guard ready.ready else {
            return makeFail(step: "device.wait-ready", code: "device_not_ready", error: RuntimeError("Android target was not ready."), hint: "Check emulator boot state or increase --timeout.")
        }
    } catch {
        return makeFail(step: "device.wait-ready", code: "device_not_ready", error: error, hint: "Check emulator boot state, target id, and adb availability.")
    }

    let openStartedAt = Date()
    do {
        let action: HostActionOutput
        let stepName: String
        if let openURL = options.openURL {
            action = try dependencies.appOpenURL(options.target, options.package, options.activity, openURL, options.adb)
            stepName = "app.open-url"
        } else {
            action = try dependencies.appLaunch(options.target, options.package, options.activity, options.adb)
            stepName = "app.launch"
        }
        let actionSourceCommands = redactedSmokeSourceCommands([action.sourceCommand], target: options.target)
        sourceCommands.append(contentsOf: actionSourceCommands)
        steps.append(SmokeStepSummary(
            name: stepName,
            status: .pass,
            proofSource: .hostAction,
            businessReady: false,
            sourceCommand: actionSourceCommands,
            elapsedMs: Int(Date().timeIntervalSince(openStartedAt) * 1000),
            target: action.target,
            artifacts: [],
            message: action.note
        ))
    } catch {
        let code = options.openURL == nil ? "app_launch_failed" : "host_open_url_failed"
        return makeFail(step: options.openURL == nil ? "app.launch" : "app.open-url", code: code, error: error, hint: "Verify the Android package, optional activity, target, and deep link URL.")
    }

    let waitStartedAt = Date()
    do {
        let wait = try await dependencies.waitText(options.target, options.adb, options.waitText, options.timeout, options.interval)
        let waitSourceCommands = redactedSmokeSourceCommands(wait.sourceCommands, target: options.target)
        sourceCommands.append(contentsOf: waitSourceCommands)
        assertions.append(SmokeAssertionSummary(condition: "text-exists", query: options.waitText, ok: wait.matched, count: wait.matched ? 1 : 0, message: wait.matched ? nil : "Expected text to exist: \(options.waitText)", proofSource: .hostLayout))
        steps.append(SmokeStepSummary(
            name: "android.wait",
            status: wait.matched ? .pass : .fail,
            proofSource: .hostLayout,
            businessReady: wait.matched,
            sourceCommand: waitSourceCommands,
            elapsedMs: max(wait.elapsedMs, Int(Date().timeIntervalSince(waitStartedAt) * 1000)),
            target: options.target.target,
            artifacts: [],
            message: wait.matched ? nil : "Expected text to exist: \(options.waitText)"
        ))
        guard wait.matched else {
            return makeFail(step: "android.wait", code: "text_not_found", error: RuntimeError("Expected text to exist: \(options.waitText)"), hint: "Run `triton observe tree --platform android --device \(options.target.target) --json` to inspect current layout text.")
        }
    } catch {
        return makeFail(step: "android.wait", code: "text_not_found", error: error, hint: "Run `triton observe tree --platform android --device \(options.target.target) --json` to inspect current layout text.")
    }

    if let tapText = options.tapText {
        let tapStartedAt = Date()
        do {
            let tap = try dependencies.tapText(options.target, options.adb, tapText)
            let tapSourceCommands = redactedSmokeSourceCommands(tap.sourceCommands, target: options.target)
            sourceCommands.append(contentsOf: tapSourceCommands)
            steps.append(SmokeStepSummary(name: "android.tap", status: .pass, sourceCommand: tapSourceCommands, elapsedMs: Int(Date().timeIntervalSince(tapStartedAt) * 1000), target: options.target.target, artifacts: [], message: tap.note))
        } catch {
            return makeFail(step: "android.tap", code: "text_not_found", error: error, hint: "Run `triton observe tree --platform android --device \(options.target.target) --json` to inspect tappable text.")
        }
    }

    if let postTapWaitText = options.postTapWaitText {
        let postWaitStartedAt = Date()
        do {
            let wait = try await dependencies.waitText(options.target, options.adb, postTapWaitText, options.timeout, options.interval)
            let waitSourceCommands = redactedSmokeSourceCommands(wait.sourceCommands, target: options.target)
            sourceCommands.append(contentsOf: waitSourceCommands)
            assertions.append(SmokeAssertionSummary(condition: "text-exists", query: postTapWaitText, ok: wait.matched, count: wait.matched ? 1 : 0, message: wait.matched ? nil : "Expected text to exist: \(postTapWaitText)", proofSource: .hostLayout))
            steps.append(SmokeStepSummary(name: "android.post-tap-wait", status: wait.matched ? .pass : .fail, proofSource: .hostLayout, businessReady: wait.matched, sourceCommand: waitSourceCommands, elapsedMs: max(wait.elapsedMs, Int(Date().timeIntervalSince(postWaitStartedAt) * 1000)), target: options.target.target, artifacts: [], message: wait.matched ? nil : "Expected text to exist: \(postTapWaitText)"))
            guard wait.matched else {
                return makeFail(step: "android.post-tap-wait", code: "text_not_found", error: RuntimeError("Expected text to exist: \(postTapWaitText)"), hint: "Run `triton observe tree --platform android --device \(options.target.target) --json` to inspect current layout text.")
            }
        } catch {
            return makeFail(step: "android.post-tap-wait", code: "text_not_found", error: error, hint: "Run `triton observe tree --platform android --device \(options.target.target) --json` to inspect current layout text.")
        }
    }

    let layoutPath = URL(fileURLWithPath: options.evidence).appendingPathComponent("artifacts/android/layout.xml").path
    do {
        let layout = try dependencies.captureLayout(options.target, options.adb, layoutPath)
        let layoutSourceCommands = redactedSmokeSourceCommands(layout.sourceCommands, target: options.target)
        sourceCommands.append(contentsOf: layoutSourceCommands)
        let artifact = SmokeArtifactSummary(kind: "host.layout", path: layout.artifact)
        artifacts.append(artifact)
        steps.append(SmokeStepSummary(name: "android.layout", status: .pass, proofSource: .hostLayout, businessReady: false, sourceCommand: layoutSourceCommands, elapsedMs: 0, target: options.target.target, artifacts: [artifact], message: layout.note))
    } catch {
        return makeFail(step: "android.layout", code: "artifact_write_failed", error: error, hint: "Check evidence output directory permissions and UIAutomator dump availability.")
    }

    if let screenshot = options.screenshot {
        do {
            let output = try dependencies.captureScreenshot(options.target, options.adb, screenshot)
            let screenshotSourceCommands = redactedSmokeSourceCommands(output.sourceCommands, target: options.target)
            sourceCommands.append(contentsOf: screenshotSourceCommands)
            let artifact = SmokeArtifactSummary(kind: "screenshot", path: output.artifact)
            artifacts.append(artifact)
            steps.append(SmokeStepSummary(name: "android.screenshot", status: .pass, sourceCommand: screenshotSourceCommands, elapsedMs: 0, target: options.target.target, artifacts: [artifact], message: output.note))
        } catch {
            return makeFail(step: "android.screenshot", code: "artifact_write_failed", error: error, hint: "Check screenshot output path and adb screencap support.")
        }
    }

    do {
        evidenceManifest = try dependencies.captureEvidence(options.evidence, options.target, artifacts, sourceCommands, options.evidenceName, options.evidenceNote)
        let evidenceArtifact = SmokeArtifactSummary(kind: "evidence", path: options.evidence)
        artifacts.append(evidenceArtifact)
        steps.append(SmokeStepSummary(name: "evidence.capture", status: .pass, proofSource: .evidence, businessReady: true, sourceCommand: [], elapsedMs: 0, target: options.target.target, artifacts: [evidenceArtifact], message: "Android evidence bundle was written."))
    } catch {
        return makeFail(step: "evidence.capture", code: "artifact_write_failed", error: error, hint: "Check evidence output directory permissions and available disk space.")
    }

    return SmokeRunSummary(
        ok: true,
        action: "smoke.android",
        platform: .android,
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
}

func waitForAndroidTargetReady(
    selected: HostDeviceTarget,
    adb: String,
    timeout: Double,
    interval: Double
) async throws -> HostDeviceReadyEvent {
    let deadline = Date().addingTimeInterval(timeout)
    var attempt = 0
    while true {
        attempt += 1
        let command = TKAndroidADBCommand.bootCompleted(serial: selected.rawTarget, executable: adb)
        let result = try runHostCommand(command)
        let ready = TKAndroidBootCompletedParser.parse(result.stdout, stderr: result.stderr, exitCode: result.exitCode) == .ready
        let event = HostDeviceReadyEvent(ok: ready, platform: "android", target: selected, ready: ready, attempt: attempt, sourceCommand: result.sourceCommand, error: nil)
        if ready { return event }
        if Date() >= deadline {
            throw HostCommandRunError.deviceNotReady(target: selected.target, timeoutSeconds: timeout)
        }
        let remaining = deadline.timeIntervalSinceNow
        let sleepSeconds = max(0.01, min(interval, remaining))
        try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
    }
}

func hostAppLaunchAndroid(selected: HostDeviceTarget, package: String, activity: String?, adb: String) throws -> HostActionOutput {
    let component: String
    if let activity, !activity.isEmpty {
        component = "\(package)/\(activity)"
    } else {
        let resolveCommand = TKAndroidADBCommand.resolveActivity(serial: selected.rawTarget, packageName: package, executable: adb)
        let resolveResult = try runHostCommand(resolveCommand)
        let resolved = TKAndroidResolveActivityParser.parse(resolveResult.stdout, stderr: resolveResult.stderr, exitCode: resolveResult.exitCode)
        guard resolved.ok, let resolvedComponent = resolved.component else {
            throw HostCommandRunError.nonZeroExit(command: resolveCommand, result: resolveResult)
        }
        component = resolvedComponent
    }
    return try hostActionOutput(action: "app.launch", runtimeScope: "host-android", target: "\(selected.id)/app:\(package)", command: TKAndroidADBCommand.launch(serial: selected.rawTarget, component: component, executable: adb), note: "Android app launch was requested; verify readiness with wait, observe, or screenshot.")
}

func hostAppOpenURLAndroid(selected: HostDeviceTarget, package: String, activity: String?, url: String, adb: String) throws -> HostActionOutput {
    _ = activity
    return try hostActionOutput(action: "app.open-url", runtimeScope: "host-android", target: "\(selected.id)/app:\(package)", command: TKAndroidADBCommand.openURL(serial: selected.rawTarget, url: url, packageName: package, executable: adb), note: "Android deep link was submitted; verify business completion with wait, observe, or screenshot.")
}

func hostActionOutput(action: String, runtimeScope: String, target: String, command: TKHostCommand, note: String) throws -> HostActionOutput {
    let result = try runHostCommand(command)
    let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    return HostActionOutput(ok: true, action: action, runtimeScope: runtimeScope, target: target, tool: command.executable, exitCode: result.exitCode, riskLevel: command.riskLevel.rawValue, sourceCommand: result.sourceCommand, stdoutTruncated: result.stdoutTruncated, stderrTruncated: result.stderrTruncated, stdout: stdout.isEmpty ? nil : stdout, stderr: stderr.isEmpty ? nil : stderr, artifacts: [], note: note)
}

func waitForAndroidText(selected: HostDeviceTarget, adb: String, text: String, timeout: Double, interval: Double) async throws -> HostAndroidWaitOutput {
    let startedAt = Date()
    let deadline = startedAt.addingTimeInterval(timeout)
    var pollCount = 0
    var lastMatch: HostAndroidTapMatch?
    var sourceCommands: [String] = []
    while true {
        pollCount += 1
        let (match, commands) = try observeAndroidTextMatch(selected: selected, query: text, adb: adb)
        sourceCommands.append(contentsOf: commands)
        lastMatch = match
        if lastMatch != nil {
            return HostAndroidWaitOutput(ok: true, action: "wait", platform: "android", target: selected, condition: "text", query: text, matched: true, timedOut: false, elapsedMs: elapsedMilliseconds(since: startedAt), pollCount: pollCount, match: lastMatch, sourceCommands: sourceCommands)
        }
        if Date() >= deadline {
            return HostAndroidWaitOutput(ok: false, action: "wait", platform: "android", target: selected, condition: "text", query: text, matched: false, timedOut: true, elapsedMs: elapsedMilliseconds(since: startedAt), pollCount: pollCount, match: lastMatch, sourceCommands: sourceCommands)
        }
        let remaining = deadline.timeIntervalSinceNow
        let sleepSeconds = max(0.01, min(interval, remaining))
        try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
    }
}

func hostTapAndroid(selected: HostDeviceTarget, adb: String, text: String) throws -> HostAndroidTapOutput {
    let resolved = try resolveAndroidTapQuery(selected: selected, query: text, adb: adb)
    let tapResult = try runHostCommand(TKAndroidADBCommand.tapCoordinate(serial: selected.rawTarget, x: resolved.x, y: resolved.y, executable: adb))
    return HostAndroidTapOutput(ok: true, action: "tap", platform: "android", target: selected, query: text, x: resolved.x, y: resolved.y, match: resolved.match, sourceCommands: resolved.sourceCommands + [tapResult.sourceCommand], note: "Android tap was submitted through adb input; verify business state with wait, observe, or screenshot.")
}

func hostCaptureAndroidLayout(selected: HostDeviceTarget, adb: String, output: String) throws -> HostAndroidArtifactOutput {
    let result = try observeAndroid(action: "observe.tree", selected: selected, output: output)
    return HostAndroidArtifactOutput(ok: true, action: "ax", platform: "android", target: selected, artifact: result.artifacts.first ?? output, sourceCommands: result.sourceCommands, note: "Android UIAutomator layout was written locally.")
}

func hostCaptureAndroidScreenshot(selected: HostDeviceTarget, adb: String, output: String) throws -> HostAndroidArtifactOutput {
    let result = try runHostCommand(TKAndroidADBCommand.screenshot(serial: selected.rawTarget, executable: adb))
    let url = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try result.stdoutData.write(to: url, options: .atomic)
    return HostAndroidArtifactOutput(ok: true, action: "screenshot", platform: "android", target: selected, artifact: output, sourceCommands: [result.sourceCommand], note: "Android screenshot was captured through adb screencap.")
}


func captureAndroidEvidenceBundle(
    output: String,
    target: HostDeviceTarget,
    artifacts: [SmokeArtifactSummary],
    sourceCommands: [String],
    name: String?,
    note: String?
) throws -> TKEvidenceManifest {
    let outputURL = URL(fileURLWithPath: output)
    try prepareEvidenceOutputDirectory(outputURL)
    var evidenceArtifacts: [TKEvidenceArtifact] = []
    try appendSmokeRealDeviceDiagnostics(
        outputURL: outputURL,
        platform: "android",
        id: target.id,
        state: target.state,
        ready: target.ready,
        source: target.source,
        scope: target.scope,
        kind: target.kind,
        blockedReasons: target.blockedReasons,
        artifacts: &evidenceArtifacts
    )
    try appendSmokeHostActionEvidence(
        outputURL: outputURL,
        platform: "android",
        target: target.id,
        sourceCommands: sourceCommands,
        actions: ["device.wait-ready", "app.launch", "app.open-url"],
        artifacts: &evidenceArtifacts
    )
    for artifact in artifacts {
        let sourceURL = URL(fileURLWithPath: artifact.path)
        let relativePath = "artifacts/android/\(sanitizedPathComponent(artifact.kind))/\(sourceURL.lastPathComponent)"
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
        evidenceArtifacts.append(TKEvidenceArtifact(kind: artifact.kind, path: relativePath, contentType: artifact.kind == "screenshot" ? "image/png" : "application/xml", bytes: bytes, freshness: TKEvidenceFreshness(capturedAt: ISO8601DateFormatter().string(from: Date()), source: "host-android"), platform: "android", riskLevel: artifact.kind == "screenshot" ? "private" : "summary", policy: "android-private", redactionStatus: artifact.kind == "screenshot" ? "excluded-from-summary" : "included", sourceCommand: nil, target: target.id))
    }
    let manifest = TKEvidenceManifest(
        ok: true,
        name: name,
        note: note,
        createdAt: ISO8601DateFormatter().string(from: Date()),
        output: outputURL.path,
        artifacts: evidenceArtifacts,
        skipped: [
            TKEvidenceSkippedArtifact(kind: "runtime.snapshot", reason: "embedded runtime was not connected; Android smoke used host.layout fallback"),
            TKEvidenceSkippedArtifact(kind: "logs", reason: "bounded Android logcat capture is not enabled for this smoke path yet"),
        ],
        target: TKEvidenceTarget(
            id: target.id,
            connected: target.ready,
            appName: nil,
            bundleIdentifier: nil,
            deviceDescription: target.name ?? target.target,
            osDescription: target.runtime,
            identityState: target.ready ? "ready" : "not-ready",
            targetConnectionState: target.state,
            hierarchyCacheState: "host-layout"
        ),
        cli: TKEvidenceCLI(version: TritonKitBuildInfo.cliVersion)
    )
    let manifestURL = outputURL.appendingPathComponent("manifest.json")
    try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
    return manifest
}
