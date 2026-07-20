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

struct Action: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "action",
        abstract: "Grouped UI action commands for agent discovery",
        discussion: "Use `triton act <command>` to discover and execute Triton UI action commands. Retired top-level action aliases are not supported.",
        subcommands: [
            Tap.self,
            Swipe.self,
            TypeText.self,
            PasteText.self,
            ClearText.self,
            Press.self,
            Focus.self,
            SetText.self,
            SelectSegment.self,
            SetSwitch.self,
        ]
    )
}

enum TapStrategyOption: String, ExpressibleByArgument {
    case smart
    case exact
    case ancestor

    var activationStrategy: TKTapActivationStrategy {
        switch self {
        case .smart:
            return .smart
        case .exact:
            return .exact
        case .ancestor:
            return .ancestor
        }
    }
}

struct Act: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "act",
        abstract: "Execute workflow-level UI actions",
        subcommands: [
            Find.self,
            Tap.self,
            TypeText.self,
            PasteText.self,
            ClearText.self,
            Swipe.self,
            Press.self,
            Focus.self,
            SetText.self,
            SelectSegment.self,
            SetSwitch.self,
            Input.self,
        ]
    )
}

struct Find: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Resolve a UI target by visible text, label, identifier, or option title")

    @Argument(help: "Text, label, identifier, or visible option title to resolve") var query: String
    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Include all matching candidates with stable 1-based indexes") var all = false
    @Option(help: "Select one matching candidate by 1-based index") var index: Int?
    @Option(help: "Restrict matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Restrict matching to candidate containing point: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if within != nil && at != nil {
                if outputFormat == .json {
                    try printValidationError("--within and --at cannot be used together")
                    throw ExitCode.failure
                }
                throw RuntimeError("--within and --at cannot be used together")
            }
            let bounds = try within.map(parseBounds)
            let point = try at.map(parsePoint)
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let resolution = try await resolveTapTarget(
                query,
                client: client,
                width: nil,
                height: nil,
                duration: nil,
                index: index,
                within: bounds,
                at: point,
                includeCandidates: all
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(resolution))
            case .text:
                print("query: \(resolution.query)")
                print("source: \(resolution.source)")
                print("strategy: \(resolution.strategy)")
                if let label = resolution.label { print("label: \(label)") }
                if let value = resolution.value { print("value: \(value)") }
                if let identifier = resolution.identifier { print("identifier: \(identifier)") }
                if let className = resolution.className { print("className: \(className)") }
                if let targetOID = resolution.targetOID { print("targetOID: \(targetOID)") }
                if let viewOID = resolution.viewOID { print("viewOID: \(viewOID)") }
                if let layerOID = resolution.layerOID { print("layerOID: \(layerOID)") }
                if let frame = resolution.frame { print("frame: \(formatRect(frame))") }
                print("matchIndex: \(resolution.matchIndex)")
                print("matchCount: \(resolution.matchCount)")
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Wait: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Wait for text, disappearance, idle state, hierarchy change, or a safe predicate"
    )

    @Option(help: "Host platform adapter: ios, android, or harmony") var platform: HostPlatform?
    @Option(name: .customLong("text"), help: "Visible text, AX label, identifier, title, or value to wait for") var text: String?
    @Option(name: .customLong("gone"), help: "Visible text, AX label, identifier, title, or value to wait to disappear") var gone: String?
    @Option(name: .customLong("exists"), help: "Alias for --text; can be combined with --role") var exists: String?
    @Flag(name: .customLong("idle"), help: "Wait until the target is connected and hierarchy is stable across two polls") var idle = false
    @Flag(name: .customLong("hierarchy-change"), help: "Wait until the hierarchy snapshot changes") var hierarchyChange = false
    @Option(name: .customLong("since"), help: "Hierarchy change baseline; currently supports latest") var since: String = "latest"
    @Option(name: .customLong("predicate"), help: "Safe predicate using text.exists/gone with &&, ||, !") var predicate: String?
    @Option(name: .customLong("role"), help: "Optional AX role filter for --text or --exists") var role: String?
    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Timeout in seconds") var timeout: Double = 10
    @Option(help: "Polling interval in seconds") var interval: Double = 0.5

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selectorCount = [
                text != nil,
                gone != nil,
                exists != nil,
                idle,
                hierarchyChange,
                predicate != nil,
            ].filter { $0 }.count
            guard selectorCount == 1 else {
                if outputFormat == .json {
                    try printValidationError("Provide exactly one wait condition: --text, --gone, --exists, --idle, --hierarchy-change, or --predicate")
                    throw ExitCode.failure
                }
                throw RuntimeError("Provide exactly one wait condition")
            }
            guard timeout > 0 else {
                if outputFormat == .json {
                    try printValidationError("--timeout must be greater than 0")
                    throw ExitCode.failure
                }
                throw RuntimeError("--timeout must be greater than 0")
            }
            guard interval > 0 else {
                if outputFormat == .json {
                    try printValidationError("--interval must be greater than 0")
                    throw ExitCode.failure
                }
                throw RuntimeError("--interval must be greater than 0")
            }
            if hierarchyChange && since != "latest" {
                if outputFormat == .json {
                    try printValidationError("--since currently supports only latest")
                    throw ExitCode.failure
                }
                throw RuntimeError("--since currently supports only latest")
            }

            if platform == .ios {
                guard text != nil || gone != nil || exists != nil else {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "iOS host wait currently supports --text, --exists, or --gone for Simulator targets.",
                        hint: "Use `triton observe tree --platform ios --device <selector> --json` for raw host AX evidence.",
                        outputFormat: outputFormat
                    )
                }
                let query = text ?? gone ?? exists ?? ""
                let selected = try resolveHostDeviceSelection(
                    request: iosHostWaitSelectionRequest(target: target),
                    hdc: hdc,
                    adb: adb
                ).target
                guard usesIOSHostSimulatorAX(selected) else {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "iOS host wait is scoped to local Simulator targets.",
                        hint: "Pass a booted Simulator selector such as `--device booted` or `--device sim:<udid>`.",
                        outputFormat: outputFormat
                    )
                }
                let response = try await waitForIOSHostText(
                    selected: selected,
                    text: query,
                    role: role,
                    timeout: timeout,
                    interval: interval,
                    gone: gone != nil
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print(response.ok ? "matched \(query)" : "timed out waiting for \(query)")
                }
                if !response.ok {
                    throw ExitCode.failure
                }
                return
            }

            if platform == .android {
                guard text != nil || gone != nil || exists != nil else {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Android host wait currently supports --text, --exists, or --gone.",
                        hint: "Use `triton observe tree --platform android --json` for raw host layout evidence.",
                        outputFormat: outputFormat
                    )
                }
                let query = text ?? gone ?? exists ?? ""
                let selected = try resolveAndroidActionSelection(target: target, adb: adb)
                let startedAt = Date()
                let deadline = startedAt.addingTimeInterval(timeout)
                var pollCount = 0
                var lastMatch: HostAndroidTapMatch?
                var sourceCommands: [String] = []
                while true {
                    pollCount += 1
                    let (match, commands) = try observeAndroidTextMatch(selected: selected, query: query, adb: adb)
                    sourceCommands.append(contentsOf: commands)
                    lastMatch = match
                    let matched = gone != nil ? lastMatch == nil : lastMatch != nil
                    if matched {
                        let response = HostAndroidWaitOutput(
                            ok: true,
                            action: "wait",
                            platform: "android",
                            target: selected,
                            condition: gone != nil ? "gone" : "text",
                            query: query,
                            matched: true,
                            timedOut: false,
                            elapsedMs: elapsedMilliseconds(since: startedAt),
                            pollCount: pollCount,
                            match: lastMatch,
                            sourceCommands: sourceCommands
                        )
                        switch outputFormat {
                        case .json:
                            print(try encodeJSON(response))
                        case .text:
                            print("matched \(query)")
                        }
                        return
                    }
                    if Date() >= deadline {
                        let response = HostAndroidWaitOutput(
                            ok: false,
                            action: "wait",
                            platform: "android",
                            target: selected,
                            condition: gone != nil ? "gone" : "text",
                            query: query,
                            matched: false,
                            timedOut: true,
                            elapsedMs: elapsedMilliseconds(since: startedAt),
                            pollCount: pollCount,
                            match: lastMatch,
                            sourceCommands: sourceCommands
                        )
                        switch outputFormat {
                        case .json:
                            print(try encodeJSON(response))
                        case .text:
                            print("timed out waiting for \(query)")
                        }
                        throw ExitCode.failure
                    }
                    let remaining = deadline.timeIntervalSinceNow
                    let sleepSeconds = max(0.01, min(interval, remaining))
                    try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
                }
            }

            if platform == .harmony {
                guard text != nil || gone != nil || exists != nil else {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Harmony host wait currently supports --text, --exists, or --gone.",
                        hint: "Use `triton debug ax --platform harmony --output <path> --json` for raw layout evidence.",
                        outputFormat: outputFormat
                    )
                }
                let query = text ?? gone ?? exists ?? ""
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                let response = try await waitForHarmonyText(
                    selected: selected,
                    hdc: hdc,
                    text: query,
                    timeout: timeout,
                    interval: interval,
                    gone: gone != nil
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print(response.ok ? "matched \(query)" : "timed out waiting for \(query)")
                }
                if !response.ok {
                    throw ExitCode.failure
                }
                return
            }

            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let request = WaitRequest(
                condition: waitCondition(),
                query: text ?? gone ?? exists,
                predicate: predicate,
                role: role,
                timeout: timeout,
                interval: interval
            )
            let result = try await performWait(request, client: client)
            try printWaitResult(result, format: outputFormat)
            if !result.ok {
                throw ExitCode.failure
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }

    private func waitCondition() -> TKWaitCondition {
        if text != nil { return .text }
        if gone != nil { return .gone }
        if exists != nil { return .exists }
        if idle { return .idle }
        if hierarchyChange { return .hierarchyChange }
        return .predicate
    }
}

struct Tap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Tap a UI target by text, coordinate, oid, or AX node")

    @Argument(help: "Text, label, identifier, or visible option title to tap") var query: String?
    @Option(help: "Alternate flag form for the text query; use either positional <query> or --text") var text: String?
    @Option(help: "Host platform adapter: android or harmony") var platform: HostPlatform?
    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
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
    @Option(help: "Hold duration in seconds") var duration: Double?
    @Option(help: "Activation strategy for query or AX text matches: smart, exact, or ancestor") var strategy: TapStrategyOption?
    @Option(help: "Select one matching query candidate by 1-based index") var index: Int?
    @Option(help: "Restrict query matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Coordinate selector or query disambiguation point: x,y") var at: String?
    @Flag(name: .customLong("webview-aware"), help: "Route this tap through the current WebView provider; first slice is explicit opt-in") var webViewAware = false
    @Option(help: "CSS selector for --webview-aware WebView tap") var selector: String?
    @Option(name: .customLong("webview-id"), help: "WebView candidate id for --webview-aware tap disambiguation") var webViewID: String?
    @Option(name: .customLong("page-session-id"), help: "Expected WebView page session id for --webview-aware tap") var pageSessionID: String?
    @Option(name: .customLong("expect-text"), help: "Expected WebView text after --webview-aware dispatch") var expectText: String?
    @Option(help: "Timeout in seconds for --webview-aware expectation") var timeout: Double = 3

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
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
            let (_, runtimeClient) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
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
                try await runInputRequest(resolution.request, client: client, format: outputFormat)
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
            let request = tapRequest(
                for: node,
                width: width,
                height: height,
                duration: duration,
                activationStrategy: strategy?.activationStrategy ?? .exact
            )
            try await runInputRequest(request, client: client, format: outputFormat)
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

struct Swipe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Swipe inside the app using window-point coordinates")

    @Option(help: "Platform adapter: iOS embedded runtime, android host, or harmony host") var platform: HostPlatform?
    @Option(name: [.long, .customLong("device")], help: "Runtime target id from `triton list --json`; for iOS use triton:ios-simulator:<udid> or triton:ios-simulator:<udid>/app:<bundle-id>, not host selector sim:<udid>. --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(name: .customLong("start-x"), help: "Start x coordinate in points") var startX: Double
    @Option(name: .customLong("start-y"), help: "Start y coordinate in points") var startY: Double
    @Option(name: .customLong("end-x"), help: "End x coordinate in points") var endX: Double
    @Option(name: .customLong("end-y"), help: "End y coordinate in points") var endY: Double
    @Option(help: "Optional screen/window width in points") var width: Double?
    @Option(help: "Optional screen/window height in points") var height: Double?
    @Option(help: "Gesture duration in seconds") var duration: Double?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if platform == .android {
            do {
                if width != nil || height != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Android host swipe uses absolute screen coordinates and does not support --width or --height normalization.",
                        hint: "Use coordinates from `triton observe tree --platform android --json` or screenshot pixels.",
                        outputFormat: outputFormat
                    )
                }
                if let duration, duration <= 0 {
                    try failHostValidation(
                        code: "validation_failed",
                        message: "--duration must be greater than 0.",
                        hint: "Omit --duration to use the Android input default duration.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveAndroidActionSelection(target: target, adb: adb)
                let durationMs = duration.map { Int(($0 * 1000).rounded()) }
                let command = TKAndroidADBCommand.swipeCoordinate(
                    serial: selected.target,
                    startX: Int(startX.rounded()),
                    startY: Int(startY.rounded()),
                    endX: Int(endX.rounded()),
                    endY: Int(endY.rounded()),
                    durationMs: durationMs,
                    executable: adb
                )
                let result = try runHostCommand(command)
                let response = HostAndroidSwipeOutput(
                    ok: true,
                    action: "swipe",
                    platform: "android",
                    target: selected,
                    startX: Int(startX.rounded()),
                    startY: Int(startY.rounded()),
                    endX: Int(endX.rounded()),
                    endY: Int(endY.rounded()),
                    durationMs: durationMs,
                    sourceCommands: [result.sourceCommand],
                    note: "Android swipe was submitted through adb input; verify business state with wait, observe, or screenshot."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("\(response.startX),\(response.startY) -> \(response.endX),\(response.endY)")
                }
            } catch {
                if error is ExitCode { throw error }
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }

        if platform == .harmony {
            do {
                if width != nil || height != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Harmony host swipe uses absolute screen coordinates and does not support --width or --height normalization.",
                        hint: "Use coordinates from `triton observe tree --platform harmony --json` or screenshot pixels.",
                        outputFormat: outputFormat
                    )
                }
                if let duration, duration <= 0 {
                    try failHostValidation(
                        code: "validation_failed",
                        message: "--duration must be greater than 0.",
                        hint: "Omit --duration to use the Harmony uitest default velocity.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                let command = TKHarmonyHDCCommand.swipeCoordinate(
                    target: selected.target,
                    startX: Int(startX.rounded()),
                    startY: Int(startY.rounded()),
                    endX: Int(endX.rounded()),
                    endY: Int(endY.rounded()),
                    velocity: harmonySwipeVelocity(startX: startX, startY: startY, endX: endX, endY: endY, duration: duration),
                    executable: hdc
                )
                let result = try runHostCommand(command)
                let response = HostHarmonySwipeOutput(
                    ok: true,
                    action: "swipe",
                    platform: "harmony",
                    target: selected,
                    startX: Int(startX.rounded()),
                    startY: Int(startY.rounded()),
                    endX: Int(endX.rounded()),
                    endY: Int(endY.rounded()),
                    velocity: harmonySwipeVelocity(startX: startX, startY: startY, endX: endX, endY: endY, duration: duration),
                    sourceCommands: [result.sourceCommand],
                    note: "Harmony swipe was submitted through uitest; verify business state with wait, ax, or screenshot."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("\(response.startX),\(response.startY) -> \(response.endX),\(response.endY)")
                }
            } catch {
                if error is ExitCode { throw error }
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }

        do {
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let request = TKInputRequest.swipe(
                startX: startX,
                startY: startY,
                endX: endX,
                endY: endY,
                width: width,
                height: height,
                duration: duration
            )
            try await runInputRequest(request, client: client, format: outputFormat)
        } catch {
            if platform == .harmony {
                try failHostCommand(error, outputFormat: outputFormat)
            }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct TypeText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text into a focused or oid-targeted UIKeyInput"
    )

    @Argument(help: "Text to insert") var textArgument: String?
    @Option(help: "Host platform adapter: android or harmony") var platform: HostPlatform?
    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Alternate flag form for the text value; use either positional <text> or --text") var text: String?
    @Option(help: "Optional responder oid from `triton debug nodes`") var oid: UInt?
    @Flag(name: .customLong("secure"), help: "Redact inserted text details in command output") var secure = false
    @Flag(name: .customLong("exact"), help: "Use direct UIKeyInput insertion without keyboard autocorrect") var exact = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selectorCount = [textArgument != nil, text != nil].filter { $0 }.count
            guard selectorCount == 1 else {
                if outputFormat == .json {
                    try printValidationError("Provide exactly one text value: <text> or --text")
                    throw ExitCode.failure
                }
                throw RuntimeError("Provide exactly one text value: <text> or --text")
            }
            let value = textArgument ?? text ?? ""
            if platform == .android {
                if oid != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Android host type currently targets the focused field only and does not support --oid.",
                        hint: "Focus the field with `triton act tap --platform android` first, then run `triton act type --platform android <text>`.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveAndroidActionSelection(target: target, adb: adb)
                let command = TKAndroidADBCommand.inputText(serial: selected.target, text: value, executable: adb)
                _ = try runHostCommand(command)
                let response = HostAndroidTextInputOutput(
                    ok: true,
                    action: "type",
                    platform: "android",
                    target: selected,
                    x: nil,
                    y: nil,
                    secure: secure,
                    redacted: secure,
                    insertedLength: value.count,
                    sourceCommands: [androidTextSourceCommand(command, text: value, secure: secure)],
                    note: "Android text input was submitted to the focused field through adb input; verify field state with wait, observe, or screenshot."
                )
                try printAndroidTextInput(response, format: outputFormat)
                return
            }
            if platform == .harmony {
                if oid != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Harmony host type currently targets the focused field only and does not support --oid.",
                        hint: "Focus the field with `triton act tap --platform harmony` first, then run `triton act type --platform harmony <text>`.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                let command = TKHarmonyHDCCommand.inputText(target: selected.target, text: value, executable: hdc)
                let result = try runHostCommand(command)
                let response = HostHarmonyTextInputOutput(
                    ok: true,
                    action: "type",
                    platform: "harmony",
                    target: selected,
                    x: nil,
                    y: nil,
                    secure: secure,
                    redacted: secure,
                    insertedLength: value.count,
                    sourceCommands: [harmonyTextSourceCommand(command, text: value, secure: secure)],
                    note: "Harmony text input was submitted to the focused field through uitest; verify field state with wait, ax, or screenshot."
                )
                try printHarmonyTextInput(response, format: outputFormat)
                _ = result
                return
            }
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest(type: .typeText, targetOID: oid, text: value, secure: secure),
                client: client,
                format: outputFormat
            )
        } catch {
            if platform == .harmony {
                try failHostCommand(error, outputFormat: outputFormat)
            }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct PasteText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paste",
        abstract: "Paste exact text into a focused, coordinate-targeted, or oid-targeted input"
    )

    @Argument(help: "Text to paste") var text: String
    @Option(help: "Host platform adapter: android or harmony") var platform: HostPlatform?
    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(name: .customLong("secure"), help: "Redact inserted text details in command output") var secure = false
    @Option(help: "Optional responder oid from `triton debug nodes`, `triton debug ax`, or `triton debug hit`") var oid: UInt?
    @Option(help: "Window x coordinate to focus before paste") var x: Double?
    @Option(help: "Window y coordinate to focus before paste") var y: Double?
    @Option(help: "Window point to focus before paste: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let point = try inputFocusPoint(at: at, x: x, y: y, outputFormat: outputFormat)
            if platform == .android {
                if oid != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Android host paste currently supports focused input or coordinate focus, not --oid.",
                        hint: "Use `--at x,y` or tap the field before pasting.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveAndroidActionSelection(target: target, adb: adb)
                var sourceCommands: [String] = []
                let focusX = point?.x ?? x
                let focusY = point?.y ?? y
                if let focusX, let focusY {
                    let tapCommand = TKAndroidADBCommand.tapCoordinate(serial: selected.target, x: Int(focusX.rounded()), y: Int(focusY.rounded()), executable: adb)
                    let tapResult = try runHostCommand(tapCommand)
                    sourceCommands.append(tapResult.sourceCommand)
                }
                let inputCommand = TKAndroidADBCommand.inputText(serial: selected.target, text: text, executable: adb)
                _ = try runHostCommand(inputCommand)
                sourceCommands.append(androidTextSourceCommand(inputCommand, text: text, secure: secure))
                let response = HostAndroidTextInputOutput(
                    ok: true,
                    action: "paste",
                    platform: "android",
                    target: selected,
                    x: focusX.map { Int($0.rounded()) },
                    y: focusY.map { Int($0.rounded()) },
                    secure: secure,
                    redacted: secure,
                    insertedLength: text.count,
                    sourceCommands: sourceCommands,
                    note: "Android paste is implemented as adb text insertion into the focused field; verify final field state with wait, observe, or screenshot."
                )
                try printAndroidTextInput(response, format: outputFormat)
                return
            }
            if platform == .harmony {
                if oid != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Harmony host paste currently supports focused input or coordinate focus, not --oid.",
                        hint: "Use `--at x,y` or tap the field before pasting.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                var sourceCommands: [String] = []
                let focusX = point?.x ?? x
                let focusY = point?.y ?? y
                if let focusX, let focusY {
                    let tapCommand = TKHarmonyHDCCommand.tapCoordinate(target: selected.target, x: Int(focusX.rounded()), y: Int(focusY.rounded()), executable: hdc)
                    let tapResult = try runHostCommand(tapCommand)
                    sourceCommands.append(tapResult.sourceCommand)
                }
                let inputCommand: TKHostCommand
                if let focusX, let focusY {
                    inputCommand = TKHarmonyHDCCommand.inputTextAt(target: selected.target, x: Int(focusX.rounded()), y: Int(focusY.rounded()), text: text, executable: hdc)
                } else {
                    inputCommand = TKHarmonyHDCCommand.inputText(target: selected.target, text: text, executable: hdc)
                }
                _ = try runHostCommand(inputCommand)
                sourceCommands.append(harmonyTextSourceCommand(inputCommand, text: text, secure: secure))
                let response = HostHarmonyTextInputOutput(
                    ok: true,
                    action: "paste",
                    platform: "harmony",
                    target: selected,
                    x: focusX.map { Int($0.rounded()) },
                    y: focusY.map { Int($0.rounded()) },
                    secure: secure,
                    redacted: secure,
                    insertedLength: text.count,
                    sourceCommands: sourceCommands,
                    note: "Harmony paste is implemented as focused uitest text insertion; verify final field state with wait, ax, or screenshot."
                )
                try printHarmonyTextInput(response, format: outputFormat)
                return
            }
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest.paste(text, targetOID: oid, x: point?.x ?? x, y: point?.y ?? y, secure: secure),
                client: client,
                format: outputFormat
            )
        } catch {
            if platform == .harmony {
                try failHostCommand(error, outputFormat: outputFormat)
            }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct ClearText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Clear a focused, coordinate-targeted, or oid-targeted input"
    )

    @Option(help: "Host platform adapter: android or harmony") var platform: HostPlatform?
    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Optional responder oid from `triton debug nodes`, `triton debug ax`, or `triton debug hit`") var oid: UInt?
    @Option(help: "Window x coordinate to focus before clear") var x: Double?
    @Option(help: "Window y coordinate to focus before clear") var y: Double?
    @Option(help: "Window point to focus before clear: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if platform == .android {
                _ = try resolveAndroidActionSelection(target: target, adb: adb)
                try failHostValidation(
                    code: "unsupported_capability",
                    message: "Android host clear is not implemented because adb input does not expose a stable clear-current-field primitive.",
                    hint: "Use focused replace flows such as `triton paste --platform android` or app-level semantic actions when available.",
                    outputFormat: outputFormat
                )
            }
            if platform == .harmony {
                _ = try resolveHarmonyTarget(target: target, hdc: hdc)
                try failHostValidation(
                    code: "unsupported_capability",
                    message: "Harmony host clear is not implemented because uitest does not expose a stable clear-current-field primitive.",
                    hint: "Use a provider semantic action or replace the field value through an app-level DEBUG runtime when available.",
                    outputFormat: outputFormat
                )
            }
            let point = try inputFocusPoint(at: at, x: x, y: y, outputFormat: outputFormat)
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest.clear(targetOID: oid, x: point?.x ?? x, y: point?.y ?? y),
                client: client,
                format: outputFormat
            )
        } catch {
            if platform == .harmony {
                try failHostCommand(error, outputFormat: outputFormat)
            }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Press: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Press a device button when supported by the active runtime")

    @Argument(help: "Button name, for example home, lock, power, volume-up") var buttonArgument: String?
    @Option(help: "Host platform adapter: android or harmony") var platform: HostPlatform?
    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Alternate flag form for the button value; use either positional <button> or --button") var button: String?
    @Option(help: "Hold duration in seconds") var duration: Double?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selectorCount = [buttonArgument != nil, button != nil].filter { $0 }.count
            guard selectorCount == 1 else {
                if outputFormat == .json {
                    try printValidationError("Provide exactly one button value: <button> or --button")
                    throw ExitCode.failure
                }
                throw RuntimeError("Provide exactly one button value: <button> or --button")
            }
            let value = buttonArgument ?? button ?? ""
            if platform == .android {
                if duration != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Android host press does not support hold duration through adb keyevent.",
                        hint: "Omit --duration, or use a platform-specific provider when long press semantics are required.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveAndroidActionSelection(target: target, adb: adb)
                let keyCode = androidKeyEventName(for: value)
                let command = TKAndroidADBCommand.keyEvent(serial: selected.target, keyCode: keyCode, executable: adb)
                try runSimpleHostCommand(
                    action: "press",
                    runtimeScope: "host-android",
                    target: "android:\(selected.target)",
                    command: command,
                    outputFormat: outputFormat,
                    note: "Android keyevent \(keyCode) was submitted through adb input; verify business state with wait, observe, or screenshot."
                )
                return
            }
            if platform == .harmony {
                if duration != nil {
                    try failHostValidation(
                        code: "unsupported_capability",
                        message: "Harmony host press does not support hold duration through uitest keyEvent.",
                        hint: "Omit --duration, or use a platform-specific provider when long press semantics are required.",
                        outputFormat: outputFormat
                    )
                }
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                let key = harmonyKeyEventName(for: value)
                let command = TKHarmonyHDCCommand.keyEvent(target: selected.target, key: key, executable: hdc)
                try runSimpleHostCommand(
                    action: "press",
                    runtimeScope: "host-harmony",
                    target: "harmony:\(selected.target)",
                    command: command,
                    outputFormat: outputFormat,
                    note: "Harmony keyEvent \(key) was submitted through uitest; verify business state with wait, ax, or screenshot."
                )
                return
            }
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest.press(button: value, duration: duration),
                client: client,
                format: outputFormat
            )
        } catch {
            if platform == .harmony {
                try failHostCommand(error, outputFormat: outputFormat)
            }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

func harmonySwipeVelocity(startX: Double, startY: Double, endX: Double, endY: Double, duration: Double?) -> Int? {
    guard let duration else { return nil }
    let distance = hypot(endX - startX, endY - startY)
    let velocity = Int((distance / max(duration, 0.01)).rounded())
    return min(40_000, max(200, velocity))
}

func harmonyTextSourceCommand(_ command: TKHostCommand, text: String, secure: Bool) -> String {
    guard secure else {
        return hostSourceCommand(command)
    }
    let redacted = "<redacted:length=\(text.count)>"
    return ([command.executable] + command.arguments.map { $0 == text ? redacted : $0 })
        .map(shellEscaped)
        .joined(separator: " ")
}

func harmonyKeyEventName(for button: String) -> String {
    switch button.lowercased() {
    case "home":
        return "Home"
    case "back":
        return "Back"
    case "power", "lock":
        return "Power"
    default:
        return button
    }
}

func printHarmonyTextInput(_ response: HostHarmonyTextInputOutput, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("\(response.action): insertedLength=\(response.insertedLength)")
    }
}

struct Geometry: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read current window geometry")

    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let data = try await client.request(type: "geometry")
            let geometry = try JSONDecoder().decode(TKGeometryResponse.self, from: data)
            switch outputFormat {
            case .json:
                print(try encodeJSON(geometry))
            case .text:
                print("bounds: \(formatRect(geometry.bounds))")
                print("safeArea: top=\(geometry.safeArea.top) left=\(geometry.safeArea.left) bottom=\(geometry.safeArea.bottom) right=\(geometry.safeArea.right)")
                print("scale: \(geometry.scale)")
                print("orientation: \(geometry.orientation)")
            }
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct AccessibilityTree: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ax",
        abstract: "Read current in-app safe actionable control index"
    )

    @Option(help: "Host platform adapter: android or harmony") var platform: HostPlatform?
    @Option(help: "Unified host device selector: alias, android:<serial>, harmony:<target>, raw id, or current") var device: String?
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(name: .customLong("with-hierarchy"), help: "Join AX nodes to latest hierarchy by view oid") var withHierarchy = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before joining with --with-hierarchy") var refresh = true
    @Option(help: "Write output to a file instead of stdout") var output: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if platform == .android {
            do {
                if device != nil && target != TKLocalTargetID {
                    throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
                }
                let selection = try resolveHostDeviceSelection(
                    request: HostDeviceSelectionRequest(
                        device: device ?? (target == TKLocalTargetID ? nil : target),
                        platform: .android,
                        ready: true
                    ),
                    hdc: hdc,
                    adb: adb
                )
                let outputPath = output ?? FileManager.default.temporaryDirectory
                    .appendingPathComponent("triton-android-\(selection.target.target)-window.xml")
                    .path
                let response = try hostCaptureAndroidLayout(selected: selection.target, adb: adb, output: outputPath)
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print(response.artifact)
                }
            } catch {
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }
        if platform == .harmony {
            do {
                if device != nil && target != TKLocalTargetID {
                    throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
                }
                let selected = try resolveHarmonyTarget(target: device ?? target, hdc: hdc)
                let result = try dumpHarmonyLayout(selected: selected, hdc: hdc, output: output)
                let response = HostHarmonyArtifactOutput(
                    ok: true,
                    action: "ax",
                    platform: "harmony",
                    target: selected,
                    artifact: result.localPath,
                    sourceCommands: result.sourceCommands,
                    note: "Harmony layout was saved as an artifact; inspect attributes.text and attributes.bounds, then verify with wait/tap/screenshot."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print(result.localPath)
                }
            } catch {
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }
        do {
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let data = try await client.request(type: "accessibility")
            let rendered: String
            switch outputFormat {
            case .json:
                if withHierarchy {
                    let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
                    let hierarchyData = refresh
                        ? try await client.request(type: "hierarchy")
                        : try await waitForHierarchy(client: client)
                    let response = try TKBuildAXHierarchyMap(axNodes: nodes, hierarchyData: hierarchyData)
                    rendered = try encodeJSON(response)
                } else {
                    rendered = try prettyJSON(data)
                }
            case .text:
                let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
                if withHierarchy {
                    let hierarchyData = refresh
                        ? try await client.request(type: "hierarchy")
                        : try await waitForHierarchy(client: client)
                    let response = try TKBuildAXHierarchyMap(axNodes: nodes, hierarchyData: hierarchyData)
                    rendered = renderAXHierarchyMap(response)
                } else {
                    rendered = renderAXTree(nodes)
                }
            }
            try writeOrPrint(rendered, output: output)
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Hit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Hit-test one point in the current app window")

    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Window x coordinate in points") var x: Double?
    @Option(help: "Window y coordinate in points") var y: Double?
    @Option(help: "Window point to hit-test: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let point = try requiredPoint(at: at, x: x, y: y, outputFormat: outputFormat)
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let payload = try JSONEncoder().encode(TKHitTestRequest(x: point.x, y: point.y))
            let data = try await client.request(type: "hitTest", payload: payload)
            let response = try JSONDecoder().decode(TKHitTestResponse.self, from: data)
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("x: \(response.x)")
                print("y: \(response.y)")
                print("center: \(response.centerX.map(String.init(describing:)) ?? "-"),\(response.centerY.map(String.init(describing:)) ?? "-")")
                if let node = response.node {
                    print("role: \(node.role)")
                    print("label: \(node.label ?? "-")")
                    print("identifier: \(node.identifier ?? "-")")
                    print("targetOID: \(node.targetOID.map(String.init(describing:)) ?? "-")")
                    print("className: \(node.className ?? "-")")
                    print("frame: \(formatRect(node.frame))")
                } else {
                    print("node: -")
                }
            }
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Screenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Capture current app screenshot as PNG")

    @Option(help: "Host platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Runtime target id from `triton list`; when used with --platform/--device, this may also be a raw host target id") var target: String = TKLocalTargetID
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready host targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output PNG file path") var output: String
    @Flag(help: "Print screenshot metadata as JSON after writing the file") var metadata = false
    @Flag(name: .customLong("json"), help: "Alias for --metadata") var json = false

    func run() async throws {
        let outputFormat: ClientOutputFormat = metadata || json ? .json : .text
        if platform != nil || device != nil {
            do {
                if device != nil && target != TKLocalTargetID {
                    throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
                }
                let selection = try resolveHostDeviceSelection(
                    request: HostDeviceSelectionRequest(
                        device: device ?? (target == TKLocalTargetID ? nil : target),
                        platform: platform,
                        name: name,
                        runtime: runtime,
                        state: state,
                        ready: ready
                    ),
                    hdc: hdc
                )
                let response = try captureHostDeviceScreenshot(
                    platform: selection.platform,
                    target: selection.target,
                    selection: selection,
                    hdc: hdc,
                    adb: adb,
                    output: output
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print(output)
                }
            } catch {
                try failHostCommand(error, outputFormat: outputFormat)
            }
            return
        }
        do {
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let data = try await client.request(type: "screenshot")
            let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: data)
            let imageData = try await screenshotImageData(screenshot, client: client)
            try imageData.write(to: URL(fileURLWithPath: output), options: .atomic)
            if outputFormat == .json {
                let summary: [String: Any] = [
                    "format": screenshot.format,
                    "width": screenshot.width,
                    "height": screenshot.height,
                    "scale": screenshot.scale,
                    "output": output,
                    "bytes": imageData.count,
                ]
                print(try encodeJSONObject(summary))
            } else {
                print(output)
            }
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Input: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "input",
        abstract: "Read newline-delimited JSON input actions from stdin"
    )

    @Option(name: [.long, .customLong("device")], help: "Target id from `triton list`; --device is an alias") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Stop on the first failed action") var failFast = false
    @Flag(help: "Print a final JSON batch summary") var summary = false
    @Flag(help: "Exit non-zero when any action fails") var strict = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
        var hadFailure = false
        var actionCount = 0
        var failedCount = 0

        while let line = readLine() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            actionCount += 1
            let result: TKInputResult
            do {
                let data = Data(trimmed.utf8)
                let input = try JSONDecoder().decode(TKInputRequest.self, from: data)
                result = try await executeInputRequest(input, client: client)
            } catch {
                result = TKInputResult.failure(action: "input", message: "\(error)")
            }
            try printInputResult(result, format: outputFormat)
            fflush(stdout)
            if !result.ok {
                hadFailure = true
                failedCount += 1
                if failFast { break }
            }
        }

        if summary {
            let response = TKInputBatchSummaryResponse(
                ok: failedCount == 0,
                actionCount: actionCount,
                failedCount: failedCount
            )
            switch outputFormat {
            case .json:
                print(try encodeCompactJSON(response))
            case .text:
                print("summary: ok=\(response.ok) actionCount=\(response.actionCount) failedCount=\(response.failedCount)")
            }
            fflush(stdout)
        }

        if hadFailure && (failFast || strict) {
            throw RuntimeError("Input failed")
        }
    }
}

// MARK: - State
