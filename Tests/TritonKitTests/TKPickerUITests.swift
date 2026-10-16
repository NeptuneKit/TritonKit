import Testing
@testable import TritonKit

#if canImport(UIKit) && TRITONKIT_RUNTIME_ENABLED
import UIKit

extension TKUIKitWindowTests {
@Suite(.serialized)
@MainActor
struct TKPickerUITests {
    private func toggleNavigation(_ controller: TKPickerOverlayViewController) throws {
        let menu = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.navigation" })
        if !menu.isHidden {
            let close = try #require(menu.subviews.compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == "收起导航" })
            close.sendActions(for: .touchUpInside)
        } else {
            controller.showNavigation()
        }
    }

    @Test("disabled presentation aids do not render during picking")
    func disabledPresentation() throws {
        let business = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { business.isHidden = true }
        let target = UILabel(frame: CGRect(x: 60, y: 100, width: 120, height: 44))
        target.text = "Target"
        business.rootViewController?.view.addSubview(target)
        var feedback = 0
        let controller = TKPickerOverlayViewController(manager: TKPickerSessionManager(), selectionFeedback: { feedback += 1 })
        controller.businessWindowProvider = { business }
        controller.loadViewIfNeeded()
        controller.view.frame = business.bounds
        controller.view.layoutIfNeeded()
        controller.updatePresentation(.init(magnifierEnabled: false, guidesEnabled: false, feedbackEnabled: false))
        controller.beginPicking(at: CGPoint(x: 100, y: 120))
        #expect(feedback == 0)
        let lensesHidden = controller.view.subviews.compactMap { $0 as? TKPickerMagnifierView }.allSatisfy { $0.isHidden }
        #expect(lensesHidden)
        #expect(controller.view.layer.sublayers?.first { $0.name == "triton.picker.guides" }?.isHidden == true)
        controller.updatePresentation(.init(magnifierEnabled: true, guidesEnabled: true, feedbackEnabled: true))
        let lens = try #require(controller.view.subviews.compactMap { $0 as? TKPickerMagnifierView }.first)
        #expect(!lens.isHidden)
        controller.updatePresentation(.init(magnifierEnabled: false, guidesEnabled: false, feedbackEnabled: false))
        #expect(lens.isHidden)
        controller.finishPicking(at: CGPoint(x: 100, y: 120), cancelled: true)
    }

    @Test("SDK hub uses a modal sheet, shields background and restores picker after dismissal")
    func sdkHubPages() async throws {
        let business = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        defer { business.isHidden = true }
        let controller = TKPickerOverlayViewController(manager: TKPickerSessionManager())
        let overlay: TKPickerOverlayWindow
        if let scene = business.windowScene { overlay = TKPickerOverlayWindow(windowScene: scene) }
        else { overlay = TKPickerOverlayWindow(frame: business.bounds) }
        overlay.frame = business.frame
        overlay.rootViewController = controller
        overlay.isHidden = false
        defer { overlay.isHidden = true }
        controller.view.layoutIfNeeded()
        controller.dot.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 400_000_000)
        let navigation = try #require(controller.presentedViewController as? UINavigationController)
        #expect(navigation.modalPresentationStyle == .pageSheet)
        #expect(controller.dot.isHidden)
        #expect(controller.acceptsTouch(at: CGPoint(x: 10, y: 10)))
        #expect(overlay.hitTest(CGPoint(x: 10, y: 10), with: nil) != nil)
        #expect(!overlay.isKeyWindow)
        if #available(iOS 15.0, *) {
            let sheet = try #require(navigation.sheetPresentationController)
            #expect(sheet.detents.map(\.identifier) == [.medium, .large])
            #expect(sheet.selectedDetentIdentifier == .medium)
            #expect(sheet.prefersGrabberVisible)
            #expect(sheet.largestUndimmedDetentIdentifier == nil)
        }
        let caption = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.caption" })
        #expect(caption.isHidden)
        let root = try #require(navigation.viewControllers.first as? UITableViewController)
        #expect(root.tableView.style == .insetGrouped)
        controller.cancelInteraction()
        for _ in 0..<30 where controller.presentedViewController != nil {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(controller.presentedViewController == nil)
        #expect(!controller.dot.isHidden)
        #expect(!caption.isHidden)
        #expect(!controller.acceptsTouch(at: CGPoint(x: 10, y: 10)))
    }

    @Test("picker chrome receives touches while its empty area passes through")
    func passthrough() throws {
        let manager = TKPickerSessionManager()
        let controller = TKPickerOverlayViewController(manager: manager)
        let window = TKPickerOverlayWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        #expect(window.hitTest(CGPoint(x: 160, y: 240), with: nil) == nil)
        #expect(window.hitTest(controller.dot.center, with: nil) != nil)
        #expect(!window.isKeyWindow)
    }

    @Test("drag selection and cancellation never dispatch business button actions")
    func pickingDoesNotTap() throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { window.isHidden = true }
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 90, y: 130, width: 140, height: 50)
        button.setTitle("Select me", for: .normal)
        let counter = PickerActionCounter()
        button.addTarget(counter, action: #selector(PickerActionCounter.tap), for: .touchUpInside)
        window.rootViewController?.view.addSubview(button)
        let manager = TKPickerSessionManager()
        let controller = TKPickerOverlayViewController(manager: manager)
        controller.businessWindowProvider = { window }
        let overlay: TKPickerOverlayWindow
        if let scene = window.windowScene { overlay = TKPickerOverlayWindow(windowScene: scene) }
        else { overlay = TKPickerOverlayWindow(frame: window.frame) }
        overlay.frame = window.frame
        overlay.windowLevel = .alert
        overlay.rootViewController = controller
        overlay.isHidden = false
        defer { overlay.isHidden = true }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        let parked = controller.dot.center
        let point = CGPoint(x: 120, y: 150)
        controller.beginPicking(at: point)
        #expect(controller.dot.center == point)
        controller.updatePicking(at: CGPoint(x: 125, y: 155))
        #expect(controller.dot.center == CGPoint(x: 125, y: 155))
        let outline = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.preview" })
        let caption = try #require(controller.view.subviews.compactMap { $0 as? UILabel }.first)
        #expect(!outline.isHidden)
        #expect(outline.frame.contains(point))
        #expect(caption.text?.contains("松手选中") == true)
        #expect(manager.selectedView == nil)
        controller.updatePicking(at: CGPoint(x: -20, y: -20))
        #expect(outline.isHidden)
        controller.updatePicking(at: point)
        #expect(!outline.isHidden)
        controller.finishPicking(at: point, cancelled: false)
        #expect(manager.selectedView != nil)
        #expect(controller.dot.center == parked)
        let original = manager.selectedView
        controller.beginPicking(at: CGPoint(x: -20, y: -20))
        controller.finishPicking(at: .zero, cancelled: true)
        #expect(manager.selectedView === original)
        #expect(controller.dot.center == parked)
        #expect(counter.count == 0)
        #expect(button.layer.borderWidth == 0)
    }

    @Test("long-press drag moves the entry and cancellation restores it without selecting")
    func gestureRelocation() {
        let manager = TKPickerSessionManager()
        let controller = TKPickerOverlayViewController(manager: manager)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        controller.view.layoutIfNeeded()
        let parked = controller.dot.center
        controller.beginMoving()
        controller.updateMoving(translation: CGPoint(x: -80, y: 100))
        #expect(controller.dot.center == CGPoint(x: parked.x - 80, y: parked.y + 100))
        controller.finishMoving(cancelled: false)
        let moved = controller.dot.center
        #expect(manager.status().selection == nil)
        controller.beginMoving()
        controller.updateMoving(translation: CGPoint(x: 30, y: -40))
        controller.cancelInteraction()
        #expect(controller.dot.center == moved)
        #expect(manager.status().selection == nil)
        #expect(controller.dot.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } == true)
    }

    @Test("drag feedback stays inside narrow screens and clear of the finger")
    func feedbackPlacement() throws {
        let controller = TKPickerOverlayViewController(manager: TKPickerSessionManager())
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        controller.view.layoutIfNeeded()
        let caption = try #require(controller.view.subviews.compactMap { $0 as? UILabel }.first)
        for point in [CGPoint(x: 30, y: 30), CGPoint(x: 290, y: 450), CGPoint(x: 160, y: 240)] {
            controller.beginPicking(at: point)
            #expect(controller.view.bounds.contains(caption.frame))
            #expect(!caption.frame.intersects(controller.dot.frame))
            controller.finishPicking(at: point, cancelled: true)
        }
    }

    @Test("crosshair and dense control guides exist only during picking")
    func temporaryGuides() throws {
        var time: TimeInterval = 0
        let business = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { business.isHidden = true }
        let container = UIView(frame: CGRect(x: 20, y: 100, width: 280, height: 160))
        business.rootViewController?.view.addSubview(container)
        for index in 0..<6 {
            let item = UIButton(frame: CGRect(x: 10 + index % 3 * 85, y: 10 + index / 3 * 65, width: 75, height: 50))
            container.addSubview(item)
        }
        let originalLayers = container.layer.sublayers?.count
        let controller = TKPickerOverlayViewController(manager: TKPickerSessionManager(), clock: { time })
        controller.businessWindowProvider = { business }
        controller.loadViewIfNeeded()
        controller.view.frame = business.bounds
        controller.view.layoutIfNeeded()
        controller.beginPicking(at: CGPoint(x: 45, y: 125))
        #expect(controller.dot.backgroundColor == .clear)
        let guides = try #require(controller.view.layer.sublayers?.first { $0.name == "triton.picker.guides" } as? CAShapeLayer)
        #expect(guides.isHidden)
        time = 0.3
        controller.updatePicking(at: CGPoint(x: 45, y: 125))
        #expect(guides.path != nil)
        #expect(!guides.isHidden)
        #expect(container.layer.sublayers?.count == originalLayers)
        controller.updatePicking(at: CGPoint(x: 70, y: 125))
        #expect(guides.isHidden)
        controller.finishPicking(at: CGPoint(x: 45, y: 125), cancelled: true)
        #expect(guides.path == nil)
        #expect(guides.isHidden)
        #expect(controller.dot.backgroundColor != .clear)
        controller.beginMoving()
        #expect(guides.isHidden)
        controller.cancelInteraction()
    }

    @Test("parent selection keeps the menu open for repeated traversal")
    func parentMenuStaysOpen() throws {
        let business = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { business.isHidden = true }
        let outer = UIView(frame: CGRect(x: 20, y: 100, width: 280, height: 200))
        let inner = UIView(frame: CGRect(x: 10, y: 10, width: 240, height: 150))
        let button = UIButton(frame: CGRect(x: 10, y: 10, width: 100, height: 44))
        business.rootViewController?.view.addSubview(outer)
        outer.addSubview(inner)
        inner.addSubview(button)
        let manager = TKPickerSessionManager()
        _ = manager.select(button, rawHit: button)
        let controller = TKPickerOverlayViewController(manager: manager)
        controller.loadViewIfNeeded()
        controller.view.frame = business.bounds
        controller.view.layoutIfNeeded()
        try toggleNavigation(controller)
        let menu = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.navigation" })
        let parent = try #require(menu.subviews.compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == "选择父级" })
        #expect(!menu.isHidden)
        parent.sendActions(for: .touchUpInside)
        #expect(manager.selectedView === inner)
        #expect(!menu.isHidden)
        parent.sendActions(for: .touchUpInside)
        #expect(manager.selectedView === outer)
        #expect(!menu.isHidden)
        try toggleNavigation(controller)
        #expect(menu.isHidden)
    }

    @Test("node toolbar avoids the selected control at top and bottom")
    func menuAvoidsSelection() throws {
        let business = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { business.isHidden = true }
        let button = UIButton(frame: CGRect(x: 100, y: 140, width: 200, height: 60))
        business.rootViewController?.view.addSubview(button)
        let manager = TKPickerSessionManager()
        let controller = TKPickerOverlayViewController(manager: manager)
        controller.loadViewIfNeeded()
        controller.view.frame = business.bounds
        controller.view.layoutIfNeeded()
        try toggleNavigation(controller)
        let menu = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.navigation" })
        for y: CGFloat in [140, 390, 20] {
            button.frame.origin.y = y
            _ = manager.select(button)
            controller.refreshSelection()
            controller.view.layoutIfNeeded()
            #expect(!menu.frame.intersects(button.frame))
            #expect(menu.frame.width <= 160)
            #expect(controller.view.bounds.contains(menu.frame))
            #expect(!menu.isHidden)
        }
    }

    @Test("compass directions match node hierarchy and retain accessible targets")
    func compassGeometry() throws {
        let controller = TKPickerOverlayViewController(manager: TKPickerSessionManager())
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        controller.view.layoutIfNeeded()
        try toggleNavigation(controller)
        controller.view.layoutIfNeeded()
        let menu = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.navigation" })
        let buttons = menu.subviews.compactMap { $0 as? UIButton }
        let up = try #require(buttons.first { $0.accessibilityLabel == "选择父级" })
        let down = try #require(buttons.first { $0.accessibilityLabel == "选择子级" })
        let left = try #require(buttons.first { $0.accessibilityLabel == "前一同级" })
        let right = try #require(buttons.first { $0.accessibilityLabel == "后一同级" })
        let close = try #require(buttons.first { $0.accessibilityLabel == "收起导航" })
        #expect(up.center.x == down.center.x)
        #expect(left.center.y == right.center.y)
        #expect(up.center.y < close.center.y && down.center.y > close.center.y)
        #expect(left.center.x < close.center.x && right.center.x > close.center.x)
        for button in buttons {
            #expect(button.frame.width >= 44 && button.frame.height >= 44)
        }
        #expect(!controller.acceptsTouch(at: CGPoint(x: menu.frame.minX + 1, y: menu.frame.minY + 1)))
        close.sendActions(for: .touchUpInside)
        #expect(menu.isHidden)
    }

    @Test("compass keeps a free position after navigating away from an obstacle")
    func stableCompass() throws {
        let business = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        defer { business.isHidden = true }
        let target = UIButton(frame: CGRect(x: 230, y: 650, width: 140, height: 50))
        business.rootViewController?.view.addSubview(target)
        let manager = TKPickerSessionManager()
        _ = manager.select(target)
        let controller = TKPickerOverlayViewController(manager: manager)
        controller.loadViewIfNeeded()
        controller.view.frame = business.bounds
        controller.view.layoutIfNeeded()
        try toggleNavigation(controller)
        controller.view.layoutIfNeeded()
        let menu = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.navigation" })
        let parked = menu.frame
        #expect(!parked.intersects(target.frame))
        target.frame = CGRect(x: 150, y: 350, width: 70, height: 44)
        controller.refreshSelection()
        #expect(menu.frame == parked)
        target.frame = CGRect(x: parked.midX - 30, y: parked.midY - 22, width: 60, height: 44)
        controller.refreshSelection()
        #expect(!menu.frame.intersects(target.frame))
        #expect(menu.frame != parked)
    }

    @Test("magnifier follows the exact hit, avoids the finger and clears on cancel")
    func magnifierLifecycle() throws {
        let business = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { business.isHidden = true }
        let target = UIButton(frame: CGRect(x: 20, y: 20, width: 280, height: 440))
        target.backgroundColor = .red
        business.rootViewController?.view.addSubview(target)
        var time: TimeInterval = 0
        var feedbackCount = 0
        let manager = TKPickerSessionManager()
        let controller = TKPickerOverlayViewController(manager: manager, clock: { time }, selectionFeedback: { feedbackCount += 1 })
        controller.businessWindowProvider = { business }
        controller.loadViewIfNeeded()
        controller.view.frame = business.bounds
        controller.view.layoutIfNeeded()
        let lens = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.magnifier" } as? UIImageView)
        let caption = try #require(controller.view.subviews.compactMap { $0 as? UILabel }.first)
        for point in [CGPoint(x: 35, y: 35), CGPoint(x: 285, y: 445), CGPoint(x: 160, y: 240)] {
            controller.beginPicking(at: point)
            #expect(!lens.isHidden && lens.image != nil)
            #expect(controller.view.bounds.contains(lens.frame))
            #expect(!lens.frame.intersects(controller.dot.frame))
            #expect(!lens.frame.intersects(caption.frame))
            #expect(!caption.frame.intersects(controller.dot.frame))
            #expect(!controller.acceptsTouch(at: lens.center))
            time += 0.2
            controller.updatePicking(at: point)
            controller.finishPicking(at: point, cancelled: true)
            #expect(lens.isHidden && lens.image == nil)
        }
        #expect(feedbackCount == 3, "Repeated refresh of the same candidate must not emit feedback")
        controller.beginPicking(at: CGPoint(x: 100, y: 200))
        controller.updatePicking(at: CGPoint(x: -20, y: -20))
        #expect(lens.isHidden && lens.image == nil)
        controller.finishPicking(at: .zero, cancelled: true)
        controller.beginPicking(at: CGPoint(x: 100, y: 200))
        controller.finishPicking(at: CGPoint(x: 100, y: 200), cancelled: false)
        let menu = try #require(controller.view.subviews.first { $0.accessibilityIdentifier == "triton.picker.navigation" })
        #expect(!menu.isHidden, "Successful selection automatically opens navigation")
        let close = try #require(menu.subviews.compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == "收起导航" })
        close.sendActions(for: .touchUpInside)
        #expect(menu.isHidden && manager.selectedView === target)
    }

    @Test("visible picker keeps the business window authoritative and does not mutate its appearance")
    func windowIsolation() throws {
        let business = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let overlay: TKPickerOverlayWindow
        if let scene = business.windowScene { overlay = TKPickerOverlayWindow(windowScene: scene) }
        else { overlay = TKPickerOverlayWindow(frame: business.frame) }
        overlay.frame = business.frame
        overlay.windowLevel = .alert
        overlay.rootViewController = TKPickerOverlayViewController(manager: TKPickerSessionManager())
        overlay.isHidden = false
        _ = TKObjectRegistry.shared.register(overlay)
        defer { overlay.isHidden = true; business.isHidden = true }
        #expect(keyWindows().first === business)
        #expect(!keyWindows().contains { $0 === overlay })
        #expect(!overlay.isKeyWindow)
    }

    @Test("entry relocation clamps to safe area without creating a selection")
    func relocationAndRotation() {
        let manager = TKPickerSessionManager()
        let controller = TKPickerOverlayViewController(manager: manager)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        controller.view.layoutIfNeeded()
        controller.moveEntry(to: CGPoint(x: -100, y: 900))
        #expect(controller.dot.frame.minX >= 0)
        #expect(controller.dot.frame.maxY <= 480)
        controller.view.frame = CGRect(x: 0, y: 0, width: 480, height: 240)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #expect(controller.dot.frame.maxY <= 240)
        #expect(manager.selectedView == nil)
    }
}
}

@MainActor
private final class PickerActionCounter: NSObject {
    var count = 0
    @objc func tap() { count += 1 }
}
#endif
