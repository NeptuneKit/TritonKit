import Foundation

public enum TKAppContainerBindingError: Error, Equatable { case malformedJSON, limitExceeded, bindingMismatch }

/// Private SDK metadata. Intentionally not Encodable: paths and bundle/group identity stay private.
public struct TKAppContainerBindingPayload {
    public let deviceArgument: String
    public let deviceIdentifier: String
    public let bindingStatus: String
    public let containerAccessible: Bool?
    public let containerPath: String?
}

public enum TKAppContainerBindingParser {
    public static func parse(_ data: Data, bundleIdentifier: String, groupIdentifier: String? = nil, maximumJSONBytes: Int = 1_048_576) throws -> TKAppContainerBindingPayload {
        guard (1...16_777_216).contains(maximumJSONBytes), data.count <= maximumJSONBytes else { throw TKAppContainerBindingError.limitExceeded }
        struct Info: Decodable { let arguments: [String]; let commandType: String; let outcome: String }
        struct App: Decodable {
            let bundleIdentifier: String
            let containerAccessible: Bool?
            let dataContainerPath: String?
            let appGroupIdentifiers: [String]?
            let groupContainerPaths: [String: String]?
        }
        struct Result: Decodable { let deviceIdentifier: String; let apps: [App] }
        struct Envelope: Decodable { let info: Info; let result: Result }
        func validValue(_ value: String) -> Bool { !value.isEmpty && value.utf8.count <= 4096 && !value.hasPrefix("-") && value.rangeOfCharacter(from: .controlCharacters) == nil }
        func validatePath(_ path: String) throws {
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            guard path.hasPrefix("/"), path.utf8.count <= 16_384, parts.count <= 65,
                  path.rangeOfCharacter(from: .controlCharacters) == nil,
                  parts.dropFirst().allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255 }) else { throw TKAppContainerBindingError.malformedJSON }
        }
        do {
            guard validValue(bundleIdentifier), groupIdentifier.map(validValue) ?? true,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["error"] == nil || root["error"] is NSNull else { throw TKAppContainerBindingError.malformedJSON }
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.info.commandType == "devicectl.device.info.apps", envelope.info.outcome == "success", validValue(envelope.result.deviceIdentifier) else { throw TKAppContainerBindingError.malformedJSON }
            let arguments = envelope.info.arguments
            func value(_ flag: String) throws -> String {
                let indices = arguments.indices.filter { arguments[$0] == flag }
                guard indices.count == 1, let index = indices.first, index + 1 < arguments.count, validValue(arguments[index + 1]) else { throw TKAppContainerBindingError.bindingMismatch }
                return arguments[index + 1]
            }
            let device = try value("--device")
            guard Array(try value("--bundle-id").utf8) == Array(bundleIdentifier.utf8) else { throw TKAppContainerBindingError.bindingMismatch }
            for flag in ["--include-all-apps", "--include-container-paths", "--include-app-group-identifiers"] {
                guard arguments.filter({ $0 == flag }).count == 1 else { throw TKAppContainerBindingError.bindingMismatch }
            }
            guard envelope.result.apps.count == 1, let app = envelope.result.apps.first, Array(app.bundleIdentifier.utf8) == Array(bundleIdentifier.utf8) else { throw TKAppContainerBindingError.bindingMismatch }
            if let path = app.dataContainerPath { try validatePath(path) }
            if let groups = app.appGroupIdentifiers {
                guard groups.count <= 10_000, groups.allSatisfy(validValue), Set(groups.map { Data($0.utf8) }).count == groups.count else { throw TKAppContainerBindingError.malformedJSON }
            }
            if let paths = app.groupContainerPaths {
                guard paths.count <= 10_000, paths.keys.allSatisfy(validValue) else { throw TKAppContainerBindingError.malformedJSON }
                for path in paths.values { try validatePath(path) }
                if let groups = app.appGroupIdentifiers, !Set(paths.keys.map { Data($0.utf8) }).isSubset(of: Set(groups.map { Data($0.utf8) })) { throw TKAppContainerBindingError.bindingMismatch }
            }
            let path: String?
            if let groupIdentifier {
                if let groups = app.appGroupIdentifiers, let paths = app.groupContainerPaths {
                    guard groups.contains(where: { Array($0.utf8) == Array(groupIdentifier.utf8) }), let groupPath = paths.first(where: { Array($0.key.utf8) == Array(groupIdentifier.utf8) })?.value else { throw TKAppContainerBindingError.bindingMismatch }
                    path = app.containerAccessible == true ? groupPath : nil
                } else if app.appGroupIdentifiers == nil && app.groupContainerPaths == nil {
                    path = nil // Older SDK layout: never infer from app display names or directory names.
                } else { throw TKAppContainerBindingError.bindingMismatch }
            } else { path = app.containerAccessible == true ? app.dataContainerPath : nil }
            return TKAppContainerBindingPayload(deviceArgument: device, deviceIdentifier: envelope.result.deviceIdentifier, bindingStatus: path == nil ? "unavailable" : "sdk-bound", containerAccessible: app.containerAccessible, containerPath: path)
        } catch let error as TKAppContainerBindingError { throw error }
        catch { throw TKAppContainerBindingError.malformedJSON }
    }
}
