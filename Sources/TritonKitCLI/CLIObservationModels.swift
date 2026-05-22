import ArgumentParser
import TritonKitShared

enum ObservationPlatform: String, ExpressibleByArgument {
    case ios
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
    let sources: [ObserveSourceOutput]
    let nodes: [ObserveNodeOutput]
    let artifacts: [String]
    let sourceCommands: [String]
    let note: String
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
