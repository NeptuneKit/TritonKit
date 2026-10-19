import Testing
@testable import TritonKitCLI

@Suite("Reference adoption public schema contracts")
struct ReferenceAdoptionSchemaTests {
    @Test func geometryFailureIsAdvertisedAcrossConsumers() throws {
        let code = "ios_host_ax_geometry_unavailable"
        for name in ["sim", "observe", "wait", "act", "node"] {
            let schema = try #require(commandSchemas().first { $0.name == name })
            #expect(schema.failureCodes.contains(code), "Missing geometry error in \(name)")
        }
        let sim = try #require(commandSchemas().first { $0.name == "sim" })
        let ax = try #require(sim.subcommands.first { $0.name == "ax" })
        #expect(ax.failureCodes.contains(code))
    }

    @Test func foregroundIdentityFieldsAreDiscoverableAndOptional() throws {
        let fields = deviceEnvironmentOutputContract().fields
        for name in ["observed.bundleIdentifier", "observed.identityState", "observed.scope", "observed.activity", "observed.component"] {
            let field = try #require(fields.first { $0.name == name })
            #expect(!field.required)
        }
    }
}
