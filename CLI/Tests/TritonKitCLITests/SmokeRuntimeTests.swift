import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct SmokeRuntimeTests {
    @Test("smoke ios reports runtime wait failure after open-url succeeds")
    func reportsWaitFailureAfterOpenURL() async throws {
        let runtime = FakeSmokeRuntimeClient(
            waitResults: [
                .success(failingWaitResult(query: "Ready")),
            ],
            assertResults: []
        )
        let temp = try makeSmokeWorkspace(prefix: "wait-failure")
        defer { try? FileManager.default.removeItem(at: temp.root) }

        let summary = try await runIOSSmoke(
            options: makeOptions(
                temp: temp,
                waitText: "Ready"
            ),
            dependencies: makeDependencies(
                runtime: runtime,
                temp: temp
            )
        )

        #expect(summary.ok == false)
        #expect(summary.status == .fail)
        #expect(summary.failure?.step == "runtime.wait")
        #expect(summary.failure?.code == "text_not_found")
        #expect(summary.steps.map(\.name) == ["app.open-url", "runtime.wait"])
        #expect(summary.steps[0].status == .pass)
        #expect(summary.steps[1].status == .fail)
        #expect(summary.steps[1].message == "Expected text to exist: Ready")
        #expect(summary.assertions.isEmpty)
        #expect(summary.artifacts.isEmpty)
        #expect(summary.evidence == nil)
    }

    @Test("smoke ios real-device open-url success is not business pass without runtime")
    func realDeviceOpenURLSuccessDoesNotPassWithoutRuntime() async throws {
        let temp = try makeSmokeWorkspace(prefix: "real-runtime-missing")
        defer { try? FileManager.default.removeItem(at: temp.root) }
        let realTarget = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:abc123",
            target: "ios-real:abc123",
            state: "available",
            ready: true,
            source: "devicectl",
            name: "iPhone",
            runtime: "iOS 26.0",
            transport: "usb",
            scope: "real",
            kind: "real-device",
            sensitive: true,
            rawTarget: "00008110-0012345678901234"
        )

        let summary = try await runIOSSmoke(
            options: makeOptions(
                temp: temp,
                hostTarget: realTarget,
                waitText: "Ready"
            ),
            dependencies: makeDisconnectedRuntimeDependencies(temp: temp)
        )

        #expect(summary.ok == false)
        #expect(summary.status == .fail)
        #expect(summary.failure?.step == "runtime.connect")
        #expect(summary.failure?.code == "runtime_not_connected")
        #expect(summary.steps.map(\.name) == ["app.open-url"])
        #expect(summary.steps[0].proofSource == .hostAction)
        #expect(summary.steps[0].businessReady == false)
        #expect(summary.steps[0].target == "ios-real:abc123/app:com.example.app")
    }

    @Test("smoke ios reports assertion failure after wait succeeds")
    func reportsAssertionFailureAfterWait() async throws {
        let runtime = FakeSmokeRuntimeClient(
            waitResults: [
                .success(successWaitResult(query: "Title")),
            ],
            assertResults: [
                .success(failingAssertResult(query: "Subtitle")),
            ]
        )
        let temp = try makeSmokeWorkspace(prefix: "assert-failure")
        defer { try? FileManager.default.removeItem(at: temp.root) }

        let summary = try await runIOSSmoke(
            options: makeOptions(
                temp: temp,
                waitText: "Title",
                assertText: "Subtitle"
            ),
            dependencies: makeDependencies(
                runtime: runtime,
                temp: temp
            )
        )

        #expect(summary.ok == false)
        #expect(summary.status == .fail)
        #expect(summary.failure?.step == "runtime.assert")
        #expect(summary.failure?.code == "text_not_found")
        #expect(summary.steps.map(\.name) == ["app.open-url", "runtime.wait", "runtime.assert"])
        #expect(summary.steps[2].status == .fail)
        #expect(summary.assertions.count == 1)
        #expect(summary.assertions[0].ok == false)
        #expect(summary.artifacts.isEmpty)
        #expect(summary.evidence == nil)
    }

    @Test("smoke ios records screenshot and evidence artifacts on success")
    func recordsArtifactsOnSuccess() async throws {
        let runtime = FakeSmokeRuntimeClient(
            waitResults: [
                .success(successWaitResult(query: "Title")),
            ],
            assertResults: [
                .success(successAssertResult(query: "Subtitle")),
            ]
        )
        let temp = try makeSmokeWorkspace(prefix: "success")
        defer { try? FileManager.default.removeItem(at: temp.root) }

        let screenshotPath = temp.root.appendingPathComponent("artifacts/screenshot.png").path
        let evidencePath = temp.root.appendingPathComponent("evidence/case.tritonevidence").path

        let summary = try await runIOSSmoke(
            options: makeOptions(
                temp: temp,
                waitText: "Title",
                assertText: "Subtitle",
                screenshot: screenshotPath,
                evidence: evidencePath
            ),
            dependencies: makeDependencies(
                runtime: runtime,
                temp: temp
            )
        )

        #expect(summary.ok == true)
        #expect(summary.status == .pass)
        #expect(summary.failure == nil)
        #expect(summary.steps.map(\.name) == ["app.open-url", "runtime.wait", "runtime.assert", "sim.screenshot", "evidence.capture"])
        #expect(summary.artifacts.map(\.path) == [screenshotPath, evidencePath])
        #expect(summary.evidence?.output == evidencePath)
        #expect(FileManager.default.fileExists(atPath: screenshotPath))
        #expect(FileManager.default.fileExists(atPath: evidencePath))
        #expect(FileManager.default.fileExists(atPath: evidencePath + "/manifest.json"))
    }
}

private final class FakeSmokeRuntimeClient: SmokeRuntimeClient {
    var waitResults: [Result<TKWaitResult, Error>]
    var assertResults: [Result<TKUIAssertResult, Error>]

    init(waitResults: [Result<TKWaitResult, Error>], assertResults: [Result<TKUIAssertResult, Error>]) {
        self.waitResults = waitResults
        self.assertResults = assertResults
    }

    func wait(_ request: WaitRequest) async throws -> TKWaitResult {
        guard !waitResults.isEmpty else {
            throw RuntimeError("Unexpected wait request for \(request.query ?? "<nil>")")
        }
        return try waitResults.removeFirst().get()
    }

    func assert(_ query: String) async throws -> TKUIAssertResult {
        guard !assertResults.isEmpty else {
            throw RuntimeError("Unexpected assert request for \(query)")
        }
        return try assertResults.removeFirst().get()
    }
}

private struct SmokeWorkspace {
    let root: URL
}

private func makeSmokeWorkspace(prefix: String) throws -> SmokeWorkspace {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return SmokeWorkspace(root: url)
}

private func makeOptions(
    temp: SmokeWorkspace,
    hostTarget: HostDeviceTarget? = nil,
    waitText: String,
    assertText: String? = nil,
    screenshot: String? = nil,
    evidence: String? = nil
) -> IOSSmokeOptions {
    IOSSmokeOptions(
        simulator: "SIM-1",
        hostTarget: hostTarget,
        target: "triton:local",
        bundleID: "com.example.app",
        openURL: "myapp://home",
        waitText: waitText,
        assertText: assertText,
        screenshot: screenshot,
        evidence: evidence ?? temp.root.appendingPathComponent("evidence/case.tritonevidence").path,
        evidenceName: "case",
        evidenceNote: "note",
        host: "127.0.0.1",
        port: 19421,
        timeout: 0.25,
        interval: 0.01
    )
}

private func makeDependencies(runtime: FakeSmokeRuntimeClient, temp: SmokeWorkspace) -> IOSSmokeDependencies {
    IOSSmokeDependencies(
        makeRuntimeClient: { _, _, _ in runtime },
        openURL: { selected, bundleID, url in
            try writeMarker(at: temp.root.appendingPathComponent("open-url.txt"), contents: "\(selected.id) \(bundleID) \(url)")
            return HostActionOutput(
                ok: true,
                action: "app.open-url",
                runtimeScope: selected.scope == "real" ? "host-ios-real" : "host-ios-simulator",
                target: selected.scope == "real" ? "\(selected.id)/app:\(bundleID)" : "sim:\(selected.target)/app:\(bundleID)",
                tool: selected.scope == "real" ? "devicectl" : "simctl",
                exitCode: 0,
                riskLevel: "automation",
                sourceCommand: selected.scope == "real" ? "devicectl launch --payload-url" : "simctl openurl \(selected.target) \(url)",
                stdoutTruncated: false,
                stderrTruncated: false,
                stdout: nil,
                stderr: nil,
                artifacts: [],
                note: "submitted"
            )
        },
        screenshot: { simulator, output in
            let url = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("screenshot:\(simulator)".utf8).write(to: url, options: .atomic)
            return "simctl screenshot \(simulator) \(output)"
        },
        captureEvidence: { output, includes, name, note, target, host, port, refresh in
            let outputURL = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            let manifest = TKEvidenceManifest(
                ok: true,
                name: name,
                note: note,
                createdAt: "2026-05-22T00:00:00Z",
                output: output,
                artifacts: [
                    TKEvidenceArtifact(kind: "screenshot", path: "artifacts/host/screenshot.png")
                ],
                target: TKEvidenceTarget(
                    connected: true,
                    appName: "App",
                    bundleIdentifier: target,
                    deviceDescription: host,
                    osDescription: "\(port)",
                    identityState: refresh ? "refreshed" : "stale",
                    targetConnectionState: "connected",
                    hierarchyCacheState: "active"
                ),
                cli: TKEvidenceCLI(version: "test")
            )
            _ = includes
            let manifestURL = outputURL.appendingPathComponent("manifest.json")
            try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
            return manifest
        }
    )
}

private func makeDisconnectedRuntimeDependencies(temp: SmokeWorkspace) -> IOSSmokeDependencies {
    IOSSmokeDependencies(
        makeRuntimeClient: { _, _, _ in
            throw RuntimeError("runtime not connected")
        },
        openURL: { selected, bundleID, url in
            try writeMarker(at: temp.root.appendingPathComponent("open-url.txt"), contents: "\(selected.id) \(bundleID) \(url)")
            return HostActionOutput(
                ok: true,
                action: "app.open-url",
                runtimeScope: "host-ios-real",
                target: "\(selected.id)/app:\(bundleID)",
                tool: "devicectl",
                exitCode: 0,
                riskLevel: "automation",
                sourceCommand: "devicectl device process launch --payload-url",
                stdoutTruncated: false,
                stderrTruncated: false,
                stdout: nil,
                stderr: nil,
                artifacts: [],
                note: "submitted"
            )
        },
        screenshot: { _, _ in
            throw RuntimeError("unexpected screenshot")
        },
        captureEvidence: { _, _, _, _, _, _, _, _ in
            throw RuntimeError("unexpected evidence")
        }
    )
}

private func successWaitResult(query: String) -> TKWaitResult {
    TKWaitResult(
        ok: true,
        matched: true,
        condition: "text",
        query: query,
        timedOut: false,
        elapsedMs: 4,
        pollCount: 1,
        timeoutSeconds: 0.25,
        intervalSeconds: 0.01,
        targetConnectionState: "connected",
        hierarchyCacheState: "active",
        lastObservedNodeCount: 1,
        lastObservedTextSample: [query],
        lastObservedHierarchyHash: "hash",
        match: TKWaitMatch(
            text: query,
            role: "staticText",
            label: nil,
            value: nil,
            identifier: nil,
            title: nil,
            frame: TKRect(x: 0, y: 0, width: 10, height: 10),
            targetOID: nil,
            viewOID: nil,
            className: nil,
            source: "runtime"
        )
    )
}

private func failingWaitResult(query: String) -> TKWaitResult {
    TKWaitResult(
        ok: false,
        matched: false,
        condition: "text",
        query: query,
        timedOut: true,
        elapsedMs: 12,
        pollCount: 3,
        timeoutSeconds: 0.25,
        intervalSeconds: 0.01,
        targetConnectionState: "connected",
        hierarchyCacheState: "active",
        lastObservedNodeCount: 1,
        lastObservedTextSample: ["Home"],
        lastObservedHierarchyHash: "hash",
        match: nil
    )
}

private func successAssertResult(query: String) -> TKUIAssertResult {
    TKUIAssertResult(
        ok: true,
        condition: "text-exists",
        query: query,
        count: 1,
        matches: [],
        sample: [query],
        targetConnectionState: "connected",
        hierarchyCacheState: "active",
        message: nil
    )
}

private func failingAssertResult(query: String) -> TKUIAssertResult {
    TKUIAssertResult(
        ok: false,
        condition: "text-exists",
        query: query,
        count: 0,
        matches: [],
        sample: ["Title"],
        targetConnectionState: "connected",
        hierarchyCacheState: "active",
        message: "Expected text to exist: \(query)"
    )
}

private func writeMarker(at url: URL, contents: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: url, options: .atomic)
}
