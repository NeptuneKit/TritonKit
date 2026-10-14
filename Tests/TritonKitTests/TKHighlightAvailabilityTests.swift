import Foundation
import Testing
@testable import TritonKit
import TritonKitShared

@Suite struct TKHighlightAvailabilityTests {
    @Test func OptionalFeatureCanBeDisabledWithoutBlockingSessionReadback() throws {
        var configuration = TritonKit.Configuration()
        #expect(configuration.features.contains(.highlight))
        configuration.features.remove(.highlight)
        let message = TKMessage(id: 194, type: .highlightApply)
        let response = try #require(TKRuntimeCapabilityGate.disabledResponse(for: message, configuration: configuration))
        let receipt = try JSONDecoder().decode(TKHighlightReceipt.self, from: try #require(response.payload))
        #expect(!receipt.ok)
        #expect(receipt.error?.code == "highlight_unsupported")
        for type in [TKRequestType.highlightStatus, .highlightClear, .highlightCapabilities] {
            #expect(TKRuntimeCapabilityGate.disabledResponse(for: TKMessage(id: 195, type: type), configuration: configuration) == nil)
        }
    }
    @Test func OptionalHighlightDoesNotBecomeAnEnabledReleaseCapability() {
        let manifest = TKRuntimeManifestResponse.releaseDisabled(sdkVersion: "test")
        #expect(!manifest.enabled)
        #expect(manifest.capabilities.first { $0.name == TKRuntimeCapabilityName.highlight.rawValue }?.supported != true)
    }

    #if !TRITONKIT_RUNTIME_ENABLED || !canImport(UIKit)
    @Test func UnavailableProviderReturnsTypedReceiptsWithoutApplying() async throws {
        let handler = TritonKitRequestHandler()
        let kit = TritonKit.shared
        for type in [TKRequestType.highlightApply, .highlightStatus, .highlightClear] {
            let message = TKMessage(id: 194, type: type, payload: Data("{}".utf8))
            let response = try #require(await handler.tritonKit(kit, didReceiveMessage: message))
            let receipt = try JSONDecoder().decode(TKHighlightReceipt.self, from: try #require(response.payload))
            #expect(!receipt.ok)
            #expect(receipt.error?.code == "highlight_unsupported")
            #expect(receipt.marks.isEmpty)
            #expect(receipt.sessionID == nil)
            #expect(!receipt.restorationVerified)
            #expect(receipt.residualState == .none)
        }
        let response = try #require(await handler.tritonKit(kit, didReceiveMessage: TKMessage(id: 195, type: .highlightCapabilities)))
        let capabilities = try JSONDecoder().decode(TKHighlightCapabilitiesResponse.self, from: try #require(response.payload))
        #expect(capabilities.ok)
        #expect(!capabilities.capability.supported)
    }
    #endif
}
