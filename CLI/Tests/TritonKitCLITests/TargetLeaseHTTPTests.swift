import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Target lease HTTP routes")
struct TargetLeaseHTTPTests {
    private let udid = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"

    private func body(_ value: some Encodable) throws -> ByteBuffer {
        ByteBuffer(data: try JSONEncoder().encode(value))
    }

    @Test("acquire returns a bounded lease and a second owner conflicts")
    func acquireAndConflictRoundTrip() async throws {
        let store = TargetLeaseStore()
        let router = Router(context: BasicRequestContext.self)
        registerTargetLeaseRoutes(on: router, store: store)
        let app = Application(router: router)

        try await app.test(.router) { client in
            let acquireBody = try body(TKTargetLeaseAcquireRequest(
                target: "sim:\(udid)",
                owner: "agent-a",
                ttlSeconds: 120,
                readonlyObservationAllowed: true
            ))
            let first = try await client.execute(uri: "/v1/target-leases/acquire", method: .post, headers: [.contentType: "application/json"], body: acquireBody)
            #expect(first.status == .ok)
            let firstResponse = try decodeAcquire(first.body)
            #expect(firstResponse.ok)
            #expect(firstResponse.status == "acquired")
            #expect(firstResponse.lease?.owner == "agent-a")
            #expect(firstResponse.lease?.ttlSeconds == 120)
            #expect(firstResponse.lease?.target == udid)

            let conflictBody = try body(TKTargetLeaseAcquireRequest(
                target: "sim:\(udid)",
                owner: "agent-b",
                ttlSeconds: nil,
                readonlyObservationAllowed: nil
            ))
            let second = try await client.execute(uri: "/v1/target-leases/acquire", method: .post, headers: [.contentType: "application/json"], body: conflictBody)
            #expect(second.status == .conflict)
            let conflict = try decodeConflict(second.body)
            #expect(conflict.error.code == "target_lease_conflict")
            #expect(conflict.error.leaseReason == "held_by_other")
            #expect(conflict.error.currentOwner == "agent-a")
            #expect(conflict.error.currentLeaseID == firstResponse.lease?.id)
            #expect(conflict.error.suggestedCommands?.contains { $0.contains("target lease status") } == true)
        }
    }

    @Test("status reports none then held")
    func statusRoundTrip() async throws {
        let store = TargetLeaseStore()
        let router = Router(context: BasicRequestContext.self)
        registerTargetLeaseRoutes(on: router, store: store)
        let app = Application(router: router)

        try await app.test(.router) { client in
            let none = try await client.execute(uri: "/v1/target-leases/status?target=\(udid)", method: .get)
            #expect(none.status == .ok)
            let noneResponse = try decodeStatus(none.body)
            #expect(noneResponse.status == "none")
            #expect(noneResponse.lease == nil)

            let acquireBody = try body(TKTargetLeaseAcquireRequest(target: udid, owner: "agent-a", ttlSeconds: nil, readonlyObservationAllowed: nil))
            _ = try await client.execute(uri: "/v1/target-leases/acquire", method: .post, headers: [.contentType: "application/json"], body: acquireBody)

            let held = try await client.execute(uri: "/v1/target-leases/status?target=\(udid)", method: .get)
            let heldResponse = try decodeStatus(held.body)
            #expect(heldResponse.status == "held")
            #expect(heldResponse.lease?.owner == "agent-a")
        }
    }

    @Test("release succeeds for the holder and conflicts for a wrong token")
    func releaseRoundTrip() async throws {
        let store = TargetLeaseStore()
        let router = Router(context: BasicRequestContext.self)
        registerTargetLeaseRoutes(on: router, store: store)
        let app = Application(router: router)

        try await app.test(.router) { client in
            let acquireBody = try body(TKTargetLeaseAcquireRequest(target: udid, owner: "agent-a", ttlSeconds: nil, readonlyObservationAllowed: nil))
            let acquired = try await client.execute(uri: "/v1/target-leases/acquire", method: .post, headers: [.contentType: "application/json"], body: acquireBody)
            let acquireResponse = try decodeAcquire(acquired.body)
            let leaseID = try #require(acquireResponse.lease?.id)

            let wrongToken = try body(TKTargetLeaseReleaseRequest(target: udid, leaseID: "wrong-token"))
            let conflict = try await client.execute(uri: "/v1/target-leases/release", method: .post, headers: [.contentType: "application/json"], body: wrongToken)
            #expect(conflict.status == .conflict)
            let conflictResponse = try decodeConflict(conflict.body)
            #expect(conflictResponse.error.leaseReason == "lease_release_denied")
            #expect(conflictResponse.error.currentOwner == "agent-a")

            let releaseBody = try body(TKTargetLeaseReleaseRequest(target: udid, leaseID: leaseID))
            let released = try await client.execute(uri: "/v1/target-leases/release", method: .post, headers: [.contentType: "application/json"], body: releaseBody)
            #expect(released.status == .ok)
            let releaseResponse = try decodeRelease(released.body)
            #expect(releaseResponse.released)
            #expect(releaseResponse.status == "released")
            #expect(releaseResponse.lease?.id == leaseID)

            let again = try await client.execute(uri: "/v1/target-leases/release", method: .post, headers: [.contentType: "application/json"], body: releaseBody)
            let againResponse = try decodeRelease(again.body)
            #expect(!againResponse.released)
            #expect(againResponse.status == "none")
        }
    }

    @Test("takeover requires confirm and then displaces the owner")
    func takeoverRoundTrip() async throws {
        let store = TargetLeaseStore()
        let router = Router(context: BasicRequestContext.self)
        registerTargetLeaseRoutes(on: router, store: store)
        let app = Application(router: router)

        try await app.test(.router) { client in
            let acquireBody = try body(TKTargetLeaseAcquireRequest(target: udid, owner: "agent-a", ttlSeconds: nil, readonlyObservationAllowed: nil))
            _ = try await client.execute(uri: "/v1/target-leases/acquire", method: .post, headers: [.contentType: "application/json"], body: acquireBody)

            let noConfirm = try body(TKTargetLeaseTakeoverRequest(target: udid, owner: "agent-b", ttlSeconds: nil, readonlyObservationAllowed: nil, confirm: false))
            let blocked = try await client.execute(uri: "/v1/target-leases/takeover", method: .post, headers: [.contentType: "application/json"], body: noConfirm)
            #expect(blocked.status == .conflict)
            let blockedResponse = try decodeConflict(blocked.body)
            #expect(blockedResponse.error.leaseReason == "lease_takeover_required")
            #expect(blockedResponse.error.currentOwner == "agent-a")

            let confirm = try body(TKTargetLeaseTakeoverRequest(target: udid, owner: "agent-b", ttlSeconds: 120, readonlyObservationAllowed: false, confirm: true))
            let taken = try await client.execute(uri: "/v1/target-leases/takeover", method: .post, headers: [.contentType: "application/json"], body: confirm)
            #expect(taken.status == .ok)
            let takenResponse = try decodeAcquire(taken.body)
            #expect(takenResponse.status == "taken_over")
            #expect(takenResponse.previousOwner == "agent-a")
            #expect(takenResponse.lease?.owner == "agent-b")
            #expect(takenResponse.lease?.readonlyObservationAllowed == false)
        }
    }

    @Test("check authorizes the holder and rejects other owners")
    func checkRoundTrip() async throws {
        let store = TargetLeaseStore()
        let router = Router(context: BasicRequestContext.self)
        registerTargetLeaseRoutes(on: router, store: store)
        let app = Application(router: router)

        try await app.test(.router) { client in
            let acquireBody = try body(TKTargetLeaseAcquireRequest(target: udid, owner: "agent-a", ttlSeconds: nil, readonlyObservationAllowed: nil))
            let acquired = try await client.execute(uri: "/v1/target-leases/acquire", method: .post, headers: [.contentType: "application/json"], body: acquireBody)
            let leaseID = try #require(try decodeAcquire(acquired.body).lease?.id)

            let okBody = try body(TKTargetLeaseCheckRequest(target: "sim:\(udid)", leaseID: leaseID))
            let ok = try await client.execute(uri: "/v1/target-leases/check", method: .post, headers: [.contentType: "application/json"], body: okBody)
            #expect(ok.status == .ok)
            let okResponse = try decodeCheck(ok.body)
            #expect(okResponse.authorized)
            #expect(okResponse.reason == "lease_matched")

            let conflictBody = try body(TKTargetLeaseCheckRequest(target: udid, leaseID: "other-token"))
            let conflict = try await client.execute(uri: "/v1/target-leases/check", method: .post, headers: [.contentType: "application/json"], body: conflictBody)
            #expect(conflict.status == .conflict)
            let conflictResponse = try decodeConflict(conflict.body)
            #expect(conflictResponse.error.code == "target_lease_conflict")
            #expect(conflictResponse.error.leaseReason == "held_by_other")
            #expect(conflictResponse.error.currentOwner == "agent-a")
        }
    }

    @Test("validation failures are machine-readable")
    func validationFailuresAreMachineReadable() async throws {
        let store = TargetLeaseStore()
        let router = Router(context: BasicRequestContext.self)
        registerTargetLeaseRoutes(on: router, store: store)
        let app = Application(router: router)

        try await app.test(.router) { client in
            let badTTL = try body(TKTargetLeaseAcquireRequest(target: udid, owner: "agent-a", ttlSeconds: 5, readonlyObservationAllowed: nil))
            let response = try await client.execute(uri: "/v1/target-leases/acquire", method: .post, headers: [.contentType: "application/json"], body: badTTL)
            #expect(response.status == .badRequest)
            let error = try decodeConflict(response.body)
            #expect(error.error.code == "lease_ttl_out_of_range")
        }
    }

    private func decodeAcquire(_ body: ByteBuffer) throws -> TKTargetLeaseAcquireResponse {
        try JSONDecoder().decode(TKTargetLeaseAcquireResponse.self, from: Data(buffer: body))
    }

    private func decodeStatus(_ body: ByteBuffer) throws -> TKTargetLeaseStatusResponse {
        try JSONDecoder().decode(TKTargetLeaseStatusResponse.self, from: Data(buffer: body))
    }

    private func decodeRelease(_ body: ByteBuffer) throws -> TKTargetLeaseReleaseResponse {
        try JSONDecoder().decode(TKTargetLeaseReleaseResponse.self, from: Data(buffer: body))
    }

    private func decodeCheck(_ body: ByteBuffer) throws -> TKTargetLeaseCheckResponse {
        try JSONDecoder().decode(TKTargetLeaseCheckResponse.self, from: Data(buffer: body))
    }

    private func decodeConflict(_ body: ByteBuffer) throws -> TKCLIErrorResponse {
        try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(buffer: body))
    }
}
