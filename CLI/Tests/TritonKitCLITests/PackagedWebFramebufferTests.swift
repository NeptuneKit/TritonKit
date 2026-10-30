import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct PackagedWebFramebufferTests {
    @Test(arguments: ["android", "harmony"], ["udid", "serial", "target", "host"])
    func packagedRouterServesMultipartInsteadOfMissingRoute(platform: String, selector: String) async throws {
        let fixture = try PackagedFramebufferFixture()
        defer { fixture.remove() }
        let app = Application(router: fixture.router())
        try await app.test(.live) { client in
            let query = selector == "host" ? "target=host:\(platform):fixture-target" : "\(selector)=fixture-target"
            let response = try await client.execute(uri: "/web/\(platform)/mjpeg?\(query)&fps=5", method: .get)
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "multipart/x-mixed-replace; boundary=tritonboundary")
            #expect(String(buffer: response.body).contains("Content-Type: image/jpeg"))
        }
        #expect(fixture.trace.subscriptions == ["\(platform):fixture-target:/fixture/sdk/\(platform == "android" ? "adb" : "hdc")"])
        #expect(fixture.trace.stops == 1)
    }

    @Test(arguments: ["android", "harmony"])
    func invalidPreviewQueriesReturnJSONWithoutAcquiringCapture(platform: String) async throws {
        let fixture = try PackagedFramebufferFixture()
        defer { fixture.remove() }
        try await Application(router: fixture.router()).test(.router) { client in
            for query in ["", "?udid=%20%20", "?target=host:ios:wrong", "?target=fixture&fps=nan", "?target=fixture&fps=1.5"] {
                let response = try await client.execute(uri: "/web/\(platform)/mjpeg\(query)", method: .get)
                #expect(response.status == .badRequest)
                #expect(response.headers[.contentType]?.contains("application/json") == true)
            }
        }
        #expect(fixture.trace.subscriptions.isEmpty)
    }

    @Test func frameRatesKeepPlatformDefaultsAndClampBounds() throws {
        for platform in [HostDevicePlatform.android, .harmony] {
            let request: (String?) throws -> PackagedWebFramebufferRequest = { fps in
                try makePackagedWebFramebufferRequest(platform: platform, target: nil, serial: nil, udid: "fixture", fps: fps)
            }
            #expect(try request(nil).fps == (platform == .android ? 15 : 10))
            #expect(try request("999").fps == (platform == .android ? 30 : 15))
            #expect(try request("0").fps == 1)
            #expect(try request("-1").fps == 1)
        }
    }

    @Test func registryUsesResolvedSDKToolsWithoutPATH() async throws {
        let fixture = try PackagedFramebufferFixture()
        defer { fixture.remove() }
        try await Application(router: fixture.router()).test(.router) { client in
            let response = try await client.execute(uri: "/web/target-registry", method: .get)
            #expect(response.status == .ok)
            let registry = try JSONDecoder().decode(TKWebTargetRegistryResponse.self, from: Data(buffer: response.body))
            #expect(Set(registry.targets.map(\.platform)) == ["android", "harmony"])
        }
        #expect(fixture.trace.discoveryTools == ["/fixture/sdk/hdc:/fixture/sdk/adb"])
    }

    @Test func packagedReadonlyRoutesKeepRejectingMalformedWrites() async throws {
        let fixture = try PackagedFramebufferFixture()
        defer { fixture.remove() }
        try await Application(router: fixture.router()).test(.router) { client in
            for endpoint in ["/web/host-input", "/web/node-property"] {
                let response = try await client.execute(uri: endpoint, method: .post, headers: [.contentType: "application/json"], body: ByteBuffer(string: "{invalid"))
                #expect(response.status == .methodNotAllowed)
                let error = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(buffer: response.body))
                #expect(error.error.endpoint == endpoint)
            }
            let ios = try await client.execute(uri: "/web/ios-simulator/mjpeg", method: .get)
            #expect(ios.status == .badRequest)
        }
    }
}

private struct PackagedFramebufferFixture: Sendable {
    let directory: URL
    let trace = PackagedFramebufferTrace()

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-packaged-framebuffer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "<html>packaged fixture</html>".write(to: directory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }

    func router() -> Router<BasicRequestContext> {
        let dependencies = PackagedWebDependencies(
            adbPath: "/fixture/sdk/adb", hdcPath: "/fixture/sdk/hdc",
            hostTargets: { hdc, adb in
                trace.recordDiscovery("\(hdc):\(adb)")
                guard hdc == "/fixture/sdk/hdc", adb == "/fixture/sdk/adb" else { return [] }
                return ["android", "harmony"].map { platform in
                    HostDeviceTarget(platform: platform, id: "\(platform):fixture", target: "fixture", state: "connected", ready: true, source: "fixture", name: nil, runtime: nil, transport: nil, scope: "emulator", kind: "emulator")
                }
            }, runtimeTargets: { [] }, resolveTarget: { _, target, _, _ in target },
            subscribeAndroid: { target, tool in trace.subscribe(platform: "android", target: target, tool: tool) },
            subscribeHarmony: { target, tool in trace.subscribe(platform: "harmony", target: target, tool: tool) }
        )
        return makePackagedWebRouter(webRoot: directory.path, tritonBin: "/fixture/triton", dependencies: dependencies)
    }
}

private final class PackagedFramebufferTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var acquired: [String] = []
    private var discovered: [String] = []
    private var stopped = 0
    var subscriptions: [String] { lock.withLock { acquired } }
    var discoveryTools: [String] { lock.withLock { discovered } }
    var stops: Int { lock.withLock { stopped } }
    func recordDiscovery(_ value: String) { lock.withLock { discovered.append(value) } }
    func subscribe(platform: String, target: String, tool: String) -> FramebufferStreamSubscription {
        lock.withLock { acquired.append("\(platform):\(target):\(tool)") }
        let session = PackagedSingleFrameCapture()
        session.start()
        return FramebufferStreamSubscription(session: session) { [self] in
            session.stop()
            lock.withLock { stopped += 1 }
        }
    }
}

private final class PackagedSingleFrameCapture: FramebufferCaptureSession, @unchecked Sendable {
    private let lock = NSLock()
    private var active = false
    var running: Bool { lock.withLock { active } }
    func start() { lock.withLock { active = true } }
    func stop() { lock.withLock { active = false } }
    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        lock.withLock {
            active = false
            return (Data([0xff, 0xd8, 0xff, 0xd9]), 1)
        }
    }
}
