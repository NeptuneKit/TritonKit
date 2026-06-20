import Foundation
import TritonKitShared

struct TKScreenWorkspaceProjectionResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let evidenceDir: String
    let screensRef: String
    let transitionsRef: String
    let screenCount: Int
    let transitionCount: Int
    let warningCount: Int
    let warnings: [TKScreenWorkspaceProjectionWarning]

    init(
        evidenceDir: String,
        screensRef: String = "screens.json",
        transitionsRef: String = "transitions.json",
        screenCount: Int,
        transitionCount: Int,
        warnings: [TKScreenWorkspaceProjectionWarning]
    ) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.screen-workspace.projection-result"
        self.evidenceDir = evidenceDir
        self.screensRef = screensRef
        self.transitionsRef = transitionsRef
        self.screenCount = screenCount
        self.transitionCount = transitionCount
        self.warningCount = warnings.count
        self.warnings = warnings
    }
}

struct TKScreenWorkspaceProjectionFailureResponse: Codable, Equatable {
    let ok: Bool
    let error: TKScreenWorkspaceProjectionErrorDetail

    init(error: TKScreenWorkspaceProjectionErrorDetail) {
        self.ok = false
        self.error = error
    }
}

struct TKScreenWorkspaceProjectionErrorDetail: Codable, Equatable {
    let type: String
    let code: String
    let message: String
}

enum TKScreenWorkspaceProjectionError: Error, Equatable {
    case missingObservationEvents
    case missingRunEvents(String)
    case invalidRunEvents(String)

    var detail: TKScreenWorkspaceProjectionErrorDetail {
        switch self {
        case .missingObservationEvents:
            return TKScreenWorkspaceProjectionErrorDetail(
                type: "projection_error",
                code: "missing_observation_events",
                message: "No observation.captured events found in run/events.jsonl."
            )
        case .missingRunEvents(let path):
            return TKScreenWorkspaceProjectionErrorDetail(
                type: "projection_error",
                code: "missing_run_events",
                message: "No run events file found at \(path)."
            )
        case .invalidRunEvents(let message):
            return TKScreenWorkspaceProjectionErrorDetail(
                type: "projection_error",
                code: "invalid_run_events",
                message: message
            )
        }
    }
}

struct TKScreenWorkspaceProjectionWarning: Codable, Equatable {
    let code: String
    let message: String
    let stepIndex: Int?
}

struct TKScreenWorkspaceSource: Codable, Equatable {
    let eventsRef: String
}

struct TKScreenWorkspaceTransitionSource: Codable, Equatable {
    let eventsRef: String
    let screensRef: String
}

struct TKScreenWorkspaceScreensDocument: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let runID: String
    let source: TKScreenWorkspaceSource
    let screens: [TKScreenWorkspaceScreen]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case runID = "runId"
        case source
        case screens
    }
}

struct TKScreenWorkspaceScreen: Codable, Equatable {
    let screenID: String
    let fingerprint: TKScreenWorkspaceFingerprint
    let primaryText: String?
    let visibleTexts: [String]
    let firstStepIndex: Int?
    let lastStepIndex: Int?
    let observations: [TKScreenWorkspaceObservation]

    enum CodingKeys: String, CodingKey {
        case screenID = "screenId"
        case fingerprint
        case primaryText
        case visibleTexts
        case firstStepIndex
        case lastStepIndex
        case observations
    }
}

struct TKScreenWorkspaceObservation: Codable, Equatable {
    let eventIndex: Int
    let stepIndex: Int
    let phase: String
    let artifacts: TKScreenWorkspaceObservationArtifacts
    let fingerprint: TKScreenWorkspaceFingerprint
    let visibleTexts: [String]

    fileprivate static func from(_ indexed: IndexedObservation) -> Self {
        TKScreenWorkspaceObservation(
            eventIndex: indexed.eventIndex,
            stepIndex: indexed.stepIndex,
            phase: indexed.phase,
            artifacts: indexed.artifacts,
            fingerprint: indexed.fingerprint,
            visibleTexts: indexed.visibleTexts
        )
    }
}

struct TKScreenWorkspaceObservationArtifacts: Codable, Equatable {
    let screenshot: String
    let ax: String
    let hierarchy: String
}

struct TKScreenWorkspaceFingerprint: Codable, Equatable, Hashable {
    let screenshotSha256: String
    let axTextHash: String
    let hierarchySha256: String
}

struct TKScreenWorkspaceTransitionsDocument: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let runID: String
    let source: TKScreenWorkspaceTransitionSource
    let transitions: [TKScreenWorkspaceTransition]
    let warnings: [TKScreenWorkspaceProjectionWarning]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case runID = "runId"
        case source
        case transitions
        case warnings
    }
}

struct TKScreenWorkspaceTransition: Codable, Equatable {
    let transitionID: String
    let fromScreenID: String
    let toScreenID: String
    let stepIndex: Int
    let trigger: TKScreenWorkspaceTransitionTrigger
    let before: TKScreenWorkspaceTransitionObservationRef
    let after: TKScreenWorkspaceTransitionObservationRef

    enum CodingKeys: String, CodingKey {
        case transitionID = "transitionId"
        case fromScreenID = "fromScreenId"
        case toScreenID = "toScreenId"
        case stepIndex
        case trigger
        case before
        case after
    }
}

struct TKScreenWorkspaceTransitionObservationRef: Codable, Equatable {
    let eventIndex: Int
    let screenID: String

    enum CodingKeys: String, CodingKey {
        case eventIndex
        case screenID = "screenId"
    }
}

struct TKScreenWorkspaceTransitionTrigger: Codable, Equatable {
    let type: String
    let point: TKScreenWorkspaceTransitionPoint?
    let coordinateSpace: String?
    let command: [String]?
    let replayable: Bool
}

struct TKScreenWorkspaceTransitionPoint: Codable, Equatable {
    let x: Double
    let y: Double
}

private struct IndexedObservation: Equatable {
    let eventIndex: Int
    let event: TKTestRunEvent
    let stepIndex: Int
    let phase: String
    let artifacts: TKScreenWorkspaceObservationArtifacts
    let fingerprint: TKScreenWorkspaceFingerprint
    let visibleTexts: [String]
    let changed: Bool?
}

private struct ScreenGroup {
    let fingerprint: TKScreenWorkspaceFingerprint
    var observations: [IndexedObservation]
}

private struct NormalizedPlanIndex {
    let pointsByStepIndex: [Int: TKTestPlanPoint]
}

func projectScreenWorkspace(evidencePath: String) throws -> TKScreenWorkspaceProjectionResponse {
    let root = evidenceBundleRoot(from: evidencePath)
    let manifest = try readEvidenceManifest(from: evidencePath)
    let eventsRef = manifest.run?.eventsPath ?? "run/events.jsonl"
    let eventsURL = root.appendingPathComponent(eventsRef)
    guard FileManager.default.fileExists(atPath: eventsURL.path) else {
        throw TKScreenWorkspaceProjectionError.missingRunEvents(eventsRef)
    }

    let parseResult: TKTestRunEventParseResult
    do {
        parseResult = try TKTestRunEventLogParser().parse(Data(contentsOf: eventsURL))
    } catch let error as TKTestRunEventLogParseError {
        throw TKScreenWorkspaceProjectionError.invalidRunEvents(error.description)
    } catch {
        throw TKScreenWorkspaceProjectionError.invalidRunEvents("\(error)")
    }

    let observations = try indexedObservations(from: parseResult.events)
    guard !observations.isEmpty else {
        throw TKScreenWorkspaceProjectionError.missingObservationEvents
    }

    let screenGroups = groupObservations(observations)
    let screenIDByFingerprint = Dictionary(uniqueKeysWithValues: screenGroups.enumerated().map {
        ($0.element.fingerprint, screenID(for: $0.offset))
    })
    let eventScreenIDs = Dictionary(uniqueKeysWithValues: observations.compactMap { observation -> (Int, String)? in
        guard let screenID = screenIDByFingerprint[observation.fingerprint] else { return nil }
        return (observation.eventIndex, screenID)
    })
    let screens = screenGroups.enumerated().map { index, group in
        screen(from: group, screenID: screenID(for: index))
    }

    let transitionProjection = buildTransitions(
        events: parseResult.events,
        observations: observations,
        eventScreenIDs: eventScreenIDs,
        normalizedPlan: readNormalizedPlanIndex(from: root)
    )
    let runID = parseResult.summary.runID ?? observations.first?.event.runID ?? "unknown"
    let screensDocument = TKScreenWorkspaceScreensDocument(
        schemaVersion: 1,
        kind: "triton.screen-workspace.screens",
        runID: runID,
        source: TKScreenWorkspaceSource(eventsRef: eventsRef),
        screens: screens
    )
    let transitionsDocument = TKScreenWorkspaceTransitionsDocument(
        schemaVersion: 1,
        kind: "triton.screen-workspace.transitions",
        runID: runID,
        source: TKScreenWorkspaceTransitionSource(eventsRef: eventsRef, screensRef: "screens.json"),
        transitions: transitionProjection.transitions,
        warnings: transitionProjection.warnings
    )

    let screensURL = root.appendingPathComponent("screens.json")
    let transitionsURL = root.appendingPathComponent("transitions.json")
    try prettyEncodedData(screensDocument).write(to: screensURL, options: .atomic)
    try prettyEncodedData(transitionsDocument).write(to: transitionsURL, options: .atomic)

    try writeProjectedManifest(
        manifest,
        root: root,
        screenCount: screens.count,
        transitionCount: transitionProjection.transitions.count,
        warningCount: transitionProjection.warnings.count
    )

    return TKScreenWorkspaceProjectionResponse(
        evidenceDir: root.path,
        screenCount: screens.count,
        transitionCount: transitionProjection.transitions.count,
        warnings: transitionProjection.warnings
    )
}

private func indexedObservations(from events: [TKTestRunEvent]) throws -> [IndexedObservation] {
    try events.enumerated().compactMap { offset, event in
        guard event.type == .observationCaptured else { return nil }
        guard let stepIndex = event.stepIndex,
              let phase = event.phase,
              let artifacts = event.artifacts,
              let screenshot = artifacts.screenshot,
              let ax = artifacts.ax,
              let hierarchy = artifacts.hierarchy,
              let screenCandidate = event.screenCandidate
        else {
            throw TKScreenWorkspaceProjectionError.invalidRunEvents("observation.captured event \(offset + 1) is missing required fields.")
        }
        return IndexedObservation(
            eventIndex: offset + 1,
            event: event,
            stepIndex: stepIndex,
            phase: phase,
            artifacts: TKScreenWorkspaceObservationArtifacts(
                screenshot: normalizeObservationArtifactRef(screenshot),
                ax: normalizeObservationArtifactRef(ax),
                hierarchy: normalizeObservationArtifactRef(hierarchy)
            ),
            fingerprint: TKScreenWorkspaceFingerprint(
                screenshotSha256: screenCandidate.screenshotSha256,
                axTextHash: screenCandidate.axTextHash,
                hierarchySha256: screenCandidate.hierarchySha256
            ),
            visibleTexts: screenCandidate.visibleTexts,
            changed: event.changed
        )
    }
}

private func groupObservations(_ observations: [IndexedObservation]) -> [ScreenGroup] {
    var groups: [ScreenGroup] = []
    var indexByFingerprint: [TKScreenWorkspaceFingerprint: Int] = [:]
    for observation in observations {
        if let index = indexByFingerprint[observation.fingerprint] {
            groups[index].observations.append(observation)
        } else {
            indexByFingerprint[observation.fingerprint] = groups.count
            groups.append(ScreenGroup(fingerprint: observation.fingerprint, observations: [observation]))
        }
    }
    return groups
}

private func screen(from group: ScreenGroup, screenID: String) -> TKScreenWorkspaceScreen {
    let observations = group.observations.map(TKScreenWorkspaceObservation.from)
    let visibleTexts = unique(group.observations.flatMap(\.visibleTexts))
    let stepIndexes = group.observations.map(\.stepIndex)
    return TKScreenWorkspaceScreen(
        screenID: screenID,
        fingerprint: group.fingerprint,
        primaryText: primaryText(from: visibleTexts),
        visibleTexts: visibleTexts,
        firstStepIndex: stepIndexes.min(),
        lastStepIndex: stepIndexes.max(),
        observations: observations
    )
}

private func buildTransitions(
    events: [TKTestRunEvent],
    observations: [IndexedObservation],
    eventScreenIDs: [Int: String],
    normalizedPlan: NormalizedPlanIndex?
) -> (transitions: [TKScreenWorkspaceTransition], warnings: [TKScreenWorkspaceProjectionWarning]) {
    let stepTypes = Dictionary(uniqueKeysWithValues: events.compactMap { event -> (Int, String)? in
        guard event.type == .stepStarted, let stepIndex = event.stepIndex, let stepType = event.stepType else { return nil }
        return (stepIndex, stepType)
    })
    let commandsByStep = Dictionary(uniqueKeysWithValues: events.compactMap { event -> (Int, [String])? in
        guard event.type == .commandExecuted, let stepIndex = event.stepIndex, let command = event.command else { return nil }
        return (stepIndex, command)
    })

    let observationsByStep = Dictionary(grouping: observations, by: \.stepIndex)
    var transitions: [TKScreenWorkspaceTransition] = []
    var warnings: [TKScreenWorkspaceProjectionWarning] = []

    for stepIndex in observationsByStep.keys.sorted() {
        guard stepTypes[stepIndex] == "tap" else {
            continue
        }
        let stepObservations = observationsByStep[stepIndex] ?? []
        guard let before = stepObservations.first(where: { $0.phase == "before" }) else {
            warnings.append(TKScreenWorkspaceProjectionWarning(
                code: "missing_before_observation",
                message: "Tap step \(stepIndex) has no before observation.",
                stepIndex: stepIndex
            ))
            continue
        }
        guard let after = stepObservations.last(where: { $0.phase == "after" }) else {
            warnings.append(TKScreenWorkspaceProjectionWarning(
                code: "missing_after_observation",
                message: "Tap step \(stepIndex) has no after observation.",
                stepIndex: stepIndex
            ))
            continue
        }
        guard after.changed == true else {
            warnings.append(TKScreenWorkspaceProjectionWarning(
                code: "unchanged_action_step",
                message: "Tap step \(stepIndex) did not report changed=true.",
                stepIndex: stepIndex
            ))
            continue
        }
        guard let beforeScreenID = eventScreenIDs[before.eventIndex],
              let afterScreenID = eventScreenIDs[after.eventIndex]
        else {
            warnings.append(TKScreenWorkspaceProjectionWarning(
                code: "missing_screen_reference",
                message: "Tap step \(stepIndex) could not resolve before/after screen references.",
                stepIndex: stepIndex
            ))
            continue
        }
        guard beforeScreenID != afterScreenID else {
            warnings.append(TKScreenWorkspaceProjectionWarning(
                code: "same_screen_transition",
                message: "Tap step \(stepIndex) before/after observations resolve to the same screen.",
                stepIndex: stepIndex
            ))
            continue
        }

        let point = normalizedPlan?.pointsByStepIndex[stepIndex]
        let triggerPoint = point.map { TKScreenWorkspaceTransitionPoint(x: $0.x, y: $0.y) }
        let trigger = TKScreenWorkspaceTransitionTrigger(
            type: "tap",
            point: triggerPoint,
            coordinateSpace: point?.coordinateSpace,
            command: commandsByStep[stepIndex],
            replayable: point?.coordinateSpace == "runtime-point"
        )
        transitions.append(TKScreenWorkspaceTransition(
            transitionID: String(format: "transition-%03d", transitions.count),
            fromScreenID: beforeScreenID,
            toScreenID: afterScreenID,
            stepIndex: stepIndex,
            trigger: trigger,
            before: TKScreenWorkspaceTransitionObservationRef(eventIndex: before.eventIndex, screenID: beforeScreenID),
            after: TKScreenWorkspaceTransitionObservationRef(eventIndex: after.eventIndex, screenID: afterScreenID)
        ))
    }

    return (transitions, warnings)
}

private func readNormalizedPlanIndex(from root: URL) -> NormalizedPlanIndex? {
    let url = root.appendingPathComponent("normalized-plan.json")
    guard let data = try? Data(contentsOf: url),
          let plan = try? JSONDecoder().decode(TKTestNormalizedPlan.self, from: data)
    else {
        return nil
    }
    return NormalizedPlanIndex(pointsByStepIndex: Dictionary(uniqueKeysWithValues: plan.steps.compactMap { step in
        guard let point = step.point else { return nil }
        return (step.index, point)
    }))
}

private func writeProjectedManifest(
    _ manifest: TKEvidenceManifest,
    root: URL,
    screenCount: Int,
    transitionCount: Int,
    warningCount: Int
) throws {
    let workspace = TKEvidenceScreenWorkspaceManifest(
        screenCount: screenCount,
        transitionCount: transitionCount,
        warningCount: warningCount
    )
    let artifacts = upsertScreenWorkspaceArtifacts(manifest.artifacts, root: root)
    let projectedManifest = TKEvidenceManifest(
        ok: manifest.ok,
        formatVersion: manifest.formatVersion,
        name: manifest.name,
        note: manifest.note,
        createdAt: manifest.createdAt,
        output: manifest.output,
        artifacts: artifacts,
        skipped: manifest.skipped,
        target: manifest.target,
        cli: manifest.cli,
        run: manifest.run,
        screenWorkspace: workspace
    )
    try prettyEncodedData(projectedManifest).write(to: root.appendingPathComponent("manifest.json"), options: .atomic)
}

private func upsertScreenWorkspaceArtifacts(_ artifacts: [TKEvidenceArtifact], root: URL) -> [TKEvidenceArtifact] {
    let projected = [
        TKEvidenceArtifact(
            kind: "screen-workspace.screens",
            path: "screens.json",
            contentType: "application/json",
            bytes: fileSize(root.appendingPathComponent("screens.json"))
        ),
        TKEvidenceArtifact(
            kind: "screen-workspace.transitions",
            path: "transitions.json",
            contentType: "application/json",
            bytes: fileSize(root.appendingPathComponent("transitions.json"))
        ),
    ]
    let filtered = artifacts.filter { artifact in
        artifact.kind != "screen-workspace.screens" && artifact.kind != "screen-workspace.transitions"
    }
    return filtered + projected
}

private func fileSize(_ url: URL) -> Int? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
          let size = attributes[.size] as? NSNumber
    else {
        return nil
    }
    return size.intValue
}

private func normalizeObservationArtifactRef(_ ref: String) -> String {
    var normalized = ref
    while normalized.hasPrefix("../") {
        normalized.removeFirst(3)
    }
    if normalized.hasPrefix("./") {
        normalized.removeFirst(2)
    }
    return normalized
}

private func screenID(for index: Int) -> String {
    String(format: "screen-%03d", index)
}

private func primaryText(from visibleTexts: [String]) -> String? {
    visibleTexts.first { text in
        !text.contains(".") && !text.contains(":") && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    } ?? visibleTexts.first
}

private func unique(_ values: [String]) -> [String] {
    var result: [String] = []
    var seen = Set<String>()
    for value in values where seen.insert(value).inserted {
        result.append(value)
    }
    return result
}
