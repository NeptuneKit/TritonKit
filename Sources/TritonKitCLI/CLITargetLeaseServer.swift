import Foundation
import Hummingbird
import NIOCore
import TritonKitShared

// MARK: - Target Lease HTTP Routes (serve process)
//
// The `triton serve` process is the shared-state holder for target leases.
// These routes let parallel agent flows acquire/status/release/takeover and
// let mutating host/runtime commands authorize against the current lease.

private func targetLeaseRequestBodyData(from request: Request) async throws -> Data {
    var bodyData = Data()
    for try await chunk in request.body {
        bodyData.append(Data(buffer: chunk))
    }
    return bodyData
}

private func targetLeaseQueryParameter(_ name: String, from request: Request) -> String? {
    request.uri.queryParameters[Substring(name)].map(String.init)?.removingPercentEncoding
}

func registerTargetLeaseRoutes<Context: RequestContext>(
    on router: Router<Context>,
    store: TargetLeaseStore
) {
    router.post("/v1/target-leases/acquire") { request, _ -> Response in
        let endpoint = "/v1/target-leases/acquire"
        guard let bodyData = try? await targetLeaseRequestBodyData(from: request),
              let body = try? JSONDecoder().decode(TKTargetLeaseAcquireRequest.self, from: bodyData) else {
            return jsonError(
                code: "invalid_payload",
                message: "Unsupported target lease acquire payload",
                endpoint: endpoint,
                hint: "Send JSON with target, owner, and optional ttlSeconds/readonlyObservationAllowed.",
                status: .badRequest
            )
        }
        do {
            switch try store.acquire(
                target: body.target,
                owner: body.owner,
                ttlSeconds: body.ttlSeconds,
                readonlyObservationAllowed: body.readonlyObservationAllowed,
                now: Date()
            ) {
            case .acquired(let result):
                return jsonResponse(TKTargetLeaseAcquireResponse(
                    ok: true,
                    status: result.status,
                    target: result.lease.target,
                    lease: result.lease,
                    previousOwner: result.previousOwner
                ))
            case .conflict(let current):
                return targetLeaseConflictResponse(
                    target: TKNormalizeTargetLeaseKey(body.target),
                    reason: "held_by_other",
                    current: current,
                    hint: "Inspect `triton target lease status --target <udid> --json`; use `triton target lease takeover --target <udid> --owner <label> --confirm --json` to displace the current owner.",
                    endpoint: endpoint
                )
            }
        } catch let error as TargetLeaseStoreValidationError {
            return jsonError(code: error.code, message: error.message, endpoint: endpoint, hint: error.hint, status: .badRequest)
        } catch {
            return jsonError(code: "request_failed", message: "\(error)", endpoint: endpoint, status: .conflict)
        }
    }

    router.get("/v1/target-leases/status") { request, _ -> Response in
        let endpoint = "/v1/target-leases/status"
        guard let target = targetLeaseQueryParameter("target", from: request) else {
            return jsonError(
                code: "invalid_payload",
                message: "Missing target query parameter",
                endpoint: endpoint,
                hint: "Pass ?target=<simulator-udid-or-selector>.",
                status: .badRequest
            )
        }
        let status = store.status(target: target, now: Date())
        return jsonResponse(TKTargetLeaseStatusResponse(
            ok: true,
            target: TKNormalizeTargetLeaseKey(target),
            status: status.status,
            lease: status.lease
        ))
    }

    router.post("/v1/target-leases/release") { request, _ -> Response in
        let endpoint = "/v1/target-leases/release"
        guard let bodyData = try? await targetLeaseRequestBodyData(from: request),
              let body = try? JSONDecoder().decode(TKTargetLeaseReleaseRequest.self, from: bodyData) else {
            return jsonError(
                code: "invalid_payload",
                message: "Unsupported target lease release payload",
                endpoint: endpoint,
                hint: "Send JSON with target and leaseID.",
                status: .badRequest
            )
        }
        switch store.release(target: body.target, leaseID: body.leaseID, now: Date()) {
        case .released(let lease):
            return jsonResponse(TKTargetLeaseReleaseResponse(
                ok: true,
                released: true,
                status: "released",
                target: lease.target,
                lease: lease
            ))
        case .none:
            return jsonResponse(TKTargetLeaseReleaseResponse(
                ok: true,
                released: false,
                status: "none",
                target: TKNormalizeTargetLeaseKey(body.target),
                lease: nil
            ))
        case .conflict(let current):
            return targetLeaseConflictResponse(
                target: TKNormalizeTargetLeaseKey(body.target),
                reason: "lease_release_denied",
                current: current,
                hint: "The lease token does not match the current holder; inspect `triton target lease status --target <udid> --json`.",
                endpoint: endpoint
            )
        }
    }

    router.post("/v1/target-leases/takeover") { request, _ -> Response in
        let endpoint = "/v1/target-leases/takeover"
        guard let bodyData = try? await targetLeaseRequestBodyData(from: request),
              let body = try? JSONDecoder().decode(TKTargetLeaseTakeoverRequest.self, from: bodyData) else {
            return jsonError(
                code: "invalid_payload",
                message: "Unsupported target lease takeover payload",
                endpoint: endpoint,
                hint: "Send JSON with target, owner, confirm, and optional ttlSeconds/readonlyObservationAllowed.",
                status: .badRequest
            )
        }
        do {
            switch try store.takeover(
                target: body.target,
                owner: body.owner,
                ttlSeconds: body.ttlSeconds,
                readonlyObservationAllowed: body.readonlyObservationAllowed,
                confirm: body.confirm,
                now: Date()
            ) {
            case .acquired(let result):
                return jsonResponse(TKTargetLeaseAcquireResponse(
                    ok: true,
                    status: result.status,
                    target: result.lease.target,
                    lease: result.lease,
                    previousOwner: result.previousOwner
                ))
            case .conflict(let current):
                return targetLeaseConflictResponse(
                    target: TKNormalizeTargetLeaseKey(body.target),
                    reason: "lease_takeover_required",
                    current: current,
                    hint: "Takeover is the explicit displacement action; pass `--confirm` to take over the target lease.",
                    endpoint: endpoint
                )
            }
        } catch let error as TargetLeaseStoreValidationError {
            return jsonError(code: error.code, message: error.message, endpoint: endpoint, hint: error.hint, status: .badRequest)
        } catch {
            return jsonError(code: "request_failed", message: "\(error)", endpoint: endpoint, status: .conflict)
        }
    }

    router.post("/v1/target-leases/check") { request, _ -> Response in
        let endpoint = "/v1/target-leases/check"
        guard let bodyData = try? await targetLeaseRequestBodyData(from: request),
              let body = try? JSONDecoder().decode(TKTargetLeaseCheckRequest.self, from: bodyData) else {
            return jsonError(
                code: "invalid_payload",
                message: "Unsupported target lease check payload",
                endpoint: endpoint,
                hint: "Send JSON with target and leaseID.",
                status: .badRequest
            )
        }
        switch store.check(target: body.target, leaseID: body.leaseID, now: Date()) {
        case .authorized(let lease):
            return jsonResponse(TKTargetLeaseCheckResponse(
                ok: true,
                authorized: true,
                reason: "lease_matched",
                target: lease.target,
                lease: lease
            ))
        case .conflict(let reason, let current):
            return targetLeaseConflictResponse(
                target: TKNormalizeTargetLeaseKey(body.target),
                reason: reason,
                current: current,
                hint: targetLeaseConflictHint(reason: reason),
                endpoint: endpoint
            )
        }
    }
}

// MARK: - Conflict Envelope

/// Stable machine-readable conflict/recovery envelope for
/// `target_lease_conflict` failures, reused by every lease route.
func targetLeaseConflictResponse(
    target: String,
    reason: String,
    current: TKTargetLease?,
    hint: String?,
    endpoint: String
) -> Response {
    let detail = TKCLIErrorDetail(
        code: "target_lease_conflict",
        message: targetLeaseConflictMessage(reason: reason, target: target, current: current),
        endpoint: endpoint,
        hint: hint ?? targetLeaseConflictHint(reason: reason),
        suggestedCommands: targetLeaseConflictSuggestedCommands(target: target, reason: reason),
        leaseReason: reason,
        currentOwner: current?.owner,
        currentLeaseID: current?.id,
        currentExpiresAt: current?.expiresAt
    )
    return jsonResponse(TKCLIErrorResponse(error: detail, surface: "target-lease"), status: .conflict)
}

func targetLeaseConflictMessage(reason: String, target: String, current: TKTargetLease?) -> String {
    switch reason {
    case "held_by_other":
        let owner = current.map { " (\($0.owner))" } ?? ""
        return "Target \(target) is leased by another owner\(owner); mutating commands are blocked until the lease is released or explicitly taken over."
    case "lease_expired":
        return "The lease for target \(target) has expired; re-acquire it before running mutating commands."
    case "lease_not_held":
        return "No lease is currently held for target \(target); the provided lease token is not valid there."
    case "lease_release_denied":
        return "Target \(target) is leased by a different token; release was denied."
    case "lease_takeover_required":
        return "Target \(target) is leased by another owner; takeover requires an explicit confirm."
    default:
        return "Target \(target) lease conflict."
    }
}

func targetLeaseConflictHint(reason: String) -> String {
    switch reason {
    case "lease_expired", "lease_not_held":
        return "Acquire a fresh lease with `triton target lease acquire --target <udid> --owner <label> --json`."
    case "lease_takeover_required":
        return "Pass `--confirm` to take over the target lease and displace the current owner."
    default:
        return "Inspect `triton target lease status --target <udid> --json`, then release or take over the lease."
    }
}

func targetLeaseConflictSuggestedCommands(target: String, reason: String) -> [String] {
    switch reason {
    case "lease_takeover_required":
        return [
            "triton target lease status --target \(target) --json",
            "triton target lease takeover --target \(target) --owner <label> --confirm --json",
        ]
    case "lease_expired", "lease_not_held":
        return [
            "triton target lease acquire --target \(target) --owner <label> --json",
        ]
    default:
        return [
            "triton target lease status --target \(target) --json",
            "triton target lease release --target \(target) --lease <lease-id> --json",
            "triton target lease takeover --target \(target) --owner <label> --confirm --json",
        ]
    }
}
