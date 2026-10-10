import Foundation
import TritonKitShared

enum DeviceAdministrationOperation: String, CaseIterable { case pair, unpair, diagnose }
struct HostDeviceAdministrationPlanOutput: Encodable {
    let ok = true
    let action: String
    let runtimeScope = "host-device"
    let riskLevel = "readonly"
    let planOnly = true
    let executable = false
    let executed = false
    let verification = "planned-not-executed"
    let target: String
    let plannedRiskLevel: String
    let plannedSourceCommand: String?
    let commandSupport: HostAppleCommandSupport
    let blockedRequirements: [String]
    let diagnosticScopeHint: String?
    let archiveDestinationSupplied: Bool
    let operationArtifactsCreated = false
    let pairingStateVerified = false
    let diagnosticArchiveVerified = false
    let sideEffects = "Readonly discovery/help may communicate with CoreDevice and write private cache artifacts. No planned administration action, archive, Finder, DDI mount, profile install or credentials storage."
}
