import Foundation
import TritonKitShared

struct TKWorkspaceRunRequest {
    let runsDirectory: String
    let runID: String?
    let target: String
    let platform: String?
    let scope: String?
    let app: String
    let goal: String
    let actionPolicy: String
    let appMode: String
    let bundleID: String?
    let packageName: String?
    let activity: String?
    let bundle: String?
    let ability: String?
    let adb: String
    let dryModelFixture: Bool
    let llmProvider: String?
    let llmBaseURL: String?
    let llmModel: String?
    let llmAPIKeyEnv: String?
    let allowRemoteLLM: Bool
    let vlmProvider: String?
    let vlmBaseURL: String?
    let vlmModel: String?
    let vlmModelPath: String?
    let vlmHelper: String?
    let vlmAllowModelDownload: Bool
    let vlmAPIKeyEnv: String?
    let allowRemoteVLM: Bool
    let maxSteps: Int?
    let allowedActions: [String]
    let stopConditions: [String]
    let observationFixture: String?
    let observeLive: Bool
    let observeKind: String
    let observeMaxNodes: Int?
    let observeOutput: String?
    let observeRuntimeBaseURL: String?
    let observeHost: String
    let observePort: Int
    let hdc: String
    let businessReadyText: String?
    let businessReadyLiveWait: Bool
    let businessReadyAssert: Bool
    let businessReadyTimeout: Double
    let businessReadyInterval: Double
    let resolveTarget: Bool
    let executeActions: Bool
    let visualSettle: VisualSettleConfiguration?

    init(
        runsDirectory: String,
        runID: String?,
        target: String,
        platform: String? = nil,
        scope: String? = nil,
        app: String,
        goal: String,
        actionPolicy: String,
        appMode: String = "dry",
        bundleID: String? = nil,
        packageName: String? = nil,
        activity: String? = nil,
        bundle: String? = nil,
        ability: String? = nil,
        adb: String = "adb",
        dryModelFixture: Bool = false,
        llmProvider: String? = nil,
        llmBaseURL: String? = nil,
        llmModel: String? = nil,
        llmAPIKeyEnv: String? = nil,
        allowRemoteLLM: Bool = false,
        vlmProvider: String? = nil,
        vlmBaseURL: String? = nil,
        vlmModel: String? = nil,
        vlmModelPath: String? = nil,
        vlmHelper: String? = nil,
        vlmAllowModelDownload: Bool = false,
        vlmAPIKeyEnv: String? = nil,
        allowRemoteVLM: Bool = false,
        maxSteps: Int? = nil,
        allowedActions: [String] = [],
        stopConditions: [String] = [],
        observationFixture: String? = nil,
        observeLive: Bool = false,
        observeKind: String = "tree",
        observeMaxNodes: Int? = nil,
        observeOutput: String? = nil,
        observeRuntimeBaseURL: String? = nil,
        observeHost: String = "127.0.0.1",
        observePort: Int = 19421,
        hdc: String = "hdc",
        businessReadyText: String? = nil,
        businessReadyLiveWait: Bool = false,
        businessReadyAssert: Bool = false,
        businessReadyTimeout: Double = 10,
        businessReadyInterval: Double = 0.5,
        resolveTarget: Bool = false,
        executeActions: Bool = false,
        visualSettle: VisualSettleConfiguration? = nil
    ) {
        self.runsDirectory = runsDirectory
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
        self.dryModelFixture = dryModelFixture
        self.llmProvider = llmProvider
        self.llmBaseURL = llmBaseURL
        self.llmModel = llmModel
        self.llmAPIKeyEnv = llmAPIKeyEnv
        self.allowRemoteLLM = allowRemoteLLM
        self.vlmProvider = vlmProvider
        self.vlmBaseURL = vlmBaseURL
        self.vlmModel = vlmModel
        self.vlmModelPath = vlmModelPath
        self.vlmHelper = vlmHelper
        self.vlmAllowModelDownload = vlmAllowModelDownload
        self.vlmAPIKeyEnv = vlmAPIKeyEnv
        self.allowRemoteVLM = allowRemoteVLM
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
        self.businessReadyAssert = businessReadyAssert
        self.businessReadyTimeout = businessReadyTimeout
        self.businessReadyInterval = businessReadyInterval
        self.resolveTarget = resolveTarget
        self.executeActions = executeActions
        self.visualSettle = visualSettle
    }

    func resolvingRunID() throws -> TKWorkspaceRunRequest {
        let resolvedRunID = try normalizedWorkspaceRunID(runID ?? defaultWorkspaceRunID())
        if runID == resolvedRunID {
            return self
        }
        return TKWorkspaceRunRequest(
            runsDirectory: runsDirectory,
            runID: resolvedRunID,
            target: target,
            platform: platform,
            scope: scope,
            app: app,
            goal: goal,
            actionPolicy: actionPolicy,
            appMode: appMode,
            bundleID: bundleID,
            packageName: packageName,
            activity: activity,
            bundle: bundle,
            ability: ability,
            adb: adb,
            dryModelFixture: dryModelFixture,
            llmProvider: llmProvider,
            llmBaseURL: llmBaseURL,
            llmModel: llmModel,
            llmAPIKeyEnv: llmAPIKeyEnv,
            allowRemoteLLM: allowRemoteLLM,
            vlmProvider: vlmProvider,
            vlmBaseURL: vlmBaseURL,
            vlmModel: vlmModel,
            vlmModelPath: vlmModelPath,
            vlmHelper: vlmHelper,
            vlmAllowModelDownload: vlmAllowModelDownload,
            vlmAPIKeyEnv: vlmAPIKeyEnv,
            allowRemoteVLM: allowRemoteVLM,
            maxSteps: maxSteps,
            allowedActions: allowedActions,
            stopConditions: stopConditions,
            observationFixture: observationFixture,
            observeLive: observeLive,
            observeKind: observeKind,
            observeMaxNodes: observeMaxNodes,
            observeOutput: observeOutput,
            observeRuntimeBaseURL: observeRuntimeBaseURL,
            observeHost: observeHost,
            observePort: observePort,
            hdc: hdc,
            businessReadyText: businessReadyText,
            businessReadyLiveWait: businessReadyLiveWait,
            businessReadyAssert: businessReadyAssert,
            businessReadyTimeout: businessReadyTimeout,
            businessReadyInterval: businessReadyInterval,
            resolveTarget: resolveTarget,
            executeActions: executeActions,
            visualSettle: visualSettle
        )
    }

}

struct TKWorkspaceRunResponse: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let runID: String
    let goal: String
    let status: String
    let target: TKWorkspaceRunTarget
    let app: String
    let ai: TKWorkspaceRunAI
    let runner: TKWorkspaceRunRunner?
    let business: TKWorkspaceBusinessReadiness?
    let visualFeedback: VisualSettleOutput?
    let paths: TKWorkspaceRunPaths
    let nextActions: [TKWorkspaceNextAction]

    init(
        schemaVersion: Int = 1,
        kind: String = "triton.workspace.run",
        runID: String,
        goal: String,
        status: String,
        target: TKWorkspaceRunTarget,
        app: String,
        ai: TKWorkspaceRunAI,
        runner: TKWorkspaceRunRunner? = nil,
        business: TKWorkspaceBusinessReadiness? = nil,
        visualFeedback: VisualSettleOutput? = nil,
        paths: TKWorkspaceRunPaths,
        nextActions: [TKWorkspaceNextAction]
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.runID = runID
        self.goal = goal
        self.status = status
        self.target = target
        self.app = app
        self.ai = ai
        self.runner = runner
        self.business = business
        self.visualFeedback = visualFeedback
        self.paths = paths
        self.nextActions = nextActions
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case runID = "runId"
        case goal
        case status
        case target
        case app
        case ai
        case runner
        case business
        case visualFeedback
        case paths
        case nextActions
    }
}
