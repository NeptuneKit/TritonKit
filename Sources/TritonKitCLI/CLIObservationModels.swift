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

struct ObserveNodeOutput: Encodable {
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
