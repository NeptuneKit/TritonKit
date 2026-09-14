import Foundation

/// Declarative resource preparation step for replay/CI planners.
public struct TKSimulatorResourcePlanStep: Codable, Equatable, Sendable {
    public let action: String
    public let profile: String?
    public let requires: [TKSimulatorResourceFeature]
    public let expectedArtifacts: [String]
    public let cleanup: String?

    public init(action: String = "plan", profile: String? = nil,
                requires: [TKSimulatorResourceFeature] = [],
                expectedArtifacts: [String] = ["simulator-resource-plan.json", "simulator-resource-status.json"],
                cleanup: String? = nil) {
        self.action = action; self.profile = profile; self.requires = requires
        self.expectedArtifacts = expectedArtifacts; self.cleanup = cleanup
    }

    /// Canonical artifact names for a resource operation, suitable for evidence manifests.
    public static func canonicalArtifacts(action: String) -> [String] {
        switch action.lowercased() {
        case "apply": return ["simulator-resource.plan.json", "simulator-resource.status.json", "simulator-resource.receipt.json"]
        case "restore": return ["simulator-resource.receipt.json", "simulator-resource.status.json"]
        case "verify": return ["simulator-resource.status.json"]
        case "measure": return ["simulator-resource.measurement.json"]
        case "doctor": return ["simulator-resource.doctor.json"]
        default: return ["simulator-resource.plan.json", "simulator-resource.status.json"]
        }
    }
}

public struct TKSimulatorResourcePlanResult: Codable, Equatable, Sendable {
    public let ok: Bool
    public let target: String
    public let step: TKSimulatorResourcePlanStep
    public let expectedArtifacts: [String]

    public init(ok: Bool = true, target: String, step: TKSimulatorResourcePlanStep) {
        self.ok = ok; self.target = target; self.step = step
        self.expectedArtifacts = step.expectedArtifacts
    }
}
