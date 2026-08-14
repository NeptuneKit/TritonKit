import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Target lease CLI surface")
struct TargetLeaseCommandTests {
    private let udid = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"

    @Test("target lease acquire parses target, owner, TTL, and host options")
    func acquireParsesOptions() throws {
        let command = try TargetLeaseAcquire.parse([
            "--target", "sim:\(udid)",
            "--owner", "agent-a",
            "--ttl", "120",
            "--host", "127.0.0.1",
            "--port", "19421",
            "--json",
        ])

        #expect(command.target == "sim:\(udid)")
        #expect(command.owner == "agent-a")
        #expect(command.ttlSeconds == 120)
        #expect(command.host == "127.0.0.1")
        #expect(command.port == 19421)
    }

    @Test("target lease status parses a target")
    func statusParsesOptions() throws {
        let command = try TargetLeaseStatus.parse(["--target", udid])
        #expect(command.target == udid)
    }

    @Test("target lease release parses target and lease token")
    func releaseParsesOptions() throws {
        let command = try TargetLeaseRelease.parse(["--target", udid, "--lease", "lease-1"])
        #expect(command.target == udid)
        #expect(command.leaseID == "lease-1")
    }

    @Test("target lease takeover parses owner and confirm")
    func takeoverParsesOptions() throws {
        let command = try TargetLeaseTakeover.parse([
            "--target", udid,
            "--owner", "agent-b",
            "--ttl", "60",
            "--confirm",
        ])
        #expect(command.target == udid)
        #expect(command.owner == "agent-b")
        #expect(command.ttlSeconds == 60)
        #expect(command.confirm)
    }

    @Test("schema --command target.lease resolves the lease subcommand")
    func schemaTargetLeaseResolves() throws {
        let response = try buildSchemaResponse(command: "target.lease")
        let schema = try #require(response.commands.first)

        #expect(schema.name == "target")
        #expect(schema.subcommands.map(\.name).contains("lease"))
        let lease = try #require(schema.subcommands.first { $0.name == "lease" })
        #expect(lease.requiresServer)
        #expect(lease.failureCodes.contains("target_lease_conflict"))
        #expect(lease.outputSelectors.contains("target.lease"))
        #expect(lease.sideEffect.contains("acquire"))
    }

    @Test("target schema exposes lease usage forms and options")
    func targetSchemaExposesLeaseSurface() {
        let schema = try? commandSchemas().first { $0.name == "target" }
        let lease = schema?.subcommands.first { $0.name == "lease" }

        #expect(lease != nil)
        #expect(schema?.usageForms.contains { $0.form == "lease acquire --target <udid> --owner <label>" } == true)
        #expect(schema?.usageForms.contains { $0.form == "lease takeover --target <udid> --owner <label> --confirm" } == true)
        #expect(schema?.options.contains { $0.name == "--lease" } == true)
        #expect(schema?.options.contains { $0.name == "--owner" } == true)
        #expect(schema?.providedCapabilities.contains("target-lease") == true)
        #expect(schema?.failureCodes.contains("target_lease_conflict") == true)
    }

    @Test("app open-url schema accepts the --lease option and conflict code")
    func appOpenURLSchemaAcceptsLeaseOption() {
        let schema = commandSchemas().first { $0.name == "app" }
        let openURL = schema?.subcommands.first { $0.name == "open-url" }

        #expect(openURL?.optionalOptions.contains("--lease") == true)
        #expect(openURL?.failureCodes.contains("target_lease_conflict") == true)
    }

    @Test("act tap schema accepts the --lease option and conflict code")
    func actTapSchemaAcceptsLeaseOption() {
        let schema = commandSchemas().first { $0.name == "act" }
        let tap = schema?.subcommands.first { $0.name == "tap" }

        #expect(tap?.optionalOptions.contains("--lease") == true)
        #expect(tap?.failureCodes.contains("target_lease_conflict") == true)
    }

    @Test("app open-url parses --lease")
    func appOpenURLParsesLease() throws {
        let command = try HostAppOpenURL.parse([
            "myapp://home",
            "--device", "sim:\(udid)",
            "--lease", "lease-1",
            "--json",
        ])

        #expect(command.leaseID == "lease-1")
        #expect(command.url == "myapp://home")
    }

    @Test("app launch parses --lease")
    func appLaunchParsesLease() throws {
        let command = try HostAppLaunch.parse([
            "--bundle-id", "com.example.app",
            "--device", "sim:\(udid)",
            "--lease", "lease-1",
            "--json",
        ])

        #expect(command.leaseID == "lease-1")
    }

    @Test("app terminate parses --lease")
    func appTerminateParsesLease() throws {
        let command = try HostAppTerminate.parse([
            "--bundle-id", "com.example.app",
            "--device", "sim:\(udid)",
            "--lease", "lease-1",
            "--json",
        ])

        #expect(command.leaseID == "lease-1")
    }

    @Test("act tap parses --lease")
    func actTapParsesLease() throws {
        let command = try Tap.parse([
            "--device", "sim:\(udid)",
            "--x", "10",
            "--y", "20",
            "--lease", "lease-1",
            "--json",
        ])

        #expect(command.leaseID == "lease-1")
    }

    @Test("capabilities advertise target-lease")
    func capabilitiesAdvertiseTargetLease() {
        let capabilities = runtimeCapabilities(host: "127.0.0.1", port: 19421, serverReachable: true, connected: false)

        #expect(capabilities.contains { $0.name == "target-lease" && $0.supported } == true)
    }
}
