import Foundation
import CryptoKit

struct IOSRunnerFailure: Error {
    let code: String
    let message: String
    init(_ code: String, _ message: String) { self.code = code; self.message = message }
}
struct IOSRunnerTarget: Codable, Equatable {
    let device: String
    let scope: String
    let address: String
}
struct IOSRunnerPrepared: Codable {
    let version: Int
    let resourceDigest: String
    let target: IOSRunnerTarget
    let xctestrun: String
    let preparedAt: Date
}
struct IOSRunnerSession: Codable {
    let target: IOSRunnerTarget
    let sessionID: String
    let token: String
    let port: UInt16
    let createdAt: Date
    let expiresAt: Date
    let xctestrun: String
    let directory: String
    let allowedBundles: [String]
    var pid: Int32?
    var state: String
}
struct IOSRunnerCommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
}
struct IOSRunnerDependencies: @unchecked Sendable {
    var registryRoot: URL
    var resolve: (String) throws -> IOSRunnerTarget
    var command: ([String], TimeInterval) throws -> IOSRunnerCommandResult
    var launch: ([String], URL) throws -> Int32
    var processExists: (Int32) -> Bool?
    var ownsProcess: (Int32, String) -> Bool
    var terminate: (Int32, String) -> Bool
    var exchange: (IOSRunnerSession, String, Data?, String, TimeInterval) -> IOSRunnerWireResponse
    var project: () throws -> URL
    var now: () -> Date
    var sleep: (TimeInterval) -> Void
    var writeArtifact: (Data, URL) throws -> Void = IOSRunnerSessionStore.writeArtifactExclusive
    var writeReceipt: (Data, URL) throws -> Void = IOSRunnerSessionStore.writeExclusive
}
func iosRunnerKey(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}
func iosRunnerJSON(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
}
func iosRunnerSanitize(_ value: Any) -> Any {
    if let dict = value as? [String: Any] {
        return dict.reduce(into: [String: Any]()) { output, item in
            if ["pngBase64", "token", "authorization", "rawTarget", "rawTargetAliases", "team", "sourceCommand", "text"].contains(item.key) { return }
            output[item.key] = iosRunnerSanitize(item.value)
        }
    }
    if let array = value as? [Any] { return array.map(iosRunnerSanitize) }
    return value
}

func iosRunnerConnection(_ session: IOSRunnerSession) -> IOSRunnerConnection {
    IOSRunnerConnection(scope: session.target.scope, targetAddress: session.target.scope == "simulator" ? "127.0.0.1" : session.target.address, port: session.port, token: session.token, sessionID: session.sessionID)
}
