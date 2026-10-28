import XCTest
import Network
import Foundation
import UIKit

final class TritonIOSRunnerTests: XCTestCase {
    /// Fixture-only proof: readiness/activation do not imply usable orientation.
    /// Run explicitly; the resident session still selects only testServe.
    func testCrossAppObservationWithoutOrientation() throws {
        let config = try RunnerConfiguration(environment: ["TRITON_RUNNER_TOKEN": "fixture-only-test-token", "TRITON_RUNNER_SESSION": "geometry-fixture"])
        let fixture = XCUIApplication(bundleIdentifier: "dev.tritonkit.runnerfixture")
        fixture.launch()
        defer { fixture.terminate() }
        XCTAssertTrue(fixture.buttons["incrementButton"].waitForExistence(timeout: 10))
        var orientation = "portrait"
        let ui = IOSRunnerUI(config: config, fixture: fixture, geometryProvider: { app in
            RunnerObservationGeometry(width: Double(app.frame.width), height: Double(app.frame.height), orientation: orientation)
        })
        let probe = try ui.perform("/probe", body: [:])
        XCTAssertEqual(probe["automationReady"] as? Bool, true)
        #if targetEnvironment(simulator)
        XCTAssertEqual(probe["supportedDeviceButtons"] as? [String], ["home"])
        for button in ["volume-up", "volume-down"] {
            XCTAssertThrowsError(try ui.perform("/crossApp", body: ["app": "fixture", "expectedBundle": "dev.tritonkit.runnerfixture", "operation": "press", "button": button])) { error in
                XCTAssertEqual((error as? ProtocolFailure)?.code, "cross_app_button")
                XCTAssertEqual((error as? ProtocolFailure)?.status, 501)
                XCTAssertTrue((error as? ProtocolFailure)?.message.contains("Simulator") ?? false)
            }
        }
        #else
        XCTAssertEqual(probe["supportedDeviceButtons"] as? [String], ["home", "volume-up", "volume-down"])
        #endif
        let base: [String: Any] = ["app": "fixture", "expectedBundle": "dev.tritonkit.runnerfixture"]
        func request(_ operation: String, _ extra: [String: Any] = [:]) -> [String: Any] {
            base.merging(["operation": operation]) { _, value in value }.merging(extra) { _, value in value }
        }
        XCTAssertEqual(try ui.perform("/crossApp", body: request("activate"))["foregroundVerified"] as? Bool, true)
        let first = try ui.perform("/crossApp", body: request("inspect"))
        let oldID = try XCTUnwrap(first["observationID"] as? String)
        let oldGeometry = try XCTUnwrap(first["geometry"] as? [String: Any])
        orientation = "unknown"
        let inspect = try ui.perform("/crossApp", body: request("inspect"))
        XCTAssertEqual(inspect["partial"] as? Bool, true)
        XCTAssertNil(inspect["observationID"])
        XCTAssertNil(inspect["geometry"])
        XCTAssertTrue((inspect["returnedCount"] as? Int ?? 0) > 0)
        let screenshot = try ui.perform("/crossApp", body: request("screenshot"))
        XCTAssertEqual(screenshot["coordinateActionsAvailable"] as? Bool, false)
        XCTAssertNotNil(screenshot["pngBase64"])
        XCTAssertNil(screenshot["observationID"])
        XCTAssertThrowsError(try ui.perform("/crossApp", body: request("coordinateTap", ["observationID": oldID, "geometry": oldGeometry, "x": 10, "y": 20]))) { error in
            XCTAssertEqual((error as? ProtocolFailure)?.code, "coordinate_stale")
        }
        fixture.terminate()
        XCTAssertThrowsError(try ui.perform("/crossApp", body: request("inspect"))) { error in
            XCTAssertEqual((error as? ProtocolFailure)?.code, "cross_app_not_foreground")
        }
    }

    func testServe() throws {
        continueAfterFailure = false
        let config = try RunnerConfiguration(environment: ProcessInfo.processInfo.environment)
        print("TritonIOSRunner start at \(Date().timeIntervalSince1970); TTL \(config.ttl) seconds")
        executionTimeAllowance = config.ttl + 60
        let fixture = XCUIApplication(bundleIdentifier: "dev.tritonkit.runnerfixture")
        fixture.launch()
        XCTAssertTrue(fixture.buttons["incrementButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(fixture.staticTexts["counterValue"].waitForExistence(timeout: 10))
        let ui = IOSRunnerUI(config: config, fixture: fixture)
        let server = try IOSRunnerServer(config: config, perform: ui.perform)
        server.start()
        let tick = Timer(timeInterval: 0.1, repeats: true) { _ in }
        RunLoop.current.add(tick, forMode: .default)
        defer { tick.invalidate() }
        let until = ProcessInfo.processInfo.systemUptime + config.ttl
        while !server.stopped && ProcessInfo.processInfo.systemUptime < until {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        server.stop()
        if let failure = server.listenerFailure { throw ProtocolFailure("listener_failed", failure, status: 503) }
        print("TritonIOSRunner stopped at \(Date().timeIntervalSince1970)")
    }
}


final class IOSRunnerUI {
    private static var supportedDeviceButtons: [String] {
        #if targetEnvironment(simulator)
        return ["home"]
        #else
        return ["home", "volume-up", "volume-down"]
        #endif
    }
    private let config: RunnerConfiguration
    private let fixture: XCUIApplication
    private let geometryProvider: (XCUIApplication) -> RunnerObservationGeometry
    private var observedApp: String?
    private var observedAt: Date?
    private var observedID: String?
    private var observedGeometry: RunnerGeometry?
    private var observedElements: [[String: String]] = []
    init(config: RunnerConfiguration, fixture: XCUIApplication,
         geometryProvider: ((XCUIApplication) -> RunnerObservationGeometry)? = nil) {
        self.config = config; self.fixture = fixture
        self.geometryProvider = geometryProvider ?? { app in
            let frame = app.frame
            return RunnerObservationGeometry(width: Double(frame.width), height: Double(frame.height),
                orientation: Self.orientationName(XCUIDevice.shared.orientation))
        }
    }
    func perform(_ path: String, body: [String: Any]) throws -> [String: Any] {
        if path == "/environment" { return try performEnvironment(RunnerEnvironmentRequest(body: body)) }
        if path == "/crossApp" { return try performCrossApp(CrossAppRequest(body: body, allowedBundles: config.allowedBundles)) }
        if path == "/home" { XCUIDevice.shared.press(.home); return ["submitted": true] }
        if path == "/activateFixture" { fixture.activate(); return ["state": fixture.state.rawValue] }
        let state = fixture.state
        if path == "/probe" {
            let ready = state == .runningForeground && fixture.buttons["incrementButton"].exists && fixture.staticTexts["counterValue"].exists
            return ["appState": state.rawValue, "automationReady": ready, "fixtureForeground": state == .runningForeground, "runnerApplicationState": UIApplication.shared.applicationState.rawValue, "supportedDeviceButtons": Self.supportedDeviceButtons]
        }
        guard state == .runningForeground else { throw ProtocolFailure("fixture_not_foreground", "Fixture must be foreground for this request", status: 409) }
        if path == "/snapshot" {
            let label = fixture.staticTexts["counterValue"].label
            return ["bundleID": "dev.tritonkit.runnerfixture", "counterLabel": label, "incrementExists": fixture.buttons["incrementButton"].exists, "scope": "two-known-identifiers"]
        }
        if path == "/screenshot" {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            guard data.count <= 8 * 1024 * 1024 else { throw ProtocolFailure("screenshot_budget", "PNG exceeds 8 MiB", status: 413) }
            return ["pngBase64": data.base64EncodedString(), "byteCount": data.count, "captureScope": "device-screen", "postconditionVerified": false]
        }
        if path == "/tap" {
            guard let expected = body["expectedCounter"] as? Int, expected >= 0, expected < Int.max,
                  let before = Int(fixture.staticTexts["counterValue"].label) else { throw ProtocolFailure("invalid_counter", "Valid expectedCounter and counter element required") }
            guard before == expected else { throw ProtocolFailure("precondition_failed", "Counter differs from expectedCounter", status: 409) }
            fixture.buttons["incrementButton"].tap()
            let counter = fixture.staticTexts["counterValue"]
            let deadline = Date().addingTimeInterval(5)
            var after = Int(counter.label)
            while after != expected + 1 && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                after = Int(counter.label)
            }
            guard after == expected + 1 else { throw ProtocolFailure("postcondition_failed", "Tap submitted but counter postcondition failed", status: 409) }
            return ["before": before, "counter": after!, "postconditionVerified": true]
        }
        throw ProtocolFailure("route_rejected", "Unsupported route")
    }
    private func clearObserved() {
        observedApp = nil; observedAt = nil; observedID = nil; observedGeometry = nil; observedElements = []
    }
    private static func orientationName(_ value: UIDeviceOrientation) -> String {
        switch value {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portrait-upside-down"
        case .landscapeLeft: return "landscape-left"
        case .landscapeRight: return "landscape-right"
        default: return "unknown"
        }
    }
    private func foregroundBundle() throws -> String? {
        let foreground = config.allowedBundles.sorted().filter {
            ($0 == "dev.tritonkit.runnerfixture" ? fixture : XCUIApplication(bundleIdentifier: $0)).state == .runningForeground
        }
        guard foreground.count <= 1 else { throw ProtocolFailure("foreground_ambiguous", "Multiple allowlisted apps report foreground", status: 409) }
        return foreground.first
    }
    private func performEnvironment(_ request: RunnerEnvironmentRequest) throws -> [String: Any] {
        if request.operation == "orientation" {
            let previous = Self.orientationName(XCUIDevice.shared.orientation)
            if let orientation = request.orientation {
                clearObserved()
                switch orientation {
                case "portrait": XCUIDevice.shared.orientation = .portrait
                case "portrait-upside-down": XCUIDevice.shared.orientation = .portraitUpsideDown
                case "landscape-left": XCUIDevice.shared.orientation = .landscapeLeft
                case "landscape-right": XCUIDevice.shared.orientation = .landscapeRight
                default: throw ProtocolFailure("environment_orientation", "Unsupported orientation")
                }
            }
            let current = Self.orientationName(XCUIDevice.shared.orientation)
            return ["operation": "orientation", "orientation": current, "previousOrientation": previous,
                    "submitted": request.orientation != nil, "verified": request.orientation.map { $0 == current } ?? (current != "unknown"),
                    "source": "public-xctest-runner", "verification": "device-orientation-readback-not-app-layout"]
        }
        let foreground = try foregroundBundle()
        var result: [String: Any] = ["operation": request.operation, "bundleID": foreground as Any? ?? NSNull(),
                                    "observed": foreground != nil, "scope": "session-allowlist", "source": "public-xctest-runner"]
        if request.operation == "screen" {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            guard data.count <= 8 * 1024 * 1024 else { throw ProtocolFailure("screenshot_budget", "PNG exceeds 8 MiB", status: 413) }
            result["pngBase64"] = data.base64EncodedString(); result["byteCount"] = data.count
            result["captureScope"] = "device-screen"; result["postconditionVerified"] = false
        }
        return result
    }
    private func liveGeometry(_ app: XCUIApplication) throws -> RunnerGeometry {
        try geometryProvider(app).requireCoordinateGeometry()
    }
    private func observeGeometry(_ app: XCUIApplication, bundleID: String) throws -> [String: Any] {
        guard app.state == .runningForeground else {
            throw ProtocolFailure("cross_app_not_foreground", "Bound app left foreground while observing; activate and inspect again", status: 409)
        }
        let observation = geometryProvider(app)
        try observation.requireUsableFrame()
        observedApp = bundleID; observedAt = Date(); observedGeometry = observation.geometry
        // Never preserve a previous coordinate lease when orientation is unavailable.
        observedID = observation.geometry == nil ? nil : UUID().uuidString
        var result = observation.json
        result["partial"] = observation.geometry == nil
        result["appAlertPresent"] = app.alerts.firstMatch.exists
        result["systemAlertDetection"] = "not-probed"
        if let observedID {
            result["observationID"] = observedID
            result["coordinateSpace"] = "app-frame-points"; result["expiresAfterSeconds"] = 30
        }
        return result
    }
    private func performCrossApp(_ request: CrossAppRequest) throws -> [String: Any] {
        let app = request.bundleID == "dev.tritonkit.runnerfixture" ? fixture : XCUIApplication(bundleIdentifier: request.bundleID)
        var result: [String: Any] = ["app": request.app, "bundleID": request.bundleID]
        if request.operation == "activate" {
            clearObserved()
            app.activate()
            let foreground = app.wait(for: .runningForeground, timeout: 10)
            guard foreground else { throw ProtocolFailure("cross_app_activation", "Whitelisted app did not reach foreground", status: 409) }
            result["state"] = app.state.rawValue; result["foregroundVerified"] = true
            return result
        }
        let state = app.state
        result["state"] = state.rawValue
        if request.operation == "probe" {
            result["foreground"] = state == .runningForeground
            result["runnerApplicationState"] = UIApplication.shared.applicationState.rawValue
            if state == .runningForeground {
                var counts = ["buttons": app.buttons.count, "textFields": app.textFields.count, "searchFields": app.searchFields.count, "navigationBars": app.navigationBars.count]
                if request.app == "calculator" { counts["keys"] = app.keys.count }
                result["counts"] = counts
                if request.app == "calculator" { result["numericDisplays"] = calculatorNumericDisplays(app) }
            }
            return result
        }
        guard state == .runningForeground else { throw ProtocolFailure("cross_app_not_foreground", "Bound app must be foreground", status: 409) }
        if request.operation == "inspect" {
            clearObserved()
            // The result is bounded. XCTest may obtain a larger internal AX
            // snapshot to implement these public queries.
            let types: [XCUIElement.ElementType] = [.button, .textField, .searchField, .textView, .secureTextField, .staticText, .key, .switch, .cell, .link]
            var elements: [[String: String]] = []
            var total = 0
            var totalUnknown = false
            for type in types {
                guard elements.count < request.limit else { totalUnknown = true; break }
                let query = app.descendants(matching: type)
                // Preserve accessibility-element identities from one query
                // result instead of resolving indexes against a later tree.
                // A transition may still remove an element after `exists`;
                // public XCTest does not provide an atomic snapshot transaction.
                let candidates = query.allElementsBoundByAccessibilityElement
                total += candidates.count
                for element in candidates.prefix(max(0, request.limit - elements.count)) {
                    guard element.exists else { continue }
                    elements.append(["type": String(describing: type), "identifier": String(element.identifier.prefix(160)), "label": String(element.label.prefix(160))])
                }
            }
            result.merge(try observeGeometry(app, bundleID: request.bundleID)) { _, value in value }; observedElements = elements
            result["scope"] = "bounded-return-not-bounded-XCTest-snapshot"
            result["elements"] = elements; result["returnedCount"] = elements.count
            result["limit"] = request.limit; result["truncated"] = totalUnknown || total > elements.count
            result["totalUnknown"] = totalUnknown
            if request.app == "calculator" { result["numericDisplays"] = calculatorNumericDisplays(app) }
            return result
        }
        if request.operation == "screenshot" {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            guard data.count <= 8 * 1024 * 1024 else { throw ProtocolFailure("screenshot_budget", "PNG exceeds 8 MiB after encoding", status: 413) }
            result["pngBase64"] = data.base64EncodedString(); result["byteCount"] = data.count
            result["captureScope"] = "device-screen"; result["postconditionVerified"] = false
            clearObserved(); result.merge(try observeGeometry(app, bundleID: request.bundleID)) { _, value in value }
            return result
        }
        if let coordinate = request.coordinate {
            guard observedApp == request.bundleID, observedGeometry != nil, observedID != nil else { throw ProtocolFailure("coordinate_stale", "Inspect this allowlisted app before coordinates", status: 409) }
            try coordinate.validate(observationID: observedID, observedAt: observedAt, now: Date(), geometry: liveGeometry(app))
            // Consume the observation before submission. An unknown outcome cannot reuse it.
            clearObserved()
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: coordinate.x, dy: coordinate.y))
            if request.operation == "coordinateSwipe" {
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: coordinate.endX!, dy: coordinate.endY!))
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: hypot(coordinate.endX! - coordinate.x, coordinate.endY! - coordinate.y) / coordinate.duration), thenHoldForDuration: 0)
            } else if request.operation == "coordinateDoubleTap" { start.doubleTap() }
            else { start.tap() }
            result["submitted"] = true; result["postconditionVerified"] = false
            result["gestureSemantics"] = request.operation == "coordinateDoubleTap" ? "public-XCUICoordinate-doubleTap" : "public-XCUICoordinate"
            return result
        }
        if request.operation == "press" {
            clearObserved()
            switch request.button {
            case "home": XCUIDevice.shared.press(.home)
            #if targetEnvironment(simulator)
            case "volume-up", "volume-down":
                throw ProtocolFailure("cross_app_button", "Volume buttons are unsupported by public XCTest in iOS Simulator; no button press was submitted.", status: 501)
            #else
            case "volume-up": XCUIDevice.shared.press(.volumeUp)
            case "volume-down": XCUIDevice.shared.press(.volumeDown)
            #endif
            default: throw ProtocolFailure("cross_app_button", "Unsupported public XCTest button")
            }
            result["submitted"] = true; result["postconditionVerified"] = false; result["button"] = request.button
            result["stateAfter"] = app.state.rawValue
            return result
        }
        if request.operation == "home" {
            clearObserved(); XCUIDevice.shared.press(.home)
            result["submitted"] = true; result["stateAfter"] = app.state.rawValue
            return result
        }
        if request.operation == "scroll" {
            clearObserved()
            switch request.direction {
            case "up": app.swipeUp()
            case "down": app.swipeDown()
            case "left": app.swipeLeft()
            case "right": app.swipeRight()
            default: throw ProtocolFailure("cross_app_direction", "Unsupported direction")
            }
            result["submitted"] = true; result["postconditionVerified"] = false
            return result
        }
        guard let selector = request.selector,
              observedApp == request.bundleID, let inspected = observedAt, Date().timeIntervalSince(inspected) <= 30,
              observedElements.contains(where: { $0[selector.kind] == selector.value }) else {
            throw ProtocolFailure("cross_app_unobserved", "Selector must come from the latest inspect (within 30 seconds)", status: 409)
        }
        let query: XCUIElementQuery
        if request.operation == "back" {
            query = app.navigationBars.buttons
        } else if ["typeText", "navigateExample"].contains(request.operation) {
            query = app.descendants(matching: .any).matching(NSPredicate(format: "elementType == %d OR elementType == %d OR elementType == %d", XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.searchField.rawValue, XCUIElement.ElementType.textView.rawValue))
        } else {
            query = app.descendants(matching: .any)
        }
        let matches = query.matching(NSPredicate(format: "\(selector.kind) == %@", selector.value))
        let liveElements = matches.allElementsBoundByAccessibilityElement
        guard liveElements.count == 1, let element = liveElements.first else { throw ProtocolFailure("cross_app_ambiguous", "Live selector must match exactly one eligible element", status: 409) }
        guard element.exists, element.isHittable else { throw ProtocolFailure("cross_app_not_hittable", "Observed element is not currently hittable", status: 409) }
        if request.operation == "navigateExample" {
            let addressNames = safariAddressNames
            guard [.textField, .searchField].contains(element.elementType),
                  addressNames.contains(element.identifier) || addressNames.contains(element.label) else {
                throw ProtocolFailure("cross_app_address", "Only a recognized Safari address/search field may navigate", status: 409)
            }
        }
        // Clear before an operation so a subsequent action requires a fresh
        // observation even if XCTest reports an error or the page changes.
        clearObserved()
        if ["typeText", "navigateExample"].contains(request.operation) {
            element.tap()
            let (editable, focusEvidence) = try resolveFocusedEditable(app, safariAddressOnly: request.operation == "navigateExample", original: selector)
            result["focusEvidence"] = focusEvidence
            if request.operation == "navigateExample" {
                // The address field value is used only locally to clear it; it
                // is never returned or logged. Refuse unknown or long values.
                guard let existing = editable.value as? String, existing.count <= 2048 else {
                    throw ProtocolFailure("cross_app_address", "Cannot safely clear the observed address field", status: 409)
                }
                editable.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: max(1, existing.count + 1)))
                let (clearedField, clearedFocusEvidence) = try resolveFocusedEditable(app, safariAddressOnly: true, original: selector)
                let cleared = clearedField.value as? String ?? "unknown"
                let placeholders = ["", "Search or enter website", "Search or enter URL", "搜索或输入网站", "搜索或输入网址"]
                guard placeholders.contains(cleared) else { throw ProtocolFailure("cross_app_address", "Address field was not verified empty; navigation refused", status: 409) }
                result["focusEvidenceAfterClear"] = clearedFocusEvidence
                clearedField.typeText("https://example.com\n")
            } else { editable.typeText(request.text!) }
        } else if request.operation == "doubleTap" { element.doubleTap(); result["gestureSemantics"] = "public-XCUIElement-doubleTap" }
        else { element.tap() }
        result["submitted"] = true; result["postconditionVerified"] = false
        result["stateAfter"] = app.state.rawValue
        return result
    }
    private var safariAddressNames: [String] {
        ["URL", "Address", "TabBarItemTitle", "地址", "Search or enter website", "Search or enter URL", "搜索或输入网站", "搜索或输入网址"]
    }
    private func resolveFocusedEditable(_ app: XCUIApplication, safariAddressOnly: Bool, original: CrossAppSelector) throws -> (XCUIElement, String) {
        guard app.state == .runningForeground else { throw ProtocolFailure("cross_app_not_foreground", "App changed while focusing field", status: 409) }
        let types: [XCUIElement.ElementType] = safariAddressOnly ? [.textField, .searchField] : [.textField, .searchField, .textView]
        var candidates: [XCUIElement] = []
        for type in types {
            for candidate in app.descendants(matching: type).allElementsBoundByAccessibilityElement {
                guard candidate.exists, candidate.isHittable else { continue }
                if safariAddressOnly && !safariAddressNames.contains(candidate.identifier) && !safariAddressNames.contains(candidate.label) { continue }
                candidates.append(candidate)
            }
        }
        let focused = candidates.filter { $0.hasFocus }
        if focused.count == 1, let field = focused.first {
            if !safariAddressOnly {
                let matchesOriginal = original.kind == "identifier" ? field.identifier == original.value : field.label == original.value
                guard matchesOriginal else { throw ProtocolFailure("cross_app_focus", "Focused field does not match the observed selector", status: 409) }
            }
            return (field, "public-hasFocus")
        }
        guard focused.isEmpty, candidates.count == 1, let field = candidates.first,
              app.keyboards.firstMatch.exists else {
            throw ProtocolFailure("cross_app_focus", "Focused editable field is absent or ambiguous", status: 409)
        }
        if !safariAddressOnly {
            let matchesOriginal = original.kind == "identifier" ? field.identifier == original.value : field.label == original.value
            guard matchesOriginal else { throw ProtocolFailure("cross_app_focus", "Unique field does not match the observed selector", status: 409) }
        }
        return (field, "unique-editable-field-with-keyboard")
    }
    private func calculatorNumericDisplays(_ app: XCUIApplication) -> [[String: String]] {
        // These are exact candidate identifiers, not a claim that every OS uses
        // them. No match yields an empty result for screenshot-based validation.
        let identifiers = ["CalculatorResult", "CalculatorResults", "Result"]
        var result: [[String: String]] = []
        for identifier in identifiers {
            let query = app.descendants(matching: .any).matching(identifier: identifier)
            guard query.count == 1, let value = query.element(boundBy: 0).value as? String,
                  !value.isEmpty, value.count <= 64,
                  value.range(of: "^[-+0-9.,eE ×÷=]+$", options: .regularExpression) == value.startIndex..<value.endIndex else { continue }
            result.append(["identifier": identifier, "numericValue": value])
        }
        return result
    }
}
