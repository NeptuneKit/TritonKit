import Foundation

public struct TKSimulatorPair: Codable, Equatable {
    public let id: String
    public let watchID: String
    public let phoneID: String
    public let state: String
}

public enum TKSimulatorPairsError: Error { case invalidJSON, limitExceeded }

/// The native pair record is relationship metadata, not proof of either endpoint's readiness.
public enum TKSimulatorPairsParser {
    public static func command() -> TKHostCommand {
        TKHostCommand(executable: "/usr/bin/xcrun", arguments: ["simctl", "list", "pairs", "--json"], sensitiveOutput: true)
    }
    public static func parse(_ data: Data) throws -> [TKSimulatorPair] {
        guard data.count <= 1_048_576 else { throw TKSimulatorPairsError.limitExceeded }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root["error"] == nil, let records = root["pairs"] as? [String: Any] else { throw TKSimulatorPairsError.invalidJSON }
        guard records.count <= 10_000 else { throw TKSimulatorPairsError.limitExceeded }
        var seen = Set<String>()
        return try records.map { key, value in
            guard let pairID = UUID(uuidString: key), let record = value as? [String: Any],
                  let watch = record["watch"] as? [String: Any], let phone = record["phone"] as? [String: Any],
                  let watchRaw = watch["udid"] as? String, let watchID = UUID(uuidString: watchRaw),
                  let phoneRaw = phone["udid"] as? String, let phoneID = UUID(uuidString: phoneRaw),
                  watchID != phoneID, seen.insert(pairID.uuidString).inserted else { throw TKSimulatorPairsError.invalidJSON }
            let states = ["(active, connected)": "active-connected", "(active, disconnected)": "active-disconnected", "(inactive, disconnected)": "inactive-disconnected", "(inactive, connected)": "inactive-connected"]
            return TKSimulatorPair(id: "sim-pair:" + pairID.uuidString, watchID: "sim:" + watchID.uuidString, phoneID: "sim:" + phoneID.uuidString, state: (record["state"] as? String).flatMap { states[$0] } ?? "unknown")
        }.sorted { $0.id < $1.id }
    }
}
