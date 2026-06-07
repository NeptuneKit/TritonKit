import Foundation
import TritonKitShared

enum SmokePlatform: String, Codable {
    case ios
    case android
    case harmony
}

enum SmokeStatus: String, Codable {
    case pass
    case fail
    case blocked
}

enum SmokeStepStatus: String, Codable {
    case pass
    case fail
    case skipped
}

struct SmokeArtifactSummary: Codable, Equatable {
    let kind: String
    let path: String
}

struct SmokeAssertionSummary: Codable, Equatable {
    let condition: String
    let query: String
    let ok: Bool
    let count: Int?
    let message: String?
}

struct SmokeStepSummary: Codable, Equatable {
    let name: String
    let status: SmokeStepStatus
    let sourceCommand: [String]
    let elapsedMs: Int
    let target: String?
    let artifacts: [SmokeArtifactSummary]
    let message: String?
}

struct SmokeFailureSummary: Codable, Equatable {
    let step: String
    let code: String
    let message: String
    let hint: String?
}

struct SmokeTargetSummary: Codable, Equatable {
    let simulator: String?
    let runtimeTarget: String?
    let bundleID: String?
    let bundleName: String?
    let abilityName: String?
}

struct SmokeRunSummary: Codable, Equatable {
    let ok: Bool
    let action: String
    let platform: SmokePlatform
    let status: SmokeStatus
    let target: SmokeTargetSummary
    let steps: [SmokeStepSummary]
    let assertions: [SmokeAssertionSummary]
    let artifacts: [SmokeArtifactSummary]
    let evidence: TKEvidenceManifest?
    let failure: SmokeFailureSummary?
    let startedAt: String
    let endedAt: String
    let elapsedMs: Int
}
