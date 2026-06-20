import Foundation

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
    let selector: TKTestPlanSelector?
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
