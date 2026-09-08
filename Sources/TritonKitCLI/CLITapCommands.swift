import ArgumentParser
import CoreGraphics
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

struct Tap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Tap a UI target by text, coordinate, oid, or AX node")

    @Argument(help: "Text, label, identifier, or visible option title to tap") var query: String?
    @Option(help: "Alternate flag form for the text query; use either positional <query> or --text") var text: String?
    @Option(help: "Host platform adapter: ios, android, or harmony") var platform: HostPlatform?
    @Option(name: [.long, .customLong("device")], help: "Runtime target id or host selector; pure coordinate taps with sim:<udid>, a raw Simulator UUID, booted, or current use iOS host HID. --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Window x coordinate in points") var x: Double?
    @Option(help: "Window y coordinate in points") var y: Double?
    @Option(help: "View oid from `triton debug nodes`") var oid: UInt?
    @Option(name: .customLong("ax-oid"), help: "AX target/view oid from `triton debug ax`") var axOID: UInt?
    @Option(name: .customLong("ax-label"), help: "Exact AX label to tap by AX target/view oid") var axLabel: String?
    @Option(help: "Optional screen/window width in points") var width: Double?
    @Option(help: "Optional screen/window height in points") var height: Double?
    @Option(help: "Unsupported for tap: press-and-hold returns a typed error without dispatch") var duration: Double?
    @Option(help: "Activation strategy for query or AX text matches: smart, exact, or ancestor") var strategy: TapStrategyOption?
    @Flag(name: .customLong("allow-host-hid-fallback"), help: "Explicitly allow an auditable iOS Simulator host-HID coordinate fallback after embedded UICollectionViewCell activation is rejected") var allowHostHIDFallback = false
    @Option(help: "Select one matching query candidate by 1-based index") var index: Int?
    @Option(help: "Restrict query matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Coordinate selector or query disambiguation point: x,y") var at: String?
    @Flag(name: .customLong("webview-aware"), help: "Route this tap through the current WebView provider; first slice is explicit opt-in") var webViewAware = false
    @Option(help: "CSS selector for --webview-aware WebView tap") var selector: String?
    @Option(name: .customLong("webview-id"), help: "WebView candidate id for --webview-aware tap disambiguation") var webViewID: String?
    @Option(name: .customLong("page-session-id"), help: "Expected WebView page session id for --webview-aware tap") var pageSessionID: String?
    @Option(name: .customLong("expect-text"), help: "Expected WebView text after --webview-aware dispatch") var expectText: String?
    @Option(help: "Timeout in seconds for --webview-aware expectation") var timeout: Double = 3
    @Option(name: .customLong("lease"), help: "Target lease token from `triton target lease acquire`; mutating actions fail with target_lease_conflict when another flow holds the lease") var leaseID: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if duration != nil {
            try failHostValidation(
                code: "unsupported_capability",
                message: "act tap does not support --duration press-and-hold; no input was dispatched.",
                hint: "Omit --duration only for an ordinary tap. For a recognizer-driven hold, use an app-owned semantic DEBUG action; embedded longPress and the current host tap provider cannot prove that gesture.",
                outputFormat: outputFormat
            )
        }
        if webViewAware {
            try await runWebViewAwareTap(outputFormat: outputFormat)
            return
        }
        if selector != nil || webViewID != nil || pageSessionID != nil || expectText != nil {
            if outputFormat == .json {
                try printValidationError("--selector, --webview-id, --page-session-id, and --expect-text require --webview-aware")
                throw ExitCode.failure
            }
            throw RuntimeError("--selector, --webview-id, --page-session-id, and --expect-text require --webview-aware")
        }
        if query != nil && text != nil {
            if outputFormat == .json {
                try printValidationError("Provide exactly one text query: <query> or --text")
                throw ExitCode.failure
            }
            throw RuntimeError("Provide exactly one text query: <query> or --text")
        }
        let query = query ?? text
        let selectorCount = [
            query != nil,
            oid != nil,
            x != nil || y != nil,
            query == nil && at != nil,
            axOID != nil,
            axLabel != nil,
        ].filter { $0 }.count
        guard selectorCount == 1 else {
            if effectiveFormat(format, json: json) == .json {
                try printValidationError("Provide exactly one target selector: <query>, --oid, --x/--y, --at, --ax-oid, or --ax-label")
                throw ExitCode.failure
            }
            throw RuntimeError("Provide exactly one target selector: <query>, --oid, --x/--y, --at, --ax-oid, or --ax-label")
        }
        if (index != nil || within != nil) && query == nil {
            if outputFormat == .json {
                try printValidationError("--index and --within can only be used with <query>")
                throw ExitCode.failure
            }
            throw RuntimeError("--index and --within can only be used with <query>")
        }
        if within != nil && at != nil {
            if outputFormat == .json {
                try printValidationError("--within and --at cannot be used together")
                throw ExitCode.failure
            }
            throw RuntimeError("--within and --at cannot be used together")
        }
        if at != nil && (x != nil || y != nil) {
            if outputFormat == .json {
                try printValidationError("--at cannot be combined with --x/--y")
                throw ExitCode.failure
            }
            throw RuntimeError("--at cannot be combined with --x/--y")
        }
        if (x == nil) != (y == nil) {
            if outputFormat == .json {
                try printValidationError("--x and --y must be provided together")
                throw ExitCode.failure
            }
            throw RuntimeError("--x and --y must be provided together")
        }
        if strategy != nil, query == nil, axOID == nil, axLabel == nil {
            if outputFormat == .json {
                try printValidationError("--strategy can only be used with <query>, --ax-oid, or --ax-label")
                throw ExitCode.failure
            }
            throw RuntimeError("--strategy can only be used with <query>, --ax-oid, or --ax-label")
        }

        if let simulatorSelector = implicitIOSHostCoordinateTapSelector(
            platform: platform,
            target: target,
            query: query,
            x: x,
            y: y,
            at: at,
            oid: oid,
            axOID: axOID,
            axLabel: axLabel
        ) {
            do {
                let point = try at.map(parsePoint)
                guard let tapX = point?.x ?? x,
                      let tapY = point?.y ?? y,
                      tapX.isFinite,
                      tapY.isFinite else {
                    try failHostValidation(
                        code: "validation_failed",
                        message: "iOS Simulator host coordinate tap requires finite --x/--y or --at coordinates.",
                        hint: "Pass a finite coordinate pair from a current host observation or screenshot.",
                        outputFormat: outputFormat
                    )
                }
                let selection = try resolveHostDeviceSelection(
                    request: HostDeviceSelectionRequest(
                        device: simulatorSelector,
                        platform: .ios,
                        scope: .simulator,
                        ready: true
                    ),
                    hdc: hdc,
                    adb: adb
                )
                if let leaseID {
                    try await enforceTargetLease(host: host, port: port, target: selection.target.target, leaseID: leaseID)
                }
                let result = try runWebHostDeviceInput(
                    id: webHostDeviceTargetID(selection.target),
                    input: .tap(x: tapX, y: tapY)
                )
                try printInputResultAndRequireSuccess(result, format: outputFormat)
            } catch {
                if error is ExitCode { throw error }
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }

        if platform == .ios {
            do {
                if oid != nil || axOID != nil || axLabel != nil || width != nil || height != nil || duration != nil || strategy != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "iOS host tap currently supports <query>, --x/--y, or --at for simulator targets.",
                        hint: "Use `triton observe tree --platform ios --device <selector> --json` to inspect visible text and bounds.",
                        outputFormat: outputFormat
                    )
                }
                let point = try at.map(parsePoint)
                let selected = try resolveHostDeviceSelection(
                    request: HostDeviceSelectionRequest(
                        device: target == TKLocalTargetID ? nil : target,
                        platform: .ios,
                        scope: .simulator,
                        ready: true
                    ),
                    hdc: hdc,
                    adb: adb
                ).target
                guard usesIOSHostSimulatorAX(selected) else {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "iOS host tap is scoped to local simulator targets.",
                        hint: "Pass a booted simulator selector such as `--device booted` or `--device sim:<udid>`.",
                        outputFormat: outputFormat
                    )
                }
                if let leaseID {
                    try await enforceTargetLease(host: host, port: port, target: selected.target, leaseID: leaseID)
                }
                let tapPoint: CGPoint?
                if let point {
                    tapPoint = CGPoint(x: point.x, y: point.y)
                } else if let x, let y {
                    tapPoint = CGPoint(x: x, y: y)
                } else {
                    tapPoint = nil
                }
                let bounds = try within.map(parseBounds)
                let match = try AXPTranslatorAccessibility(udid: selected.target).press(
                    query: query,
                    point: tapPoint,
                    index: index,
                    within: bounds
                )
                let outputX = Int((tapPoint.map { Double($0.x) } ?? match.frame.centerX).rounded())
                let outputY = Int((tapPoint.map { Double($0.y) } ?? match.frame.centerY).rounded())
                let response = HostIOSTapOutput(
                    ok: true,
                    action: "tap",
                    platform: "ios",
                    target: selected,
                    query: query,
                    x: outputX,
                    y: outputY,
                    match: match,
                    sourceCommands: [
                        "triton sim ax --device \(selected.target) --json",
                        "host.ax accessibilityPerformPress",
                    ],
                    note: "iOS host tap was submitted through private host-side AX; verify business state with observe, wait, or screenshot."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("\(outputX),\(outputY)")
                }
            } catch {
                if error is ExitCode { throw error }
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }

        if platform == .android {
            do {
                if oid != nil || axOID != nil || axLabel != nil || within != nil || index != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Android host tap currently supports <query>, --x/--y, or --at.",
                        hint: "Use `triton observe tree --platform android --json` to inspect visible text and bounds.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveAndroidActionSelection(target: target, adb: adb)
                let sourceCommands: [String]
                let match: HostAndroidTapMatch?
                let tapX: Int
                let tapY: Int
                if let query {
                    let resolved = try resolveAndroidTapQuery(selected: selected, query: query, adb: adb)
                    let tapResult = try runHostCommand(TKAndroidADBCommand.tapCoordinate(serial: selected.target, x: resolved.x, y: resolved.y, executable: adb))
                    sourceCommands = resolved.sourceCommands + [tapResult.sourceCommand]
                    match = resolved.match
                    tapX = resolved.x
                    tapY = resolved.y
                } else {
                    let point = try at.map(parsePoint)
                    guard let tapPointX = point?.x ?? x, let tapPointY = point?.y ?? y else {
                        try failHostValidation(
                            code: "validation_failed",
                            message: "Android host tap requires <query>, --x/--y, or --at.",
                            hint: "Pass visible text or explicit coordinates.",
                            outputFormat: outputFormat
                        )
                    }
                    tapX = Int(tapPointX.rounded())
                    tapY = Int(tapPointY.rounded())
                    let tapResult = try runHostCommand(TKAndroidADBCommand.tapCoordinate(serial: selected.target, x: tapX, y: tapY, executable: adb))
                    sourceCommands = [tapResult.sourceCommand]
                    match = nil
                }
                let response = HostAndroidTapOutput(
                    ok: true,
                    action: "tap",
                    platform: "android",
                    target: selected,
                    query: query,
                    x: tapX,
                    y: tapY,
                    match: match,
                    sourceCommands: sourceCommands,
                    note: "Android tap was submitted through adb input; verify business state with wait, observe, or screenshot."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("\(tapX),\(tapY)")
                }
            } catch {
                if error is ExitCode { throw error }
                if case HostCommandRunError.layoutTextNotFound(let query) = error {
                    try failAndroidTextNotFound(query, outputFormat: outputFormat)
                }
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }

        if platform == .harmony {
            do {
                if oid != nil || axOID != nil || axLabel != nil || within != nil || index != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Harmony host tap currently supports <query>, --x/--y, or --at.",
                        hint: "Use `triton debug ax --platform harmony --output <path> --json` to inspect attributes.text and bounds.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                let sourceCommands: [String]
                let match: TKHarmonyLayoutTextMatch?
                let tapX: Int
                let tapY: Int
                if let query {
                    let layout = try dumpHarmonyLayout(selected: selected, hdc: hdc, output: nil)
                    guard let resolved = try TKHarmonyLayoutParser.firstTextMatch(in: layout.data, text: query) else {
                        throw HostCommandRunError.layoutTextNotFound(query)
                    }
                    let tapResult = try runHostCommand(TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: resolved.centerX, y: resolved.centerY, executable: hdc))
                    sourceCommands = layout.sourceCommands + [tapResult.sourceCommand]
                    match = resolved
                    tapX = resolved.centerX
                    tapY = resolved.centerY
                } else {
                    let point = try at.map(parsePoint)
                    guard let tapPointX = point?.x ?? x, let tapPointY = point?.y ?? y else {
                        try failHostValidation(
                            code: "validation_failed",
                            message: "Harmony host tap requires <query>, --x/--y, or --at.",
                            hint: "Pass visible text or explicit coordinates.",
                            outputFormat: outputFormat
                        )
                    }
                    tapX = Int(tapPointX.rounded())
                    tapY = Int(tapPointY.rounded())
                    let tapResult = try runHostCommand(TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: tapX, y: tapY, executable: hdc))
                    sourceCommands = [tapResult.sourceCommand]
                    match = nil
                }
                let response = HostHarmonyTapOutput(
                    ok: true,
                    action: "tap",
                    platform: "harmony",
                    target: selected,
                    query: query,
                    x: tapX,
                    y: tapY,
                    match: match,
                    sourceCommands: sourceCommands,
                    note: "Harmony tap was submitted through uitest; verify business state with wait, ax, or screenshot."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("\(tapX),\(tapY)")
                }
            } catch {
                if error is ExitCode { throw error }
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }

        do {
            let point = try at.map(parsePoint)
            let (runtimeTarget, runtimeClient) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            if let leaseID {
                let leaseKey = runtimeTarget.simulatorUDID ?? runtimeTarget.id
                try await enforceTargetLease(host: host, port: port, target: leaseKey, leaseID: leaseID)
            }
            if let query {
                let client = runtimeClient
                let bounds = try within.map(parseBounds)
                let resolution = try await resolveTapTarget(
                    query,
                    client: client,
                    width: width,
                    height: height,
                    duration: duration,
                    activationStrategy: strategy?.activationStrategy ?? .smart,
                    index: index,
                    within: bounds,
                    at: point
                )
                let embeddedResult = try await executeInputRequest(resolution.request, client: client)
                if allowHostHIDFallback, isUnsupportedCollectionCellResult(embeddedResult) {
                    let screenGeometry: TKGeometryResponse?
                    do {
                        let data = try await client.request(type: "geometry")
                        screenGeometry = try JSONDecoder().decode(TKGeometryResponse.self, from: data)
                    } catch {
                        screenGeometry = nil
                    }
                    let result = collectionCellHostHIDFallbackResult(
                        embeddedResult: embeddedResult,
                        resolution: resolution,
                        runtimeTarget: runtimeTarget,
                        screenGeometry: screenGeometry,
                        hostInput: { id, input in
                            try runWebHostDeviceInput(id: id, input: input)
                        }
                    )
                    try printInputResultAndRequireSuccess(result, format: outputFormat)
                } else {
                    try printInputResultAndRequireSuccess(embeddedResult, format: outputFormat)
                }
                return
            }

            if axOID != nil || axLabel != nil {
                let client = runtimeClient
                let data = try await client.request(type: "accessibility")
                let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
                guard let node = selectAXNode(nodes, oid: axOID, label: axLabel) else {
                    let message = axOID.map { "AX node not found for oid \($0)" } ?? "AX node not found for label \(axLabel ?? "")"
                    if outputFormat == .json {
                        try printValidationError(message)
                        throw ExitCode.failure
                    }
                    throw RuntimeError(message)
                }
                let activationStrategy = strategy?.activationStrategy ?? .exact
                let request = tapRequest(
                    for: node,
                    width: width,
                    height: height,
                    duration: duration,
                    activationStrategy: activationStrategy
                )
                let embeddedResult = try await executeInputRequest(request, client: client)
                if allowHostHIDFallback, isUnsupportedCollectionCellResult(embeddedResult) {
                    let resolution = collectionCellHostHIDAXResolution(
                        node: node,
                        query: axLabel ?? axOID.map { "oid:\($0)" } ?? "ax-node",
                        request: request,
                        activationStrategy: activationStrategy
                    )
                    let screenGeometry: TKGeometryResponse?
                    do {
                        let geometryData = try await client.request(type: "geometry")
                        screenGeometry = try JSONDecoder().decode(TKGeometryResponse.self, from: geometryData)
                    } catch {
                        screenGeometry = nil
                    }
                    let result = collectionCellHostHIDFallbackResult(
                        embeddedResult: embeddedResult,
                        resolution: resolution,
                        runtimeTarget: runtimeTarget,
                        screenGeometry: screenGeometry,
                        hostInput: { id, input in
                            try runWebHostDeviceInput(id: id, input: input)
                        }
                    )
                    try printInputResultAndRequireSuccess(result, format: outputFormat)
                } else {
                    try printInputResultAndRequireSuccess(embeddedResult, format: outputFormat)
                }
                return
            }

            let request = TKInputRequest.tap(
                x: point?.x ?? x,
                y: point?.y ?? y,
                targetOID: oid,
                width: width,
                height: height,
                duration: duration
            )
            try await runInputRequest(request, client: runtimeClient, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }

    private func runWebViewAwareTap(outputFormat: ClientOutputFormat) async throws {
        do {
            guard platform == nil else {
                try failHostValidation(
                    code: "unsupported_capability",
                    message: "--webview-aware currently targets the embedded iOS runtime, not host platform adapters.",
                    hint: "Omit --platform and use the connected DEBUG iOS runtime, or use the existing host tap path.",
                    outputFormat: outputFormat
                )
            }
            guard query == nil, text == nil, oid == nil, axOID == nil, axLabel == nil, x == nil, y == nil, at == nil else {
                if outputFormat == .json {
                    try printValidationError("--webview-aware first slice accepts only --selector")
                    throw ExitCode.failure
                }
                throw RuntimeError("--webview-aware first slice accepts only --selector")
            }
            let selectorValue = selector?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !selectorValue.isEmpty else {
                if outputFormat == .json {
                    try printValidationError("--webview-aware requires --selector")
                    throw ExitCode.failure
                }
                throw RuntimeError("--webview-aware requires --selector")
            }
            guard timeout > 0 else {
                if outputFormat == .json {
                    try printValidationError("--timeout must be greater than 0")
                    throw ExitCode.failure
                }
                throw RuntimeError("--timeout must be greater than 0")
            }

            let (_, runtimeClient) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let expectedText = expectText?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceCommand = webViewAwareTapSourceCommand(
                selector: selectorValue,
                webViewID: webViewID,
                pageSessionID: pageSessionID,
                expectText: expectedText,
                timeout: timeout,
                outputFormat: outputFormat
            )
            let tapRequest = TKWebViewTapRequest(
                webViewID: webViewID,
                pageSessionID: pageSessionID,
                selector: selectorValue,
                sourceCommand: sourceCommand
            )
            let tapData = try await runtimeClient.request(type: "webViewTap", payload: try JSONEncoder().encode(tapRequest))
            let tap = try decodeWebViewTapRuntimeResult(tapData)
            let wait: TKWebViewWaitResponse?
            if tap.ok, let expected = expectedText, !expected.isEmpty {
                let waitRequest = TKWebViewWaitRequest(
                    webViewID: tap.webViewID,
                    pageSessionID: tap.pageSessionID,
                    condition: .text,
                    query: expected,
                    timeoutSeconds: timeout,
                    intervalSeconds: 0.25,
                    sourceCommand: "triton webview wait --text \(webViewAwareShellQuote(expected)) --json"
                )
                let waitData = try await runtimeClient.request(type: "webViewWait", payload: try JSONEncoder().encode(waitRequest))
                switch try decodeWebViewWaitRuntimeResult(waitData) {
                case .wait(let response):
                    wait = response
                case .error:
                    wait = nil
                }
            } else {
                wait = nil
            }

            let response = TKMakeWebViewAwareTapResponse(
                selector: selectorValue,
                tap: tap,
                expectText: expectedText,
                wait: wait,
                recoveryCommand: webViewAwareTapRecoveryCommand(selector: selectorValue, tap: tap, expectText: expectedText)
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("status: \(response.status.rawValue)")
                print("selector: \(selectorValue)")
                print("note: \(response.note)")
                if let recovery = response.recoveryCommand {
                    print("recovery: \(recovery)")
                }
            }
            if response.status == .failed {
                throw ExitCode.failure
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

private func decodeWebViewTapRuntimeResult(_ data: Data) throws -> TKWebViewTapResponse {
    let decoder = JSONDecoder()
    if let response = try? decoder.decode(TKWebViewTapResponse.self, from: data) {
        return response
    }
    if let error = try? decoder.decode(TKWebViewErrorResponse.self, from: data) {
        return TKWebViewTapResponse(
            ok: false,
            capturedAt: currentCLITimestamp(),
            platform: error.platform,
            target: error.target,
            selector: "",
            dispatched: false,
            trusted: false,
            error: TKWebViewError(code: TKWebViewErrorCode(rawValue: error.error.code) ?? .javascriptError, message: error.error.message, hint: error.error.hint),
            elapsedMs: 0
        )
    }
    return try decoder.decode(TKWebViewTapResponse.self, from: data)
}

private func currentCLITimestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}

func webViewAwareTapSourceCommand(
    selector: String,
    webViewID: String? = nil,
    pageSessionID: String? = nil,
    expectText: String?,
    timeout: Double,
    outputFormat: ClientOutputFormat
) -> String {
    var parts = [
        "triton",
        "act",
        "tap",
        "--webview-aware",
        "--selector",
        webViewAwareShellQuote(selector),
    ]
    if let webViewID, !webViewID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        parts.append("--webview-id")
        parts.append(webViewAwareShellQuote(webViewID))
    }
    if let pageSessionID, !pageSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        parts.append("--page-session-id")
        parts.append(webViewAwareShellQuote(pageSessionID))
    }
    if let expectText, !expectText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        parts.append("--expect-text")
        parts.append(webViewAwareShellQuote(expectText))
        if timeout != 3 {
            parts.append("--timeout")
            parts.append(formatPointForCommand(timeout))
        }
    }
    switch outputFormat {
    case .json:
        parts.append("--json")
    case .text:
        parts.append("--format")
        parts.append("text")
    }
    return parts.joined(separator: " ")
}

private func webViewAwareTapRecoveryCommand(selector: String, tap: TKWebViewTapResponse, expectText: String?) -> String {
    if let rect = tap.element?.nativeRect {
        let x = rect.x + rect.width / 2
        let y = rect.y + rect.height / 2
        return "triton act tap --at \(formatPointForCommand(x)),\(formatPointForCommand(y)) --json"
    }
    if let expectText, !expectText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "triton webview snapshot --include metadata,text,dom,forms --json"
    }
    return "triton act tap --webview-aware --selector \(webViewAwareShellQuote(selector)) --expect-text <text> --json"
}

private func formatPointForCommand(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    if rounded.rounded() == rounded {
        return String(Int(rounded))
    }
    return String(rounded)
}

private func webViewAwareShellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
