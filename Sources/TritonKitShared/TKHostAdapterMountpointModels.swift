import Foundation

public enum TKDevicectlMountpointError: Error, Equatable { case malformedJSON, limitExceeded }
/// Private backend payload; deliberately not Codable/Encodable for public output.
public struct TKDevicectlMountpointPayload {
    public let deviceArgument: String
    public let deviceIdentifier: String?
    public let dataPath: String
}
public enum TKDevicectlMountpointParser {
    public static func parse(_ data: Data, maximumJSONBytes: Int = 1_048_576) throws -> TKDevicectlMountpointPayload {
        guard (1...16_777_216).contains(maximumJSONBytes), data.count <= maximumJSONBytes else { throw TKDevicectlMountpointError.limitExceeded }
        struct Info: Decodable { let arguments: [String]; let commandType: String; let outcome: String }
        struct Result: Decodable { let dataPath: String; let deviceIdentifier: String? }
        struct Envelope: Decodable { let info: Info; let result: Result }
        do {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["error"] == nil || root["error"] is NSNull else { throw TKDevicectlMountpointError.malformedJSON }
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.info.commandType == "devicectl.device.info.mountpoint", envelope.info.outcome == "success" else { throw TKDevicectlMountpointError.malformedJSON }
            let arguments = envelope.info.arguments
            let indexes = arguments.indices.filter { arguments[$0] == "--device" }
            guard indexes.count == 1, let index = indexes.first, index + 1 < arguments.count else { throw TKDevicectlMountpointError.malformedJSON }
            let identifier = arguments[index + 1]
            guard !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !identifier.hasPrefix("-"), identifier.rangeOfCharacter(from: .controlCharacters) == nil else { throw TKDevicectlMountpointError.malformedJSON }
            let path = envelope.result.dataPath
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard path.hasPrefix("/"), path.utf8.count <= 16_384, components.count > 1,
                  path.rangeOfCharacter(from: .controlCharacters) == nil,
                  components.dropFirst().allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { throw TKDevicectlMountpointError.malformedJSON }
            if let actual = envelope.result.deviceIdentifier {
                guard !actual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, actual.rangeOfCharacter(from: .controlCharacters) == nil else { throw TKDevicectlMountpointError.malformedJSON }
            }
            return TKDevicectlMountpointPayload(deviceArgument: identifier, deviceIdentifier: envelope.result.deviceIdentifier, dataPath: path)
        } catch let error as TKDevicectlMountpointError { throw error }
        catch { throw TKDevicectlMountpointError.malformedJSON }
    }
}
