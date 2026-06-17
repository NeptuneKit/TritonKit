import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

@Suite
struct TKRuntimeInputActionsTests {
    @MainActor
    @Test("UIButton tap falls back to accessibilityActivate when target actions are absent")
    func buttonTapFallsBackToAccessibilityActivateWithoutTargetActions() {
        let button = ActivatingButton(type: .system)
        let request = TKInputRequest.tap(targetOID: nil)

        let result = performControlTap(
            button,
            request: request,
            action: "tap",
            matchedView: nil,
            strategy: nil
        )

        #expect(result.ok)
        #expect(button.didActivate)
        #expect(result.message == "Activated UIButton via accessibilityActivate")
        #expect(result.strategy == "uikit-accessibility-activate")
    }
}

private final class ActivatingButton: UIButton {
    var didActivate = false

    override func accessibilityActivate() -> Bool {
        didActivate = true
        return true
    }
}
#endif
