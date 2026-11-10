import Foundation
import Testing
import TritonKitShared
@testable import TritonKit

@Suite("Hierarchy details availability")
struct TKHierarchyDetailsAvailabilityTests {
    @Test("detail images require screenshot capability while attributes remain available")
    func screenshotCapability() throws {
        var configuration = TritonKit.Configuration()
        configuration.features.remove(.screenshot)
        for mode in TKNodeScreenshotMode.allCases {
            let request = TKMessage(id: 733, type: .hierarchyDetails,
                payload: try JSONEncoder().encode(TKHierarchyDetailsRequest(oids: [1], screenshots: mode)))
            let message = TKRuntimeCapabilityGate.disabledResponse(for: request, configuration: configuration)
            if mode == .none {
                #expect(message == nil)
            } else {
                let payload = try #require(message?.payload)
                let response = try JSONDecoder().decode(TKHierarchyDetailsResponse.self, from: payload)
                #expect(!response.ok && response.details.isEmpty)
                #expect(response.error?.code == "capability_disabled")
            }
        }
    }

    @Test("disabled hierarchy preserves typed details failure")
    func disabledCapability() throws {
        var configuration = TritonKit.Configuration()
        configuration.features.remove(.hierarchy)
        let request = TKMessage(id: 730, type: .hierarchyDetails,
            payload: try JSONEncoder().encode(TKHierarchyDetailsRequest(oids: [1])))
        let message = try #require(TKRuntimeCapabilityGate.disabledResponse(for: request, configuration: configuration))
        let response = try JSONDecoder().decode(TKHierarchyDetailsResponse.self, from: #require(message.payload))
        #expect(message.type == .hierarchyDetails)
        #expect(message.id == request.id)
        #expect(!response.ok && !response.partial && response.details.isEmpty)
        #expect(response.error?.code == "capability_disabled")
    }

    @Test("UI admission failures stay typed and never fabricate detail images")
    func healthErrors() throws {
        for code in ["runtime_ui_busy", "runtime_ui_timeout", "runtime_ui_circuit_open"] {
            let request = TKMessage(id: 731, type: .hierarchyDetails)
            let message = runtimeUIHealthErrorResponse(request, code: code, health: TKRuntimeUIHealthController().snapshot())
            let response = try JSONDecoder().decode(TKHierarchyDetailsResponse.self, from: #require(message.payload))
            #expect(message.id == request.id && message.type == request.type)
            #expect(!response.ok && !response.partial && response.details.isEmpty)
            #expect(response.error?.code == code)
            #expect(response.outcome == (code == "runtime_ui_timeout" ? "unknown" : "not_started"))
            #expect(response.uiHealth != nil)
        }
    }

    @Test("Release entry point denies details without entering its provider")
    func releaseEntryPoint() async throws {
        guard !TritonKit.isRuntimeEnabled else { return }
        let handler = TritonKitRequestHandler()
        let message = try #require(await handler.tritonKit(TritonKit.shared,
            didReceiveMessage: TKMessage(id: 732, type: .hierarchyDetails,
                payload: try JSONEncoder().encode(TKHierarchyDetailsRequest(oids: [1])))))
        let response = try JSONDecoder().decode(TKHierarchyDetailsResponse.self, from: #require(message.payload))
        #expect(message.type == .hierarchyDetails)
        #expect(!response.ok && response.details.isEmpty)
        #expect(response.error?.code == "runtime_disabled")
    }
}
