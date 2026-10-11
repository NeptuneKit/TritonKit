import XCTest

final class TVControlTests: XCTestCase {
    @MainActor
    func testControl() throws {
        continueAfterFailure = false
        let request = try PlatformRequest.load(platform: "tvos")
        var succeeded = false
        defer { attachPlatformResult(request, succeeded: succeeded) }
        let destinations: [String: (XCUIRemote.Button, Int)] = [
            "remote-up": (.up, 1), "remote-down": (.down, 7),
            "remote-left": (.left, 3), "remote-right": (.right, 5)
        ]
        guard destinations[request.action] != nil || ["remote-select", "remote-menu"].contains(request.action), request.crownDelta == nil else {
            throw PlatformRequest.rejection("Unsupported tvOS request")
        }
        let app = XCUIApplication()
        app.launch()
        let center = app.buttons["cell-4"]
        try requireFocus(center)
        if let (button, destination) = destinations[request.action] {
            XCUIRemote.shared.press(button)
            try requireFocus(app.buttons["cell-\(destination)"])
            guard !center.hasFocus else { throw PlatformRequest.rejection("Focus did not leave center") }
        } else if request.action == "remote-select" {
            XCUIRemote.shared.press(.select)
            try requireDetail(app)
        } else if request.action == "remote-menu" {
            // Deliberate setup event, on this dedicated fixture only; the requested event is menu.
            XCUIRemote.shared.press(.select)
            try requireDetail(app)
            XCUIRemote.shared.press(.menu)
            let returned = expectation(for: NSPredicate(format: "label == %@", "Grid"), evaluatedWith: app.staticTexts["screen-state"])
            guard XCTWaiter.wait(for: [returned], timeout: 8) == .completed else {
                throw PlatformRequest.rejection("Menu did not return from detail to grid")
            }
            try requireFocus(center)
        }
        succeeded = true
    }

    @MainActor private func requireFocus(_ element: XCUIElement) throws {
        let focused = expectation(for: NSPredicate(format: "hasFocus == true"), evaluatedWith: element)
        guard XCTWaiter.wait(for: [focused], timeout: 8) == .completed else {
            throw PlatformRequest.rejection("Expected element did not receive focus")
        }
    }

    @MainActor private func requireDetail(_ app: XCUIApplication) throws {
        guard app.staticTexts["detail-screen"].waitForExistence(timeout: 8),
              app.staticTexts["screen-state"].label == "Detail 4" else {
            throw PlatformRequest.rejection("Select did not open the center cell detail")
        }
    }
}
