import XCTest

final class WatchControlTests: XCTestCase {
    @MainActor
    func testControl() throws {
        continueAfterFailure = false
        let request = try PlatformRequest.load(platform: "watchos")
        var succeeded = false
        defer { attachPlatformResult(request, succeeded: succeeded) }
        if request.action == "action-button" {
            guard XCUIDevice.shared.hasHardwareButton(.action) else {
                throw PlatformRequest.rejection("Selected watch has no Action hardware button")
            }
            // Hardware support alone does not define a safe, observable Action postcondition.
            // Do not press a system-configured Action button and claim delivery from a void API.
            throw PlatformRequest.rejection("Action button requires an isolated configured postcondition; no event delivered")
        }
        guard request.action == "crown-rotate", let delta = request.crownDelta,
              delta.isFinite, delta != 0, abs(delta) <= 1000 else {
            throw PlatformRequest.rejection("Unsupported Crown request")
        }
        let app = XCUIApplication()
        app.launch()
        let value = app.staticTexts["crown-value"]
        guard value.waitForExistence(timeout: 8), let before = Double(value.label) else {
            throw PlatformRequest.rejection("Crown fixture has no readable initial value")
        }
        XCUIDevice.shared.rotateDigitalCrown(delta: CGFloat(delta))
        let changed = expectation(for: NSPredicate { _, _ in
            guard let after = Double(value.label) else { return false }
            return after != before && after.isFinite
        }, evaluatedWith: value)
        guard XCTWaiter.wait(for: [changed], timeout: 8) == .completed else {
            throw PlatformRequest.rejection("Crown event did not change the fixture value")
        }
        succeeded = true
    }
}
