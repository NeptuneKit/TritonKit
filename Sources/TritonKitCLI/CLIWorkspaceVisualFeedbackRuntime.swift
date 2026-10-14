import Foundation
import TritonKitShared

typealias TKWorkspaceVisualFeedbackProvider = (TKWorkspaceVisualFeedbackRequest) async -> VisualSettleOutput

struct TKWorkspaceVisualFeedbackRequest: Equatable {
    let target: String
    let device: String?
    let platform: String?
    let scope: String?
    let host: String
    let port: Int
    let runtimeBaseURL: String?
    let adb: String
    let hdc: String
    let configuration: VisualSettleConfiguration
}

func validateWorkspaceVisualFeedback(_ request: TKWorkspaceRunRequest) throws {
    guard let configuration = request.visualSettle else { return }
    _ = try VisualSettleConfiguration(changeThreshold: configuration.changeThreshold,
                                      pixelThreshold: configuration.pixelThreshold,
                                      stableWindow: configuration.stableWindow,
                                      interval: configuration.interval,
                                      timeout: configuration.timeout)
    guard request.observeLive, request.executeActions else {
        throw RuntimeError("Workspace visual settle requires --observe-live and --execute-actions.")
    }
}

func workspaceVisualFeedbackAllowsContinuation(_ feedback: VisualSettleOutput?) -> Bool {
    feedback == nil || feedback?.state == .settled
}

/// Unavailable visual feedback is audit evidence, not a newly captured screen.
/// Existing structure observations without visual settle keep their original event contract.
func workspaceHasCapturedPostActionObservation(_ observation: TKWorkspaceObservationSeed?) -> Bool {
    guard let observation else { return false }
    return workspaceVisualFeedbackAllowsContinuation(observation.visualFeedback)
}

func workspaceVisualFeedbackRequest(for request: TKWorkspaceRunRequest, configuration: VisualSettleConfiguration) -> TKWorkspaceVisualFeedbackRequest {
    // A declared host simulator/emulator is selected once by the provider. Runtime targets
    // remain connection IDs; converting one into a host device would select a different app.
    let scope = request.scope?.lowercased()
    let isHost = scope == "simulator" || scope == "emulator"
    return TKWorkspaceVisualFeedbackRequest(target: isHost ? TKLocalTargetID : workspaceRuntimeTarget(for: request),
                                            device: isHost ? request.target : nil,
                                            platform: request.platform, scope: request.scope,
                                            host: request.observeHost, port: request.observePort,
                                            runtimeBaseURL: request.observeRuntimeBaseURL.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                                            adb: request.adb, hdc: request.hdc,
                                            configuration: configuration)
}

func workspaceDefaultVisualFeedbackProvider(_ request: TKWorkspaceVisualFeedbackRequest) async -> VisualSettleOutput {
    let startedAt = ProcessInfo.processInfo.systemUptime
    do {
        let provider = try await VisualScreenshotProvider.make(device: request.device, target: request.target,
                                                               host: request.host, port: request.port,
                                                               timeout: request.configuration.timeout,
                                                               runtimeBaseURL: request.runtimeBaseURL,
                                                               adb: request.adb, hdc: request.hdc,
                                                               platform: request.device == nil ? nil : request.platform.flatMap(HostDevicePlatform.init(rawValue:)),
                                                               scope: request.device == nil ? nil : request.scope.flatMap(HostDeviceScope.init(rawValue:)))
        return await runVisualSettle(configuration: request.configuration, capture: { remaining in
            let image = try await provider.capture(timeout: remaining)
            return try visualScreenshotFrame(data: image.data, capturedAt: image.capturedAt,
                                             source: image.source, scale: image.scale)
        }, startedAt: startedAt)
    } catch {
        return VisualSettleOutput(ok: false, action: "observe.settle", state: .unknown,
                                  reason: "screenshot_provider_unavailable", businessVerified: false,
                                  elapsedMs: max(0, Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1000)),
                                  sampleCount: 0, lastChangeFraction: nil, capturedAt: nil, source: nil,
                                  configuration: request.configuration,
                                  comparisonPolicy: "changed RGB pixel area on a bounded screenshot thumbnail")
    }
}

/// When stability is unknown, preserve only real feedback. Do not call the same UI provider
/// again, fabricate a refreshed tree, or feed cached coordinates to another automatic action.
func workspaceUnavailableVisualObservation(_ feedback: VisualSettleOutput) throws -> TKWorkspaceObservationSeed {
    struct UnavailableObservation: Encodable {
        let available: Bool
        let action: String
        let reason: String
        let visualFeedback: VisualSettleOutput
    }
    let data = try JSONEncoder().encode(UnavailableObservation(available: false, action: "workspace.post-action-observation",
                                                              reason: "visual_" + feedback.state.rawValue, visualFeedback: feedback))
    var observation = TKWorkspaceObservationSeed(fixturePath: nil, fixtureRef: nil, rawObservationData: data,
                                                 artifacts: TKTestRunObservationArtifacts(),
                                                 screenCandidate: TKTestRunScreenCandidate(screenshotSha256: "unavailable", axTextHash: "unavailable",
                                                                                         hierarchySha256: "unavailable", visibleTexts: []),
                                                 sourceCommands: [], changed: nil)
    observation.visualFeedback = feedback
    return observation
}
