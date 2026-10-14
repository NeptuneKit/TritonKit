import CryptoKit
import Foundation
import TritonKitShared

struct TKAppMapMergeResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let evidenceDir: String
    let mapDir: String
    let projectedWorkspace: Bool
    let screenCount: Int
    let transitionCount: Int
    let pathCount: Int
    let suiteCount: Int
    let screenIDs: [String]
    let transitionIDs: [String]
    let pathIDs: [String]

    init(
        evidenceDir: String,
        mapDir: String,
        projectedWorkspace: Bool,
        screenIDs: [String],
        transitionIDs: [String],
        pathIDs: [String],
        suiteCount: Int
    ) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.app-map.merge-result"
        self.evidenceDir = evidenceDir
        self.mapDir = mapDir
        self.projectedWorkspace = projectedWorkspace
        self.screenCount = screenIDs.count
        self.transitionCount = transitionIDs.count
        self.pathCount = pathIDs.count
        self.suiteCount = suiteCount
        self.screenIDs = screenIDs
        self.transitionIDs = transitionIDs
        self.pathIDs = pathIDs
    }
}

struct TKAppMapInspectResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let screenCount: Int
    let transitionCount: Int
    let pathCount: Int
    let suiteCount: Int
    let coverage: TKAppMapCoverage
    let health: TKAppMapHealth
}

struct TKAppMapPathsResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let pathCount: Int
    let paths: [TKAppMapPath]
    let totalCount: Int
    let returnedCount: Int
    let truncated: Bool
    let nextOffset: Int?
}

struct TKAppMapScreensResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let screenCount: Int
    let screens: [TKAppMapScreen]
    let totalCount: Int
    let returnedCount: Int
    let truncated: Bool
    let nextOffset: Int?
}

struct TKAppMapTransitionsResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let transitionCount: Int
    let transitions: [TKAppMapTransition]
    let totalCount: Int
    let returnedCount: Int
    let truncated: Bool
    let nextOffset: Int?
}

struct TKAppMapPathShowResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let path: TKAppMapPath
    let screens: [TKAppMapScreen]
    let transitions: [TKAppMapTransition]
}

struct TKAppMapPathMutationResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let path: TKAppMapPath
}

struct TKAppMapHealthResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let health: TKAppMapHealth
    let pathCount: Int
    let stateCount: Int
    let transitionCount: Int
    let failingPathIDs: [String]
    let unconfirmedPathIDs: [String]
    let unreplayablePathIDs: [String]
    let uncoveredScreenIDs: [String]
    let uncoveredTransitionIDs: [String]
    let unhealthyStateRefs: [String]
    let unhealthyTransitionIDs: [String]
    let stateHealth: [TKAppMapStateHealth]
    let transitionHealth: [TKAppMapTransitionHealth]

    enum CodingKeys: String, CodingKey {
        case ok
        case schemaVersion
        case kind
        case mapDir
        case health
        case pathCount
        case stateCount
        case transitionCount
        case failingPathIDs = "failingPathIds"
        case unconfirmedPathIDs = "unconfirmedPathIds"
        case unreplayablePathIDs = "unreplayablePathIds"
        case uncoveredScreenIDs = "uncoveredScreenIds"
        case uncoveredTransitionIDs = "uncoveredTransitionIds"
        case unhealthyStateRefs
        case unhealthyTransitionIDs = "unhealthyTransitionIds"
        case stateHealth
        case transitionHealth
    }
}

struct TKAppMapStateHealth: Codable, Equatable {
    let screenID: String
    let stateID: String
    let ref: String
    let status: String
    let sourceRuns: [String]
    let evidenceRefs: [String]
    let issueCodes: [String]

    enum CodingKeys: String, CodingKey {
        case screenID = "screenId"
        case stateID = "stateId"
        case ref
        case status
        case sourceRuns
        case evidenceRefs
        case issueCodes
    }
}

struct TKAppMapTransitionHealth: Codable, Equatable {
    let transitionID: String
    let fromScreenID: String
    let toScreenID: String
    let status: String
    let replayable: Bool
    let coveredByPathIDs: [String]
    let coveredBySuite: Bool
    let sourceRuns: [String]
    let issueCodes: [String]

    enum CodingKeys: String, CodingKey {
        case transitionID = "transitionId"
        case fromScreenID = "fromScreenId"
        case toScreenID = "toScreenId"
        case status
        case replayable
        case coveredByPathIDs = "coveredByPathIds"
        case coveredBySuite
        case sourceRuns
        case issueCodes
    }
}

struct TKAppMapVLMHealthResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let providerCount: Int
    let providers: [TKAppMapVLMProviderSummary]
}

struct TKAppMapSuiteInspectResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let suite: TKAppMapSuite
    let paths: [TKAppMapPath]
}

struct TKAppMapSuiteMutationResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let suite: TKAppMapSuite
    let paths: [TKAppMapPath]
}

struct TKAppMapSuiteRunResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let suiteID: String
    let evidenceRoot: String
    let status: String
    let pathCount: Int
    let passedCount: Int
    let failedCount: Int
    let stoppedOnFailure: Bool
    let results: [TKAppMapSuiteRunPathResult]

    enum CodingKeys: String, CodingKey {
        case ok
        case schemaVersion
        case kind
        case mapDir
        case suiteID = "suiteId"
        case evidenceRoot
        case status
        case pathCount
        case passedCount
        case failedCount
        case stoppedOnFailure
        case results
    }
}

struct TKAppMapSuiteRunPathResult: Codable, Equatable {
    let pathID: String
    let status: String
    let flow: String
    let evidenceDir: String
    let runID: String?
    let failure: TKTestRunFailure?

    enum CodingKeys: String, CodingKey {
        case pathID = "pathId"
        case status
        case flow
        case evidenceDir
        case runID = "runId"
        case failure
    }
}

struct TKAppMapExportFlowResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let pathID: String
    let output: String
    let stepCount: Int
    let requiresVLM: Bool
    let suggestedCommands: [String]
}

struct TKAppMapViewerResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let output: String
    let bytes: Int
    let screenCount: Int
    let transitionCount: Int
    let pathCount: Int
    let suiteCount: Int
}

struct TKAppMapDocument: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let app: TKAppMapApp
    let screenCount: Int
    let transitionCount: Int
    let pathCount: Int
    let suiteCount: Int
    let coverage: TKAppMapCoverage?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case app
        case screenCount
        case transitionCount
        case pathCount
        case suiteCount
        case coverage
        case updatedAt
    }

    init(
        schemaVersion: Int,
        kind: String,
        app: TKAppMapApp,
        screenCount: Int,
        transitionCount: Int,
        pathCount: Int,
        suiteCount: Int,
        coverage: TKAppMapCoverage? = nil,
        updatedAt: String
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.app = app
        self.screenCount = screenCount
        self.transitionCount = transitionCount
        self.pathCount = pathCount
        self.suiteCount = suiteCount
        self.coverage = coverage
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        kind = try container.decode(String.self, forKey: .kind)
        app = try container.decode(TKAppMapApp.self, forKey: .app)
        screenCount = try container.decode(Int.self, forKey: .screenCount)
        transitionCount = try container.decode(Int.self, forKey: .transitionCount)
        pathCount = try container.decode(Int.self, forKey: .pathCount)
        suiteCount = try container.decode(Int.self, forKey: .suiteCount)
        coverage = try container.decodeIfPresent(TKAppMapCoverage.self, forKey: .coverage)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
}

struct TKAppMapApp: Codable, Equatable {
    let bundleID: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case bundleID = "bundleId"
        case platform
    }
}

struct TKAppMapCoverage: Codable, Equatable {
    let observedRuns: Int
    let screenCount: Int
    let stateCount: Int
    let transitionCount: Int
    let pathCount: Int
    let suiteCount: Int
    let confirmedPathCount: Int
    let replayablePathCount: Int
    let passCount: Int
    let failCount: Int
    let flakeCount: Int
}

struct TKAppMapStateVariant: Codable, Equatable {
    let stateID: String
    let runLocalScreenID: String
    let phase: String?
    let sourceRuns: [String]
    let evidenceRefs: [String]
    let visibleTexts: [String]

    enum CodingKeys: String, CodingKey {
        case stateID = "stateId"
        case runLocalScreenID = "runLocalScreenId"
        case phase
        case sourceRuns
        case evidenceRefs
        case visibleTexts
    }
}

struct TKAppMapScreen: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let screenID: String
    let fingerprint: TKScreenWorkspaceFingerprint
    let primaryText: String?
    let visibleTexts: [String]
    let runLocalScreenIDs: [String]
    let sourceRuns: [String]
    let stateVariants: [TKAppMapStateVariant]
    let vlmHealth: TKAppMapVLMHealth?

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case screenID = "screenId"
        case fingerprint
        case primaryText
        case visibleTexts
        case runLocalScreenIDs = "runLocalScreenIds"
        case sourceRuns
        case stateVariants
        case vlmHealth
    }

    init(
        schemaVersion: Int,
        kind: String,
        screenID: String,
        fingerprint: TKScreenWorkspaceFingerprint,
        primaryText: String?,
        visibleTexts: [String],
        runLocalScreenIDs: [String],
        sourceRuns: [String],
        stateVariants: [TKAppMapStateVariant] = [],
        vlmHealth: TKAppMapVLMHealth? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.screenID = screenID
        self.fingerprint = fingerprint
        self.primaryText = primaryText
        self.visibleTexts = visibleTexts
        self.runLocalScreenIDs = runLocalScreenIDs
        self.sourceRuns = sourceRuns
        self.stateVariants = stateVariants
        self.vlmHealth = vlmHealth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        kind = try container.decode(String.self, forKey: .kind)
        screenID = try container.decode(String.self, forKey: .screenID)
        fingerprint = try container.decode(TKScreenWorkspaceFingerprint.self, forKey: .fingerprint)
        primaryText = try container.decodeIfPresent(String.self, forKey: .primaryText)
        visibleTexts = try container.decode([String].self, forKey: .visibleTexts)
        runLocalScreenIDs = try container.decodeIfPresent([String].self, forKey: .runLocalScreenIDs) ?? []
        sourceRuns = try container.decodeIfPresent([String].self, forKey: .sourceRuns) ?? []
        stateVariants = try container.decodeIfPresent([TKAppMapStateVariant].self, forKey: .stateVariants) ?? []
        vlmHealth = try container.decodeIfPresent(TKAppMapVLMHealth.self, forKey: .vlmHealth)
    }
}

struct TKAppMapTransition: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let transitionID: String
    let fromScreenID: String
    let toScreenID: String
    let triggerStepIndex: Int
    let trigger: TKAppMapTransitionTrigger
    let changed: Bool
    let replayable: Bool
    let status: String
    let sourceRuns: [String]
    let vlmHealth: TKAppMapVLMHealth?

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case transitionID = "transitionId"
        case fromScreenID = "fromScreenId"
        case toScreenID = "toScreenId"
        case triggerStepIndex
        case trigger
        case changed
        case replayable
        case status
        case sourceRuns
        case vlmHealth
    }
}

struct TKAppMapTransitionTrigger: Codable, Equatable {
    let type: String
    let point: TKAppMapPoint?
    let target: String?

    init(type: String, point: TKAppMapPoint? = nil, target: String? = nil) {
        self.type = type
        self.point = point
        self.target = target
    }

    enum CodingKeys: String, CodingKey {
        case type
        case point
        case target
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        point = try container.decodeIfPresent(TKAppMapPoint.self, forKey: .point)
        target = try container.decodeIfPresent(String.self, forKey: .target)
    }
}

struct TKAppMapPoint: Codable, Equatable {
    let x: Double
    let y: Double
    let coordinateSpace: String
}

struct TKAppMapPath: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let pathID: String
    let name: String
    let status: String
    let confirmed: Bool
    let startScreenID: String
    let endScreenID: String
    let transitions: [String]
    let health: TKAppMapHealth
    let replayable: Bool
    let sourceRuns: [String]
    let source: String
    let vlmHealth: TKAppMapVLMHealth?
    let requiresVLM: Bool
    let suggestedCommands: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case pathID = "pathId"
        case name
        case status
        case confirmed
        case startScreenID = "startScreenId"
        case endScreenID = "endScreenId"
        case transitions
        case health
        case replayable
        case sourceRuns
        case source
        case vlmHealth
        case requiresVLM
        case suggestedCommands
    }

    init(
        schemaVersion: Int,
        kind: String,
        pathID: String,
        name: String,
        status: String,
        confirmed: Bool,
        startScreenID: String,
        endScreenID: String,
        transitions: [String],
        health: TKAppMapHealth,
        replayable: Bool,
        sourceRuns: [String],
        source: String = "deterministic",
        vlmHealth: TKAppMapVLMHealth? = nil,
        requiresVLM: Bool = false,
        suggestedCommands: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.pathID = pathID
        self.name = name
        self.status = status
        self.confirmed = confirmed
        self.startScreenID = startScreenID
        self.endScreenID = endScreenID
        self.transitions = transitions
        self.health = health
        self.replayable = replayable
        self.sourceRuns = sourceRuns
        self.source = source
        self.vlmHealth = vlmHealth
        self.requiresVLM = requiresVLM
        self.suggestedCommands = suggestedCommands
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        kind = try container.decode(String.self, forKey: .kind)
        pathID = try container.decode(String.self, forKey: .pathID)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(String.self, forKey: .status)
        confirmed = try container.decode(Bool.self, forKey: .confirmed)
        startScreenID = try container.decode(String.self, forKey: .startScreenID)
        endScreenID = try container.decode(String.self, forKey: .endScreenID)
        transitions = try container.decode([String].self, forKey: .transitions)
        health = try container.decode(TKAppMapHealth.self, forKey: .health)
        replayable = try container.decode(Bool.self, forKey: .replayable)
        sourceRuns = try container.decodeIfPresent([String].self, forKey: .sourceRuns) ?? []
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "deterministic"
        vlmHealth = try container.decodeIfPresent(TKAppMapVLMHealth.self, forKey: .vlmHealth)
        requiresVLM = try container.decodeIfPresent(Bool.self, forKey: .requiresVLM)
            ?? appMapPathHasVLMProvenance(source: source, vlmHealth: vlmHealth)
        suggestedCommands = try container.decodeIfPresent([String].self, forKey: .suggestedCommands) ?? []
    }
}

struct TKAppMapSuite: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let suiteID: String
    let name: String
    let paths: [String]
    let policy: TKAppMapSuitePolicy

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case suiteID = "suiteId"
        case name
        case paths
        case policy
    }
}

struct TKAppMapSuitePolicy: Codable, Equatable {
    let strict: Bool
    let stopOnFailure: Bool
}

struct TKAppMapHealth: Codable, Equatable {
    let observedRuns: Int
    let passCount: Int
    let failCount: Int
    let flakeCount: Int
}

func appMapPathHasVLMProvenance(source: String, vlmHealth: TKAppMapVLMHealth?) -> Bool {
    if source == "vlm-assisted" {
        return true
    }
    return vlmHealth?.providers.values.contains { $0.groundingRuns > 0 } == true
}

func appMapPrimaryVLMProvider(_ vlmHealth: TKAppMapVLMHealth?) -> String? {
    vlmHealth?.providers
        .filter { $0.value.groundingRuns > 0 }
        .map(\.key)
        .sorted()
        .first
}

func appMapPathRequiresVLM(_ path: TKAppMapPath) -> Bool {
    path.requiresVLM || appMapPathHasVLMProvenance(source: path.source, vlmHealth: path.vlmHealth)
}

func appMapPathFlowURL(mapRoot: URL, pathID: String) -> URL {
    mapRoot.appendingPathComponent("flows/\(pathID).tritontest.yaml")
}

func appMapPathEvidenceURL(mapRoot: URL, pathID: String) -> URL {
    mapRoot.appendingPathComponent("evidence/\(pathID).tritonevidence", isDirectory: true)
}

func appMapPathSuggestedCommands(mapRoot: URL, path: TKAppMapPath) -> [String] {
    guard path.replayable else { return [] }
    let flowURL = appMapPathFlowURL(mapRoot: mapRoot, pathID: path.pathID)
    let evidenceURL = appMapPathEvidenceURL(mapRoot: mapRoot, pathID: path.pathID)
    var runCommand = "triton test run \(shellQuotedEvidencePath(flowURL.path)) --json --evidence-dir \(shellQuotedEvidencePath(evidenceURL.path))"
    if appMapPathRequiresVLM(path) {
        runCommand += " --allow-vlm"
    }
    return [
        "triton map export-flow \(shellQuotedEvidencePath(mapRoot.path)) --path \(path.pathID) --out \(shellQuotedEvidencePath(flowURL.path)) --json",
        runCommand,
    ]
}

func appMapExportFlowSuggestedCommands(outputURL: URL, requiresVLM: Bool) -> [String] {
    let output = shellQuotedEvidencePath(outputURL.path)
    let evidenceDir = shellQuotedEvidencePath(outputURL.deletingPathExtension().path + ".tritonevidence")
    var runCommand = "triton test run \(output) --json --evidence-dir \(evidenceDir)"
    if requiresVLM {
        runCommand += " --allow-vlm"
    }
    return [
        "triton test validate \(output) --json",
        runCommand,
    ]
}

func appMapPathWithSuggestedCommands(_ path: TKAppMapPath, mapRoot: URL) -> TKAppMapPath {
    let requiresVLM = appMapPathRequiresVLM(path)
    return TKAppMapPath(
        schemaVersion: path.schemaVersion,
        kind: path.kind,
        pathID: path.pathID,
        name: path.name,
        status: path.status,
        confirmed: path.confirmed,
        startScreenID: path.startScreenID,
        endScreenID: path.endScreenID,
        transitions: path.transitions,
        health: path.health,
        replayable: path.replayable,
        sourceRuns: path.sourceRuns,
        source: path.source,
        vlmHealth: path.vlmHealth,
        requiresVLM: requiresVLM,
        suggestedCommands: appMapPathSuggestedCommands(mapRoot: mapRoot, path: path)
    )
}

struct TKAppMapVLMHealth: Codable, Equatable {
    let providers: [String: TKAppMapVLMProviderHealth]
}

struct TKAppMapVLMProviderHealth: Codable, Equatable {
    let groundingRuns: Int
    let successCount: Int
    let failureCount: Int
    let targetNotVisibleCount: Int
    let parseFailureCount: Int
    let outOfBoundsCount: Int
    let meanLatencyMs: Double?
    let lastModel: String?
    let lastSeenAt: String?
    let targets: [String]
}

struct TKAppMapVLMProviderSummary: Codable, Equatable {
    let id: String
    let groundingRuns: Int
    let successRate: Double
    let meanLatencyMs: Double?
    let topFailures: [String]
    let targets: [String]
}

struct TKAppMapRunRecord: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let runID: String
    let evidenceDir: String
    let verdict: String?
    let screenCount: Int
    let transitionCount: Int
    let pathCount: Int

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case runID = "runId"
        case evidenceDir
        case verdict
        case screenCount
        case transitionCount
        case pathCount
    }
}

enum TKAppMapError: Error, CustomStringConvertible {
    case missingMap(String)
    case missingPath(String)
    case missingTransition(String)
    case missingScreen(String)
    case missingSuite(String)
    case invalidWorkspace(String)
    case nonReplayablePath(String)
    case unconfirmedPath(String)
    case emptySuite
    case invalidPage

    var description: String {
        switch self {
        case .missingMap(let path):
            return "App map does not exist at \(path)."
        case .missingPath(let pathID):
            return "App map path does not exist: \(pathID)."
        case .missingTransition(let transitionID):
            return "App map transition does not exist: \(transitionID)."
        case .missingScreen(let screenID):
            return "App map screen does not exist: \(screenID)."
        case .missingSuite(let suiteID):
            return "App map suite does not exist: \(suiteID)."
        case .invalidWorkspace(let message):
            return message
        case .nonReplayablePath(let pathID):
            return "App map path is not replayable: \(pathID)."
        case .unconfirmedPath(let pathID):
            return "App map path is not confirmed: \(pathID)."
        case .emptySuite:
            return "An App Map suite must contain at least one path before execution."
        case .invalidPage:
            return "App Map offset must be nonnegative and limit must be between 1 and 1000."
        }
    }
}
