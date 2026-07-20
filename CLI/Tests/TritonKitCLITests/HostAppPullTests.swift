import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct HostAppPullTests {
    @Test("app pull parses bounded real-device artifact options")
    func parsesOptions() throws {
        let command = try HostAppPull.parse([
            "--device", "ios-real:abc123",
            "--scope", "real",
            "--domain", "app-data",
            "--bundle-id", "com.example.demo",
            "--source", "Library/Application Support/bench/evidence.json",
            "--destination", "/tmp/evidence.json",
            "--overwrite",
            "--allow-directory",
            "--max-bytes", "2048",
            "--json",
        ])

        #expect(command.device == "ios-real:abc123")
        #expect(command.scope == .real)
        #expect(command.domain == .appData)
        #expect(command.bundleID == "com.example.demo")
        #expect(command.groupID == nil)
        #expect(command.source == "Library/Application Support/bench/evidence.json")
        #expect(command.destination == "/tmp/evidence.json")
        #expect(command.overwrite)
        #expect(command.allowDirectory)
        #expect(command.maxBytes == 2048)
    }

    @Test("real-device app pull atomically publishes one bounded file and redacts target")
    func pullsFile() throws {
        let directory = temporaryDirectory("success")
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("evidence.json").path
        let request = try makeHostAppPullExecutionRequest(
            selection: realDeviceSelection(),
            domain: .appData,
            bundleID: "com.example.demo",
            groupID: nil,
            source: "Library/Application Support/bench/evidence.json",
            destination: destination,
            overwrite: false,
            allowDirectory: false,
            maxBytes: 1024,
            devicectlArtifacts: (directory.appendingPathComponent("pull.json").path, directory.appendingPathComponent("pull.log").path)
        )

        let output = try executeHostAppPull(request: request) { command in
            let staged = try #require(argument(after: "--destination", in: command.argv))
            try Data("{\"pass\":true}".utf8).write(to: URL(fileURLWithPath: staged))
            return successfulResult(command)
        }

        #expect(output.ok)
        #expect(output.action == "app.pull")
        #expect(output.runtimeScope == "host-ios-real-device")
        #expect(output.target == "ios-real:abc123/app:com.example.demo")
        #expect(output.domain == "app-data")
        #expect(output.domainIdentifier == "com.example.demo")
        #expect(output.source == "Library/Application Support/bench/evidence.json")
        #expect(output.artifact.path == destination)
        #expect(output.artifact.kind == "file")
        #expect(output.artifact.bytes == 13)
        #expect(output.artifact.entryCount == 1)
        #expect(output.sourceCommand.contains("ios-real:abc123"))
        #expect(output.sourceCommand.contains("00008110-PRIVATE") == false)
        #expect(try String(contentsOfFile: destination, encoding: .utf8) == "{\"pass\":true}")
    }

    @Test("existing destination is rejected before devicectl runs")
    func rejectsExistingDestination() throws {
        let directory = temporaryDirectory("existing")
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("evidence.json")
        try Data("old".utf8).write(to: destination)
        let request = try request(destination: destination.path)
        var called = false

        #expect(throws: HostArtifactOutputError.self) {
            _ = try executeHostAppPull(request: request) { command in
                called = true
                return successfulResult(command)
            }
        }
        #expect(called == false)
        #expect(try String(contentsOf: destination, encoding: .utf8) == "old")
    }

    @Test("overwrite publishes only after a successful bounded staging copy")
    func overwritesAtomically() throws {
        let directory = temporaryDirectory("overwrite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("evidence.json")
        try Data("old".utf8).write(to: destination)
        let request = try request(destination: destination.path, overwrite: true)

        let output = try executeHostAppPull(request: request) { command in
            let staged = try #require(argument(after: "--destination", in: command.argv))
            try Data("new".utf8).write(to: URL(fileURLWithPath: staged))
            return successfulResult(command)
        }

        #expect(output.artifact.bytes == 3)
        #expect(try String(contentsOf: destination, encoding: .utf8) == "new")
    }

    @Test("overwrite keeps the prior artifact when transfer fails and always rejects symlink destinations")
    func preservesExistingArtifactOnFailure() throws {
        let directory = temporaryDirectory("overwrite-failure")
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("evidence.json")
        try Data("old".utf8).write(to: destination)
        let overwriteRequest = try request(destination: destination.path, overwrite: true)

        #expect(throws: PullTestError.expected) {
            _ = try executeHostAppPull(request: overwriteRequest) { _ in
                throw PullTestError.expected
            }
        }
        #expect(try String(contentsOf: destination, encoding: .utf8) == "old")

        let symlink = directory.appendingPathComponent("linked.json")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: destination)
        let symlinkRequest = try request(destination: symlink.path, overwrite: true)
        var called = false
        #expect(throws: HostArtifactOutputError.self) {
            _ = try executeHostAppPull(request: symlinkRequest) { command in
                called = true
                return successfulResult(command)
            }
        }
        #expect(called == false)
        #expect(try String(contentsOf: destination, encoding: .utf8) == "old")
    }

    @Test("directory and maximum byte policy reject staging output without replacing final path")
    func enforcesBounds() throws {
        let directory = temporaryDirectory("bounds")
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("pulled")
        let directoryRequest = try request(destination: destination.path)

        #expect(throws: HostAppPullError.directoryNotAllowed) {
            _ = try executeHostAppPull(request: directoryRequest) { command in
                let staged = try #require(argument(after: "--destination", in: command.argv))
                try FileManager.default.createDirectory(atPath: staged, withIntermediateDirectories: true)
                try Data("entry".utf8).write(to: URL(fileURLWithPath: staged).appendingPathComponent("report.json"))
                return successfulResult(command)
            }
        }
        #expect(FileManager.default.fileExists(atPath: destination.path) == false)

        let sizeRequest = try request(destination: destination.path, maxBytes: 4)
        #expect(throws: HostAppPullError.artifactTooLarge) {
            _ = try executeHostAppPull(request: sizeRequest) { command in
                let staged = try #require(argument(after: "--destination", in: command.argv))
                try Data("12345".utf8).write(to: URL(fileURLWithPath: staged))
                return successfulResult(command)
            }
        }
        #expect(FileManager.default.fileExists(atPath: destination.path) == false)
    }

    @Test("explicit directory pull reports recursive byte and entry counts")
    func pullsBoundedDirectory() throws {
        let directory = temporaryDirectory("directory")
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("pulled")
        let base = try request(destination: destination.path)
        let request = try makeHostAppPullExecutionRequest(
            selection: base.selection,
            domain: base.domain,
            bundleID: base.domainIdentifier,
            groupID: nil,
            source: base.source,
            destination: base.destination,
            overwrite: base.overwrite,
            allowDirectory: true,
            maxBytes: base.maxBytes,
            devicectlArtifacts: base.devicectlArtifacts
        )

        let output = try executeHostAppPull(request: request) { command in
            let staged = try #require(argument(after: "--destination", in: command.argv))
            let stagedURL = URL(fileURLWithPath: staged)
            try FileManager.default.createDirectory(at: stagedURL, withIntermediateDirectories: true)
            try Data("12".utf8).write(to: stagedURL.appendingPathComponent("a.txt"))
            try Data("345".utf8).write(to: stagedURL.appendingPathComponent("b.txt"))
            return successfulResult(command)
        }

        #expect(output.artifact.kind == "directory")
        #expect(output.artifact.bytes == 5)
        #expect(output.artifact.entryCount == 2)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("a.txt").path))
    }

    @Test("app-group domain requires a group id and maps stable devicectl failures")
    func validatesDomainAndFailureCodes() throws {
        #expect(throws: ValidationError.self) {
            _ = try makeHostAppPullExecutionRequest(
                selection: realDeviceSelection(),
                domain: .appGroup,
                bundleID: "com.example.demo",
                groupID: nil,
                source: "Shared/report.json",
                destination: "/tmp/report.json",
                overwrite: false,
                allowDirectory: false,
                maxBytes: 1024,
                devicectlArtifacts: ("/tmp/pull.json", "/tmp/pull.log")
            )
        }
        #expect(iosDevicectlPullErrorMapping(stderr: "The source file does not exist").code == "app_pull_source_not_found")
        #expect(iosDevicectlPullErrorMapping(stderr: "Application is not installed for domain identifier").code == "app_pull_domain_not_found")
        #expect(iosDevicectlPullErrorMapping(stderr: "The device is locked").code == "device_locked")
    }

    @Test("app schema exposes real-device pull contract")
    func schemaContract() throws {
        let app = try #require(commandSchemas().first { $0.name == "app" })
        let pull = try #require(app.subcommands.first { $0.name == "pull" })
        #expect(pull.requiredOptions.contains("--source"))
        #expect(pull.requiredOptions.contains("--destination"))
        #expect(pull.oneOfRequiredOptions.contains(["--bundle-id"]))
        #expect(pull.oneOfRequiredOptions.contains(["--group-id"]))
        #expect(pull.failureCodes.contains("app_pull_source_not_found"))
        #expect(app.providedCapabilities.contains("ios-real-app-pull"))
        #expect(app.examples.contains { $0.contains("triton app pull") && $0.contains("--max-bytes") })
    }

    private func request(destination: String, overwrite: Bool = false, maxBytes: UInt64 = 1024) throws -> HostAppPullExecutionRequest {
        let directory = URL(fileURLWithPath: destination).deletingLastPathComponent()
        return try makeHostAppPullExecutionRequest(
            selection: realDeviceSelection(),
            domain: .appData,
            bundleID: "com.example.demo",
            groupID: nil,
            source: "Library/report.json",
            destination: destination,
            overwrite: overwrite,
            allowDirectory: false,
            maxBytes: maxBytes,
            devicectlArtifacts: (directory.appendingPathComponent("pull.json").path, directory.appendingPathComponent("pull.log").path)
        )
    }

    private func temporaryDirectory(_ suffix: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("triton-app-pull-test-\(suffix)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func realDeviceSelection() -> HostDeviceSelectionResult {
        HostDeviceSelectionResult(
            platform: .ios,
            target: HostDeviceTarget(
                platform: "ios",
                id: "ios-real:abc123",
                target: "ios-real:abc123",
                state: "connected",
                ready: true,
                source: "devicectl",
                name: "Test iPhone",
                runtime: "iOS 26.5",
                transport: "wired",
                scope: "real",
                kind: "real-device",
                rawTarget: "00008110-PRIVATE"
            ),
            selector: "ios-real:abc123",
            source: .explicit,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "ios-real:abc123", platform: .ios, scope: .real))
        )
    }

    private func argument(after option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private func successfulResult(_ command: TKHostCommand) -> HostProcessResult {
        HostProcessResult(
            stdoutData: Data(),
            stderrData: Data(),
            exitCode: 0,
            sourceCommand: hostSourceCommand(command),
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: nil,
            stderrLogPath: nil,
            stdoutBytes: 0,
            stderrBytes: 0
        )
    }

    private enum PullTestError: Error, Equatable {
        case expected
    }
}
