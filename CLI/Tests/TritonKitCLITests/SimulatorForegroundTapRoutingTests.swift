import Testing
@testable import TritonKitCLI

@Suite("SP-163 Simulator foreground coordinate tap routing")
struct SimulatorForegroundTapRoutingTests {
    @Test("explicit sim selector routes a pure coordinate tap to the iOS host adapter")
    func simSelectorRoutesCoordinateTapToHost() throws {
        let command = try Tap.parse([
            "--device", "sim:A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            "--at", "470,1000",
            "--json",
        ])

        #expect(shouldRouteImplicitIOSHostCoordinateTap(
            platform: command.platform,
            target: command.target,
            query: command.query ?? command.text,
            x: command.x,
            y: command.y,
            at: command.at,
            oid: command.oid,
            axOID: command.axOID,
            axLabel: command.axLabel
        ))
    }

    @Test("raw Simulator UUID routes a coordinate tap to host instead of a same-UDID runtime")
    func rawSimulatorUUIDRoutesCoordinateTapToHost() throws {
        let command = try Tap.parse([
            "--device", "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            "--x", "470",
            "--y", "1000",
            "--json",
        ])

        #expect(shouldRouteImplicitIOSHostCoordinateTap(
            platform: command.platform,
            target: command.target,
            query: command.query ?? command.text,
            x: command.x,
            y: command.y,
            at: command.at,
            oid: command.oid,
            axOID: command.axOID,
            axLabel: command.axLabel
        ))
    }

    @Test("canonical runtime targets preserve embedded routing")
    func canonicalRuntimeTargetStaysEmbedded() throws {
        for target in [
            "triton:ios-simulator:A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            "triton:ios-simulator:A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D/app:com.example.fixture",
        ] {
            #expect(!shouldRouteImplicitIOSHostCoordinateTap(
                platform: nil,
                target: target,
                query: nil,
                x: 470,
                y: 1000,
                at: nil,
                oid: nil,
                axOID: nil,
                axLabel: nil
            ))
        }
    }

    @Test("implicit host routing is limited to explicit Simulator coordinate selectors")
    func implicitRoutingRejectsSemanticAndUnscopedSelectors() {
        #expect(!shouldRouteImplicitIOSHostCoordinateTap(
            platform: nil,
            target: "sim:A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            query: "Continue",
            x: nil,
            y: nil,
            at: nil,
            oid: nil,
            axOID: nil,
            axLabel: nil
        ))
        #expect(!shouldRouteImplicitIOSHostCoordinateTap(
            platform: nil,
            target: "local",
            query: nil,
            x: 470,
            y: 1000,
            at: nil,
            oid: nil,
            axOID: nil,
            axLabel: nil
        ))
        #expect(!shouldRouteImplicitIOSHostCoordinateTap(
            platform: .android,
            target: "sim:A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            query: nil,
            x: 470,
            y: 1000,
            at: nil,
            oid: nil,
            axOID: nil,
            axLabel: nil
        ))
    }

    @Test("booted and current are explicit host Simulator coordinate selectors")
    func hostAliasesRouteCoordinateTapToHost() {
        for target in ["booted", "current"] {
            #expect(shouldRouteImplicitIOSHostCoordinateTap(
                platform: nil,
                target: target,
                query: nil,
                x: nil,
                y: nil,
                at: "470,1000",
                oid: nil,
                axOID: nil,
                axLabel: nil
            ))
        }
    }

    @Test("act schema distinguishes host Simulator selectors from canonical runtime targets")
    func actSchemaDocumentsHostCoordinateRouting() throws {
        let schema = try #require(actionCommandSchemas().first { $0.name == "act" })
        let target = try #require(schema.options.first { $0.name == "--target/--device" })
        let outputSemantics = try #require(schema.outputSemantics)

        #expect(target.description.contains("sim:<udid>"))
        #expect(target.description.contains("routes directly to host HID"))
        #expect(schema.usageForms.contains { $0.form == "triton act tap --device <selector> --at <x,y> --json" })
        #expect(outputSemantics.contains("bypasses embedded /targets resolution"))
        #expect(outputSemantics.contains("Host acknowledgement remains unverified"))
        #expect(schema.outputContracts.contains { $0.selector == "input.result" })
    }
}
