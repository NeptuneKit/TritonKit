import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

struct Plan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print recommended next CLI steps or inspect a replay plan")

    @Argument(help: "Optional action. Use `inspect` to summarize a .tritonplan, or a task such as ios-smoke, open-url, webview-check, or network-proxy.") var action: String?
    @Argument(help: "Replay plan path for `inspect`.") var input: String?
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Host target selector for task planning") var device: String?
    @Option(help: "Platform for host-side task planning: ios|android|harmony") var platform: String?
    @Option(help: "App bundle identifier for task planning") var bundleID: String?
    @Option(help: "URL or deep link for task planning") var url: String?
    @Option(help: "Text to wait for or assert during task planning") var text: String?
    @Option(help: "Expected WebView URL for webview-check planning") var expectedURL: String?
    @Option(help: "Evidence bundle output path for task planning") var evidence: String?
    @Option(help: "Proxy endpoint host:port for network-proxy task planning") var proxy: String?
    @Option(help: "Proxy capture mode for network-proxy task planning: record|mock|block|throttle") var mode: String?
    @Option(help: "Proxy session or capture output directory for network-proxy task planning") var output: String?
    @Option(help: "Proxy root certificate path for network-proxy certificate planning") var certificate: String?
    @Option(help: "Audit record id used by network-proxy break-glass plan steps") var auditRecord: String?
    @Option(help: "JSON mock rules file passed to proxy serve when network-proxy mode is mock") var mockRules: String?
    @Option(help: "Synthetic response delay passed to proxy serve when network-proxy mode is throttle") var throttleMs: Int?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        if let action, action == "inspect" {
            let outputFormat = effectiveFormat(format, json: json)
            guard let input else {
                try failReplayValidation("`triton plan inspect` requires a .tritonplan path", outputFormat: outputFormat)
            }
            do {
                let plan = try readReplayPlan(from: input)
                let summary = TKReplayPlanSummary(ok: true, path: input, plan: plan)
                switch outputFormat {
                case .json:
                    print(try encodeJSON(summary))
                case .text:
                    print("ok: true")
                    print("path: \(summary.path)")
                    print("schemaVersion: \(summary.schemaVersion)")
                    if let name = summary.name { print("name: \(name)") }
                    print("stepCount: \(summary.stepCount)")
                    print("actions: \(summary.actions.joined(separator: ","))")
                }
            } catch {
                if error is ExitCode { throw error }
                try failReplayValidation("\(error)", outputFormat: outputFormat)
            }
            return
        }
        if let action, !["ios-smoke", "open-url", "webview-check", "network-proxy"].contains(action) {
            try failReplayValidation("Unsupported plan action: \(action)", outputFormat: effectiveFormat(format, json: json))
        }
        guard input == nil else {
            try failReplayValidation("Unexpected plan argument: \(input ?? "")", outputFormat: effectiveFormat(format, json: json))
        }
        let capabilities = await buildCapabilities(host: host, port: port)
        let plan = buildWorkflowPlan(
            capabilities: capabilities,
            host: host,
            port: port,
            request: WorkflowPlanRequest(
                goal: action ?? "general",
                device: device,
                platform: platform,
                bundleID: bundleID,
                url: url,
                text: text,
                expectedURL: expectedURL,
                evidence: evidence,
                proxy: proxy,
                mode: mode,
                output: output,
                certificate: certificate,
                auditRecord: auditRecord,
                mockRules: mockRules,
                throttleMs: throttleMs
            )
        )
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
        let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
        let data = refresh ? try await client.request(type: "hierarchy") : try await waitForHierarchy(client: client)
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
        let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
        let data = refresh ? try await client.request(type: "hierarchy") : try await waitForHierarchy(client: client)
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
    static let configuration = CommandConfiguration(
        abstract: "Inspect or resolve one current UI node",
        subcommands: [NodeResolve.self]
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "View or layer oid from `triton nodes`") var oid: UInt?
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before reading the node")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard oid != nil else {
            if outputFormat == .json {
                try printValidationError("`triton node` requires --oid, or use `triton node resolve --text <text>`")
                throw ExitCode.failure
            }
            throw RuntimeError("`triton node` requires --oid, or use `triton node resolve --text <text>`")
        }
        let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
        let data = refresh ? try await client.request(type: "hierarchy") : try await waitForHierarchy(client: client)
        guard let oid, let node = try hierarchyNodeSummaries(data).first(where: { nodeMatches($0, oid: oid) }) else {
            throw RuntimeError("Node not found: \(self.oid ?? 0)")
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
        let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
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
        let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
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
