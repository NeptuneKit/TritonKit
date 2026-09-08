import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

func collectionCellHostHIDRetryCommand(for request: TKInputRequest, matchedOID: UInt?) -> String? {
    guard let matchedOID else { return nil }
    let strategy = request.activationStrategy ?? .smart
    return "triton act tap --ax-oid \(matchedOID) --strategy \(strategy.rawValue) --allow-host-hid-fallback --target <ios-simulator-runtime-target> --json"
}

func collectionCellHostHIDVerificationBoundary() -> TKInputVerificationBoundary {
    TKInputVerificationBoundary(
        hint: "Host-HID submission only confirms coordinate delivery; verify the settled business postcondition separately.",
        suggestedCommands: [
            "triton verify text-exists <expected-postcondition> --target <ios-simulator-runtime-target> --json",
            "triton wait --text <expected-postcondition> --target <ios-simulator-runtime-target> --json",
            "triton observe current --target <ios-simulator-runtime-target> --json",
        ]
    )
}

func collectionCellSelectionVerificationBoundary() -> TKInputVerificationBoundary {
    TKInputVerificationBoundary(
        hint: "Embedded selection invoked the public UICollectionViewDelegate callbacks; verify the visible business postcondition before claiming completion.",
        suggestedCommands: [
            "triton verify text-exists <expected-postcondition> --target <ios-simulator-runtime-target> --json",
            "triton wait --text <expected-postcondition> --target <ios-simulator-runtime-target> --json",
            "triton observe current --target <ios-simulator-runtime-target> --json",
        ]
    )
}

#if canImport(UIKit)
import UIKit

@MainActor
func performTapGestureAccessibilityActivation(
    from view: UIView,
    within collectionCell: UICollectionViewCell,
    request: TKInputRequest,
    action: String,
    matchedView: UIView?
) -> TKInputResult? {
    guard let candidate = nearestTapGestureCandidate(from: view, stoppingAt: collectionCell),
          candidate.view.accessibilityActivate() else {
        return nil
    }

    let matched = tapMatchedContext(request, fallback: matchedView ?? view)
    let activationOID = oid(for: candidate.view)
    let activationClassName = NSStringFromClass(type(of: candidate.view))
    return TKInputResult.success(
        action: action,
        message: "Activated tap gesture view via accessibilityActivate",
        targetOID: activationOID,
        targetClassName: activationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        strategy: "tap-gesture-accessibility-activate"
    )
}

@MainActor
func collectionCellContaining(request: TKInputRequest) -> UICollectionViewCell? {
    guard let point = inputPoint(from: request) else { return nil }
    for window in keyWindows() {
        for collectionView in allSubviews(of: window, matching: UICollectionView.self) where isInteractable(collectionView) {
            let collectionPoint = collectionView.convert(point, from: nil)
            guard collectionView.bounds.contains(collectionPoint),
                  let indexPath = collectionView.indexPathForItem(at: collectionPoint) else {
                continue
            }
            if let cell = collectionView.cellForItem(at: indexPath) {
                return cell
            }
        }
    }
    return nil
}

@MainActor
func performCollectionCellTap(
    _ cell: UICollectionViewCell,
    request: TKInputRequest,
    action: String,
    matchedView: UIView
) -> TKInputResult? {
    guard let collectionView = nearestSuperview(of: cell, matching: UICollectionView.self),
          let indexPath = collectionView.indexPath(for: cell) else {
        return nil
    }

    let matched = tapMatchedContext(request, fallback: matchedView)
    let originalActivationOID = oid(for: cell)
    let originalActivationClassName = NSStringFromClass(type(of: cell))

    guard collectionView.allowsSelection, cell.isUserInteractionEnabled else {
        let message = "UICollectionViewCell ancestor is not selectable"
        return TKInputResult.failure(
            action: action,
            message: message,
            targetOID: originalActivationOID,
            targetClassName: originalActivationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: originalActivationOID,
            activationClassName: originalActivationClassName,
            strategy: "ancestor-collection-cell-selection-blocked",
            error: TKCLIErrorDetail(
                code: "collection_cell_selection_blocked",
                message: message,
                hint: "The collection view has allowsSelection disabled or the cell is not user-interactive; enable selection in the app instead of bypassing delegate eligibility.",
                suggestedCommands: ["triton schema --command act --json"]
            )
        )
    }

    if collectionView.delegate?.responds(to: #selector(UICollectionViewDelegate.collectionView(_:shouldSelectItemAt:))) == true {
        guard collectionView.delegate?.collectionView?(collectionView, shouldSelectItemAt: indexPath) == true else {
            let message = "UICollectionViewCell ancestor selection was denied by delegate"
            return TKInputResult.failure(
                action: action,
                message: message,
                targetOID: originalActivationOID,
                targetClassName: originalActivationClassName,
                matchedOID: matched.oid,
                matchedClassName: matched.className,
                activationOID: originalActivationOID,
                activationClassName: originalActivationClassName,
                strategy: "ancestor-collection-cell-selection-denied",
                error: TKCLIErrorDetail(
                    code: "collection_cell_selection_denied",
                    message: message,
                    hint: "The app delegate rejected collectionView(_:shouldSelectItemAt:) for the resolved index path; the cell stays unselected and no didSelectItemAt callback fires.",
                    suggestedCommands: ["triton schema --command act --json"]
                )
            )
        }
    }

    collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    guard collectionView.indexPathsForSelectedItems?.contains(indexPath) == true else {
        let message = "UICollectionViewCell ancestor selection state did not update"
        return TKInputResult.failure(
            action: action,
            message: message,
            targetOID: originalActivationOID,
            targetClassName: originalActivationClassName,
            matchedOID: matched.oid,
            matchedClassName: matched.className,
            activationOID: originalActivationOID,
            activationClassName: originalActivationClassName,
            strategy: "ancestor-collection-cell-selection-failed"
        )
    }
    collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: indexPath)

    return TKInputResult.success(
        action: action,
        message: "Selected UICollectionViewCell ancestor and invoked delegate callback",
        targetOID: originalActivationOID,
        targetClassName: originalActivationClassName,
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: originalActivationOID,
        activationClassName: originalActivationClassName,
        strategy: "ancestor-collection-cell-selection",
        verification: collectionCellSelectionVerificationBoundary()
    )
}

@MainActor
func unsupportedCollectionCellTap(
    _ cell: UICollectionViewCell,
    request: TKInputRequest,
    action: String,
    matchedView: UIView
) -> TKInputResult {
    let matched = tapMatchedContext(request, fallback: matchedView)
    let activationOID = oid(for: cell)
    let activationClassName = NSStringFromClass(type(of: cell))
    let message = "UICollectionViewCell could not be resolved for a safe public selection path"
    let retryCommand = collectionCellHostHIDRetryCommand(for: request, matchedOID: matched.oid)
    let verification = collectionCellHostHIDVerificationBoundary()
    return TKInputResult.unsupported(
        action: action,
        message: message,
        strategy: "ancestor-collection-cell-unsupported",
        matchedOID: matched.oid,
        matchedClassName: matched.className,
        activationOID: activationOID,
        activationClassName: activationClassName,
        error: TKCLIErrorDetail(
            code: "unsupported_capability",
            message: message,
            hint: "The cell is not attached to a resolvable UICollectionView index path, so no public selection API can be invoked safely. Retry explicitly with --allow-host-hid-fallback on a connected iOS Simulator, or use a public UIControl, accessibility-activatable gesture, or app-owned semantic DEBUG action.",
            suggestedCommands: (retryCommand.map { [$0] } ?? []) + [
                "triton schema --command act --json",
            ] + verification.suggestedCommands
        ),
        verification: verification
    )
}

#endif
