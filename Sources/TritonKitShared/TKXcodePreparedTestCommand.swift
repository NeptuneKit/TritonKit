import Foundation

extension TKXcodebuildCommand {
    /// Reuse an explicit immutable test artifact, without rebuilding its source container.
    public static func testPrepared(
        artifactPath: String,
        destination: String,
        resultBundlePath: String,
        onlyTesting: [String] = [],
        redactDestination: Bool = false
    ) -> TKHostCommand {
        let artifactFlag = artifactPath.hasSuffix(".xctestproducts") ? "-testProductsPath" : "-xctestrun"
        let arguments = ["test-without-building", artifactFlag, artifactPath, "-destination", destination,
                         "-resultBundlePath", resultBundlePath] + onlyTesting.map { "-only-testing:\($0)" }
        return TKHostCommand(executable: "xcodebuild", arguments: arguments,
            redactedArgumentIndexes: redactDestination ? [4] : [], riskLevel: .automation,
            requiredConfig: [.timeout, .auditRecord], defaultTimeoutSeconds: 1_200, capturesArtifacts: true)
    }
}
