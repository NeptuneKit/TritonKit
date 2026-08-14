import Foundation
import TritonKitShared

// MARK: - Target Lease Mutation Gate
//
// Mutating host/runtime commands call `enforceTargetLease` when the caller
// explicitly passes `--lease <id>`. The serve process decides atomically:
// - no check happens when `--lease` is omitted (opt-in, backward compatible);
// - a 409 `target_lease_conflict` envelope is thrown when the provided token
//   is not the currently held lease for the resolved target;
// - read-only observation commands never call this gate (exempt by policy).

func enforceTargetLease(
    host: String,
    port: Int,
    target: String,
    leaseID: String,
    session: URLSession = .shared
) async throws {
    let client = TritonKitHTTPClient(host: host, port: port, session: session)
    let _: TKTargetLeaseCheckResponse = try await client.postJSON(
        "/v1/target-leases/check",
        body: TKTargetLeaseCheckRequest(target: target, leaseID: leaseID)
    )
}
