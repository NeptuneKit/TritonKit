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
            dot.tap()
            XCTAssertFalse(parent.exists, "Tapping the dot explicitly closes the menu")
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

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
