import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

// MARK: - Entry Point

@main
struct TritonKitEntry {
    static func main() async {
        if shouldPrintChineseHelp() {
            printChineseHelp()
            return
        }
        await TritonKitCLI.main()
    }
}

struct TritonKitCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "triton",
        abstract: "TritonKit macOS CLI - WebSocket control + HTTP data server for iOS view debugging",
        version: tritonCLIVersion,
        subcommands: [
            Serve.self,
            Version.self,
            Status.self,
            Doctor.self,
            Capabilities.self,
            Schema.self,
            Plan.self,
            List.self,
            Inspect.self,
            Hierarchy.self,
            Nodes.self,
            Node.self,
            Attrs.self,
            ObjectInfo.self,
            Export.self,
            Find.self,
            Tap.self,
            Swipe.self,
            TypeText.self,
            Press.self,
            Geometry.self,
            AccessibilityTree.self,
            Hit.self,
            Screenshot.self,
            Input.self,
        ],
        defaultSubcommand: List.self
    )
}

// MARK: - Serve Command

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Start server")

    @Option(name: .shortAndLong, help: "Port to listen on") var port: Int = 19421
    @Option(name: .shortAndLong, help: "Host to bind to") var host: String = "0.0.0.0"

    func run() async throws {
        let store = DataStore()
        let state = ConnectionState()
        let targetState = TargetState()
        let encoder = JSONEncoder()
        let counter = MessageCounter()

        let router = Router(context: BasicWebSocketRequestContext.self)

        // ---- HTTP Data Endpoints ----

        router.post("/data") { request, _ -> Response in
            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }
            guard !bodyData.isEmpty else {
                return Response(status: .badRequest, body: .init(byteBuffer: ByteBuffer(string: "Empty body")))
            }
            let id = store.put(bodyData)
            let resp = try JSONEncoder().encode(["id": id])
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: resp)))
        }

        router.get("/data/:id") { request, _ -> Response in
            guard let idStr = request.uri.path.split(separator: "/").last,
                  let id = UUID(uuidString: String(idStr)),
                  let data = store.get(id) else {
                return Response(status: .notFound)
            }
            return Response(status: .ok, headers: [.contentType: "application/octet-stream"],
                            body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        router.get("/health") { _, _ -> HTTPResponse.Status in .ok }

        router.get("/hierarchy/latest") { _, _ -> Response in
            guard let data = targetState.latestHierarchy else {
                return jsonError(
                    code: "hierarchy_unavailable",
                    message: "No hierarchy received yet",
                    endpoint: "/hierarchy/latest",
                    hint: "Connect an app that embeds TritonKit, then request `triton hierarchy --json`",
                    status: .notFound
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        router.get("/status") { _, _ -> Response in
            jsonResponse(TKStatusResponse(
                connected: state.isConnected,
                latestHierarchyAvailable: targetState.latestHierarchy != nil,
                targetCount: state.isConnected ? 1 : 0
            ))
        }

        router.get("/targets") { _, _ -> Response in
            let targets = targetState.summary(connected: state.isConnected).map { [$0] } ?? []
            return jsonResponse(TKTargetsResponse(targets: targets))
        }

        router.get("/geometry") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .geometry,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/geometry"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/geometry",
                    hint: "Connect an app that embeds TritonKit before requesting geometry",
                    status: .conflict
                )
            }
        }

        router.get("/accessibility") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .accessibility,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/accessibility"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/accessibility",
                    hint: "Connect an app that embeds TritonKit before requesting accessibility",
                    status: .conflict
                )
            }
        }

        router.post("/hit") { request, _ -> Response in
            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }
            guard let hit = try? JSONDecoder().decode(TKHitTestRequest.self, from: bodyData),
                  let hitPayload = try? JSONEncoder().encode(hit) else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported hit payload",
                    endpoint: "/hit",
                    hint: "Send JSON with numeric x and y fields",
                    status: .badRequest
                )
            }
            do {
                let payload = try await requestPayload(
                    type: .hitTest,
                    payload: hitPayload,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/hit"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/hit",
                    hint: "Connect an app that embeds TritonKit before hit testing",
                    status: .conflict
                )
            }
        }

        router.get("/screenshot") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .screenshot,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                guard let screenshot = try? JSONDecoder().decode(TKScreenshotResponse.self, from: payload),
                      let imageData = try? await screenshotImageData(screenshot, client: TritonKitHTTPClient(host: host, port: port)) else {
                    return jsonError(
                        code: "invalid_payload",
                        message: "Invalid screenshot payload",
                        endpoint: "/screenshot",
                        hint: "Retry after the connected runtime responds to screenshot",
                        status: .internalServerError
                    )
                }
                return Response(status: .ok, headers: [.contentType: "image/png"],
                                body: .init(byteBuffer: ByteBuffer(data: imageData)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/screenshot"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/screenshot",
                    hint: "Connect an app that embeds TritonKit before requesting screenshot",
                    status: .conflict
                )
            }
        }

        router.post("/command") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/command",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard
                let command = try? JSONDecoder().decode(TKCLICommandRequest.self, from: bodyData),
                let type = command.requestType
            else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported command",
                    endpoint: "/command",
                    hint: "Send JSON with a supported type such as ping, appInfo, or hierarchy",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: type, payload: command.payload), encoder: encoder)
            return jsonResponse(TKCLICommandResponse(id: id, type: type.rawValue))
        }

        router.post("/request") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/request",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard
                let command = try? JSONDecoder().decode(TKCLICommandRequest.self, from: bodyData),
                let type = command.requestType
            else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported command",
                    endpoint: "/request",
                    hint: "Send JSON with a supported type and optional payload",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: type, payload: command.payload), encoder: encoder)
            guard let payload = await targetState.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: type.rawValue, endpoint: "/request"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: payload)))
        }

        router.post("/input") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/input",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard let input = try? JSONDecoder().decode(TKInputRequest.self, from: bodyData),
                  let payload = try? JSONEncoder().encode(input) else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported input payload",
                    endpoint: "/input",
                    hint: "Send one TKInputRequest JSON object such as {\"type\":\"tap\",\"x\":1,\"y\":1}",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> input [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: .input, payload: payload), encoder: encoder)
            guard let responsePayload = await targetState.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: "input", endpoint: "/input"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: responsePayload)))
        }

        // ---- WebSocket Control Channel ----

        router.ws("/") { inbound, outbound, _ in
            log("[tritonkit] iOS device connected (ws)")
            state.set(outbound)

            // Test ping first to verify bidirectional communication
            let pingId = counter.next()
            log("[tritonkit] -> ping [id:\(pingId)]")
            try await outbound.send(TKMessage(id: pingId, type: .ping), encoder: encoder)

            // Then request hierarchy
            let id = counter.next()
            log("[tritonkit] -> hierarchy [id:\(id)]")
            try await outbound.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)

            do {
                for try await frame in inbound {
                    let data: Data
                    switch frame.opcode {
                    case .binary: data = Data(frame.data.readableBytesView)
                    case .text: data = Data(String(buffer: frame.data).utf8)
                    default: continue
                    }
                    handleResponse(
                        data: data,
                        store: store,
                        targetState: targetState
                    )
                }
            } catch {
                log("[tritonkit] Connection error: \(error)")
            }

            log("[tritonkit] iOS device disconnected")
            state.set(nil)
        }

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(
                webSocketRouter: router,
                configuration: .init(maxFrameSize: tritonWebSocketMaxFrameSize, extensions: [])
            ),
            configuration: .init(address: .hostname(host, port: port))
        )

        log("[tritonkit] Control: ws://\(host):\(port)/")
        log("[tritonkit] Data:   http://\(host):\(port)/data")
        log("[tritonkit] Status: http://\(host):\(port)/status")
        log("[tritonkit] Command: POST http://\(host):\(port)/command")
        log("[tritonkit] Commands: h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")

        // Stdin
        Task {
            while let line = readLine() {
                switch line.trimmingCharacters(in: .whitespaces).lowercased() {
                case "q", "quit", "exit": log("[tritonkit] Shut down."); Darwin.exit(0)
                case "h", "hierarchy":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> hierarchy [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "a", "appinfo":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> appInfo [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .appInfo), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "p", "ping":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> ping [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .ping), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "help", "?": log("[tritonkit] h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")
                case "": break
                default: log("[tritonkit] Unknown: \(line)")
                }
            }
        }

        signal(SIGINT, SIG_IGN)
        let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sig.setEventHandler { log("\n[tritonkit] Interrupted."); Darwin.exit(0) }
        sig.resume()

        do { try await app.run() } catch { log("[tritonkit] Error: \(error)"); throw error }
    }
}

// MARK: - Client Commands

enum ClientOutputFormat: String, ExpressibleByArgument {
    case text
    case json
}

enum HierarchyOutputFormat: String, ExpressibleByArgument {
    case tree
    case json
}

enum ExportOutputFormat: String, ExpressibleByArgument {
    case auto
    case json
    case archive
}

enum CLILanguage: String, CaseIterable, ExpressibleByArgument {
    case en
    case zh
}

struct LocalizationOptions: ParsableArguments {
    @Option(name: [.customLong("language"), .customLong("lang")], help: "Human-readable output language: en or zh")
    var language: CLILanguage?
}

let tritonCLIVersion = "0.1.0"
let tritonWebSocketMaxFrameSize = 16_777_216

func effectiveFormat(_ format: ClientOutputFormat, json: Bool) -> ClientOutputFormat {
    json ? .json : format
}

func effectiveFormat(_ format: HierarchyOutputFormat, json: Bool) -> HierarchyOutputFormat {
    json ? .json : format
}

func effectiveFormat(_ format: ExportOutputFormat, json: Bool) -> ExportOutputFormat {
    json ? .json : format
}

func effectiveLanguage(_ option: CLILanguage?) -> CLILanguage {
    option ?? environmentLanguage() ?? .en
}

func environmentLanguage() -> CLILanguage? {
    let environment = ProcessInfo.processInfo.environment
    guard let raw = environment["TRITON_LANGUAGE"] ?? environment["TRITON_LANG"] else {
        return nil
    }
    return normalizeLanguage(raw)
}

func normalizeLanguage(_ raw: String) -> CLILanguage? {
    let normalized = raw
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "_", with: "-")
        .lowercased()
    if normalized == "en" || normalized.hasPrefix("en-") {
        return .en
    }
    if normalized == "zh" || normalized.hasPrefix("zh-") {
        return .zh
    }
    return nil
}

func shouldPrintChineseHelp(arguments: [String] = Array(ProcessInfo.processInfo.arguments.dropFirst())) -> Bool {
    guard effectiveHelpLanguage(arguments: arguments) == .zh else {
        return false
    }
    return helpRequest(arguments: arguments) != nil
}

func effectiveHelpLanguage(arguments: [String]) -> CLILanguage {
    if let index = arguments.firstIndex(where: { $0 == "--language" || $0 == "--lang" }),
       arguments.indices.contains(arguments.index(after: index)),
       let language = normalizeLanguage(arguments[arguments.index(after: index)]) {
        return language
    }
    for argument in arguments {
        if argument.hasPrefix("--language="),
           let language = normalizeLanguage(String(argument.dropFirst("--language=".count))) {
            return language
        }
        if argument.hasPrefix("--lang="),
           let language = normalizeLanguage(String(argument.dropFirst("--lang=".count))) {
            return language
        }
    }
    return environmentLanguage() ?? .en
}

enum HelpRequest {
    case root
    case command(String)
}

func helpRequest(arguments: [String]) -> HelpRequest? {
    let filtered = stripLanguageArguments(arguments)
    if filtered.isEmpty {
        return nil
    }
    if filtered.contains("-h") || filtered.contains("--help") {
        if let command = filtered.first(where: { !$0.hasPrefix("-") && $0 != "help" }) {
            return .command(command)
        }
        return .root
    }
    if filtered.first == "help" {
        if filtered.count > 1 {
            return .command(filtered[1])
        }
        return .root
    }
    return nil
}

func stripLanguageArguments(_ arguments: [String]) -> [String] {
    var result: [String] = []
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
        if argument == "--language" || argument == "--lang" {
            _ = iterator.next()
            continue
        }
        if argument.hasPrefix("--language=") || argument.hasPrefix("--lang=") {
            continue
        }
        result.append(argument)
    }
    return result
}

func printChineseHelp(arguments: [String] = Array(ProcessInfo.processInfo.arguments.dropFirst())) {
    switch helpRequest(arguments: arguments) {
    case .command(let command):
        print(chineseCommandHelp(command))
    case .root, .none:
        print(chineseRootHelp())
    }
}

struct ChineseCommandHelp {
    let name: String
    let overview: String
    let usage: String
    let options: [(String, String)]
}

func chineseRootHelp() -> String {
    let commands: [(String, String)] = [
        ("serve", "启动本地 WebSocket 与 HTTP 控制服务"),
        ("version", "输出 Triton CLI 版本和启动默认值"),
        ("status", "读取本地 TritonKit 服务状态"),
        ("doctor", "诊断服务、目标和运行时能力"),
        ("capabilities", "输出 Triton 运行时能力矩阵"),
        ("schema", "输出机器可读命令 schema 和示例"),
        ("plan", "根据当前状态输出推荐下一步"),
        ("list (默认)", "列出已连接的 TritonKit 目标"),
        ("inspect", "查看单个 TritonKit 目标摘要"),
        ("hierarchy", "读取目标最新视图层级"),
        ("nodes", "列出最新层级中的节点摘要"),
        ("node", "查看单个层级节点"),
        ("attrs", "读取节点 layer oid 的实时属性组"),
        ("object", "读取 view 或 layer oid 的对象元数据"),
        ("export", "导出可复用层级快照或 archive"),
        ("find", "解析一个可见文本或意图目标"),
        ("tap", "点击文本、坐标、view oid 或 AX 节点"),
        ("swipe", "在 App 内按 window points 执行滑动"),
        ("type", "向已聚焦或 oid 指定的 UIKeyInput 输入文本"),
        ("press", "在当前运行时支持时按设备按钮"),
        ("geometry", "读取当前 window 几何信息"),
        ("ax", "读取 App 内安全可操作控件索引"),
        ("hit", "对当前 App window 中一点做命中测试"),
        ("screenshot", "捕获当前 App PNG 截图"),
        ("input", "从 stdin 读取 NDJSON 输入动作"),
    ]
    var lines = [
        "概览: TritonKit macOS CLI - iOS 视图调试的 WebSocket 控制与 HTTP 数据服务",
        "",
        "用法: triton <子命令>",
        "",
        "选项:",
        "  --language, --lang <language>  人读输出语言：en 或 zh",
        "  --version                      显示版本。",
        "  -h, --help                     显示帮助信息。",
        "",
        "子命令:",
    ]
    lines.append(contentsOf: commands.map { "  \($0.0.padding(toLength: 22, withPad: " ", startingAt: 0))\($0.1)" })
    lines.append("")
    lines.append("  使用 `triton --language zh help <子命令>` 查看子命令帮助。")
    return lines.joined(separator: "\n")
}

func chineseCommandHelp(_ command: String) -> String {
    let help = chineseCommandHelps()[command] ?? ChineseCommandHelp(
        name: command,
        overview: "暂无该子命令的中文帮助。",
        usage: "triton \(command) [选项]",
        options: []
    )
    var lines = [
        "概览: \(help.overview)",
        "",
        "用法: \(help.usage)",
    ]
    if !help.options.isEmpty {
        lines.append("")
        lines.append("选项:")
        lines.append(contentsOf: help.options.map { "  \($0.0.padding(toLength: 34, withPad: " ", startingAt: 0))\($0.1)" })
    }
    lines.append("")
    lines.append("  --language, --lang <language>     人读输出语言：en 或 zh")
    lines.append("  --version                         显示版本。")
    lines.append("  -h, --help                        显示帮助信息。")
    return lines.joined(separator: "\n")
}

func chineseCommandHelps() -> [String: ChineseCommandHelp] {
    let hostPort = [
        ("--host <host>", "服务 host，默认 127.0.0.1"),
        ("--port <port>", "服务端口，默认 19421"),
    ]
    let target = [("--target <target>", "目标 id，来自 `triton list`；只有一个目标时可省略")]
    let formatTextJSON = [("--format <format>", "输出格式：text 或 json"), ("--json", "等价于 --format json")]
    return [
        "serve": ChineseCommandHelp(name: "serve", overview: "启动本地控制服务。", usage: "triton serve [--host <host>] [--port <port>]", options: [
            ("--host <host>", "监听 host，默认 0.0.0.0"),
            ("--port <port>", "监听端口，默认 19421"),
        ]),
        "version": ChineseCommandHelp(name: "version", overview: "输出 Triton CLI 版本和启动默认值。", usage: "triton version [--format <format>] [--json]", options: formatTextJSON),
        "status": ChineseCommandHelp(name: "status", overview: "读取本地 TritonKit 服务状态。", usage: "triton status [选项]", options: hostPort + formatTextJSON),
        "doctor": ChineseCommandHelp(name: "doctor", overview: "诊断服务、目标和运行时能力。", usage: "triton doctor [选项]", options: hostPort + formatTextJSON),
        "capabilities": ChineseCommandHelp(name: "capabilities", overview: "输出运行时能力矩阵。", usage: "triton capabilities [选项]", options: hostPort + formatTextJSON),
        "schema": ChineseCommandHelp(name: "schema", overview: "输出机器可读命令 schema 和示例。", usage: "triton schema [--command <command>] [--format <format>] [--json]", options: [
            ("--command <command>", "筛选单个命令，例如 input 或 tap"),
        ] + formatTextJSON),
        "plan": ChineseCommandHelp(name: "plan", overview: "根据当前服务和目标状态输出推荐下一步。", usage: "triton plan [选项]", options: hostPort + formatTextJSON),
        "list": ChineseCommandHelp(name: "list", overview: "列出已连接的 TritonKit 目标。", usage: "triton list [选项]", options: hostPort + formatTextJSON + [
            ("--name-contains <text>", "按 App 名称片段过滤"),
            ("--bundle-id <id>", "按 bundle id 过滤"),
            ("--ids-only", "只输出 target id"),
        ]),
        "inspect": ChineseCommandHelp(name: "inspect", overview: "查看单个 TritonKit 目标摘要。", usage: "triton inspect [选项]", options: target + hostPort + formatTextJSON),
        "hierarchy": ChineseCommandHelp(name: "hierarchy", overview: "读取目标最新视图层级。", usage: "triton hierarchy [选项]", options: target + hostPort + [
            ("--format <format>", "输出格式：tree 或 json"),
            ("--json", "等价于 --format json"),
            ("--output <path>", "写入文件"),
            ("--refresh/--no-refresh", "读取前是否刷新层级"),
            ("--hide-noise/--no-hide-noise", "tree 输出是否隐藏无效 UIKit 包装视图"),
        ]),
        "ax": ChineseCommandHelp(name: "ax", overview: "读取 App 内安全可操作控件索引。", usage: "triton ax [选项]", options: target + hostPort + formatTextJSON + [
            ("--with-hierarchy", "把 AX 节点按 viewOID 映射到 hierarchy 节点"),
            ("--refresh/--no-refresh", "映射 hierarchy 前是否刷新层级"),
            ("--output <path>", "写入文件"),
        ]),
        "find": ChineseCommandHelp(name: "find", overview: "把可见文本、label、identifier 或选项标题解析为可操作目标。", usage: "triton find <文本> [选项]", options: target + hostPort + formatTextJSON + [
            ("<文本>", "要解析的用户意图，例如 HTTP"),
        ]),
        "tap": ChineseCommandHelp(name: "tap", overview: "点击文本、坐标、view oid 或 AX 节点。", usage: "triton tap [文本] [选项]", options: target + hostPort + formatTextJSON + [
            ("<文本>", "要点击的可见文本、label、identifier 或选项标题，例如 HTTP"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
            ("--oid <oid>", "hierarchy view oid"),
            ("--ax-oid <oid>", "`triton ax` 输出的 targetOID/viewOID"),
            ("--ax-label <label>", "`triton ax` 输出的精确 label，优先按 AX oid 点击"),
            ("--duration <seconds>", "按住时长"),
        ]),
        "input": ChineseCommandHelp(name: "input", overview: "从 stdin 读取 NDJSON 输入动作。", usage: "triton input [选项] < gestures.ndjson", options: target + hostPort + formatTextJSON + [
            ("--fail-fast", "首个失败动作后停止"),
            ("--summary", "输出最终批次 summary"),
            ("--strict", "任一动作失败时以非 0 退出"),
        ]),
    ]
}


struct Version: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print Triton CLI version and bootstrap defaults")

    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() throws {
        let language = effectiveLanguage(localization.language)
        let response = TKCLIVersionResponse(version: tritonCLIVersion, language: language.rawValue)
        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(response))
        case .text:
            switch language {
            case .en:
                print(response.version)
            case .zh:
                print("版本: \(response.version)")
            }
        }
    }
}

struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read local TritonKit server status")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let client = TritonKitHTTPClient(host: host, port: port)
        let outputFormat = effectiveFormat(format, json: json)
        let language = effectiveLanguage(localization.language)
        do {
            let status: TKStatusResponse = try await client.getJSON("/status")
            switch outputFormat {
            case .json:
                print(try encodeJSON(TKCLIStatusEnvelope(
                    ok: true,
                    serverReachable: true,
                    connected: status.connected,
                    latestHierarchyAvailable: status.latestHierarchyAvailable,
                    targetCount: status.targetCount,
                    runtime: status.connected ? "embedded" : "none"
                )))
            case .text:
                switch language {
                case .en:
                    print("connected: \(status.connected)")
                    print("latestHierarchyAvailable: \(status.latestHierarchyAvailable)")
                    print("targetCount: \(status.targetCount)")
                case .zh:
                    print("已连接: \(status.connected)")
                    print("已有最新层级: \(status.latestHierarchyAvailable)")
                    print("目标数量: \(status.targetCount)")
                }
            }
        } catch {
            if outputFormat == .json {
                try printCLIError(error, endpoint: "/status", host: host, port: port)
                throw ExitCode.failure
            }
            printCLIErrorText(error, endpoint: "/status", host: host, port: port, language: language)
            throw ExitCode.failure
        }
    }
}

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Diagnose server, target, and runtime capabilities")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let response = await buildCapabilities(host: host, port: port)
        try printCapabilities(response, format: effectiveFormat(format, json: json), language: effectiveLanguage(localization.language))
    }
}

struct Capabilities: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print machine-readable Triton runtime capabilities")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let response = await buildCapabilities(host: host, port: port)
        try printCapabilities(response, format: effectiveFormat(format, json: json), language: effectiveLanguage(localization.language))
    }
}

struct Schema: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print machine-readable command schemas and examples")

    @Option(help: "Command name to filter, for example tap or export") var command: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let commands = commandSchemas()
        let filtered: [TKCommandSchema]
        if let command {
            filtered = commands.filter { $0.name == command }
            guard !filtered.isEmpty else {
                throw RuntimeError("Unknown command schema: \(command)")
            }
        } else {
            filtered = commands
        }
        let response = TKCLISchemaResponse(commands: filtered)
        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print(renderSchema(response, language: effectiveLanguage(localization.language)))
        }
    }
}

struct Plan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print recommended next CLI steps for the current runtime state")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let capabilities = await buildCapabilities(host: host, port: port)
        let plan = buildWorkflowPlan(capabilities: capabilities, host: host, port: port)
        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(plan))
        case .text:
            print(renderWorkflowPlan(plan, language: effectiveLanguage(localization.language)))
        }
    }
}

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List connected TritonKit targets")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Filter by app name substring") var nameContains: String?
    @Option(help: "Filter by bundle identifier") var bundleID: String?
    @Flag(help: "Print only target ids") var idsOnly = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let client = TritonKitHTTPClient(host: host, port: port)
        let language = effectiveLanguage(localization.language)
        let response: TKTargetsResponse
        do {
            response = try await client.getJSON("/targets")
        } catch {
            let outputFormat = effectiveFormat(format, json: json)
            if outputFormat == .json {
                try printCLIError(error, endpoint: "/targets", host: host, port: port)
                throw ExitCode.failure
            }
            printCLIErrorText(error, endpoint: "/targets", host: host, port: port, language: language)
            throw ExitCode.failure
        }
        let targets = filter(response.targets)

        if idsOnly {
            for target in targets {
                print(target.id)
            }
            return
        }

        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(TKTargetsResponse(targets: targets)))
        case .text:
            if targets.isEmpty {
                switch language {
                case .en:
                    print("No connected TritonKit targets")
                case .zh:
                    print("没有已连接的 TritonKit 目标")
                }
            } else {
                for target in targets {
                    print(renderTargetLine(target))
                }
            }
        }
    }

    private func filter(_ targets: [TKTargetSummary]) -> [TKTargetSummary] {
        targets.filter { target in
            if let nameContains,
               target.appName?.range(of: nameContains, options: .caseInsensitive) == nil {
                return false
            }
            if let bundleID, target.bundleIdentifier != bundleID {
                return false
            }
            return true
        }
    }
}

struct Inspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Inspect one TritonKit target")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let summary = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        switch outputFormat {
        case .json:
            print(try encodeJSON(summary))
        case .text:
            print("id: \(summary.id)")
            print("transport: \(summary.transport)")
            print("connected: \(summary.connected)")
            print("latestHierarchyAvailable: \(summary.latestHierarchyAvailable)")
            print("appName: \(summary.appName ?? "-")")
            print("bundleIdentifier: \(summary.bundleIdentifier ?? "-")")
            print("device: \(summary.deviceDescription ?? "-")")
            print("os: \(summary.osDescription ?? "-")")
        }
    }
}

struct Hierarchy: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Fetch the latest hierarchy from a TritonKit target")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: tree or json") var format: HierarchyOutputFormat = .tree
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Write output to a file instead of stdout") var output: String?
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before reading the latest snapshot")
    var refresh = true
    @Flag(inversion: .prefixedNo, help: "Hide low-signal UIKit wrapper views in tree output")
    var hideNoise = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        if refresh {
            try await client.sendCommand("hierarchy")
        }
        let data = try await waitForHierarchy(client: client)
        let rendered: String
        switch outputFormat {
        case .json:
            rendered = try prettyJSON(data)
        case .tree:
            rendered = try renderHierarchyTree(data, hideNoise: hideNoise)
        }
        try writeOrPrint(rendered, output: output)
    }
}

struct Nodes: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List nodes from the latest hierarchy snapshot")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before listing nodes")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        if refresh {
            try await client.sendCommand("hierarchy")
        }
        let data = try await waitForHierarchy(client: client)
        let nodes = try hierarchyNodeSummaries(data)
        switch outputFormat {
        case .json:
            print(try encodeJSONObject(["nodes": nodes]))
        case .text:
            for node in nodes {
                print(renderNodeLine(node))
            }
        }
    }
}

struct Node: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Inspect one hierarchy node from the latest snapshot")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "View or layer oid from `triton nodes`") var oid: UInt
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before reading the node")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        if refresh {
            try await client.sendCommand("hierarchy")
        }
        let data = try await waitForHierarchy(client: client)
        guard let node = try hierarchyNodeSummaries(data).first(where: { nodeMatches($0, oid: oid) }) else {
            throw RuntimeError("Node not found: \(oid)")
        }
        switch outputFormat {
        case .json:
            print(try encodeJSONObject(node))
        case .text:
            print("oid: \(node["oid"] ?? "-")")
            print("viewOid: \(node["viewOid"] ?? "-")")
            print("layerOid: \(node["layerOid"] ?? "-")")
            print("className: \(node["className"] ?? "-")")
            print("depth: \(node["depth"] ?? "-")")
            print("frame: \(node["frame"] ?? "-")")
            print("hidden: \(node["hidden"] ?? "-")")
            print("alpha: \(node["alpha"] ?? "-")")
        }
    }
}

struct Attrs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Fetch live attribute groups for a node layer oid")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Layer oid from `triton nodes`") var oid: UInt
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        let payload = try JSONEncoder().encode(oid)
        let data = try await client.request(type: "allAttrGroups", payload: payload)
        switch outputFormat {
        case .json:
            print(try prettyJSON(data))
        case .text:
            let groups = try JSONDecoder().decode([TKAttributesGroup].self, from: data)
            print(renderAttributeGroups(groups))
        }
    }
}

struct ObjectInfo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "object",
        abstract: "Fetch live object metadata for a view or layer oid"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Object oid from `triton nodes`") var oid: UInt
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        let payload = try JSONEncoder().encode(oid)
        let data = try await client.request(type: "fetchObject", payload: payload)
        switch outputFormat {
        case .json:
            print(try prettyJSON(data))
        case .text:
            let object = try JSONDecoder().decode(TKObject.self, from: data)
            print("oid: \(object.oid)")
            print("address: \(object.memoryAddress)")
            print("class: \(object.rawClassName)")
            print("classChain: \(object.classChainList.joined(separator: " -> "))")
        }
    }
}

struct Export: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export a reusable hierarchy snapshot or archive")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output file path") var output: String
    @Option(help: "Export format: auto, json, or archive") var format: ExportOutputFormat = .auto
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before exporting")
    var refresh = true

    func run() async throws {
        let resolvedFormat = try resolveExportFormat(effectiveFormat(format, json: json), output: output)
        let targetSummary = try await resolveTarget(
            target,
            host: host,
            port: port,
            jsonError: json || resolvedFormat == .json
        )
        let client = TritonKitHTTPClient(host: host, port: port)
        if refresh {
            try await client.sendCommand("hierarchy")
        }
        let hierarchyData = try await waitForHierarchy(client: client)
        let data: Data
        switch resolvedFormat {
        case .json, .auto:
            data = hierarchyData
        case .archive:
            let archive = try await buildExportArchive(
                target: targetSummary,
                hierarchyData: hierarchyData,
                client: client
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            data = try encoder.encode(archive)
        }
        try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        print(output)
    }
}

struct Find: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Resolve a UI target by visible text, label, identifier, or option title")

    @Argument(help: "Text, label, identifier, or visible option title to resolve") var query: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let resolution = try await resolveTapTarget(query, client: client, width: nil, height: nil, duration: nil)
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
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Tap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Tap a UI target by text, coordinate, oid, or AX node")

    @Argument(help: "Text, label, identifier, or visible option title to tap") var query: String?
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Window x coordinate in points") var x: Double?
    @Option(help: "Window y coordinate in points") var y: Double?
    @Option(help: "View oid from `triton nodes`") var oid: UInt?
    @Option(name: .customLong("ax-oid"), help: "AX target/view oid from `triton ax`") var axOID: UInt?
    @Option(name: .customLong("ax-label"), help: "Exact AX label to tap by AX target/view oid") var axLabel: String?
    @Option(help: "Optional screen/window width in points") var width: Double?
    @Option(help: "Optional screen/window height in points") var height: Double?
    @Option(help: "Hold duration in seconds") var duration: Double?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let selectorCount = [
            query != nil,
            oid != nil,
            x != nil || y != nil,
            axOID != nil,
            axLabel != nil,
        ].filter { $0 }.count
        guard selectorCount == 1 else {
            if effectiveFormat(format, json: json) == .json {
                try printValidationError("Provide exactly one target selector: <query>, --oid, --x/--y, --ax-oid, or --ax-label")
                throw ExitCode.failure
            }
            throw RuntimeError("Provide exactly one target selector: <query>, --oid, --x/--y, --ax-oid, or --ax-label")
        }
        if (x == nil) != (y == nil) {
            if outputFormat == .json {
                try printValidationError("--x and --y must be provided together")
                throw ExitCode.failure
            }
            throw RuntimeError("--x and --y must be provided together")
        }

        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            if let query {
                let client = TritonKitHTTPClient(host: host, port: port)
                let resolution = try await resolveTapTarget(query, client: client, width: width, height: height, duration: duration)
                try await runInputRequest(resolution.request, host: host, port: port, format: outputFormat)
                return
            }

            if axOID != nil || axLabel != nil {
                let client = TritonKitHTTPClient(host: host, port: port)
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
            let request = tapRequest(for: node, width: width, height: height, duration: duration)
            try await runInputRequest(request, host: host, port: port, format: outputFormat)
            return
        }

            let request = TKInputRequest.tap(
                x: x,
                y: y,
                targetOID: oid,
                width: width,
                height: height,
                duration: duration
            )
            try await runInputRequest(request, host: host, port: port, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Swipe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Swipe inside the app using window-point coordinates")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
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
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let request = TKInputRequest.swipe(
                startX: startX,
                startY: startY,
                endX: endX,
                endY: endY,
                width: width,
                height: height,
                duration: duration
            )
            try await runInputRequest(request, host: host, port: port, format: outputFormat)
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct TypeText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text into a focused or oid-targeted UIKeyInput"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Text to insert") var text: String
    @Option(help: "Optional responder oid from `triton nodes`") var oid: UInt?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest.typeText(text, targetOID: oid),
                host: host,
                port: port,
                format: outputFormat
            )
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Press: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Press a device button when supported by the active runtime")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Button name, for example home, lock, power, volume-up") var button: String
    @Option(help: "Hold duration in seconds") var duration: Double?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest.press(button: button, duration: duration),
                host: host,
                port: port,
                format: outputFormat
            )
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Geometry: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read current window geometry")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
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

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(name: .customLong("with-hierarchy"), help: "Join AX nodes to latest hierarchy by view oid") var withHierarchy = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before joining with --with-hierarchy") var refresh = true
    @Option(help: "Write output to a file instead of stdout") var output: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
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

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Window x coordinate in points") var x: Double
    @Option(help: "Window y coordinate in points") var y: Double

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let payload = try JSONEncoder().encode(TKHitTestRequest(x: x, y: y))
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

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output PNG file path") var output: String
    @Flag(help: "Print screenshot metadata as JSON after writing the file") var metadata = false
    @Flag(name: .customLong("json"), help: "Alias for --metadata") var json = false

    func run() async throws {
        let outputFormat: ClientOutputFormat = metadata || json ? .json : .text
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
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

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Stop on the first failed action") var failFast = false
    @Flag(help: "Print a final JSON batch summary") var summary = false
    @Flag(help: "Exit non-zero when any action fails") var strict = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
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

final class ConnectionState: @unchecked Sendable {
    private let lock = NSLock()
    private var _outbound: WebSocketOutboundWriter?
    func set(_ w: WebSocketOutboundWriter?) { lock.withLock { _outbound = w } }
    var outbound: WebSocketOutboundWriter? { lock.withLock { _outbound } }
    var isConnected: Bool { lock.withLock { _outbound != nil } }
}

final class MessageCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
}

struct TargetMetadata: Sendable {
    var appName: String?
    var bundleIdentifier: String?
    var deviceDescription: String?
    var osDescription: String?
}

final class TargetState: @unchecked Sendable {
    private let lock = NSLock()
    private var _latestHierarchy: Data?
    private var metadata = TargetMetadata()
    private var responses: [Int: Data] = [:]

    var latestHierarchy: Data? {
        lock.withLock { _latestHierarchy }
    }

    func setLatestHierarchy(_ data: Data) {
        let appInfo = extractAppInfo(fromHierarchy: data)
        lock.withLock {
            _latestHierarchy = data
            if let appInfo {
                metadata = appInfo
            }
        }
    }

    func setLatestAppInfo(_ data: Data) {
        guard let appInfo = extractAppInfo(fromAppInfoPayload: data) else { return }
        lock.withLock {
            metadata = appInfo
        }
    }

    func summary(connected: Bool) -> TKTargetSummary? {
        guard connected else { return nil }
        return lock.withLock {
            TKTargetSummary(
                connected: true,
                latestHierarchyAvailable: _latestHierarchy != nil,
                appName: metadata.appName,
                bundleIdentifier: metadata.bundleIdentifier,
                deviceDescription: metadata.deviceDescription,
                osDescription: metadata.osDescription
            )
        }
    }

    func storeResponse(id: Int, payload: Data) {
        lock.withLock {
            responses[id] = payload
        }
    }

    func waitForResponse(id: Int, attempts: Int = 25) async -> Data? {
        for _ in 0..<attempts {
            if let data = lock.withLock({ responses.removeValue(forKey: id) }) {
                return data
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    private func extractAppInfo(fromHierarchy data: Data) -> TargetMetadata? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let appInfo = json["appInfo"] as? [String: Any] else {
            return nil
        }
        return extractMetadata(from: appInfo)
    }

    private func extractAppInfo(fromAppInfoPayload data: Data) -> TargetMetadata? {
        guard let appInfo = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return extractMetadata(from: appInfo)
    }

    private func extractMetadata(from appInfo: [String: Any]) -> TargetMetadata {
        TargetMetadata(
            appName: appInfo["appName"] as? String,
            bundleIdentifier: appInfo["appBundleIdentifier"] as? String,
            deviceDescription: appInfo["deviceDescription"] as? String,
            osDescription: appInfo["osDescription"] as? String
        )
    }
}

/// Thread-safe binary data store keyed by UUID
final class DataStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: Data] = [:]

    func put(_ data: Data) -> UUID {
        let id = UUID()
        lock.withLock { storage[id] = data }
        return id
    }

    func get(_ id: UUID) -> Data? {
        lock.withLock { storage[id] }
    }
}

func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) -> Response {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(value) else {
        return Response(status: .internalServerError)
    }
    return Response(status: status, headers: [.contentType: "application/json"],
                    body: .init(byteBuffer: ByteBuffer(data: data)))
}

func jsonError(_ message: String, status: HTTPResponse.Status) -> Response {
    jsonError(code: "request_failed", message: message, status: status)
}

func jsonError(
    code: String,
    message: String,
    endpoint: String? = nil,
    hint: String? = nil,
    status: HTTPResponse.Status
) -> Response {
    jsonResponse(
        TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: code,
            message: message,
            endpoint: endpoint,
            hint: hint
        )),
        status: status
    )
}

func jsonError(detail: TKCLIErrorDetail, status: HTTPResponse.Status) -> Response {
    jsonResponse(TKCLIErrorResponse(error: detail), status: status)
}

struct TritonKitHTTPClient {
    let host: String
    let port: Int

    func getData(_ path: String) async throws -> Data {
        try await data(for: URLRequest(url: url(path)))
    }

    func getJSON<T: Decodable>(_ path: String) async throws -> T {
        let data = try await getData(path)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func postJSON<Request: Encodable, Response: Decodable>(_ path: String, body: Request) async throws -> Response {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await data(for: request)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func sendCommand(_ type: String) async throws {
        let _: TKCLICommandResponse = try await postJSON("/command", body: TKCLICommandRequest(type: type))
    }

    func request(type: String, payload: Data? = nil) async throws -> Data {
        try await postRawJSON("/request", body: TKCLICommandRequest(type: type, payload: payload))
    }

    private func url(_ path: String) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        return components.url!
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RuntimeError("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CLIHTTPError(statusCode: http.statusCode, data: data)
        }
        return data
    }

    private func postRawJSON<Request: Encodable>(_ path: String, body: Request) async throws -> Data {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await data(for: request)
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

struct CLIHTTPError: Error, CustomStringConvertible {
    let statusCode: Int
    let data: Data
    let response: TKCLIErrorResponse?

    init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
        self.response = try? JSONDecoder().decode(TKCLIErrorResponse.self, from: data)
    }

    var description: String {
        if let response {
            return "HTTP \(statusCode) \(response.error.code): \(response.error.message)"
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return "HTTP \(statusCode) \(body)"
    }
}

struct RuntimeRequestTimeoutError: Error, CustomStringConvertible {
    let requestType: String

    var description: String {
        "Timed out waiting for \(requestType) response"
    }
}

func resolveTarget(_ target: String, host: String, port: Int) async throws -> TKTargetSummary {
    let client = TritonKitHTTPClient(host: host, port: port)
    let response: TKTargetsResponse = try await client.getJSON("/targets")
    return try TKResolveTargetSummary(target, in: response.targets)
}

func resolveTarget(
    _ target: String,
    host: String,
    port: Int,
    jsonError: Bool
) async throws -> TKTargetSummary {
    do {
        return try await resolveTarget(target, host: host, port: port)
    } catch {
        if jsonError {
            try printCLIError(error, endpoint: "/targets", host: host, port: port)
            throw ExitCode.failure
        }
        printCLIErrorText(error, endpoint: "/targets", host: host, port: port, language: effectiveLanguage(nil))
        throw ExitCode.failure
    }
}

func buildCapabilities(host: String, port: Int) async -> TKCapabilitiesResponse {
    let client = TritonKitHTTPClient(host: host, port: port)
    do {
        let status: TKStatusResponse = try await client.getJSON("/status")
        return TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: status.connected,
            latestHierarchyAvailable: status.latestHierarchyAvailable,
            targetCount: status.targetCount,
            runtime: status.connected ? "embedded" : "none",
            capabilities: runtimeCapabilities(connected: status.connected)
        )
    } catch {
        let detail = cliErrorDetail(for: error, endpoint: "/status", host: host, port: port)
        return TKCapabilitiesResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            latestHierarchyAvailable: false,
            targetCount: 0,
            runtime: "unknown",
            capabilities: runtimeCapabilities(connected: false),
            error: detail
        )
    }
}

func runtimeCapabilities(connected: Bool) -> [TKRuntimeCapability] {
    let requiresRuntime = connected ? nil : "Requires connected embedded TritonKit runtime"
    return [
        TKRuntimeCapability(name: "plan", supported: true),
        TKRuntimeCapability(name: "schema", supported: true),
        TKRuntimeCapability(name: "status", supported: true),
        TKRuntimeCapability(name: "list", supported: true),
        TKRuntimeCapability(name: "inspect", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hierarchy", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "nodes", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "node", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "attrs", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "object", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "export-json", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "export-archive", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "geometry", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "ax", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hit", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "screenshot", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "tap", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "swipe", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "type", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "input", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "press", supported: false, reason: "Host-side HID is not available in the embedded runtime"),
    ]
}

func printCapabilities(_ response: TKCapabilitiesResponse, format: ClientOutputFormat, language: CLILanguage = effectiveLanguage(nil)) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        switch language {
        case .en:
            print("ok: \(response.ok)")
            print("serverReachable: \(response.serverReachable)")
            print("connected: \(response.connected)")
            print("latestHierarchyAvailable: \(response.latestHierarchyAvailable)")
            print("targetCount: \(response.targetCount)")
            print("runtime: \(response.runtime)")
        case .zh:
            print("正常: \(response.ok)")
            print("服务可达: \(response.serverReachable)")
            print("已连接: \(response.connected)")
            print("已有最新层级: \(response.latestHierarchyAvailable)")
            print("目标数量: \(response.targetCount)")
            print("运行时: \(response.runtime)")
        }
        if let error = response.error {
            switch language {
            case .en:
                print("error: \(error.code) \(error.message)")
            case .zh:
                print("错误: \(localizedErrorMessage(error, language: language))")
            }
            if let hint = error.hint {
                switch language {
                case .en:
                    print("hint: \(hint)")
                case .zh:
                    print("提示: \(localizedHint(error, fallback: hint, language: language))")
                }
            }
        }
        print(language == .zh ? "能力:" : "capabilities:")
        for capability in response.capabilities {
            let status = capability.supported
                ? (language == .zh ? "支持" : "supported")
                : (language == .zh ? "不支持" : "unsupported")
            if let reason = capability.reason {
                print("  \(capability.name): \(status) (\(reason))")
            } else {
                print("  \(capability.name): \(status)")
            }
        }
    }
}

func buildWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    host: String,
    port: Int
) -> TKWorkflowPlanResponse {
    if !capabilities.serverReachable {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            runtime: capabilities.runtime,
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
                    command: "open the iOS app or run the simulator build that embeds TritonKit",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "triton status reports connected: true"
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

    if !capabilities.connected {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: true,
            connected: false,
            runtime: capabilities.runtime,
            nextStep: "connect-target",
            steps: [
                TKWorkflowPlanStep(
                    id: "connect-target",
                    title: "Launch an app with embedded TritonKit runtime",
                    command: "open the iOS app or run the simulator build that embeds TritonKit",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "WebSocket target connects to ws://\(host):\(port)/"
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
        nextStep: "observe",
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
                    command: "triton input --host \(host) --port \(port) --format json --summary --strict < gestures.ndjson",
                    requiresServer: true,
                    requiresTarget: true,
                    when: "after selecting safe actions",
                    expected: "Input results plus a final summary; non-zero exit when any action fails"
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

func printCLIError(_ error: Error, endpoint: String, host: String, port: Int) throws {
    let response = TKCLIErrorResponse(error: cliErrorDetail(
        for: error,
        endpoint: endpoint,
        host: host,
        port: port
    ))
    print(try encodeJSON(response))
}

func printCLIErrorText(_ error: Error, endpoint: String, host: String, port: Int, language: CLILanguage = effectiveLanguage(nil)) {
    let detail = cliErrorDetail(for: error, endpoint: endpoint, host: host, port: port)
    switch language {
    case .en:
        fputs("\(detail.code): \(detail.message)\n", stderr)
    case .zh:
        fputs("\(detail.code): \(localizedErrorMessage(detail, language: language))\n", stderr)
    }
    if let endpoint = detail.endpoint {
        fputs("\(language == .zh ? "端点" : "endpoint"): \(endpoint)\n", stderr)
    }
    if let hint = detail.hint {
        fputs("\(language == .zh ? "提示" : "hint"): \(localizedHint(detail, fallback: hint, language: language))\n", stderr)
    }
    if let nextAction = detail.nextAction {
        let command = (["triton", nextAction.command] + nextAction.args).joined(separator: " ")
        fputs("\(language == .zh ? "下一步" : "next"): \(command)\n", stderr)
    }
}

func failCommand(
    _ error: Error,
    outputFormat: ClientOutputFormat,
    endpoint: String,
    host: String,
    port: Int
) throws -> Never {
    switch outputFormat {
    case .json:
        if let httpError = error as? CLIHTTPError,
           let response = httpError.response {
            print(try encodeJSON(response))
        } else {
            try printCLIError(error, endpoint: endpoint, host: host, port: port)
        }
    case .text:
        printCLIErrorText(error, endpoint: endpoint, host: host, port: port)
    }
    throw ExitCode.failure
}

func localizedErrorMessage(_ detail: TKCLIErrorDetail, language: CLILanguage) -> String {
    guard language == .zh else { return "\(detail.code) \(detail.message)" }
    switch detail.code {
    case "server_unavailable":
        return "服务器不可用：无法连接到本地 Triton 服务。"
    case "request_failed":
        return "请求失败：\(detail.message)"
    case "validation_failed":
        return "参数校验失败：\(detail.message)"
    default:
        return "\(detail.code)：\(detail.message)"
    }
}

func localizedHint(_ detail: TKCLIErrorDetail, fallback: String, language: CLILanguage) -> String {
    guard language == .zh else { return fallback }
    switch detail.code {
    case "server_unavailable":
        return "运行 `triton serve --host 127.0.0.1 --port 19421` 并连接 iOS App"
    default:
        return fallback
    }
}

func printValidationError(_ message: String) throws {
    let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
        code: "validation_failed",
        message: message,
        hint: "Run `triton schema --command tap --json` to inspect required fields"
    ))
    print(try encodeJSON(response))
}

func cliErrorDetail(for error: Error, endpoint: String, host: String, port: Int) -> TKCLIErrorDetail {
    let url = endpointURL(endpoint, host: host, port: port)
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return response.error
    }
    if let urlError = error as? URLError {
        return TKCLIErrorDetail(
            code: "server_unavailable",
            message: urlError.localizedDescription,
            endpoint: url,
            hint: "Run `triton serve --host \(host) --port \(port)` and connect the iOS app",
            nextAction: TKCLINextAction(
                command: "serve",
                args: ["--host", host, "--port", "\(port)"],
                requiresLongRunningProcess: true
            )
        )
    }
    if let runtime = error as? RuntimeError {
        return TKCLIErrorDetail(
            code: "request_failed",
            message: runtime.description,
            endpoint: url,
            hint: "Check `triton doctor --format json` for server and target state"
        )
    }
    return TKCLIErrorDetail(
        code: "request_failed",
        message: "\(error)",
        endpoint: url,
        hint: "Check `triton doctor --format json` for server and target state"
    )
}

func endpointURL(_ endpoint: String, host: String, port: Int) -> String {
    "http://\(host):\(port)\(endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)")"
}

func renderTargetLine(_ target: TKTargetSummary) -> String {
    [
        target.id,
        target.transport,
        target.appName ?? "-",
        target.bundleIdentifier ?? "-",
        target.deviceDescription ?? "-",
        target.osDescription ?? "-",
    ].joined(separator: "\t")
}

func commandSchemas() -> [TKCommandSchema] {
    let hostPort = [
        TKCommandSchemaOption(name: "--host", type: "String", defaultValue: "127.0.0.1", description: "Triton server host"),
        TKCommandSchemaOption(name: "--port", type: "Int", defaultValue: "19421", description: "Triton server port"),
    ]
    let target = TKCommandSchemaOption(name: "--target", type: "String", defaultValue: TKLocalTargetID, description: "Target id from `triton list`; commands auto-select the only connected target when omitted")
    let jsonText = ["text", "json"]
    let formatTextJSON = TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format")
    let jsonAlias = TKCommandSchemaOption(name: "--json", type: "Bool", defaultValue: "false", description: "Alias for --format json")
    let languageOption = TKCommandSchemaOption(name: "--language/--lang", type: "en|zh", defaultValue: "TRITON_LANGUAGE or en", description: "Human-readable output language")
    let metadataJSONAlias = TKCommandSchemaOption(name: "--json", type: "Bool", defaultValue: "false", description: "Alias for --metadata")
    let refreshOption = TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before reading")
    return [
        TKCommandSchema(
            name: "version",
            summary: "Print Triton CLI version and bootstrap defaults",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 0,
            outputFormats: jsonText,
            options: [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton version --format json"],
            successShape: "{ ok, version, schemaVersion, defaultHost, defaultPort, language, supportedLanguages }"
        ),
        TKCommandSchema(
            name: "serve",
            summary: "Start the local WebSocket and HTTP control server",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli-long-running",
            exitCodeOnFailure: 1,
            outputFormats: ["logs"],
            options: [
                TKCommandSchemaOption(name: "--host", type: "String", defaultValue: "0.0.0.0", description: "Host to bind to"),
                TKCommandSchemaOption(name: "--port", type: "Int", defaultValue: "19421", description: "Port to listen on"),
            ],
            examples: ["triton serve --host 127.0.0.1 --port 19421"],
            successShape: "Long-running process; exposes /status, /targets, /request, /input, /hierarchy/latest and WebSocket /"
        ),
        TKCommandSchema(
            name: "status",
            summary: "Read local TritonKit server status",
            requiresServer: true,
            requiresTarget: false,
            runtimeScope: "cli",
            outputFormats: jsonText,
            options: hostPort + [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton status --format json"],
            successShape: "{ ok, serverReachable, connected, latestHierarchyAvailable, targetCount, runtime }",
            failureShape: "{ ok: false, error: { code, message, endpoint, hint, nextAction? } }"
        ),
        TKCommandSchema(
            name: "doctor",
            summary: "Diagnose server, target, and runtime capabilities",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 0,
            outputFormats: jsonText,
            options: hostPort + [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton doctor --format json"],
            successShape: "{ ok, serverReachable, connected, latestHierarchyAvailable, runtime, capabilities, error? }"
        ),
        TKCommandSchema(
            name: "plan",
            summary: "Print recommended next CLI steps for the current runtime state",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 0,
            outputFormats: jsonText,
            options: hostPort + [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton plan --format json", "triton plan --format text"],
            successShape: "{ ok, serverReachable, connected, runtime, nextStep, steps[], error? }",
            failureShape: nil,
            providedCapabilities: ["plan"]
        ),
        TKCommandSchema(
            name: "capabilities",
            summary: "Print runtime capability matrix",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 0,
            outputFormats: jsonText,
            options: hostPort + [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton capabilities --format json"],
            successShape: "{ ok, serverReachable, connected, runtime, capabilities[] }"
        ),
        TKCommandSchema(
            name: "schema",
            summary: "Print machine-readable command schemas and examples",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 1,
            outputFormats: jsonText,
            options: [
                TKCommandSchemaOption(name: "--command", type: "String", description: "Optional command name to filter"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
                languageOption,
            ],
            examples: ["triton schema --json", "triton schema --command input --json"],
            successShape: "{ schemaVersion, commands[] }"
        ),
        TKCommandSchema(
            name: "list",
            summary: "List connected Triton targets",
            requiresServer: true,
            requiresTarget: false,
            runtimeScope: "cli",
            outputFormats: jsonText,
            options: hostPort + [
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"),
                jsonAlias,
                languageOption,
                TKCommandSchemaOption(name: "--ids-only", type: "Bool", defaultValue: "false", description: "Print only target ids"),
            ],
            examples: ["triton list --format json", "triton list --ids-only"],
            successShape: "{ targets: [{ id, transport, connected, appName, bundleIdentifier, deviceDescription, osDescription }] }"
        ),
        TKCommandSchema(
            name: "inspect",
            summary: "Inspect one Triton target summary",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "cli",
            outputFormats: jsonText,
            options: hostPort + [target, formatTextJSON, jsonAlias],
            examples: ["triton inspect --target triton:local --format json"],
            successShape: "{ id, transport, connected, latestHierarchyAvailable, appName, bundleIdentifier, deviceDescription, osDescription }"
        ),
        TKCommandSchema(
            name: "hierarchy",
            summary: "Read latest hierarchy snapshot",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: ["tree", "json"],
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--format", type: "tree|json", defaultValue: "tree", description: "Output format"),
                jsonAlias,
                TKCommandSchemaOption(name: "--output", type: "Path", description: "Optional output file"),
                TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before reading"),
                TKCommandSchemaOption(name: "--hide-noise/--no-hide-noise", type: "Bool", defaultValue: "true", description: "Hide low-signal UIKit wrapper views in tree output"),
            ],
            examples: ["triton hierarchy --target triton:local --format json --output /tmp/hierarchy.json"],
            successShape: "TKHierarchyInfo JSON or rendered tree"
        ),
        TKCommandSchema(
            name: "nodes",
            summary: "List node summaries from the latest hierarchy snapshot",
            requiresServer: true,
            requiresTarget: true,
            requiresHierarchy: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [target, formatTextJSON, jsonAlias, refreshOption],
            examples: ["triton nodes --target triton:local --format json"],
            successShape: "{ nodes: [{ oid, viewOid, layerOid, className, depth, frame, hidden, alpha }] }"
        ),
        TKCommandSchema(
            name: "node",
            summary: "Inspect one hierarchy node by view or layer oid",
            requiresServer: true,
            requiresTarget: true,
            requiresHierarchy: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--oid", type: "UInt", required: true, description: "View or layer oid from `triton nodes`"),
                formatTextJSON,
                jsonAlias,
                refreshOption,
            ],
            examples: ["triton node --target triton:local --oid 1 --format json"],
            successShape: "{ oid, viewOid, layerOid, className, depth, frame, hidden, alpha }"
        ),
        TKCommandSchema(
            name: "attrs",
            summary: "Fetch live attribute groups for a node layer oid",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--oid", type: "UInt", required: true, description: "Layer oid from `triton nodes`"),
                formatTextJSON,
                jsonAlias,
            ],
            examples: ["triton attrs --target triton:local --oid 2 --format json"],
            successShape: "[TKAttributesGroup]"
        ),
        TKCommandSchema(
            name: "object",
            summary: "Fetch live object metadata for a view or layer oid",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--oid", type: "UInt", required: true, description: "View or layer oid from `triton nodes`"),
                formatTextJSON,
                jsonAlias,
            ],
            examples: ["triton object --target triton:local --oid 1 --format json"],
            successShape: "{ oid, memoryAddress, rawClassName, classChainList }"
        ),
        TKCommandSchema(
            name: "export",
            summary: "Export hierarchy JSON or self-contained archive",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: ["auto", "json", "archive"],
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--output", type: "Path", required: true, description: "Output file path"),
                TKCommandSchemaOption(name: "--format", type: "auto|json|archive", defaultValue: "auto", description: "Export format"),
                jsonAlias,
                TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before exporting"),
            ],
            examples: [
                "triton export --output /tmp/triton-hierarchy.json",
                "triton export --format archive --output /tmp/triton-smoke.triton",
            ],
            successShape: "File path on stdout; output file contains hierarchy JSON or TKExportArchive JSON"
        ),
        TKCommandSchema(
            name: "find",
            summary: "Resolve a UI target by visible text, label, identifier, or option title",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<query>", type: "String", required: true, description: "Visible text, AX label, identifier, value, or option title to resolve"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                #"triton find "HTTP" --json"#,
            ],
            successShape: "TapTargetResolution describing source, strategy, ids, frame, and request"
        ),
        TKCommandSchema(
            name: "ax",
            summary: "Read safe actionable control index",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"),
                jsonAlias,
                TKCommandSchemaOption(name: "--with-hierarchy", type: "Bool", defaultValue: "false", description: "Join AX nodes to hierarchy viewObject.oid and expose layer oid/path/frame"),
                TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before joining with --with-hierarchy"),
                TKCommandSchemaOption(name: "--output", type: "Path", description: "Optional output file"),
            ],
            examples: [
                "triton ax --format json --output /tmp/ax.json",
                "triton ax --with-hierarchy --json",
            ],
            successShape: "[TKAXNode] by default; TKAXHierarchyMapResponse when --with-hierarchy is used"
        ),
        TKCommandSchema(
            name: "geometry",
            summary: "Read current window geometry",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [target, formatTextJSON, jsonAlias],
            examples: ["triton geometry --format json"],
            successShape: "{ bounds, safeArea, scale, orientation }"
        ),
        TKCommandSchema(
            name: "hit",
            summary: "Hit-test one window coordinate",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--x", type: "Double", required: true, description: "Window x coordinate in points"),
                TKCommandSchemaOption(name: "--y", type: "Double", required: true, description: "Window y coordinate in points"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"),
                jsonAlias,
            ],
            examples: ["triton hit --x 270 --y 300 --format json"],
            successShape: "{ x, y, centerX?, centerY?, node? }"
        ),
        TKCommandSchema(
            name: "screenshot",
            summary: "Capture current app screenshot",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: ["file", "json-metadata"],
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--output", type: "Path", required: true, description: "Output PNG path"),
                TKCommandSchemaOption(name: "--metadata", type: "Bool", defaultValue: "false", description: "Print JSON metadata after writing"),
                metadataJSONAlias,
            ],
            examples: ["triton screenshot --output /tmp/triton.png --metadata"],
            successShape: "{ format, width, height, scale, output, bytes } when --metadata is used"
        ),
        TKCommandSchema(
            name: "tap",
            summary: "Tap a UI target by text, coordinate, view oid, or AX node",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<query>", type: "String", description: "Visible text, AX label, identifier, value, or option title to tap"),
                TKCommandSchemaOption(name: "--x", type: "Double", description: "Window x coordinate"),
                TKCommandSchemaOption(name: "--y", type: "Double", description: "Window y coordinate"),
                TKCommandSchemaOption(name: "--oid", type: "UInt", description: "Target view oid"),
                TKCommandSchemaOption(name: "--ax-oid", type: "UInt", description: "AX target/view oid from `triton ax`; taps by runtime oid"),
                TKCommandSchemaOption(name: "--ax-label", type: "String", description: "Exact AX label from `triton ax`; taps by runtime oid"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                #"triton tap "HTTP" --json"#,
                "triton tap --x 270 --y 300 --format json",
                "triton tap --oid 13 --format json",
                "triton tap --ax-label Save --json",
            ],
            successShape: "{ ok, action, message, targetOID, targetClassName }"
        ),
        TKCommandSchema(
            name: "swipe",
            summary: "Swipe inside the app using window-point coordinates",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--start-x", type: "Double", required: true, description: "Start x coordinate in window points"),
                TKCommandSchemaOption(name: "--start-y", type: "Double", required: true, description: "Start y coordinate in window points"),
                TKCommandSchemaOption(name: "--end-x", type: "Double", required: true, description: "End x coordinate in window points"),
                TKCommandSchemaOption(name: "--end-y", type: "Double", required: true, description: "End y coordinate in window points"),
                TKCommandSchemaOption(name: "--width", type: "Double", description: "Optional screen/window width in points"),
                TKCommandSchemaOption(name: "--height", type: "Double", description: "Optional screen/window height in points"),
                TKCommandSchemaOption(name: "--duration", type: "Double", description: "Gesture duration in seconds"),
                formatTextJSON,
                jsonAlias,
            ],
            examples: ["triton swipe --start-x 350 --start-y 390 --end-x 100 --end-y 390 --format json"],
            successShape: "{ ok, action, message, targetOID, targetClassName }",
            providedCapabilities: ["swipe"]
        ),
        TKCommandSchema(
            name: "type",
            summary: "Type text into a focused or oid-targeted UIKeyInput",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--text", type: "String", required: true, description: "Text to insert"),
                TKCommandSchemaOption(name: "--oid", type: "UInt", description: "Optional responder oid from `triton nodes`"),
                formatTextJSON,
                jsonAlias,
            ],
            examples: ["triton type --text hello --format json"],
            successShape: "{ ok, action, message, targetOID, targetClassName }",
            providedCapabilities: ["type"]
        ),
        TKCommandSchema(
            name: "press",
            summary: "Press a device button when supported by the active runtime",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--button", type: "String", required: true, description: "Button name, for example home"),
                TKCommandSchemaOption(name: "--duration", type: "Double", description: "Hold duration in seconds"),
                formatTextJSON,
                jsonAlias,
            ],
            examples: ["triton press --button home --format json"],
            successShape: "{ ok: false, action, message } in embedded runtime",
            providedCapabilities: ["press"]
        ),
        TKCommandSchema(
            name: "input",
            summary: "Run newline-delimited JSON actions from stdin",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
                TKCommandSchemaOption(name: "--fail-fast", type: "Bool", defaultValue: "false", description: "Stop on first failed action"),
                TKCommandSchemaOption(name: "--summary", type: "Bool", defaultValue: "false", description: "Print a final JSON batch summary"),
                TKCommandSchemaOption(name: "--strict", type: "Bool", defaultValue: "false", description: "Exit non-zero when any action fails"),
            ],
            examples: [
                #"printf '%s\n' '{"type":"tap","x":270,"y":300}' '{"type":"type","text":"hello"}' | triton input --format json --summary --strict"#,
            ],
            successShape: "One TKInputResult JSON object per input line; with --summary, final { ok, actionCount, failedCount }",
            inputActions: inputActionSchemas(),
            providedCapabilities: ["tap", "swipe", "type", "press"]
        ),
    ]
}

func inputActionSchemas() -> [TKInputActionSchema] {
    [
        TKInputActionSchema(
            type: "tap",
            requiredFields: ["type"],
            optionalFields: ["x", "y", "targetOID", "width", "height", "duration"],
            oneOfRequired: [["x", "y"], ["targetOID"]],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["tap"], "Action discriminator"),
                inputField("x", "Double", "Window x coordinate in points; required with y unless targetOID is used"),
                inputField("y", "Double", "Window y coordinate in points; required with x unless targetOID is used"),
                inputField("targetOID", "UInt", "View oid from hierarchy/ax/hit; alternative to x/y"),
                inputField("width", "Double", "Optional window width in points for caller bookkeeping"),
                inputField("height", "Double", "Optional window height in points for caller bookkeeping"),
                inputField("duration", "Double", "Optional hold duration in seconds"),
            ],
            example: #"{"type":"tap","x":270,"y":300}"#
        ),
        TKInputActionSchema(
            type: "swipe",
            requiredFields: ["type", "startX", "startY", "endX", "endY"],
            optionalFields: ["width", "height", "duration"],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["swipe"], "Action discriminator"),
                inputField("startX", "Double", required: true, "Start x coordinate in window points"),
                inputField("startY", "Double", required: true, "Start y coordinate in window points"),
                inputField("endX", "Double", required: true, "End x coordinate in window points"),
                inputField("endY", "Double", required: true, "End y coordinate in window points"),
                inputField("width", "Double", "Optional window width in points for caller bookkeeping"),
                inputField("height", "Double", "Optional window height in points for caller bookkeeping"),
                inputField("duration", "Double", "Optional gesture duration in seconds"),
            ],
            example: #"{"type":"swipe","startX":350,"startY":390,"endX":100,"endY":390}"#
        ),
        TKInputActionSchema(
            type: "type",
            requiredFields: ["type", "text"],
            optionalFields: ["targetOID"],
            fields: [
                inputField("type", "String", required: true, enumValues: ["type"], "Action discriminator"),
                inputField("text", "String", required: true, "Text to insert into target or first responder"),
                inputField("targetOID", "UInt", "Optional UIKeyInput target oid"),
            ],
            example: #"{"type":"type","text":"hello"}"#
        ),
        TKInputActionSchema(
            type: "button",
            requiredFields: ["type", "button"],
            optionalFields: ["duration"],
            fields: [
                inputField("type", "String", required: true, enumValues: ["button"], "Action discriminator"),
                inputField("button", "String", required: true, enumValues: ["home"], "Device button name; embedded runtime returns unsupported"),
                inputField("duration", "Double", "Optional press duration in seconds"),
            ],
            example: #"{"type":"button","button":"home"}"#,
            resultShape: "{ ok: false, action, message } in embedded runtime"
        ),
    ]
}

func inputField(
    _ name: String,
    _ type: String,
    required: Bool = false,
    enumValues: [String]? = nil,
    _ description: String
) -> TKInputActionFieldSchema {
    TKInputActionFieldSchema(
        name: name,
        type: type,
        required: required,
        enumValues: enumValues,
        description: description
    )
}

func renderSchema(_ response: TKCLISchemaResponse, language: CLILanguage = effectiveLanguage(nil)) -> String {
    response.commands.map { command in
        var lines = ["\(command.name): \(command.summary)"]
        lines.append("  \(language == .zh ? "需要服务" : "requiresServer"): \(command.requiresServer)")
        lines.append("  \(language == .zh ? "需要目标" : "requiresTarget"): \(command.requiresTarget)")
        lines.append("  \(language == .zh ? "需要层级" : "requiresHierarchy"): \(command.requiresHierarchy)")
        lines.append("  \(language == .zh ? "运行时范围" : "runtimeScope"): \(command.runtimeScope)")
        lines.append("  \(language == .zh ? "失败退出码" : "exitCodeOnFailure"): \(command.exitCodeOnFailure)")
        lines.append("  \(language == .zh ? "输出格式" : "outputFormats"): \(command.outputFormats.joined(separator: ","))")
        if !command.options.isEmpty {
            lines.append("  \(language == .zh ? "选项" : "options"):")
            for option in command.options {
                let required = option.required ? " required" : ""
                let defaultValue = option.defaultValue.map { " default=\($0)" } ?? ""
                lines.append("    \(option.name): \(option.type)\(required)\(defaultValue) - \(option.description)")
            }
        }
        if !command.examples.isEmpty {
            lines.append("  \(language == .zh ? "示例" : "examples"):")
            lines.append(contentsOf: command.examples.map { "    \($0)" })
        }
        if let inputActions = command.inputActions, !inputActions.isEmpty {
            lines.append("  inputActions:")
            for action in inputActions {
                lines.append("    \(action.type): required=\(action.requiredFields.joined(separator: ",")) optional=\(action.optionalFields.joined(separator: ","))")
                if let coordinateSpace = action.coordinateSpace {
                    lines.append("      coordinateSpace: \(coordinateSpace)")
                }
                if !action.oneOfRequired.isEmpty {
                    let oneOf = action.oneOfRequired.map { $0.joined(separator: "+") }.joined(separator: " | ")
                    lines.append("      oneOfRequired: \(oneOf)")
                }
                lines.append("      fields:")
                for field in action.fields {
                    let required = field.required ? " required" : ""
                    let enumValues = field.enumValues.map { " enum=\($0.joined(separator: "|"))" } ?? ""
                    lines.append("        \(field.name): \(field.type)\(required)\(enumValues) - \(field.description)")
                }
                lines.append("      example: \(action.example)")
            }
        }
        return lines.joined(separator: "\n")
    }.joined(separator: "\n\n")
}

func waitForHierarchy(client: TritonKitHTTPClient) async throws -> Data {
    var lastError: Error?
    for _ in 0..<10 {
        do {
            return try await client.getData("/hierarchy/latest")
        } catch {
            lastError = error
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }
    throw lastError ?? RuntimeError("No hierarchy snapshot available")
}

func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}

func encodeCompactJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}

func prettyJSON(_ data: Data) throws -> String {
    let json = try JSONSerialization.jsonObject(with: data)
    let pretty = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    return String(data: pretty, encoding: .utf8) ?? "{}"
}

func encodeJSONObject(_ value: Any) throws -> String {
    guard JSONSerialization.isValidJSONObject(value) else {
        throw RuntimeError("Value is not a valid JSON object")
    }
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    return String(data: data, encoding: .utf8) ?? "{}"
}

func writeOrPrint(_ text: String, output: String?) throws {
    if let output {
        try text.data(using: .utf8)?.write(to: URL(fileURLWithPath: output), options: .atomic)
    } else {
        print(text)
    }
}

func requestPayload(
    type: TKRequestType,
    payload: Data? = nil,
    state: ConnectionState,
    targetState: TargetState,
    counter: MessageCounter,
    encoder: JSONEncoder
) async throws -> Data {
    guard let ws = state.outbound else {
        throw RuntimeError("No iOS device connected")
    }
    let id = counter.next()
    log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
    try await ws.send(TKMessage(id: id, type: type, payload: payload), encoder: encoder)
    guard let responsePayload = await targetState.waitForResponse(id: id) else {
        throw RuntimeRequestTimeoutError(requestType: type.rawValue)
    }
    return responsePayload
}

func executeInputRequest(_ request: TKInputRequest, client: TritonKitHTTPClient) async throws -> TKInputResult {
    let payload = try JSONEncoder().encode(request)
    let data = try await client.request(type: "input", payload: payload)
    return try JSONDecoder().decode(TKInputResult.self, from: data)
}

func screenshotImageData(_ screenshot: TKScreenshotResponse, client: TritonKitHTTPClient) async throws -> Data {
    if let dataRef = screenshot.dataRef, !dataRef.isEmpty {
        return try await client.getData("/data/\(dataRef)")
    }
    guard let data = Data(base64Encoded: screenshot.dataBase64) else {
        throw RuntimeError("Invalid screenshot image data")
    }
    return data
}

func buildExportArchive(
    target: TKTargetSummary,
    hierarchyData: Data,
    client: TritonKitHTTPClient
) async throws -> TKExportArchive {
    let hierarchyObject = try JSONSerialization.jsonObject(with: hierarchyData)
    let hierarchy = try TKJSONValue.fromJSONObject(hierarchyObject)
    let geometryData = try await client.request(type: "geometry")
    let geometry = try JSONDecoder().decode(TKGeometryResponse.self, from: geometryData)
    let accessibilityData = try await client.request(type: "accessibility")
    let accessibility = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
    let screenshotData = try await client.request(type: "screenshot")
    let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: screenshotData)
    let imageData = try await screenshotImageData(screenshot, client: client)
    let embeddedScreenshot = TKScreenshotResponse(
        format: screenshot.format,
        width: screenshot.width,
        height: screenshot.height,
        scale: screenshot.scale,
        dataBase64: imageData.base64EncodedString()
    )

    return TKExportArchive(
        exportedAt: ISO8601DateFormatter().string(from: Date()),
        target: target,
        hierarchy: hierarchy,
        geometry: geometry,
        accessibility: accessibility,
        screenshot: embeddedScreenshot
    )
}

func runInputRequest(
    _ request: TKInputRequest,
    host: String,
    port: Int,
    format: ClientOutputFormat
) async throws {
    let client = TritonKitHTTPClient(host: host, port: port)
    let result = try await executeInputRequest(request, client: client)
    try printInputResult(result, format: format)
    if !result.ok {
        throw RuntimeError(result.message ?? "Input request failed")
    }
}

func printInputResult(_ result: TKInputResult, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeCompactJSON(result))
    case .text:
        print("ok: \(result.ok)")
        print("action: \(result.action)")
        if let message = result.message {
            print("message: \(message)")
        }
        if let targetOID = result.targetOID {
            print("targetOID: \(targetOID)")
        }
        if let targetClassName = result.targetClassName {
            print("targetClassName: \(targetClassName)")
        }
    }
}

func renderAXTree(_ nodes: [TKAXNode]) -> String {
    axTreeLines(nodes, indent: 0).joined(separator: "\n")
}

func renderAXHierarchyMap(_ response: TKAXHierarchyMapResponse) -> String {
    var lines = [
        "AX nodes: \(response.axNodeCount)",
        "Hierarchy nodes: \(response.hierarchyNodeCount)",
        "Mapped: \(response.mappedCount)",
        "Unmatched: \(response.unmatchedCount)",
    ]
    for node in response.nodes {
        let prefix = String(repeating: "  ", count: node.depth)
        var line = "\(prefix)\(node.role)"
        if let label = node.label, !label.isEmpty { line += " \"\(label)\"" }
        if let identifier = node.identifier, !identifier.isEmpty { line += " #\(identifier)" }
        if let oid = node.viewOID ?? node.targetOID { line += " oid:\(oid)" }
        if let className = node.className { line += " \(className)" }
        line += " \(formatRect(node.frame))"
        if let hierarchy = node.hierarchy {
            line += " -> view:\(hierarchy.viewOID)"
            if let layerOID = hierarchy.layerOID { line += " layer:\(layerOID)" }
            if let hierarchyClass = hierarchy.className, hierarchyClass != node.className {
                line += " \(hierarchyClass)"
            }
        } else {
            line += " -> [unmatched]"
        }
        lines.append(line)
    }
    return lines.joined(separator: "\n")
}

func axTreeLines(_ nodes: [TKAXNode], indent: Int) -> [String] {
    var lines: [String] = []
    for (index, node) in nodes.enumerated() {
        let isLast = index == nodes.count - 1
        let prefix: String
        if indent == 0 {
            prefix = ""
        } else {
            prefix = String(repeating: "  ", count: indent - 1) + (isLast ? "└─ " : "├─ ")
        }
        var line = "\(prefix)\(node.role)"
        if let label = node.label, !label.isEmpty { line += " \"\(label)\"" }
        if let identifier = node.identifier, !identifier.isEmpty { line += " #\(identifier)" }
        if let oid = node.targetOID { line += " oid:\(oid)" }
        if let className = node.className { line += " \(className)" }
        line += " \(formatRect(node.frame))"
        if node.hidden { line += " [hidden]" }
        if !node.enabled { line += " [disabled]" }
        lines.append(line)
        lines.append(contentsOf: axTreeLines(node.children, indent: indent + 1))
    }
    return lines
}

func selectAXNode(_ nodes: [TKAXNode], oid: UInt?, label: String?) -> TKAXNode? {
    let flattened = TKFlattenAXNodes(nodes).map(\.node)
    if let oid {
        return flattened.first { $0.viewOID == oid || $0.targetOID == oid }
    }
    guard let label else { return nil }
    return flattened
        .filter { $0.label == label }
        .sorted { lhs, rhs in
            axTapPriority(lhs) > axTapPriority(rhs)
        }
        .first
}

struct TapTargetResolution: Codable {
    let query: String
    let source: String
    let strategy: String
    let role: String?
    let label: String?
    let value: String?
    let identifier: String?
    let className: String?
    let viewOID: UInt?
    let targetOID: UInt?
    let layerOID: UInt?
    let frame: TKRect?
    let request: TKInputRequest
}

func resolveTapTarget(
    _ query: String,
    client: TritonKitHTTPClient,
    width: Double?,
    height: Double?,
    duration: Double?
) async throws -> TapTargetResolution {
    let accessibilityData = try await client.request(type: "accessibility")
    let axNodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
    if let axNode = selectAXNodeByQuery(axNodes, query: query, includeValue: false) {
        let request = tapRequest(for: axNode, width: width, height: height, duration: duration)
        return TapTargetResolution(
            query: query,
            source: "ax",
            strategy: axTapShouldUseCoordinate(axNode) ? "coordinate" : "oid",
            role: axNode.role,
            label: axNode.label,
            value: axNode.value,
            identifier: axNode.identifier,
            className: axNode.className,
            viewOID: axNode.viewOID,
            targetOID: axNode.targetOID,
            layerOID: axNode.layerOID,
            frame: axNode.frame,
            request: request
        )
    }

    let hierarchyData = try await client.request(type: "hierarchy")
    if let candidate = try await selectHierarchyTextCandidate(query, hierarchyData: hierarchyData, client: client) {
        let request = TKInputRequest.tap(
            x: candidate.frame.centerX,
            y: candidate.frame.centerY,
            width: width,
            height: height,
            duration: duration
        )
        return TapTargetResolution(
            query: query,
            source: "hierarchy-text",
            strategy: "coordinate",
            role: nil,
            label: query,
            value: nil,
            identifier: nil,
            className: candidate.className,
            viewOID: candidate.viewOID,
            targetOID: nil,
            layerOID: candidate.layerOID,
            frame: candidate.frame,
            request: request
        )
    }

    if let axNode = selectAXNodeByQuery(axNodes, query: query, includeValue: true) {
        let request = tapRequest(for: axNode, width: width, height: height, duration: duration)
        return TapTargetResolution(
            query: query,
            source: "ax-value",
            strategy: axTapShouldUseCoordinate(axNode) ? "coordinate" : "oid",
            role: axNode.role,
            label: axNode.label,
            value: axNode.value,
            identifier: axNode.identifier,
            className: axNode.className,
            viewOID: axNode.viewOID,
            targetOID: axNode.targetOID,
            layerOID: axNode.layerOID,
            frame: axNode.frame,
            request: request
        )
    }

    throw RuntimeError("No tappable UI target matched query: \(query)")
}

func selectAXNodeByQuery(_ nodes: [TKAXNode], query: String, includeValue: Bool = true) -> TKAXNode? {
    TKFlattenAXNodes(nodes)
        .map(\.node)
        .filter { node in
            node.label == query
                || node.identifier == query
                || node.title == query
                || (includeValue && node.value == query)
        }
        .sorted { lhs, rhs in
            axTapPriority(lhs) > axTapPriority(rhs)
        }
        .first
}

func tapRequest(
    for node: TKAXNode,
    width: Double?,
    height: Double?,
    duration: Double?
) -> TKInputRequest {
    if axTapShouldUseCoordinate(node) {
        return TKInputRequest.tap(
            x: node.frame.centerX,
            y: node.frame.centerY,
            width: width,
            height: height,
            duration: duration
        )
    }
    return TKInputRequest.tap(
        targetOID: node.targetOID ?? node.viewOID,
        width: width,
        height: height,
        duration: duration
    )
}

func axTapShouldUseCoordinate(_ node: TKAXNode) -> Bool {
    if node.targetOID == nil && node.viewOID == nil {
        return true
    }
    return ["text", "image", "textField", "textView"].contains(node.role)
}

struct HierarchyTextCandidate {
    let viewOID: UInt
    let layerOID: UInt
    let className: String
    let frame: TKRect
    let depth: Int
}

func selectHierarchyTextCandidate(
    _ query: String,
    hierarchyData: Data,
    client: TritonKitHTTPClient
) async throws -> HierarchyTextCandidate? {
    let candidates = try hierarchyTextCandidates(hierarchyData)
        .sorted { lhs, rhs in
            hierarchyTextCandidatePriority(lhs) > hierarchyTextCandidatePriority(rhs)
        }

    for candidate in candidates {
        let payload = try JSONEncoder().encode(candidate.layerOID)
        let data = try await client.request(type: "allAttrGroups", payload: payload)
        let groups = try JSONDecoder().decode([TKAttributesGroup].self, from: data)
        if attributeGroups(groups, containText: query) {
            return candidate
        }
    }
    return nil
}

func hierarchyTextCandidates(_ data: Data) throws -> [HierarchyTextCandidate] {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }
    return flattenHierarchyTextCandidates(items, depth: 0, ancestorVisible: true)
}

func flattenHierarchyTextCandidates(
    _ items: [[String: Any]],
    depth: Int,
    ancestorVisible: Bool
) -> [HierarchyTextCandidate] {
    var candidates: [HierarchyTextCandidate] = []
    for item in items {
        let viewObj = item["viewObject"] as? [String: Any]
        let layerObj = item["layerObject"] as? [String: Any]
        let viewOid = viewObj?["oid"] as? UInt ?? uintValue(viewObj?["oid"])
        let layerOid = layerObj?["oid"] as? UInt ?? uintValue(layerObj?["oid"])
        let className = (viewObj?["classChainList"] as? [String])?.first
            ?? (layerObj?["classChainList"] as? [String])?.first
            ?? ""
        let hidden = item["isHidden"] as? Bool ?? false
        let alpha = doubleValue(item["alpha"]) ?? 1
        let visible = ancestorVisible && !hidden && alpha > 0.01
        if let viewOid,
           let layerOid,
           let frame = rectValue(item["frame"]),
           visible,
           frame.width > 0,
           frame.height > 0,
           isHierarchyTextCandidateClass(className) {
            candidates.append(HierarchyTextCandidate(
                viewOID: viewOid,
                layerOID: layerOid,
                className: className,
                frame: frame,
                depth: depth
            ))
        }
        if let subitems = item["subitems"] as? [[String: Any]] {
            candidates.append(contentsOf: flattenHierarchyTextCandidates(
                subitems,
                depth: depth + 1,
                ancestorVisible: visible
            ))
        }
    }
    return candidates
}

func isHierarchyTextCandidateClass(_ className: String) -> Bool {
    className == "UILabel"
        || className == "UISegmentLabel"
        || className == "UIButtonLabel"
        || className == "UITextFieldLabel"
        || className.hasSuffix("Label")
}

func hierarchyTextCandidatePriority(_ candidate: HierarchyTextCandidate) -> Int {
    var priority = 0
    if candidate.className == "UISegmentLabel" { priority += 30 }
    if candidate.className == "UIButtonLabel" { priority += 20 }
    if candidate.className == "UILabel" { priority += 10 }
    priority -= candidate.depth
    return priority
}

func attributeGroups(_ groups: [TKAttributesGroup], containText query: String) -> Bool {
    for group in groups {
        for section in group.attrSections {
            for attribute in section.attributes where isTextAttribute(attribute) {
                if attributeValueString(attribute.value) == query {
                    return true
                }
            }
        }
    }
    return false
}

func isTextAttribute(_ attribute: TKAttribute) -> Bool {
    attribute.identifier == "text" || attribute.displayTitle == "Text" || attribute.displayTitle == "Title"
}

func attributeValueString(_ value: TKAttributeValue?) -> String? {
    guard let value else { return nil }
    switch value {
    case .string(let string):
        return string
    case .number(let number):
        return "\(number)"
    case .bool(let bool):
        return bool ? "true" : "false"
    case .stringArray(let strings):
        return strings.joined(separator: ",")
    case .numberArray(let numbers):
        return numbers.map { "\($0)" }.joined(separator: ",")
    case .null:
        return nil
    }
}

func axTapPriority(_ node: TKAXNode) -> Int {
    var priority = 0
    if !node.hidden { priority += 10 }
    if node.enabled { priority += 10 }
    if ["button", "segmentedControl", "switch", "slider", "stepper", "textField", "textView", "control"].contains(node.role) {
        priority += 20
    }
    if node.role == "text" {
        priority -= 10
    }
    if node.targetOID != nil || node.viewOID != nil {
        priority += 5
    }
    return priority
}

func formatRect(_ rect: TKRect) -> String {
    String(format: "(%.0f,%.0f %.0fx%.0f)", rect.x, rect.y, rect.width, rect.height)
}

func resolveExportFormat(_ format: ExportOutputFormat, output: String) throws -> ExportOutputFormat {
    switch format {
    case .json, .archive:
        return format
    case .auto:
        let pathExtension = URL(fileURLWithPath: output).pathExtension.lowercased()
        switch pathExtension {
        case "", "json":
            return .json
        case "triton", "tritonkit", "archive", "lookinside":
            return .archive
        default:
            throw RuntimeError("Unsupported export extension: .\(pathExtension)")
        }
    }
}

// Flush-printing to stderr for immediate output in piped environments
func log(_ msg: String) {
    fputs("\(msg)\n", stderr)
    fflush(stderr)
}

// MARK: - Extensions

extension WebSocketOutboundWriter {
    func send(_ msg: TKMessage, encoder: JSONEncoder) async throws {
        guard let data = try? encoder.encode(msg) else { return }
        try await write(.binary(ByteBuffer(data: data)))
    }
}

// MARK: - Response Handling

func handleResponse(
    data: Data,
    store: DataStore,
    targetState: TargetState
) {
    guard let msg = try? JSONDecoder().decode(TKMessage.self, from: data) else {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            log("[tritonkit] <- raw:\n\(str)")
        }
        return
    }

    log("[tritonkit] <- \(msg.type.rawValue) [id:\(msg.id)]")

    guard let payload = msg.payload,
          let json = try? JSONSerialization.jsonObject(with: payload) else { return }
    targetState.storeResponse(id: msg.id, payload: payload)

    switch msg.type {
    case .hierarchy:
        targetState.setLatestHierarchy(payload)
        if let dict = json as? [String: Any] {
            if let items = dict["displayItems"] as? [[String: Any]] {
                printHierarchy(items, indent: 0)
            }
            if let info = dict["appInfo"] as? [String: Any] {
                log("── App: \(info["appName"] ?? "?") | \(info["deviceDescription"] ?? "?") | OS \(info["osDescription"] ?? "?")")
            }
        }

    case .appInfo:
        targetState.setLatestAppInfo(payload)
        if let dict = json as? [String: Any] {
            log("── \(dict["appName"] ?? "?") | \(dict["appBundleIdentifier"] ?? "?") | Device: \(dict["deviceDescription"] ?? "?")")
        }

    case .hierarchyDetails:
        checkAndShowImage(json: json, label: "solo", store: store)
        checkAndShowImage(json: json, label: "group", store: store)

    case .ping: log("  Pong!")
    default:
        if let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) { log(str) }
    }
}

func checkAndShowImage(json: Any, label: String, store: DataStore) {
    guard let dict = json as? [String: Any],
          let ref = dict["\(label)ScreenshotRef"] as? String,
          let id = UUID(uuidString: ref),
          let imgData = store.get(id) else { return }
    let size = ByteCountFormatter.string(fromByteCount: Int64(imgData.count), countStyle: .file)
    log("  [\(label) screenshot: \(size)]")
}

func renderHierarchyTree(_ data: Data, hideNoise: Bool = true) throws -> String {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }

    var lines: [String] = []
    if let info = json["appInfo"] as? [String: Any] {
        let appName = info["appName"] as? String ?? "?"
        let device = info["deviceDescription"] as? String ?? "?"
        let os = info["osDescription"] as? String ?? "?"
        lines.append("App: \(appName) | \(device) | OS \(os)")
    }
    lines.append(contentsOf: hierarchyTreeLines(items, indent: 0, hideNoise: hideNoise))
    return lines.joined(separator: "\n")
}

func hierarchyNodeSummaries(_ data: Data) throws -> [[String: Any]] {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }
    return flattenNodeSummaries(items, depth: 0)
}

func flattenNodeSummaries(_ items: [[String: Any]], depth: Int) -> [[String: Any]] {
    var nodes: [[String: Any]] = []
    for item in items {
        let viewObj = item["viewObject"] as? [String: Any]
        let layerObj = item["layerObject"] as? [String: Any]
        let viewOid = viewObj?["oid"] as? UInt ?? uintValue(viewObj?["oid"])
        let layerOid = layerObj?["oid"] as? UInt ?? uintValue(layerObj?["oid"])
        let oid = viewOid ?? layerOid ?? 0
        let className = (viewObj?["classChainList"] as? [String])?.first
            ?? (layerObj?["classChainList"] as? [String])?.first
            ?? "?"
        var node: [String: Any] = [
            "oid": oid,
            "className": className,
            "depth": depth,
            "hidden": item["isHidden"] as? Bool ?? false,
            "alpha": doubleValue(item["alpha"]) ?? 1,
            "frame": frameDescription(item["frame"]) ?? "",
        ]
        if let viewOid { node["viewOid"] = viewOid }
        if let layerOid { node["layerOid"] = layerOid }
        if let title = item["customDisplayTitle"] as? String { node["title"] = title }
        nodes.append(node)
        if let subitems = item["subitems"] as? [[String: Any]] {
            nodes.append(contentsOf: flattenNodeSummaries(subitems, depth: depth + 1))
        }
    }
    return nodes
}

func uintValue(_ value: Any?) -> UInt? {
    if let value = value as? UInt { return value }
    if let value = value as? Int { return UInt(value) }
    if let value = value as? NSNumber { return value.uintValue }
    return nil
}

func doubleValue(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? Float { return Double(value) }
    if let value = value as? Int { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    return nil
}

func rectValue(_ frame: Any?) -> TKRect? {
    if let dict = frame as? [String: Any] {
        return TKRect(
            x: doubleValue(dict["x"]) ?? 0,
            y: doubleValue(dict["y"]) ?? 0,
            width: doubleValue(dict["width"]) ?? 0,
            height: doubleValue(dict["height"]) ?? 0
        )
    }
    guard let array = frame as? [[Double]], array.count >= 2 else {
        return nil
    }
    let origin = array[0]
    let size = array[1]
    guard origin.count >= 2, size.count >= 2 else {
        return nil
    }
    return TKRect(x: origin[0], y: origin[1], width: size[0], height: size[1])
}

func nodeMatches(_ node: [String: Any], oid: UInt) -> Bool {
    uintValue(node["oid"]) == oid || uintValue(node["viewOid"]) == oid || uintValue(node["layerOid"]) == oid
}

func renderNodeLine(_ node: [String: Any]) -> String {
    [
        "\(node["oid"] ?? "-")",
        "\(node["layerOid"] ?? "-")",
        "\(node["depth"] ?? "-")",
        "\(node["className"] ?? "-")",
        "\(node["frame"] ?? "-")",
    ].joined(separator: "\t")
}

func renderAttributeGroups(_ groups: [TKAttributesGroup]) -> String {
    guard !groups.isEmpty else { return "No attributes" }
    var lines: [String] = []
    for group in groups {
        lines.append("[\(group.title)]")
        for section in group.attrSections {
            lines.append("  \(section.identifier)")
            for attribute in section.attributes {
                lines.append("    \(attribute.displayTitle ?? attribute.identifier): \(describeAttributeValue(attribute.value))")
            }
        }
    }
    return lines.joined(separator: "\n")
}

func describeAttributeValue(_ value: TKAttributeValue?) -> String {
    guard let value else { return "-" }
    switch value {
    case .null: return "null"
    case .string(let value): return value
    case .number(let value): return "\(value)"
    case .bool(let value): return "\(value)"
    case .stringArray(let value): return value.joined(separator: ",")
    case .numberArray(let value): return value.map { "\($0)" }.joined(separator: ",")
    }
}

func printHierarchy(_ items: [[String: Any]], indent: Int) {
    for line in hierarchyTreeLines(items, indent: indent, hideNoise: true) {
        log(line)
    }
}

func hierarchyTreeLines(_ items: [[String: Any]], indent: Int, hideNoise: Bool = true) -> [String] {
    var lines: [String] = []
    let renderedItems = hierarchyTreeRenderableItems(items, hideNoise: hideNoise)
    for (i, item) in renderedItems.enumerated() {
        let isLast = i == renderedItems.count - 1
        let prefix: String
        if indent == 0 { prefix = "  " }
        else { prefix = String(repeating: "  ", count: indent - 1) + (isLast ? "  └─ " : "  ├─ ") }

        let viewObj = item["viewObject"] as? [String: Any]
        let className = (viewObj?["classChainList"] as? [String])?.first ?? "?"
        let frame = item["frame"]
        let hidden = item["isHidden"] as? Bool ?? false
        let alpha = item["alpha"] as? Float ?? 1.0
        let title = item["customDisplayTitle"] as? String
        let screenshotRef = item["screenshotRef"] as? String

        var line = "\(prefix)\(className)"
        if let t = title { line += " \"\(t)\"" }
        if let frame = frameDescription(frame) {
            line += " \(frame)"
        }
        if hidden { line += " [H]" }
        if alpha < 1 { line += String(format: " α:%.2f", alpha) }
        if screenshotRef != nil { line += " [image]" }
        lines.append(line)

        if let subitems = item["subitems"] as? [[String: Any]] {
            lines.append(contentsOf: hierarchyTreeLines(subitems, indent: indent + 1, hideNoise: hideNoise))
        }
    }
    return lines
}

func hierarchyTreeRenderableItems(_ items: [[String: Any]], hideNoise: Bool) -> [[String: Any]] {
    guard hideNoise else { return items }
    return items.flatMap { item -> [[String: Any]] in
        guard let className = hierarchyTreeClassName(item),
              TKIsDefaultHiddenHierarchyTreeClass(className),
              let subitems = item["subitems"] as? [[String: Any]]
        else {
            return [item]
        }
        return hierarchyTreeRenderableItems(subitems, hideNoise: hideNoise)
    }
}

func hierarchyTreeClassName(_ item: [String: Any]) -> String? {
    let viewObj = item["viewObject"] as? [String: Any]
    if let className = (viewObj?["classChainList"] as? [String])?.first {
        return className
    }
    let layerObj = item["layerObject"] as? [String: Any]
    return (layerObj?["classChainList"] as? [String])?.first
}

func frameDescription(_ frame: Any?) -> String? {
    if let dict = frame as? [String: Any] {
        return String(format: "(%.0f,%.0f %.0fx%.0f)",
            dict["x"] as? Double ?? 0, dict["y"] as? Double ?? 0,
            dict["width"] as? Double ?? 0, dict["height"] as? Double ?? 0)
    }
    guard let array = frame as? [[Double]], array.count >= 2 else {
        return nil
    }
    let origin = array[0]
    let size = array[1]
    guard origin.count >= 2, size.count >= 2 else {
        return nil
    }
    return String(format: "(%.0f,%.0f %.0fx%.0f)", origin[0], origin[1], size[0], size[1])
}
