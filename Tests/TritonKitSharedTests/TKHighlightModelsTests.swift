import Foundation
import Testing
import TritonKitShared

@Suite struct TKHighlightModelsTests {
    private func item(_ id: String = "submit") -> TKHighlightItem {
        TKHighlightItem(markID: id, selector: TKHighlightSelector(identifier: "submit"))
    }

    @Test func independentRequestRoundTrip() throws {
        let request = TKHighlightApplyRequest(operationID: "operation-A", spec: TKHighlightSpec(items: [item()]))
        try request.validate()
        let data = try JSONEncoder().encode(request)
        #expect(try JSONDecoder().decode(TKHighlightApplyRequest.self, from: data) == request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["screenshot"] == nil)
        #expect(request.ttlSeconds == 30)
        #expect(request.spec.color == "#FF453A")
        #expect(request.spec.width == 3)
    }

    @Test func minimalSpecDefaultsAndUnknownFields() throws {
        let data = Data(#"{"items":[{"markID":"a","selector":{"identifier":"submit"}}]}"#.utf8)
        let spec = try JSONDecoder().decode(TKHighlightSpec.self, from: data)
        #expect(spec.color == "#FF453A")
        #expect(spec.width == 3)
        #expect(spec.schemaVersion == 1)
        for raw in [#"{"items":[{"markID":"a","selector":{"identifier":"submit","within":3}}]}"#, #"{"items":[{"markID":"a","selector":{"identifier":"submit"}}],"screenshot":true}"#] {
            #expect(throws: TKHighlightError.self) { try JSONDecoder().decode(TKHighlightSpec.self, from: Data(raw.utf8)) }
        }
        let request = try JSONDecoder().decode(TKHighlightClearRequest.self, from: Data(#"{"sessionID":"session"}"#.utf8))
        #expect(request.markIDs.isEmpty)
    }

    @Test func canonicalPayloadNormalizesColorButPreservesTTL() throws {
        let lowercase = TKHighlightApplyRequest(operationID: "op", spec: TKHighlightSpec(color: "#ff453a", items: [item()]))
        let uppercase = TKHighlightApplyRequest(operationID: "op", spec: TKHighlightSpec(items: [item()]))
        #expect(try lowercase.canonicalData() == uppercase.canonicalData())
        let changedTTL = TKHighlightApplyRequest(operationID: "op", ttlSeconds: 31, spec: uppercase.spec)
        #expect(try uppercase.canonicalData() != changedTTL.canonicalData())
    }

    @Test func budgetAndTTLBoundaries() throws {
        for ttl in [1, 300] {
            try TKHighlightApplyRequest(operationID: "op", ttlSeconds: ttl, spec: TKHighlightSpec(items: (0..<10).map { item("m\($0)") })).validate()
        }
        for ttl in [0, 301] {
            #expect(throws: TKHighlightError.self) {
                try TKHighlightApplyRequest(operationID: "op", ttlSeconds: ttl, spec: TKHighlightSpec(items: [item()])).validate()
            }
        }
        for count in [0, 11] {
            #expect(throws: TKHighlightError.self) {
                try TKHighlightSpec(items: (0..<count).map { item("m\($0)") }).validate()
            }
        }
    }

    @Test func duplicateAndMalformedSelectorsAreRejectedBeforeWrites() {
        #expect(throws: TKHighlightError.self) { try TKHighlightSpec(items: [item(), item()]).validate() }
        for selector in [TKHighlightSelector(), TKHighlightSelector(oid: 1, identifier: "submit"), TKHighlightSelector(text: " "), TKHighlightSelector(oid: 0), TKHighlightSelector(identifier: "submit", withinOID: 0)] {
            #expect(throws: TKHighlightError.self) { try selector.validate() }
        }
    }

    @Test func statusHasExactlyOneLookupKey() throws {
        try TKHighlightStatusRequest(sessionID: "session").validate()
        try TKHighlightStatusRequest(operationID: "operation").validate()
        for request in [TKHighlightStatusRequest(), TKHighlightStatusRequest(sessionID: "session", operationID: "operation"), TKHighlightStatusRequest(sessionID: " ")] {
            #expect(throws: TKHighlightError.self) { try request.validate() }
        }
    }

    @Test func clearRequiresScopedUniqueMarks() throws {
        try TKHighlightClearRequest(sessionID: "session").validate()
        try TKHighlightClearRequest(sessionID: "session", markIDs: ["a", "b"]).validate()
        #expect(throws: TKHighlightError.self) { try TKHighlightClearRequest(sessionID: "", markIDs: []).validate() }
        #expect(throws: TKHighlightError.self) { try TKHighlightClearRequest(sessionID: "session", markIDs: ["a", "a"]).validate() }
    }

    @Test func invalidStyleOrRuntimeIsRejected() {
        for spec in [TKHighlightSpec(preset: "background", items: [item()]), TKHighlightSpec(color: "red", items: [item()]), TKHighlightSpec(width: .infinity, items: [item()]), TKHighlightSpec(width: 0, items: [item()]), TKHighlightSpec(schemaVersion: 2, items: [item()])] {
            #expect(throws: TKHighlightError.self) { try spec.validate() }
        }
        #expect(throws: TKHighlightError.self) { try TKHighlightApplyRequest(operationID: " ", spec: TKHighlightSpec(items: [item()])).validate() }
        #expect(throws: TKHighlightError.self) { try TKHighlightCapabilitiesRequest(runtimeInstanceID: " ").validate() }
    }

    @Test func conflictReceiptDoesNotImplyRestoration() throws {
        let receipt = TKHighlightReceipt(ok: false, runtimeInstanceID: "runtime", sessionID: "session", state: .needsAttention, marks: [TKHighlightMarkReceipt(markID: "submit", outcome: .conflict, changedKeys: ["borderColor", "borderWidth"])], residualState: .possible, error: TKHighlightError(code: "highlight_restore_conflict", message: "Business values preserved"))
        let decoded = try JSONDecoder().decode(TKHighlightReceipt.self, from: JSONEncoder().encode(receipt))
        #expect(decoded == receipt)
        #expect(!decoded.cleanupComplete)
        #expect(!decoded.restorationVerified)
        #expect(!decoded.marks[0].restoreWritten)
        #expect(decoded.marks[0].restoredTo == .none)
    }

    @Test func futureProviderCanReportCurrentBase() throws {
        let mark = TKHighlightMarkReceipt(markID: "title", outcome: .restored, restorationMode: .managedOverride, restoredTo: .currentBase, baselineVersionAtApply: "1", baselineVersionCurrent: "2")
        #expect(try JSONDecoder().decode(TKHighlightMarkReceipt.self, from: JSONEncoder().encode(mark)) == mark)
    }

    @Test func olderReceiptDoesNotInventRestorationEvidence() throws {
        let raw = #"{"ok":true,"runtimeInstanceID":"runtime","sessionID":"session","state":"closed","marks":[{"markID":"a","outcome":"target_gone"}]}"#
        let receipt = try JSONDecoder().decode(TKHighlightReceipt.self, from: Data(raw.utf8))
        #expect(!receipt.restorationVerified)
        #expect(!receipt.cleanupComplete)
        #expect(receipt.residualState == .unknown)
        #expect(receipt.renderObservation == "not_observed")
        #expect(receipt.marks[0].restoredTo == .none)
    }

    @Test func unsupportedIsAnExplicitOptionalCapability() throws {
        let response = TKHighlightCapabilitiesResponse(runtimeInstanceID: "runtime", capability: .unsupported(reason: "no_writable_provider"))
        let decoded = try JSONDecoder().decode(TKHighlightCapabilitiesResponse.self, from: JSONEncoder().encode(response))
        #expect(decoded.ok)
        #expect(!decoded.capability.supported)
        #expect(decoded.capability.reason == "no_writable_provider")
        #expect(decoded.capability.presets.isEmpty)
        #expect(decoded.capability.limits.maxNodes == 10)
    }
}
