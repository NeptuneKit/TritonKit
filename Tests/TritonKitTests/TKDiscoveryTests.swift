import Foundation
import Testing
@testable import TritonKit

@Suite(.serialized)
struct TKDiscoveryTests {
    @Test("explicit host skips discovery even when Bonjour is requested")
    func explicitHostPrecedence() {
        for (environment, bundle, expected) in [
            (["TRITON_HOST": "chosen.local", "TRITON_DISCOVERY": "bonjour"], [String: Any](), "chosen.local"),
            (["TRITON_DISCOVERY": "bonjour"], ["TritonKitDefaultHost": "bundled.local"], "bundled.local"),
        ] {
            var calls = 0
            let payload = TritonKitStartPayload.environment(environment, bundleInfo: bundle, bonjourResolver: {
                calls += 1
                return .device("unexpected.local")
            })
            #expect(calls == 0)
            #expect(payload.host == expected)
            #expect(payload.discovery == nil)
        }
    }

    @Test("discovery environment opt-in is explicit and invalid settings fail closed")
    func environmentConfiguration() {
        let invalidValues = ["", "automatic", "true", "1"]
        for value in invalidValues {
            var calls = 0
            let payload = TritonKitStartPayload.environment(["TRITON_DISCOVERY": value], bundleInfo: nil, bonjourResolver: {
                calls += 1
                return .device("unexpected.local")
            })
            #expect(calls == 0)
            #expect(payload.discovery?.status == .invalidConfiguration)
        }
        for timeout in ["0", "-1", "nan", "inf", "5.01", "invalid", ""] {
            var calls = 0
            let payload = TritonKitStartPayload.environment([
                "TRITON_DISCOVERY": "bonjour", "TRITON_DISCOVERY_TIMEOUT_SECONDS": timeout,
            ], bundleInfo: nil, bonjourResolver: {
                calls += 1
                return .device("unexpected.local")
            })
            #expect(calls == 0)
            #expect(payload.discovery?.status == .invalidConfiguration)
        }
        var calls = 0
        let payload = TritonKitStartPayload.environment([
            "TRITON_DISCOVERY": "bonjour", "TRITON_DISCOVERY_TIMEOUT_SECONDS": "0.25",
        ], bundleInfo: nil, bonjourResolver: {
            calls += 1
            return .device("candidate.local")
        })
        #if TRITONKIT_RUNTIME_ENABLED
        #expect(calls == 1)
        #expect(payload.host == "candidate.local")
        #expect(payload.discovery?.status == .candidate)
        #expect(payload.discovery?.candidates.first?.isAuthenticated == false)
        #else
        #expect(calls == 0)
        #expect(payload.discovery?.status == .runtimeDisabled)
        #endif
    }

    @Test("explicit disabled policy overrides environment Bonjour opt-in")
    func disabledPolicyWins() {
        var calls = 0
        let payload = TritonKitStartPayload.environment(["TRITON_DISCOVERY": "bonjour"], bundleInfo: nil, discoveryPolicy: .disabled, bonjourResolver: {
            calls += 1
            return .device("unexpected.local")
        })
        #expect(calls == 0)
        #expect(payload.host == "127.0.0.1")
        #expect(payload.discovery == nil)
    }

    @Test("single resolved service is a candidate only after the entire window")
    func singleCandidateWaitsForWindow() {
        let driver = FakeDiscoveryDriver(events: [
            [.found(id: "one", name: "one"), .resolved(id: "one", host: "candidate.local.", port: 19421, publicID: "forged-trusted-id")],
            [], [], [],
        ])
        let result = run(driver)
        #if TRITONKIT_RUNTIME_ENABLED
        #expect(driver.pollCount == 4)
        #expect(driver.stopped)
        #expect(result.status == .candidate)
        #expect(result.candidates.first?.host == "candidate.local")
        #expect(result.candidates.first?.publicID == "forged-trusted-id")
        #expect(result.candidates.first?.isAuthenticated == false)
        #else
        #expect(driver.pollCount == 0)
        #expect(!driver.started)
        #expect(result.status == .runtimeDisabled)
        #endif
    }

    @Test("late or unresolved second service prevents selecting the first")
    func ambiguousCandidates() {
        for second in [
            [TritonKitDiscoveryEvent.found(id: "two", name: "two")],
            [.found(id: "two", name: "two"), .resolved(id: "two", host: "candidate.local", port: 19421, publicID: "same-id")],
            [.found(id: "two", name: "two"), .removed(id: "two")],
        ] {
            let driver = FakeDiscoveryDriver(events: [
                [.found(id: "one", name: "one"), .resolved(id: "one", host: "candidate.local", port: 19421, publicID: "same-id")],
                [], [], second,
            ])
            let result = run(driver)
            #if TRITONKIT_RUNTIME_ENABLED
            #expect(result.status == .ambiguous)
            #expect(result.candidates.count == 2)
            #expect(result.endpoint == nil)
            #expect(result.candidates.allSatisfy { !$0.isAuthenticated })
            #endif
        }
    }

    @Test("timeout unresolved removed and search failure never produce an endpoint")
    func failures() {
        let cases: [([TritonKitDiscoveryEvent], TritonKitDiscoveryResult.Status)] = [
            ([], .noCandidates),
            ([.found(id: "one", name: "one")], .unresolved),
            ([.found(id: "one", name: "one"), .resolutionFailed(id: "one")], .unresolved),
            ([.found(id: "one", name: "one"), .resolved(id: "one", host: "candidate.local", port: 19421, publicID: nil), .removed(id: "one")], .unresolved),
            ([.found(id: "one", name: "one"), .removed(id: "one"), .resolutionFailed(id: "one"), .resolved(id: "one", host: "candidate.local", port: 19421, publicID: nil)], .unresolved),
            ([.found(id: "one", name: "one"), .resolved(id: "one", host: "candidate.local", port: 0, publicID: nil)], .unresolved),
            ([.found(id: "one", name: "one"), .resolved(id: "one", host: "candidate.local", port: 19421, publicID: nil), .searchFailed], .failed),
        ]
        for (events, expected) in cases {
            let driver = FakeDiscoveryDriver(events: [events, [], [], []])
            let result = run(driver)
            #if TRITONKIT_RUNTIME_ENABLED
            #expect(result.status == expected)
            #expect(result.endpoint == nil)
            #expect(driver.stopped)
            #endif
        }
    }

    @Test("duplicate callbacks do not create ambiguity and candidate growth is bounded")
    func duplicateAndFlood() {
        let duplicate = FakeDiscoveryDriver(events: [[
            .found(id: "one", name: "one"), .found(id: "one", name: "one"),
            .resolved(id: "one", host: "candidate.local", port: 19421, publicID: nil),
        ], [], [], []])
        let duplicateResult = run(duplicate)
        let flood = FakeDiscoveryDriver(events: [(0..<65).map { .found(id: String($0), name: String($0)) }])
        let floodResult = run(flood)
        #if TRITONKIT_RUNTIME_ENABLED
        #expect(duplicateResult.status == .candidate)
        #expect(duplicateResult.candidates.count == 1)
        #expect(floodResult.status == .failed)
        #expect(floodResult.candidates.count == 64)
        #expect(floodResult.endpoint == nil)
        #expect(flood.stopped)
        #endif
    }

    @Test("invalid direct timeout never creates a browser")
    func invalidTimeout() {
        for timeout in [0.0, -1.0, .nan, .infinity, 5.01] {
            var factories = 0
            let result = TritonKitBonjourDiscovery.resolve(timeout: timeout, driverFactory: {
                factories += 1
                return FakeDiscoveryDriver(events: [])
            })
            #expect(factories == 0)
            #expect(result.status == .invalidConfiguration)
        }
    }

    private func run(_ driver: FakeDiscoveryDriver) -> TritonKitDiscoveryResult {
        TritonKitBonjourDiscovery.resolve(timeout: 0.08, driverFactory: { driver }, now: { driver.clock })
    }
}

private final class FakeDiscoveryDriver: TritonKitDiscoveryDriver {
    var event: ((TritonKitDiscoveryEvent) -> Void)?
    let events: [[TritonKitDiscoveryEvent]]
    var clock = 0.0
    var started = false
    var stopped = false
    var pollCount = 0

    init(events: [[TritonKitDiscoveryEvent]]) { self.events = events }
    func start(timeout: TimeInterval) { started = true }
    func poll(until deadline: TimeInterval) {
        if pollCount < events.count { events[pollCount].forEach { event?($0) } }
        pollCount += 1
        clock = deadline
    }
    func stop() { stopped = true }
}

extension TKPlatformFallbackTests {
    @Test("failed opt-in cannot fall back into a connection attempt")
    func failedDiscoveryBlocksStart() {
        let payload = TritonKitStartPayload.environment([:], bundleInfo: nil, discoveryPolicy: .bonjour(timeout: 0.15), bonjourResolver: { nil })
        let kit = TritonKit.shared
        let original = kit.endpointReadinessProbe
        var probes = 0
        kit.endpointReadinessProbe = { _, _, _ in probes += 1; return false }
        var observed: [TritonKitDiscoveryResult.Status] = []
        let token = kit.onError { error in
            if case let TritonKitRuntimeError.discoveryRejected(status) = error { observed.append(status) }
        }
        defer { token.cancel(); kit.stop(); kit.endpointReadinessProbe = original }
        var configuration = TritonKit.Configuration(endpoint: payload, autoReconnect: false)
        configuration.features.insert(.inspector)
        configuration.picker = .init(enabled: true)
        #expect(!kit.start(configuration))
        #if canImport(UIKit)
        #expect(!kit.pickerStorage.isEnabled)
        #endif
        #if TRITONKIT_RUNTIME_ENABLED
        #expect(observed == [.noCandidates])
        #endif
        #expect(probes == 0)
        #expect(kit.state == .disconnected)
    }

    @Test("Release explicit Bonjour and default bootstrap do not start discovery or transport")
    func releaseNoOp() {
        #if !TRITONKIT_RUNTIME_ENABLED
        let direct = TritonKitStartPayload.bonjourDiscovery(timeout: 0.15)
        #expect(direct.status == .runtimeDisabled)
        #expect(TritonKitStartPayload.bonjour(timeout: 0.15) == nil)
        let kit = TritonKit.shared
        let original = kit.endpointReadinessProbe
        var probes = 0
        kit.endpointReadinessProbe = { _, _, _ in probes += 1; return false }
        defer { kit.stop(); kit.endpointReadinessProbe = original }
        #expect(!kit.start())
        #expect(!kit.start(TritonKit.Configuration()))
        #expect(probes == 0)
        #expect(kit.state == .disconnected)
        #endif
    }

}

#if TRITONKIT_RUNTIME_ENABLED && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS))
extension TKDiscoveryTests {
    @Test("real isolated Bonjour services with forged identical IDs remain ambiguous", .enabled(if: ProcessInfo.processInfo.environment["TRITON_TEST_BONJOUR"] == "1"))
    func realBonjourAmbiguity() throws {
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        let serviceType = "_sp203-\(suffix)._tcp."
        let publishers = ["candidate-a", "candidate-b"].map {
            IsolatedBonjourPublisher(serviceType: serviceType, name: $0)
        }
        defer {
            publishers.forEach { $0.service.stop() }
            pump(until: { publishers.allSatisfy { $0.stopped } }, timeout: 1)
            #expect(publishers.allSatisfy { $0.stopped })
            publishers.forEach { $0.service.delegate = nil }
            print("SP203 Bonjour cleanup: stopped=\(publishers.filter(\.stopped).count)/2 type=\(serviceType)")
        }
        publishers.forEach { $0.service.publish() }
        pump(until: { publishers.allSatisfy { $0.published } || publishers.contains(where: { $0.failed }) }, timeout: 3)
        try #require(publishers.allSatisfy { $0.published }, "Both isolated records must receive the real publish callback")

        let result = TritonKitBonjourDiscovery.resolve(timeout: 1.5, driverFactory: {
            TritonKitBonjourDriver(serviceType: serviceType)
        })
        #expect(result.status == .ambiguous)
        #expect(result.endpoint == nil)
        #expect(result.candidates.count == 2)
        #expect(result.candidates.allSatisfy { $0.publicID == "forged-same-public-id" && !$0.isAuthenticated })
        print("SP203 Bonjour integration: status=\(result.status.rawValue) candidates=\(result.candidates.count) authenticated=\(result.isAuthenticated) type=\(serviceType)")

        let absent = TritonKitBonjourDiscovery.resolve(timeout: 0.1, driverFactory: {
            TritonKitBonjourDriver(serviceType: "_sp203z\(suffix)._tcp.")
        })
        #expect(absent.status == .noCandidates)
        #expect(absent.endpoint == nil)
    }

    private func pump(until finished: () -> Bool, timeout: TimeInterval) {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while !finished() && ProcessInfo.processInfo.systemUptime < deadline {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }
}

private final class IsolatedBonjourPublisher: NSObject, NetServiceDelegate {
    let service: NetService
    var published = false
    var failed = false
    var stopped = false

    init(serviceType: String, name: String) {
        // Advertise metadata only; never bind or connect a TCP socket.
        service = NetService(domain: "local.", type: serviceType, name: name, port: 9)
        super.init()
        service.delegate = self
        service.setTXTRecord(NetService.data(fromTXTRecord: ["id": Data("forged-same-public-id".utf8)]))
    }

    func netServiceDidPublish(_ sender: NetService) { published = true }
    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) { failed = true }
    func netServiceDidStop(_ sender: NetService) { stopped = true }
}
#endif
