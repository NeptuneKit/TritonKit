#if canImport(UIKit)
import UIKit
import TritonKitShared

@MainActor
func isBarButtonSurface(_ view: UIView) -> Bool {
    nearestSuperview(of: view, matching: UINavigationBar.self) != nil
        || nearestSuperview(of: view, matching: UIToolbar.self) != nil
}

/// UIKit exposes UIBarButtonItem.target/action, but no public association from
/// a system-generated button view to that item. Matching its title alone could
/// invoke a different item, including one behind a modal or on the back stack.
@MainActor
func unsupportedBarButtonTap(_ view: UIView, request: TKInputRequest, action: String, matchedView: UIView?) -> TKInputResult {
    let matched = tapMatchedContext(request, fallback: matchedView ?? view)
    let activationOID = oid(for: view)
    let className = NSStringFromClass(type(of: view))
    let message = "Navigation/toolbar view has no public control activation and cannot be mapped safely to a UIBarButtonItem target/action. No bar item action was sent."
    return .failure(
        action: action, message: message,
        targetOID: activationOID, targetClassName: className,
        matchedOID: matched.oid, matchedClassName: matched.className,
        activationOID: activationOID, activationClassName: className,
        strategy: "bar-button-action-unsupported",
        error: TKCLIErrorDetail(
            code: "unsupported_capability", message: message,
            hint: "Use a customView UIControl with a public action or accessibilityActivate. For host recovery, select an explicit simulator target and freshly inspect its coordinates before sim tap; on a physical device use an already-ready, allowlisted Runner or a manual tap. Do not retry against background content. Host acknowledgement requires a separate business-state check.",
            suggestedCommands: ["triton device doctor --platform ios --scope simulator --device <simulator-target> --json", "triton sim ax --device <simulator-target> --json"]
        )
    )
}
#endif
