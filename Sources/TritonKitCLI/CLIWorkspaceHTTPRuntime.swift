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
    let observationFixture: String?
    let observeLive: Bool?
    let observeKind: String?
    let observeMaxNodes: Int?
    let observeOutput: String?
    let observeRuntimeBaseURL: String?
    let observeHost: String?
    let observePort: Int?
    let hdc: String?

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
        stopConditions: [String]? = nil,
        observationFixture: String? = nil,
        observeLive: Bool? = nil,
        observeKind: String? = nil,
        observeMaxNodes: Int? = nil,
        observeOutput: String? = nil,
        observeRuntimeBaseURL: String? = nil,
        observeHost: String? = nil,
        observePort: Int? = nil,
        hdc: String? = nil
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
        self.observationFixture = observationFixture
        self.observeLive = observeLive
        self.observeKind = observeKind
        self.observeMaxNodes = observeMaxNodes
        self.observeOutput = observeOutput
        self.observeRuntimeBaseURL = observeRuntimeBaseURL
        self.observeHost = observeHost
        self.observePort = observePort
        self.hdc = hdc
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
        case observationFixture
        case observeLive
        case observeKind
        case observeMaxNodes
        case observeOutput
        case observeRuntimeBaseURL
        case observeHost
        case observePort
        case hdc
    }
}

struct TKWorkspaceHTTPExportFlowRequest: Codable, Equatable {
    let runsDir: String?
    let output: String
}

func handleWorkspaceHTTPRun(body: Data) throws -> TKWorkspaceRunResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPRunRequest.self, from: body)
    return try runWorkspaceRun(workspaceRunRequest(from: request))
}

func handleWorkspaceHTTPRunAsync(
    body: Data,
    observeProvider: TKWorkspaceLiveObserveProvider = workspaceDefaultLiveObserveProvider
) async throws -> TKWorkspaceRunResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPRunRequest.self, from: body)
    return try await runWorkspaceRunAsync(workspaceRunRequest(from: request), observeProvider: observeProvider)
}

private func workspaceRunRequest(from request: TKWorkspaceHTTPRunRequest) -> TKWorkspaceRunRequest {
    TKWorkspaceRunRequest(
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
        stopConditions: request.stopConditions ?? [],
        observationFixture: request.observationFixture,
        observeLive: request.observeLive ?? false,
        observeKind: request.observeKind ?? "tree",
        observeMaxNodes: request.observeMaxNodes,
        observeOutput: request.observeOutput,
        observeRuntimeBaseURL: request.observeRuntimeBaseURL,
        observeHost: request.observeHost ?? "127.0.0.1",
        observePort: request.observePort ?? 19421,
        hdc: request.hdc ?? "hdc"
    )
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
