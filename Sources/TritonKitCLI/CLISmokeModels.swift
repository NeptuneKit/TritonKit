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

enum SmokeProofSource: String, Codable {
    case runtime
    case hostLayout = "host-layout"
    case hostAction = "host-action"
    case evidence
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
    let proofSource: SmokeProofSource?

    init(
        condition: String,
        query: String,
        ok: Bool,
        count: Int?,
        message: String?,
        proofSource: SmokeProofSource? = nil
    ) {
        self.condition = condition
        self.query = query
        self.ok = ok
        self.count = count
        self.message = message
        self.proofSource = proofSource
    }
}

struct SmokeStepSummary: Codable, Equatable {
    let name: String
    let status: SmokeStepStatus
    let proofSource: SmokeProofSource?
    let businessReady: Bool
    let sourceCommand: [String]
    let elapsedMs: Int
    let target: String?
    let artifacts: [SmokeArtifactSummary]
    let message: String?

    init(
        name: String,
        status: SmokeStepStatus,
        proofSource: SmokeProofSource? = nil,
        businessReady: Bool = false,
        sourceCommand: [String],
        elapsedMs: Int,
        target: String?,
        artifacts: [SmokeArtifactSummary],
        message: String?
    ) {
        self.name = name
        self.status = status
        self.proofSource = proofSource
        self.businessReady = businessReady
        self.sourceCommand = sourceCommand
        self.elapsedMs = elapsedMs
        self.target = target
        self.artifacts = artifacts
        self.message = message
    }
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
