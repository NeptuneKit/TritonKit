import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKRuntimeManifestModelsTests {
    @Test("debug runtime manifest exposes embedded SDK identity limits and redaction")
    func debugManifestShape() throws {
        let manifest = TKRuntimeManifestResponse.debugDefault(
            sdkVersion: "0.1.1",
            capabilities: [
                TKRuntimeCapabilityDetail(
                    name: .stateApp,
                    supported: true,
                    scope: .embedded,
                    boundary: .appProcess
                ),
                TKRuntimeCapabilityDetail(
                    name: .press,
                    supported: false,
                    scope: .hostSide,
                    boundary: .simulatorHost,
                    reason: "Host-side HID is not available in the embedded runtime",
                    nextAction: TKCLINextAction(command: "sim", args: ["<host-side-button-command>"])
                ),
            ]
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(TKRuntimeManifestResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.platform == "ios")
        #expect(decoded.runtime == "embedded")
        #expect(decoded.transport == "embedded-websocket")
        #expect(decoded.enabled)
        #expect(decoded.sdkVersion == "0.1.1")
        #expect(decoded.buildConfiguration == "debug")
        #expect(decoded.limits.maxAXNodes == 800)
        #expect(decoded.limits.maxLedgerEntries == 100)
        #expect(decoded.redaction.secureText == "length-only")
        #expect(decoded.redaction.clipboard == "not-collected")
        #expect(decoded.capabilities.first?.scope == "embedded")
        #expect(decoded.capabilities.first?.boundary == "app-process")
        #expect(decoded.capabilities.last?.supported == false)
        #expect(decoded.capabilities.last?.nextAction?.command == "sim")
    }

    @Test("typed runtime capability detail preserves wire strings")
    func typedCapabilityWireShape() throws {
        let capability = TKRuntimeCapabilityDetail(
            name: .ledger,
            supported: true,
            scope: .embedded,
            boundary: .appProcess
        )

        let data = try JSONEncoder().encode(capability)
        let decoded = try JSONDecoder().decode(TKRuntimeCapabilityDetail.self, from: data)

        #expect(decoded.name == "ledger")
        #expect(decoded.scope == "embedded")
        #expect(decoded.boundary == "app-process")
    }

    @Test("default debug capabilities are named from the shared capability catalog")
    func defaultDebugCapabilityNames() {
        let names = Set(TKRuntimeManifestResponse.defaultDebugCapabilities.map(\.name))

        #expect(names.contains(TKRuntimeCapabilityName.snapshot.rawValue))
        #expect(names.contains(TKRuntimeCapabilityName.semanticFocus.rawValue))
        #expect(names.contains(TKRuntimeCapabilityName.semanticSetText.rawValue))
        #expect(names.contains(TKRuntimeCapabilityName.semanticSelectSegment.rawValue))
        #expect(names.contains(TKRuntimeCapabilityName.semanticSetSwitch.rawValue))
        #expect(names.contains(TKRuntimeCapabilityName.ledger.rawValue))
    }

    @Test("release runtime manifest is disabled no-op surface")
    func releaseManifestShape() throws {
        let manifest = TKRuntimeManifestResponse.releaseDisabled(sdkVersion: "0.1.1")

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(TKRuntimeManifestResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.platform == "ios")
        #expect(decoded.runtime == "embedded")
        #expect(decoded.enabled == false)
        #expect(decoded.buildConfiguration == "release")
        #expect(decoded.capabilities.isEmpty)
        #expect(decoded.redaction.policy == "disabled-runtime")
        #expect(decoded.redaction.network == "not-collected")
        #expect(decoded.redaction.logs == "not-collected")
    }
}
