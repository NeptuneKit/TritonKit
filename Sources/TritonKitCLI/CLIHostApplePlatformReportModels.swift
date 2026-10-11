import ArgumentParser
import TritonKitShared

enum HostApplePlatformFamily: String, CaseIterable, Codable, ExpressibleByArgument { case ios, ipados, watchos, tvos, visionos, macos, unknown }
struct HostApplePlatformProfile: Encodable {
    let family: HostApplePlatformFamily
    let integrationState: String
    let legacyDeviceNamespace: String?
    let existingEntryPoints: [String]
    let missingCapabilities: [String]
    let verification = "catalog-only-not-host-sdk-or-action-acceptance"
    let platformSpecificControlAccepted = false
    let actionsAuthorized = false
}
struct HostAppleSimulatorPlatformCount: Encodable {
    let family: HostApplePlatformFamily
    let count: Int
}
struct HostApplePlatformReport: Encodable {
    let ok = true
    let action = "device.platforms"
    let runtimeScope = "host-device"
    let riskLevel = "readonly"
    let profiles: [HostApplePlatformProfile]
    let inventoryObserved: Bool
    let simulatorCounts: [HostAppleSimulatorPlatformCount]
    let sourceCommands: [String]
    let physicalInventoryObserved: Bool
    let physicalDevices: [TKApplePhysicalInventoryDevice]
    let actionsExecuted = false
    let inventoryScope = "Opt-in available Simulator counts and independent explicit physical hardware inventory; no names/raw identities/runtime echo"
    let classification = "Simulator family from native runtime shape; physical family/device/reality from exact SDK hardware fields with modern/legacy provenance. No name/product/capability inference; no action authorization"
    let limitations = ["Catalog is compiled integration metadata, not current SDK availability/business readiness", "Profile filter affects catalog only; --device selects one exact physical inventory record, never changes control routing", "Zero count is not platform unavailability proof; unknown stays unknown", "Old ios namespace/IDs/argv retained; apple-physical IDs are metadata selectors only, not legacy action targets; no automatic capability-based controls", "Metadata service/cache side effects possible; no boot/pair/input/Finder/profile/DDI or server/Run required"]
}
struct HostApplePlatformInventoryFailure: Error, CustomStringConvertible {
    let detail: TKCLIErrorDetail
    init(_ error: Error) { detail = TKCLIErrorDetail(code: HostDeviceAdministrationDiscoveryFailure(error).detail.code, message: "Apple platform metadata discovery failed. No platform action executed.", hint: "Inspect private discovery evidence locally; use readonly device doctor/list. Do not publish raw logs, identifiers, candidates or paths.") }
    var description: String { detail.message }
}
