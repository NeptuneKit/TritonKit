import Foundation
import TritonKitShared

struct TKTestRecorderManifest: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let name: String
    let sourcePlatform: String?
    let tritonKitVersion: String
    let capabilitiesRef: String
    let redactionStatus: String
    let truncationStatus: String

    init(schemaVersion: Int, kind: String, name: String, sourcePlatform: String?, tritonKitVersion: String = "unknown", capabilitiesRef: String = "contract-capabilities.json", redactionStatus: String = "pending", truncationStatus: String = "not-truncated") {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.name = name
        self.sourcePlatform = sourcePlatform
        self.tritonKitVersion = tritonKitVersion
        self.capabilitiesRef = capabilitiesRef
        self.redactionStatus = redactionStatus
        self.truncationStatus = truncationStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.name = try container.decode(String.self, forKey: .name)
        self.sourcePlatform = try container.decodeIfPresent(String.self, forKey: .sourcePlatform)
        self.tritonKitVersion = try container.decodeIfPresent(String.self, forKey: .tritonKitVersion) ?? "unknown"
        self.capabilitiesRef = try container.decodeIfPresent(String.self, forKey: .capabilitiesRef) ?? "contract-capabilities.json"
        self.redactionStatus = try container.decodeIfPresent(String.self, forKey: .redactionStatus) ?? "pending"
        self.truncationStatus = try container.decodeIfPresent(String.self, forKey: .truncationStatus) ?? "not-truncated"
    }
}

struct TKTestRecorderContractCapabilities: Codable, Equatable {
    let schemaVersion: Int
    let actions: [String]
    let pages: [String]
    let network: [String]
}

struct TKTestRecorderSessionStartResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let sessionId: String
    let casePath: String
    let manifest: TKTestRecorderManifest
    let capabilities: TKTestRecorderContractCapabilities
    let suggestedCommands: [String]

    init(sessionId: String, casePath: String, manifest: TKTestRecorderManifest, capabilities: TKTestRecorderContractCapabilities) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.testrec.session-start"
        self.sessionId = sessionId
        self.casePath = casePath
        self.manifest = manifest
        self.capabilities = capabilities
        self.suggestedCommands = [
            "triton testrec event --session \(sessionId) --kind action --payload-json <json> --json",
            "triton testrec stop --session \(sessionId) --json",
            "triton testrec inspect \(casePath) --json",
        ]
    }
}

struct TKTestRecorderEventResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let sessionId: String
    let casePath: String
    let eventKind: String
    let eventPath: String
    let eventCount: Int
    let suggestedCommands: [String]

    init(sessionId: String, casePath: String, eventKind: String, eventPath: String, eventCount: Int) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.testrec.event"
        self.sessionId = sessionId
        self.casePath = casePath
        self.eventKind = eventKind
        self.eventPath = eventPath
        self.eventCount = eventCount
        self.suggestedCommands = [
            "triton testrec event --session \(sessionId) --kind action --payload-json <json> --json",
            "triton testrec stop --session \(sessionId) --json",
            "triton testrec inspect \(casePath) --json",
        ]
    }
}

struct TKTestRecorderSessionStopResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let sessionId: String
    let casePath: String
    let eventCount: Int
    let artifacts: [TKTestRecorderArtifact]
    let suggestedCommands: [String]

    init(sessionId: String, casePath: String, eventCount: Int, artifacts: [TKTestRecorderArtifact]) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.testrec.session-stop"
        self.sessionId = sessionId
        self.casePath = casePath
        self.eventCount = eventCount
        self.artifacts = artifacts
        self.suggestedCommands = [
            "triton testrec inspect \(casePath) --json",
            "triton testrec compile \(casePath) --json",
        ]
    }
}

struct TKTestRecorderHTTPSessionCreateRequest: Codable, Equatable {
    let platform: String
    let caseName: String
    let output: String
}

struct TKTestRecorderHTTPEventRequest: Codable, Equatable {
    let kind: String
    let payload: TKJSONValue
}

struct TKTestRecorderHTTPCasePathRequest: Codable, Equatable {
    let path: String
}

struct TKTestRecorderHTTPCompileRequest: Codable, Equatable {
    let path: String
    let output: String?
}

struct TKTestRecorderHTTPReplayRequest: Codable, Equatable {
    let path: String
    let platform: String
    let device: String?
    let dryRun: Bool?
    let executor: String?
    let evidenceDir: String?
    let targetFingerprints: TKJSONValue?
}

struct TKTestRecorderHTTPMatrixRequest: Codable, Equatable {
    let path: String
    let targets: String
    let executor: String?
    let evidenceRoot: String?
    let targetFingerprints: TKJSONValue?
}

struct TKTestRecorderHTTPPageMatchRequest: Codable, Equatable {
    let path: String
    let page: String
    let candidate: TKJSONValue
}

struct TKTestRecorderUnsupportedCapability: Codable, Equatable {
    let domain: String
    let name: String
}

struct TKTestRecorderArtifact: Codable, Equatable {
    let kind: String
    let path: String
    let required: Bool
    let present: Bool
    let byteCount: Int?
    let digestAlgorithm: String?
    let digest: String?
}

struct TKTestRecorderLifecycle: Codable, Equatable {
    let stage: String
    let health: String
    let hasCompiledContract: Bool
    let hasCompileProposals: Bool
}

struct TKTestRecorderInspectResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let path: String
    let manifest: TKTestRecorderManifest
    let capabilities: TKTestRecorderContractCapabilities
    let lifecycle: TKTestRecorderLifecycle
    let unsupportedCapabilities: [TKTestRecorderUnsupportedCapability]
    let artifacts: [TKTestRecorderArtifact]
    let suggestedCommands: [String]

    init(path: String, manifest: TKTestRecorderManifest, capabilities: TKTestRecorderContractCapabilities, unsupportedCapabilities: [TKTestRecorderUnsupportedCapability], artifacts: [TKTestRecorderArtifact]) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.testrec.inspect"
        self.path = path
        self.manifest = manifest
        self.capabilities = capabilities
        self.lifecycle = testRecorderLifecycle(artifacts: artifacts)
        self.unsupportedCapabilities = unsupportedCapabilities
        self.artifacts = artifacts
        self.suggestedCommands = [
            "triton schema --command testrec --json",
        ]
    }
}

struct TKTestRecorderCompileWarning: Codable, Equatable {
    let code: String
    let path: String
    let message: String
}

struct TKTestRecorderCompileSummary: Codable, Equatable {
    let actionEventCount: Int
    let networkEventCount: Int
    let pageRouteEventCount: Int
    let pageFingerprintCount: Int
}

struct TKTestRecorderCompilerInfo: Codable, Equatable {
    let mode: String
    let llmUsed: Bool
    let vlmUsed: Bool
    let proposalCount: Int
}

struct TKTestRecorderCompiledAction: Codable, Equatable {
    let index: Int
    let sourceEventID: String?
    let action: String
    let sourcePath: String
    let targetText: String?
    let inputText: String?
}

struct TKTestRecorderCompiledNetworkRequest: Codable, Equatable {
    let index: Int
    let sourcePath: String
    let id: String?
    let method: String?
    let url: String?
    let statusCode: Int?
    let responseBody: String?

    init(
        index: Int,
        sourcePath: String,
        id: String?,
        method: String?,
        url: String?,
        statusCode: Int?,
        responseBody: String? = nil
    ) {
        self.index = index
        self.sourcePath = sourcePath
        self.id = id
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.responseBody = responseBody
    }

    private enum CodingKeys: String, CodingKey {
        case index
        case sourcePath
        case id
        case method
        case url
        case statusCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.index = try container.decode(Int.self, forKey: .index)
        self.sourcePath = try container.decode(String.self, forKey: .sourcePath)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.method = try container.decodeIfPresent(String.self, forKey: .method)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
        self.responseBody = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(sourcePath, forKey: .sourcePath)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(method, forKey: .method)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(statusCode, forKey: .statusCode)
    }
}

struct TKTestRecorderCompiledNetwork: Codable, Equatable {
    let eventCount: Int
    let mode: String
    let requests: [TKTestRecorderCompiledNetworkRequest]
}

struct TKTestRecorderNetworkMapMatch: Codable, Equatable {
    let method: String?
    let url: String?
}

struct TKTestRecorderNetworkMapRule: Codable, Equatable {
    let index: Int
    let id: String
    let sourcePath: String
    let match: TKTestRecorderNetworkMapMatch
    let strategy: String
    let nonBlocking: Bool
    let reason: String
    let fixturePath: String?
    let redactionRequired: Bool
}

struct TKTestRecorderNetworkMap: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let rules: [TKTestRecorderNetworkMapRule]
}

struct TKTestRecorderActionMapTarget: Codable, Equatable {
    let label: String?
    let text: String?
    let selector: String?
}

struct TKTestRecorderActionMapRule: Codable, Equatable {
    let index: Int
    let id: String
    let sourceEventID: String?
    let sourcePath: String
    let action: String
    let target: TKTestRecorderActionMapTarget
    let strategy: String
    let requiresReview: Bool
    let redactionRequired: Bool
    let evidence: [String]
}

struct TKTestRecorderActionMap: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let rules: [TKTestRecorderActionMapRule]
}

struct TKTestRecorderCompiledPageRoute: Codable, Equatable {
    let index: Int
    let sourcePath: String
    let id: String?
    let route: String?
    let url: String?
}

struct TKTestRecorderCompiledPageFingerprint: Codable, Equatable {
    let index: Int
    let sourcePath: String
    let pageId: String?
    let route: String?
    let kind: String?
    let hash: String?
}

struct TKTestRecorderFingerprintMatchThresholds: Codable, Equatable {
    let matched: Double
    let assistedMatched: Double
    let needsReview: Double
}

struct TKTestRecorderFingerprintMatchPolicy: Codable, Equatable {
    let scorer: String
    let thresholds: TKTestRecorderFingerprintMatchThresholds
    let requiredElementGate: String
    let conflictPolicy: String
    let vlmRole: String
    let llmRole: String
    let llmDecisionAuthority: Bool
}

struct TKTestRecorderQualityFinding: Codable, Equatable {
    let code: String
    let path: String
    let severity: String
    let message: String
    let proposalKind: String
}

struct TKTestRecorderCompileProposal: Codable, Equatable {
    let schemaVersion: Int
    let id: String
    let proposalKind: String
    let findingCode: String
    let sourcePath: String
    let status: String
    let summary: String
    let suggestedChange: String
}

struct TKTestRecorderCompiledPages: Codable, Equatable {
    let routeEventCount: Int
    let fingerprintCount: Int
    let matchingEvidence: [String]
    let matchPolicy: TKTestRecorderFingerprintMatchPolicy
    let routes: [TKTestRecorderCompiledPageRoute]
    let fingerprints: [TKTestRecorderCompiledPageFingerprint]
}

struct TKTestRecorderPageMapEntry: Codable, Equatable {
    let index: Int
    let id: String
    let route: String?
    let url: String?
    let routeSourcePath: String?
    let fingerprintSourcePath: String?
    let fingerprintHash: String?
    let evidence: [String]
}

struct TKTestRecorderPageMap: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let matchPolicy: TKTestRecorderFingerprintMatchPolicy
    let pages: [TKTestRecorderPageMapEntry]
}

struct TKTestRecorderCompiledContract: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let caseName: String
    let sourcePlatform: String?
    let compiler: TKTestRecorderCompilerInfo
    let capabilities: TKTestRecorderContractCapabilities
    let actions: [TKTestRecorderCompiledAction]
    let network: TKTestRecorderCompiledNetwork
    let pages: TKTestRecorderCompiledPages
    let qualityFindings: [TKTestRecorderQualityFinding]
    let warnings: [TKTestRecorderCompileWarning]
}

struct TKTestRecorderContractArtifact: Codable, Equatable {
    let path: String
    let absolutePath: String
    let contentType: String
    let written: Bool
    let byteCount: Int
}

struct TKTestRecorderCompileResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let path: String
    let status: String
    let manifest: TKTestRecorderManifest
    let capabilities: TKTestRecorderContractCapabilities
    let summary: TKTestRecorderCompileSummary
    let compiledContract: TKTestRecorderCompiledContract?
    let contractArtifact: TKTestRecorderContractArtifact?
    let actionMapArtifact: TKTestRecorderContractArtifact?
    let networkMapArtifact: TKTestRecorderContractArtifact?
    let pageMapArtifact: TKTestRecorderContractArtifact?
    let proposalArtifact: TKTestRecorderContractArtifact?
    let artifacts: [TKTestRecorderArtifact]
    let warnings: [TKTestRecorderCompileWarning]
    let suggestedCommands: [String]

    init(path: String, inspect: TKTestRecorderInspectResponse, summary: TKTestRecorderCompileSummary, warnings: [TKTestRecorderCompileWarning], compiledContract: TKTestRecorderCompiledContract?, contractArtifact: TKTestRecorderContractArtifact?, actionMapArtifact: TKTestRecorderContractArtifact?, networkMapArtifact: TKTestRecorderContractArtifact?, pageMapArtifact: TKTestRecorderContractArtifact?, proposalArtifact: TKTestRecorderContractArtifact?) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.testrec.compile"
        self.path = path
        self.status = compileStatus(summary: summary, warnings: warnings)
        self.manifest = inspect.manifest
        self.capabilities = inspect.capabilities
        self.summary = summary
        self.compiledContract = compiledContract
        self.contractArtifact = contractArtifact
        self.actionMapArtifact = actionMapArtifact
        self.networkMapArtifact = networkMapArtifact
        self.pageMapArtifact = pageMapArtifact
        self.proposalArtifact = proposalArtifact
        self.artifacts = inspect.artifacts
        self.warnings = warnings
        self.suggestedCommands = [
            "triton testrec inspect \(path) --json",
        ]
    }
}

struct TKTestRecorderProposalsResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let path: String
    let proposalCount: Int
    let proposals: [TKTestRecorderCompileProposal]
    let suggestedCommands: [String]

    init(path: String, proposals: [TKTestRecorderCompileProposal]) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.testrec.proposals"
        self.path = path
        self.proposalCount = proposals.count
        self.proposals = proposals
        self.suggestedCommands = [
            "triton testrec inspect \(path) --json",
        ]
    }
}

struct TKTestRecorderReplayBlocker: Codable, Equatable {
    let code: String
    let path: String
    let message: String
}

struct TKTestRecorderReplayPlannedStep: Codable, Equatable {
    let index: Int
    let sourceEventID: String?
    let action: String
    let status: String
    let sourcePath: String
    let command: String
    let argv: [String]
    let workflowCategories: [String]
    let expectedArtifacts: [String]
    let stopConditions: [String]
}

struct TKTestRecorderReplayPageCheck: Codable, Equatable {
    let index: Int
    let pageId: String?
    let route: String?
    let status: String
    let sourcePath: String
    let command: String
    let argv: [String]
    let expectedArtifacts: [String]
    let stopConditions: [String]
}

struct TKTestRecorderReplayExecutorProfile: Codable, Equatable {
    let id: String
    let status: String
    let mode: String
    let message: String
    let requirements: [TKTestRecorderReplayExecutorRequirement]
    let nextCommand: String?

    static func localSimulated(path: String, platform: String) -> TKTestRecorderReplayExecutorProfile {
        TKTestRecorderReplayExecutorProfile(
            id: "local-simulated",
            status: "available",
            mode: "offline-simulated",
            message: "Offline executor contract; no live device commands are executed.",
            requirements: [
                TKTestRecorderReplayExecutorRequirement(name: "compiled-contract", required: true, status: "satisfied", evidence: ["compiled-contract"]),
                TKTestRecorderReplayExecutorRequirement(name: "live-target-device", required: false, status: "not-required", evidence: ["local-simulated"]),
                TKTestRecorderReplayExecutorRequirement(name: "device-action-execution", required: false, status: "not-required", evidence: ["no-device-command-executed"]),
                TKTestRecorderReplayExecutorRequirement(name: "evidence-artifact-capture", required: false, status: "optional", evidence: ["--evidence-dir"]),
            ],
            nextCommand: "triton testrec replay \(path) --platform \(platform) --executor local-simulated --target-fingerprints-json <json> --evidence-dir <dir.tritonevidence> --json"
        )
    }

    static func localDeviceUnsupported() -> TKTestRecorderReplayExecutorProfile {
        TKTestRecorderReplayExecutorProfile(
            id: "local-device",
            status: "unsupported",
            mode: "device-execution",
            message: "Real device replay executor is not implemented yet; use local-simulated until all required capabilities are satisfied.",
            requirements: [
                TKTestRecorderReplayExecutorRequirement(name: "compiled-contract", required: true, status: "satisfied", evidence: ["compiled-contract"]),
                TKTestRecorderReplayExecutorRequirement(name: "live-target-device", required: true, status: "missing", evidence: ["target-readiness:not-wired"]),
                TKTestRecorderReplayExecutorRequirement(name: "device-action-execution", required: true, status: "missing", evidence: ["act-runner:not-wired"]),
                TKTestRecorderReplayExecutorRequirement(name: "evidence-artifact-capture", required: true, status: "missing", evidence: ["artifact-writer:not-wired"]),
                TKTestRecorderReplayExecutorRequirement(name: "network-policy-application", required: true, status: "missing", evidence: ["network-policy:not-wired"]),
            ],
            nextCommand: "triton schema --command testrec --json"
        )
    }
}

struct TKTestRecorderReplayDryRunResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let path: String
    let dryRun: Bool
    let platform: String
    let device: String?
    let status: String
    let manifest: TKTestRecorderManifest
    let capabilities: TKTestRecorderContractCapabilities
    let compileSummary: TKTestRecorderCompileSummary
    let contractRef: TKTestRecorderReplayContractRef?
    let pageChecks: [TKTestRecorderReplayPageCheck]
    let executorProfiles: [TKTestRecorderReplayExecutorProfile]
    let plannedSteps: [TKTestRecorderReplayPlannedStep]
    let blockers: [TKTestRecorderReplayBlocker]
    let suggestedCommands: [String]

    init(path: String, platform: String, device: String?, compile: TKTestRecorderCompileResponse, contractRef: TKTestRecorderReplayContractRef?, pageChecks: [TKTestRecorderReplayPageCheck], plannedSteps: [TKTestRecorderReplayPlannedStep], blockers: [TKTestRecorderReplayBlocker]) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.testrec.replay-dry-run"
        self.path = path
        self.dryRun = true
        self.platform = platform
        self.device = device
        self.status = blockers.isEmpty ? "ready" : "blocked"
        self.manifest = compile.manifest
        self.capabilities = compile.capabilities
        self.compileSummary = compile.summary
        self.contractRef = contractRef
        self.pageChecks = pageChecks
        self.executorProfiles = [
            .localSimulated(path: path, platform: platform),
            .localDeviceUnsupported(),
        ]
        self.plannedSteps = plannedSteps
        self.blockers = blockers
        self.suggestedCommands = [
            "triton testrec compile \(path) --json",
        ]
    }
}

struct TKTestRecorderReplayPageResult: Codable, Equatable {
    let index: Int
    let pageId: String?
    let route: String?
    let status: String
    let matchScore: Double?
    let matchDecision: String?
    let sourcePath: String
    let artifactRefs: [String]
    let evidence: [String]
    let expectedArtifacts: [String]
}

struct TKTestRecorderReplayStepResult: Codable, Equatable {
    let index: Int
    let sourceEventID: String?
    let action: String
    let status: String
    let sourcePath: String
    let command: String
    let argv: [String]
    let deviceCommandExecuted: Bool
    let artifactRefs: [String]
    let evidence: [String]
    let failure: TKTestRecorderReplayStepFailure?
    let expectedArtifacts: [String]
    let stopConditions: [String]
}

struct TKTestRecorderReplayStepFailure: Codable, Equatable {
    let code: String
    let message: String
    let path: String?
    let artifactRefs: [String]
    let recoveryCommands: [String]
    let retryable: Bool
}

struct TKTestRecorderReplayNetworkResult: Codable, Equatable {
    let index: Int
    let id: String
    let status: String
    let strategy: String
    let sourcePath: String
    let method: String?
    let url: String?
    let nonBlocking: Bool
    let redactionRequired: Bool
    let fixturePath: String?
    let artifactRefs: [String]
    let evidence: [String]
}

struct TKTestRecorderReplayExecutionSummary: Codable, Equatable {
    let mode: String
    let executor: String
    let requiresDevice: Bool
    let deviceCommandsExecuted: Bool
    let llmUsed: Bool
    let vlmUsed: Bool
    let networkPolicyMode: String
    let stepStatusTaxonomy: [String]
    let executorRequirements: [TKTestRecorderReplayExecutorRequirement]
    let evidence: [String]

    static func localDeviceBlocked(
        failureCode: String = "target_not_found",
        liveTargetStatus: String = "missing",
        liveTargetEvidence: [String] = ["target_not_found", "target-readiness:not-wired"],
        deviceActionEvidence: [String] = ["act-runner:not-wired", "no-device-command-executed"]
    ) -> TKTestRecorderReplayExecutionSummary {
        TKTestRecorderReplayExecutionSummary(
            mode: "device-execution",
            executor: "local-device",
            requiresDevice: true,
            deviceCommandsExecuted: false,
            llmUsed: false,
            vlmUsed: false,
            networkPolicyMode: "not-applied",
            stepStatusTaxonomy: ["executed", "failed", "skipped", "blocked", "not-run"],
            executorRequirements: [
                TKTestRecorderReplayExecutorRequirement(name: "compiled-contract", required: true, status: "satisfied", evidence: ["compiled-contract"]),
                TKTestRecorderReplayExecutorRequirement(name: "live-target-device", required: true, status: liveTargetStatus, evidence: liveTargetEvidence),
                TKTestRecorderReplayExecutorRequirement(name: "device-action-execution", required: true, status: "missing", evidence: deviceActionEvidence),
                TKTestRecorderReplayExecutorRequirement(name: "evidence-artifact-capture", required: true, status: "missing", evidence: ["artifact-writer:not-wired"]),
                TKTestRecorderReplayExecutorRequirement(name: "network-policy-application", required: true, status: "missing", evidence: ["network-policy:not-wired"]),
            ],
            evidence: [
                "compiled-contract",
                failureCode,
                "no-device-command-executed",
                "llm:unused",
                "vlm:unused",
                "network-policy:not-applied",
            ]
        )
    }

    static func localSimulated(executor: String, hasNetworkResults: Bool, writesEvidence: Bool) -> TKTestRecorderReplayExecutionSummary {
        TKTestRecorderReplayExecutionSummary(
            mode: "offline-simulated",
            executor: executor,
            requiresDevice: false,
            deviceCommandsExecuted: false,
            llmUsed: false,
            vlmUsed: false,
            networkPolicyMode: hasNetworkResults ? "simulated-projection" : "not-present",
            stepStatusTaxonomy: ["executed", "failed", "skipped", "blocked", "not-run", "simulated-passed"],
            executorRequirements: [
                TKTestRecorderReplayExecutorRequirement(
                    name: "compiled-contract",
                    required: true,
                    status: "satisfied",
                    evidence: ["compiled-contract"]
                ),
                TKTestRecorderReplayExecutorRequirement(
                    name: "live-target-device",
                    required: false,
                    status: "not-required",
                    evidence: ["local-simulated", "no-target-device"]
                ),
                TKTestRecorderReplayExecutorRequirement(
                    name: "device-action-execution",
                    required: false,
                    status: "not-required",
                    evidence: ["no-device-command-executed"]
                ),
                TKTestRecorderReplayExecutorRequirement(
                    name: "network-policy-application",
                    required: false,
                    status: hasNetworkResults ? "simulated" : "not-present",
                    evidence: [hasNetworkResults ? "network-map-simulated" : "network-map:not-present"]
                ),
                TKTestRecorderReplayExecutorRequirement(
                    name: "evidence-artifact-capture",
                    required: false,
                    status: writesEvidence ? "satisfied" : "not-requested",
                    evidence: [writesEvidence ? "evidence-bundle" : "evidence-dir:not-requested"]
                ),
            ],
            evidence: [
                "compiled-contract",
                "local-simulated",
                "no-device-command-executed",
                "llm:unused",
                "vlm:unused",
                hasNetworkResults ? "network-map-simulated" : "network-map:not-present",
            ]
        )
    }
}

struct TKTestRecorderReplayExecutorRequirement: Codable, Equatable {
    let name: String
    let required: Bool
    let status: String
    let evidence: [String]
}

struct TKTestRecorderReplayContractRef: Codable, Equatable {
    let path: String
    let byteCount: Int
    let digestAlgorithm: String
    let digest: String
}

struct TKTestRecorderReplayEvidenceSummary: Codable, Equatable {
    let expectedEventCount: Int
    let pageEventCount: Int
    let networkEventCount: Int
    let stepEventCount: Int
    let artifactRefCount: Int
    let pageArtifactRefCount: Int
    let networkArtifactRefCount: Int
    let stepArtifactRefCount: Int
    let blockerCount: Int
    let statusConsistent: Bool

    init(status: String, artifactRefs: [String], pageResults: [TKTestRecorderReplayPageResult], networkResults: [TKTestRecorderReplayNetworkResult], steps: [TKTestRecorderReplayStepResult], blockers: [TKTestRecorderReplayBlocker]) {
        self.pageEventCount = pageResults.count
        self.networkEventCount = networkResults.count
        self.stepEventCount = steps.count
        self.artifactRefCount = Set(artifactRefs).count
        self.pageArtifactRefCount = pageResults.reduce(0) { $0 + $1.artifactRefs.count }
        self.networkArtifactRefCount = networkResults.reduce(0) { $0 + $1.artifactRefs.count }
        self.stepArtifactRefCount = steps.reduce(0) { partial, step in
            partial + step.artifactRefs.count + (step.failure?.artifactRefs.count ?? 0)
        }
        self.blockerCount = blockers.count
        self.expectedEventCount = 2 + pageResults.count + networkResults.count + steps.count
        self.statusConsistent = (status == "passed" && blockers.isEmpty) || (status == "blocked" && !blockers.isEmpty)
    }
}

struct TKTestRecorderReplayRunResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let path: String
    let dryRun: Bool
    let executor: String
    let platform: String
    let device: String?
    let status: String
    let manifest: TKTestRecorderManifest
    let capabilities: TKTestRecorderContractCapabilities
    let compileSummary: TKTestRecorderCompileSummary
    let contractRef: TKTestRecorderReplayContractRef?
    let evidenceDir: String?
    let artifactRefs: [String]
    let execution: TKTestRecorderReplayExecutionSummary
    let evidenceSummary: TKTestRecorderReplayEvidenceSummary
    let pageResults: [TKTestRecorderReplayPageResult]
    let networkResults: [TKTestRecorderReplayNetworkResult]
    let steps: [TKTestRecorderReplayStepResult]
    let blockers: [TKTestRecorderReplayBlocker]
    let suggestedCommands: [String]

    init(plan: TKTestRecorderReplayDryRunResponse, executor: String, evidenceDir: String? = nil, artifactRefs: [String] = [], pageResults: [TKTestRecorderReplayPageResult], networkResults: [TKTestRecorderReplayNetworkResult] = [], steps: [TKTestRecorderReplayStepResult], blockers: [TKTestRecorderReplayBlocker], execution: TKTestRecorderReplayExecutionSummary? = nil) {
        self.ok = blockers.isEmpty
        self.schemaVersion = 1
        self.kind = "triton.testrec.replay-result"
        self.path = plan.path
        self.dryRun = false
        self.executor = executor
        self.platform = plan.platform
        self.device = plan.device
        self.status = blockers.isEmpty ? "passed" : "blocked"
        self.manifest = plan.manifest
        self.capabilities = plan.capabilities
        self.compileSummary = plan.compileSummary
        self.contractRef = plan.contractRef
        self.evidenceDir = evidenceDir
        self.artifactRefs = artifactRefs
        self.execution = execution ?? .localSimulated(
            executor: executor,
            hasNetworkResults: !networkResults.isEmpty,
            writesEvidence: !artifactRefs.isEmpty
        )
        self.evidenceSummary = TKTestRecorderReplayEvidenceSummary(
            status: self.status,
            artifactRefs: artifactRefs,
            pageResults: pageResults,
            networkResults: networkResults,
            steps: steps,
            blockers: blockers
        )
        self.pageResults = pageResults
        self.networkResults = networkResults
        self.steps = steps
        self.blockers = blockers
        self.suggestedCommands = [
            "triton testrec inspect \(plan.path) --json",
            "triton testrec replay \(plan.path) --platform \(plan.platform) --dry-run --json",
        ]
    }
}

struct TKTestRecorderMatrixTarget: Codable, Equatable {
    let raw: String
    let platform: String
    let device: String?
}

struct TKTestRecorderMatrixTargetResult: Codable, Equatable {
    let target: String
    let platform: String
    let device: String?
    let status: String
    let dryRun: Bool
    let executor: String?
    let plannedStepCount: Int
    let pageCheckCount: Int
    let networkResultCount: Int
    let stepResultCount: Int
    let evidenceDir: String?
    let blockers: [TKTestRecorderReplayBlocker]
    let suggestedCommand: String

    init(target: TKTestRecorderMatrixTarget, plan: TKTestRecorderReplayDryRunResponse) {
        self.target = target.raw
        self.platform = target.platform
        self.device = target.device
        self.status = plan.status
        self.dryRun = true
        self.executor = nil
        self.plannedStepCount = plan.plannedSteps.count
        self.pageCheckCount = plan.pageChecks.count
        self.networkResultCount = 0
        self.stepResultCount = 0
        self.evidenceDir = nil
        self.blockers = plan.blockers
        var command = "triton testrec replay \(shellQuotedEvidencePath(plan.path)) --platform \(target.platform)"
        if let device = target.device {
            command += " --device \(shellQuotedEvidencePath(device))"
        }
        self.suggestedCommand = command + " --dry-run --json"
    }

    init(target: TKTestRecorderMatrixTarget, run: TKTestRecorderReplayRunResponse, evidenceDir: String?) {
        self.target = target.raw
        self.platform = target.platform
        self.device = target.device
        self.status = run.status
        self.dryRun = false
        self.executor = run.executor
        self.plannedStepCount = run.steps.count
        self.pageCheckCount = run.pageResults.count
        self.networkResultCount = run.networkResults.count
        self.stepResultCount = run.steps.count
        self.evidenceDir = evidenceDir
        self.blockers = run.blockers
        var command = "triton testrec replay \(shellQuotedEvidencePath(run.path)) --platform \(target.platform)"
        if let device = target.device {
            command += " --device \(shellQuotedEvidencePath(device))"
        }
        command += " --executor \(run.executor)"
        if let evidenceDir {
            command += " --evidence-dir \(shellQuotedEvidencePath(evidenceDir))"
        }
        self.suggestedCommand = command + " --json"
    }
}

struct TKTestRecorderMatrixResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let path: String
    let executor: String?
    let evidenceRoot: String?
    let status: String
    let targetCount: Int
    let readyCount: Int
    let passedCount: Int
    let blockedCount: Int
    let results: [TKTestRecorderMatrixTargetResult]
    let suggestedCommands: [String]

    init(path: String, targets: String, executor: String?, evidenceRoot: String?, results: [TKTestRecorderMatrixTargetResult]) {
        self.ok = results.allSatisfy { ["ready", "passed"].contains($0.status) }
        self.schemaVersion = 1
        self.kind = "triton.testrec.matrix"
        self.path = path
        self.executor = executor
        self.evidenceRoot = evidenceRoot
        self.targetCount = results.count
        self.readyCount = results.filter { $0.status == "ready" }.count
        self.passedCount = results.filter { $0.status == "passed" }.count
        self.blockedCount = results.filter { $0.status == "blocked" }.count
        self.status = blockedCount == 0 ? (executor == nil ? "ready" : "passed") : "blocked"
        self.results = results
        var suggestedCommands = ["triton testrec matrix \(path) --targets \(targets) --json"]
        suggestedCommands += results.compactMap(\.evidenceDir).map { "triton evidence summary \(shellQuotedEvidencePath($0)) --json" }
        self.suggestedCommands = suggestedCommands
    }
}

struct TKTestRecorderFingerprintMatchComponent: Codable, Equatable {
    let name: String
    let weight: Double
    let score: Double
    let evidence: String
}

struct TKTestRecorderFingerprintMatchSubject: Codable, Equatable {
    let pageId: String?
    let route: String?
    let kind: String?
    let hash: String?
}

struct TKTestRecorderFingerprintMatchResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let path: String
    let page: String
    let source: TKTestRecorderCompiledPageFingerprint
    let candidate: TKTestRecorderFingerprintMatchSubject
    let policy: TKTestRecorderFingerprintMatchPolicy
    let scorer: String
    let score: Double
    let decision: String
    let components: [TKTestRecorderFingerprintMatchComponent]
    let evidence: [String]
    let llmUsed: Bool
    let llmDecisionAuthority: Bool
    let suggestedCommands: [String]

    init(path: String, page: String, source: TKTestRecorderCompiledPageFingerprint, candidate: TKTestRecorderFingerprintMatchSubject, policy: TKTestRecorderFingerprintMatchPolicy, score: Double, decision: String, components: [TKTestRecorderFingerprintMatchComponent], evidence: [String]) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.testrec.page-fingerprint-match"
        self.path = path
        self.page = page
        self.source = source
        self.candidate = candidate
        self.policy = policy
        self.scorer = policy.scorer
        self.score = score
        self.decision = decision
        self.components = components
        self.evidence = evidence
        self.llmUsed = false
        self.llmDecisionAuthority = policy.llmDecisionAuthority
        self.suggestedCommands = [
            "triton testrec inspect \(shellQuotedEvidencePath(path)) --json",
            "triton testrec proposals \(shellQuotedEvidencePath(path)) --json",
            "triton testrec compile \(shellQuotedEvidencePath(path)) --json",
        ]
    }
}

struct TKTestRecorderValidationErrorDetail: Codable, Equatable {
    let type: String
    let message: String
    let path: String
    let code: String
    let hint: String?
}

struct TKTestRecorderValidationFailure: Error, Equatable {
    let detail: TKTestRecorderValidationErrorDetail
}

struct TKTestRecorderValidationFailureResponse: Codable, Equatable {
    let ok: Bool
    let error: TKTestRecorderValidationErrorDetail

    init(_ failure: TKTestRecorderValidationFailure) {
        self.ok = false
        self.error = failure.detail
    }
}
