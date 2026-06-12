import Foundation
import TritonKitShared

struct WorkflowPlanRequest {
    let goal: String
    let device: String?
    let platform: String?
    let bundleID: String?
    let url: String?
    let text: String?
    let expectedURL: String?
    let evidence: String?
    let proxy: String?
    let mode: String?
    let output: String?
    let certificate: String?
    let auditRecord: String?
    let mockRules: String?
    let policyRules: String?
    let throttleMs: Int?

    init(
        goal: String,
        device: String? = nil,
        platform: String? = nil,
        bundleID: String? = nil,
        url: String? = nil,
        text: String? = nil,
        expectedURL: String? = nil,
        evidence: String? = nil,
        proxy: String? = nil,
        mode: String? = nil,
        output: String? = nil,
        certificate: String? = nil,
        auditRecord: String? = nil,
        mockRules: String? = nil,
        policyRules: String? = nil,
        throttleMs: Int? = nil
    ) {
        self.goal = goal
        self.device = device
        self.platform = platform
        self.bundleID = bundleID
        self.url = url
        self.text = text
        self.expectedURL = expectedURL
        self.evidence = evidence
        self.proxy = proxy
        self.mode = mode
        self.output = output
        self.certificate = certificate
        self.auditRecord = auditRecord
        self.mockRules = mockRules
        self.policyRules = policyRules
        self.throttleMs = throttleMs
    }

    static let general = WorkflowPlanRequest(
        goal: "general",
        device: nil,
        platform: nil,
        bundleID: nil,
        url: nil,
        text: nil,
        expectedURL: nil,
        evidence: nil,
        proxy: nil,
        mode: nil,
        output: nil,
        certificate: nil
    )
}

func buildWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    host: String,
    port: Int,
    request: WorkflowPlanRequest = .general
) -> TKWorkflowPlanResponse {
    if request.goal == "network-proxy" {
        return buildTaskWorkflowPlan(
            capabilities: capabilities,
            host: host,
            port: port,
            request: request
        )
    }

    if !capabilities.serverReachable {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            runtime: capabilities.runtime,
            mode: "bootstrap",
            goal: request.goal,
            nextStep: "start-server",
            steps: [
                TKWorkflowPlanStep(
                    id: "start-server",
                    title: "Start Triton server",
                    command: "triton serve --host \(host) --port \(port)",
                    requiresServer: false,
                    requiresTarget: false,
                    when: "serverReachable == false",
                    expected: "Server listens on \(host):\(port)"
                ),
                TKWorkflowPlanStep(
                    id: "connect-target",
                    title: "Launch an app with embedded TritonKit runtime",
                    command: "triton xcode run --json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "App launches with embedded TritonKit runtime and triton status reports connected: true"
                ),
                TKWorkflowPlanStep(
                    id: "diagnose",
                    title: "Re-check machine-readable runtime state",
                    command: "triton doctor --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after starting server and target",
                    expected: "ok=true, serverReachable=true, connected=true"
                ),
            ],
            error: capabilities.error
        )
    }

    if request.goal != "general" {
        return buildTaskWorkflowPlan(
            capabilities: capabilities,
            host: host,
            port: port,
            request: request
        )
    }

    if !capabilities.connected {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: true,
            connected: false,
            runtime: capabilities.runtime,
            mode: "bootstrap",
            goal: request.goal,
            nextStep: "connect-target",
            steps: [
                TKWorkflowPlanStep(
                    id: "connect-target",
                    title: "Launch an app with embedded TritonKit runtime",
                    command: "triton xcode run --json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "App launches and WebSocket target connects to ws://\(host):\(port)/"
                ),
                TKWorkflowPlanStep(
                    id: "list-targets",
                    title: "List connected targets",
                    command: "triton list --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after target launch",
                    expected: "targets contains triton:local"
                ),
                TKWorkflowPlanStep(
                    id: "diagnose",
                    title: "Confirm capability matrix",
                    command: "triton doctor --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after target connects",
                    expected: "embedded runtime capabilities become supported"
                ),
            ],
            error: TKCLIErrorDetail(
                code: "target_unavailable",
                message: "Triton server is reachable but no embedded runtime is connected",
                endpoint: endpointURL("/status", host: host, port: port),
                hint: "Launch an app that embeds TritonKit, then run `triton doctor --format json`"
            )
        )
    }

    return TKWorkflowPlanResponse(
        ok: true,
        serverReachable: true,
        connected: true,
        runtime: capabilities.runtime,
        mode: "bootstrap",
        goal: request.goal,
        nextStep: "geometry",
        steps: [
            TKWorkflowPlanStep(
                id: "geometry",
                title: "Read screen and window geometry",
                command: "triton geometry --host \(host) --port \(port) --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "connected == true",
                expected: "JSON geometry response"
            ),
            TKWorkflowPlanStep(
                id: "ax",
                title: "Build actionable accessibility index",
                command: "triton ax --host \(host) --port \(port) --format json --output /tmp/triton-ax.json",
                requiresServer: true,
                requiresTarget: true,
                when: "connected == true",
                expected: "Safe machine-readable controls"
            ),
            TKWorkflowPlanStep(
                id: "wait",
                title: "Wait for asynchronous UI state",
                command: "triton wait --host \(host) --port \(port) --text <text> --timeout 10 --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "after taps, submissions, and navigation",
                expected: "Machine-readable wait result with elapsedMs and timeout state"
            ),
            TKWorkflowPlanStep(
                id: "hit",
                title: "Resolve a coordinate before acting",
                command: "triton hit --host \(host) --port \(port) --x <x> --y <y> --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "before coordinate input",
                expected: "Hit-test node or empty result"
            ),
                TKWorkflowPlanStep(
                    id: "input",
                    title: "Execute NDJSON input actions",
                    command: "triton input --host \(host) --port \(port) --format json --summary --strict",
                    requiresServer: true,
                    requiresTarget: true,
                    when: "after selecting safe actions",
                    expected: "Read NDJSON actions from stdin; emit input results plus a final summary; non-zero exit when any action fails"
                ),
            TKWorkflowPlanStep(
                id: "screenshot",
                title: "Capture visual evidence",
                command: "triton screenshot --host \(host) --port \(port) --output /tmp/triton.png --metadata",
                requiresServer: true,
                requiresTarget: true,
                when: "after state changes",
                expected: "PNG plus metadata JSON"
            ),
            TKWorkflowPlanStep(
                id: "export",
                title: "Export replayable inspection archive",
                command: "triton export --host \(host) --port \(port) --format archive --output /tmp/triton.triton",
                requiresServer: true,
                requiresTarget: true,
                when: "when handing off context",
                expected: "Self-contained .triton archive"
            ),
        ]
    )
}

func buildTaskWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    host: String,
    port: Int,
    request: WorkflowPlanRequest
) -> TKWorkflowPlanResponse {
    switch request.goal {
    case "ios-smoke":
        return taskWorkflowPlan(
            capabilities: capabilities,
            goal: request.goal,
            nextStep: "target-list",
            steps: [
                targetListPlanStep(host: host, port: port),
                targetResolvePlanStep(device: request.device, host: host, port: port),
                targetUsePlanStep(device: request.device, host: host, port: port),
                targetWaitReadyPlanStep(device: request.device, host: host, port: port),
                TKWorkflowPlanStep(
                    id: "ios-smoke",
                    title: "Run iOS smoke workflow",
                    command: [
                        "triton", "smoke", "ios",
                        "--device", planValue(request.device, "<device>"),
                        "--bundle-id", planValue(request.bundleID, "<bundle-id>"),
                        "--open-url", planValue(request.url, "<url>"),
                        "--wait-text", planValue(request.text, "<text>"),
                        "--assert-text", planValue(request.text, "<text>"),
                        "--evidence", planValue(request.evidence, "<dir.tritonevidence>"),
                        "--json",
                    ].map(shellEscaped).joined(separator: " "),
                    requiresServer: true,
                    requiresTarget: true,
                    when: "target is resolved and host app can be launched",
                    expected: "Smoke summary proves host action, runtime readiness, assertion, screenshot, and evidence"
                ),
                evidenceSummaryPlanStep(evidence: request.evidence),
            ]
        )
    case "network-proxy":
        let platform = planValue(request.platform, "<platform>")
        let device = planValue(request.device, "<device>")
        let proxy = planValue(request.proxy, "127.0.0.1:19431")
        let mode = planValue(request.mode, "record")
        let output = planValue(request.output, "<proxy-session-dir>")
        let certificate = planValue(request.certificate, "<path.cer>")
        let auditRecord = planValue(request.auditRecord, "<id>")
        let restoreSnapshot = (request.output?.isEmpty == false)
            ? "\(output)/restore-state.json"
            : "<restore-state-json>"
        let captureOutput: String
        if let requestedOutput = request.output, !requestedOutput.isEmpty {
            captureOutput = requestedOutput.hasSuffix(".ndjson") || requestedOutput.hasSuffix(".har")
                ? requestedOutput
                : "\(requestedOutput)/requests.ndjson"
        } else {
            captureOutput = "<network-capture.ndjson>"
        }
        return taskWorkflowPlan(
            capabilities: capabilities,
            goal: request.goal,
            nextStep: "proxy-probe-plan",
            ok: true,
            steps: [
                targetResolvePlanStep(device: request.device, host: host, port: port),
                networkProxyDoctorPlanStep(platform: platform),
                networkProxyProbePlanStep(platform: platform, device: device),
                networkProxyCertificatePlanStep(platform: platform, device: device, certificate: certificate),
                networkProxyCertificateInstallPlanStep(platform: platform, device: device, certificate: certificate, auditRecord: auditRecord),
                networkProxyServePlanStep(proxy: proxy, mode: mode, output: output, mockRules: request.mockRules, policyRules: request.policyRules, throttleMs: request.throttleMs),
                networkProxyStartPlanStep(platform: platform, device: device, proxy: proxy, mode: mode, output: output),
                networkProxyStartExecutePlanStep(platform: platform, device: device, proxy: proxy, mode: mode, output: output, auditRecord: auditRecord),
                networkProxyStatusReadonlyPlanStep(platform: platform, device: device),
                networkProxyExportPlanStep(platform: platform, device: device, output: captureOutput),
                networkProxyEvidencePlanStep(proxySession: output, evidence: request.evidence),
                networkProxyStopPlanStep(platform: platform, device: device, restoreSnapshot: restoreSnapshot),
                networkProxyStopExecutePlanStep(platform: platform, device: device, restoreSnapshot: restoreSnapshot, auditRecord: auditRecord),
            ]
        )
    case "open-url":
        return taskWorkflowPlan(
            capabilities: capabilities,
            goal: request.goal,
            nextStep: "target-resolve",
            steps: [
                targetResolvePlanStep(device: request.device, host: host, port: port),
                TKWorkflowPlanStep(
                    id: "app-open-url",
                    title: "Open app URL and capture runtime readiness",
                    command: [
                        "triton", "app", "go",
                        planValue(request.url, "<url>"),
                        "--device", planValue(request.device, "<device>"),
                    ].map(shellEscaped).joined(separator: " "),
                    requiresServer: true,
                    requiresTarget: true,
                    when: "target is ready and URL/deep link is known",
                    expected: "Host action succeeds and optional runtime snapshot summarizes app state"
                ),
                waitTextPlanStep(text: request.text, host: host, port: port),
                assertTextPlanStep(text: request.text, host: host, port: port),
                evidenceCapturePlanStep(evidence: request.evidence),
            ]
        )
    case "webview-check":
        return taskWorkflowPlan(
            capabilities: capabilities,
            goal: request.goal,
            nextStep: "webview-current",
            steps: [
                TKWorkflowPlanStep(
                    id: "webview-current",
                    title: "Read current WebView metadata",
                    command: "triton webview current --host \(shellEscaped(host)) --port \(port) --json",
                    requiresServer: true,
                    requiresTarget: true,
                    when: "hybrid page may be visible",
                    expected: "Provider metadata includes WebView id, title, URL, and page session when available"
                ),
                TKWorkflowPlanStep(
                    id: "route-assert-current-url",
                    title: "Assert current WebView URL",
                    command: [
                        "triton", "route", "assert-current-url",
                        planValue(request.expectedURL ?? request.url, "<expected-url>"),
                        "--host", host,
                        "--port", String(port),
                        "--json",
                    ].map(shellEscaped).joined(separator: " "),
                    requiresServer: true,
                    requiresTarget: true,
                    when: "expected URL is known",
                    expected: "Route assertion returns status=pass or a machine-readable mismatch"
                ),
                TKWorkflowPlanStep(
                    id: "webview-wait",
                    title: "Wait for WebView text",
                    command: [
                        "triton", "webview", "wait",
                        "--text", planValue(request.text, "<text>"),
                        "--host", host,
                        "--port", String(port),
                        "--json",
                    ].map(shellEscaped).joined(separator: " "),
                    requiresServer: true,
                    requiresTarget: true,
                    when: "page text or event is the readiness signal",
                    expected: "WebView wait result includes match, timeout state, and last observed sample"
                ),
                evidenceCapturePlanStep(evidence: request.evidence),
            ]
        )
    default:
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: capabilities.serverReachable,
            connected: capabilities.connected,
            runtime: capabilities.runtime,
            mode: "task",
            goal: request.goal,
            nextStep: "inspect-schema",
            steps: [
                TKWorkflowPlanStep(
                    id: "inspect-schema",
                    title: "Inspect plan command schema",
                    command: "triton schema --command plan --json",
                    requiresServer: false,
                    requiresTarget: false,
                    when: "plan goal is unknown",
                    expected: "Schema lists supported task goals"
                ),
            ],
            error: TKCLIErrorDetail(
                code: "validation_failed",
                message: "Unsupported plan goal: \(request.goal)",
                hint: "Use one of: ios-smoke, open-url, webview-check, network-proxy, inspect"
            )
        )
    }
}

private func taskWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    goal: String,
    nextStep: String,
    ok: Bool? = nil,
    steps: [TKWorkflowPlanStep]
) -> TKWorkflowPlanResponse {
    TKWorkflowPlanResponse(
        ok: ok ?? capabilities.serverReachable,
        serverReachable: capabilities.serverReachable,
        connected: capabilities.connected,
        runtime: capabilities.runtime,
        mode: "task",
        goal: goal,
        nextStep: nextStep,
        steps: steps,
        error: capabilities.error
    )
}

private func planValue(_ value: String?, _ placeholder: String) -> String {
    guard let value, !value.isEmpty else { return placeholder }
    return value
}

private func targetListPlanStep(host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "target-list",
        title: "List available host targets",
        command: "triton target list --host \(shellEscaped(host)) --port \(port) --json",
        requiresServer: false,
        requiresTarget: false,
        when: "before selecting a device or emulator",
        expected: "Targets include platform, readiness, and default candidate"
    )
}

private func targetResolvePlanStep(device: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "target-resolve",
        title: "Resolve target selector",
        command: [
            "triton", "target", "resolve",
            planValue(device, "<device>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "after target list returns candidates",
        expected: "A single target is selected or ambiguity is explained"
    )
}

private func targetUsePlanStep(device: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "target-use",
        title: "Persist current target",
        command: [
            "triton", "target", "use",
            planValue(device, "<device>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "the resolved target will be reused by later commands",
        expected: "Workspace defaults contain the selected target"
    )
}

private func targetWaitReadyPlanStep(device: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "target-wait-ready",
        title: "Wait for target readiness",
        command: [
            "triton", "target", "wait-ready",
            planValue(device, "<device>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "before launching or opening app URLs",
        expected: "Target reports ready or returns device_not_ready with source command"
    )
}

private func waitTextPlanStep(text: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "wait-text",
        title: "Wait for expected text",
        command: [
            "triton", "wait",
            "--text", planValue(text, "<text>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: true,
        requiresTarget: true,
        when: "after navigation or async loading",
        expected: "Wait result proves readiness or returns timeout diagnostics"
    )
}

private func assertTextPlanStep(text: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "assert-text",
        title: "Assert expected text",
        command: [
            "triton", "assert", "text-exists",
            planValue(text, "<text>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: true,
        requiresTarget: true,
        when: "after wait succeeds",
        expected: "Assertion result is the pass/fail gate"
    )
}

private func evidenceCapturePlanStep(evidence: String?) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "evidence",
        title: "Capture evidence bundle",
        command: [
            "triton", "evidence",
            "--output", planValue(evidence, "<dir.tritonevidence>"),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: true,
        requiresTarget: true,
        when: "after the workflow reaches a pass/fail state",
        expected: "Evidence manifest lists artifacts, skipped sources, target, CLI, and run metadata"
    )
}

private func evidenceSummaryPlanStep(evidence: String?) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "evidence-summary",
        title: "Summarize evidence bundle",
        command: [
            "triton", "evidence", "summary",
            planValue(evidence, "<dir.tritonevidence>"),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "before handoff or issue filing",
        expected: "Summary identifies the key artifacts and redaction state"
    )
}

private func networkProxyDoctorPlanStep(platform: String) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-doctor",
        title: "Inspect platform proxy prerequisites",
        command: [
            "triton", "device", "proxy", "doctor",
            "--platform", platform,
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "before planning proxy mutation for a simulator or emulator",
        expected: "Proxy doctor returns lane=host-proxy, conservative certificate state, and limitations",
        requires: ["cli.available"],
        expectedArtifacts: ["stdout-json", "host-device-proxy"],
        stopConditions: ["command.failed"]
    )
}

private func networkProxyProbePlanStep(platform: String, device: String) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-probe-plan",
        title: "Inspect readonly platform proxy capability evidence",
        command: [
            "triton", "device", "proxy", "probe",
            "--platform", platform,
            "--device", device,
            "--plan-only",
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "after proxy doctor and before starting the local proxy endpoint",
        expected: "Plan-only response declares readonly probe sourceCommands and configured=false",
        requires: ["cli.available"],
        expectedArtifacts: ["stdout-json", "host-device-proxy"],
        stopConditions: ["command.failed"]
    )
}

private func networkProxyCertificatePlanStep(platform: String, device: String, certificate: String) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-cert-plan",
        title: "Generate proxy certificate trust preparation ledger",
        command: [
            "triton", "device", "proxy", "cert", "plan",
            "--platform", platform,
            "--device", device,
            "--certificate", certificate,
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "after readonly probe and before relying on HTTPS visibility",
        expected: "Plan-only response declares certificate trust commands or probe-only limitations without installing trust",
        requires: ["cli.available"],
        expectedArtifacts: ["stdout-json", "proxy-certificate"],
        stopConditions: ["command.failed"]
    )
}

private func networkProxyCertificateInstallPlanStep(
    platform: String,
    device: String,
    certificate: String,
    auditRecord: String
) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-cert-install",
        title: "Review proxy certificate install break-glass command",
        command: [
            "triton", "device", "proxy", "cert", "install",
            "--platform", platform,
            "--device", device,
            "--certificate", certificate,
            "--confirm",
            "--audit-record", auditRecord,
            "--execute-runner",
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "only after proxy-cert-plan has been reviewed and explicit operator approval exists",
        expected: "Break-glass response records certificate state; Harmony remains probe-only until a verified trust command exists",
        requires: ["cli.available", "operator.approval", "audit-record"],
        expectedArtifacts: ["stdout-json", "proxy-certificate"],
        stopConditions: ["command.failed"]
    )
}

private func networkProxyServePlanStep(proxy: String, mode: String, output: String, mockRules: String?, policyRules: String?, throttleMs: Int?) -> TKWorkflowPlanStep {
    var argv = [
        "triton", "device", "proxy", "serve",
        "--listen", proxy,
        "--output", output,
        "--mode", mode,
    ]
    if mode == "mock", let mockRules, !mockRules.isEmpty {
        argv += ["--mock-rules", mockRules]
    }
    if let policyRules, !policyRules.isEmpty {
        argv += ["--policy-rules", policyRules]
    }
    if mode == "throttle", let throttleMs {
        argv += ["--throttle-ms", String(throttleMs)]
    }
    argv.append("--jsonl")
    return TKWorkflowPlanStep(
        id: "proxy-serve",
        title: "Start local host-side proxy endpoint",
        command: argv.map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "before platform proxy settings point the simulator or emulator at the host proxy",
        expected: "JSONL emits proxy.serve.ready and writes metadata-only requests.ndjson",
        requires: ["cli.available"],
        expectedArtifacts: ["network-capture", "stdout-json"],
        stopConditions: ["command.failed", "artifact.write-failed"]
    )
}

private func networkProxyStartPlanStep(platform: String, device: String, proxy: String, mode: String, output: String) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-start-plan",
        title: "Generate platform proxy start ledger",
        command: [
            "triton", "device", "proxy", "start",
            "--platform", platform,
            "--device", device,
            "--proxy", proxy,
            "--mode", mode,
            "--output", output,
            "--plan-only",
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "after proxy endpoint is known and before any break-glass mutation",
        expected: "Plan-only response contains sourceCommands and configured=false",
        requires: ["cli.available"],
        expectedArtifacts: ["stdout-json", "host-device-proxy"],
        stopConditions: ["command.failed"]
    )
}

private func networkProxyStartExecutePlanStep(
    platform: String,
    device: String,
    proxy: String,
    mode: String,
    output: String,
    auditRecord: String
) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-start-execute",
        title: "Review platform proxy start break-glass command",
        command: [
            "triton", "device", "proxy", "start",
            "--platform", platform,
            "--device", device,
            "--proxy", proxy,
            "--mode", mode,
            "--output", output,
            "--confirm",
            "--audit-record", auditRecord,
            "--execute-runner",
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "only after proxy-start-plan and proxy.serve.ready have been reviewed",
        expected: "Break-glass response records platform proxy state, restore-state.json, and session-state.json; Harmony remains probe-only until a verified mutation command exists",
        requires: ["cli.available", "proxy.endpoint.ready", "operator.approval", "audit-record"],
        expectedArtifacts: ["stdout-json", "host-device-proxy", "proxy-restore", "network-capture"],
        stopConditions: ["command.failed", "artifact.write-failed"]
    )
}

private func networkProxyStatusReadonlyPlanStep(platform: String, device: String) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-status-readonly",
        title: "Verify platform proxy state with a readonly status probe",
        command: [
            "triton", "device", "proxy", "status",
            "--platform", platform,
            "--device", device,
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "after proxy-start-execute and before exporting or archiving capture artifacts",
        expected: "Readonly status reports configured/proxyEndpoint from platform state when available; Harmony remains probe-only",
        requires: ["cli.available", "proxy-start-reviewed"],
        expectedArtifacts: ["stdout-json", "host-device-proxy"],
        stopConditions: ["command.failed"]
    )
}

private func networkProxyExportPlanStep(platform: String, device: String, output: String) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-export-plan",
        title: "Generate network capture export artifact plan",
        command: [
            "triton", "device", "proxy", "export",
            "--platform", platform,
            "--device", device,
            "--output", output,
            "--plan-only",
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["evidence", "target"],
        requiresServer: false,
        requiresTarget: false,
        when: "before archiving or converting network capture artifacts",
        expected: "Plan-only response declares the network-capture artifact path without writing files",
        requires: ["cli.available"],
        expectedArtifacts: ["network-capture", "stdout-json"],
        stopConditions: ["command.failed", "artifact.write-failed"]
    )
}

private func networkProxyEvidencePlanStep(proxySession: String, evidence: String?) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-evidence",
        title: "Archive proxy session into evidence",
        command: [
            "triton", "evidence",
            "--include", "network.proxy-session",
            "--proxy-session", proxySession,
            "--output", planValue(evidence, "<dir.tritonevidence>"),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        category: "archive",
        workflowCategories: ["evidence", "target"],
        requiresServer: false,
        requiresTarget: false,
        when: "after a proxy session directory contains session-state.json",
        expected: "Evidence manifest includes network.proxy-session and network-capture artifacts when present",
        requires: ["cli.available"],
        expectedArtifacts: ["evidence-bundle", "network-capture"],
        stopConditions: ["command.failed", "artifact.write-failed"]
    )
}

private func networkProxyStopPlanStep(platform: String, device: String, restoreSnapshot: String) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-stop-plan",
        title: "Generate restore snapshot ledger review",
        command: [
            "triton", "device", "proxy", "stop",
            "--platform", platform,
            "--device", device,
            "--restore-snapshot", restoreSnapshot,
            "--plan-only",
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "after start writes restore-state.json and before stop/restore break-glass execution",
        expected: "Plan-only response reviews restore snapshot sourceCommands and configured=false",
        requires: ["cli.available"],
        expectedArtifacts: ["stdout-json", "proxy-restore"],
        stopConditions: ["command.failed"]
    )
}

private func networkProxyStopExecutePlanStep(
    platform: String,
    device: String,
    restoreSnapshot: String,
    auditRecord: String
) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "proxy-stop-execute",
        title: "Review platform proxy restore break-glass command",
        command: [
            "triton", "device", "proxy", "stop",
            "--platform", platform,
            "--device", device,
            "--restore-snapshot", restoreSnapshot,
            "--confirm",
            "--audit-record", auditRecord,
            "--execute-runner",
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        workflowCategories: ["target", "evidence"],
        requiresServer: false,
        requiresTarget: false,
        when: "only after proxy-stop-plan has reviewed the original-value restore ledger",
        expected: "Break-glass response restores the reviewed platform proxy ledger; Harmony remains probe-only until a verified mutation command exists",
        requires: ["cli.available", "operator.approval", "audit-record", "restore-snapshot"],
        expectedArtifacts: ["stdout-json", "proxy-restore"],
        stopConditions: ["command.failed"]
    )
}

func renderWorkflowPlan(_ plan: TKWorkflowPlanResponse, language: CLILanguage = effectiveLanguage(nil)) -> String {
    if language == .zh {
        return renderWorkflowPlanZH(plan)
    }
    var lines = [
        "ok: \(plan.ok)",
        "serverReachable: \(plan.serverReachable)",
        "connected: \(plan.connected)",
        "runtime: \(plan.runtime)",
        "nextStep: \(plan.nextStep)",
        "nextWorkflows: \(plan.nextWorkflows.joined(separator: ","))",
    ]
    if let error = plan.error {
        lines.append("error: \(error.code) \(error.message)")
        if let hint = error.hint {
            lines.append("hint: \(hint)")
        }
        if let nextAction = error.nextAction {
            let command = ([nextAction.command] + nextAction.args).joined(separator: " ")
            lines.append("nextAction: triton \(command)")
            lines.append("requiresLongRunningProcess: \(nextAction.requiresLongRunningProcess)")
        }
    }
    lines.append("steps:")
    for step in plan.steps {
        lines.append("  \(step.id): \(step.title)")
        lines.append("    command: \(step.command)")
        lines.append("    when: \(step.when)")
        lines.append("    expected: \(step.expected)")
    }
    return lines.joined(separator: "\n")
}

func renderWorkflowPlanZH(_ plan: TKWorkflowPlanResponse) -> String {
    var lines = [
        "正常: \(plan.ok)",
        "服务可达: \(plan.serverReachable)",
        "已连接: \(plan.connected)",
        "运行时: \(plan.runtime)",
        "下一步: \(plan.nextStep)",
        "下一步工作流: \(plan.nextWorkflows.joined(separator: ","))",
    ]
    if let error = plan.error {
        lines.append("错误: \(localizedErrorMessage(error, language: .zh))")
        if let hint = error.hint {
            lines.append("提示: \(localizedHint(error, fallback: hint, language: .zh))")
        }
        if let nextAction = error.nextAction {
            let command = ([nextAction.command] + nextAction.args).joined(separator: " ")
            lines.append("下一步命令: triton \(command)")
            lines.append("需要长驻进程: \(nextAction.requiresLongRunningProcess)")
        }
    }
    lines.append("步骤:")
    for step in plan.steps {
        lines.append("  \(step.id): \(step.title)")
        lines.append("    命令: \(step.command)")
        lines.append("    条件: \(step.when)")
        lines.append("    预期: \(step.expected)")
    }
    return lines.joined(separator: "\n")
}
