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
    let health: TKAppMapHealth
}

struct TKAppMapPathsResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let pathCount: Int
    let paths: [TKAppMapPath]
}

struct TKAppMapScreensResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let screenCount: Int
    let screens: [TKAppMapScreen]
}

struct TKAppMapTransitionsResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let transitionCount: Int
    let transitions: [TKAppMapTransition]
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

struct TKAppMapHealthResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let health: TKAppMapHealth
    let pathCount: Int
    let failingPathIDs: [String]
    let unconfirmedPathIDs: [String]
    let unreplayablePathIDs: [String]
    let uncoveredScreenIDs: [String]
    let uncoveredTransitionIDs: [String]

    enum CodingKeys: String, CodingKey {
        case ok
        case schemaVersion
        case kind
        case mapDir
        case health
        case pathCount
        case failingPathIDs = "failingPathIds"
        case unconfirmedPathIDs = "unconfirmedPathIds"
        case unreplayablePathIDs = "unreplayablePathIds"
        case uncoveredScreenIDs = "uncoveredScreenIds"
        case uncoveredTransitionIDs = "uncoveredTransitionIds"
    }
}

struct TKAppMapSuiteInspectResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let suite: TKAppMapSuite
    let paths: [TKAppMapPath]
}

struct TKAppMapExportFlowResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let mapDir: String
    let pathID: String
    let output: String
    let stepCount: Int
}

struct TKAppMapDocument: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let app: TKAppMapApp
    let screenCount: Int
    let transitionCount: Int
    let pathCount: Int
    let suiteCount: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case app
        case screenCount
        case transitionCount
        case pathCount
        case suiteCount
        case updatedAt
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

struct TKAppMapScreen: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let screenID: String
    let fingerprint: TKScreenWorkspaceFingerprint
    let primaryText: String?
    let visibleTexts: [String]
    let runLocalScreenIDs: [String]
    let sourceRuns: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case screenID = "screenId"
        case fingerprint
        case primaryText
        case visibleTexts
        case runLocalScreenIDs = "runLocalScreenIds"
        case sourceRuns
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
    }
}

struct TKAppMapTransitionTrigger: Codable, Equatable {
    let type: String
    let point: TKAppMapPoint?
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
        sourceRuns: [String]
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
        }
    }
}

@discardableResult
func projectEvidenceWorkspace(evidencePath: String) throws -> TKScreenWorkspaceProjectionResponse {
    try projectScreenWorkspace(evidencePath: evidencePath)
}

func mergeTritonAppMap(
    evidencePath: String,
    into mapPath: String,
    confirm: Bool
) throws -> TKAppMapMergeResponse {
    let evidenceRoot = evidenceBundleRoot(from: evidencePath)
    let mapRoot = URL(fileURLWithPath: mapPath, isDirectory: true)
    let screensURL = evidenceRoot.appendingPathComponent("screens.json")
    let transitionsURL = evidenceRoot.appendingPathComponent("transitions.json")
    let projectedWorkspace = !FileManager.default.fileExists(atPath: screensURL.path)
        || !FileManager.default.fileExists(atPath: transitionsURL.path)
    if projectedWorkspace {
        _ = try projectEvidenceWorkspace(evidencePath: evidencePath)
    }

    let manifest = try readEvidenceManifest(from: evidencePath)
    let screens = try decodeJSON(TKScreenWorkspaceScreensDocument.self, from: screensURL)
    let transitions = try decodeJSON(TKScreenWorkspaceTransitionsDocument.self, from: transitionsURL)
    let normalizedPlan = readNormalizedPlan(from: evidenceRoot)
    let app = TKAppMapApp(
        bundleID: normalizedPlan?.app.bundleId ?? manifest.target?.bundleIdentifier ?? "unknown.bundle",
        platform: normalizedPlan?.device.platform ?? manifest.target?.osDescription ?? "unknown"
    )

    try prepareAppMapDirectories(mapRoot)

    let runID = screens.runID
    var runLocalToMapScreen: [String: String] = [:]
    var screenIDs: [String] = []
    for screen in screens.screens {
        let mapScreenID = mapScreenID(for: screen.fingerprint)
        runLocalToMapScreen[screen.screenID] = mapScreenID
        let screenURL = mapRoot.appendingPathComponent("screens/\(mapScreenID).json")
        let existing = try? decodeJSON(TKAppMapScreen.self, from: screenURL)
        let merged = TKAppMapScreen(
            schemaVersion: 1,
            kind: "triton.app-map.screen",
            screenID: mapScreenID,
            fingerprint: screen.fingerprint,
            primaryText: existing?.primaryText ?? screen.primaryText,
            visibleTexts: unique((existing?.visibleTexts ?? []) + screen.visibleTexts),
            runLocalScreenIDs: unique((existing?.runLocalScreenIDs ?? []) + [screen.screenID]),
            sourceRuns: unique((existing?.sourceRuns ?? []) + [runID])
        )
        try prettyEncodedData(merged).write(to: screenURL, options: .atomic)
        screenIDs.append(mapScreenID)
    }

    var transitionIDs: [String] = []
    for transition in transitions.transitions {
        guard let fromScreenID = runLocalToMapScreen[transition.fromScreenID],
              let toScreenID = runLocalToMapScreen[transition.toScreenID]
        else {
            continue
        }
        let triggerPoint = transition.trigger.point.map {
            TKAppMapPoint(
                x: $0.x,
                y: $0.y,
                coordinateSpace: transition.trigger.coordinateSpace ?? "runtime-point"
            )
        }
        let trigger = TKAppMapTransitionTrigger(type: transition.trigger.type, point: triggerPoint)
        let transitionID = mapTransitionID(
            fromScreenID: fromScreenID,
            toScreenID: toScreenID,
            stepIndex: transition.stepIndex,
            trigger: trigger
        )
        let transitionURL = mapRoot.appendingPathComponent("transitions/\(transitionID).json")
        let existing = try? decodeJSON(TKAppMapTransition.self, from: transitionURL)
        let merged = TKAppMapTransition(
            schemaVersion: 1,
            kind: "triton.app-map.transition",
            transitionID: transitionID,
            fromScreenID: fromScreenID,
            toScreenID: toScreenID,
            triggerStepIndex: transition.stepIndex,
            trigger: trigger,
            changed: true,
            replayable: transition.trigger.replayable,
            status: "observed",
            sourceRuns: unique((existing?.sourceRuns ?? []) + [runID])
        )
        try prettyEncodedData(merged).write(to: transitionURL, options: .atomic)
        transitionIDs.append(transitionID)
    }

    let pathIDs = try writeCandidatePath(
        transitionIDs: transitionIDs,
        mapRoot: mapRoot,
        runID: runID,
        verdict: manifest.run?.summary?.verdict,
        confirm: confirm
    )
    try writeSmokeSuite(mapRoot)
    try writeRunRecord(
        mapRoot: mapRoot,
        runID: runID,
        evidenceDir: evidenceRoot.path,
        verdict: manifest.run?.summary?.verdict,
        screenCount: screenIDs.count,
        transitionCount: transitionIDs.count,
        pathCount: pathIDs.count
    )
    try writeAppMapIndex(mapRoot: mapRoot, app: app)

    let inspect = try inspectTritonAppMap(mapPath: mapRoot.path)
    return TKAppMapMergeResponse(
        evidenceDir: evidenceRoot.path,
        mapDir: mapRoot.path,
        projectedWorkspace: projectedWorkspace,
        screenIDs: screenIDs,
        transitionIDs: transitionIDs,
        pathIDs: pathIDs,
        suiteCount: inspect.suiteCount
    )
}

func inspectTritonAppMap(mapPath: String) throws -> TKAppMapInspectResponse {
    let mapRoot = URL(fileURLWithPath: mapPath, isDirectory: true)
    guard FileManager.default.fileExists(atPath: mapRoot.appendingPathComponent("app-map.json").path) else {
        throw TKAppMapError.missingMap(mapPath)
    }
    let screenCount = try jsonFileCount(in: mapRoot.appendingPathComponent("screens", isDirectory: true))
    let transitionCount = try jsonFileCount(in: mapRoot.appendingPathComponent("transitions", isDirectory: true))
    let pathCount = try jsonFileCount(in: mapRoot.appendingPathComponent("paths", isDirectory: true))
    let suiteCount = try jsonFileCount(in: mapRoot.appendingPathComponent("suites", isDirectory: true))
    return TKAppMapInspectResponse(
        ok: true,
        schemaVersion: 1,
        kind: "triton.app-map.inspect-result",
        mapDir: mapRoot.path,
        screenCount: screenCount,
        transitionCount: transitionCount,
        pathCount: pathCount,
        suiteCount: suiteCount,
        health: try appMapHealth(mapRoot)
    )
}

func listTritonAppMapPaths(mapPath: String) throws -> TKAppMapPathsResponse {
    let mapRoot = URL(fileURLWithPath: mapPath, isDirectory: true)
    guard FileManager.default.fileExists(atPath: mapRoot.appendingPathComponent("app-map.json").path) else {
        throw TKAppMapError.missingMap(mapPath)
    }
    let paths = try jsonFiles(in: mapRoot.appendingPathComponent("paths", isDirectory: true))
        .map { try decodeJSON(TKAppMapPath.self, from: $0) }
        .sorted { $0.pathID < $1.pathID }
    return TKAppMapPathsResponse(
        ok: true,
        schemaVersion: 1,
        kind: "triton.app-map.paths-result",
        mapDir: mapRoot.path,
        pathCount: paths.count,
        paths: paths
    )
}

func listTritonAppMapScreens(mapPath: String) throws -> TKAppMapScreensResponse {
    let mapRoot = try requireAppMapRoot(mapPath)
    let screens = try readAllMapScreens(mapRoot: mapRoot)
    return TKAppMapScreensResponse(
        ok: true,
        schemaVersion: 1,
        kind: "triton.app-map.screens-result",
        mapDir: mapRoot.path,
        screenCount: screens.count,
        screens: screens
    )
}

func listTritonAppMapTransitions(mapPath: String) throws -> TKAppMapTransitionsResponse {
    let mapRoot = try requireAppMapRoot(mapPath)
    let transitions = try readAllMapTransitions(mapRoot: mapRoot)
    return TKAppMapTransitionsResponse(
        ok: true,
        schemaVersion: 1,
        kind: "triton.app-map.transitions-result",
        mapDir: mapRoot.path,
        transitionCount: transitions.count,
        transitions: transitions
    )
}

func showTritonAppMapPath(mapPath: String, pathID: String) throws -> TKAppMapPathShowResponse {
    let mapRoot = try requireAppMapRoot(mapPath)
    let path = try readMapPath(mapRoot: mapRoot, pathID: pathID)
    let transitions = try path.transitions.map { transitionID in
        try readMapTransition(mapRoot: mapRoot, transitionID: transitionID)
    }
    let screenIDs = unique([path.startScreenID, path.endScreenID] + transitions.flatMap { [$0.fromScreenID, $0.toScreenID] })
    let screens = try screenIDs.map { try readMapScreen(mapRoot: mapRoot, screenID: $0) }
    return TKAppMapPathShowResponse(
        ok: true,
        schemaVersion: 1,
        kind: "triton.app-map.path-show-result",
        mapDir: mapRoot.path,
        path: path,
        screens: screens,
        transitions: transitions
    )
}

func inspectTritonAppMapHealth(mapPath: String) throws -> TKAppMapHealthResponse {
    let mapRoot = try requireAppMapRoot(mapPath)
    let screens = try readAllMapScreens(mapRoot: mapRoot)
    let transitions = try readAllMapTransitions(mapRoot: mapRoot)
    let paths = try readAllMapPaths(mapRoot: mapRoot)
    let suitePaths = try readSuiteCoveredPathIDs(mapRoot: mapRoot)
    let pathScreenIDs = Set(paths.flatMap { [$0.startScreenID, $0.endScreenID] })
    let pathTransitionIDs = Set(paths.filter { suitePaths.contains($0.pathID) }.flatMap(\.transitions))
    return TKAppMapHealthResponse(
        ok: true,
        schemaVersion: 1,
        kind: "triton.app-map.health-result",
        mapDir: mapRoot.path,
        health: try appMapHealth(mapRoot),
        pathCount: paths.count,
        failingPathIDs: paths.filter { $0.health.failCount > 0 }.map(\.pathID).sorted(),
        unconfirmedPathIDs: paths.filter { !$0.confirmed }.map(\.pathID).sorted(),
        unreplayablePathIDs: paths.filter { !$0.replayable }.map(\.pathID).sorted(),
        uncoveredScreenIDs: screens.map(\.screenID).filter { !pathScreenIDs.contains($0) }.sorted(),
        uncoveredTransitionIDs: transitions.map(\.transitionID).filter { !pathTransitionIDs.contains($0) }.sorted()
    )
}

func inspectTritonAppMapSuite(mapPath: String, suiteID: String) throws -> TKAppMapSuiteInspectResponse {
    let mapRoot = try requireAppMapRoot(mapPath)
    let suite = try readMapSuite(mapRoot: mapRoot, suiteID: suiteID)
    let paths = try suite.paths.map { try readMapPath(mapRoot: mapRoot, pathID: $0) }
    return TKAppMapSuiteInspectResponse(
        ok: true,
        schemaVersion: 1,
        kind: "triton.app-map.suite-inspect-result",
        mapDir: mapRoot.path,
        suite: suite,
        paths: paths
    )
}

func exportTritonAppMapFlow(
    mapPath: String,
    pathID: String,
    output: String
) throws -> TKAppMapExportFlowResponse {
    let mapRoot = URL(fileURLWithPath: mapPath, isDirectory: true)
    let appMapURL = mapRoot.appendingPathComponent("app-map.json")
    guard FileManager.default.fileExists(atPath: appMapURL.path) else {
        throw TKAppMapError.missingMap(mapPath)
    }
    let appMap = try decodeJSON(TKAppMapDocument.self, from: appMapURL)
    let pathURL = mapRoot.appendingPathComponent("paths/\(pathID).json")
    guard FileManager.default.fileExists(atPath: pathURL.path) else {
        throw TKAppMapError.missingPath(pathID)
    }
    let path = try decodeJSON(TKAppMapPath.self, from: pathURL)
    guard path.replayable else {
        throw TKAppMapError.nonReplayablePath(pathID)
    }
    let transitions = try path.transitions.map { transitionID -> TKAppMapTransition in
        let url = mapRoot.appendingPathComponent("transitions/\(transitionID).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TKAppMapError.missingTransition(transitionID)
        }
        return try decodeJSON(TKAppMapTransition.self, from: url)
    }
    guard let firstTransition = transitions.first else {
        throw TKAppMapError.nonReplayablePath(pathID)
    }
    let startScreen = try readMapScreen(mapRoot: mapRoot, screenID: firstTransition.fromScreenID)
    var stepCount = 3
    var yaml = """
    version: 1
    name: \(pathID.replacingOccurrences(of: "path-", with: ""))
    app:
      bundleId: \(yamlQuoted(appMap.app.bundleID))
    device:
      platform: \(yamlQuoted(appMap.app.platform))
    settings:
      strict: true
    steps:
      - launch: {}
      - takeScreenshot: {}
      - assertVisible:
          text: \(yamlQuoted(startScreen.primaryText ?? ""))
    """

    for transition in transitions {
        guard let point = transition.trigger.point else {
            throw TKAppMapError.nonReplayablePath(pathID)
        }
        let targetScreen = try readMapScreen(mapRoot: mapRoot, screenID: transition.toScreenID)
        yaml += """

          - tap:
              point:
                x: \(formatNumber(point.x))
                y: \(formatNumber(point.y))
                coordinateSpace: \(point.coordinateSpace)
          - assertVisible:
              text: \(yamlQuoted(targetScreen.primaryText ?? ""))
        """
        stepCount += 2
    }
    yaml += "\n"

    let outputURL = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try yaml.write(to: outputURL, atomically: true, encoding: .utf8)
    return TKAppMapExportFlowResponse(
        ok: true,
        schemaVersion: 1,
        kind: "triton.app-map.export-flow-result",
        mapDir: mapRoot.path,
        pathID: pathID,
        output: outputURL.path,
        stepCount: stepCount
    )
}

private func prepareAppMapDirectories(_ mapRoot: URL) throws {
    for path in ["screens", "transitions", "paths", "suites", "runs"] {
        try FileManager.default.createDirectory(
            at: mapRoot.appendingPathComponent(path, isDirectory: true),
            withIntermediateDirectories: true
        )
    }
}

private func writeCandidatePath(
    transitionIDs: [String],
    mapRoot: URL,
    runID: String,
    verdict: TKEvidenceRunVerdict?,
    confirm: Bool
) throws -> [String] {
    guard !transitionIDs.isEmpty else { return [] }
    let transitions = try transitionIDs.map { transitionID in
        try decodeJSON(TKAppMapTransition.self, from: mapRoot.appendingPathComponent("transitions/\(transitionID).json"))
    }.sorted { $0.triggerStepIndex < $1.triggerStepIndex }
    guard let first = transitions.first, let last = transitions.last else { return [] }
    let start = try readMapScreen(mapRoot: mapRoot, screenID: first.fromScreenID)
    let end = try readMapScreen(mapRoot: mapRoot, screenID: last.toScreenID)
    let startName = start.primaryText ?? start.screenID
    let endName = pathEndName(start: startName, end: end.primaryText ?? end.screenID)
    let pathID = "path-\(slug(startName))-\(slug(endName))"
    let pathURL = mapRoot.appendingPathComponent("paths/\(pathID).json")
    let existing = try? decodeJSON(TKAppMapPath.self, from: pathURL)
    let healthUpdate = pathHealthAfterMerge(existing: existing, runID: runID, verdict: verdict)
    let path = TKAppMapPath(
        schemaVersion: 1,
        kind: "triton.app-map.path",
        pathID: pathID,
        name: "\(startName) to \(endName)",
        status: "observed",
        confirmed: existing?.confirmed == true || confirm || verdict == .success,
        startScreenID: first.fromScreenID,
        endScreenID: last.toScreenID,
        transitions: transitions.map(\.transitionID),
        health: healthUpdate.health,
        replayable: transitions.allSatisfy(\.replayable),
        sourceRuns: healthUpdate.sourceRuns
    )
    try prettyEncodedData(path).write(to: pathURL, options: .atomic)
    return [pathID]
}

private func pathHealthAfterMerge(
    existing: TKAppMapPath?,
    runID: String,
    verdict: TKEvidenceRunVerdict?
) -> (health: TKAppMapHealth, sourceRuns: [String]) {
    let base = existing?.health ?? TKAppMapHealth(observedRuns: 0, passCount: 0, failCount: 0, flakeCount: 0)
    let sourceRuns = unique((existing?.sourceRuns ?? []) + [runID])
    guard existing?.sourceRuns.contains(runID) != true else {
        return (base, sourceRuns)
    }
    return (
        TKAppMapHealth(
            observedRuns: base.observedRuns + 1,
            passCount: base.passCount + (verdict == .success ? 1 : 0),
            failCount: base.failCount + (verdict == .failure ? 1 : 0),
            flakeCount: base.flakeCount
        ),
        sourceRuns
    )
}

private func writeSmokeSuite(_ mapRoot: URL) throws {
    let paths = try jsonFiles(in: mapRoot.appendingPathComponent("paths", isDirectory: true))
        .map { try decodeJSON(TKAppMapPath.self, from: $0) }
        .filter { $0.confirmed && $0.replayable }
        .map(\.pathID)
        .sorted()
    let suite = TKAppMapSuite(
        schemaVersion: 1,
        kind: "triton.app-map.suite",
        suiteID: "smoke",
        name: "Smoke",
        paths: paths,
        policy: TKAppMapSuitePolicy(strict: true, stopOnFailure: true)
    )
    try prettyEncodedData(suite).write(to: mapRoot.appendingPathComponent("suites/smoke.json"), options: .atomic)
}

private func writeRunRecord(
    mapRoot: URL,
    runID: String,
    evidenceDir: String,
    verdict: TKEvidenceRunVerdict?,
    screenCount: Int,
    transitionCount: Int,
    pathCount: Int
) throws {
    let record = TKAppMapRunRecord(
        schemaVersion: 1,
        kind: "triton.app-map.run",
        runID: runID,
        evidenceDir: evidenceDir,
        verdict: verdict?.rawValue,
        screenCount: screenCount,
        transitionCount: transitionCount,
        pathCount: pathCount
    )
    try prettyEncodedData(record).write(to: mapRoot.appendingPathComponent("runs/\(runID).json"), options: .atomic)
}

private func writeAppMapIndex(mapRoot: URL, app: TKAppMapApp) throws {
    let screenCount = try jsonFileCount(in: mapRoot.appendingPathComponent("screens", isDirectory: true))
    let transitionCount = try jsonFileCount(in: mapRoot.appendingPathComponent("transitions", isDirectory: true))
    let pathCount = try jsonFileCount(in: mapRoot.appendingPathComponent("paths", isDirectory: true))
    let suiteCount = try jsonFileCount(in: mapRoot.appendingPathComponent("suites", isDirectory: true))
    let document = TKAppMapDocument(
        schemaVersion: 1,
        kind: "triton.app-map",
        app: app,
        screenCount: screenCount,
        transitionCount: transitionCount,
        pathCount: pathCount,
        suiteCount: suiteCount,
        updatedAt: isoTimestamp()
    )
    try prettyEncodedData(document).write(to: mapRoot.appendingPathComponent("app-map.json"), options: .atomic)
}

private func appMapHealth(_ mapRoot: URL) throws -> TKAppMapHealth {
    let runs = try jsonFiles(in: mapRoot.appendingPathComponent("runs", isDirectory: true))
        .map { try decodeJSON(TKAppMapRunRecord.self, from: $0) }
    return TKAppMapHealth(
        observedRuns: runs.count,
        passCount: runs.filter { $0.verdict == "success" }.count,
        failCount: runs.filter { $0.verdict == "failure" }.count,
        flakeCount: 0
    )
}

private func readMapScreen(mapRoot: URL, screenID: String) throws -> TKAppMapScreen {
    let url = mapRoot.appendingPathComponent("screens/\(screenID).json")
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw TKAppMapError.missingScreen(screenID)
    }
    return try decodeJSON(TKAppMapScreen.self, from: url)
}

private func requireAppMapRoot(_ mapPath: String) throws -> URL {
    let mapRoot = URL(fileURLWithPath: mapPath, isDirectory: true)
    guard FileManager.default.fileExists(atPath: mapRoot.appendingPathComponent("app-map.json").path) else {
        throw TKAppMapError.missingMap(mapPath)
    }
    return mapRoot
}

private func readMapTransition(mapRoot: URL, transitionID: String) throws -> TKAppMapTransition {
    let url = mapRoot.appendingPathComponent("transitions/\(transitionID).json")
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw TKAppMapError.missingTransition(transitionID)
    }
    return try decodeJSON(TKAppMapTransition.self, from: url)
}

private func readMapPath(mapRoot: URL, pathID: String) throws -> TKAppMapPath {
    let url = mapRoot.appendingPathComponent("paths/\(pathID).json")
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw TKAppMapError.missingPath(pathID)
    }
    return try decodeJSON(TKAppMapPath.self, from: url)
}

private func readMapSuite(mapRoot: URL, suiteID: String) throws -> TKAppMapSuite {
    let url = mapRoot.appendingPathComponent("suites/\(suiteID).json")
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw TKAppMapError.missingSuite(suiteID)
    }
    return try decodeJSON(TKAppMapSuite.self, from: url)
}

private func readAllMapScreens(mapRoot: URL) throws -> [TKAppMapScreen] {
    try jsonFiles(in: mapRoot.appendingPathComponent("screens", isDirectory: true))
        .map { try decodeJSON(TKAppMapScreen.self, from: $0) }
        .sorted { $0.screenID < $1.screenID }
}

private func readAllMapTransitions(mapRoot: URL) throws -> [TKAppMapTransition] {
    try jsonFiles(in: mapRoot.appendingPathComponent("transitions", isDirectory: true))
        .map { try decodeJSON(TKAppMapTransition.self, from: $0) }
        .sorted { $0.transitionID < $1.transitionID }
}

private func readAllMapPaths(mapRoot: URL) throws -> [TKAppMapPath] {
    try jsonFiles(in: mapRoot.appendingPathComponent("paths", isDirectory: true))
        .map { try decodeJSON(TKAppMapPath.self, from: $0) }
        .sorted { $0.pathID < $1.pathID }
}

private func readSuiteCoveredPathIDs(mapRoot: URL) throws -> Set<String> {
    let suites = try jsonFiles(in: mapRoot.appendingPathComponent("suites", isDirectory: true))
        .map { try decodeJSON(TKAppMapSuite.self, from: $0) }
    return Set(suites.flatMap(\.paths))
}

private func readNormalizedPlan(from evidenceRoot: URL) -> TKTestNormalizedPlan? {
    let url = evidenceRoot.appendingPathComponent("normalized-plan.json")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(TKTestNormalizedPlan.self, from: data)
}

private func decodeJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
}

private func jsonFileCount(in directory: URL) throws -> Int {
    try jsonFiles(in: directory).count
}

private func jsonFiles(in directory: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "json" }
}

private func mapScreenID(for fingerprint: TKScreenWorkspaceFingerprint) -> String {
    let key = "\(fingerprint.screenshotSha256)|\(fingerprint.axTextHash)|\(fingerprint.hierarchySha256)"
    return "screen-\(shortHash(key))"
}

private func mapTransitionID(
    fromScreenID: String,
    toScreenID: String,
    stepIndex: Int,
    trigger: TKAppMapTransitionTrigger
) -> String {
    let point = trigger.point.map { "\($0.x),\($0.y),\($0.coordinateSpace)" } ?? "none"
    return "transition-\(shortHash("\(fromScreenID)|\(toScreenID)|\(stepIndex)|\(trigger.type)|\(point)"))"
}

private func shortHash(_ value: String) -> String {
    let digest = SHA256.hash(data: Data(value.utf8))
    return digest.map { String(format: "%02x", $0) }.joined().prefix(12).description
}

private func slug(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics
    let scalars = value.lowercased().unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let collapsed = String(scalars)
        .split(separator: "-", omittingEmptySubsequences: true)
        .joined(separator: "-")
    return collapsed.isEmpty ? "screen" : collapsed
}

private func pathEndName(start: String, end: String) -> String {
    let startParts = start.split(separator: " ")
    let endParts = end.split(separator: " ")
    guard let firstStart = startParts.first,
          endParts.first == firstStart,
          endParts.count > 1
    else {
        return end
    }
    return endParts.dropFirst().joined(separator: " ")
}

private func yamlQuoted(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
}

private func formatNumber(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(value)
}

private func unique(_ values: [String]) -> [String] {
    var result: [String] = []
    var seen = Set<String>()
    for value in values where seen.insert(value).inserted {
        result.append(value)
    }
    return result
}

private func isoTimestamp(_ date: Date = Date()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}
