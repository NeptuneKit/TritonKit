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
    let appMode: String?
    let bundleID: String?
    let packageName: String?
    let activity: String?
    let bundle: String?
    let ability: String?
    let adb: String?
    let llmProvider: String?
    let llmBaseURL: String?
    let llmModel: String?
    let llmAPIKeyEnv: String?
    let allowRemoteLLM: Bool?
    let vlmProvider: String?
    let vlmBaseURL: String?
    let vlmModel: String?
    let vlmAPIKeyEnv: String?
    let allowRemoteVLM: Bool?
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
    let businessReadyText: String?
    let businessReadyLiveWait: Bool?
    let businessReadyTimeout: Double?
    let businessReadyInterval: Double?
    let executeActions: Bool?

    init(
        runsDir: String?,
        runID: String?,
        target: String?,
        platform: String? = nil,
        scope: String? = nil,
        app: String,
        goal: String,
        actionPolicy: String?,
        appMode: String? = nil,
        bundleID: String? = nil,
        packageName: String? = nil,
        activity: String? = nil,
        bundle: String? = nil,
        ability: String? = nil,
        adb: String? = nil,
        llmProvider: String? = nil,
        llmBaseURL: String? = nil,
        llmModel: String? = nil,
        llmAPIKeyEnv: String? = nil,
        allowRemoteLLM: Bool? = nil,
        vlmProvider: String? = nil,
        vlmBaseURL: String? = nil,
        vlmModel: String? = nil,
        vlmAPIKeyEnv: String? = nil,
        allowRemoteVLM: Bool? = nil,
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
        hdc: String? = nil,
        businessReadyText: String? = nil,
        businessReadyLiveWait: Bool? = nil,
        businessReadyTimeout: Double? = nil,
        businessReadyInterval: Double? = nil,
        executeActions: Bool? = nil
    ) {
        self.runsDir = runsDir
        self.runID = runID
        self.target = target
        self.platform = platform
        self.scope = scope
        self.app = app
        self.goal = goal
        self.actionPolicy = actionPolicy
        self.appMode = appMode
        self.bundleID = bundleID
        self.packageName = packageName
        self.activity = activity
        self.bundle = bundle
        self.ability = ability
        self.adb = adb
        self.llmProvider = llmProvider
        self.llmBaseURL = llmBaseURL
        self.llmModel = llmModel
        self.llmAPIKeyEnv = llmAPIKeyEnv
        self.allowRemoteLLM = allowRemoteLLM
        self.vlmProvider = vlmProvider
        self.vlmBaseURL = vlmBaseURL
        self.vlmModel = vlmModel
        self.vlmAPIKeyEnv = vlmAPIKeyEnv
        self.allowRemoteVLM = allowRemoteVLM
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
        self.businessReadyText = businessReadyText
        self.businessReadyLiveWait = businessReadyLiveWait
        self.businessReadyTimeout = businessReadyTimeout
        self.businessReadyInterval = businessReadyInterval
        self.executeActions = executeActions
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
        case appMode
        case bundleID
        case packageName
        case activity
        case bundle
        case ability
        case adb
        case llmProvider
        case llmBaseURL
        case llmModel
        case llmAPIKeyEnv
        case allowRemoteLLM
        case vlmProvider
        case vlmBaseURL
        case vlmModel
        case vlmAPIKeyEnv
        case allowRemoteVLM
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
        case businessReadyText
        case businessReadyLiveWait
        case businessReadyTimeout
        case businessReadyInterval
        case executeActions
    }
}

struct TKWorkspaceHTTPExportFlowRequest: Codable, Equatable {
    let runsDir: String?
    let output: String
}

struct TKWorkspaceHTTPMergeMapRequest: Codable, Equatable {
    let runsDir: String?
    let mapDir: String
    let confirm: Bool?
}

func handleWorkspaceHTTPRun(body: Data) throws -> TKWorkspaceRunResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPRunRequest.self, from: body)
    return try runWorkspaceRun(workspaceRunRequest(from: request))
}

func handleWorkspaceHTTPRunAsync(
    body: Data,
    observeProvider: TKWorkspaceLiveObserveProvider = workspaceDefaultLiveObserveProvider,
    appLifecycleProvider: TKWorkspaceAppLifecycleProvider = workspaceDefaultAppLifecycleProvider,
    businessWaitProvider: TKWorkspaceBusinessWaitProvider = workspaceDefaultBusinessWaitProvider,
    modelDecisionProvider: TKWorkspaceModelDecisionProvider = workspaceDefaultModelDecisionProvider,
    vlmGroundingProvider: TKWorkspaceVLMGroundingProvider = workspaceDefaultVLMGroundingProvider,
    actionExecutionProvider: TKWorkspaceActionExecutionProvider = workspaceDefaultActionExecutionProvider
) async throws -> TKWorkspaceRunResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPRunRequest.self, from: body)
    return try await runWorkspaceRunAsync(
        workspaceRunRequest(from: request),
        observeProvider: observeProvider,
        appLifecycleProvider: appLifecycleProvider,
        businessWaitProvider: businessWaitProvider,
        modelDecisionProvider: modelDecisionProvider,
        vlmGroundingProvider: vlmGroundingProvider,
        actionExecutionProvider: actionExecutionProvider
    )
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
        appMode: request.appMode ?? "dry",
        bundleID: request.bundleID,
        packageName: request.packageName,
        activity: request.activity,
        bundle: request.bundle,
        ability: request.ability,
        adb: request.adb ?? "adb",
        dryModelFixture: request.dryModelFixture ?? false,
        llmProvider: request.llmProvider,
        llmBaseURL: request.llmBaseURL,
        llmModel: request.llmModel,
        llmAPIKeyEnv: request.llmAPIKeyEnv,
        allowRemoteLLM: request.allowRemoteLLM ?? false,
        vlmProvider: request.vlmProvider,
        vlmBaseURL: request.vlmBaseURL,
        vlmModel: request.vlmModel,
        vlmAPIKeyEnv: request.vlmAPIKeyEnv,
        allowRemoteVLM: request.allowRemoteVLM ?? false,
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
        hdc: request.hdc ?? "hdc",
        businessReadyText: request.businessReadyText,
        businessReadyLiveWait: request.businessReadyLiveWait ?? false,
        businessReadyTimeout: request.businessReadyTimeout ?? 10,
        businessReadyInterval: request.businessReadyInterval ?? 0.5,
        executeActions: request.executeActions ?? false
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

func handleWorkspaceHTTPMergeMap(runID: String, body: Data) throws -> TKWorkspaceMergeMapResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPMergeMapRequest.self, from: body)
    return try mergeWorkspaceRunAppMap(
        runID: runID,
        runsDirectory: request.runsDir ?? ".triton/runs",
        mapDirectory: request.mapDir,
        confirm: request.confirm ?? false
    )
}

private func decodeWorkspaceHTTP<T: Decodable>(_ type: T.Type, from body: Data) throws -> T {
    do {
        return try JSONDecoder().decode(type, from: body)
    } catch {
        throw RuntimeError("Invalid workspace HTTP payload: \(error)")
    }
}
