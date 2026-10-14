import Foundation

struct PreparedTestsToolchain: Codable, Equatable {
    let developerDirectory: String
    let version: String
    let supportsTestProducts: Bool
}

struct PreparedTestsIdentity: Codable, Equatable {
    let workspace: String?
    let project: String?
    let package: String?
    let scheme: String
    let configuration: String
    let sdk: String?
    let destination: String
    let buildSettings: [String]
    let toolchain: PreparedTestsToolchain
}

struct PreparedTestsManifest: Codable {
    let version: Int
    let policy: String
    let identity: PreparedTestsIdentity
    let sourceRoot: String
    let sourceDigest: String
    let artifact: String
    let artifactDigest: String
}

struct PreparedTestsError: Error {
    let code: String
    let message: String
    static func invalid(_ message: String) -> Self { .init(code: "prepared_tests_artifact_invalid", message: message) }
    static func mismatch() -> Self { .init(code: "prepared_tests_identity_mismatch", message: "Prepared tests changed source, build settings, target, toolchain, or artifact. Build a fresh prepared snapshot.") }
}
