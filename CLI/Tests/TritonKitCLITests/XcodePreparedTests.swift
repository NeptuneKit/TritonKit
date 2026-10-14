import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct XcodePreparedTests {
    @Test("Apple test products internal links bind link bytes and target content")
    func internalProductLinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("prepared-internal-links-\(UUID())")
        let source = root.appendingPathComponent("Source")
        let artifact = source.appendingPathComponent(".triton/Tests.xctestproducts")
        let binaryDirectory = artifact.appendingPathComponent("Binaries/0/Debug")
        let testDirectory = artifact.appendingPathComponent("Tests/0")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let binary = binaryDirectory.appendingPathComponent("Tests")
        try Data("binary-v1".utf8).write(to: binary)
        let link = testDirectory.appendingPathComponent("Debug")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../../Binaries/0/Debug")
        try FileManager.default.createSymbolicLink(atPath: artifact.appendingPathComponent("BinaryAlias").path, withDestinationPath: "Binaries/0/Debug/Tests")
        let tool = PreparedTestsToolchain(developerDirectory: "/Xcode/Developer", version: "Xcode 27", supportsTestProducts: true)
        let invocation = try resolveXcodeInvocation(package: source.path, scheme: "App", destination: "platform=macOS")
        let manifest = try makePreparedTestsManifest(invocation: invocation, artifact: artifact.path, sourceRoot: source.path, toolchain: tool)
        try validatePreparedTestsManifest(manifest, invocation: invocation, toolchain: tool)
        let obsolete = PreparedTestsManifest(version: manifest.version, policy: "sha256-tree-v1;no-symlinks", identity: manifest.identity, sourceRoot: manifest.sourceRoot, sourceDigest: manifest.sourceDigest, artifact: manifest.artifact, artifactDigest: manifest.artifactDigest)
        do {
            try validatePreparedTestsManifest(obsolete, invocation: invocation, toolchain: tool)
            Issue.record("Obsolete fingerprint policies must require a fresh build.")
        } catch let error as PreparedTestsError {
            #expect(error.code == "prepared_tests_manifest_invalid")
        }
        try Data("binary-v2".utf8).write(to: binary)
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsManifest(manifest, invocation: invocation, toolchain: tool) }
        try Data("binary-v1".utf8).write(to: binary)
        try FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../../Binaries/0/./Debug")
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsManifest(manifest, invocation: invocation, toolchain: tool) }
        // The artifact-only policy must not extend to source trees or .xctestrun bundles.
        #expect(throws: PreparedTestsError.self) { try preparedTestsTreeDigest(artifact.path, source: true) }
        #expect(throws: PreparedTestsError.self) { try preparedTestsTreeDigest(artifact.path, source: false) }
    }

    @Test("test product links reject escape, dangling, absolute, linked parents and cycles")
    func rejectedProductLinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("prepared-rejected-links-\(UUID())")
        let artifact = root.appendingPathComponent("Tests.xctestproducts")
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let inside = artifact.appendingPathComponent("Inside")
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        try Data("binary".utf8).write(to: inside.appendingPathComponent("Tests"))
        let outside = root.appendingPathComponent("outside")
        try Data("outside".utf8).write(to: outside)
        let link = artifact.appendingPathComponent("Link")
        let tool = PreparedTestsToolchain(developerDirectory: "/Xcode/Developer", version: "Xcode 27", supportsTestProducts: true)
        for target in ["../outside", "../../outside", "missing", outside.path, inside.path, "Link", ".", "Inside/../Link"] {
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target)
            #expect(throws: PreparedTestsError.self) { try preparedTestsArtifactDigest(artifact.path, toolchain: tool) }
            try FileManager.default.removeItem(at: link)
        }
        let parent = artifact.appendingPathComponent("Parent")
        try FileManager.default.createSymbolicLink(atPath: parent.path, withDestinationPath: "Inside")
        for target in ["Parent/Tests", "Parent/../Inside/Tests"] {
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target)
            #expect(throws: PreparedTestsError.self) { try preparedTestsArtifactDigest(artifact.path, toolchain: tool) }
            try FileManager.default.removeItem(at: link)
        }
        try FileManager.default.removeItem(at: parent)
        let second = artifact.appendingPathComponent("Other")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "Other")
        try FileManager.default.createSymbolicLink(atPath: second.path, withDestinationPath: "Link")
        #expect(throws: PreparedTestsError.self) { try preparedTestsArtifactDigest(artifact.path, toolchain: tool) }
    }

    @Test("test product directory aliases cannot form traversal cycles")
    func productDirectoryCycles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("prepared-directory-cycle-\(UUID()).xctestproducts")
        let a = root.appendingPathComponent("A")
        let b = root.appendingPathComponent("B")
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(atPath: a.appendingPathComponent("toB").path, withDestinationPath: "../B")
        try FileManager.default.createSymbolicLink(atPath: b.appendingPathComponent("toA").path, withDestinationPath: "../A")
        let tool = PreparedTestsToolchain(developerDirectory: "/Xcode/Developer", version: "Xcode 27", supportsTestProducts: true)
        #expect(throws: PreparedTestsError.self) { try preparedTestsArtifactDigest(root.path, toolchain: tool) }
    }

    @Test("prepared snapshots invalidate on source, artifact, destination and Xcode changes")
    func snapshotIdentity() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("prepared-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let swift = source.appendingPathComponent("App.swift")
        try Data("let value = 1".utf8).write(to: swift)
        let bundle = root.appendingPathComponent("Tests.xctest")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let binary = bundle.appendingPathComponent("Tests")
        try Data("binary-v1".utf8).write(to: binary)
        let artifact = root.appendingPathComponent("Tests.xctestrun")
        let plist: [String: Any] = ["Tests": ["TestBundlePath": "__TESTROOT__/Tests.xctest"]]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: artifact)
        let invocation = try resolveXcodeInvocation(package: source.path, scheme: "App", configuration: "Debug", destination: "platform=macOS")
        let tool = PreparedTestsToolchain(developerDirectory: "/Xcode/Developer", version: "Xcode 27\nBuild version A", supportsTestProducts: true)
        let manifest = try makePreparedTestsManifest(invocation: invocation, artifact: artifact.path, sourceRoot: source.path, toolchain: tool)
        try validatePreparedTestsManifest(manifest, invocation: invocation, toolchain: tool)
        try Data("let value = 2".utf8).write(to: swift)
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsManifest(manifest, invocation: invocation, toolchain: tool) }
        try Data("let value = 1".utf8).write(to: swift)
        try Data("binary-v2".utf8).write(to: binary)
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsManifest(manifest, invocation: invocation, toolchain: tool) }
        try Data("binary-v1".utf8).write(to: binary)
        let changed = try resolveXcodeInvocation(package: source.path, scheme: "App", configuration: "Release", destination: "platform=macOS")
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsManifest(manifest, invocation: changed, toolchain: tool) }
        let otherDestination = try resolveXcodeInvocation(package: source.path, scheme: "App", configuration: "Debug", destination: "platform=macOS,arch=x86_64")
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsManifest(manifest, invocation: otherDestination, toolchain: tool) }
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsManifest(manifest, invocation: invocation, toolchain: .init(developerDirectory: "/Other/Developer", version: tool.version, supportsTestProducts: true)) }
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsManifest(manifest, invocation: invocation, toolchain: .init(developerDirectory: tool.developerDirectory, version: "Xcode 28", supportsTestProducts: true)) }
    }

    @Test("fresh results never consume old bundles or symbolic link parents")
    func freshResult() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("prepared-results-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try freshPreparedTestsResultPath(nil, package: root.path)
        let second = try freshPreparedTestsResultPath(nil, package: root.path)
        #expect(first != second)
        try FileManager.default.createDirectory(atPath: first, withIntermediateDirectories: true)
        #expect(throws: PreparedTestsError.self) { try freshPreparedTestsResultPath(first, package: nil) }
        try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent("link").path, withDestinationPath: root.path)
        #expect(throws: PreparedTestsError.self) { try freshPreparedTestsResultPath(root.appendingPathComponent("link/result.xcresult").path, package: nil) }
    }

    @Test("test-without-building uses artifact and never rebuilds container")
    func preparedCommand() {
        let command = TKXcodebuildCommand.testPrepared(artifactPath: "/tmp/Tests.xctestrun", destination: "platform=macOS", resultBundlePath: "/tmp/fresh.xcresult", onlyTesting: ["Tests/testA"])
        #expect(command.arguments.contains("test-without-building"))
        #expect(command.arguments.contains("-xctestrun"))
        #expect(!command.arguments.contains("-scheme"))
        #expect(command.arguments.contains("-only-testing:Tests/testA"))
        let products = TKXcodebuildCommand.testPrepared(artifactPath: "/tmp/Tests.xctestproducts", destination: "platform=iOS,id=private-target", resultBundlePath: "/tmp/fresh.xcresult", redactDestination: true)
        #expect(products.arguments.contains("-testProductsPath"))
        #expect(products.redactedArgumentIndexes == [4])
        let build = TKXcodebuildCommand.build(workspace: nil, project: "App.xcodeproj", scheme: "App", configuration: "Debug", sdk: nil, destination: "platform=macOS", derivedDataPath: nil, buildForTesting: true, testProductsPath: "/tmp/Tests.xctestproducts")
        #expect(build.arguments.contains("build-for-testing"))
        #expect(!build.arguments.contains("build"))
        #expect(build.arguments.contains("-testProductsPath"))
    }

    @Test("CLI rejects partial prepared build contracts")
    func cliOptions() throws {
        let command = try XcodeBuild.parse(["--for-testing", "--test-artifact", "tests.xctestrun", "--source-root", ".", "--prepared-tests-manifest", ".triton/tests.json"])
        #expect(command.forTesting)
        try validatePreparedTestsBuildOptions(forTesting: command.forTesting, artifact: command.testArtifact, sourceRoot: command.sourceRoot, manifest: command.preparedTestsManifest)
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsBuildOptions(forTesting: true, artifact: "tests.xctestrun", sourceRoot: nil, manifest: nil) }
        #expect(throws: PreparedTestsError.self) { try validatePreparedTestsBuildOptions(forTesting: false, artifact: nil, sourceRoot: ".", manifest: nil) }
        #expect(try XcodeTest.parse(["--prepared-tests-manifest", "prepared.json"]).preparedTestsManifest == "prepared.json")
    }

    @Test("process zero without executed result evidence cannot pass prepared tests")
    func zeroIsNotResultEvidence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("prepared-execution-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let artifact = root.appendingPathComponent("Tests.xctestproducts")
        try Data("explicit test snapshot".utf8).write(to: artifact)
        let invocation = try resolveXcodeInvocation(package: root.path, scheme: "App", destination: "platform=macOS")
        let tool = PreparedTestsToolchain(developerDirectory: "/Xcode/Developer", version: "Xcode 27", supportsTestProducts: true)
        let manifest = try makePreparedTestsManifest(invocation: invocation, artifact: artifact.path, sourceRoot: root.path, toolchain: tool)
        var seen = 0
        let summary = try runXcodeTest(invocation: invocation, resultBundlePath: nil, jsonl: false,
            preparedManifest: manifest, toolchainProvider: { tool }, hostCommandRunner: { command, _, _, _ in
                seen += 1
                #expect(command.arguments.contains("test-without-building"))
                return (HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0), 1)
            }, resultCommandRunner: { _ in throw PreparedTestsError.invalid("Fixture has no test results") })
        #expect(seen == 1)
        #expect(!summary.ok)
        #expect(summary.failureCode == "prepared_tests_result_incomplete")
        #expect(summary.resultBundlePath?.hasSuffix(".xcresult") == true)
        let manifestPath = root.appendingPathComponent(".triton/prepared.json").path
        try writePreparedTestsManifest(manifest, path: manifestPath)
        #expect(try readPreparedTestsManifest(manifestPath).version == 1)
        #expect(throws: PreparedTestsError.self) { try writePreparedTestsManifest(manifest, path: manifestPath) }
        let successful = try runXcodeTest(invocation: invocation, resultBundlePath: nil, jsonl: false,
            preparedManifest: manifest, toolchainProvider: { tool }, hostCommandRunner: { command, _, _, _ in
                let index = try #require(command.arguments.firstIndex(of: "-resultBundlePath"))
                try FileManager.default.createDirectory(atPath: command.arguments[index + 1], withIntermediateDirectories: true)
                return (HostProcessResult(stdoutData: Data("** TEST SUCCEEDED **".utf8), stderrData: Data(), exitCode: 0, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0), 1)
            }, resultCommandRunner: { command in
                let json = command.arguments.contains("summary")
                    ? "{\"title\":\"App\",\"environmentDescription\":\"Fixture\",\"topInsights\":[],\"statistics\":[],\"result\":\"Passed\",\"totalTestCount\":1,\"passedTests\":1,\"failedTests\":0,\"skippedTests\":0,\"expectedFailures\":0}"
                    : "{\"testNodes\":[],\"testPlanConfigurations\":[],\"devices\":[]}"
                return HostProcessResult(stdoutData: Data(json.utf8), stderrData: Data(), exitCode: 0, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
            })
        #expect(successful.ok)
        #expect(successful.testResultSummary?.passedTests == 1)
        #expect(successful.resultBundlePath != summary.resultBundlePath)
        let skipped = try runXcodeTest(invocation: invocation, resultBundlePath: nil, jsonl: false,
            preparedManifest: manifest, toolchainProvider: { tool }, hostCommandRunner: { command, _, _, _ in
                let index = try #require(command.arguments.firstIndex(of: "-resultBundlePath"))
                try FileManager.default.createDirectory(atPath: command.arguments[index + 1], withIntermediateDirectories: true)
                return (HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0), 1)
            }, resultCommandRunner: { command in
                let json = command.arguments.contains("summary")
                    ? "{\"title\":\"App\",\"environmentDescription\":\"Fixture\",\"topInsights\":[],\"statistics\":[],\"result\":\"Passed\",\"totalTestCount\":1,\"passedTests\":0,\"failedTests\":0,\"skippedTests\":1,\"expectedFailures\":0}"
                    : "{\"testNodes\":[],\"testPlanConfigurations\":[],\"devices\":[]}"
                return HostProcessResult(stdoutData: Data(json.utf8), stderrData: Data(), exitCode: 0, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
            })
        #expect(!skipped.ok)
        #expect(skipped.failureCode == "prepared_tests_result_incomplete")
    }

    @Test("symlink sources and unsupported test products fail closed")
    func boundedSources() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("prepared-links-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent("Source.swift").path, withDestinationPath: "/private/file")
        #expect(throws: PreparedTestsError.self) { try preparedTestsTreeDigest(root.path, source: true) }
        #expect(throws: PreparedTestsError.self) { try preparedTestsArtifactDigest(root.appendingPathComponent("Tests.xctestproducts").path, toolchain: .init(developerDirectory: "/Xcode", version: "Xcode 15", supportsTestProducts: false)) }
    }
}
