import Foundation
import TritonKitShared

struct TKTestValidationResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let input: String
    let normalizedPlan: TKTestNormalizedPlan

    init(input: String, normalizedPlan: TKTestNormalizedPlan) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.test.validation-result"
        self.input = input
        self.normalizedPlan = normalizedPlan
    }
}

struct TKTestValidationFailureResponse: Codable, Equatable {
    let ok: Bool
    let error: TKTestValidationErrorDetail

    init(error: TKTestValidationErrorDetail) {
        self.ok = false
        self.error = error
    }
}

struct TKTestValidationErrorDetail: Codable, Equatable {
    let type: String
    let message: String
    let path: String
    let code: String
    let allowed: [String]?
}

struct TKTestValidationFailure: Error, Equatable {
    let detail: TKTestValidationErrorDetail
}

struct TKTestCreateResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let input: String
    let output: String
    let source: String
    let name: String
    let stepCount: Int
    let validation: TKTestValidationResponse
    let suggestedCommands: [String]

    init(
        input: String,
        output: String,
        source: String,
        name: String,
        stepCount: Int,
        validation: TKTestValidationResponse,
        suggestedCommands: [String]
    ) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.test.create-result"
        self.input = input
        self.output = output
        self.source = source
        self.name = name
        self.stepCount = stepCount
        self.validation = validation
        self.suggestedCommands = suggestedCommands
    }
}

struct TKTestNormalizedPlan: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let name: String
    let app: TKTestPlanApp
    let device: TKTestPlanDevice
    let settings: TKTestPlanSettings
    let steps: [TKTestPlanStep]

    init(
        name: String,
        app: TKTestPlanApp,
        device: TKTestPlanDevice,
        settings: TKTestPlanSettings,
        steps: [TKTestPlanStep]
    ) {
        self.schemaVersion = 1
        self.kind = "triton.test.normalized-plan"
        self.name = name
        self.app = app
        self.device = device
        self.settings = settings
        self.steps = steps
    }
}

struct TKTestPlanApp: Codable, Equatable {
    let bundleId: String
}

struct TKTestPlanDevice: Codable, Equatable {
    let platform: String
}

struct TKTestPlanSettings: Codable, Equatable {
    let strict: Bool
    let timeoutMs: Int
    let retry: TKTestPlanRetry
}

struct TKTestPlanRetry: Codable, Equatable {
    let count: Int
    let intervalMs: Int
}

struct TKTestPlanStep: Codable, Equatable {
    let index: Int
    let id: String
    let kind: String
    let type: String
    let optional: Bool
    let timeoutMs: Int?
    let point: TKTestPlanPoint?
    let endPoint: TKTestPlanPoint?
    let selector: TKTestPlanSelector?
    let text: String?
    let button: String?
    let direction: String?
    let maxScrolls: Int?
    let target: String?
    let grounding: String?
    let provider: String?
    let prompt: String?
    let baseline: String?
    let threshold: Double?
    let cropOn: String?

    init(
        index: Int,
        id: String,
        kind: String,
        type: String,
        optional: Bool,
        timeoutMs: Int?,
        point: TKTestPlanPoint?,
        endPoint: TKTestPlanPoint? = nil,
        selector: TKTestPlanSelector?,
        text: String? = nil,
        button: String? = nil,
        direction: String? = nil,
        maxScrolls: Int? = nil,
        target: String? = nil,
        grounding: String? = nil,
        provider: String? = nil,
        prompt: String? = nil,
        baseline: String? = nil,
        threshold: Double? = nil,
        cropOn: String? = nil
    ) {
        self.index = index
        self.id = id
        self.kind = kind
        self.type = type
        self.optional = optional
        self.timeoutMs = timeoutMs
        self.point = point
        self.endPoint = endPoint
        self.selector = selector
        self.text = text
        self.button = button
        self.direction = direction
        self.maxScrolls = maxScrolls
        self.target = target
        self.grounding = grounding
        self.provider = provider
        self.prompt = prompt
        self.baseline = baseline
        self.threshold = threshold
        self.cropOn = cropOn
    }
}

struct TKTestPlanPoint: Codable, Equatable {
    let x: Double
    let y: Double
    let coordinateSpace: String
}

struct TKTestPlanSelector: Codable, Equatable {
    let text: String
    let match: String
    let source: String
}

struct TKTestReportResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let evidenceDir: String
    let run: TKTestReportRun?
    let summary: TKTestReportSummary
    let failure: TKTestRunFailure?
    let steps: [TKTestReportStep]
    let artifacts: [TKTestReportArtifact]
    let suggestedCommands: [String]

    init(
        evidenceDir: String,
        run: TKTestReportRun?,
        summary: TKTestReportSummary,
        failure: TKTestRunFailure?,
        steps: [TKTestReportStep],
        artifacts: [TKTestReportArtifact],
        suggestedCommands: [String]
    ) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.test.report"
        self.evidenceDir = evidenceDir
        self.run = run
        self.summary = summary
        self.failure = failure
        self.steps = steps
        self.artifacts = artifacts
        self.suggestedCommands = suggestedCommands
    }
}

struct TKTestReportRun: Codable, Equatable {
    let runId: String
    let source: String?
    let status: TKTestRunStatus?
    let startedAt: String?
    let endedAt: String?
    let durationMs: Int?
    let planRef: String?
}

struct TKTestReportSummary: Codable, Equatable {
    let status: TKTestRunStatus?
    let eventCount: Int
    let stepCount: Int
    let assertionCount: Int
    let artifactCount: Int
    let observationCount: Int
    let failureCount: Int
    let screenshotCount: Int
    let overlayCount: Int
}

struct TKTestReportStep: Codable, Equatable {
    let stepIndex: Int
    let stepId: String?
    let stepType: String?
    let status: TKTestRunStatus?
    let durationMs: Int?
    let command: [String]?
    let exitCode: Int?
    let assertion: TKTestReportAssertion?
    let failure: TKTestRunFailure?
    let observations: [TKTestReportObservation]
    let artifacts: [TKTestReportArtifact]
    let vlmGrounding: TKVLMGroundResponse?
}

struct TKTestReportAssertion: Codable, Equatable {
    let status: TKTestRunStatus
    let selector: TKTestRunSelector
}

struct TKTestReportObservation: Codable, Equatable {
    let phase: String
    let changed: Bool?
    let artifacts: TKTestRunObservationArtifacts
    let screenCandidate: TKTestRunScreenCandidate
}

struct TKTestReportArtifact: Codable, Equatable {
    let kind: String
    let ref: String
    let sha256: String?
}

struct TKTestAIResult: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let provider: String
    let stepType: String
    let status: TKTestRunStatus
    let prompt: String?
    let extractedText: String?
    let confidence: Double
    let screenshot: String?
    let note: String

    init(
        provider: String,
        stepType: String,
        status: TKTestRunStatus,
        prompt: String?,
        extractedText: String? = nil,
        confidence: Double = 1.0,
        screenshot: String?,
        note: String
    ) {
        self.schemaVersion = 1
        self.kind = "triton.test.ai-result"
        self.provider = provider
        self.stepType = stepType
        self.status = status
        self.prompt = prompt
        self.extractedText = extractedText
        self.confidence = confidence
        self.screenshot = screenshot
        self.note = note
    }
}
