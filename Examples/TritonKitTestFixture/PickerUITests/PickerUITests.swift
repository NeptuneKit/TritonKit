import XCTest

/// Real XCTest touch delivery. The runtime/CLI continuation separately proves
/// that the stored selection can perform exactly one business action.
@MainActor
final class PickerUITests: XCTestCase {
    private var application: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        application = XCUIApplication(bundleIdentifier: "com.neptunekit.tritonkit.testfixture")
        application.launchEnvironment["TRITON_PICKER_ENABLED"] = "1"
        application.launchEnvironment["TRITON_PORT"] = "19422"
        application.launchEnvironment["TRITON_HOST"] = "127.0.0.1"
        application.launch()
    }

    func testDragSelectsButtonWithoutBusinessClick() throws {
        let openFixture = application.buttons["fixture.login.picker"]
        XCTAssertTrue(openFixture.waitForExistence(timeout: 15), "UIKit fixture entry must exist")
        openFixture.tap()

        let button = application.buttons["fixture.picker.increment"]
        let counter = application.staticTexts["fixture.picker.count"]
        let dot = application.buttons["triton.picker.dot"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        XCTAssertTrue(dot.waitForExistence(timeout: 10), "Explicitly enabled picker must be visible")
        XCTAssertEqual(counter.label, "Picker Clicks: 0")
        XCTAssertTrue(dot.isHittable)
        XCTAssertTrue(button.isHittable)

        // A long-press drag repositions the actual ball and must not select anything.
        let originalFrame = dot.frame
        let quickSource = dot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        quickSource.press(forDuration: 0.6, thenDragTo: quickSource.withOffset(CGVector(dx: -70, dy: 40)))
        XCTAssertGreaterThan(abs(dot.frame.midX - originalFrame.midX), 40)
        XCTAssertEqual(counter.label, "Picker Clicks: 0")
        XCTAssertFalse(application.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "(?s)#[0-9]+ .+")).firstMatch.exists)
        let parkedFrame = dot.frame
        attachScreenshot(named: "picker-before-real-drag")
        let source = dot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let destination = button.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        print("SP201_DRAG_MAGNIFIER_CAPTURE")
        source.press(forDuration: 0.05, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 3)

        let selectionCaption = application.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "(?s)#[0-9]+ .+")
        ).firstMatch
        XCTAssertTrue(selectionCaption.waitForExistence(timeout: 5), "Releasing the actual drag must fix a selection")
        XCTAssertEqual(counter.label, "Picker Clicks: 0", "The drag must not dispatch the underlying button action")
        XCTAssertEqual(dot.frame.midX, parkedFrame.midX, accuracy: 2)
        XCTAssertEqual(dot.frame.midY, parkedFrame.midY, accuracy: 2)
        attachScreenshot(named: "picker-real-drag-no-business-click")

        // UIKit may let its title label occupy the entire button bounds. In
        // that case use the visible parent operation, never silently rewrite
        // the selection or inject a tap into the business button.
        let selectedButtonCaption = application.staticTexts["triton.picker.caption"]
        func selectedClass() -> String? {
            selectedButtonCaption.label.split(whereSeparator: { $0.isWhitespace }).dropFirst().first.map(String.init)
        }
        let automaticParent = application.buttons["选择父级"]
        XCTAssertTrue(automaticParent.waitForExistence(timeout: 5), "Releasing a selection opens the compass")
        if selectedClass() != "UIButton" {
            let originalClass = selectedClass()
            let parent = application.buttons["选择父级"]
            XCTAssertTrue(parent.waitForExistence(timeout: 5))
            parent.tap()
            XCTAssertTrue(parent.isHittable, "Choosing a parent keeps the menu open")
            let child = application.buttons["选择子级"]
            XCTAssertTrue(child.isHittable)
            XCTAssertTrue(application.buttons["前一同级"].exists)
            XCTAssertTrue(application.buttons["后一同级"].exists)
            let stableParentFrame = parent.frame
            child.tap()
            XCTAssertTrue(parent.isHittable)
            XCTAssertEqual(selectedClass(), originalClass, "Down returns to the child just visited")
            XCTAssertEqual(parent.frame, stableParentFrame, "Unobstructed compass stays in place")
            parent.tap()
            XCTAssertTrue(parent.isHittable)
            XCTAssertFalse(parent.frame.intersects(button.frame), "Compass must leave the selected button visible")
            attachScreenshot(named: "picker-stable-compass-avoids-selected-control")
            application.buttons["收起导航"].tap()
            XCTAssertFalse(parent.exists, "The compass center explicitly closes navigation")
        }
        XCTAssertEqual(selectedClass(), "UIButton", "Final selection must explicitly identify the actionable UIButton")
        XCTAssertEqual(counter.label, "Picker Clicks: 0", "Selection and parent adjustment must leave the business count unchanged")
        attachScreenshot(named: "picker-button-selected-ready-for-cli")
        if ProcessInfo.processInfo.environment["SP201_WAIT_FOR_AGENT"] == "1" {
            // The test runner waits while the controller reads the selection
            // and performs the guarded tap through Triton's real CLI path.
            // No network request or business input is emitted by this test.
            let clickedOnce = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "Picker Clicks: 1"),
                object: counter
            )
            XCTAssertEqual(XCTWaiter.wait(for: [clickedOnce], timeout: 90), .completed,
                           "External guarded CLI action must increment the business counter exactly once")
            XCTAssertEqual(counter.label, "Picker Clicks: 1")
            let changedAgain = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label != %@", "Picker Clicks: 1"),
                object: counter
            )
            changedAgain.isInverted = true
            XCTAssertEqual(XCTWaiter.wait(for: [changedAgain], timeout: 1), .completed,
                           "The business count must remain one after the single external action")
            attachScreenshot(named: "picker-cli-guarded-action-clicks-exactly-one")
        }
        // Do not terminate or clear the application: the controller continues
        // with the real CLI selection read and guarded business action.
    }

    func testDotOpensSDKSettingsAndRetainsAssistancePreferences() throws {
        let openFixture = application.buttons["fixture.login.picker"]
        XCTAssertTrue(openFixture.waitForExistence(timeout: 15))
        openFixture.tap()
        let status = application.staticTexts["fixture.runtime.status"]
        let connected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Fixture Runtime: Connected"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [connected], timeout: 15), .completed)
        let dot = application.buttons["triton.picker.dot"]
        XCTAssertTrue(dot.waitForExistence(timeout: 5))
        dot.tap()
        let title = application.staticTexts["TritonKit"]
        let panel = application.tables["triton.settings.panel"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "A tap opens the native SDK sheet without a host debug menu")
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(panel.frame.minY, application.frame.height * 0.25, "The sheet initially uses its medium detent")
        XCTAssertFalse(dot.exists, "The floating entry is hidden while the system sheet owns interaction")
        let badge = application.staticTexts["triton.settings.connectionStatus"]
        if badge.exists {
            XCTAssertEqual(badge.label, "已连接")
        } else {
            XCTAssertTrue(panel.staticTexts["已连接"].exists)
        }
        XCTAssertFalse(application.buttons["选择父级"].exists)
        attachScreenshot(named: "native-sheet-home-connected")

        func returnHome() {
            let back = application.buttons["triton.settings.back"]
            if back.exists { back.tap() }
            else { application.navigationBars.buttons.element(boundBy: 0).tap() }
            XCTAssertTrue(title.waitForExistence(timeout: 5))
        }
        tapSettingsRoute("connection")
        XCTAssertTrue(application.navigationBars["连接与会话"].waitForExistence(timeout: 5))
        XCTAssertEqual(application.staticTexts["triton.settings.connectionStatus"].label, "已连接")
        let endpoint = panel.descendants(matching: .any).matching(identifier: "triton.settings.endpoint").firstMatch
        revealSettingsElement(endpoint)
        XCTAssertEqual(endpoint.value as? String, "127.0.0.1:19422", "Connection details reflect the configured fixture endpoint")
        let reconnect = panel.descendants(matching: .any).matching(identifier: "triton.settings.reconnect").firstMatch
        revealSettingsElement(reconnect)
        XCTAssertEqual(reconnect.label, "自动重连")
        XCTAssertEqual(reconnect.value as? String, "开启")
        returnHome()

        tapSettingsRoute("capabilities")
        XCTAssertTrue(application.staticTexts["SDK 功能"].waitForExistence(timeout: 5))
        XCTAssertEqual(panel.descendants(matching: .any).matching(identifier: "triton.settings.feature.0").firstMatch.label, "属性高亮")
        XCTAssertEqual(panel.descendants(matching: .any).matching(identifier: "triton.settings.feature.1").firstMatch.label, "控件选择器")
        XCTAssertEqual(panel.descendants(matching: .any).matching(identifier: "triton.settings.feature.1").firstMatch.value as? String, "已启用")
        attachScreenshot(named: "native-sheet-capabilities")
        let input = panel.descendants(matching: .any).matching(identifier: "triton.settings.feature.7").firstMatch
        revealSettingsElement(input)
        XCTAssertEqual(input.label, "输入操作")
        let semantic = panel.descendants(matching: .any).matching(identifier: "triton.settings.feature.9").firstMatch
        revealSettingsElement(semantic)
        XCTAssertEqual(semantic.label, "语义信息")
        returnHome()

        tapSettingsRoute("app")
        XCTAssertTrue(application.staticTexts["应用与环境"].waitForExistence(timeout: 5))
        let version = panel.descendants(matching: .any).matching(identifier: "triton.settings.appInfo.1").firstMatch
        revealSettingsElement(version)
        XCTAssertFalse((version.value as? String ?? "").isEmpty)
        let identifier = panel.descendants(matching: .any).matching(identifier: "triton.settings.appInfo.3").firstMatch
        revealSettingsElement(identifier)
        XCTAssertEqual(identifier.value as? String, "com.neptunekit.tritonkit.testfixture")
        returnHome()

        tapSettingsRoute("picker")
        let preferenceIDs = ["triton.settings.magnifier", "triton.settings.guides", "triton.settings.feedback"]
        for identifier in preferenceIDs {
            let control = application.switches[identifier]
            revealSettingsElement(control)
            XCTAssertEqual(control.value as? String, "1")
            control.tap()
            XCTAssertEqual(control.value as? String, "0")
        }
        attachScreenshot(named: "native-sheet-picker-assistance-disabled")
        application.buttons["triton.settings.close"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(dot.waitForExistence(timeout: 5), "Closing the sheet restores the picker")
        dot.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Every opening starts at the hub home")
        tapSettingsRoute("picker")
        for identifier in preferenceIDs {
            let control = application.switches[identifier]
            revealSettingsElement(control)
            XCTAssertEqual(control.value as? String, "0", "Reopening the picker page retains the runtime preference")
        }
        application.buttons["triton.settings.close"].tap()
        XCTAssertTrue(dot.waitForExistence(timeout: 5))
        let button = application.buttons["fixture.picker.increment"]
        dot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.05,
            thenDragTo: button.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
        XCTAssertTrue(application.buttons["选择父级"].waitForExistence(timeout: 5), "Dragging still selects and opens the compass with optional aids disabled")
        let selectedCaption = application.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "(?s)#[0-9]+ .+")).firstMatch
        XCTAssertTrue(selectedCaption.exists)
        dot.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertFalse(selectedCaption.exists)
        XCTAssertFalse(dot.exists)
        application.buttons["triton.settings.close"].tap()
        XCTAssertTrue(selectedCaption.waitForExistence(timeout: 5), "Closing the sheet restores the existing selection feedback")
        XCTAssertEqual(application.staticTexts["fixture.picker.count"].label, "Picker Clicks: 0")
        XCTAssertEqual(status.label, "Fixture Runtime: Connected")
        attachScreenshot(named: "native-sheet-closed-selection-restored")
    }

    func testSDKSettingsHidePickerWithoutBusinessClickOrDisconnect() throws {
        let openFixture = application.buttons["fixture.login.picker"]
        XCTAssertTrue(openFixture.waitForExistence(timeout: 15))
        openFixture.tap()
        let status = application.staticTexts["fixture.runtime.status"]
        let connected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Fixture Runtime: Connected"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [connected], timeout: 15), .completed)
        let dot = application.buttons["triton.picker.dot"]
        XCTAssertTrue(dot.waitForExistence(timeout: 5))
        let button = application.buttons["fixture.picker.increment"]
        dot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.05,
            thenDragTo: button.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
        let selectedCaption = application.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "(?s)#[0-9]+ .+")).firstMatch
        XCTAssertTrue(selectedCaption.waitForExistence(timeout: 5))
        let selectionBeforeOpening = selectedCaption.label
        dot.tap()
        let panel = application.tables["triton.settings.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertFalse(selectedCaption.exists)
        XCTAssertFalse(dot.exists)
        tapSettingsRoute("entry")
        tapSettingsRoute("hide")
        let alert = application.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Hiding uses a system confirmation alert")
        attachScreenshot(named: "native-sheet-confirmation")
        let cancelByID = alert.buttons.matching(identifier: "triton.settings.cancelHide").firstMatch
        (cancelByID.exists ? cancelByID : alert.buttons["取消"]).tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        XCTAssertTrue(panel.exists)
        XCTAssertFalse(dot.exists, "Canceling leaves the modal sheet open")
        application.buttons["triton.settings.close"].tap()
        XCTAssertTrue(dot.waitForExistence(timeout: 5), "Canceling hide keeps the picker enabled")
        XCTAssertTrue(selectedCaption.waitForExistence(timeout: 5))
        XCTAssertEqual(selectedCaption.label, selectionBeforeOpening, "Canceling hide preserves the selected node")
        dot.tap()
        tapSettingsRoute("entry")
        tapSettingsRoute("hide")
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let confirmByID = alert.buttons.matching(identifier: "triton.settings.confirmHide").firstMatch
        (confirmByID.exists ? confirmByID : alert.buttons["隐藏"]).tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertFalse(dot.exists)
        XCTAssertFalse(selectedCaption.exists)
        XCTAssertFalse(application.buttons["选择父级"].exists)
        XCTAssertEqual(application.staticTexts["fixture.picker.count"].label, "Picker Clicks: 0")
        XCTAssertEqual(status.label, "Fixture Runtime: Connected")
        let disconnected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", "Fixture Runtime: Connected"), object: status)
        disconnected.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [disconnected], timeout: 1), .completed,
                       "Hiding the picker leaves the runtime connected")
        attachScreenshot(named: "native-sheet-entry-hidden")
    }

    func testNativeSheetDismissalPreservesSelectionAndBlocksBackground() throws {
        let openFixture = application.buttons["fixture.login.picker"]
        XCTAssertTrue(openFixture.waitForExistence(timeout: 15))
        openFixture.tap()
        let dot = application.buttons["triton.picker.dot"]
        XCTAssertTrue(dot.waitForExistence(timeout: 5))
        let businessButton = application.buttons["fixture.picker.increment"]
        let counter = application.staticTexts["fixture.picker.count"]
        dot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.05,
            thenDragTo: businessButton.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
        let selectedCaption = application.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "(?s)#[0-9]+ .+")).firstMatch
        XCTAssertTrue(selectedCaption.waitForExistence(timeout: 5))
        let selectionBeforeOpening = selectedCaption.label
        dot.tap()
        let panel = application.tables["triton.settings.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let navigation = application.navigationBars["TritonKit"]
        XCTAssertTrue(navigation.exists)
        XCTAssertFalse(dot.exists)
        XCTAssertFalse(selectedCaption.exists)
        attachScreenshot(named: "native-sheet-medium-over-selection")

        // Use the exposed dimmed area, not an underlying control whose frame
        // may now be covered by the native sheet. UIKit owns this touch.
        let outsideY = max(application.frame.minY + 24, navigation.frame.minY / 2)
        application.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: application.frame.width / 2, dy: outsideY)).tap()
        if panel.exists {
            // Some system versions retain page sheets on a backdrop tap.
            application.buttons["triton.settings.close"].tap()
        }
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(dot.waitForExistence(timeout: 5))
        XCTAssertEqual(counter.label, "Picker Clicks: 0", "The modal background touch never reaches business controls")
        XCTAssertEqual(selectedCaption.label, selectionBeforeOpening)

        dot.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let start = application.navigationBars["TritonKit"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = application.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5), "Dragging the native sheet down dismisses it")
        XCTAssertTrue(dot.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedCaption.waitForExistence(timeout: 5))
        XCTAssertEqual(selectedCaption.label, selectionBeforeOpening, "Interactive dismissal preserves the selected node")
        XCTAssertEqual(counter.label, "Picker Clicks: 0")
        attachScreenshot(named: "native-sheet-dismissal-selection-restored")
    }

    private func tapSettingsRoute(_ route: String) {
        let cell = application.tables["triton.settings.panel"].cells["triton.settings.\(route)"]
        revealSettingsElement(cell)
        cell.tap()
    }

    private func revealSettingsElement(_ element: XCUIElement) {
        let panel = application.tables["triton.settings.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            panel.swipeUp()
        }
        // A popped native page preserves its offset; an earlier route can
        // therefore be above the visible region rather than below it.
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            panel.swipeDown()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected SDK table element to become visible after bounded scrolling")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
