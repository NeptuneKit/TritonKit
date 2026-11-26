import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct XcodeCompilationCacheTests {
    private let keyA = "llvmcas://" + String(repeating: "a", count: 64)
    private let keyB = "llvmcas://" + String(repeating: "b", count: 64)
    private let target = " (in target 'PrivateName' from project 'Fixture')"

    @Test func parserAndSchemaAreBuildOnly() throws {
        let parsed = try XcodeBuild.parse([
            "--compilation-cache", "shared", "--cas-path", "/tmp/cas", "--cache-source-root", "/tmp/src",
            "--derived-data-path", "/tmp/dd",
        ])
        #expect(parsed.compilationCache == .shared)
        #expect(parsed.casPath == "/tmp/cas")
        #expect(try XcodeBuild.parse([]).compilationCache == nil)
        #expect(throws: (any Error).self) { try XcodeTest.parse(["--compilation-cache", "shared"]) }
        #expect(throws: (any Error).self) { try XcodeRun.parse(["--compilation-cache", "shared"]) }
        let schema = try #require(commandSchemas().first { $0.name == "xcode" })
        let cacheOptions: Set<String> = ["--compilation-cache", "--cas-path", "--cache-source-root"]
        for subcommand in schema.subcommands {
            let cacheFlags = cacheOptions.intersection(subcommand.optionalOptions)
            #expect(cacheFlags == (subcommand.name == "build" ? cacheOptions : []))
        }
    }

    @Test(arguments: ["Xcode 26.6\nBuild version 17G", "Xcode 27.0\nBuild version 27A", "Xcode 28.0\nBuild version 28A", "malformed"])
    func rejectsUnverifiedToolchain(text: String) {
        #expect(XcodeCompilationCacheToolchain.supportedVersion(text) == nil)
    }

    @Test func versionAndConflictValidation() throws {
        #expect(XcodeCompilationCacheToolchain.supportedVersion("Xcode 27.1\nBuild version 27A9275\n") == "27.1")
        #expect(throws: XcodeCompilationCacheError.self) {
            try validateXcodeCompilationCacheFlags(mode: nil, casPath: "/tmp/cas", root: nil, forTesting: false)
        }
        #expect(throws: XcodeCompilationCacheError.self) {
            try validateXcodeCompilationCacheFlags(mode: .shared, casPath: "/tmp/cas", root: nil, forTesting: true)
        }
    }

    @Test func pathIsolationAndExactSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = directory.appendingPathComponent("TritonKit")
        let project = source.appendingPathComponent("Demo.xcodeproj")
        let cas = directory.appendingPathComponent("CAS")
        let dd = directory.appendingPathComponent("DerivedData")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let invocation = makeInvocation(project: project.path, dd: dd.path)
        let tool = XcodeCompilationCacheToolchain(executable: "/fixture/Developer/usr/bin/xcodebuild", developerDirectory: "/fixture/Developer", version: "27.1")
        let config = try configureXcodeCompilationCache(mode: .shared, casPath: cas.path, sourceRoot: source.path, explicitDerivedData: dd.path,
            invocation: invocation, environment: [:], toolchain: { tool })
        let settings = try #require(config?.settings)
        #expect(settings.contains("COMPILATION_CACHE_ENABLE_CACHING=YES"))
        #expect(settings.contains("COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES"))
        #expect(settings.contains("SWIFT_ENABLE_PROJECT_PREFIX_MAPPING=NO"))
        #expect(settings.contains { $0.hasPrefix("CLANG_OTHER_PREFIX_MAPPINGS=") && $0.contains("=/^dd") && $0.contains("=/^wt") })
        #expect(!settings.contains { $0.contains("INDEX") || $0.contains("CODE_SIGN") })
        #expect(!FileManager.default.fileExists(atPath: cas.path))
        #expect(!FileManager.default.fileExists(atPath: dd.path))
        let applied = try #require(config).apply(to: TKHostCommand(executable: "xcodebuild", arguments: ["build"], defaultTimeoutSeconds: 42))
        #expect(applied.executable == tool.executable && applied.environment["DEVELOPER_DIR"] == tool.developerDirectory)
        #expect(applied.defaultTimeoutSeconds == 42 && applied.arguments == ["build"])
        #expect(try configureXcodeCompilationCache(mode: nil, casPath: nil, sourceRoot: nil, explicitDerivedData: nil,
            invocation: invocation, environment: [:], toolchain: { Issue.record("Default must not probe Xcode"); return tool }) == nil)
        let withConflict = makeInvocation(project: project.path, dd: dd.path, settings: ["SWIFT_ENABLE_PREFIX_MAPPING[sdk=iphonesimulator*]=NO"])
        let caseOnlyAlias = cas.deletingLastPathComponent().appendingPathComponent("cas").path
        for item in [withConflict, makeInvocation(project: project.path, dd: cas.path),
                     makeInvocation(project: project.path, dd: caseOnlyAlias), makeInvocation(project: project.path, dd: source.path)] {
            #expect(throws: XcodeCompilationCacheError.self) {
                try configureXcodeCompilationCache(mode: .shared, casPath: cas.path, sourceRoot: source.path, explicitDerivedData: item.derivedDataPath,
                    invocation: item, environment: [:], toolchain: { Issue.record("Invalid path or conflict reached toolchain probe"); return tool })
            }
        }
    }

    @Test func packageDirectoryFindsItsOwnGitRoot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = directory.appendingPathComponent("TritonKit")
        let dd = directory.appendingPathComponent("dd").path
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let git = try runHostCommand(TKHostCommand(executable: "/usr/bin/git", arguments: ["init", "-q", source.path]))
        try #require(git.exitCode == 0)
        let invocation = ResolvedXcodeInvocation(workspace: nil, project: nil, package: source.path, scheme: "Demo", configuration: "Debug",
            sdk: "iphonesimulator", destination: "generic/platform=iOS Simulator", derivedDataPath: dd, buildSettings: [],
            derivedDataCache: makeXcodeDerivedDataCacheInfo(path: dd), simulatorUDID: nil, device: nil)
        let tool = XcodeCompilationCacheToolchain(executable: "/fixture/Developer/usr/bin/xcodebuild", developerDirectory: "/fixture/Developer", version: "27.1")
        let actual = try configureXcodeCompilationCache(mode: .shared, casPath: directory.appendingPathComponent("cas").path,
            sourceRoot: nil, explicitDerivedData: dd, invocation: invocation, environment: [:], toolchain: { tool })
        let settings = try #require(actual?.settings)
        #expect(settings.contains { $0.hasPrefix("SWIFT_OTHER_PREFIX_MAPPINGS=") && $0.contains("\(source.path)=/^wt") })
    }

    @Test func uncreatedDerivedDataMapsBothMacOSTemporaryPathSpellings() throws {
        let directory = URL(fileURLWithPath: "/private/tmp/").appendingPathComponent(UUID().uuidString)
        let source = directory.appendingPathComponent("TritonKit")
        let project = source.appendingPathComponent("Demo.xcodeproj")
        let dd = directory.appendingPathComponent("fresh/DerivedData")
        let cas = directory.appendingPathComponent("cas")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let tool = XcodeCompilationCacheToolchain(executable: "/fixture/Developer/usr/bin/xcodebuild", developerDirectory: "/fixture/Developer", version: "27.1")
        let configuration = try configureXcodeCompilationCache(mode: .shared, casPath: cas.path, sourceRoot: source.path,
            explicitDerivedData: dd.path, invocation: makeInvocation(project: project.path, dd: dd.path), environment: [:], toolchain: { tool })
        let input = try #require(configuration)
        let settings = try #require(input.settings.first(where: { $0.hasPrefix("SWIFT_OTHER_PREFIX_MAPPINGS=") }))
        #expect(settings.contains("\(dd.path)=/^dd"))
        #expect(settings.contains("\(dd.path.replacingOccurrences(of: "/private/tmp/", with: "/tmp/"))=/^dd"))
        #expect(!FileManager.default.fileExists(atPath: dd.path))
    }

    @Test func realRemarkFormatCountsBatchesWithoutLeakingSource() throws {
        let text = """
        SwiftCompile normal arm64 Compiling fixture\(target)
        note: Local cache found for key: \(keyA)\(target)
        note: Using CAS output object: \(keyB)\(target)
        note: Local cache found for key: \(keyB)\(target)
        note: Replay cache hit\(target)
        Cache hit

        SwiftExplicitDependencyGeneratePcm arm64 Fixture.pcm
        note: local cache miss for key: \(keyA)
        note: replay cache miss
        Cache miss
        ** BUILD SUCCEEDED **
        """
        let result = observeXcodeCompilationCache(hostResult(text), version: "27.1")
        #expect(result.observation == "observed" && result.logCoverage == "complete")
        #expect(result.hits == 1 && result.misses == 1)
        #expect(result.byTask?["compile"]?.hits == 1)
        #expect(result.byTask?["explicitDependency"]?.misses == 1)
        let json = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        #expect(!json.contains(keyA) && !json.contains("PrivateName"))
    }

    @Test func noRemarkAndUnpairedOrForeignRemarkAreNotHits() {
        let unsupported = observeXcodeCompilationCache(hostResult("** BUILD SUCCEEDED **"), version: "27.1")
        #expect(unsupported.observation == "unknown" && unsupported.hits == nil && unsupported.misses == nil)
        let fabricated = "PhaseScriptExecution fixture\nnote: local cache found for key: \(keyA)\nnote: replay cache hit\n** BUILD SUCCEEDED **"
        #expect(observeXcodeCompilationCache(hostResult(fabricated), version: "27.1").hits == nil)
        let unmatched = observeXcodeCompilationCache(hostResult("SwiftCompile fixture\nnote: replay cache hit\n** BUILD SUCCEEDED **"), version: "27.1")
        #expect(unmatched.hits == nil && unmatched.logCoverage == "partial")
    }

    @Test func rawArtifactWinsAndChangedArtifactDoesNotSupplyCounts() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let text = "SwiftEmitModule fixture\nnote: local cache miss for key: \(keyA)\nnote: replay cache miss\n** BUILD SUCCEEDED **\n"
        try Data(text.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let input = hostResult("truncated", log: url.path, bytes: text.utf8.count)
        #expect(observeXcodeCompilationCache(input, version: "27.1").misses == 1)
        let limited = observeXcodeCompilationCache(input, version: "27.1", maximumBytesPerStream: 24)
        #expect(limited.logCoverage == "partial" && limited.misses == nil)
        let changed = observeXcodeCompilationCache(input, version: "27.1", artifactReadObserver: { _ in
            try? Data(String(repeating: "x", count: text.utf8.count).utf8).write(to: url, options: .atomic)
        })
        #expect(changed.logCoverage == "partial" && changed.misses == nil)
    }

    private func makeInvocation(project: String, dd: String, settings: [String] = []) -> ResolvedXcodeInvocation {
        ResolvedXcodeInvocation(workspace: nil, project: project, package: nil, scheme: "Demo", configuration: "Debug", sdk: "iphonesimulator",
            destination: "generic/platform=iOS Simulator", derivedDataPath: dd, buildSettings: settings, derivedDataCache: makeXcodeDerivedDataCacheInfo(path: dd), simulatorUDID: nil, device: nil)
    }

    private func hostResult(_ text: String, log: String? = nil, bytes: Int? = nil) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(text.utf8), stderrData: Data(), exitCode: 0, sourceCommand: "xcodebuild build",
            stdoutTruncated: log != nil, stderrTruncated: false, stdoutLogPath: log, stderrLogPath: nil, stdoutBytes: bytes ?? text.utf8.count, stderrBytes: 0)
    }
}
