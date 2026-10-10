import Foundation

public enum TKDevicectlFilesError: Error, Equatable {
    case invalidRequest
    case temporaryRequiresPolicy
    case malformedJSON
    case limitExceeded
}

public struct TKDevicectlFilesRequest: Equatable {
    public let domain: String
    public let domainIdentifier: String?
    public let subdirectory: String?
    public let username: String?
    public init(domain: String, domainIdentifier: String? = nil, subdirectory: String? = nil, username: String? = nil) throws {
        if domain == "temporary" { throw TKDevicectlFilesError.temporaryRequiresPolicy }
        guard ["appDataContainer", "appGroupDataContainer", "systemCrashLogs"].contains(domain) else { throw TKDevicectlFilesError.invalidRequest }
        func valid(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.rangeOfCharacter(from: .controlCharacters) == nil }
        if domain == "systemCrashLogs" {
            guard domainIdentifier == nil else { throw TKDevicectlFilesError.invalidRequest }
        } else {
            guard let domainIdentifier, valid(domainIdentifier) else { throw TKDevicectlFilesError.invalidRequest }
        }
        if let username, !valid(username) { throw TKDevicectlFilesError.invalidRequest }
        if let subdirectory, subdirectory != ".", !Self.validRelativePath(subdirectory) { throw TKDevicectlFilesError.invalidRequest }
        self.domain = domain; self.domainIdentifier = domainIdentifier
        self.subdirectory = subdirectory == "." ? nil : subdirectory; self.username = username
    }
    public static func validRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), path.rangeOfCharacter(from: .controlCharacters) == nil else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}

// Raw names and identities are for validation/private artifacts, not implicitly public Codable.
public struct TKDevicectlFileEntry: Equatable {
    public let name: String
    public let relativePath: String
    public let kind: String
    public let sizeBytes: UInt64?
    public let modifiedAt: String?
    public let isHidden: Bool?
    public let isReadable: Bool?
}
public struct TKDevicectlFilesPayload: Equatable {
    public let deviceIdentifier: String
    public let domain: String
    public let domainIdentifier: String?
    public let arguments: [String]?
    public let files: [TKDevicectlFileEntry]
}

public enum TKDevicectlFilesParser {
    public static func parse(_ data: Data, maximumJSONBytes: Int = 1_048_576, maximumEntries: Int = 1000) throws -> TKDevicectlFilesPayload {
        guard data.count <= maximumJSONBytes else { throw TKDevicectlFilesError.limitExceeded }
        struct Metadata: Decodable { let size: UInt64?; let lastModDate: String? }
        struct Resources: Decodable { let isDirectory: Bool; let isSymbolicLink: Bool; let isHidden: Bool?; let isReadable: Bool? }
        struct Entry: Decodable { let name: String; let relativePath: String; let metadata: Metadata?; let resources: Resources }
        struct Result: Decodable { let deviceIdentifier: String; let domain: String; let domainIdentifier: String?; let files: [Entry] }
        do {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = root["result"] as? [String: Any] else { throw TKDevicectlFilesError.malformedJSON }
            if let error = root["error"], !(error is NSNull) { throw TKDevicectlFilesError.malformedJSON }
            let info: [String: Any]
            if let value = root["info"] {
                guard let dictionary = value as? [String: Any] else { throw TKDevicectlFilesError.malformedJSON }
                info = dictionary
            } else { info = [:] }
            if let outcome = info["outcome"], outcome as? String != "success" { throw TKDevicectlFilesError.malformedJSON }
            if let commandType = info["commandType"], commandType as? String != "devicectl.device.info.files" { throw TKDevicectlFilesError.malformedJSON }
            let arguments: [String]?
            if let value = info["arguments"] {
                guard let array = value as? [String] else { throw TKDevicectlFilesError.malformedJSON }
                arguments = array
            } else { arguments = nil }
            let payload = try JSONDecoder().decode(Result.self, from: JSONSerialization.data(withJSONObject: result))
            guard payload.files.count <= maximumEntries else { throw TKDevicectlFilesError.limitExceeded }
            guard !payload.deviceIdentifier.isEmpty, ["appDataContainer", "appGroupDataContainer", "systemCrashLogs"].contains(payload.domain) else { throw TKDevicectlFilesError.malformedJSON }
            var paths: Set<String> = []
            let files = try payload.files.map { entry in
                guard TKDevicectlFilesRequest.validRelativePath(entry.relativePath),
                      entry.name == entry.relativePath.split(separator: "/").last.map(String.init),
                      paths.insert(entry.relativePath).inserted else { throw TKDevicectlFilesError.malformedJSON }
                if let date = entry.metadata?.lastModDate {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let fractional = formatter.date(from: date)
                    formatter.formatOptions = [.withInternetDateTime]
                    let format = #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?(Z|[+-][0-9]{2}:[0-9]{2})$"#
                    guard date.rangeOfCharacter(from: .controlCharacters) == nil, date.range(of: format, options: .regularExpression) != nil,
                          fractional != nil || formatter.date(from: date) != nil else { throw TKDevicectlFilesError.malformedJSON }
                }
                return TKDevicectlFileEntry(name: entry.name, relativePath: entry.relativePath,
                    kind: entry.resources.isSymbolicLink ? "symbolic-link" : (entry.resources.isDirectory ? "directory" : "non-directory"),
                    sizeBytes: entry.metadata?.size, modifiedAt: entry.metadata?.lastModDate,
                    isHidden: entry.resources.isHidden, isReadable: entry.resources.isReadable)
            }
            return TKDevicectlFilesPayload(deviceIdentifier: payload.deviceIdentifier, domain: payload.domain, domainIdentifier: payload.domainIdentifier, arguments: arguments, files: files)
        } catch let error as TKDevicectlFilesError { throw error }
        catch { throw TKDevicectlFilesError.malformedJSON }
    }

    public static func isUnsupported(_ data: Data) -> Bool {
        struct Feature: Decodable { let string: String }
        struct UserInfo: Decodable { let CapabilityFeatureIdentifier: Feature }
        struct BackendError: Decodable { let code: Int; let domain: String; let userInfo: UserInfo }
        struct Info: Decodable { let outcome: String }
        struct Root: Decodable { let info: Info; let error: BackendError }
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else { return false }
        return root.info.outcome == "failed" && root.error.domain == "com.apple.dt.CoreDeviceError" && root.error.code == 1001
            && root.error.userInfo.CapabilityFeatureIdentifier.string == "com.apple.coredevice.feature.listFiles"
    }
}
