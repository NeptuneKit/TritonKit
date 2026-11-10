import ArgumentParser
import Foundation
import TritonKit
import TritonKitShared

func requestHierarchyDetails(_ request: TKHierarchyDetailsRequest, client: TritonKitHTTPClient) async throws -> Data {
    if let reason = request.validationError { throw ValidationError(reason) }
    return try await client.request(type: "hierarchyDetails", payload: JSONEncoder().encode(request))
}

/// Validate before printing: even HTTP 200 can carry a capability/target failure.
/// The existing error envelope and typed partial response are each emitted exactly once.
func emitHierarchyDetails(_ data: Data, requestedOIDs: [UInt], outputFormat: ClientOutputFormat) throws {
    let decoder = JSONDecoder()
    if let response = try? decoder.decode(TKHierarchyDetailsResponse.self, from: data) {
        let actualOIDs = response.details.map(\.displayItemOid)
        guard Set(actualOIDs).count == actualOIDs.count,
              Set(actualOIDs).isSubset(of: Set(requestedOIDs)) else {
            throw RuntimeError("Hierarchy details returned duplicate or unexpected object IDs")
        }
        if response.ok {
            guard !response.partial, response.error == nil,
                  Set(actualOIDs) == Set(requestedOIDs),
                  response.details.allSatisfy({ $0.failureCode == 0 }) else {
                throw RuntimeError("Hierarchy details reported success with incomplete or failed results")
            }
        }
        switch outputFormat {
        case .json:
            print(try prettyJSON(data))
        case .text:
            print("ok: \(response.ok)")
            print("partial: \(response.partial)")
            for detail in response.details {
                print("oid: \(detail.displayItemOid)")
                print("  frame: \(detail.frameValue)")
                print("  attributes: \(detail.attributesGroupList.count)")
                print("  solo PNG bytes: \(detail.soloScreenshot?.count ?? 0)")
                print("  group PNG bytes: \(detail.groupScreenshot?.count ?? 0)")
                if detail.failureCode != 0 {
                    print("  failure: \(detail.failureReason ?? String(detail.failureCode))")
                }
            }
            if let error = response.error { print("error: \(error.code) \(error.message)") }
        }
        if !response.ok { throw ExitCode.failure }
        return
    }
    if let failure = try? decoder.decode(TKCLIErrorResponse.self, from: data), !failure.ok {
        switch outputFormat {
        case .json: print(try prettyJSON(data))
        case .text: print("error: \(failure.error.code) \(failure.error.message)")
        }
        throw ExitCode.failure
    }
    throw RuntimeError("Runtime returned an invalid hierarchy details response")
}

func hierarchyDetailsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "hierarchy.details", format: "json", kind: "node-details",
        model: "TKHierarchyDetailsResponse", fields: schemaContractFields([
            ("ok", "Bool", true, "True only when every requested node completes successfully"),
            ("partial", "Bool", true, "Some nodes succeeded and some failed; false does not imply success"),
            ("details", "[TKDisplayItemDetail]", true, "Bounded per-object detail results for the selected runtime target"),
            ("details[].displayItemOid", "UInt", true, "Requested view or layer OID, scoped to the current runtime process"),
            ("details[].soloScreenshot", "Data?", false, "Base64 PNG containing the selected layer without descendants"),
            ("details[].groupScreenshot", "Data?", false, "Base64 PNG containing the selected layer and visible descendants"),
            ("details[].screenshotScale", "Double?", false, "Raster scale after the pixel budget is applied"),
            ("details[].frameValue", "CGRect", true, "Current frame geometry"),
            ("details[].boundsValue", "CGRect", true, "Current local bounds"),
            ("details[].attributesGroupList", "[TKAttributesGroup]", true, "Live attributes, empty when not requested"),
            ("details[].failureCode", "Int", true, "Zero for successful detail; nonzero requires inspecting failureReason"),
            ("details[].failureReason", "String?", false, "Stable per-node failure reason"),
            ("error", "TKHierarchyDetailsError?", false, "Global validation/platform failure or partial/failed summary"),
            ("error.code", "String", false, "Stable machine-readable error code"),
            ("error.message", "String", false, "Human-readable failure explanation"),
            ("outcome", "String?", false, "Runtime UI admission outcome when capture could not begin"),
            ("uiHealth", "TKRuntimeUIHealthSnapshot?", false, "Runtime UI health attached to admission failures"),
        ]))
}
