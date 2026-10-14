import XCTest
import Network
import Foundation
import UIKit

final class TritonIOSRunnerTests: XCTestCase {
    func testServe() throws {
        continueAfterFailure = false
        let config = try RunnerConfiguration(environment: ProcessInfo.processInfo.environment)
        print("TritonIOSRunner start at \(Date().timeIntervalSince1970); TTL \(config.ttl) seconds")
        executionTimeAllowance = config.ttl + 60
        let fixture = XCUIApplication(bundleIdentifier: "dev.tritonkit.runnerfixture")
        fixture.launch()
        XCTAssertTrue(fixture.buttons["incrementButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(fixture.staticTexts["counterValue"].waitForExistence(timeout: 10))
        let server = try IOSRunnerServer(config: config, fixture: fixture)
        server.start()
        let tick = Timer(timeInterval: 0.1, repeats: true) { _ in }
        RunLoop.current.add(tick, forMode: .default)
        defer { tick.invalidate() }
        let until = Date().addingTimeInterval(config.ttl)
        while !server.stopped && Date() < until {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        server.stop()
        if let failure = server.listenerFailure { throw ProtocolFailure("listener_failed", failure, status: 503) }
        print("TritonIOSRunner stopped at \(Date().timeIntervalSince1970)")
    }
}


final class IOSRunnerServer {
    private let config: RunnerConfiguration
    private let fixture: XCUIApplication
    private let listener: NWListener
    private let queue = DispatchQueue(label: "dev.tritonkit.iosrunner.http")
    private let ledger = RequestLedger()
    private let lock = NSLock()
    private var stopRequested = false
    private var listenerError: String?
    var listenerFailure: String? { lock.lock(); defer { lock.unlock() }; return listenerError }
    private var clients: [ObjectIdentifier: NWConnection] = [:]
    private var uiPending: [(RunnerHTTPRequest, [String: Any], NWConnection)] = []
    private var uiBusy = false
    private var observedApp: String?
    private var observedAt: Date?
    private var observedElements: [[String: String]] = []
    private let started = Date()
    var stopped: Bool { lock.lock(); defer { lock.unlock() }; return stopRequested }
    init(config: RunnerConfiguration, fixture: XCUIApplication) throws {
        self.config = config; self.fixture = fixture
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: config.port)!)
        listener = try NWListener(using: parameters)
    }
    func start() {
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state { print("TritonIOSRunner listener ready at \(Date().timeIntervalSince1970)") }
            if case .failed = state {
                guard let self else { return }
                self.lock.lock(); self.listenerError = "Runner listener failed"; self.lock.unlock()
                self.stop()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
    }
    func stop() {
        lock.lock(); stopRequested = true; lock.unlock()
        listener.cancel()
        queue.async { [weak self] in
            guard let self else { return }
            for client in self.clients.values { client.cancel() }
            self.clients.removeAll()
        }
    }
    private func accept(_ connection: NWConnection) {
        guard clients.count < 8 else { connection.cancel(); return }
        let id = ObjectIdentifier(connection)
        clients[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { self?.clients.removeValue(forKey: id) }
            if case .failed = state { self?.clients.removeValue(forKey: id) }
        }
        connection.start(queue: queue)
        // Connections and incomplete reads have a strict lifetime. Cancelling a
        // connection does not cancel an already dispatched XCTest action.
        queue.asyncAfter(deadline: .now() + 20) { connection.cancel() }
        receive(connection, parser: BoundedHTTPParser())
    }
    private func receive(_ connection: NWConnection, parser: BoundedHTTPParser) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self else { return }
            do {
                if let data, let request = try parser.append(data) { self.handle(request, connection: connection); return }
                if complete || error != nil { connection.cancel(); return }
                self.receive(connection, parser: parser)
            } catch {
                self.send(self.failure(error, requestID: ""), status: (error as? ProtocolFailure)?.status ?? 400, connection: connection)
            }
        }
    }
    private func envelope(ok: Bool, requestID: String, result: Any = NSNull(), error: Any = NSNull()) -> [String: Any] {
        ["ok": ok, "sessionID": config.session, "requestID": requestID, "result": result, "error": error]
    }
    private func failure(_ error: Error, requestID: String) -> [String: Any] {
        let value = error as? ProtocolFailure ?? ProtocolFailure("request_failed", "Request could not be completed")
        return envelope(ok: false, requestID: requestID, error: ["code": value.code, "message": value.message])
    }
    private func handle(_ request: RunnerHTTPRequest, connection: NWConnection) {
        do {
            try request.validate(token: config.token, session: config.session)
            let body = try request.jsonBody()
            if request.path == "/crossApp" { _ = try CrossAppRequest(body: body, allowedBundles: config.allowedBundles) }
            if request.path == "/health" {
                send(envelope(ok: true, requestID: request.requestID, result: ["listenerReady": true, "networkReady": true, "automationReady": false, "uptimeSeconds": Date().timeIntervalSince(started), "ttlSeconds": config.ttl, "backend": "public-xctest-runner"]), connection: connection)
                return
            }
            if request.path == "/receipt" {
                guard let actionID = body["actionRequestID"] as? String, !actionID.isEmpty else { throw ProtocolFailure("invalid_receipt", "actionRequestID required") }
                send(envelope(ok: true, requestID: request.requestID, result: ["found": ledger.receipt(actionID) != nil, "receipt": ledger.receipt(actionID) ?? [:]]), connection: connection)
                return
            }
            if request.path == "/stop" {
                send(envelope(ok: true, requestID: request.requestID, result: ["stopping": true]), connection: connection, after: { [weak self] in self?.stop() })
                return
            }
            let isAction = ["/probe", "/snapshot", "/screenshot", "/tap", "/home", "/activateFixture", "/crossApp"].contains(request.path)
            if isAction, let existing = try ledger.claim(request) {
                let value = existing["status"] as? String == "pending" ? envelope(ok: false, requestID: request.requestID, result: ["status": "pending"], error: ["code": "request_pending", "message": "Original action has not completed"]) : existing
                send(value, status: existing["status"] as? String == "pending" ? 202 : 200, connection: connection)
                return
            }
            guard uiPending.count < 8 else {
                let value = failure(ProtocolFailure("ui_queue_budget", "UI queue budget exhausted", status: 429), requestID: request.requestID)
                if isAction { ledger.complete(requestID: request.requestID, envelope: value) }
                send(value, status: 429, connection: connection)
                return
            }
            uiPending.append((request, body, connection))
            drainUI()
        } catch {
            send(failure(error, requestID: request.requestID), status: (error as? ProtocolFailure)?.status ?? 400, connection: connection)
        }
    }
    private func drainUI() {
        guard !uiBusy, !uiPending.isEmpty else { return }
        uiBusy = true
        let (request, body, connection) = uiPending.removeFirst()
        DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let result: [String: Any]
                let status: Int
                do {
                    guard !self.stopped else { throw ProtocolFailure("session_stopping", "Runner is stopping", status: 409) }
                    result = self.envelope(ok: true, requestID: request.requestID, result: try self.perform(request.path, body: body))
                    status = 200
                } catch {
                    result = self.failure(error, requestID: request.requestID)
                    status = (error as? ProtocolFailure)?.status ?? 500
                }
                if ["/probe", "/snapshot", "/screenshot", "/tap", "/home", "/activateFixture", "/crossApp"].contains(request.path) {
                    self.ledger.complete(requestID: request.requestID, envelope: result)
                }
                let delivered = self.ledger.receipt(request.requestID) ?? result
                self.queue.async {
                    self.send(delivered, status: delivered["ok"] as? Bool == false && status == 200 ? 413 : status, connection: connection)
                    self.uiBusy = false
                    self.drainUI()
                }
            }
    }
    private func perform(_ path: String, body: [String: Any]) throws -> [String: Any] {
        if path == "/crossApp" { return try performCrossApp(CrossAppRequest(body: body, allowedBundles: config.allowedBundles)) }
        if path == "/home" { XCUIDevice.shared.press(.home); return ["submitted": true] }
        if path == "/activateFixture" { fixture.activate(); return ["state": fixture.state.rawValue] }
        let state = fixture.state
        if path == "/probe" {
            let ready = state == .runningForeground && fixture.buttons["incrementButton"].exists && fixture.staticTexts["counterValue"].exists
            return ["appState": state.rawValue, "automationReady": ready, "fixtureForeground": state == .runningForeground, "runnerApplicationState": UIApplication.shared.applicationState.rawValue]
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
        observedApp = nil; observedAt = nil; observedElements = []
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
            observedApp = request.bundleID; observedAt = Date(); observedElements = elements
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
        } else { element.tap() }
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
    private func send(_ body: [String: Any], status: Int = 200, connection: NWConnection, after: (() -> Void)? = nil) {
        guard let json = try? JSONSerialization.data(withJSONObject: body), json.count <= 12 * 1024 * 1024 else { connection.cancel(); return }
        let requestID = body["requestID"] as? String ?? ""
        let header = "HTTP/1.1 \(status) Runner\r\nContent-Type: application/json\r\nContent-Length: \(json.count)\r\nConnection: close\r\nX-Request-ID: \(requestID)\r\n\r\n"
        connection.send(content: Data(header.utf8) + json, completion: .contentProcessed { _ in connection.cancel(); after?() })
    }
}
