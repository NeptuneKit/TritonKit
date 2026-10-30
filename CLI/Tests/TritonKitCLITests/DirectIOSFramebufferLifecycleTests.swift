import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct DirectIOSFramebufferLifecycleTests {
    @Test func unusedResponseReleasesEagerCapture() {
        let trace = DirectIOSCaptureTrace()
        do {
            let request = Request(head: .init(method: .get, scheme: "http", authority: "localhost", path: "/web/ios-simulator/framebuffer?udid=fixture"), body: .init(buffer: ByteBuffer()))
            let response = makeDirectIOSFramebufferResponse(request: request, capture: trace.dependencies)
            #expect(response.status == .ok)
            #expect(trace.snapshot.starts == 1)
            #expect(trace.snapshot.stops == 0)
            withExtendedLifetime(response) {}
        }
        #expect(trace.snapshot.stops == 1, "A failed HTTP head write never executes the body, but must release its eagerly started capture")
    }

    @Test func startupFailureKeepsDirectConflictContractAndNoRelease() async throws {
        let trace = DirectIOSCaptureTrace(canStart: false)
        try await Application(router: directIOSFixtureRouter(trace)).test(.router) { client in
            let response = try await client.execute(uri: "/web/ios-simulator/framebuffer?target=host:ios:fixture", method: .get)
            #expect(response.status == .conflict)
            let error = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(buffer: response.body))
            #expect(error.error.code == "web_ios_simulator_mjpeg_unavailable")
            #expect(error.error.message == "Framebuffer service did not start.")
            #expect(error.error.endpoint == "/web/ios-simulator/framebuffer")
        }
        #expect(trace.snapshot.starts == 1)
        #expect(trace.snapshot.targets == ["fixture"])
        #expect(trace.snapshot.stops == 0)
    }

    @Test func validationFailureDoesNotStartCapture() async throws {
        let trace = DirectIOSCaptureTrace(validationFails: true)
        try await Application(router: directIOSFixtureRouter(trace)).test(.router) { client in
            let response = try await client.execute(uri: "/web/ios-simulator/framebuffer?udid=fixture", method: .get)
            #expect(response.status == .conflict)
            let error = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(buffer: response.body))
            #expect(error.error.code == "ios_simulator_resize_capture_state_unknown")
            #expect(error.error.endpoint == "/web/ios-simulator/framebuffer")
        }
        #expect(trace.snapshot.starts == 0)
        #expect(trace.snapshot.stops == 0)
    }

    @Test func disconnectBeforeFirstFrameReleasesCapture() async throws {
        let trace = DirectIOSCaptureTrace()
        try await Application(router: directIOSFixtureRouter(trace)).test(.live) { server in
            let port = try #require(server.port)
            try await TestClient.withClient(host: "localhost", port: port) { client in
                try await client.executeAndDontWaitForResponse(.init("/web/ios-simulator/framebuffer?udid=fixture&fps=30", method: .get))
                #expect(try await awaitDirectCapture(trace, starts: 1, stops: 0))
                try await client.close(mode: .all)
                #expect(try await awaitDirectCapture(trace, starts: 1, stops: 1), "Disconnect must release the capture even before any frame exists")
                // Bound teardown for the pre-fix route: only a failed write observes close.
                trace.publishFrame()
            }
        }
        #expect(trace.snapshot.stops == 1)
    }

    @Test func terminalCaptureCompletesResponseAndReleasesOnce() async throws {
        let trace = DirectIOSCaptureTrace()
        try await Application(router: directIOSFixtureRouter(trace)).test(.live) { server in
            let port = try #require(server.port)
            try await TestClient.withClient(host: "localhost", port: port) { client in
                let responseTask = Task { try await client.get("/web/ios-simulator/framebuffer?udid=fixture&fps=30") }
                #expect(try await awaitDirectCapture(trace, starts: 1, stops: 0))
                trace.finishFixture()
                let completed = try await awaitDirectCapture(trace, starts: 1, stops: 1)
                #expect(completed, "A terminal capture must finish and release without waiting for a JPEG or client close")
                if completed {
                    let response = try await responseTask.value
                    #expect(response.head.status == .ok)
                    #expect(response.body?.readableBytes ?? 0 == 0)
                } else {
                    try await client.close(mode: .all)
                    trace.publishFrame()
                    _ = try? await responseTask.value
                }
            }
        }
        #expect(trace.snapshot.stops == 1)
    }

    @Test func closingOneSubscriberOnlyReleasesItsReference() async throws {
        let trace = DirectIOSCaptureTrace()
        try await Application(router: directIOSFixtureRouter(trace)).test(.live) { server in
            let port = try #require(server.port)
            try await TestClient.withClient(host: "localhost", port: port) { first in
                try await TestClient.withClient(host: "localhost", port: port) { second in
                    try await first.executeAndDontWaitForResponse(.init("/web/ios-simulator/framebuffer?udid=fixture&fps=30", method: .get))
                    try await second.executeAndDontWaitForResponse(.init("/web/ios-simulator/framebuffer?udid=fixture&fps=30", method: .get))
                    #expect(try await awaitDirectCapture(trace, starts: 2, stops: 0))
                    try await first.close(mode: .all)
                    let firstReleased = try await awaitDirectCapture(trace, starts: 2, stops: 1)
                    #expect(firstReleased)
                    if !firstReleased { trace.publishFrame() }
                    try await second.close(mode: .all)
                    #expect(try await awaitDirectCapture(trace, starts: 2, stops: 2))
                    trace.publishFrame()
                }
            }
        }
        #expect(trace.snapshot.starts == 2)
        #expect(trace.snapshot.stops == 2)
    }
}

private func directIOSFixtureRouter(_ trace: DirectIOSCaptureTrace) -> Router<BasicRequestContext> {
    let router = Router()
    registerDirectIOSFramebufferRoute(on: router, capture: trace.dependencies)
    return router
}

private func awaitDirectCapture(_ trace: DirectIOSCaptureTrace, starts: Int, stops: Int) async throws -> Bool {
    for _ in 0..<100 {
        let snapshot = trace.snapshot
        if snapshot.starts == starts, snapshot.stops == stops { return true }
        try await Task.sleep(for: .milliseconds(10))
    }
    let snapshot = trace.snapshot
    return snapshot.starts == starts && snapshot.stops == stops
}

private final class DirectIOSCaptureTrace: @unchecked Sendable {
    struct Snapshot { let starts: Int; let stops: Int; let targets: [String] }
    private let lock = NSLock()
    private var starts = 0
    private var stops = 0
    private var targets: [String] = []
    private var currentFrame: Data?
    private var running = true
    private let canStart: Bool
    private let validationFails: Bool
    init(canStart: Bool = true, validationFails: Bool = false) {
        self.canStart = canStart
        self.validationFails = validationFails
    }
    var snapshot: Snapshot { lock.withLock { Snapshot(starts: starts, stops: stops, targets: targets) } }
    func publishFrame() { lock.withLock { currentFrame = Data([0xff, 0xd8, 0xff, 0xd9]) } }
    func finishFixture() { lock.withLock { running = false } }
    var dependencies: PackagedWebIOSFramebufferDependencies {
        .init(validateCapture: { [self] _ in
            if validationFails { throw RuntimeError("fixture capture validation failure") }
        }, start: { [self] target in
            lock.withLock { starts += 1; targets.append(target) }
            return canStart
        }, stop: { [self] _ in
            lock.withLock { stops += 1 }
        }, running: { [self] _ in
            lock.withLock { running }
        }, frame: { [self] _ in
            lock.withLock { currentFrame.map { ($0, 1) } }
        })
    }
}
