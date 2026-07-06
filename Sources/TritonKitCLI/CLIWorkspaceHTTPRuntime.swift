import Foundation

struct TKWorkspaceHTTPRunRequest: Codable, Equatable {
    let runsDir: String?
    let runID: String?
    let target: String?
    let platform: String?
    let scope: String?
    let app: String
    let goal: String
    let actionPolicy: String?
    let llmProvider: String?
    let vlmProvider: String?
    let dryModelFixture: Bool?
    let maxSteps: Int?
    let allowedActions: [String]?
    let stopConditions: [String]?

    init(
        runsDir: String?,
        runID: String?,
        target: String?,
        platform: String? = nil,
        scope: String? = nil,
        app: String,
        goal: String,
        actionPolicy: String?,
        llmProvider: String? = nil,
        vlmProvider: String? = nil,
        dryModelFixture: Bool? = nil,
        maxSteps: Int? = nil,
        allowedActions: [String]? = nil,
        stopConditions: [String]? = nil
    ) {
        self.runsDir = runsDir
        self.runID = runID
        self.target = target
        self.platform = platform
        self.scope = scope
        self.app = app
        self.goal = goal
        self.actionPolicy = actionPolicy
        self.llmProvider = llmProvider
        self.vlmProvider = vlmProvider
        self.dryModelFixture = dryModelFixture
        self.maxSteps = maxSteps
        self.allowedActions = allowedActions
        self.stopConditions = stopConditions
    }

    enum CodingKeys: String, CodingKey {
        case runsDir
        case runID = "runId"
        case target
        case platform
        case scope
        case app
        case goal
        case actionPolicy
        case llmProvider
        case vlmProvider
        case dryModelFixture
        case maxSteps
        case allowedActions
        case stopConditions
    }
}

struct TKWorkspaceHTTPExportFlowRequest: Codable, Equatable {
    let runsDir: String?
    let output: String
}

func handleWorkspaceHTTPRun(body: Data) throws -> TKWorkspaceRunResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPRunRequest.self, from: body)
    return try runWorkspaceRun(TKWorkspaceRunRequest(
        runsDirectory: request.runsDir ?? ".triton/runs",
        runID: request.runID,
        target: request.target ?? "current",
        platform: request.platform,
        scope: request.scope,
        app: request.app,
        goal: request.goal,
        actionPolicy: request.actionPolicy ?? "explore",
        dryModelFixture: request.dryModelFixture ?? false,
        llmProvider: request.llmProvider,
        vlmProvider: request.vlmProvider,
        maxSteps: request.maxSteps,
        allowedActions: request.allowedActions ?? [],
        stopConditions: request.stopConditions ?? []
    ))
}

func handleWorkspaceHTTPInspect(runID: String, runsDir: String?) throws -> TKWorkspaceInspectResponse {
    try inspectWorkspaceRun(runID: runID, runsDirectory: runsDir ?? ".triton/runs")
}

func handleWorkspaceHTTPStop(runID: String, runsDir: String?) throws -> TKWorkspaceInspectResponse {
    try stopWorkspaceRun(runID: runID, runsDirectory: runsDir ?? ".triton/runs")
}

func handleWorkspaceHTTPExportFlow(runID: String, body: Data) throws -> TKWorkspaceExportFlowResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPExportFlowRequest.self, from: body)
    return try exportWorkspaceFlow(
        runID: runID,
        runsDirectory: request.runsDir ?? ".triton/runs",
        output: request.output
    )
}

private func decodeWorkspaceHTTP<T: Decodable>(_ type: T.Type, from body: Data) throws -> T {
    do {
        return try JSONDecoder().decode(type, from: body)
    } catch {
        throw RuntimeError("Invalid workspace HTTP payload: \(error)")
    }
}
