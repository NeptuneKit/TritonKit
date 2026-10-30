import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct PackagedWebIOSFramebufferTests {
    @Test func unusedResponseReleasesEagerIOSCapture() throws {
        let trace = PackagedIOSCaptureTrace()
        do {
            let response = makePackagedWebIOSSimulatorMjpegResponse(
                try makePackagedWebIOSSimulatorMjpegRequest(target: "fixture", udid: nil, fps: nil),
                request: Request(head: .init(method: .get, scheme: "http", authority: "localhost", path: "/"), body: .init(buffer: ByteBuffer())),
                capture: trace.dependencies
            )
            #expect(response.status == .ok)
            #expect(trace.starts == 1)
            #expect(trace.stops == 0)
            withExtendedLifetime(response) {}
        }
        #expect(trace.stops == 1, "An eagerly acquired iOS capture must be released even if HTTP never executes its body")
    }

    @Test func startupFailurePreservesConflictWithoutReleasingUnacquiredCapture() async throws {
        let trace = PackagedIOSCaptureTrace(canStart: false)
        try await Application(router: makeIOSFixtureRouter(trace)).test(.router) { client in
            let response = try await client.execute(uri: "/web/ios-simulator/mjpeg?udid=fixture", method: .get)
            #expect(response.status == .conflict)
            let error = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(buffer: response.body))
            #expect(error.error.code == "web_ios_simulator_mjpeg_unavailable")
        }
        #expect(trace.starts == 1)
        #expect(trace.stops == 0)
    }

    @Test func disconnectBeforeFirstIOSFrameReleasesCapture() async throws {
        let trace = PackagedIOSCaptureTrace()
        try await Application(router: makeIOSFixtureRouter(trace)).test(.live) { server in
            let port = try #require(server.port)
            try await TestClient.withClient(host: "localhost", port: port) { client in
                try await client.executeAndDontWaitForResponse(.init("/web/ios-simulator/mjpeg?udid=fixture&fps=30", method: .get))
                let started = try await waitForIOSCapture(trace, starts: 1, stops: 0)
                #expect(started.starts == 1)
                try await client.close(mode: .all)
                let released = try await waitForIOSCapture(trace, starts: 1, stops: 1)
                #expect(released.stops == 1)
                // Bounds teardown on the old implementation, which only notices close while writing.
                trace.finishFixture()
            }
        }
        #expect(trace.stops == 1)
    }

    @Test func closingOneIOSSubscriberKeepsTheOtherCaptureReference() async throws {
        let trace = PackagedIOSCaptureTrace()
        try await Application(router: makeIOSFixtureRouter(trace)).test(.live) { server in
            let port = try #require(server.port)
            try await TestClient.withClient(host: "localhost", port: port) { first in
                try await TestClient.withClient(host: "localhost", port: port) { second in
                    try await first.executeAndDontWaitForResponse(.init("/web/ios-simulator/mjpeg?udid=fixture&fps=30", method: .get))
                    try await second.executeAndDontWaitForResponse(.init("/web/ios-simulator/mjpeg?udid=fixture&fps=30", method: .get))
                    let started = try await waitForIOSCapture(trace, starts: 2, stops: 0)
                    #expect(started.starts == 2)
                    try await first.close(mode: .all)
                    let remaining = try await waitForIOSCapture(trace, starts: 2, stops: 1)
                    #expect(remaining.starts == 2, "\(remaining.events)")
                    #expect(remaining.stops == 1, "\(remaining.events)")
                    #expect(remaining.active == 1, "\(remaining.events)")
                    if remaining.stops != 1 { trace.publishFrame() }
                    try await second.close(mode: .all)
                    let released = try await waitForIOSCapture(trace, starts: 2, stops: 2)
                    #expect(released.stops == 2)
                    trace.finishFixture()
                }
            }
        }
        let finished = trace.snapshot
        #expect(finished.starts == 2)
        #expect(finished.stops == 2)
        #expect(finished.active == 0)
    }
}

private func makeIOSFixtureRouter(_ trace: PackagedIOSCaptureTrace) -> Router<BasicRequestContext> {
    makePackagedWebRouter(webRoot: "/nonexistent/unused-web-fixture", tritonBin: "/fixture/triton", dependencies: .init(iosFramebuffer: trace.dependencies))
}

private func waitForIOSCapture(_ trace: PackagedIOSCaptureTrace, starts: Int, stops: Int) async throws -> PackagedIOSCaptureTrace.Snapshot {
    for _ in 0..<100 {
        let snapshot = trace.snapshot
        if snapshot.starts == starts, snapshot.stops == stops { return snapshot }
        try await Task.sleep(for: .milliseconds(10))
    }
    return trace.snapshot
}

private final class PackagedIOSCaptureTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var startCount = 0
    private var stopCount = 0
    private var currentFrame: Data?
    private var fixtureRunning = true
    private var events: [String] = []
    let canStart: Bool
    init(canStart: Bool = true) { self.canStart = canStart }
    var starts: Int { lock.withLock { startCount } }
    var stops: Int { lock.withLock { stopCount } }
    struct Snapshot {
        let starts: Int
        let stops: Int
        let active: Int
        let events: [String]
    }
    var snapshot: Snapshot {
        lock.withLock { Snapshot(starts: startCount, stops: stopCount, active: startCount - stopCount, events: events) }
    }
    func finishFixture() { lock.withLock { fixtureRunning = false } }
    func publishFrame() { lock.withLock { currentFrame = Data([0xff, 0xd8, 0xff, 0xd9]) } }
    var dependencies: PackagedWebIOSFramebufferDependencies {
        .init(validateCapture: { _ in }, start: { [self] _ in
            lock.withLock { startCount += 1; events.append("start: \(startCount), stop: \(stopCount)") }
            return canStart
        }, stop: { [self] _ in
            lock.withLock { stopCount += 1; events.append("start: \(startCount), stop: \(stopCount)") }
        }, running: { [self] _ in
            lock.withLock { fixtureRunning }
        }, frame: { [self] _ in
            lock.withLock { currentFrame.map { ($0, 1) } }
        })
    }
}
