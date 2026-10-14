import CryptoKit
import Foundation
import TritonKitShared

struct TKTestRunExecutionResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let input: String
    let evidenceDir: String
    let normalizedPlan: TKTestNormalizedPlan
    let run: TKTestRunMetadata
    let summary: TKTestRunEventSummary
    let failedStepIndex: Int?
    let failure: TKTestRunFailure?

    init(
        ok: Bool,
        input: String,
        evidenceDir: String,
        normalizedPlan: TKTestNormalizedPlan,
        run: TKTestRunMetadata,
        summary: TKTestRunEventSummary,
        failedStepIndex: Int? = nil,
        failure: TKTestRunFailure? = nil
    ) {
        self.ok = ok
        self.schemaVersion = 1
        self.kind = "triton.test.run-result"
        self.input = input
        self.evidenceDir = evidenceDir
        self.normalizedPlan = normalizedPlan
        self.run = run
        self.summary = summary
        self.failedStepIndex = failedStepIndex
        self.failure = failure
    }
}

struct TKTestRunExecutionContext {
    let evidenceDirectory: URL
    let target: String
    let host: String
    let port: Int
    let runID: String
    let allowVLM: Bool
    let allowRemoteVLM: Bool
    let vlmBaseURL: String?
    let vlmModel: String?
    let vlmModelPath: String?
    let vlmAPIKeyEnv: String?
    let vlmAllowModelDownload: Bool

    init(
        evidenceDirectory: URL,
        target: String,
        host: String,
        port: Int,
        runID: String,
        allowVLM: Bool = false,
        allowRemoteVLM: Bool = false,
        vlmBaseURL: String? = nil,
        vlmModel: String? = nil,
        vlmModelPath: String? = nil,
        vlmAPIKeyEnv: String? = nil,
        vlmAllowModelDownload: Bool = false
    ) {
        self.evidenceDirectory = evidenceDirectory
        self.target = target
        self.host = host
        self.port = port
        self.runID = runID
        self.allowVLM = allowVLM
        self.allowRemoteVLM = allowRemoteVLM
        self.vlmBaseURL = vlmBaseURL
        self.vlmModel = vlmModel
        self.vlmModelPath = vlmModelPath
        self.vlmAPIKeyEnv = vlmAPIKeyEnv
        self.vlmAllowModelDownload = vlmAllowModelDownload
    }
}

struct TKTestRunPublishedScreenshotMetadata: Codable, Equatable {
    let format: String
    let width: Double
    let height: Double
    let scale: Double
    let dataRef: String?
    let imagePath: String
    let bytes: Int
    let sourceFormat: String
}

func testRunPublishedScreenshotMetadata(
    runtimeScreenshot: TKScreenshotResponse,
    artifactData: Data,
    imagePath: String
) -> TKTestRunPublishedScreenshotMetadata {
    TKTestRunPublishedScreenshotMetadata(
        format: "png",
        width: runtimeScreenshot.width,
        height: runtimeScreenshot.height,
        scale: runtimeScreenshot.scale,
        dataRef: nil,
        imagePath: imagePath,
        bytes: artifactData.count,
        sourceFormat: runtimeScreenshot.format.lowercased()
    )
}

struct TKTestRunVLMGroundingOutcome: Equatable {
    let response: TKVLMGroundResponse
}

struct TKTestRunAssertionOutcome: Equatable {
    let status: TKTestRunStatus
    let selector: TKTestRunSelector
}

struct TKTestRunObservationOutcome: Equatable {
    let phase: String
    let artifacts: TKTestRunObservationArtifacts
    let screenCandidate: TKTestRunScreenCandidate
    let changed: Bool?
    let evidenceArtifacts: [TKEvidenceArtifact]

    init(
        phase: String,
        artifacts: TKTestRunObservationArtifacts,
        screenCandidate: TKTestRunScreenCandidate,
        changed: Bool? = nil,
        evidenceArtifacts: [TKEvidenceArtifact] = []
    ) {
        self.phase = phase
        self.artifacts = artifacts
        self.screenCandidate = screenCandidate
        self.changed = changed
        self.evidenceArtifacts = evidenceArtifacts
    }
}

struct TKTestRunPrimitiveOutcome: Equatable {
    let command: [String]
    let status: TKTestRunStatus
    let exitCode: Int
    let durationMs: Int
    let artifacts: [TKEvidenceArtifact]
    let observations: [TKTestRunObservationOutcome]
    let vlmGroundings: [TKTestRunVLMGroundingOutcome]
    let assertion: TKTestRunAssertionOutcome?
    let failure: TKTestRunFailure?

    static func passed(
        command: [String],
        durationMs: Int = 0,
        artifacts: [TKEvidenceArtifact] = [],
        observations: [TKTestRunObservationOutcome] = [],
        vlmGroundings: [TKTestRunVLMGroundingOutcome] = [],
        assertion: TKTestRunAssertionOutcome? = nil
    ) -> TKTestRunPrimitiveOutcome {
        TKTestRunPrimitiveOutcome(
            command: command,
            status: .passed,
            exitCode: 0,
            durationMs: durationMs,
            artifacts: artifacts,
            observations: observations,
            vlmGroundings: vlmGroundings,
            assertion: assertion,
            failure: nil
        )
    }

    static func failed(
        command: [String],
        durationMs: Int = 0,
        exitCode: Int = 1,
        failure: TKTestRunFailure,
        assertion: TKTestRunAssertionOutcome? = nil,
        artifacts: [TKEvidenceArtifact] = [],
        observations: [TKTestRunObservationOutcome] = [],
        vlmGroundings: [TKTestRunVLMGroundingOutcome] = []
    ) -> TKTestRunPrimitiveOutcome {
        TKTestRunPrimitiveOutcome(
            command: command,
            status: .failed,
            exitCode: exitCode,
            durationMs: durationMs,
            artifacts: artifacts,
            observations: observations,
            vlmGroundings: vlmGroundings,
            assertion: assertion,
            failure: failure
        )
    }
}

protocol TKTestRunPrimitiveExecutor {
    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome
}

struct TKTestRunPrimitiveError: Error, Equatable {
    let type: String
    let message: String
}
