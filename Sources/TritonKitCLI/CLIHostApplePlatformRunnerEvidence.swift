import Foundation
import TritonKitShared

struct ApplePlatformRunnerEvidenceSession {
    let writer: TKEvidenceRunLogWriter
    let runID: String
    let target: TKEvidenceRunTarget

    init(directory: String, request: HostApplePlatformRunnerRequest) throws {
        let runID = "platform-control-" + request.nonce
        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        self.writer = try TKEvidenceRunLogWriter(
            evidenceDirectory: directoryURL,
            metadata: TKEvidenceRunMetadata(
                runID: runID,
                caseName: "device.platform-control",
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        )
        self.runID = runID
        self.target = TKEvidenceRunTarget(
            platform: request.platform.rawValue,
            simulatorUDID: request.device,
            runtimeTargetID: "host:apple-platform:\(request.device)"
        )
        try writer.append(TKEvidenceRunEvent(
            runID: runID,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            kind: .runStarted,
            caseName: "device.platform-control",
            mode: "explicit-runner",
            target: target
        ))
        try writer.append(TKEvidenceRunEvent(
            runID: runID,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            kind: .stepStarted,
            target: target,
            step: 1,
            source: "triton.device.platform-control"
        ))
        try writer.append(TKEvidenceRunEvent(
            runID: runID,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            kind: .toolCall,
            step: 1,
            source: "triton.device.platform-control",
            tool: "device.platform-control",
            scope: "host-runner",
            input: [
                "platform": .string(request.platform.rawValue),
                "action": .string(request.action.rawValue),
                "target": .string(request.device)
            ]
        ))
    }

    func finish(receipt: inout HostApplePlatformRunnerReceipt) {
        do {
            let receiptData = try JSONEncoder().encode(receipt)
            let receiptRef = try writer.writeArtifact(receiptData, relativePath: "run/action-receipt.json")
            let metadata = applePlatformRunnerActionEvidenceMetadata(receipt, evidenceRefs: [receiptRef])
            try writer.append(TKEvidenceRunEvent(
                runID: runID,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                kind: .toolResult,
                step: 1,
                source: "triton.device.platform-control",
                tool: "device.platform-control",
                success: receipt.ok,
                error: receipt.failureCode,
                artifactRefs: [receiptRef],
                status: receipt.terminalStatus ?? receipt.outcome.rawValue,
                actionContext: metadata
            ))
            try writer.append(TKEvidenceRunEvent(
                runID: runID,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                kind: .stepCompleted,
                step: 1,
                status: receipt.terminalStatus ?? receipt.outcome.rawValue,
                actionContext: metadata
            ))
            try writer.append(TKEvidenceRunEvent(
                runID: runID,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                kind: .runCompleted,
                verdict: receipt.ok ? .success : .failure,
                stepCount: 1,
                actionContext: metadata
            ))
            receipt.evidencePersistence = "written"
        } catch {
            receipt.evidencePersistence = "failed"
        }
    }
}
