import Foundation
import Testing
@testable import TritonKitShared

@Suite struct TKSelectionModelsTests {
    @Test func selectionReferenceRoundTripsThroughInput() throws {
        let reference = TKSelectionGuard(runtimeInstanceID: "runtime-1", selectionID: "selection-1", revision: 3)
        try reference.validate()
        let request = TKInputRequest(type: .tap, selection: reference)
        let decoded = try JSONDecoder().decode(TKInputRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded.selection == reference)
        #expect(decoded.targetOID == nil)
        let legacy = try JSONDecoder().decode(TKInputRequest.self, from: Data("{\"type\":\"tap\",\"targetOID\":42}".utf8))
        #expect(legacy.selection == nil)
        #expect(legacy.targetOID == 42)
    }
    @Test func guardRejectsIncompleteIdentity() {
        for reference in [TKSelectionGuard(runtimeInstanceID: "", selectionID: "a", revision: 1),
                          TKSelectionGuard(runtimeInstanceID: "r", selectionID: " ", revision: 1),
                          TKSelectionGuard(runtimeInstanceID: "r", selectionID: "a", revision: 0)] {
            #expect(throws: TKSelectionError.self) { try reference.validate() }
        }
    }
    @Test func transportMappings() {
        #expect(TKCLICommandRequest(type: "selectionStatus").requestType == .selectionStatus)
        #expect(TKCLICommandRequest(type: "selectionClear").requestType == .selectionClear)
        #expect(TKCLICommandRequest(type: "selectionCapabilities").requestType == .selectionCapabilities)
    }
    @Test func nestedSnapshotRoundTrip() throws {
        let node = TKAXNode(role: "button", label: "Continue", value: nil, identifier: "continue", title: nil,
            frame: TKRect(x: 1, y: 2, width: 80, height: 44), enabled: true, focused: false, hidden: false,
            targetOID: 17, className: "UIButton", children: [])
        let snapshot = TKSelectionSnapshot(id: "s", revision: 1, selectedAt: 1, expiresAt: 301,
            sceneID: "scene", windowID: 5, rawHitOID: 17, target: node, validity: "valid", supportedActions: ["tap"])
        let response = TKSelectionResponse(runtimeInstanceID: "r", revision: 1, state: "selected", selection: snapshot)
        #expect(try JSONDecoder().decode(TKSelectionResponse.self, from: JSONEncoder().encode(response)) == response)
        #expect(response.selection?.coordinateSpace == "window-points")
    }
}
