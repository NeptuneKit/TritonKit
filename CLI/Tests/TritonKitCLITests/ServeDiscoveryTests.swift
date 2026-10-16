import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct ServeDiscoveryTests {
    @Test("Disabled publisher never enters publishing")
    func disabledPublisher() {
        let publisher = TritonBonjourPublisher(wanted: false, port: 19421)
        publisher.start()
        #expect(publisher.snapshot == TKDiscoveryStatus(wanted: false, state: "stopped"))
        publisher.stop()
    }

    @Test("HTTP status exposes callback state without claiming peer trust")
    func httpStatus() async throws {
        let publisher = TritonBonjourPublisher(wanted: true, port: 19421)
        let router = Router(context: BasicRequestContext.self)
        registerTritonStatusRoute(on: router, state: ConnectionState(), publisher: publisher)
        try await Application(router: router).test(.router) { client in
            let service = NetService(domain: "local.", type: "_sp203-test._tcp.", name: "fixture", port: 19421)
            for state in ["wanted", "publishing", "advertising", "failed", "stopped"] {
                switch state {
                case "publishing": publisher.begin(service)
                case "advertising": publisher.netServiceDidPublish(service)
                case "failed": publisher.netService(service, didNotPublish: [NetService.errorCode: -72001])
                case "stopped":
                    publisher.stop()
                    publisher.netServiceDidStop(service)
                default: break
                }
                let response = try await client.execute(uri: "/status", method: .get)
                #expect(response.status == .ok)
                let value = try JSONDecoder().decode(TKStatusResponse.self, from: Data(buffer: response.body))
                #expect(value.discovery?.state == state)
                #expect(value.discovery?.wanted == true)
                #expect(value.discovery?.identityVerified == false)
                #expect(value.connected == false)
            }
        }
    }

    @Test("An untrusted status response cannot promote discovery to verified identity")
    func forgedIdentityClaim() throws {
        let forged = Data(#"{"wanted":true,"state":"advertising","serviceType":"_tritonkit-server._tcp.","identityVerified":true}"#.utf8)
        let status = try JSONDecoder().decode(TKDiscoveryStatus.self, from: forged)
        #expect(status.identityVerified == false)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(status)) as? [String: Any])
        #expect(encoded["identityVerified"] as? Bool == false)
    }

    @Test("Old status responses remain readable and new snapshots round trip")
    func statusCompatibility() throws {
        let oldHTTP = Data(#"{"connected":false,"latestHierarchyAvailable":false,"targetCount":0}"#.utf8)
        #expect(try JSONDecoder().decode(TKStatusResponse.self, from: oldHTTP).discovery == nil)
        let oldCLI = Data(#"{"ok":true,"serverReachable":true,"connected":false,"latestHierarchyAvailable":false,"targetCount":0,"runtime":"none"}"#.utf8)
        #expect(try JSONDecoder().decode(TKCLIStatusEnvelope.self, from: oldCLI).discovery == nil)
        let value = TKCLIStatusEnvelope(ok: true, serverReachable: true, connected: false,
            latestHierarchyAvailable: false, targetCount: 0, runtime: "none",
            discovery: TKDiscoveryStatus(wanted: true, state: "failed", errorCode: -72001))
        #expect(try JSONDecoder().decode(TKCLIStatusEnvelope.self, from: JSONEncoder().encode(value)) == value)
    }

    @Test("Real NetService rejects an invalid service type and preserves failure", .enabled(if: ProcessInfo.processInfo.environment["TRITON_TEST_BONJOUR"] == "1"))
    func realPublicationFailure() async throws {
        // Invalid DNS-SD type cannot create an advertisement on the LAN.
        let publisher = TritonBonjourPublisher(wanted: true, port: 19421, serviceType: "invalid", name: "sp203-negative")
        defer { publisher.stop() }
        for _ in 0..<2 {
            publisher.start()
            let deadline = Date().addingTimeInterval(3)
            while publisher.snapshot.state != "failed", Date() < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(publisher.snapshot.state == "failed")
            #expect(publisher.snapshot.errorCode == -72004)
            #expect(publisher.snapshot.identityVerified == false)
        }
        publisher.stop()
        #expect(publisher.snapshot.state == "stopped")
    }

    @Test("Real NetService publishes and withdraws only its own isolated service", .enabled(if: ProcessInfo.processInfo.environment["TRITON_TEST_BONJOUR"] == "1"))
    func realPublicationLifecycle() async throws {
        // Test-only type; does not attract production Triton SDK browsers or expose a listener.
        let publisher = TritonBonjourPublisher(wanted: true, port: 9, serviceType: "_sp203-test._tcp.", name: "sp203-\(UUID().uuidString)")
        defer { publisher.stop() }
        for _ in 0..<2 {
            publisher.start()
            let deadline = Date().addingTimeInterval(4)
            while ["wanted", "stopped", "publishing"].contains(publisher.snapshot.state), Date() < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(publisher.snapshot.state == "advertising")
            #expect(publisher.snapshot.identityVerified == false)
            publisher.stop()
            #expect(publisher.snapshot.state == "stopped")
        }
    }
}
