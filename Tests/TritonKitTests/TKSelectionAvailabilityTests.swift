import Foundation
import Testing
@testable import TritonKit
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

@Suite(.serialized) struct TKSelectionAvailabilityTests {
    @Test func pickerConfigurationDefaultsAndEnvironment() {
        #expect(!TritonKit.Configuration.defaultFeatures.contains(.inspector))
        #expect(TritonKit.PickerConfiguration.environment([:]).enabled == false)
        #expect(TritonKit.PickerConfiguration.environment([:]).ttlSeconds == 300)
        let enabled = TritonKit.PickerConfiguration.environment(["TRITON_PICKER_ENABLED":"1", "TRITON_PICKER_TTL_SECONDS":"45"])
        #expect(enabled.enabled && enabled.ttlSeconds == 45)
        let invalid = TritonKit.PickerConfiguration.environment(["TRITON_PICKER_ENABLED":"yes", "TRITON_PICKER_TTL_SECONDS":"-1"])
        #expect(!invalid.enabled && invalid.ttlSeconds == 300)
        #expect(TritonKit.PickerConfiguration(enabled: true, ttlSeconds: 999).ttlSeconds == 300)
    }
    @Test @MainActor func runtimeToggleCannotStartStoppedSDK() {
        let kit = TritonKit.shared
        kit.stop()
        #expect(!kit.setPickerEnabled(true))
        #expect(!kit.isPickerEnabled)
        #expect(kit.setPickerEnabled(false))
        #expect(kit.state == .disconnected)
    }

    @Test func disabledSelectionHasTypedEnvelope() async throws {
        let kit = TritonKit.shared
        kit.stop()
        let handler = TritonKitRequestHandler()
        let message = TKMessage(id: 7, type: .selectionStatus, payload: try JSONEncoder().encode(TKSelectionRequest()))
        let result = try #require(await handler.tritonKit(kit, didReceiveMessage: message))
        #expect(result.type == .selectionStatus)
        let response = try JSONDecoder().decode(TKSelectionResponse.self, from: #require(result.payload))
        #expect(!response.ok)
        #expect(response.error?.code == "selection_unsupported")
        #expect(response.selection == nil)
    }
    @Test func guardedInputRejectsConflictingFieldsBeforeDispatch() async throws {
        let handler = TritonKitRequestHandler()
        let guardValue = TKSelectionGuard(runtimeInstanceID: "runtime", selectionID: "selection", revision: 1)
        let invalidRequests = [
            TKInputRequest(type: .tap, targetOID: 1, selection: guardValue),
            TKInputRequest(type: .tap, matchedClassName: "UIButton", selection: guardValue),
            TKInputRequest(type: .tap, duration: 0.5, selection: guardValue),
            TKInputRequest(type: .tap, width: 320, height: 480, selection: guardValue),
            TKInputRequest(type: .tap, secure: true, selection: guardValue),
            TKInputRequest(type: .swipe, selection: guardValue),
            TKInputRequest(type: .tap, selection: .init(runtimeInstanceID: "", selectionID: "selection", revision: 1))
        ]
        for request in invalidRequests {
            let result = try #require(await handler.handleInput(TKMessage(id: 9, type: .input, payload: try JSONEncoder().encode(request))))
            let response = try JSONDecoder().decode(TKInputResult.self, from: #require(result.payload))
            #expect(!response.ok)
            #expect(response.error?.code == "validation_failed")
        }
    }

    #if !TRITONKIT_RUNTIME_ENABLED
    @Test func releaseCannotEnablePickerOrConnection() async throws {
        let kit = TritonKit.shared
        var configuration = TritonKit.Configuration()
        configuration.features.insert(.inspector)
        configuration.picker = .init(enabled: true)
        #expect(!kit.start(configuration))
        let enabled = await kit.setPickerEnabled(true)
        #expect(!enabled)
        #expect(!kit.isPickerEnabled)
        #expect(kit.state == .disconnected)
        #if canImport(UIKit)
        let hasManager = await MainActor.run { kit.pickerStorage.current() != nil }
        #expect(!hasManager)
        #endif
        let response = try #require(await TritonKitRequestHandler().tritonKit(kit, didReceiveMessage:
            TKMessage(id: 13, type: .selectionCapabilities, payload: try JSONEncoder().encode(TKSelectionRequest()))))
        let value = try JSONDecoder().decode(TKSelectionResponse.self, from: #require(response.payload))
        #expect(value.error?.code == "selection_unsupported")
        kit.stop()
    }
    #endif

}
