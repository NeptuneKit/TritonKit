import CryptoKit
import Foundation

private struct TKWorkspaceAtlasProjectionDocument: Decodable {
    let runID: String
    let app: String
    let screens: [TKWorkspaceAtlasProjectionScreen]
    let states: [TKWorkspaceAtlasProjectionState]
    let transitions: [TKWorkspaceAtlasProjectionTransition]

    enum CodingKeys: String, CodingKey {
        case runID = "runId"
        case app
        case screens
        case states
        case transitions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runID = try container.decodeIfPresent(String.self, forKey: .runID) ?? ""
        app = try container.decodeIfPresent(String.self, forKey: .app) ?? ""
        screens = try container.decodeIfPresent([TKWorkspaceAtlasProjectionScreen].self, forKey: .screens) ?? []
        states = try container.decodeIfPresent([TKWorkspaceAtlasProjectionState].self, forKey: .states) ?? []
        transitions = try container.decodeIfPresent([TKWorkspaceAtlasProjectionTransition].self, forKey: .transitions) ?? []
    }
}

private struct TKWorkspaceAtlasProjectionScreen: Decodable {
    let screenID: String
    let stateID: String?
    let signature: String
    let dominantTexts: [String]
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case screenID = "screenId"
        case stateID = "stateId"
        case signature
        case dominantTexts
        case evidenceRefs
    }
}

private struct TKWorkspaceAtlasProjectionState: Decodable {
    let stateID: String
    let screenID: String
    let phase: String?
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case stateID = "stateId"
        case screenID = "screenId"
        case phase
        case evidenceRefs
    }
}

private struct TKWorkspaceAtlasProjectionTransition: Decodable {
    let transitionID: String
    let fromScreenID: String
    let toScreenID: String
    let action: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case transitionID = "transitionId"
        case fromScreenID = "fromScreenId"
        case toScreenID = "toScreenId"
        case action
        case status
    }
}

private struct TKWorkspaceActionPointArtifact: Decodable {
    let vlmGrounding: TKWorkspaceVLMGroundingPointArtifact?
}

private struct TKWorkspaceVLMGroundingPointArtifact: Decodable {
    let coordinateSpace: String?
    let runtimePoint: TKWorkspaceRuntimePointArtifact?
}

private struct TKWorkspaceRuntimePointArtifact: Decodable {
    let x: Double
    let y: Double
}

struct TKWorkspaceMergeMapResponse: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let runID: String
    let sourceMapRef: String
    let mapDir: String
    let screenCount: Int
    let transitionCount: Int
    let pathCount: Int
    let suiteCount: Int
    let coverage: TKAppMapCoverage
    let pathIDs: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case runID = "runId"
        case sourceMapRef
        case mapDir
        case screenCount
        case transitionCount
        case pathCount
        case suiteCount
        case coverage
        case pathIDs = "pathIds"
    }
}

func projectWorkspaceAtlasAppMap(run: TKWorkspaceRunResponse, runDir: URL) throws {
    let atlasURL = runDir.appendingPathComponent("atlas/atlas.json")
    guard FileManager.default.fileExists(atPath: atlasURL.path) else { return }
    let atlas = try JSONDecoder().decode(
        TKWorkspaceAtlasProjectionDocument.self,
        from: Data(contentsOf: atlasURL)
    )
    let mapRoot = workspaceAppMapRoot(runDir: runDir)
    if FileManager.default.fileExists(atPath: mapRoot.path) {
        try FileManager.default.removeItem(at: mapRoot)
    }
    try workspacePrepareAppMapDirectories(mapRoot)

    let runID = atlas.runID.isEmpty ? run.runID : atlas.runID
    let app = TKAppMapApp(bundleID: atlas.app.isEmpty ? run.app : atlas.app, platform: run.target.platform)
    var localToMapScreenID: [String: String] = [:]
    let statesByScreenID = Dictionary(grouping: atlas.states, by: \.screenID)
    for screen in atlas.screens {
        let fingerprint = workspaceAtlasFingerprint(from: screen.signature)
        let screenID = workspaceMapScreenID(for: fingerprint)
        localToMapScreenID[screen.screenID] = screenID
        let stateVariants = workspaceStateVariants(
            screen: screen,
            states: statesByScreenID[screen.screenID] ?? [],
            runID: runID
        )
        let merged = TKAppMapScreen(
            schemaVersion: 1,
            kind: "triton.app-map.screen",
            screenID: screenID,
            fingerprint: fingerprint,
            primaryText: workspacePrimaryText(screen.dominantTexts),
            visibleTexts: workspaceUnique(screen.dominantTexts),
            runLocalScreenIDs: [screen.screenID],
            sourceRuns: [runID],
            stateVariants: stateVariants,
            vlmHealth: nil
        )
        try prettyEncodedData(merged).write(
            to: mapRoot.appendingPathComponent("screens/\(screenID).json"),
            options: .atomic
        )
    }

    var changedTransitionIDs: [String] = []
    for (index, transition) in atlas.transitions.enumerated() {
        guard let fromScreenID = localToMapScreenID[transition.fromScreenID],
              let toScreenID = localToMapScreenID[transition.toScreenID]
        else {
            continue
        }
        let point = workspaceActionPoint(runDir: runDir, index: index)
        let trigger = TKAppMapTransitionTrigger(type: transition.action, point: point)
        let transitionID = workspaceMapTransitionID(
            fromScreenID: fromScreenID,
            toScreenID: toScreenID,
            stepIndex: index + 1,
            trigger: trigger
        )
        let changed = fromScreenID != toScreenID
        let mapped = TKAppMapTransition(
            schemaVersion: 1,
            kind: "triton.app-map.transition",
            transitionID: transitionID,
            fromScreenID: fromScreenID,
            toScreenID: toScreenID,
            triggerStepIndex: index + 1,
            trigger: trigger,
            changed: changed,
            replayable: point?.coordinateSpace == "runtime-point",
            status: transition.status,
            sourceRuns: [runID],
            vlmHealth: nil
        )
        try prettyEncodedData(mapped).write(
            to: mapRoot.appendingPathComponent("transitions/\(transitionID).json"),
            options: .atomic
        )
        if changed {
            changedTransitionIDs.append(transitionID)
        }
    }

    let pathIDs = try workspaceWriteAppMapPath(
        transitionIDs: changedTransitionIDs,
        mapRoot: mapRoot,
        run: run
    )
    if !pathIDs.isEmpty {
        try workspaceWriteAppMapSuite(mapRoot: mapRoot, pathIDs: pathIDs)
    }
    try workspaceWriteAppMapRunRecord(
        mapRoot: mapRoot,
        run: run,
        screenCount: atlas.screens.count,
        transitionCount: atlas.transitions.count,
        pathCount: pathIDs.count
    )
    try workspaceWriteAppMapIndex(mapRoot: mapRoot, app: app)
}

func mergeWorkspaceRunAppMap(
    runID: String,
    runsDirectory: String,
    mapDirectory: String,
    confirm: Bool = false
) throws -> TKWorkspaceMergeMapResponse {
    let inspected = try inspectWorkspaceRun(runID: runID, runsDirectory: runsDirectory)
    let run = inspected.run
    let runDir = workspaceRunDirectory(runID: run.runID, runsDirectory: runsDirectory)
    let sourceRoot = workspaceAppMapRoot(runDir: runDir)
    let sourceIndexURL = sourceRoot.appendingPathComponent("app-map.json")
    guard FileManager.default.fileExists(atPath: sourceIndexURL.path) else {
        throw RuntimeError("Workspace run \(run.runID) does not have a projected app map at atlas/app-map/app-map.json.")
    }

    let sourceIndex = try JSONDecoder().decode(TKAppMapDocument.self, from: Data(contentsOf: sourceIndexURL))
    let mapRoot = URL(fileURLWithPath: mapDirectory, isDirectory: true)
    try workspacePrepareAppMapDirectories(mapRoot)
    let app = (try? JSONDecoder().decode(
        TKAppMapDocument.self,
        from: Data(contentsOf: mapRoot.appendingPathComponent("app-map.json"))
    ))?.app ?? sourceIndex.app

    for screen in try workspaceReadMapScreens(mapRoot: sourceRoot) {
        let targetURL = mapRoot.appendingPathComponent("screens/\(screen.screenID).json")
        let existing = try? JSONDecoder().decode(TKAppMapScreen.self, from: Data(contentsOf: targetURL))
        let merged = TKAppMapScreen(
            schemaVersion: 1,
            kind: "triton.app-map.screen",
            screenID: screen.screenID,
            fingerprint: screen.fingerprint,
            primaryText: existing?.primaryText ?? screen.primaryText,
            visibleTexts: workspaceUnique((existing?.visibleTexts ?? []) + screen.visibleTexts),
            runLocalScreenIDs: workspaceUnique((existing?.runLocalScreenIDs ?? []) + screen.runLocalScreenIDs),
            sourceRuns: workspaceUnique((existing?.sourceRuns ?? []) + screen.sourceRuns),
            stateVariants: workspaceMergeStateVariants(existing?.stateVariants ?? [], screen.stateVariants),
            vlmHealth: existing?.vlmHealth ?? screen.vlmHealth
        )
        try prettyEncodedData(merged).write(to: targetURL, options: .atomic)
    }

    for transition in try workspaceReadMapTransitions(mapRoot: sourceRoot) {
        let targetURL = mapRoot.appendingPathComponent("transitions/\(transition.transitionID).json")
        let existing = try? JSONDecoder().decode(TKAppMapTransition.self, from: Data(contentsOf: targetURL))
        let merged = TKAppMapTransition(
            schemaVersion: 1,
            kind: "triton.app-map.transition",
            transitionID: transition.transitionID,
            fromScreenID: transition.fromScreenID,
            toScreenID: transition.toScreenID,
            triggerStepIndex: transition.triggerStepIndex,
            trigger: transition.trigger,
            changed: transition.changed || (existing?.changed ?? false),
            replayable: transition.replayable || (existing?.replayable ?? false),
            status: transition.status,
            sourceRuns: workspaceUnique((existing?.sourceRuns ?? []) + transition.sourceRuns),
            vlmHealth: existing?.vlmHealth ?? transition.vlmHealth
        )
        try prettyEncodedData(merged).write(to: targetURL, options: .atomic)
    }

    for path in try workspaceReadMapPaths(mapRoot: sourceRoot) {
        let targetURL = mapRoot.appendingPathComponent("paths/\(path.pathID).json")
        let existing = try? JSONDecoder().decode(TKAppMapPath.self, from: Data(contentsOf: targetURL))
        let merged = TKAppMapPath(
            schemaVersion: 1,
            kind: "triton.app-map.path",
            pathID: path.pathID,
            name: existing?.name ?? path.name,
            status: path.status,
            confirmed: existing?.confirmed == true || confirm || path.confirmed,
            startScreenID: path.startScreenID,
            endScreenID: path.endScreenID,
            transitions: workspaceUnique((existing?.transitions ?? []) + path.transitions),
            health: workspaceMergedPathHealth(existing: existing, incoming: path, runID: run.runID),
            replayable: path.replayable || (existing?.replayable ?? false),
            sourceRuns: workspaceUnique((existing?.sourceRuns ?? []) + path.sourceRuns),
            source: existing?.source ?? path.source,
            vlmHealth: existing?.vlmHealth ?? path.vlmHealth
        )
        try prettyEncodedData(merged).write(to: targetURL, options: .atomic)
    }

    for suite in try workspaceReadMapSuites(mapRoot: sourceRoot) {
        let targetURL = mapRoot.appendingPathComponent("suites/\(suite.suiteID).json")
        let existing = try? JSONDecoder().decode(TKAppMapSuite.self, from: Data(contentsOf: targetURL))
        let merged = TKAppMapSuite(
            schemaVersion: 1,
            kind: "triton.app-map.suite",
            suiteID: suite.suiteID,
            name: existing?.name ?? suite.name,
            paths: workspaceUnique((existing?.paths ?? []) + suite.paths).sorted(),
            policy: existing?.policy ?? suite.policy
        )
        try prettyEncodedData(merged).write(to: targetURL, options: .atomic)
    }

    try workspaceWriteAppMapRunRecord(
        mapRoot: mapRoot,
        run: run,
        screenCount: sourceIndex.screenCount,
        transitionCount: sourceIndex.transitionCount,
        pathCount: sourceIndex.pathCount
    )
    try workspaceWriteAppMapIndex(mapRoot: mapRoot, app: app)

    let inspect = try inspectTritonAppMap(mapPath: mapRoot.path)
    let pathIDs = try listTritonAppMapPaths(mapPath: mapRoot.path).paths.map(\.pathID)
    let coverage = try workspaceAppMapCoverage(
        mapRoot: mapRoot,
        screenCount: inspect.screenCount,
        transitionCount: inspect.transitionCount,
        pathCount: inspect.pathCount,
        suiteCount: inspect.suiteCount
    )
    return TKWorkspaceMergeMapResponse(
        schemaVersion: 1,
        kind: "triton.workspace.merge-map",
        runID: run.runID,
        sourceMapRef: "atlas/app-map/app-map.json",
        mapDir: mapRoot.path,
        screenCount: inspect.screenCount,
        transitionCount: inspect.transitionCount,
        pathCount: inspect.pathCount,
        suiteCount: inspect.suiteCount,
        coverage: coverage,
        pathIDs: pathIDs
    )
}

func workspaceAppMapSummary(runDir: URL) throws -> TKWorkspaceAppMapSummary? {
    let mapRoot = workspaceAppMapRoot(runDir: runDir)
    guard FileManager.default.fileExists(atPath: mapRoot.appendingPathComponent("app-map.json").path) else {
        return nil
    }
    let inspect = try inspectTritonAppMap(mapPath: mapRoot.path)
    let paths = try listTritonAppMapPaths(mapPath: mapRoot.path).paths
    return TKWorkspaceAppMapSummary(
        mapRef: "atlas/app-map/app-map.json",
        screenCount: inspect.screenCount,
        transitionCount: inspect.transitionCount,
        pathCount: inspect.pathCount,
        pathIDs: paths.map(\.pathID)
    )
}

private func workspaceAppMapRoot(runDir: URL) -> URL {
    runDir.appendingPathComponent("atlas/app-map", isDirectory: true)
}

private func workspacePrepareAppMapDirectories(_ mapRoot: URL) throws {
    for path in ["screens", "transitions", "paths", "suites", "runs"] {
        try FileManager.default.createDirectory(
            at: mapRoot.appendingPathComponent(path, isDirectory: true),
            withIntermediateDirectories: true
        )
    }
}

private func workspaceWriteAppMapPath(
    transitionIDs: [String],
    mapRoot: URL,
    run: TKWorkspaceRunResponse
) throws -> [String] {
    guard !transitionIDs.isEmpty else { return [] }
    let transitions = try transitionIDs.map {
        try JSONDecoder().decode(
            TKAppMapTransition.self,
            from: Data(contentsOf: mapRoot.appendingPathComponent("transitions/\($0).json"))
        )
    }.sorted { $0.triggerStepIndex < $1.triggerStepIndex }
    guard let first = transitions.first, let last = transitions.last else { return [] }
    let start = try workspaceReadAppMapScreen(mapRoot: mapRoot, screenID: first.fromScreenID)
    let end = try workspaceReadAppMapScreen(mapRoot: mapRoot, screenID: last.toScreenID)
    let startName = start.primaryText ?? start.screenID
    let endName = workspacePathEndName(start: startName, end: end.primaryText ?? end.screenID)
    let pathID = "path-\(workspaceSlug(startName))-\(workspaceSlug(endName))"
    let path = TKAppMapPath(
        schemaVersion: 1,
        kind: "triton.app-map.path",
        pathID: pathID,
        name: "\(startName) to \(endName)",
        status: "observed",
        confirmed: run.status == "passed",
        startScreenID: first.fromScreenID,
        endScreenID: last.toScreenID,
        transitions: transitions.map(\.transitionID),
        health: workspaceAppMapHealth(for: run),
        replayable: transitions.allSatisfy(\.replayable),
        sourceRuns: [run.runID],
        source: "workspace-atlas",
        vlmHealth: nil
    )
    try prettyEncodedData(path).write(to: mapRoot.appendingPathComponent("paths/\(pathID).json"), options: .atomic)
    return [pathID]
}

private func workspaceWriteAppMapSuite(mapRoot: URL, pathIDs: [String]) throws {
    let suite = TKAppMapSuite(
        schemaVersion: 1,
        kind: "triton.app-map.suite",
        suiteID: "workspace",
        name: "Workspace",
        paths: pathIDs.sorted(),
        policy: TKAppMapSuitePolicy(strict: true, stopOnFailure: true)
    )
    try prettyEncodedData(suite).write(to: mapRoot.appendingPathComponent("suites/workspace.json"), options: .atomic)
}

private func workspaceWriteAppMapRunRecord(
    mapRoot: URL,
    run: TKWorkspaceRunResponse,
    screenCount: Int,
    transitionCount: Int,
    pathCount: Int
) throws {
    let record = TKAppMapRunRecord(
        schemaVersion: 1,
        kind: "triton.app-map.run",
        runID: run.runID,
        evidenceDir: run.paths.runDir,
        verdict: workspaceAppMapVerdict(for: run),
        screenCount: screenCount,
        transitionCount: transitionCount,
        pathCount: pathCount
    )
    try prettyEncodedData(record).write(to: mapRoot.appendingPathComponent("runs/\(run.runID).json"), options: .atomic)
}

private func workspaceWriteAppMapIndex(mapRoot: URL, app: TKAppMapApp) throws {
    let screenCount = try workspaceJSONFileCount(in: mapRoot.appendingPathComponent("screens", isDirectory: true))
    let transitionCount = try workspaceJSONFileCount(in: mapRoot.appendingPathComponent("transitions", isDirectory: true))
    let pathCount = try workspaceJSONFileCount(in: mapRoot.appendingPathComponent("paths", isDirectory: true))
    let suiteCount = try workspaceJSONFileCount(in: mapRoot.appendingPathComponent("suites", isDirectory: true))
    let document = TKAppMapDocument(
        schemaVersion: 1,
        kind: "triton.app-map",
        app: app,
        screenCount: screenCount,
        transitionCount: transitionCount,
        pathCount: pathCount,
        suiteCount: suiteCount,
        coverage: try workspaceAppMapCoverage(
            mapRoot: mapRoot,
            screenCount: screenCount,
            transitionCount: transitionCount,
            pathCount: pathCount,
            suiteCount: suiteCount
        ),
        updatedAt: workspaceISO8601Timestamp()
    )
    try prettyEncodedData(document).write(to: mapRoot.appendingPathComponent("app-map.json"), options: .atomic)
}

private func workspaceReadAppMapScreen(mapRoot: URL, screenID: String) throws -> TKAppMapScreen {
    try JSONDecoder().decode(
        TKAppMapScreen.self,
        from: Data(contentsOf: mapRoot.appendingPathComponent("screens/\(screenID).json"))
    )
}

private func workspaceReadMapScreens(mapRoot: URL) throws -> [TKAppMapScreen] {
    try workspaceJSONFiles(in: mapRoot.appendingPathComponent("screens", isDirectory: true))
        .map { try JSONDecoder().decode(TKAppMapScreen.self, from: Data(contentsOf: $0)) }
}

private func workspaceReadMapTransitions(mapRoot: URL) throws -> [TKAppMapTransition] {
    try workspaceJSONFiles(in: mapRoot.appendingPathComponent("transitions", isDirectory: true))
        .map { try JSONDecoder().decode(TKAppMapTransition.self, from: Data(contentsOf: $0)) }
}

private func workspaceReadMapPaths(mapRoot: URL) throws -> [TKAppMapPath] {
    try workspaceJSONFiles(in: mapRoot.appendingPathComponent("paths", isDirectory: true))
        .map { try JSONDecoder().decode(TKAppMapPath.self, from: Data(contentsOf: $0)) }
}

private func workspaceReadMapSuites(mapRoot: URL) throws -> [TKAppMapSuite] {
    try workspaceJSONFiles(in: mapRoot.appendingPathComponent("suites", isDirectory: true))
        .map { try JSONDecoder().decode(TKAppMapSuite.self, from: Data(contentsOf: $0)) }
}

private func workspaceStateVariants(
    screen: TKWorkspaceAtlasProjectionScreen,
    states: [TKWorkspaceAtlasProjectionState],
    runID: String
) -> [TKAppMapStateVariant] {
    let variants = states.map { state in
        TKAppMapStateVariant(
            stateID: state.stateID,
            runLocalScreenID: screen.screenID,
            phase: state.phase,
            sourceRuns: [runID],
            evidenceRefs: workspaceUnique(screen.evidenceRefs + state.evidenceRefs),
            visibleTexts: workspaceUnique(screen.dominantTexts)
        )
    }
    if !variants.isEmpty {
        return variants
    }
    let stateID = screen.stateID ?? screen.screenID
    return [
        TKAppMapStateVariant(
            stateID: stateID,
            runLocalScreenID: screen.screenID,
            phase: nil,
            sourceRuns: [runID],
            evidenceRefs: workspaceUnique(screen.evidenceRefs),
            visibleTexts: workspaceUnique(screen.dominantTexts)
        ),
    ]
}

private func workspaceMergeStateVariants(
    _ existing: [TKAppMapStateVariant],
    _ incoming: [TKAppMapStateVariant]
) -> [TKAppMapStateVariant] {
    var result = existing
    for variant in incoming {
        if let index = result.firstIndex(where: {
            $0.stateID == variant.stateID
                && $0.runLocalScreenID == variant.runLocalScreenID
                && $0.phase == variant.phase
        }) {
            let current = result[index]
            result[index] = TKAppMapStateVariant(
                stateID: current.stateID,
                runLocalScreenID: current.runLocalScreenID,
                phase: current.phase,
                sourceRuns: workspaceUnique(current.sourceRuns + variant.sourceRuns),
                evidenceRefs: workspaceUnique(current.evidenceRefs + variant.evidenceRefs),
                visibleTexts: workspaceUnique(current.visibleTexts + variant.visibleTexts)
            )
        } else {
            result.append(variant)
        }
    }
    return result
}

private func workspaceAppMapCoverage(
    mapRoot: URL,
    screenCount: Int,
    transitionCount: Int,
    pathCount: Int,
    suiteCount: Int
) throws -> TKAppMapCoverage {
    let runs = try workspaceJSONFiles(in: mapRoot.appendingPathComponent("runs", isDirectory: true))
        .map { try JSONDecoder().decode(TKAppMapRunRecord.self, from: Data(contentsOf: $0)) }
    let screens = try workspaceReadMapScreens(mapRoot: mapRoot)
    let paths = try workspaceReadMapPaths(mapRoot: mapRoot)
    return TKAppMapCoverage(
        observedRuns: runs.count,
        screenCount: screenCount,
        stateCount: screens.reduce(0) { $0 + $1.stateVariants.count },
        transitionCount: transitionCount,
        pathCount: pathCount,
        suiteCount: suiteCount,
        confirmedPathCount: paths.filter(\.confirmed).count,
        replayablePathCount: paths.filter(\.replayable).count,
        passCount: runs.filter { $0.verdict == "success" }.count,
        failCount: runs.filter { $0.verdict == "failure" }.count,
        flakeCount: 0
    )
}

private func workspaceActionPoint(runDir: URL, index: Int) -> TKAppMapPoint? {
    let suffix = workspaceArtifactSuffix(index)
    let url = runDir.appendingPathComponent("evidence/actions/action-\(suffix).json")
    guard let data = try? Data(contentsOf: url),
          let artifact = try? JSONDecoder().decode(TKWorkspaceActionPointArtifact.self, from: data),
          let grounding = artifact.vlmGrounding,
          let runtimePoint = grounding.runtimePoint else {
        return nil
    }
    return TKAppMapPoint(
        x: runtimePoint.x,
        y: runtimePoint.y,
        coordinateSpace: grounding.coordinateSpace ?? "runtime-point"
    )
}

private func workspaceAtlasFingerprint(from signature: String) -> TKScreenWorkspaceFingerprint {
    let parts = signature.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
    return TKScreenWorkspaceFingerprint(
        screenshotSha256: parts[safe: 0] ?? "unknown-screenshot",
        axTextHash: parts[safe: 1] ?? "unknown-ax",
        hierarchySha256: parts[safe: 2] ?? "unknown-hierarchy"
    )
}

private func workspaceMapScreenID(for fingerprint: TKScreenWorkspaceFingerprint) -> String {
    let key = "\(fingerprint.screenshotSha256)|\(fingerprint.axTextHash)|\(fingerprint.hierarchySha256)"
    return "screen-\(workspaceShortHash(key))"
}

private func workspaceMapTransitionID(
    fromScreenID: String,
    toScreenID: String,
    stepIndex: Int,
    trigger: TKAppMapTransitionTrigger
) -> String {
    let point = trigger.point.map { "\($0.x),\($0.y),\($0.coordinateSpace)" } ?? "none"
    return "transition-\(workspaceShortHash("\(fromScreenID)|\(toScreenID)|\(stepIndex)|\(trigger.type)|\(point)"))"
}

private func workspacePrimaryText(_ texts: [String]) -> String? {
    texts
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
}

private func workspacePathEndName(start: String, end: String) -> String {
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

private func workspaceAppMapHealth(for run: TKWorkspaceRunResponse) -> TKAppMapHealth {
    TKAppMapHealth(
        observedRuns: 1,
        passCount: run.status == "passed" ? 1 : 0,
        failCount: run.status == "failed" ? 1 : 0,
        flakeCount: 0
    )
}

private func workspaceAppMapVerdict(for run: TKWorkspaceRunResponse) -> String? {
    if run.status == "passed" { return "success" }
    if run.status == "failed" { return "failure" }
    return nil
}

private func workspaceMergedPathHealth(existing: TKAppMapPath?, incoming: TKAppMapPath, runID: String) -> TKAppMapHealth {
    guard let existing else {
        return incoming.health
    }
    guard !existing.sourceRuns.contains(runID) else {
        return existing.health
    }
    return TKAppMapHealth(
        observedRuns: existing.health.observedRuns + incoming.health.observedRuns,
        passCount: existing.health.passCount + incoming.health.passCount,
        failCount: existing.health.failCount + incoming.health.failCount,
        flakeCount: existing.health.flakeCount + incoming.health.flakeCount
    )
}

private func workspaceJSONFileCount(in directory: URL) throws -> Int {
    return try workspaceJSONFiles(in: directory).count
}

private func workspaceJSONFiles(in directory: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "json" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

private func workspaceUnique(_ values: [String]) -> [String] {
    var result: [String] = []
    var seen = Set<String>()
    for value in values where seen.insert(value).inserted {
        result.append(value)
    }
    return result
}

private func workspaceSlug(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics
    let scalars = value.lowercased().unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let collapsed = String(scalars)
        .split(separator: "-", omittingEmptySubsequences: true)
        .joined(separator: "-")
    return collapsed.isEmpty ? "screen" : collapsed
}

private func workspaceShortHash(_ value: String) -> String {
    let digest = SHA256.hash(data: Data(value.utf8))
    return digest.map { String(format: "%02x", $0) }.joined().prefix(12).description
}

private func workspaceISO8601Timestamp(_ date: Date = Date()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
