import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

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
        ("xcode", "发现、构建、测试和运行 Xcode 工程"),
        ("xcresult", "读取 Xcode result bundle 汇总和失败列表"),
        ("xctrace", "采集 Instruments .trace 证据"),
        ("coverage", "导出 Xcode 覆盖率报告 artifact"),
        ("runtime", "读取 embedded runtime manifest 和能力边界"),
        ("state", "读取 App、scene、route 和 responder 状态"),
        ("snapshot", "读取 App 内聚合快照"),
        ("plan", "根据当前状态输出推荐下一步"),
        ("list (默认)", "列出已连接的 TritonKit 目标"),
        ("inspect", "查看单个 TritonKit 目标摘要"),
        ("observe", "读取当前可见节点或平台观察树"),
        ("webview", "读取 WebView 候选、URL 和 opt-in bridge 状态"),
        ("route", "断言当前 route 或 WebView URL"),
        ("hierarchy", "读取目标最新视图层级"),
        ("nodes", "列出最新层级中的节点摘要"),
        ("node", "查看单个层级节点"),
        ("attrs", "读取节点 layer oid 的实时属性组"),
        ("object", "读取 view 或 layer oid 的对象元数据"),
        ("export", "导出可复用层级快照或 archive"),
        ("evidence", "导出 agent 回归证据包"),
        ("capture", "一站式采集回归证据包"),
        ("smoke", "运行一命令真实项目 smoke 流程"),
        ("assert", "执行 agent 友好的 UI 文本断言"),
        ("record", "生成可编辑 replay plan 模板"),
        ("replay", "复跑 .tritonplan smoke 流程"),
        ("find", "解析一个可见文本或意图目标"),
        ("wait", "等待文本、消失、空闲或谓词条件"),
        ("tap", "点击文本、坐标、view oid 或 AX 节点"),
        ("swipe", "在 App 内按 window points 执行滑动"),
        ("type", "向已聚焦或 oid 指定的 UIKeyInput 输入文本"),
        ("paste", "向已聚焦、坐标或 oid 指定的输入框精确粘贴文本"),
        ("clear", "清空已聚焦、坐标或 oid 指定的输入框"),
        ("press", "在当前运行时支持时按设备按钮"),
        ("geometry", "读取当前 window 几何信息"),
        ("ax", "读取 App 内安全可操作控件索引"),
        ("hit", "对当前 App window 中一点做命中测试"),
        ("screenshot", "捕获当前 App PNG 截图"),
        ("input", "从 stdin 读取 NDJSON 输入动作"),
        ("device", "发现和检查 host-side 设备与模拟器"),
        ("sim", "控制 iOS Simulator 生命周期、截图和维护"),
        ("app", "控制 simulator / emulator App 生命周期和偏好"),
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
        "xcode": ChineseCommandHelp(name: "xcode", overview: "发现、配置、构建、测试和运行 Xcode 工程。", usage: "triton xcode <discover|use|schemes|status|wait-idle|settings|build|test|run> [选项]", options: formatTextJSON + [
            ("discover --path <path>", "发现 workspace / project / Package.swift 候选"),
            ("use --workspace <path> --scheme <name>", "写入工作区 Xcode 默认值"),
            ("schemes", "列出可用 schemes"),
            ("status", "检查活跃 xcodebuild 进程"),
            ("wait-idle", "等待 workspace 相关 xcodebuild 空闲"),
            ("settings", "解析 app product 路径与 bundle id"),
            ("build", "运行 xcodebuild build"),
            ("test --result-bundle <path>", "运行 xcodebuild test"),
            ("run", "执行 build/install/launch 一体化流程"),
        ]),
        "xcresult": ChineseCommandHelp(name: "xcresult", overview: "读取 Xcode result bundle 的测试汇总和失败列表。", usage: "triton xcresult <summary|failures> --path <path.xcresult> [选项]", options: formatTextJSON + [
            ("summary --path <path.xcresult>", "读取测试计数、环境描述和结果状态"),
            ("failures --path <path.xcresult>", "读取结构化失败列表和 top failure"),
            ("--include-sensitive", "输出私有路径、邮箱和 token-like 片段；默认关闭并自动脱敏"),
        ]),
        "runtime": ChineseCommandHelp(name: "runtime", overview: "读取 embedded runtime manifest、能力边界、限制和脱敏策略。", usage: "triton runtime manifest [选项]", options: target + hostPort + formatTextJSON),
        "sim": ChineseCommandHelp(name: "sim", overview: "控制 iOS Simulator 生命周期、截图和维护。", usage: "triton sim <list|use|boot|shutdown|screenshot|record|logs|diagnose|logverbose|runtime|status-bar|privacy|location|ui|pasteboard|push> [选项]", options: formatTextJSON + [
            ("list", "列出可用 simulator"),
            ("use <udid>", "写入工作区默认 simulator"),
            ("boot <udid>", "启动 simulator"),
            ("shutdown <udid|booted>", "关闭 simulator"),
            ("screenshot --output <path>", "采集 simulator 截图"),
            ("record --output <path.mov> --duration <seconds>", "录制 simulator 视频"),
            ("logs --output <path.log> --duration <seconds>", "采集有边界的 simulator 日志流"),
            ("diagnose [--output <path>]", "收集 simulator 诊断信息和日志"),
            ("logverbose [--simulator <udid>] enable|disable", "打开或关闭 verbose logging"),
            ("runtime list|verify", "查看 simulator runtime 或验证 runtime 签名"),
        ]),
        "device": ChineseCommandHelp(name: "device", overview: "发现和检查 host-side 平台设备。", usage: "triton device <doctor|list|use|wait-ready|screenshot|runtime-url> --platform ios|harmony [选项]", options: formatTextJSON + [
            ("--platform <platform>", "平台适配器：ios 或 harmony；默认 harmony 以保持兼容"),
            ("--hdc <path>", "HDC 可执行文件路径，默认 hdc"),
            ("--target <target>", "iOS simulator UDID 或 Harmony target，例如 127.0.0.1:10100"),
            ("screenshot --output <path>", "通过统一入口采集 iOS/Harmony host-side 截图"),
            ("--timeout <seconds>", "wait-ready 超时时间，默认 30"),
            ("--local-port <port>", "runtime-url 本机 host-access 端口，默认 \(TKHarmonyRuntimeDefaults.hostAccessPort)"),
            ("--remote-port <port>", "runtime-url 设备端 embedded runtime host-access 端口，默认 \(TKHarmonyRuntimeDefaults.hostAccessPort)"),
            ("--probe-manifest", "runtime-url 建立 Harmony 端口映射后验证 /v2/runtime/manifest"),
        ]),
        "plan": ChineseCommandHelp(name: "plan", overview: "根据当前服务和目标状态输出推荐下一步；inspect 子动作可离线查看 .tritonplan 摘要。", usage: "triton plan [inspect <path>] [选项]", options: hostPort + formatTextJSON),
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
        "evidence": ChineseCommandHelp(name: "evidence", overview: "导出 agent 回归证据包，包含 manifest 与截图、AX、层级、状态等 artifact。", usage: "triton evidence [inspect <path>] [选项]", options: target + hostPort + formatTextJSON + [
            ("--output <path>", "证据包目录路径，建议使用 .tritonevidence 后缀"),
            ("--include <list>", "逗号分隔 artifact：screenshot,ax,hierarchy,status,list,version,geometry,archive,logs"),
            ("--name <name>", "场景名，写入 manifest"),
            ("--note <note>", "备注，写入 manifest"),
            ("--refresh/--no-refresh", "导出 hierarchy/archive 前是否请求新层级"),
        ]),
        "capture": ChineseCommandHelp(name: "capture", overview: "一站式采集 agent 回归证据包。", usage: "triton capture --case <name> --output <path> [选项]", options: target + hostPort + formatTextJSON + [
            ("--case <name>", "回归场景名，写入 manifest"),
            ("--output <path>", "证据包目录路径，建议使用 .tritonevidence 后缀"),
            ("--include <list>", "逗号分隔 artifact，默认包含 status,list,version,hierarchy,ax,screenshot,geometry,archive"),
            ("--note <note>", "备注，写入 manifest"),
        ]),
        "smoke": ChineseCommandHelp(name: "smoke", overview: "运行一命令真实项目 smoke 编排。", usage: "triton smoke ios --bundle-id <id> --open-url <url> --wait-text <text> [选项]", options: target + hostPort + formatTextJSON + [
            ("ios", "运行 iOS smoke evidence 流程"),
            ("--bundle-id <id>", "目标 App bundle identifier"),
            ("--open-url <url>", "要打开的 deep link URL"),
            ("--wait-text <text>", "等待出现的可见文本"),
            ("--assert-text <text>", "等待后额外断言的可见文本"),
            ("--screenshot <path>", "模拟器截图输出路径"),
            ("--evidence <path>", "证据包目录路径"),
            ("--evidence-name <name>", "写入 manifest 的场景名"),
            ("--evidence-note <note>", "写入 manifest 的备注"),
        ]),
        "assert": ChineseCommandHelp(name: "assert", overview: "断言 UI 可见文本存在或不存在。", usage: "triton assert <text-exists|text-not-exists> <text> [选项]", options: target + hostPort + formatTextJSON + [
            ("--role <role>", "限制 AX role"),
            ("--count <n>", "要求匹配数量等于 n"),
            ("--min-count <n>", "要求匹配数量至少为 n"),
            ("--max-count <n>", "要求匹配数量最多为 n"),
            ("--within <x,y,w,h>", "只检查指定 window bounds 内的文本"),
        ]),
        "record": ChineseCommandHelp(name: "record", overview: "生成可编辑 .tritonplan 模板；首期不是交互式真实录制。", usage: "triton record --output <path> [选项]", options: formatTextJSON + [
            ("--output <path>", "写入 .tritonplan 文件"),
            ("--name <name>", "计划名称，默认来自输出文件名"),
        ]),
        "replay": ChineseCommandHelp(name: "replay", overview: "复跑 .tritonplan smoke 流程。", usage: "triton replay <path> [选项]", options: target + hostPort + formatTextJSON + [
            ("<path>", ".tritonplan 文件路径"),
            ("--dry-run", "只校验与展示步骤，不连接 runtime"),
            ("--var <key=value>", "提供变量值，可重复"),
            ("--var <key-env=ENV>", "从环境变量读取变量值，可重复"),
        ]),
        "find": ChineseCommandHelp(name: "find", overview: "把可见文本、label、identifier 或选项标题解析为可操作目标。", usage: "triton find <文本> [选项]", options: target + hostPort + formatTextJSON + [
            ("<文本>", "要解析的用户意图，例如 HTTP"),
            ("--all", "输出全部候选及 1 起始序号"),
            ("--index <n>", "选择第 n 个候选"),
            ("--within <x,y,w,h>", "只在指定 window bounds 内匹配"),
            ("--at <x,y>", "只匹配包含该 window 点位的候选"),
        ]),
        "wait": ChineseCommandHelp(name: "wait", overview: "等待文本出现、文本消失、目标空闲、层级变化或安全谓词成立。", usage: "triton wait [条件] [选项]", options: target + hostPort + formatTextJSON + [
            ("--text <text>", "等待可见文本出现"),
            ("--gone <text>", "等待可见文本消失"),
            ("--exists <text>", "等待可见文本出现，可配合 --role"),
            ("--role <role>", "限制 AX role，例如 button"),
            ("--idle", "等待当前 target 已连接且 hierarchy 连续稳定"),
            ("--hierarchy-change", "等待 hierarchy 快照变化"),
            ("--since <value>", "hierarchy-change 基线，目前支持 latest"),
            ("--predicate <expr>", "安全谓词，例如 text.exists(\"console\") && !text.exists(\"登录\")"),
            ("--timeout <seconds>", "超时时间，默认 10"),
            ("--interval <seconds>", "轮询间隔，默认 0.5"),
        ]),
        "tap": ChineseCommandHelp(name: "tap", overview: "点击文本、坐标、view oid 或 AX 节点。", usage: "triton tap [文本] [选项]", options: target + hostPort + formatTextJSON + [
            ("<文本>", "要点击的可见文本、label、identifier 或选项标题，例如 HTTP"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
            ("--oid <oid>", "hierarchy view oid"),
            ("--ax-oid <oid>", "`triton ax` 输出的 targetOID/viewOID"),
            ("--ax-label <label>", "`triton ax` 输出的精确 label，优先按 AX oid 点击"),
            ("--strategy <smart|exact|ancestor>", "query/AX 文本点击的激活目标策略；query 默认 smart，AX 默认 exact"),
            ("--duration <seconds>", "按住时长"),
            ("--index <n>", "按 `find --all` 的 1 起始序号选择候选"),
            ("--within <x,y,w,h>", "只在指定 window bounds 内匹配文本候选"),
            ("--at <x,y>", "无文本时按坐标点击；有文本时只匹配包含该点位的候选"),
        ]),
        "input": ChineseCommandHelp(name: "input", overview: "从 stdin 读取 NDJSON 输入动作。", usage: "triton input [选项] < gestures.ndjson", options: target + hostPort + formatTextJSON + [
            ("--fail-fast", "首个失败动作后停止"),
            ("--summary", "输出最终批次 summary"),
            ("--strict", "任一动作失败时以非 0 退出"),
        ]),
        "paste": ChineseCommandHelp(name: "paste", overview: "向当前焦点或指定输入框精确粘贴文本。", usage: "triton paste <text> [选项]", options: target + hostPort + formatTextJSON + [
            ("<text>", "要插入的文本"),
            ("--secure", "敏感文本，输出只回显长度和 redaction 状态"),
            ("--oid <oid>", "可选 responder oid"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
            ("--at <x,y>", "聚焦该 window 点位后粘贴"),
        ]),
        "type": ChineseCommandHelp(name: "type", overview: "向已聚焦或 oid 指定的 UIKeyInput 输入文本。", usage: "triton type <text> [选项]", options: target + hostPort + formatTextJSON + [
            ("<text>", "要插入的文本"),
            ("--text <text>", "兼容入口；与位置参数二选一"),
            ("--secure", "敏感文本，输出只回显长度和 redaction 状态"),
            ("--oid <oid>", "可选 responder oid"),
            ("--exact", "保留兼容选项，当前 embedded runtime 使用直接插入"),
        ]),
        "clear": ChineseCommandHelp(name: "clear", overview: "清空当前焦点或指定输入框。", usage: "triton clear [选项]", options: target + hostPort + formatTextJSON + [
            ("--oid <oid>", "可选 responder oid"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
            ("--at <x,y>", "聚焦该 window 点位后清空"),
        ]),
        "press": ChineseCommandHelp(name: "press", overview: "按下运行时支持的设备按钮。", usage: "triton press <button> [选项]", options: target + hostPort + formatTextJSON + [
            ("<button>", "按钮名，例如 home"),
            ("--button <button>", "兼容入口；与位置参数二选一"),
            ("--duration <seconds>", "按住时长"),
        ]),
        "hit": ChineseCommandHelp(name: "hit", overview: "对当前 App window 点位做 hit-test。", usage: "triton hit --at <x,y> [选项]", options: target + hostPort + formatTextJSON + [
            ("--at <x,y>", "window 点位"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
        ]),
    ]
}
