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

    @MainActor
    @Test("UISlider swipe sets value from end coordinate")
    func sliderSwipeSetsValueFromEndCoordinate() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        let slider = UISlider(frame: CGRect(x: 40, y: 40, width: 200, height: 40))
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        window.addSubview(slider)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let request = TKInputRequest.swipe(
            startX: 140,
            startY: 60,
            endX: 200,
            endY: 60
        )

        let result = performSwipe(request)

        #expect(result.ok)
        #expect(result.strategy == "slider-drag")
        #expect(slider.value > 75)
        #expect(slider.value < 85)
    }

    @MainActor
    @Test("deleteBackward removes one character from focused UIKeyInput")
    func deleteBackwardRemovesOneCharacterFromFocusedInput() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        let textField = UITextField(frame: CGRect(x: 20, y: 20, width: 200, height: 44))
        textField.text = "abc"
        window.addSubview(textField)
        window.makeKeyAndVisible()
        textField.becomeFirstResponder()
        defer { window.isHidden = true }

        let result = await performInput(.deleteBackward())

        #expect(result.ok)
        #expect(result.action == "deleteBackward")
        #expect(result.message == "Deleted backward")
        #expect(result.deletedLength == 1)
        #expect(textField.text == "ab")
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
