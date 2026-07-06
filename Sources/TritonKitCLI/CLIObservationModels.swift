import Foundation
import ArgumentParser
import TritonKitShared

enum ObservationPlatform: String, ExpressibleByArgument {
    case ios
    case android
    case harmony
}

struct ObserveSourceOutput: Encodable {
    let name: String
    let available: Bool
    let reason: String?
    let artifact: String?
    let sourceCommands: [String]
}

struct ObserveNodeOutput: Codable, Equatable {
    let nodeID: String
    let source: String
    let role: String?
    let text: String?
    let identifier: String?
    let frame: TKRect?
    let enabled: Bool?
    let focused: Bool?
    let hidden: Bool?
    let candidateOnly: Bool
    let confidence: Double
    let capabilities: [String]
    let missingCapabilities: [String]
}

struct ObserveNodeAliasOutput: Codable, Equatable {
    let alias: String
    let nodeID: String
    let source: String
    let role: String?
    let text: String?
    let identifier: String?
    let frame: TKRect?
    let enabled: Bool?
    let focused: Bool?
    let hidden: Bool?
    let candidateOnly: Bool
    let confidence: Double
    let capabilities: [String]
    let missingCapabilities: [String]

    init(alias: String, node: ObserveNodeOutput) {
        self.alias = alias
        self.nodeID = node.nodeID
        self.source = node.source
        self.role = node.role
        self.text = node.text
        self.identifier = node.identifier
        self.frame = node.frame
        self.enabled = node.enabled
        self.focused = node.focused
        self.hidden = node.hidden
        self.candidateOnly = node.candidateOnly
        self.confidence = node.confidence
        self.capabilities = node.capabilities
        self.missingCapabilities = node.missingCapabilities
    }

    var node: ObserveNodeOutput {
        ObserveNodeOutput(
            nodeID: nodeID,
            source: source,
            role: role,
            text: text,
            identifier: identifier,
            frame: frame,
            enabled: enabled,
            focused: focused,
            hidden: hidden,
            candidateOnly: candidateOnly,
            confidence: confidence,
            capabilities: capabilities,
            missingCapabilities: missingCapabilities
        )
    }
}

struct ObserveAliasCacheOutput: Encodable {
    let path: String
    let aliasCount: Int
}

struct NodeAliasCache: Codable, Equatable {
    let schemaVersion: Int
    let platform: String
    let target: String
    let capturedAt: String
    let primarySourceName: String?
    let sourceCommands: [String]
    let aliases: [ObserveNodeAliasOutput]

    init(
        schemaVersion: Int = 1,
        platform: String,
        target: String,
        capturedAt: String,
        primarySourceName: String?,
        sourceCommands: [String],
        aliases: [ObserveNodeAliasOutput]
    ) {
        self.schemaVersion = schemaVersion
        self.platform = platform
        self.target = target
        self.capturedAt = capturedAt
        self.primarySourceName = primarySourceName
        self.sourceCommands = sourceCommands
        self.aliases = aliases
    }

    static func filePath(workspace: String) -> String {
        URL(fileURLWithPath: workspace)
            .appendingPathComponent(".triton")
            .appendingPathComponent("node-aliases.json")
            .path
    }
}

struct ObserveOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let capturedAt: String
    let partial: Bool
    let target: String
    let primarySource: ObserveSourceOutput?
    let sources: [ObserveSourceOutput]
    let nodes: [ObserveNodeOutput]
    let outline: [ObserveNodeAliasOutput]?
    let aliasCache: ObserveAliasCacheOutput?
    let artifacts: [String]
    let sourceCommands: [String]
    let note: String

    init(
        ok: Bool,
        action: String,
        platform: String,
        capturedAt: String,
        partial: Bool,
        target: String,
        primarySource: ObserveSourceOutput? = nil,
        sources: [ObserveSourceOutput],
        nodes: [ObserveNodeOutput],
        outline: [ObserveNodeAliasOutput]? = nil,
        aliasCache: ObserveAliasCacheOutput? = nil,
        artifacts: [String],
        sourceCommands: [String],
        note: String
    ) {
        self.ok = ok
        self.action = action
        self.platform = platform
        self.capturedAt = capturedAt
        self.partial = partial
        self.target = target
        self.sources = sources
        self.primarySource = primarySource ?? Self.defaultPrimarySource(from: sources)
        self.nodes = nodes
        self.outline = outline
        self.aliasCache = aliasCache
        self.artifacts = artifacts
        self.sourceCommands = sourceCommands
        self.note = note
    }

    private static func defaultPrimarySource(from sources: [ObserveSourceOutput]) -> ObserveSourceOutput? {
        let available = sources.filter(\.available)
        let priority = ["runtime-tree", "android-bridge", "host-layout", "webview-provider"]

        for name in priority {
            if let source = available.first(where: { $0.name == name }) {
                return source
            }
        }
        return available.first ?? sources.first
    }
}

struct NodeResolveOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let query: String
    let matchIndex: Int
    let matchCount: Int
    let node: ObserveNodeOutput
    let candidates: [ObserveNodeOutput]?
    let sourceCommands: [String]
}

enum NodeAliasResolutionError: Error, Equatable {
    case cacheMissing(path: String, platform: String, target: String)
    case invalidAlias(String)
    case aliasNotFound(alias: String, path: String, platform: String, target: String, availableAliases: [String])
    case staleAlias(alias: String, expectedPlatform: String, expectedTarget: String, cachedPlatform: String, cachedTarget: String)

    var code: String {
        switch self {
        case .cacheMissing, .aliasNotFound:
            "node_alias_not_found"
        case .invalidAlias:
            "validation_failed"
        case .staleAlias:
            "stale_node_alias"
        }
    }

    var message: String {
        switch self {
        case .cacheMissing(let path, _, _):
            "Node alias cache is missing at \(path)."
        case .invalidAlias(let alias):
            "Node alias must use @<number>, got \(alias)."
        case .aliasNotFound(let alias, let path, _, _, let availableAliases):
            "Node alias \(alias) was not found in \(path). Available aliases: \(availableAliases.joined(separator: ", "))."
        case .staleAlias(let alias, let expectedPlatform, let expectedTarget, let cachedPlatform, let cachedTarget):
            "Node alias \(alias) was captured for \(cachedPlatform) \(cachedTarget), not \(expectedPlatform) \(expectedTarget)."
        }
    }

    var recoveryPlatformAndTarget: (platform: String, target: String)? {
        switch self {
        case .cacheMissing(_, let platform, let target),
             .aliasNotFound(_, _, let platform, let target, _):
            (platform, target)
        case .staleAlias(_, let expectedPlatform, let expectedTarget, _, _):
            (expectedPlatform, expectedTarget)
        case .invalidAlias:
            nil
        }
    }

    func detail(endpoint: String? = nil) -> TKCLIErrorDetail {
        let recovery = recoveryPlatformAndTarget
        return TKCLIErrorDetail(
            code: code,
            message: message,
            endpoint: endpoint,
            hint: recovery.map { "Run `triton observe tree --platform \($0.platform) --device \($0.target) --outline --json` to refresh node aliases." }
                ?? "Use a node alias such as @1 from `triton observe tree --outline --json`.",
            nextAction: recovery.map {
                TKCLINextAction(command: "observe", args: ["tree", "--platform", $0.platform, "--device", $0.target, "--outline", "--json"])
            }
        )
    }
}
