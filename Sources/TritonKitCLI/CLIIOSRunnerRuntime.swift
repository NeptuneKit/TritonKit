import Foundation
import Security
import CoreFoundation

/// CLI and HTTP use this service and the same cross-process store and locks.
final class IOSRunnerService: @unchecked Sendable {
    let dependencies: IOSRunnerDependencies
    init(dependencies: IOSRunnerDependencies = .live) { self.dependencies = dependencies }

    func execute(operation: String, payload: Data) throws -> Data {
        do {
            guard let input = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else { throw IOSRunnerFailure("ios_runner_invalid_payload", "Expected a JSON object.") }
            guard ["doctor", "prepare", "start", "status", "stop", "request", "receipt"].contains(operation) else { throw IOSRunnerFailure("ios_runner_invalid_operation", "Unsupported Runner operation.") }
            guard let device = input["device"] as? String, !device.isEmpty else { throw IOSRunnerFailure("ios_runner_explicit_device_required", "Select an explicit iOS device.") }
            // Ownership and target locks are global. sessionRoot only selects private artifacts.
            let root = dependencies.registryRoot
            let cachedStore = try IOSRunnerSessionStore(root: root, device: device)
            let target: IOSRunnerTarget
            if ["status", "stop"].contains(operation), device.hasPrefix("ios-real:") || device.hasPrefix("sim:"),
               let cached = try cachedStore.read("session", as: IOSRunnerSession.self) {
                guard cached.target.device == device else { throw IOSRunnerFailure("ios_runner_session_target_mismatch", "Stored Runner binding does not match this selector.") }
                target = cached.target
            } else { target = try dependencies.resolve(device) }
            let store = target.device == device ? cachedStore : try IOSRunnerSessionStore(root: root, device: target.device)
            return try store.locked {
                let result: [String: Any]
                switch operation {
                case "doctor":
                    let resource = (try? dependencies.project()) != nil
                    let tool = try? dependencies.command(["/usr/bin/xcodebuild", "-version"], 10)
                    result = ["operation": operation, "device": target.device, "scope": target.scope, "bundledProjectAvailable": resource, "xcodeAvailable": tool?.status == 0, "readyToPrepare": resource && tool?.status == 0]
                case "prepare": result = try prepare(target, payload: input, store: store)
                case "start": result = try start(target, payload: input, store: store)
                case "status": result = try status(target, payload: input, store: store)
                case "stop": result = try stop(target, payload: input, store: store)
                case "request", "receipt": return try request(target, operation: operation, payload: input, store: store)
                default: throw IOSRunnerFailure("ios_runner_invalid_operation", "Unsupported Runner operation.")
                }
                return try iosRunnerJSON(["ok": true, "result": iosRunnerSanitize(result), "error": NSNull()])
            }
        } catch let error as IOSRunnerFailure {
            var failure: [String: Any] = ["code": error.code, "message": error.message, "retryable": false]
            if let startup = error.startup { failure["startup"] = startup.json }
            return try iosRunnerJSON(["ok": false, "result": NSNull(), "error": failure])
        } catch {
            // Native errors may contain private target IDs, signing identities, and paths.
            return try iosRunnerJSON(["ok": false, "result": NSNull(), "error": ["code": "ios_runner_internal", "message": "Runner operation failed; private state is retained for recovery.", "retryable": false]])
        }
    }
    func duration(_ payload: [String: Any], key: String, fallback: Double, range: ClosedRange<Double>) throws -> Double {
        guard let value = payload[key] else { return fallback }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), range.contains(number.doubleValue), number.doubleValue.isFinite else { throw IOSRunnerFailure("ios_runner_invalid_" + key, "Invalid " + key + " duration.") }
        return number.doubleValue
    }
    func boundSession(_ target: IOSRunnerTarget, store: IOSRunnerSessionStore) throws -> IOSRunnerSession {
        guard let session = try store.read("session", as: IOSRunnerSession.self) else { throw IOSRunnerFailure("ios_runner_session_missing", "Run prepare and start for this device first.") }
        guard session.target == target else { throw IOSRunnerFailure("ios_runner_session_target_mismatch", "Stored Runner session belongs to a different target.") }
        return session
    }
    func start(_ target: IOSRunnerTarget, payload: [String: Any], store: IOSRunnerSessionStore) throws -> [String: Any] {
        if let previous = try store.read("session", as: IOSRunnerSession.self), let pid = previous.pid, dependencies.ownsProcess(pid, previous.xctestrun) {
            throw IOSRunnerFailure("ios_runner_already_running", "This target already has an owned Runner session; use status or stop.")
        }
        if let previous = try store.read("session", as: IOSRunnerSession.self), let pid = previous.pid, dependencies.processExists(pid) != false { throw IOSRunnerFailure("ios_runner_owner_unknown", "Previous native process exit is unverified; recover or stop that session before starting another.") }
        guard let prepared = try store.read("prepared", as: IOSRunnerPrepared.self), prepared.version == 1, prepared.target == target else { throw IOSRunnerFailure("ios_runner_prepare_required", "Run device runner prepare for this target before starting.") }
        let installed = try dependencies.project()
        guard prepared.resourceDigest == (try resourceFingerprint(installed)) else { throw IOSRunnerFailure("ios_runner_prepare_required", "Bundled Runner changed; run prepare before starting a new session.") }
        let ttl = try duration(payload, key: "ttl", fallback: 600, range: 10...3600)
        let timeout = try duration(payload, key: "timeout", fallback: 120, range: 1...120)
        let allowed = try allowedBundles(payload)
        let artifactStore: IOSRunnerSessionStore
        if let artifactRoot = payload["sessionRoot"] as? String {
            artifactStore = try IOSRunnerSessionStore(root: URL(fileURLWithPath: NSString(string: artifactRoot).expandingTildeInPath), device: target.device)
        } else { artifactStore = store }
        let directory = try artifactStore.newDirectory()
        let sessionID = UUID().uuidString
        var secret = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, secret.count, &secret) == errSecSuccess else { throw IOSRunnerFailure("ios_runner_entropy_failed", "Could not create private Runner credentials.") }
        let token = secret.map { String(format: "%02x", $0) }.joined()
        let configuration = try configureTestRun(source: URL(fileURLWithPath: prepared.xctestrun), sessionID: sessionID, token: token, ttl: ttl, bundles: allowed)
        let xctestrun = directory.appendingPathComponent("session.xctestrun")
        try IOSRunnerSessionStore.writeExclusive(configuration, to: xctestrun)
        let now = dependencies.now()
        var session = IOSRunnerSession(target: target, sessionID: sessionID, token: token, port: 19439, createdAt: now, expiresAt: now.addingTimeInterval(ttl), xctestrun: xctestrun.path, directory: directory.path, allowedBundles: allowed, pid: nil, state: "starting")
        try store.write(session, name: "session")
        let args = ["/usr/bin/xcodebuild", "test-without-building", "-xctestrun", xctestrun.path, "-destination", "platform=" + (target.scope == "real" ? "iOS" : "iOS Simulator") + ",id=" + target.address,
                    "-only-testing:TritonIOSRunnerTests/TritonIOSRunnerTests/testServe", "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES", "-maximum-test-execution-time-allowance", String(Int(ttl + 120)), "-resultBundlePath", directory.appendingPathComponent("result.xcresult").path]
        var startup = IOSRunnerStartupDiagnostics()
        do {
            do { session.pid = try dependencies.launch(args, directory) }
            catch {
                throw IOSRunnerFailure("ios_runner_native_launch_failed", "Native XCTest process could not be launched. Check the selected Xcode installation and private session diagnostics before preparing a fresh session.", startup: startup)
            }
            startup.launchVerified = true
            try store.write(session, name: "session")
            try IOSRunnerSessionStore.writeExclusive(try JSONEncoder().encode(session), to: directory.appendingPathComponent("owner.json"))
            let deadline = dependencies.now().addingTimeInterval(timeout)
            while dependencies.now() < deadline {
                guard let pid = session.pid, dependencies.ownsProcess(pid, session.xctestrun) else { break }
                let health = dependencies.exchange(session, "/health", nil, UUID().uuidString, min(2, max(0.01, deadline.timeIntervalSince(dependencies.now()))))
                if (health.envelope["error"] as? [String: Any])?["code"] as? String != "ios_runner_transport_unknown" {
                    startup.transportVerified = true
                }
                if health.ok, health.result?["networkReady"] as? Bool == true {
                    startup.healthVerified = true
                    let probe = dependencies.exchange(session, "/probe", Data("{}".utf8), UUID().uuidString, min(8, max(0.01, deadline.timeIntervalSince(dependencies.now()))))
                    if probe.ok, probe.result?["automationReady"] as? Bool == true {
                        session.state = "ready"; try store.write(session, name: "session")
                        return ["operation": "start", "device": target.device, "sessionID": sessionID, "state": "ready", "automationReady": true, "ttlSeconds": ttl, "ownershipVerified": true]
                    }
                }
                if !startup.healthVerified, iosRunnerDriverChannelRefused(directory: directory) {
                    throw startup.failure(driverChannelRefused: true, nativeExited: false)
                }
                dependencies.sleep(0.25)
            }
            let exited = session.pid.map { dependencies.processExists($0) == false } ?? false
            throw startup.failure(driverChannelRefused: !startup.healthVerified && iosRunnerDriverChannelRefused(directory: directory), nativeExited: exited)
        } catch {
            session.state = "startup_failed"
            if let pid = session.pid, dependencies.ownsProcess(pid, session.xctestrun) { _ = dependencies.terminate(pid, session.xctestrun) }
            if let pid = session.pid, dependencies.processExists(pid) != false { session.state = "stop_unknown" }
            try? store.write(session, name: "session")
            throw error
        }
    }

    func allowedBundles(_ payload: [String: Any]) throws -> [String] {
        let fixture = "dev.tritonkit.runnerfixture"
        guard payload["allowBundles"] == nil || payload["allowBundles"] is [String] else { throw IOSRunnerFailure("ios_runner_invalid_allow_bundles", "allowBundles must be a JSON string array.") }
        let input = payload["allowBundles"] as? [String] ?? []
        guard input.count <= 31, input.allSatisfy({ $0.utf8.count <= 255 && $0.range(of: "^[A-Za-z0-9][A-Za-z0-9.-]+$", options: .regularExpression) != nil }) else { throw IOSRunnerFailure("ios_runner_invalid_allow_bundles", "Supply up to 31 exact bundle identifiers; wildcards are unsupported.") }
        return Array(Set(input + [fixture])).sorted()
    }
    func configureTestRun(source: URL, sessionID: String, token: String, ttl: Double, bundles: [String]) throws -> Data {
        let original = try PropertyListSerialization.propertyList(from: Data(contentsOf: source), format: nil)
        var targets = 0
        func rewrite(_ value: Any) -> Any {
            if let text = value as? String { return text.replacingOccurrences(of: "__TESTROOT__", with: source.deletingLastPathComponent().path) }
            if let array = value as? [Any] { return array.map(rewrite) }
            if let dict = value as? [String: Any] {
                var output = dict.mapValues(rewrite)
                if (dict["TestBundlePath"] as? String)?.contains("TritonIOSRunnerTests.xctest") == true {
                    targets += 1
                    var env = output["EnvironmentVariables"] as? [String: Any] ?? [:]
                    env.merge(["TRITON_RUNNER_TOKEN": token, "TRITON_RUNNER_SESSION": sessionID, "TRITON_RUNNER_PORT": "19439", "TRITON_RUNNER_TTL": String(ttl), "TRITON_RUNNER_ALLOWED_BUNDLES": bundles.joined(separator: ",")]) { _, new in new }
                    output["EnvironmentVariables"] = env
                }
                return output
            }
            return value
        }
        let configuration = rewrite(original)
        guard targets == 1 else { throw IOSRunnerFailure("ios_runner_test_configuration_invalid", "Expected exactly one bundled Runner test target.") }
        return try PropertyListSerialization.data(fromPropertyList: configuration, format: .xml, options: 0)
    }
    func status(_ target: IOSRunnerTarget, payload: [String: Any], store: IOSRunnerSessionStore) throws -> [String: Any] {
        guard let stored = try store.read("session", as: IOSRunnerSession.self) else {
            let prepared = try store.read("prepared", as: IOSRunnerPrepared.self)
            return ["operation": "status", "device": target.device, "state": prepared?.target == target ? "prepared" : "absent", "automationReady": false]
        }
        guard stored.target == target else { throw IOSRunnerFailure("ios_runner_session_target_mismatch", "Stored Runner session belongs to a different target.") }
        let owned = stored.pid.map { dependencies.ownsProcess($0, stored.xctestrun) } ?? false
        let expired = dependencies.now() >= stored.expiresAt
        let exited = stored.pid.map { dependencies.processExists($0) == false } ?? false
        let verifiedStopped = stored.state == "stopped" && exited
        var state = verifiedStopped ? "stopped" : expired ? "expired" : owned ? stored.state : exited ? "native_exited" : "ownership_unknown"
        var health = false
        if owned && !expired {
            let response = dependencies.exchange(stored, "/health", nil, UUID().uuidString, try duration(payload, key: "timeout", fallback: 10, range: 1...120))
            health = response.ok
            // status never triggers a UI query. Readiness was established by start; transport ownership remains dynamic.
            state = health ? "network_ready" : "unreachable"
        }
        return ["operation": "status", "device": target.device, "sessionID": stored.sessionID, "state": state, "healthVerified": health, "automationReady": NSNull(), "automationPreviouslyVerified": stored.state == "ready", "ownershipVerified": owned, "expired": expired, "remainingSeconds": max(0, stored.expiresAt.timeIntervalSince(dependencies.now()))]
    }
    func stop(_ target: IOSRunnerTarget, payload: [String: Any], store: IOSRunnerSessionStore) throws -> [String: Any] {
        var session = try boundSession(target, store: store)
        let timeout = try duration(payload, key: "timeout", fallback: 30, range: 1...120)
        guard let pid = session.pid else { throw IOSRunnerFailure("ios_runner_owner_missing", "This session has no recorded native process owner.") }
        let owned = dependencies.ownsProcess(pid, session.xctestrun)
        var acknowledged = false, fallback = false
        if owned {
            let response = dependencies.exchange(session, "/stop", Data("{}".utf8), UUID().uuidString, min(5, timeout))
            acknowledged = response.ok
            let deadline = dependencies.now().addingTimeInterval(timeout)
            while dependencies.ownsProcess(pid, session.xctestrun), dependencies.now() < deadline { dependencies.sleep(0.1) }
            if dependencies.ownsProcess(pid, session.xctestrun) { fallback = dependencies.terminate(pid, session.xctestrun) }
        }
        let exited = dependencies.processExists(pid) == false
        session.state = exited ? "stopped" : "stop_unknown"
        try store.write(session, name: "session")
        guard exited else { throw IOSRunnerFailure("ios_runner_stop_unknown", "Native Runner exit could not be verified; private ownership information is retained.") }
        return ["operation": "stop", "device": target.device, "sessionID": session.sessionID, "state": "stopped", "stopAcknowledged": acknowledged, "nativeExited": true, "ownershipVerifiedBeforeStop": owned, "ownedTerminationUsed": fallback]
    }
    func request(_ target: IOSRunnerTarget, operation: String, payload: [String: Any], store: IOSRunnerSessionStore) throws -> Data {
        let session = try boundSession(target, store: store)
        guard session.state == "ready", dependencies.now() < session.expiresAt, let pid = session.pid, dependencies.ownsProcess(pid, session.xctestrun) else { throw IOSRunnerFailure("ios_runner_session_not_ready", "Start a fresh Runner session before sending actions.") }
        let timeout = try duration(payload, key: "timeout", fallback: 18, range: 1...120)
        let requestID = payload["requestID"] as? String ?? UUID().uuidString
        guard requestID.utf8.count <= 128, !requestID.isEmpty, requestID.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else { throw IOSRunnerFailure("ios_runner_invalid_request_id", "requestID must be a bounded identifier.") }
        let route: String
        let body: [String: Any]
        if operation == "receipt" {
            guard let actionRequestID = (payload["actionRequestID"] as? String) ?? (payload["requestID"] as? String), !actionRequestID.isEmpty, actionRequestID.utf8.count <= 128 else { throw IOSRunnerFailure("ios_runner_action_request_id_required", "receipt requires an existing actionRequestID.") }
            route = "/receipt"; body = ["actionRequestID": actionRequestID]
        } else {
            route = "/" + (payload["route"] as? String ?? "crossApp").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard ["/crossApp", "/probe", "/snapshot", "/tap", "/screenshot", "/home", "/activateFixture", "/environment"].contains(route) else { throw IOSRunnerFailure("ios_runner_invalid_route", "Use a supported Runner action route.") }
            guard payload["body"] == nil || payload["body"] is [String: Any] else { throw IOSRunnerFailure("ios_runner_invalid_payload", "Action body must be a JSON object.") }
            body = payload["body"] as? [String: Any] ?? [:]
            if route == "/crossApp" {
                guard let bundle = body["expectedBundle"] as? String, session.allowedBundles.contains(bundle) else { throw IOSRunnerFailure("ios_runner_bundle_not_allowed", "The target bundle is not enabled for this session.") }
            }
        }
        return try store.locked("action") {
            if let output = payload["screenshotOutput"] as? String {
                try IOSRunnerSessionStore.validateArtifactOutput(URL(fileURLWithPath: NSString(string: output).expandingTildeInPath).standardizedFileURL)
            }
            let encoded = try iosRunnerJSON(body)
            guard encoded.count <= 64 * 1024 else { throw IOSRunnerFailure("ios_runner_body_too_large", "Runner action body exceeds 64 KiB.") }
            let response = dependencies.exchange(session, route, encoded, operation == "receipt" ? UUID().uuidString : requestID, timeout)
            var envelope = iosRunnerSanitize(response.envelope) as? [String: Any] ?? [:]
            if let output = payload["screenshotOutput"] as? String, response.ok {
                do {
                    let imageResponse: IOSRunnerWireResponse
                    if operation == "receipt" {
                        guard let actionID = body["actionRequestID"] as? String,
                              response.result?["found"] as? Bool == true,
                              let nested = response.result?["receipt"] as? [String: Any],
                              nested["sessionID"] as? String == session.sessionID,
                              nested["requestID"] as? String == actionID else {
                            throw IOSRunnerFailure("ios_runner_receipt_image_unverified", "Receipt image is pending or does not match the original action and session.")
                        }
                        imageResponse = IOSRunnerWireResponse(envelope: nested)
                    } else { imageResponse = response }
                    let data = try imageResponse.decodedScreenshot()
                    let url = URL(fileURLWithPath: NSString(string: output).expandingTildeInPath).standardizedFileURL
                    try dependencies.writeArtifact(data, url)
                    var result = envelope["result"] as? [String: Any] ?? [:]
                    result["artifact"] = ["path": url.path, "byteCount": data.count, "format": "png", "sensitive": true]
                    envelope["result"] = result
                } catch {
                    // Image export cannot erase the request identity or imply that the UI action was not delivered.
                    envelope["ok"] = false
                    envelope["artifactError"] = ["code": (error as? IOSRunnerFailure)?.code ?? "ios_runner_screenshot_export_failed"]
                    envelope["error"] = ["code": (error as? IOSRunnerFailure)?.code ?? "ios_runner_screenshot_export_failed", "message": "Screenshot could not be exported; query the original action receipt with a new output path.", "retryable": false, "actionRequestID": body["actionRequestID"] as? String ?? requestID, "delivery": "response_received"]
                }
            }
            // Unknown outcomes are retained and returned once. No transport or action retry occurs here.
            let receipt = ["route": route, "requestID": requestID, "recordedAt": ISO8601DateFormatter().string(from: dependencies.now()), "response": envelope] as [String: Any]
            do {
                try dependencies.writeReceipt(try iosRunnerJSON(receipt), URL(fileURLWithPath: session.directory).appendingPathComponent("receipt-" + UUID().uuidString + ".json"))
            } catch {
                envelope["receiptError"] = ["code": "ios_runner_receipt_save_failed", "message": "Private host receipt could not be saved; query the action by its request ID."]
            }
            return try iosRunnerJSON(envelope)
        }
    }
}
