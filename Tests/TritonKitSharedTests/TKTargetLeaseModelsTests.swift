import Foundation
import Testing
@testable import TritonKitShared

@Suite("TKTargetLease wire contract")
struct TKTargetLeaseModelsTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_750_000_000)

    @Test("target lease encodes and decodes with all fields")
    func targetLeaseRoundTrip() throws {
        let lease = TKTargetLease(
            id: "lease-1",
            target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            owner: "agent-a",
            acquiredAt: fixedNow,
            expiresAt: fixedNow.addingTimeInterval(300),
            ttlSeconds: 300,
            readonlyObservationAllowed: true
        )

        let data = try JSONEncoder().encode(lease)
        let decoded = try JSONDecoder().decode(TKTargetLease.self, from: data)

        #expect(decoded == lease)
        #expect(decoded.kind == "triton.target-lease")
    }

    @Test("target lease request models round trip")
    func requestModelsRoundTrip() throws {
        let acquire = TKTargetLeaseAcquireRequest(
            target: "sim:A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            owner: "agent-a",
            ttlSeconds: 120,
            readonlyObservationAllowed: false
        )
        let release = TKTargetLeaseReleaseRequest(target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D", leaseID: "lease-1")
        let takeover = TKTargetLeaseTakeoverRequest(
            target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            owner: "agent-b",
            ttlSeconds: nil,
            readonlyObservationAllowed: nil,
            confirm: true
        )
        let check = TKTargetLeaseCheckRequest(target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D", leaseID: "lease-1")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        #expect(try decoder.decode(TKTargetLeaseAcquireRequest.self, from: encoder.encode(acquire)) == acquire)
        #expect(try decoder.decode(TKTargetLeaseReleaseRequest.self, from: encoder.encode(release)) == release)
        #expect(try decoder.decode(TKTargetLeaseTakeoverRequest.self, from: encoder.encode(takeover)) == takeover)
        #expect(try decoder.decode(TKTargetLeaseCheckRequest.self, from: encoder.encode(check)) == check)
    }

    @Test("target lease response models round trip")
    func responseModelsRoundTrip() throws {
        let lease = TKTargetLease(
            id: "lease-1",
            target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            owner: "agent-a",
            acquiredAt: fixedNow,
            expiresAt: fixedNow.addingTimeInterval(300),
            ttlSeconds: 300,
            readonlyObservationAllowed: true
        )
        let acquireResponse = TKTargetLeaseAcquireResponse(
            ok: true,
            status: "acquired",
            target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            lease: lease,
            previousOwner: nil
        )
        let statusResponse = TKTargetLeaseStatusResponse(
            ok: true,
            target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            status: "held",
            lease: lease
        )
        let releaseResponse = TKTargetLeaseReleaseResponse(
            ok: true,
            released: true,
            status: "released",
            target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            lease: lease
        )
        let checkResponse = TKTargetLeaseCheckResponse(
            ok: true,
            authorized: true,
            reason: "lease_matched",
            target: "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D",
            lease: lease
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        #expect(try decoder.decode(TKTargetLeaseAcquireResponse.self, from: encoder.encode(acquireResponse)) == acquireResponse)
        #expect(try decoder.decode(TKTargetLeaseStatusResponse.self, from: encoder.encode(statusResponse)) == statusResponse)
        #expect(try decoder.decode(TKTargetLeaseReleaseResponse.self, from: encoder.encode(releaseResponse)) == releaseResponse)
        #expect(try decoder.decode(TKTargetLeaseCheckResponse.self, from: encoder.encode(checkResponse)) == checkResponse)
    }

    @Test("lease conflict envelope carries stable code and current-owner diagnostics")
    func conflictEnvelopeDecodesLeaseFields() throws {
        let json = """
        {
          "ok": false,
          "surface": "target-lease",
          "error": {
            "code": "target_lease_conflict",
            "message": "Target lease is held by another owner.",
            "hint": "Inspect `triton target lease status --target <udid> --json`.",
            "endpoint": "http://127.0.0.1:19421/v1/target-leases/check",
            "leaseReason": "held_by_other",
            "currentOwner": "agent-a",
            "currentLeaseID": "lease-1",
            "currentExpiresAt": 771693100,
            "suggestedCommands": ["triton target lease status --target <udid> --json"]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: json)

        #expect(!response.ok)
        #expect(response.error.code == "target_lease_conflict")
        #expect(response.error.leaseReason == "held_by_other")
        #expect(response.error.currentOwner == "agent-a")
        #expect(response.error.currentLeaseID == "lease-1")
        #expect(response.error.currentExpiresAt == Date(timeIntervalSince1970: 1_750_000_300))
        #expect(response.error.suggestedCommands?.first?.contains("target lease status") == true)
    }

    @Test("legacy error JSON without lease fields still decodes")
    func legacyErrorJSONWithoutLeaseFieldsStillDecodes() throws {
        let json = """
        {
          "ok": false,
          "error": {
            "code": "target_not_found",
            "message": "Target not found",
            "hint": "Run `triton list --json`."
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: json)

        #expect(response.error.code == "target_not_found")
        #expect(response.error.leaseReason == nil)
        #expect(response.error.currentOwner == nil)
        #expect(response.error.currentLeaseID == nil)
        #expect(response.error.currentExpiresAt == nil)
    }

    @Test("lease target keys normalize known simulator prefixes")
    func normalizeTargetLeaseKey() {
        let udid = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"

        #expect(TKNormalizeTargetLeaseKey("sim:\(udid)") == udid)
        #expect(TKNormalizeTargetLeaseKey("host:ios:\(udid)") == udid)
        #expect(TKNormalizeTargetLeaseKey("triton:ios-simulator:\(udid)") == udid)
        #expect(TKNormalizeTargetLeaseKey("triton:ios-simulator:\(udid)/app:com.example.app") == udid)
        #expect(TKNormalizeTargetLeaseKey(udid) == udid)
        #expect(TKNormalizeTargetLeaseKey("booted") == "booted")
        #expect(TKNormalizeTargetLeaseKey("  sim:\(udid)  ") == udid)
    }
}
