import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKHostStrongControlModelsTests {
    @Test("strong-control capability round trips stable fields")
    func strongControlCapabilityRoundTrips() throws {
        let capability = TKHostStrongControlCapability(
            name: "ios-host-ax",
            platform: "ios",
            runtimeScope: "host-simulator",
            available: false,
            reason: "idb_not_available",
            dependency: "idb/FBSimulatorControl",
            limitations: ["private_framework_dependency", "simulator_only"],
            fallbackCapability: "embedded-runtime-or-public-simctl",
            sourceCommand: "idb --version",
            nextAction: TKCLINextAction(command: "device", args: ["doctor", "--platform", "ios", "--json"], category: "diagnose")
        )

        let decoded = try JSONDecoder().decode(TKHostStrongControlCapability.self, from: JSONEncoder().encode(capability))

        #expect(decoded == capability)
    }

    @Test("root package manifest does not leak host strong-control dependencies")
    func rootPackageManifestDoesNotLeakHostStrongControlDependencies() throws {
        let manifest = try String(contentsOfFile: "Package.swift", encoding: .utf8)

        for forbidden in ["TritonKitCLI", "ArgumentParser", "Hummingbird", "FBSimulatorControl", "FBControlCore", "XCTestBootstrap", "idb", "Gradle"] {
            #expect(!manifest.contains(forbidden))
        }
        #expect(manifest.contains("dependencies: []"))
    }
}
