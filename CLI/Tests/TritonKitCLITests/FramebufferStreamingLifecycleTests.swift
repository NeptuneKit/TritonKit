import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
@testable import TritonKitCLI

@Suite(.serialized)
struct FramebufferStreamingLifecycleTests {
    @Test func responseWithoutBodyExecutionDoesNotAcquireCapture() {
        let factory = CaptureFactory()
        let registry = FramebufferStreamRegistry()
        let request = Request(head: .init(method: .get, scheme: "http", authority: "localhost", path: "/"), body: .init(buffer: ByteBuffer()))
        let response = framebufferStreamingResponse(request: request, framesPerSecond: 30) {
            registry.subscribe(target: "test", makeSession: factory.make)
        }
        #expect(response.status == .ok)
        #expect(factory.sessions.isEmpty)
        withExtendedLifetime(response) {}
    }

    @Test func terminalCaptureNeedsExplicitFreshSubscriptionAndOldCleanupCannotStopIt() {
        let factory = CaptureFactory()
        let registry = FramebufferStreamRegistry()
        let old = registry.subscribe(target: "test", makeSession: factory.make)
        let oldSession = factory.sessions[0]
        oldSession.stop()
        #expect(oldSession.starts == 1)
        let current = registry.subscribe(target: "test", makeSession: factory.make)
        defer { current.cancel() }
        #expect(factory.sessions.count == 2)
        #expect(current.session !== old.session)
        #expect(current.session.running)
        old.cancel()
        old.cancel()
        #expect(current.session.running)
        #expect(oldSession.starts == 1)
    }

    @Test func independentSubscribersShareCaptureUntilLastRelease() {
        let factory = CaptureFactory()
        let registry = FramebufferStreamRegistry()
        let first = registry.subscribe(target: "test", makeSession: factory.make)
        let second = registry.subscribe(target: "test", makeSession: factory.make)
        #expect(factory.sessions.count == 1)
        #expect(first.session === second.session)
        first.cancel()
        first.cancel()
        #expect(second.session.running)
        second.cancel()
        #expect(!second.session.running)
        #expect(factory.sessions[0].stops == 1)
        let resumed = registry.subscribe(target: "test", makeSession: factory.make)
        defer { resumed.cancel() }
        #expect(factory.sessions.count == 2)
        #expect(resumed.session !== second.session)
    }

    @Test(arguments: ["android", "harmony"])
    func platformServiceReplacesTerminalHelperOnExplicitSubscription(platform: String) async throws {
        let subscribe: () -> FramebufferStreamSubscription
        if platform == "android" {
            let service = CLIAndroidFramebufferService()
            subscribe = { service.subscribe(serial: "fixture", adbPath: "/nonexistent/triton-test-adb") }
        } else {
            let service = CLIHarmonyFramebufferService()
            subscribe = { service.subscribe(target: "fixture", hdcPath: "/nonexistent/triton-test-hdc") }
        }
        let old = subscribe()
        defer { old.cancel() }
        try await waitFor { !old.session.running }
        let fresh = subscribe()
        defer { fresh.cancel() }
        #expect(fresh.session !== old.session)
        #expect(!old.session.running)
    }

    @Test func terminalCaptureFinishesHTTPResponseWithoutAFrame() async throws {
        let factory = CaptureFactory()
        let registry = FramebufferStreamRegistry()
        let router = Router()
        router.get("/") { request, _ in
            framebufferStreamingResponse(request: request, framesPerSecond: 30) {
                registry.subscribe(target: "test", makeSession: factory.make)
            }
        }
        try await Application(router: router).test(.live) { server in
            let port = try #require(server.port)
            try await TestClient.withClient(host: "localhost", port: port) { client in
                let responseTask = Task { try await client.get("/") }
                try await waitFor { factory.sessions.count == 1 }
                let session = try #require(factory.sessions.first)
                session.stop()
                let released = try await becomesTrue { session.stops == 2 }
                #expect(released, "A terminal capture must finish its HTTP body and release its subscription")
                if !released {
                    try await client.close(mode: .all)
                    session.publishFrame()
                }
                let response = try await responseTask.value
                #expect(response.head.status == .ok)
                #expect(response.body?.readableBytes ?? 0 == 0)
                #expect(factory.sessions.count == 1, "The body must not automatically relaunch a terminal helper")
            }
        }
    }

    @Test func disconnectBeforeFirstFrameReleasesCapture() async throws {
        let factory = CaptureFactory()
        let registry = FramebufferStreamRegistry()
        let router = Router()
        router.get("/") { request, _ in
            framebufferStreamingResponse(request: request, framesPerSecond: 30) {
                registry.subscribe(target: "test", makeSession: factory.make)
            }
        }
        try await Application(router: router).test(.live) { server in
            let port = try #require(server.port)
            try await TestClient.withClient(host: "localhost", port: port) { client in
                try await client.executeAndDontWaitForResponse(.init("/", method: .get))
                try await waitFor { factory.sessions.count == 1 }
                let session = try #require(factory.sessions.first)
                try await client.close(mode: .all)
                let released = try await becomesTrue { !session.running }
                #expect(released, "Client close must cancel capture even when no frame has been produced")
                // Bound teardown on the pre-fix implementation: a write observes the closed socket.
                session.publishFrame()
            }
        }
        #expect(factory.sessions.first?.stops == 1)
    }
}

private func becomesTrue(_ condition: () -> Bool) async throws -> Bool {
    for _ in 0..<100 {
        if condition() { return true }
        try await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

private func waitFor(_ condition: () -> Bool) async throws {
    let result = try await becomesTrue(condition)
    #expect(result)
}

private final class CaptureFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var captures: [FakeCaptureSession] = []
    var sessions: [FakeCaptureSession] { lock.withLock { captures } }
    func make() -> any FramebufferCaptureSession {
        lock.withLock {
            let capture = FakeCaptureSession()
            captures.append(capture)
            return capture
        }
    }
}

private final class FakeCaptureSession: FramebufferCaptureSession, @unchecked Sendable {
    private let lock = NSLock()
    private var isRunning = false
    private var startCount = 0
    private var stopCount = 0
    private var frame: Data?
    var running: Bool { lock.withLock { isRunning } }
    var starts: Int { lock.withLock { startCount } }
    var stops: Int { lock.withLock { stopCount } }
    func start() { lock.withLock { startCount += 1; isRunning = true } }
    func stop() { lock.withLock { stopCount += 1; isRunning = false } }
    func publishFrame() { lock.withLock { frame = Data([0xff, 0xd8, 0xff, 0xd9]) } }
    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        lock.withLock { frame.map { ($0, 1) } }
    }
}
