import Foundation
import TritonKitShared

/// The host runner is injectable so collection-cell fallback policy can be tested
/// without starting a Simulator or invoking a real Baguette installation.
typealias CollectionCellHostHIDInputRunner = (String, TKInputRequest) throws -> TKInputResult

let collectionCellEmbeddedUnsupportedStrategy = "ancestor-collection-cell-unsupported"
let collectionCellHostHIDStrategy = "host-hid-coordinate-tap"

func collectionCellHostHIDAXResolution(
    node: TKAXNode,
    query: String,
    request: TKInputRequest,
    activationStrategy: TKTapActivationStrategy
) -> TapTargetResolution {
    let candidate = TapTargetCandidate(
        index: 1,
        query: query,
        source: "ax",
        strategy: tapCandidateStrategy(for: node, activationStrategy: activationStrategy),
        role: node.role,
        label: node.label,
        value: node.value,
        identifier: node.identifier,
        className: node.className,
        viewOID: node.viewOID,
        targetOID: node.targetOID,
        layerOID: node.layerOID,
        frame: node.frame,
        request: request
    )
    return TapTargetResolution(selected: candidate, candidates: [candidate], includeCandidates: false)
}

func isUnsupportedCollectionCellResult(_ result: TKInputResult) -> Bool {
    result.strategy == collectionCellEmbeddedUnsupportedStrategy
        && result.error?.code == "unsupported_capability"
}

func collectionCellHostHIDVerification(
    query: String,
    target: String
) -> TKInputVerificationBoundary {
    TKInputVerificationBoundary(
        hint: "Host-HID submission only confirms coordinate delivery; verify the settled business postcondition separately.",
        suggestedCommands: [
            "triton verify text-exists <expected-postcondition> --target \(target) --json",
            "triton wait --text <expected-postcondition> --target \(target) --json",
            "triton observe current --target \(target) --json",
        ]
    )
}

func collectionCellHostHIDTapRequest(
    resolution: TapTargetResolution,
    screenGeometry: TKGeometryResponse
) -> Result<TKInputRequest, CollectionCellHostHIDResolutionError> {
    guard let frame = resolution.frame,
          finitePositive(frame.width),
          finitePositive(frame.height),
          frame.x.isFinite,
          frame.y.isFinite,
          frame.centerX.isFinite,
          frame.centerY.isFinite else {
        return .failure(.missingMatchedGeometry)
    }

    let bounds = screenGeometry.bounds
    guard finitePositive(bounds.width),
          finitePositive(bounds.height),
          bounds.x.isFinite,
          bounds.y.isFinite,
          bounds.contains(x: frame.centerX, y: frame.centerY) else {
        return .failure(.invalidScreenGeometry)
    }

    return .success(TKInputRequest.tap(
        x: frame.centerX,
        y: frame.centerY,
        targetOID: resolution.targetOID ?? resolution.viewOID,
        width: bounds.width,
        height: bounds.height,
        matchedOID: resolution.viewOID ?? resolution.targetOID,
        matchedClassName: resolution.className,
        activationStrategy: .exact
    ))
}

func collectionCellHostHIDFallbackResult(
    embeddedResult: TKInputResult,
    resolution: TapTargetResolution,
    runtimeTarget: TKTargetSummary,
    screenGeometry: TKGeometryResponse?,
    hostInput: @escaping CollectionCellHostHIDInputRunner
) -> TKInputResult {
    guard isUnsupportedCollectionCellResult(embeddedResult) else {
        return embeddedResult
    }

    let matchedOID = resolution.viewOID ?? resolution.targetOID ?? embeddedResult.matchedOID
    let matchedClassName = resolution.className ?? embeddedResult.matchedClassName
    let frame = resolution.frame
    let target = runtimeTarget.id
    let verification = collectionCellHostHIDVerification(query: resolution.query, target: target)

    guard runtimeTarget.platform == "ios",
          runtimeTarget.connected,
          let simulatorUDID = runtimeTarget.simulatorUDID,
          !simulatorUDID.isEmpty else {
        return TKInputResult.failure(
            action: embeddedResult.action,
            message: "Host-HID UICollectionViewCell fallback is scoped to a connected iOS Simulator runtime target.",
            targetOID: embeddedResult.targetOID,
            targetClassName: embeddedResult.targetClassName,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationOID: embeddedResult.activationOID,
            activationClassName: embeddedResult.activationClassName,
            strategy: collectionCellEmbeddedUnsupportedStrategy,
            source: "embedded",
            geometry: frame,
            fallbackFromStrategy: collectionCellEmbeddedUnsupportedStrategy,
            verification: verification,
            error: TKCLIErrorDetail(
                code: "unsupported_scope",
                message: "Host-HID UICollectionViewCell fallback is scoped to a connected iOS Simulator runtime target.",
                hint: "Use an iOS Simulator target with simulatorUDID; real-device and non-iOS fallback is not supported.",
                suggestedCommands: ["triton schema --command act --json"]
            )
        )
    }

    guard let screenGeometry else {
        return TKInputResult.failure(
            action: embeddedResult.action,
            message: "Host-HID UICollectionViewCell fallback requires fresh runtime screen geometry.",
            targetOID: embeddedResult.targetOID,
            targetClassName: embeddedResult.targetClassName,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationOID: embeddedResult.activationOID,
            activationClassName: embeddedResult.activationClassName,
            strategy: collectionCellEmbeddedUnsupportedStrategy,
            source: "embedded",
            geometry: frame,
            fallbackFromStrategy: collectionCellEmbeddedUnsupportedStrategy,
            verification: verification,
            error: TKCLIErrorDetail(
                code: "geometry_required",
                message: "Host-HID UICollectionViewCell fallback requires fresh runtime screen geometry.",
                hint: "Retry after `triton observe current --target \(target) --json` succeeds.",
                suggestedCommands: ["triton observe current --target \(target) --json"]
            )
        )
    }

    let request: TKInputRequest
    switch collectionCellHostHIDTapRequest(resolution: resolution, screenGeometry: screenGeometry) {
    case .success(let value):
        request = value
    case .failure(let error):
        return TKInputResult.failure(
            action: embeddedResult.action,
            message: error.message,
            targetOID: embeddedResult.targetOID,
            targetClassName: embeddedResult.targetClassName,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationOID: embeddedResult.activationOID,
            activationClassName: embeddedResult.activationClassName,
            strategy: collectionCellEmbeddedUnsupportedStrategy,
            source: "embedded",
            geometry: frame,
            fallbackFromStrategy: collectionCellEmbeddedUnsupportedStrategy,
            verification: verification,
            error: TKCLIErrorDetail(
                code: "geometry_required",
                message: error.message,
                hint: "Only finite, positive, on-screen matched geometry may be sent to host HID.",
                suggestedCommands: ["triton observe current --target \(target) --json"]
            )
        )
    }

    let hostTargetID = "host:ios:\(simulatorUDID)"
    do {
        let hostResult = try hostInput(hostTargetID, request)
        let hostMessage = hostResult.ok
            ? "Embedded UICollectionViewCell activation was unsupported; submitted a coordinate tap through the iOS Simulator host-HID adapter."
            : (hostResult.message ?? "The iOS Simulator host-HID fallback was not accepted.")
        let hostError = hostResult.ok ? nil : (hostResult.error ?? TKCLIErrorDetail(
            code: "host_command_failed",
            message: hostMessage,
            hint: "Verify the Simulator is booted and the host-HID adapter is available, then retry."
        ))
        return TKInputResult(
            ok: hostResult.ok,
            action: embeddedResult.action,
            message: hostMessage,
            targetOID: embeddedResult.targetOID,
            targetClassName: embeddedResult.targetClassName,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationOID: embeddedResult.activationOID,
            activationClassName: embeddedResult.activationClassName,
            strategy: hostResult.ok ? collectionCellHostHIDStrategy : "\(collectionCellHostHIDStrategy)-failed",
            source: "host-hid",
            geometry: frame,
            fallbackFromStrategy: collectionCellEmbeddedUnsupportedStrategy,
            verification: verification,
            sourceCommands: hostResult.sourceCommands,
            error: hostError
        )
    } catch {
        let message = "The iOS Simulator host-HID fallback failed: \(error)"
        return TKInputResult.failure(
            action: embeddedResult.action,
            message: message,
            targetOID: embeddedResult.targetOID,
            targetClassName: embeddedResult.targetClassName,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationOID: embeddedResult.activationOID,
            activationClassName: embeddedResult.activationClassName,
            strategy: "\(collectionCellHostHIDStrategy)-failed",
            source: "host-hid",
            geometry: frame,
            fallbackFromStrategy: collectionCellEmbeddedUnsupportedStrategy,
            verification: verification,
            error: TKCLIErrorDetail(
                code: "host_command_failed",
                message: message,
                hint: "Verify the Simulator is booted and the host-HID adapter is available, then retry.",
                suggestedCommands: ["triton sim tap --simulator \(simulatorUDID) --x \(Int(request.x?.rounded() ?? 0)) --y \(Int(request.y?.rounded() ?? 0)) --json"]
            )
        )
    }
}

enum CollectionCellHostHIDResolutionError: Error, Equatable {
    case missingMatchedGeometry
    case invalidScreenGeometry

    var message: String {
        switch self {
        case .missingMatchedGeometry:
            return "Resolved UICollectionViewCell match has no finite, positive geometry."
        case .invalidScreenGeometry:
            return "Runtime screen geometry is invalid or the matched UICollectionViewCell center is off-screen."
        }
    }
}

private func finitePositive(_ value: Double) -> Bool {
    value.isFinite && value > 0
}
