import ArgumentParser
import Foundation
import TritonKitShared

enum HostPreferenceSetType: String, ExpressibleByArgument {
    case json
    case data
}

enum HostPreferencesImportFormat: String, ExpressibleByArgument { case json, plist }

struct HostPreferencesPresenceOutput: Encodable {
    let output: HostPreferencesOutput
    let present: Bool
    enum CodingKeys: String, CodingKey { case present }
    func encode(to encoder: Encoder) throws {
        try output.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(present, forKey: .present)
    }
}

struct HostPreferencesRelaunchReceipt: Encodable {
    let requested: Bool
    let status: String
    let runtimeConsumptionVerified = false
    var ok: Bool { status == "not-requested" || status == "launched" }
}

struct HostPreferencesWriteOutput: Encodable {
    let output: HostPreferencesSetOutput
    let relaunch: HostPreferencesRelaunchReceipt
    enum CodingKeys: String, CodingKey { case ok, diskWriteVerified, runtimeConsumptionVerified, relaunch, error }
    func encode(to encoder: Encoder) throws {
        try output.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(relaunch.ok, forKey: .ok)
        try container.encode(true, forKey: .diskWriteVerified)
        try container.encode(false, forKey: .runtimeConsumptionVerified)
        try container.encode(relaunch, forKey: .relaunch)
        if !relaunch.ok { try container.encode(HostPreferencesDeliveryError(), forKey: .error) }
    }
}

struct HostPreferencesImportOutput: Encodable {
    let ok: Bool
    let action = "app.prefs.import"
    let simulatorUDID: String
    let bundleID: String
    let importedKeys: [String]
    let importedPlistTypes: [String: String]
    let diskWriteVerified: Bool
    let runtimeConsumptionVerified = false
    let relaunch: HostPreferencesRelaunchReceipt
    var error: HostPreferencesDeliveryError? { ok ? nil : .init() }
    enum CodingKeys: String, CodingKey { case ok, action, simulatorUDID, bundleID, importedKeys, importedPlistTypes, diskWriteVerified, runtimeConsumptionVerified, relaunch, error }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ok, forKey: .ok); try c.encode(action, forKey: .action)
        try c.encode(simulatorUDID, forKey: .simulatorUDID); try c.encode(bundleID, forKey: .bundleID)
        try c.encode(importedKeys, forKey: .importedKeys); try c.encode(importedPlistTypes, forKey: .importedPlistTypes)
        try c.encode(diskWriteVerified, forKey: .diskWriteVerified); try c.encode(runtimeConsumptionVerified, forKey: .runtimeConsumptionVerified)
        try c.encode(relaunch, forKey: .relaunch); try c.encodeIfPresent(error, forKey: .error)
    }
}

struct HostPreferencesDeliveryError: Encodable {
    let code = "preferences_relaunch_failed"
    let message = "Preferences were written to disk, but the requested relaunch did not complete."
}
