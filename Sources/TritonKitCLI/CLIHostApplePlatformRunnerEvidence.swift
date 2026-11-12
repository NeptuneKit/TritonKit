import Foundation
import TritonKitShared

/// Export both the typed receipt and the original runner diagnostic response.
struct ApplePlatformRunnerEvidenceSession {
    private let session: ActionEvidenceSession
    var eventsURL: URL { session.directory.appendingPathComponent("run/events.jsonl") }

    init(directory: String, request: HostApplePlatformRunnerRequest) throws {
        let (context, _) = try makeApplePlatformRunnerActionContext(request)
        session = try ActionEvidenceSession(directory: directory, context: context, platform: request.platform.rawValue)
    }

    func finish(receipt: inout HostApplePlatformRunnerReceipt) {
        guard let shared = receipt.actionReceipt else {
            receipt.evidencePersistence = "failed"
            return
        }
        let raw: [ActionRawArtifact]
        if let data = receipt.providerResponseData {
            raw = [ActionRawArtifact(name: "provider-response.json", data: data, contentType: "application/json")]
        } else if let data = try? JSONEncoder().encode(receipt) {
            raw = [ActionRawArtifact(name: "runner-diagnostic.json", data: data, contentType: "application/json", fidelity: "derived-diagnostic")]
        } else { raw = [] }
        let finalized = session.finish(shared, rawArtifacts: raw)
        receipt.actionReceipt = finalized
        receipt.evidencePersistence = finalized.evidencePersistence.rawValue
    }
}
