import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

struct Runtime: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runtime",
        abstract: "Inspect embedded runtime capabilities and boundaries",
        subcommands: [RuntimeManifest.self]
    )
}

struct RuntimeManifest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "manifest",
        abstract: "Read the embedded runtime manifest"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let data: Data
            if let runtimeBaseURL {
                data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.runtimeManifest)
            } else {
                let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
                data = try await client.request(type: "runtimeManifest")
            }
            let manifest = try JSONDecoder().decode(TKRuntimeManifestResponse.self, from: data)
            switch outputFormat {
            case .json:
                print(try encodeJSON(manifest))
            case .text:
                print("ok: \(manifest.ok)")
                print("platform: \(manifest.platform)")
                print("runtime: \(manifest.runtime)")
                print("transport: \(manifest.transport)")
                print("enabled: \(manifest.enabled)")
                print("sdkVersion: \(manifest.sdkVersion)")
                print("buildConfiguration: \(manifest.buildConfiguration)")
                print("capabilities:")
                for capability in manifest.capabilities {
                    let status = capability.supported ? "supported" : "unsupported"
                    let reason = capability.reason.map { " reason=\($0)" } ?? ""
                    print("  - \(capability.name): \(status) scope=\(capability.scope) boundary=\(capability.boundary)\(reason)")
                }
                print("limits: maxSnapshotBytes=\(manifest.limits.maxSnapshotBytes) maxAXNodes=\(manifest.limits.maxAXNodes) maxLedgerEntries=\(manifest.limits.maxLedgerEntries)")
                print("redaction: secureText=\(manifest.redaction.secureText) clipboard=\(manifest.redaction.clipboard) network=\(manifest.redaction.network) logs=\(manifest.redaction.logs)")
            }
        } catch {
            if let exitCode = error as? ExitCode {
                throw exitCode
            }
            try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
        }
    }
}

struct State: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "state",
        abstract: "Read embedded app runtime state",
        subcommands: [StateApp.self, StateScene.self, StateRoute.self, StateResponder.self]
    )
}

struct StateApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "app", abstract: "Read app identity and environment state")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runStateRequest(type: "stateApp", target: target, host: host, port: port, runtimeBaseURL: runtimeBaseURL, format: format, json: json)
    }
}

struct StateScene: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scene", abstract: "Read scene and window state")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runStateRequest(type: "stateScene", target: target, host: host, port: port, runtimeBaseURL: runtimeBaseURL, format: format, json: json)
    }
}

struct StateRoute: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "route", abstract: "Read controller route and container state")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runStateRequest(type: "stateRoute", target: target, host: host, port: port, runtimeBaseURL: runtimeBaseURL, format: format, json: json)
    }
}

struct StateResponder: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "responder", abstract: "Read first responder and text input traits")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runStateRequest(type: "stateResponder", target: target, host: host, port: port, runtimeBaseURL: runtimeBaseURL, format: format, json: json)
    }
}

func runStateRequest(
    type: String,
    target: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        let data: Data
        if let runtimeBaseURL {
            guard let requestType = TKCLICommandRequest(type: type).requestType else {
                throw RuntimeError("Unsupported runtime state request: \(type)")
            }
            data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(requestType)
        } else {
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            data = try await client.request(type: type)
        }
        switch outputFormat {
        case .json:
            print(String(data: data, encoding: .utf8) ?? "{}")
        case .text:
            if let object = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: pretty, encoding: .utf8) {
                print(text)
            } else {
                print(String(data: data, encoding: .utf8) ?? "")
            }
        }
    } catch {
        if let exitCode = error as? ExitCode {
            throw exitCode
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

struct Snapshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot",
        abstract: "Read an aggregated embedded runtime snapshot"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Comma-separated sections: app,scene,route,responder,ax,geometry,screenshot-metadata") var include: String = "app,scene,route,ax,geometry"
    @Option(help: "Maximum AX nodes to return") var maxAXNodes: Int?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let includeList = include.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let data: Data
            if let runtimeBaseURL {
                var queryItems = [URLQueryItem(name: "include", value: includeList.joined(separator: ","))]
                if let maxAXNodes {
                    queryItems.append(URLQueryItem(name: "maxAXNodes", value: String(maxAXNodes)))
                }
                data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.runtimeSnapshot, queryItems: queryItems)
            } else {
                let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
                let request = TKRuntimeSnapshotRequest(include: includeList, maxAXNodes: maxAXNodes)
                let payload = try JSONEncoder().encode(request)
                data = try await client.request(type: "runtimeSnapshot", payload: payload)
            }
            try printRawJSONData(data, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
        }
    }
}

struct Focus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "focus", abstract: "Focus a text input by selector")

    @Argument(help: "Text, label, identifier, or visible placeholder to focus; with --webview a stable DOM form identity (#id, [name=...], form-N)") var selector: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Select one matching selector candidate by 1-based index") var index: Int?
    @Option(help: "Restrict matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Restrict matching to candidate containing point: x,y") var at: String?
    @Flag(name: .customLong("webview"), help: "Focus an opt-in WebView DOM form target by stable selector instead of the native AX tree") var webview = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if webview {
            if index != nil || within != nil || at != nil {
                if outputFormat == .json {
                    try printValidationError("--webview focus accepts only a stable form selector; --index/--within/--at target the native AX tree")
                    throw ExitCode.failure
                }
                throw RuntimeError("--webview focus accepts only a stable form selector")
            }
            try await runWebViewFocus(
                selector: selector,
                platform: .ios,
                target: target,
                host: host,
                port: port,
                runtimeBaseURL: runtimeBaseURL,
                webViewID: nil,
                pageSessionID: nil,
                format: format,
                json: json
            )
            return
        }
        try await runSemanticSelectorAction(
            action: .focus,
            sourceCommand: "focus",
            selector: selector,
            target: target,
            host: host,
            port: port,
            index: index,
            within: within,
            at: at,
            runtimeBaseURL: runtimeBaseURL,
            format: format,
            json: json
        )
    }
}

struct SetText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set-text", abstract: "Clear and set exact text by selector")

    @Argument(help: "Text, label, identifier, or visible placeholder to target; with --webview a stable DOM form identity (#id, [name=...], form-N)") var selector: String
    @Argument(help: "Exact text to set") var text: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Flag(name: .customLong("secure"), help: "Redact text in command output and ledger") var secure = false
    @Option(help: "Select one matching selector candidate by 1-based index") var index: Int?
    @Option(help: "Restrict matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Restrict matching to candidate containing point: x,y") var at: String?
    @Flag(name: .customLong("webview"), help: "Set exact text on an opt-in WebView DOM form target by stable selector instead of the native AX tree") var webview = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if webview {
            if index != nil || within != nil || at != nil {
                if outputFormat == .json {
                    try printValidationError("--webview set-text accepts only a stable form selector; --index/--within/--at target the native AX tree")
                    throw ExitCode.failure
                }
                throw RuntimeError("--webview set-text accepts only a stable form selector")
            }
            try await runWebViewFormInput(
                mode: .setText,
                text: text,
                selector: selector,
                secure: secure,
                platform: .ios,
                target: target,
                host: host,
                port: port,
                runtimeBaseURL: runtimeBaseURL,
                webViewID: nil,
                pageSessionID: nil,
                format: format,
                json: json
            )
            return
        }
        try await runSemanticSelectorAction(
            action: .setText,
            sourceCommand: "set-text",
            selector: selector,
            target: target,
            host: host,
            port: port,
            text: text,
            secure: secure,
            index: index,
            within: within,
            at: at,
            runtimeBaseURL: runtimeBaseURL,
            format: format,
            json: json
        )
    }
}

struct SelectSegment: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "select-segment", abstract: "Select a UISegmentedControl segment by title or index")

    @Argument(help: "Text, label, identifier, or visible option title to target") var selector: String
    @Argument(help: "Segment title or zero-based index") var value: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Select one matching selector candidate by 1-based index") var index: Int?
    @Option(help: "Restrict matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Restrict matching to candidate containing point: x,y") var at: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runSemanticSelectorAction(
            action: .selectSegment,
            sourceCommand: "select-segment",
            selector: selector,
            target: target,
            host: host,
            port: port,
            segmentTitle: Int(value) == nil ? value : nil,
            segmentIndex: Int(value),
            index: index,
            within: within,
            at: at,
            runtimeBaseURL: runtimeBaseURL,
            format: format,
            json: json
        )
    }
}

struct SetSwitch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set-switch", abstract: "Set or toggle a UISwitch by selector")

    @Argument(help: "Text, label, identifier, or visible option title to target") var selector: String
    @Argument(help: "Switch value: on, off, or toggle") var value: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Select one matching selector candidate by 1-based index") var index: Int?
    @Option(help: "Restrict matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Restrict matching to candidate containing point: x,y") var at: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runSemanticSelectorAction(
            action: .setSwitch,
            sourceCommand: "set-switch",
            selector: selector,
            target: target,
            host: host,
            port: port,
            switchValue: value,
            index: index,
            within: within,
            at: at,
            runtimeBaseURL: runtimeBaseURL,
            format: format,
            json: json
        )
    }
}

struct Ledger: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ledger", abstract: "Read recent embedded runtime request and action ledger")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767")
    var runtimeBaseURL: String?
    @Option(help: "Maximum ledger entries to return") var limit: Int = 50
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Emit JSON Lines entries instead of an envelope") var jsonl = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let request = TKRuntimeLedgerRequest(limit: limit)
            let data: Data
            if let runtimeBaseURL {
                data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.runtimeLedger, queryItems: [
                    URLQueryItem(name: "limit", value: String(request.limit))
                ])
            } else {
                let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json || jsonl)
                let payload = try JSONEncoder().encode(request)
                data = try await client.request(type: "runtimeLedger", payload: payload)
            }
            let response = try JSONDecoder().decode(TKRuntimeLedgerResponse.self, from: data)
            if jsonl {
                for entry in response.entries {
                    print(try encodeCompactJSON(entry))
                }
            } else {
                try printLedger(response, format: outputFormat)
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
        }
    }
}
