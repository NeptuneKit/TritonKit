import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct EvidenceBundleTests {
    @Test("evidence capture propagates explicit target to nested runtime artifact requests")
    func evidenceCapturePropagatesExplicitTargetToNestedRuntimeArtifactRequests() async throws {
        let expectedTarget = "triton:ios-simulator:SIM-2"
        let fakeServer = EvidenceTargetPropagationFakeServer(expectedTarget: expectedTarget)
        defer { fakeServer.stop() }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("evidence-target-propagation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["list", "hierarchy", "ax", "screenshot", "geometry", "archive"],
            name: "target-propagation",
            note: nil,
            target: expectedTarget,
            host: fakeServer.host,
            port: fakeServer.port,
            refresh: true,
            urlSession: fakeServer.session
        )

        #expect(manifest.target?.id == expectedTarget)
        #expect(manifest.skipped.isEmpty)
        #expect(manifest.artifacts.map(\.kind).contains("hierarchy"))
        #expect(manifest.artifacts.map(\.kind).contains("ax"))
        #expect(manifest.artifacts.map(\.kind).contains("screenshot"))
        #expect(manifest.artifacts.map(\.kind).contains("geometry"))
        #expect(manifest.artifacts.map(\.kind).contains("archive"))
        #expect(fakeServer.requestTargets.allSatisfy { $0 == expectedTarget })
        #expect(fakeServer.requestTypes.contains("hierarchy"))
        #expect(fakeServer.requestTypes.contains("accessibility"))
        #expect(fakeServer.requestTypes.contains("screenshot"))
        #expect(fakeServer.requestTypes.contains("geometry"))
    }

    @Test("evidence capture propagates explicit target to cached hierarchy requests")
    func evidenceCapturePropagatesExplicitTargetToCachedHierarchyRequests() async throws {
        let expectedTarget = "triton:ios-simulator:SIM-2"
        let fakeServer = EvidenceTargetPropagationFakeServer(expectedTarget: expectedTarget)
        defer { fakeServer.stop() }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("evidence-cached-hierarchy-target-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["list", "hierarchy"],
            name: "cached-hierarchy-target",
            note: nil,
            target: expectedTarget,
            host: fakeServer.host,
            port: fakeServer.port,
            refresh: false,
            urlSession: fakeServer.session
        )

        #expect(manifest.target?.id == expectedTarget)
        #expect(manifest.skipped.isEmpty)
        #expect(manifest.artifacts.map(\.kind).contains("hierarchy"))
        #expect(fakeServer.latestHierarchyTargets == [expectedTarget])
    }

    @Test("schema exposes explicit xcode summary evidence import option")
    func schemaExposesExplicitXcodeSummaryEvidenceImportOption() throws {
        let evidence = try #require(commandSchemas().first { $0.name == "evidence" })

        let evidenceCapture = try #require(evidence.subcommands.first { $0.name == "capture" })
        #expect(evidenceCapture.requiredOptions.contains("--output"))
        #expect(evidenceCapture.optionalOptions.contains("--case"))
        #expect(!evidenceCapture.optionalOptions.contains("--name"))
        #expect(evidenceCapture.outputSelectors.contains("evidence.manifest"))
        #expect(evidence.examples.contains { $0.contains("evidence capture --case") })
        #expect(commandSchemas().first { $0.name == "capture" } == nil)
        #expect(evidence.options.map { $0.name }.contains("--xcode-summary"))
        #expect(evidence.options.map { $0.name }.contains("--proxy-session"))
        #expect(evidence.artifacts.contains("proxy-restore"))
        #expect(evidence.examples.contains { $0.contains("--xcode-summary") })
        #expect(evidence.examples.contains { $0.contains("--proxy-session") })
    }

    @Test("evidence capture root subcommand parses product surface")
    func evidenceCaptureRootSubcommandParsesProductSurface() throws {
        _ = try TritonKitCLI.parseAsRoot([
            "evidence",
            "capture",
            "--case",
            "login-home",
            "--output",
            "/tmp/login-home.tritonevidence",
            "--include",
            "status,list,version",
            "--json",
        ])
    }

    @Test("schema exposes real-device evidence taxonomy")
    func schemaExposesRealDeviceEvidenceTaxonomy() throws {
        let evidence = try #require(commandSchemas().first { $0.name == "evidence" })
        let smoke = try #require(commandSchemas().first { $0.name == "smoke" })

        for kind in ["real-device.diagnostics", "host.app-action", "runtime.snapshot", "host.layout", "build.summary"] {
            #expect(evidence.artifacts.contains(kind))
        }
        #expect(evidence.options.first { $0.name == "--include" }?.description.contains("real-device.diagnostics") == true)
        #expect(evidence.examples.contains { $0.contains("real-device.diagnostics,host.app-action,runtime.snapshot,host.layout,logs,build.summary") })

        #expect(smoke.options.map(\.name).contains("--scope"))
        #expect(smoke.outputSemantics?.contains("Host install/launch/open-url steps only prove action submission") == true)
        #expect(smoke.outputSemantics?.contains("proofSource=runtime") == true)
    }

    @Test("evidence include parser accepts real-device taxonomy")
    func evidenceIncludeParserAcceptsRealDeviceTaxonomy() throws {
        #expect(try parseEvidenceIncludes("real-device.diagnostics,host.app-action,runtime.snapshot,host.layout,screenshot,logs,build.summary,network.proxy-session") == [
            "real-device.diagnostics",
            "host.app-action",
            "runtime.snapshot",
            "host.layout",
            "screenshot",
            "logs",
            "build.summary",
            "network.proxy-session",
        ])
    }

    @Test("evidence capture imports explicit proxy session with network capture")
    func captureImportsExplicitProxySessionWithNetworkCapture() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-network-\(UUID().uuidString)", isDirectory: true)
        let session = FileManager.default.temporaryDirectory.appendingPathComponent("proxy-session-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: session)
        }
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)

        let captureURL = session.appendingPathComponent("requests.ndjson")
        try Data(#"{"event":"proxy.serve.request","method":"GET","url":"https://example.test/login","redaction":"headers-names-only"}"#.utf8)
            .write(to: captureURL, options: .atomic)

        let state = NetworkProxySessionStatePayload(
            schemaVersion: "triton.proxy.session.v1",
            platform: "ios",
            target: "booted",
            captureMode: "record",
            proxyEndpoint: "127.0.0.1:19431",
            configured: true,
            visibility: .partial,
            limitations: ["proxy_visibility_limited"],
            artifacts: [NetworkProxyArtifact(kind: "network-capture", path: captureURL.path, bytes: nil)],
            restoreSnapshotPath: session.appendingPathComponent("restore-state.json").path,
            sourceCommands: ["xcrun simctl spawn booted defaults write proxy"]
        )
        try prettyEncodedData(state).write(to: session.appendingPathComponent("session-state.json"), options: .atomic)

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["network.proxy-session"],
            name: "network-capture",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            proxySessionPath: session.path
        )

        #expect(manifest.artifacts.map(\.kind) == ["network.proxy-session", "network-capture"])
        #expect(manifest.primaryArtifacts.map(\.kind).first == "network-capture")
        #expect(manifest.skipped.isEmpty)

        let sessionArtifact = try #require(manifest.artifacts.first { $0.kind == "network.proxy-session" })
        #expect(sessionArtifact.path == "artifacts/network/session-state.json")
        #expect(sessionArtifact.platform == "ios")
        #expect(sessionArtifact.target == "booted")
        #expect(sessionArtifact.policy == "explicit-proxy-session")
        #expect(sessionArtifact.redactionStatus == "sensitive")
        #expect(sessionArtifact.sourceCommand == "read --proxy-session")

        let captureArtifact = try #require(manifest.artifacts.first { $0.kind == "network-capture" })
        #expect(captureArtifact.path == "artifacts/network/requests.ndjson")
        #expect(captureArtifact.contentType == "application/x-ndjson")
        #expect(captureArtifact.platform == "ios")
        #expect(captureArtifact.target == "booted")
        #expect(captureArtifact.policy == "host-proxy-metadata-capture")
        #expect(captureArtifact.redactionStatus == "sensitive")
        #expect(captureArtifact.sourceCommand == "read --proxy-session")

        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/network/session-state.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/network/requests.ndjson").path))
        #expect(try summarizeEvidenceBundle(input: root.path).sensitiveArtifactCount == 2)
    }

    @Test("evidence capture imports proxy session from argv")
    func evidenceCaptureImportsProxySessionFromArgv() async throws {
        for fixture in [
            (command: "evidence", platform: "ios", target: "booted"),
        ] {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("evidence-proxy-argv-\(fixture.command)-\(UUID().uuidString)", isDirectory: true)
            let session = FileManager.default.temporaryDirectory
                .appendingPathComponent("proxy-session-argv-\(fixture.command)-\(UUID().uuidString)", isDirectory: true)
            defer {
                try? FileManager.default.removeItem(at: root)
                try? FileManager.default.removeItem(at: session)
            }
            try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)

            let captureURL = session.appendingPathComponent("requests.ndjson")
            try Data(#"{"event":"proxy.serve.request","method":"GET","host":"example.test","redaction":"headers-names-only"}"#.utf8)
                .write(to: captureURL, options: .atomic)

            let state = NetworkProxySessionStatePayload(
                schemaVersion: "triton.proxy.session.v1",
                platform: fixture.platform,
                target: fixture.target,
                captureMode: "record",
                proxyEndpoint: "127.0.0.1:19431",
                configured: true,
                visibility: .partial,
                limitations: ["proxy_visibility_limited"],
                artifacts: [NetworkProxyArtifact(kind: "network-capture", path: "requests.ndjson", bytes: nil)],
                restoreSnapshotPath: nil,
                sourceCommands: ["triton device proxy start --platform \(fixture.platform) --plan-only --json"]
            )
            try prettyEncodedData(state).write(to: session.appendingPathComponent("session-state.json"), options: .atomic)

            let output = try await captureEvidenceCommandOutput {
                switch fixture.command {
                case "evidence":
                    let command = try EvidenceCapture.parse([
                        "--include", "network.proxy-session",
                        "--proxy-session", session.path,
                        "--output", root.path,
                        "--case", "argv-evidence",
                        "--format", "json",
                        "--json",
                    ])
                    try await command.run()
                default:
                    Issue.record("Unsupported command fixture: \(fixture.command)")
                }
            }
            let manifest = try JSONDecoder().decode(TKEvidenceManifest.self, from: Data(output.utf8))
            let sessionArtifact = try #require(manifest.artifacts.first { $0.kind == "network.proxy-session" })
            let captureArtifact = try #require(manifest.artifacts.first { $0.kind == "network-capture" })

            #expect(manifest.ok)
            #expect(sessionArtifact.platform == fixture.platform)
            #expect(sessionArtifact.target == fixture.target)
            #expect(captureArtifact.platform == fixture.platform)
            #expect(captureArtifact.target == fixture.target)
            #expect(captureArtifact.path == "artifacts/network/requests.ndjson")
            #expect(manifest.primaryArtifacts.map { $0.kind }.first == "network-capture")
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/network/session-state.json").path))
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/network/requests.ndjson").path))
        }
    }

    @Test("evidence proxy session import preserves all three emulator platforms")
    func proxySessionImportPreservesThreeEmulatorPlatforms() async throws {
        for fixture in [
            (platform: "ios", target: "booted"),
            (platform: "android", target: "emulator-5554"),
            (platform: "harmony", target: "127.0.0.1:5555"),
        ] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-network-\(fixture.platform)-\(UUID().uuidString)", isDirectory: true)
            let session = FileManager.default.temporaryDirectory.appendingPathComponent("proxy-session-\(fixture.platform)-\(UUID().uuidString)", isDirectory: true)
            defer {
                try? FileManager.default.removeItem(at: root)
                try? FileManager.default.removeItem(at: session)
            }
            try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)

            let captureURL = session.appendingPathComponent("requests.ndjson")
            try Data(#"{"event":"proxy.serve.request","method":"CONNECT","host":"example.test","redaction":"headers-names-only"}"#.utf8)
                .write(to: captureURL, options: .atomic)

            let state = NetworkProxySessionStatePayload(
                schemaVersion: "triton.proxy.session.v1",
                platform: fixture.platform,
                target: fixture.target,
                captureMode: "record",
                proxyEndpoint: "127.0.0.1:19431",
                configured: fixture.platform != "harmony",
                visibility: .partial,
                limitations: ["proxy_visibility_limited"],
                artifacts: [NetworkProxyArtifact(kind: "network-capture", path: "requests.ndjson", bytes: nil)],
                restoreSnapshotPath: nil,
                sourceCommands: ["triton device proxy start --platform \(fixture.platform) --plan-only --json"]
            )
            try prettyEncodedData(state).write(to: session.appendingPathComponent("session-state.json"), options: .atomic)

            let manifest = try await captureEvidenceBundle(
                output: root.path,
                includes: ["network.proxy-session"],
                name: "network-capture-\(fixture.platform)",
                note: nil,
                target: "triton:local",
                host: "127.0.0.1",
                port: 1,
                refresh: false,
                proxySessionPath: session.path
            )

            let sessionArtifact = try #require(manifest.artifacts.first { $0.kind == "network.proxy-session" })
            let captureArtifact = try #require(manifest.artifacts.first { $0.kind == "network-capture" })
            #expect(sessionArtifact.platform == fixture.platform)
            #expect(sessionArtifact.target == fixture.target)
            #expect(captureArtifact.platform == fixture.platform)
            #expect(captureArtifact.target == fixture.target)
            #expect(captureArtifact.path == "artifacts/network/requests.ndjson")
            #expect(manifest.primaryArtifacts.map(\.kind).first == "network-capture")
            #expect(manifest.skipped.isEmpty)
        }
    }

    @Test("evidence proxy session import preserves session metadata when capture is missing")
    func proxySessionImportPreservesSessionMetadataWhenCaptureIsMissing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-network-missing-\(UUID().uuidString)", isDirectory: true)
        let session = FileManager.default.temporaryDirectory.appendingPathComponent("proxy-session-missing-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: session)
        }
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)

        let missingCaptureURL = session.appendingPathComponent("requests.ndjson")
        let state = NetworkProxySessionStatePayload(
            schemaVersion: "triton.proxy.session.v1",
            platform: "android",
            target: "emulator-5554",
            captureMode: "record",
            proxyEndpoint: "127.0.0.1:19431",
            configured: true,
            visibility: .partial,
            limitations: ["proxy_visibility_limited"],
            artifacts: [NetworkProxyArtifact(kind: "network-capture", path: missingCaptureURL.path, bytes: nil)],
            restoreSnapshotPath: nil,
            sourceCommands: ["adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:19431"]
        )
        try prettyEncodedData(state).write(to: session.appendingPathComponent("session-state.json"), options: .atomic)

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["network.proxy-session"],
            name: "network-capture-missing",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            proxySessionPath: session.path
        )

        #expect(manifest.artifacts.map(\.kind) == ["network.proxy-session"])
        #expect(manifest.skipped.map(\.kind) == ["network-capture"])
        #expect(manifest.primaryArtifacts.map(\.kind) == ["network.proxy-session"])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/network/session-state.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/network/requests.ndjson").path))
    }

    @Test("evidence proxy session import archives restore failure even when capture is missing")
    func proxySessionImportArchivesRestoreFailureWhenCaptureIsMissing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-network-restore-\(UUID().uuidString)", isDirectory: true)
        let session = FileManager.default.temporaryDirectory.appendingPathComponent("proxy-session-restore-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: session)
        }
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)

        let restoreSnapshotURL = session.appendingPathComponent("restore-state.json")
        try Data(#"{"schemaVersion":"triton.proxy.restore.v1"}"#.utf8).write(to: restoreSnapshotURL, options: .atomic)
        let restoreFailure = NetworkProxyRestoreFailurePayload(
            schemaVersion: "triton.proxy.restore-failure.v1",
            platform: "android",
            target: "emulator-5554",
            action: "proxy.stop",
            auditRecord: "audit-restore-1",
            restoreSnapshotPath: restoreSnapshotURL.path,
            restoreSourceCommands: ["adb -s emulator-5554 shell settings delete global http_proxy"],
            errorCode: "proxy_restore_failed",
            errorSummary: "denied",
            capturedAt: "2026-06-11T00:00:00Z"
        )
        try prettyEncodedData(restoreFailure).write(to: session.appendingPathComponent("restore-failure.json"), options: .atomic)

        let state = NetworkProxySessionStatePayload(
            schemaVersion: "triton.proxy.session.v1",
            platform: "android",
            target: "emulator-5554",
            captureMode: "record",
            proxyEndpoint: "127.0.0.1:19431",
            configured: true,
            visibility: .partial,
            limitations: ["proxy_visibility_limited", "proxy_restore_failure_artifact_written"],
            artifacts: [NetworkProxyArtifact(kind: "network-capture", path: "requests.ndjson", bytes: nil)],
            restoreSnapshotPath: restoreSnapshotURL.path,
            sourceCommands: ["adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:19431"]
        )
        try prettyEncodedData(state).write(to: session.appendingPathComponent("session-state.json"), options: .atomic)

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["network.proxy-session"],
            name: "network-restore-failure",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            proxySessionPath: session.path
        )

        #expect(manifest.artifacts.map(\.kind) == ["network.proxy-session", "proxy-restore"])
        #expect(manifest.skipped.map(\.kind) == ["network-capture"])
        #expect(manifest.primaryArtifacts.map(\.kind).first == "proxy-restore")

        let restoreArtifact = try #require(manifest.artifacts.first { $0.kind == "proxy-restore" })
        #expect(restoreArtifact.path == "artifacts/network/restore-failure.json")
        #expect(restoreArtifact.contentType == "application/json")
        #expect(restoreArtifact.platform == "android")
        #expect(restoreArtifact.target == "emulator-5554")
        #expect(restoreArtifact.policy == "proxy-restore-failure-recovery")
        #expect(restoreArtifact.redactionStatus == "sensitive")
        #expect(restoreArtifact.sourceCommand == "read --proxy-session")

        let copiedPayload = try JSONDecoder().decode(
            NetworkProxyRestoreFailurePayload.self,
            from: Data(contentsOf: root.appendingPathComponent("artifacts/network/restore-failure.json"))
        )
        #expect(copiedPayload.errorCode == "proxy_restore_failed")
        #expect(copiedPayload.errorSummary == "denied")
        #expect(try summarizeEvidenceBundle(input: root.path).sensitiveArtifactCount == 2)
    }

    @Test("evidence capture writes host and xcode read-only artifacts without runtime")
    func captureWritesHostAndXcodeReadOnlyArtifactsWithoutRuntime() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-host-xcode-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(try parseEvidenceIncludes("host,xcode") == ["host", "xcode"])

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: {
                TKHostWorkspaceDefaults(
                    defaultSimulatorUDID: "SIM-1",
                    xcode: TKXcodeWorkspaceDefaults(
                        workspace: "App.xcworkspace",
                        project: nil,
                        scheme: "App",
                        configuration: "Debug",
                        sdk: "iphonesimulator",
                        destination: "platform=iOS Simulator,id=SIM-1",
                        derivedDataPath: ".triton/DerivedData"
                    )
                )
            },
            simulatorList: {
                EvidenceArtifactPayload(
                    data: Data(#"{"devices":{}}"#.utf8),
                    sourceCommand: "xcrun simctl list devices available --json"
                )
            },
            xcodeStatus: {
                EvidenceArtifactPayload(
                    data: try prettyEncodedData(XcodeProcessStatusOutput(
                        ok: true,
                        active: false,
                        workspaceFilter: nil,
                        processes: [],
                        summary: XcodeProcessStatusSummary(
                            xcodebuildCount: 0,
                            buildServiceCount: 0,
                            xctestCount: 0,
                            matchingWorkspaceCount: 0
                        ),
                        sourceCommand: "pgrep -f xcodebuild"
                    )),
                    sourceCommand: "pgrep -f xcodebuild"
                )
            },
            xcodeDiscovery: {
                EvidenceArtifactPayload(
                    data: Data(#"{"ok":true,"workspaces":[],"projects":[],"packages":[]}"#.utf8),
                    sourceCommand: "triton xcode discover --path . --json"
                )
            }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["host", "xcode"],
            name: "host-xcode-contract",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            hostXcodeProviders: providers
        )

        #expect(manifest.artifacts.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.defaults",
            "xcode.status",
            "xcode.discovery",
        ])
        #expect(manifest.primaryArtifacts.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.status",
            "xcode.discovery",
            "xcode.defaults",
        ])
        #expect(manifest.artifacts.allSatisfy { !$0.path.hasPrefix("/") && !$0.path.contains("..") })
        #expect(manifest.artifacts.allSatisfy { $0.riskLevel == "readonly" })
        #expect(manifest.artifacts.allSatisfy { $0.policy == "read-only-small-artifact" })
        #expect(manifest.artifacts.allSatisfy { $0.redactionStatus == "sensitive" })
        #expect(manifest.skipped.isEmpty)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/host/defaults.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/status.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/discovery.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("manifest.json").path))

        let summary = try summarizeEvidenceBundle(input: root.path)
        #expect(summary.sensitiveArtifactCount == 5)
        #expect(summary.primaryArtifacts.map(\.kind) == manifest.primaryArtifacts.map(\.kind))
    }

    @Test("evidence capture records skipped host and xcode sources when unavailable")
    func captureRecordsSkippedHostAndXcodeSourcesWhenUnavailable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-host-xcode-skipped-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: { nil },
            simulatorList: { throw RuntimeError("simulator list unavailable") },
            xcodeStatus: { throw RuntimeError("xcode status unavailable") },
            xcodeDiscovery: { throw RuntimeError("xcode discovery unavailable") }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["host", "xcode"],
            name: "host-xcode-skipped",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            hostXcodeProviders: providers
        )

        #expect(manifest.artifacts.isEmpty)
        #expect(manifest.skipped.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.defaults",
            "xcode.status",
            "xcode.discovery",
        ])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("manifest.json").path))
    }

    @Test("evidence capture imports explicit xcode action summary without copying logs")
    func captureImportsExplicitXcodeActionSummaryWithoutCopyingLogs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-xcode-summary-\(UUID().uuidString)", isDirectory: true)
        let summaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("xcode-action-summary-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: summaryURL)
        }

        let actionSummary = TKXcodeActionSummary(
            ok: false,
            action: "xcode.test",
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData",
            resultBundlePath: "/tmp/App.xcresult",
            simulatorUDID: "SIM-1",
            durationMs: 42,
            sourceCommand: "xcodebuild test -workspace App.xcworkspace",
            exitCode: 65,
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/stderr.log",
            stdoutBytes: 123,
            stderrBytes: 456,
            note: "Test failed."
        )
        try prettyEncodedData(actionSummary).write(to: summaryURL, options: .atomic)

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: { nil },
            simulatorList: { throw RuntimeError("not used") },
            xcodeStatus: { throw RuntimeError("not available") },
            xcodeDiscovery: { throw RuntimeError("not available") }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["xcode"],
            name: "xcode-summary-import",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            xcodeSummaryPath: summaryURL.path,
            hostXcodeProviders: providers
        )

        let artifact = try #require(manifest.artifacts.first { $0.kind == "xcode.action-summary" })
        #expect(artifact.path == "artifacts/xcode/action-summary.json")
        #expect(artifact.riskLevel == "readonly")
        #expect(artifact.policy == "explicit-xcode-summary")
        #expect(artifact.redactionStatus == "sensitive")
        #expect(artifact.sourceCommand == "read --xcode-summary")
        #expect(manifest.artifacts.count == 1)
        #expect(manifest.primaryArtifacts.map(\.kind) == ["xcode.action-summary"])
        #expect(manifest.skipped.map { $0.kind } == ["xcode.defaults", "xcode.status", "xcode.discovery"])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/action-summary.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/stdout.log").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/stderr.log").path))

        let importedData = try Data(contentsOf: root.appendingPathComponent("artifacts/xcode/action-summary.json"))
        let imported = try JSONDecoder().decode(TKXcodeActionSummary.self, from: importedData)
        #expect(imported.stdoutLogPath == "/tmp/triton-xcode-artifacts/stdout.log")
        #expect(try summarizeEvidenceBundle(input: root.path).sensitiveArtifactCount == 1)
    }

    @Test("evidence summary and redact exclude sensitive artifacts")
    func summaryAndRedactExcludeSensitiveArtifacts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-\(UUID().uuidString)", isDirectory: true)
        let redacted = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-redacted-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: redacted)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(#"{"ok":true}"#.utf8).write(to: root.appendingPathComponent("status.json"), options: .atomic)
        try Data("private screenshot".utf8).write(to: root.appendingPathComponent("screenshot.png"), options: .atomic)

        let manifest = TKEvidenceManifest(
            ok: true,
            name: "case",
            note: "note",
            createdAt: "2026-05-23T00:00:00Z",
            output: root.path,
            artifacts: [
                TKEvidenceArtifact(kind: "status", path: "status.json", contentType: "application/json", bytes: 11),
                TKEvidenceArtifact(
                    kind: "screenshot",
                    path: "screenshot.png",
                    contentType: "image/png",
                    bytes: 18,
                    sourceCommand: "xcrun simctl io /Users/private/App screenshot"
                ),
            ],
            target: TKEvidenceTarget(
                connected: true,
                appName: "App",
                bundleIdentifier: "com.example.app",
                deviceDescription: "sim",
                osDescription: "iOS",
                identityState: "debug"
            ),
            cli: TKEvidenceCLI(version: "test"),
            run: TKEvidenceRunManifest(
                eventsPath: "run/events.jsonl",
                metaPath: "run/meta.json",
                screenshotPaths: ["screenshot.png"],
                eventCount: 2,
                status: .completed,
                summary: TKEvidenceRunSummary(
                    runID: "run-1",
                    verdict: .success,
                    frictionCount: 0,
                    stepCount: 1
                )
            )
        )
        try prettyEncodedData(manifest).write(to: root.appendingPathComponent("manifest.json"), options: .atomic)

        let summary = try summarizeEvidenceBundle(input: root.path)

        #expect(summary.artifactCount == 2)
        #expect(summary.sensitiveArtifactCount == 1)
        #expect(summary.artifacts.map(\.kind) == ["status", "screenshot"])
        #expect(summary.primaryArtifacts.map(\.kind) == ["screenshot", "status"])
        #expect(summary.suggestedCommands.count == 1)

        let output = try redactEvidenceBundle(input: root.path, output: redacted.path, profile: "ios-private")

        #expect(output.redactedArtifactCount == 1)
        #expect(output.keptArtifactCount == 1)
        #expect(output.manifest.artifacts.map(\.kind) == ["status", "screenshot"])
        #expect(output.manifest.artifacts.first { $0.kind == "status" }?.redactionStatus == "included")
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.redactionStatus == "redacted")
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.sourceCommand == nil)
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.path.hasPrefix("redacted/") == true)
        #expect(output.primaryArtifacts.map(\.kind) == ["screenshot", "status"])
        #expect(output.suggestedCommands.contains("triton evidence inspect '\(redacted.path)' --json"))
        #expect(output.manifest.run?.eventsPath == "run/events.jsonl")
        #expect(output.manifest.run?.metaPath == "run/meta.json")
        #expect(output.manifest.run?.summary?.verdict == .success)
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("summary.json").path))
    }

    @Test("evidence summary exposes P0C run event overview")
    func summaryExposesP0CRunEventOverview() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-p0c-run-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("run"), withIntermediateDirectories: true)

        let run = TKTestRunMetadata(
            runID: "run-p0c-001",
            source: "manual-primitive-smoke",
            status: .passed,
            startedAt: "2026-06-20T00:00:00Z",
            endedAt: "2026-06-20T00:00:04Z",
            durationMs: 4000,
            evidenceManifestRef: "../manifest.json"
        )
        try prettyEncodedData(run).write(to: root.appendingPathComponent("run/run.json"), options: .atomic)
        let events = """
        {"schemaVersion":1,"type":"run.started","runId":"run-p0c-001","timestamp":"2026-06-20T00:00:00Z"}
        {"schemaVersion":1,"type":"assertion.result","runId":"run-p0c-001","timestamp":"2026-06-20T00:00:01Z","stepIndex":2,"status":"passed","selector":{"text":{"value":"Fixture Login","match":"exact","source":"ax"}}}
        {"schemaVersion":1,"type":"run.finished","runId":"run-p0c-001","timestamp":"2026-06-20T00:00:04Z","status":"passed","durationMs":4000}
        """
        try Data(events.utf8).write(to: root.appendingPathComponent("run/events.jsonl"), options: .atomic)

        let manifest = TKEvidenceManifest(
            ok: true,
            name: "p0c-pass",
            createdAt: "2026-06-20T00:00:00Z",
            output: root.path,
            artifacts: [
                TKEvidenceArtifact(kind: "run.run", path: "run/run.json", contentType: "application/json"),
                TKEvidenceArtifact(kind: "run.events", path: "run/events.jsonl", contentType: "application/x-ndjson"),
            ],
            cli: TKEvidenceCLI(version: "test"),
            run: TKEvidenceRunManifest(
                eventsPath: "run/events.jsonl",
                metaPath: "run/run.json",
                eventCount: 3,
                status: .completed,
                summary: TKEvidenceRunSummary(
                    runID: "run-p0c-001",
                    verdict: .success,
                    frictionCount: 0,
                    stepCount: 0
                )
            )
        )
        try prettyEncodedData(manifest).write(to: root.appendingPathComponent("manifest.json"), options: .atomic)

        let summary = try summarizeEvidenceBundle(input: root.path)

        #expect(summary.run?.eventCount == 3)
        #expect(summary.run?.metaPath == "run/run.json")
        #expect(summary.run?.summary?.runID == "run-p0c-001")
        #expect(summary.primaryArtifacts.map(\.kind) == ["run.events", "run.run"])
    }
}

private func captureEvidenceCommandOutput(_ body: () async throws -> Void) async throws -> String {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)

    fflush(stdout)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    do {
        try await body()
    } catch {
        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()
        throw error
    }
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}

private final class EvidenceTargetPropagationFakeServer {
    let host = "127.0.0.1"
    let port: Int
    let session: URLSession

    private let server: URLProtocol.Type

    init(expectedTarget: String) {
        self.port = Int.random(in: 20_000...40_000)
        self.server = EvidenceTargetPropagationURLProtocol.self
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [server]
        self.session = URLSession(configuration: configuration)
        EvidenceTargetPropagationURLProtocol.configure(port: port, expectedTarget: expectedTarget)
        URLProtocol.registerClass(server)
    }

    func stop() {
        URLProtocol.unregisterClass(server)
        EvidenceTargetPropagationURLProtocol.reset()
    }

    var requestTargets: [String?] {
        EvidenceTargetPropagationURLProtocol.requestTargets
    }

    var requestTypes: [String] {
        EvidenceTargetPropagationURLProtocol.requestTypes
    }

    var latestHierarchyTargets: [String?] {
        EvidenceTargetPropagationURLProtocol.latestHierarchyTargets
    }
}

private final class EvidenceTargetPropagationURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var configuredPort: Int?
    private static var configuredExpectedTarget: String?
    private static var recordedTargets: [String?] = []
    private static var recordedTypes: [String] = []
    private static var recordedLatestHierarchyTargets: [String?] = []

    static var requestTargets: [String?] {
        lock.withEvidenceLock { recordedTargets }
    }

    static var requestTypes: [String] {
        lock.withEvidenceLock { recordedTypes }
    }

    static var latestHierarchyTargets: [String?] {
        lock.withEvidenceLock { recordedLatestHierarchyTargets }
    }

    static func configure(port: Int, expectedTarget: String) {
        lock.withEvidenceLock {
            configuredPort = port
            configuredExpectedTarget = expectedTarget
            recordedTargets = []
            recordedTypes = []
            recordedLatestHierarchyTargets = []
        }
    }

    static func reset() {
        lock.withEvidenceLock {
            configuredPort = nil
            configuredExpectedTarget = nil
            recordedTargets = []
            recordedTypes = []
            recordedLatestHierarchyTargets = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return lock.withEvidenceLock {
            url.scheme == "http"
                && url.host == "127.0.0.1"
                && url.port == configuredPort
        }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let response = try Self.response(for: request)
            client?.urlProtocol(
                self,
                didReceive: HTTPURLResponse(
                    url: request.url!,
                    statusCode: response.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": response.contentType]
                )!,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func response(for request: URLRequest) throws -> (statusCode: Int, contentType: String, data: Data) {
        guard let url = request.url else {
            throw RuntimeError("Missing fake server URL")
        }
        switch (request.httpMethod ?? "GET", url.path) {
        case ("GET", "/status"):
            return try json(TKStatusResponse(connected: true, latestHierarchyAvailable: true, targetCount: 2))
        case ("GET", "/targets"):
            let targets = [
                TKTargetSummary(id: "triton:ios-simulator:SIM-1", connected: true, latestHierarchyAvailable: true, simulatorUDID: "SIM-1"),
                TKTargetSummary(id: configuredExpectedTarget ?? "triton:ios-simulator:SIM-2", connected: true, latestHierarchyAvailable: true, simulatorUDID: "SIM-2"),
            ]
            return try json(TKTargetsResponse(targets: targets))
        case ("GET", "/hierarchy/latest"):
            let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "target" }?
                .value
            let expectedTarget = lock.withEvidenceLock { configuredExpectedTarget }
            lock.withEvidenceLock {
                recordedLatestHierarchyTargets.append(target)
            }
            guard target == expectedTarget else {
                return try json(
                    TKCLIErrorResponse(error: TKCLIErrorDetail(
                        code: "ambiguous_target",
                        message: "Target is ambiguous: \(target ?? TKLocalTargetID). Pass --target <id>."
                    )),
                    statusCode: 409
                )
            }
            return try runtimeResponse(for: "hierarchy")
        case ("POST", "/request"):
            let body = request.httpBodyStream.map(readBodyStream) ?? request.httpBody ?? Data()
            let command = try JSONDecoder().decode(TKCLICommandRequest.self, from: body)
            let expectedTarget = lock.withEvidenceLock { configuredExpectedTarget }
            lock.withEvidenceLock {
                recordedTargets.append(command.target)
                recordedTypes.append(command.type)
            }
            guard command.target == expectedTarget else {
                return try json(
                    TKCLIErrorResponse(error: TKCLIErrorDetail(
                        code: "ambiguous_target",
                        message: "Target is ambiguous: \(command.target ?? TKLocalTargetID). Pass --target <id>."
                    )),
                    statusCode: 409
                )
            }
            return try runtimeResponse(for: command.type)
        default:
            return (404, "text/plain", Data("not found".utf8))
        }
    }

    private static func runtimeResponse(for type: String) throws -> (statusCode: Int, contentType: String, data: Data) {
        switch type {
        case "hierarchy":
            return try json([
                "displayItems": [],
                "appInfo": [
                    "appName": "Demo",
                    "deviceDescription": "iPhone",
                    "osDescription": "iOS 26",
                ],
            ] as [String: Any])
        case "accessibility":
            return try json([TKAXNode]())
        case "geometry":
            return try json(TKGeometryResponse(
                bounds: TKRect(x: 0, y: 0, width: 390, height: 844),
                safeArea: TKInsets(top: 59, left: 0, bottom: 34, right: 0),
                scale: 3,
                orientation: "portrait"
            ))
        case "screenshot":
            return try json(TKScreenshotResponse(
                format: "png",
                width: 1,
                height: 1,
                scale: 1,
                dataBase64: Data("png".utf8).base64EncodedString()
            ))
        default:
            return (400, "text/plain", Data("unsupported request".utf8))
        }
    }

    private static func json<T: Encodable>(
        _ value: T,
        statusCode: Int = 200
    ) throws -> (statusCode: Int, contentType: String, data: Data) {
        (statusCode, "application/json", try JSONEncoder().encode(value))
    }

    private static func json(
        _ object: Any,
        statusCode: Int = 200
    ) throws -> (statusCode: Int, contentType: String, data: Data) {
        (statusCode, "application/json", try JSONSerialization.data(withJSONObject: object))
    }

    private static func readBodyStream(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private extension NSLock {
    func withEvidenceLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
