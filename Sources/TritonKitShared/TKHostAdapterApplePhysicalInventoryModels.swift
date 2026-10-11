import Foundation

/// Independent metadata identities. Never pass this ID to the legacy iOS action dispatcher.
public struct TKApplePhysicalInventoryDevice: Encodable, Equatable {
    public let id: String
    public let observation: TKAppleHardwarePlatformObservation
    private let primaryIdentifier: String
    enum CodingKeys: String, CodingKey { case id, observation }
    init(identifier: String, observation: TKAppleHardwarePlatformObservation) {
        self.primaryIdentifier = identifier
        self.observation = observation
        // Preserve the project's opaque inventory identifier convention without exposing primary IDs.
        let legacy = TKDevicectlDeviceTarget(identifier: identifier, state: "unknown", ready: false, blockedReasons: ["readiness-unknown"])
        self.id = "apple-physical:" + String(legacy.id.dropFirst("ios-real:".count))
    }
    public func matches(selector: String) -> Bool { selector == id || selector == primaryIdentifier }
}
public enum TKApplePhysicalInventoryError: Error { case invalidJSON, limitExceeded }
public enum TKApplePhysicalInventoryParser {
    public static func parse(_ data: Data) throws -> [TKApplePhysicalInventoryDevice] {
        guard data.count <= 1_048_576 else { throw TKApplePhysicalInventoryError.limitExceeded }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], root["error"] == nil,
              let result = root["result"] as? [String: Any], let records = result["devices"] as? [[String: Any]] else { throw TKApplePhysicalInventoryError.invalidJSON }
        guard let info = root["info"] as? [String: Any], info["outcome"] as? String == "success" else { throw TKApplePhysicalInventoryError.invalidJSON }
        guard records.count <= 10_000 else { throw TKApplePhysicalInventoryError.limitExceeded }
        var seen = Set<String>()
        var ids = Set<String>()
        var devices: [TKApplePhysicalInventoryDevice] = []
        for record in records {
            guard let identifier = (record["identifier"] ?? record["deviceIdentifier"]) as? String,
                  !identifier.isEmpty, identifier.utf8.count <= 1024,
                  !identifier.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  identifier == identifier.trimmingCharacters(in: .whitespacesAndNewlines),
                  seen.insert(identifier).inserted else { throw TKApplePhysicalInventoryError.invalidJSON }
            let modern = record["properties"] != nil
            let properties = record["properties"] as? [String: Any] ?? [:]
            let hardware = (modern ? properties["hardware"] : record["hardwareProperties"]) as? [String: Any] ?? [:]
            let observation = TKDevicectlHardwareObservationParser.parse(hardware, modern: modern)
            guard observation.reality == .physical else { continue }
            let device = TKApplePhysicalInventoryDevice(identifier: identifier, observation: observation)
            guard ids.insert(device.id).inserted else { throw TKApplePhysicalInventoryError.invalidJSON }
            devices.append(device)
        }
        return devices.sorted { $0.id < $1.id }
    }
}
