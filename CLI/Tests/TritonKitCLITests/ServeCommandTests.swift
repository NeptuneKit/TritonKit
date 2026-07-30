import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct ServeCommandTests {
    @Test("0.2.15 legacy runtime manifest is accepted without a registration frame")
    func legacyRuntimeManifestIsAccepted() throws {
        let fixture = try #require("""
        {
          "ok": true,
          "platform": "ios",
          "runtime": "embedded",
          "transport": "embedded-websocket",
          "enabled": true,
          "sdkVersion": "0.1.0-dev",
          "buildConfiguration": "debug",
          "capabilities": [],
          "semanticDomains": [],
          "limits": {"maxSnapshotBytes": 1, "maxAXNodes": 1, "maxLedgerEntries": 1},
          "redaction": {
            "secureText": "length-only",
            "clipboard": "not-collected",
            "network": "opt-in-only",
            "logs": "opt-in-only",
            "fileArtifacts": "opt-in-only"
          }
        }
        """.data(using: .utf8))

        let decision = runtimeRegistrationDecision(manifestPayload: fixture)

        #expect(decision.accepted)
        #expect(decision.state == "accepted")
        #expect(decision.code == "legacy_runtime_manifest_accepted")
        #expect(decision.sdkVersion == "0.1.0-dev")
        #expect(decision.versionSource == "runtime-manifest-unverified-release")
        #expect(decision.reason.contains("registration frame"))
    }

    @Test("legacy runtime remains accepted when runtimeManifest is unanswered")
    func legacyRuntimeWithoutManifestResponseRemainsAccepted() {
        let target = TargetState()

        #expect(target.registrationDecision.accepted)
        #expect(target.registrationDecision.code == "legacy_websocket_accepted")
        #expect(target.registrationDecision.sdkVersion == nil)
    }

    @Test("malformed runtime registration has a stable machine-readable refusal")
    func malformedRuntimeManifestIsRejected() {
        let decision = runtimeRegistrationDecision(manifestPayload: Data("{}".utf8))

        #expect(!decision.accepted)
        #expect(decision.state == "rejected")
        #expect(decision.code == "runtime_manifest_invalid")
        #expect(decision.reason.contains("TKRuntimeManifestResponse"))
    }

    @Test("registration endpoint model explains an unobservable app process")
    func emptyRegistrationResponseIsMachineReadable() throws {
        let response = RuntimeRegistrationResponse(registrations: [])
        let payload = try JSONEncoder().encode(response)
        let json = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])

        #expect(!response.ok)
        #expect(response.code == "runtime_registration_unobserved")
        #expect(response.reason.contains("cannot determine whether an app process launched"))
        #expect(json["code"] as? String == "runtime_registration_unobserved")
        #expect((json["registrations"] as? [Any])?.isEmpty == true)
    }

    @Test("serve parser defaults to loopback without starting the server")
    func parserDefaultsToLoopbackWithoutStartingTheServer() throws {
        let command = try Serve.parse([])

        #expect(command.host == "127.0.0.1")
        #expect(command.port == 19421)
    }

    @Test("serve parser preserves an explicit non-loopback host")
    func parserPreservesExplicitNonLoopbackHost() throws {
        let command = try Serve.parse([
            "--host", "0.0.0.0",
            "--port", "19421",
        ])

        #expect(command.host == "0.0.0.0")
        #expect(command.port == 19421)
    }

    @Test("Chinese serve help describes the loopback default")
    func chineseServeHelpDescribesLoopbackDefault() throws {
        let help = try #require(chineseCommandHelps()["serve"])
        let hostOption = try #require(help.options.first { $0.0 == "--host <host>" })

        #expect(hostOption.1.contains("默认 127.0.0.1"))
        #expect(!hostOption.1.contains("0.0.0.0"))
    }

    @Test("serve schema describes the loopback default")
    func serveSchemaDescribesLoopbackDefault() throws {
        let response = try buildSchemaResponse(command: "serve")
        let serve = try #require(response.commands.first)
        let hostOption = try #require(serve.options.first { $0.name == "--host" })
        let portOption = try #require(serve.options.first { $0.name == "--port" })

        #expect(hostOption.defaultValue == "127.0.0.1")
        #expect(portOption.defaultValue == "19421")
        #expect(serve.examples.contains("triton serve --host 127.0.0.1 --port 19421"))
    }

    @Test("server recovery action uses the loopback default")
    func serverRecoveryActionUsesLoopbackDefault() throws {
        let action = try #require(runtimeCapabilityNextAction(
            for: "status",
            host: "127.0.0.1",
            port: 19421,
            serverReachable: false,
            connected: false
        ))

        #expect(action.command == "serve")
        #expect(action.args == ["--host", "127.0.0.1", "--port", "19421"])
        #expect(action.requiresLongRunningProcess)
    }

    @Test("server recovery action preserves an explicit non-loopback host")
    func serverRecoveryActionPreservesExplicitNonLoopbackHost() throws {
        let action = try #require(runtimeCapabilityNextAction(
            for: "status",
            host: "192.168.1.20",
            port: 19421,
            serverReachable: false,
            connected: false
        ))

        #expect(action.args == ["--host", "192.168.1.20", "--port", "19421"])
    }

    @Test("doctor no-target diagnosis does not assume the app was never launched")
    func doctorNoTargetExplainsUnobservableAppState() throws {
        let response = buildDoctorResponse(
            capabilities: TKCapabilitiesResponse(
                ok: false,
                serverReachable: true,
                connected: false,
                latestHierarchyAvailable: false,
                targetCount: 0,
                runtime: "none",
                capabilities: runtimeCapabilities(
                    host: "127.0.0.1",
                    port: 19421,
                    serverReachable: true,
                    connected: false
                ),
                error: TKCLIErrorDetail(code: "target_unavailable", message: "No target")
            ),
            host: "127.0.0.1",
            port: 19421
        )

        let connection = try #require(response.checks.first { $0.id == "runtime-connection" })
        #expect(connection.status == "fail")
        #expect(connection.code == "runtime_registration_unobserved")
        #expect(connection.message.contains("cannot determine whether the app process launched"))
        #expect(connection.hint?.contains("DEBUG bootstrap") == true)
        #expect(connection.nextAction?.command == "target")
        #expect(connection.nextAction?.args == ["list", "--json"])
        #expect(response.checks.contains { $0.id == "host-device" })
    }
}
