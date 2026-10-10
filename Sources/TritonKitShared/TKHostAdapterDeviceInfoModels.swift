import Foundation

/// Whitelisted device properties. Identifiers, network addresses and capability claims stay private.
public struct TKDevicectlHardwareInfo: Codable, Equatable {
    public let deviceType: String?
    public let productType: String?
    public let marketingName: String?
    public let cpuType: String?
    public let platformObservation: TKAppleHardwarePlatformObservation?
}

// Intentionally not Encodable: raw identities are needed for validation, not public output.
public struct TKDevicectlDeviceDetails: Equatable {
    public let device: TKDevicectlDeviceTarget
    public let hardware: TKDevicectlHardwareInfo
}

public struct TKDevicectlLockState: Equatable {
    public let deviceIdentifier: String
    public let passcodeRequired: Bool?
    public let unlockedSinceBoot: Bool?
}

public enum TKDevicectlDeviceInfoParserError: Error, Equatable {
    case malformedJSON
    case missingResult
    case unsuccessfulOutcome
    case invalidLockState
}

public enum TKDevicectlDeviceInfoParser {
    /// Recognize only the observed structured error, never localized terminal text.
    public static func isLockStateUnsupported(_ data: Data) -> Bool {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              (root["info"] as? [String: Any])?["outcome"] as? String == "failed",
              let error = root["error"] as? [String: Any],
              error["domain"] as? String == "com.apple.dt.CoreDeviceError",
              error["code"] as? Int == 1001,
              let info = error["userInfo"] as? [String: Any],
              (info["CapabilityFeatureIdentifier"] as? [String: Any])?["string"] as? String == "com.apple.coredevice.feature.getlockstate" else { return false }
        return true
    }

    public static func parseDetails(_ data: Data) throws -> TKDevicectlDeviceDetails {
        let root = try envelope(data)
        let result = root["result"] as! [String: Any]
        // Reuse exactly the discovery identity/classification rules for single-record details.
        let inventory = try JSONSerialization.data(withJSONObject: ["info": root["info"] ?? [:], "result": ["devices": [result]]])
        let device = try TKDevicectlDeviceListParser.parse(inventory)[0]
        let hardware: [String: Any]
        if result["properties"] != nil {
            hardware = ((result["properties"] as? [String: Any])?["hardware"] as? [String: Any]) ?? [:]
        } else {
            hardware = result["hardwareProperties"] as? [String: Any] ?? [:]
        }
        func string(_ key: String) -> String? {
            guard let value = hardware[key] as? String, !value.isEmpty else { return nil }
            return value
        }
        return TKDevicectlDeviceDetails(device: device, hardware: TKDevicectlHardwareInfo(
            deviceType: string("deviceType"), productType: string("productType"), marketingName: string("marketingName"),
            cpuType: (hardware["cpuType"] as? [String: Any])?["name"] as? String,
            platformObservation: TKDevicectlHardwareObservationParser.parse(hardware, modern: result["properties"] != nil)
        ))
    }

    public static func parseLockState(_ data: Data) throws -> TKDevicectlLockState {
        struct Payload: Decodable {
            let deviceIdentifier: String
            let passcodeRequired: Bool?
            let unlockedSinceBoot: Bool?
        }
        let result = try envelope(data)["result"] as! [String: Any]
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: JSONSerialization.data(withJSONObject: result))
            guard !payload.deviceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TKDevicectlDeviceInfoParserError.invalidLockState
            }
            return TKDevicectlLockState(deviceIdentifier: payload.deviceIdentifier, passcodeRequired: payload.passcodeRequired, unlockedSinceBoot: payload.unlockedSinceBoot)
        } catch {
            throw TKDevicectlDeviceInfoParserError.invalidLockState
        }
    }

    private static func envelope(_ data: Data) throws -> [String: Any] {
        let value: Any
        do { value = try JSONSerialization.jsonObject(with: data) }
        catch { throw TKDevicectlDeviceInfoParserError.malformedJSON }
        guard let root = value as? [String: Any], root["result"] is [String: Any] else {
            throw TKDevicectlDeviceInfoParserError.missingResult
        }
        if let error = root["error"], !(error is NSNull) {
            throw TKDevicectlDeviceInfoParserError.unsuccessfulOutcome
        }
        if let outcome = (root["info"] as? [String: Any])?["outcome"], outcome as? String != "success" {
            throw TKDevicectlDeviceInfoParserError.unsuccessfulOutcome
        }
        return root
    }
}
