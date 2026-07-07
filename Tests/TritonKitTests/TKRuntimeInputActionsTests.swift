import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

@Suite
struct TKRuntimeInputActionsTests {
    @MainActor
    @Test("UIControl tap falls back to accessibilityActivate when target actions are absent")
    func controlTapFallsBackToAccessibilityActivateWithoutTargetActions() {
        let button = ActivatingControl(frame: .zero)
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
        #expect(result.message == "Activated UIControl via accessibilityActivate")
        #expect(result.strategy == "uikit-accessibility-activate")
    }

    @MainActor
    @Test("UIControl target collection normalizes Objective-C sets without Swift Set bridging")
    func controlTargetCollectionNormalizesObjectiveCSets() {
        let target = ControlEventRecorder()
        let values = normalizedControlTargets(from: NSSet(array: [target, NSNull()]))

        #expect(values.count == 2)
        #expect(values.contains { ($0 as AnyObject?) === target })
        #expect(values.contains { $0 == nil })
        #expect(normalizedControlTargets(from: NSObject()).isEmpty)
    }

    @MainActor
    @Test("UIControl target action lookup skips non-NSObject targets")
    func controlTargetActionLookupSkipsNonNSObjectTargets() {
        let control = UIControl()
        let target = SwiftOnlyControlTarget()

        let actions = safeControlActionNames(for: control, target: target, event: .touchUpInside)

        #expect(actions.isEmpty)
    }

    @MainActor
    @Test("UIControl tap dispatch can fall back to event dispatch when actions are not introspectable")
    func controlTapDispatchFallsBackToEventDispatchWhenActionsAreNotIntrospectable() {
        let control = EventReportingControl(frame: .zero, events: .touchUpInside)

        let dispatch = preferredTapDispatch(for: control)

        #expect(dispatch?.event == .touchUpInside)
        #expect(dispatch?.eventName == "UIControl.touchUpInside")
        #expect(dispatch?.actions.isEmpty == true)
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
    @Test("UIControl long press submits touch down and touch up events")
    func controlLongPressSubmitsTouchEvents() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        let control = UIControl(frame: CGRect(x: 40, y: 30, width: 160, height: 60))
        let recorder = ControlEventRecorder()
        control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
        control.addTarget(recorder, action: #selector(ControlEventRecorder.touchUpInside), for: .touchUpInside)
        window.addSubview(control)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let result = await performLongPress(.longPress(x: 80, y: 50, duration: 0.05))

        #expect(result.ok)
        #expect(result.action == "longPress")
        #expect(result.strategy == "control-long-press-touch-events")
        #expect(recorder.events == ["down", "up"])
    }

    @MainActor
    @Test("UIView long press gesture does not use private recognizer target introspection")
    func viewLongPressGestureDoesNotUsePrivateRecognizerTargetIntrospection() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        let view = UIView(frame: CGRect(x: 40, y: 30, width: 160, height: 60))
        let target = GestureLongPressTarget()
        view.addGestureRecognizer(UILongPressGestureRecognizer(target: target, action: #selector(GestureLongPressTarget.didLongPress(_:))))
        window.addSubview(view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let result = await performLongPress(.longPress(x: 80, y: 50, duration: 0.05))
        await Task.yield()

        #expect(!result.ok)
        #expect(target.longPressCount == 0)
        #expect(result.message == "UILongPressGestureRecognizer target actions are not exposed through public UIKit runtime APIs")
        #expect(result.strategy == "long-press-gesture-recognizer")
    }

    @MainActor
    @Test("UIView tap gesture does not use private recognizer target introspection")
    func viewTapGestureDoesNotUsePrivateRecognizerTargetIntrospection() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        let view = UIView(frame: CGRect(x: 40, y: 30, width: 160, height: 60))
        let target = GestureTapTarget()
        view.addGestureRecognizer(UITapGestureRecognizer(target: target, action: #selector(GestureTapTarget.didTap(_:))))
        window.addSubview(view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let result = performTap(.tap(x: 80, y: 50))
        await Task.yield()

        #expect(!result.ok)
        #expect(target.tapCount == 0)
        #expect(result.message == "UITapGestureRecognizer target actions are not exposed through public UIKit runtime APIs")
        #expect(result.activationClassName == NSStringFromClass(UIView.self))
        #expect(result.strategy == "tap-gesture-recognizer")
    }

    @MainActor
    @Test("UITabBar private button tap selects tab bar controller index")
    func tabBarPrivateButtonTapSelectsTabBarControllerIndex() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let first = UIViewController()
        first.tabBarItem = UITabBarItem(title: "One", image: nil, tag: 0)
        let second = UIViewController()
        second.tabBarItem = UITabBarItem(title: "Two", image: nil, tag: 1)
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [first, second]
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        tabBarController.view.layoutIfNeeded()
        defer { window.isHidden = true }

        let tabBarFrame = tabBarController.tabBar.frame
        let result = performTap(.tap(
            x: Double(tabBarFrame.minX + tabBarFrame.width * 0.75),
            y: Double(tabBarFrame.midY)
        ))
        await Task.yield()

        #expect(result.ok)
        #expect(result.message == "Submitted UITabBar item selection")
        #expect(result.strategy == "tab-bar-selection")
        #expect(tabBarController.selectedIndex == 1)
    }

    @MainActor
    @Test("UITabBar duplicate private button layers map by visual slot")
    func duplicateTabBarButtonLayersMapByVisualSlot() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 428, height: 926))
        let tabBar = UITabBar(frame: CGRect(x: 0, y: 843, width: 428, height: 83))
        let items = ["Server", "Photos", "Music", "Settings"].map { UITabBarItem(title: $0, image: nil, tag: 0) }
        tabBar.items = items
        window.addSubview(tabBar)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let slotFrames = [
            CGRect(x: 25, y: 4, width: 104.5, height: 54),
            CGRect(x: 116.16666666666669, y: 4, width: 104.5, height: 54),
            CGRect(x: 207.33333333333334, y: 4, width: 104.5, height: 54),
            CGRect(x: 298.5, y: 4, width: 104.5, height: 54),
        ]
        var duplicatePhotosButton: UIControl?
        for frame in slotFrames {
            tabBar.addSubview(UIControl(frame: frame))
        }
        for frame in slotFrames {
            let duplicate = UIControl(frame: frame)
            tabBar.addSubview(duplicate)
            if abs(frame.minX - 116.16666666666669) < 0.1 {
                duplicatePhotosButton = duplicate
            }
        }

        let photosButton = try #require(duplicatePhotosButton)
        let result = performTabBarControlTap(
            photosButton,
            request: .tap(x: 168, y: 883),
            action: "tap",
            matchedView: photosButton,
            strategy: nil
        )
        await Task.yield()

        #expect(result?.ok == true)
        #expect(result?.message == "Submitted UITabBar item selection")
        #expect(result?.strategy == "tab-bar-selection")
        #expect(tabBar.selectedItem === items[1])
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

    @MainActor
    @Test("pinch scales nearest zoomable UIScrollView")
    func pinchScalesNearestZoomableScrollView() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        let scrollView = UIScrollView(frame: CGRect(x: 20, y: 20, width: 240, height: 240))
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.zoomScale = 1.5
        let content = UIView(frame: CGRect(x: 0, y: 0, width: 480, height: 480))
        scrollView.addSubview(content)
        scrollView.contentSize = content.bounds.size
        window.addSubview(scrollView)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let result = performPinch(.pinch(centerX: 80, centerY: 80, startDistance: 60, endDistance: 120, scale: 2))

        #expect(result.ok)
        #expect(result.action == "pinch")
        #expect(result.strategy == "scroll-view-pinch-zoom")
        #expect(scrollView.zoomScale == 3)
    }

    @MainActor
    @Test("pinch reports unsupported when target is not zoomable")
    func pinchReportsUnsupportedWhenTargetIsNotZoomable() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 240, height: 240))
        window.addSubview(view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let result = performPinch(.pinch(centerX: 80, centerY: 80, startDistance: 60, endDistance: 120, scale: 2))

        #expect(!result.ok)
        #expect(result.action == "pinch")
        #expect(result.message == "Hit view is not inside a zoomable UIScrollView")
        #expect(result.strategy == "zoomable-scroll-view-required")
    }
}

private final class ActivatingControl: UIControl {
    var didActivate = false

    override func accessibilityActivate() -> Bool {
        didActivate = true
        return true
    }
}

private final class ControlEventRecorder: NSObject {
    var events: [String] = []

    @objc func touchDown() {
        events.append("down")
    }

    @objc func touchUpInside() {
        events.append("up")
    }
}

private final class SwiftOnlyControlTarget {
    func touchUpInside() {}
}

private final class EventReportingControl: UIControl {
    private let events: UIControl.Event

    init(frame: CGRect, events: UIControl.Event) {
        self.events = events
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var allControlEvents: UIControl.Event {
        events
    }
}

private final class GestureTapTarget: NSObject {
    var tapCount = 0

    @objc func didTap(_ recognizer: UITapGestureRecognizer) {
        tapCount += 1
    }
}

private final class GestureLongPressTarget: NSObject {
    var longPressCount = 0

    @objc func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        longPressCount += 1
    }
}
#endif
