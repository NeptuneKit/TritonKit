import Foundation
import CoreFoundation

struct ProtocolFailure: Error {
    let code: String
    let message: String
    let status: Int
    init(_ code: String, _ message: String, status: Int = 400) {
        self.code = code; self.message = message; self.status = status
    }
}

struct RunnerHTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
    var requestID: String { headers["x-request-id"] ?? "" }
    var fingerprint: Data { Data((method + " " + path + "\n").utf8) + body }
    /// Called only after RunnerServer has authenticated and decrypted the frame.
    func validate(session: String) throws {
        guard headers["authorization"] == nil else {
            throw ProtocolFailure("legacy_authentication_rejected", "Bearer authentication is not accepted by protocol v2", status: 401)
        }
        guard headers["x-session-id"] == session else {
            throw ProtocolFailure("session_mismatch", "Session binding does not match", status: 409)
        }
        guard !requestID.isEmpty, requestID.utf8.count <= 128,
              requestID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }) else {
            throw ProtocolFailure("invalid_request_id", "A bounded X-Request-ID is required")
        }
        let allowed = ["/probe", "/snapshot", "/screenshot", "/tap", "/receipt", "/stop", "/home", "/activateFixture", "/crossApp", "/environment"]
        guard (method == "GET" && path == "/health") || (method == "POST" && allowed.contains(path)) else {
            throw ProtocolFailure("route_rejected", "Method or path not supported", status: 405)
        }
    }
    func jsonBody() throws -> [String: Any] {
        if body.isEmpty { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw ProtocolFailure("invalid_json", "JSON object required")
        }
        return object
    }
}

struct RunnerConfiguration {
    let token: String
    let session: String
    let port: UInt16
    let ttl: TimeInterval
    let allowedBundles: Set<String>
    init(environment: [String: String]) throws {
        token = environment["TRITON_RUNNER_TOKEN"] ?? ""
        session = environment["TRITON_RUNNER_SESSION"] ?? ""
        guard token.utf8.count >= 16, token.utf8.count <= 256, !session.isEmpty, session.utf8.count <= 128 else {
            throw ProtocolFailure("configuration_missing", "Runner token (16...256 bytes) and session required")
        }
        guard let parsedPort = UInt16(environment["TRITON_RUNNER_PORT"] ?? "19439"), parsedPort > 0,
              let parsedTTL = Double(environment["TRITON_RUNNER_TTL"] ?? "300"), parsedTTL.isFinite,
              parsedTTL >= 10, parsedTTL <= 3600 else {
            throw ProtocolFailure("configuration_invalid", "Port or TTL is invalid")
        }
        let raw = environment["TRITON_RUNNER_ALLOWED_BUNDLES"] ?? ""
        let requested = raw.isEmpty ? [] : raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard requested.count <= 32, requested.allSatisfy({ Self.validBundle($0) }) else {
            throw ProtocolFailure("configuration_invalid", "Allowed bundles must be a bounded comma-separated list of bundle IDs")
        }
        allowedBundles = Set(requested).union(["dev.tritonkit.runnerfixture"])
        port = parsedPort; ttl = parsedTTL
    }
    static func validBundle(_ value: String) -> Bool {
        value.utf8.count <= 255 && value.contains(".") && !value.hasPrefix(".") && !value.hasSuffix(".") && !value.contains("..") && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || ".-".contains($0)) }
    }
}

/// Strongly validated point-space geometry, never screenshot pixels.
struct RunnerGeometry: Equatable {
    let width: Double
    let height: Double
    let orientation: String
    var json: [String: Any] { ["width": width, "height": height, "orientation": orientation] }
    init(body: [String: Any]) throws {
        guard Set(body.keys) == ["width", "height", "orientation"],
              let w = Self.number(body["width"]), let h = Self.number(body["height"]),
              w > 0, h > 0, w <= 32768, h <= 32768,
              let o = body["orientation"] as? String, RunnerEnvironmentRequest.orientations.contains(o) else {
            throw ProtocolFailure("coordinate_geometry", "Finite positive point geometry and orientation required")
        }
        width = w; height = h; orientation = o
    }
    static func number(_ value: Any?) -> Double? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite else { return nil }
        return n.doubleValue
    }
}
struct RunnerCoordinateRequest {
    let observationID: String
    let geometry: RunnerGeometry
    let x: Double
    let y: Double
    let endX: Double?
    let endY: Double?
    let duration: Double
    init(body: [String: Any], swipe: Bool) throws {
        guard let id = body["observationID"] as? String, !id.isEmpty, id.utf8.count <= 128,
              let raw = body["geometry"] as? [String: Any] else { throw ProtocolFailure("coordinate_observation", "Latest observationID and point geometry required") }
        observationID = id; geometry = try RunnerGeometry(body: raw)
        guard let px = RunnerGeometry.number(body["x"]), let py = RunnerGeometry.number(body["y"]),
              px >= 0, py >= 0, px < geometry.width, py < geometry.height else {
            throw ProtocolFailure("coordinate_bounds", "Finite coordinate must be inside observed geometry")
        }
        x = px; y = py
        if swipe {
            guard let ex = RunnerGeometry.number(body["endX"]), let ey = RunnerGeometry.number(body["endY"]),
                  ex >= 0, ey >= 0, ex < geometry.width, ey < geometry.height,
                  let d = RunnerGeometry.number(body["duration"]), (0.05...5).contains(d) else {
                throw ProtocolFailure("coordinate_bounds", "Swipe end and finite duration 0.05...5 required")
            }
            endX = ex; endY = ey; duration = d
        } else {
            guard body["endX"] == nil, body["endY"] == nil, body["duration"] == nil else { throw ProtocolFailure("coordinate_bounds", "Swipe fields only apply to coordinateSwipe") }
            endX = nil; endY = nil; duration = 0
        }
    }
    func validate(observationID currentID: String?, observedAt: Date?, now: Date, geometry live: RunnerGeometry) throws {
        guard observationID == currentID, let observedAt, (0...30).contains(now.timeIntervalSince(observedAt)), geometry == live else {
            throw ProtocolFailure("coordinate_stale", "Observation expired or live geometry changed; inspect again", status: 409)
        }
    }
}
struct RunnerEnvironmentRequest {
    static let orientations: Set<String> = ["portrait", "landscape-left", "landscape-right", "portrait-upside-down"]
    let operation: String
    let orientation: String?
    init(body: [String: Any]) throws {
        guard Set(body.keys).isSubset(of: ["operation", "orientation"]),
              let op = body["operation"] as? String, ["orientation", "foreground", "screen"].contains(op) else {
            throw ProtocolFailure("environment_operation", "Supported environment operation required")
        }
        operation = op
        if let raw = body["orientation"] {
            guard op == "orientation", let value = raw as? String, Self.orientations.contains(value) else { throw ProtocolFailure("environment_orientation", "Unsupported orientation") }
            orientation = value
        } else { orientation = nil }
    }
}

struct CrossAppSelector {
    let kind: String
    let value: String
}

struct CrossAppRequest {
    static let testPhrase = "TritonKit resident runner probe"
    static let bundles = ["fixture": "dev.tritonkit.runnerfixture", "settings": "com.apple.Preferences", "calculator": "com.apple.calculator", "safari": "com.apple.mobilesafari"]
    let app: String
    let bundleID: String
    let operation: String
    let selector: CrossAppSelector?
    let direction: String?
    let text: String?
    let limit: Int
    let coordinate: RunnerCoordinateRequest?
    let button: String?
    init(body: [String: Any], allowedBundles: Set<String> = Set(bundles.values)) throws {
        let keys: Set<String> = ["app", "operation", "expectedBundle", "selector", "direction", "text", "limit", "observationID", "geometry", "x", "y", "endX", "endY", "duration", "button"]
        guard Set(body.keys).isSubset(of: keys),
              let alias = body["app"] as? String,
              let bundle = body["expectedBundle"] as? String, RunnerConfiguration.validBundle(bundle),
              (alias == "target" || Self.bundles[alias] == bundle),
              allowedBundles.contains(bundle) else {
            throw ProtocolFailure("cross_app_binding", "Whitelisted app and matching expectedBundle required")
        }
        let operations = ["activate", "probe", "inspect", "tap", "typeText", "scroll", "home", "back", "screenshot", "navigateExample", "doubleTap", "coordinateTap", "coordinateDoubleTap", "coordinateSwipe", "press"]
        guard let op = body["operation"] as? String, operations.contains(op) else {
            throw ProtocolFailure("cross_app_operation", "Unsupported cross-app operation")
        }
        app = alias; bundleID = bundle; operation = op
        if ["coordinateTap", "coordinateDoubleTap", "coordinateSwipe"].contains(op) {
            coordinate = try RunnerCoordinateRequest(body: body, swipe: op == "coordinateSwipe")
            guard body["selector"] == nil else { throw ProtocolFailure("cross_app_selector", "Coordinate actions do not accept a selector") }
        } else {
            guard ["observationID", "geometry", "x", "y", "endX", "endY", "duration"].allSatisfy({ body[$0] == nil }) else { throw ProtocolFailure("coordinate_bounds", "Coordinate fields only apply to coordinate actions") }
            coordinate = nil
        }
        if op == "press" {
            guard let value = body["button"] as? String, ["home", "volume-up", "volume-down"].contains(value) else { throw ProtocolFailure("cross_app_button", "Supported public XCTest device button required") }
            button = value
        } else {
            guard body["button"] == nil else { throw ProtocolFailure("cross_app_button", "Button only applies to press") }; button = nil
        }
        if let raw = body["selector"] {
            guard let object = raw as? [String: Any], Set(object.keys) == ["kind", "value"],
                  let kind = object["kind"] as? String, ["identifier", "label"].contains(kind),
                  let value = object["value"] as? String, !value.isEmpty, value.count <= 160 else {
                throw ProtocolFailure("cross_app_selector", "Bounded exact identifier or label selector required")
            }
            selector = CrossAppSelector(kind: kind, value: value)
        } else { selector = nil }
        if ["tap", "doubleTap", "typeText", "back", "navigateExample"].contains(op), selector == nil {
            throw ProtocolFailure("cross_app_selector", "This operation requires an observed selector")
        }
        if let raw = body["limit"] {
            guard let parsed = raw as? Int, (1...40).contains(parsed) else { throw ProtocolFailure("cross_app_limit", "Inspect limit must be 1...40") }
            limit = parsed
        } else { limit = 40 }
        if op == "scroll" {
            guard let parsed = body["direction"] as? String, ["up", "down", "left", "right"].contains(parsed) else {
                throw ProtocolFailure("cross_app_direction", "Scroll direction required")
            }
            direction = parsed
        } else {
            guard body["direction"] == nil else { throw ProtocolFailure("cross_app_direction", "Direction only applies to scroll") }
            direction = nil
        }
        if op == "typeText" {
            guard let value = body["text"] as? String, !value.isEmpty, value.utf8.count <= 4096 else {
                throw ProtocolFailure("cross_app_text", "Text must be a nonempty string of at most 4096 UTF-8 bytes")
            }
            text = value
        } else {
            guard body["text"] == nil else { throw ProtocolFailure("cross_app_text", "Text only applies to typeText") }; text = nil
        }
        if op == "navigateExample", bundle != Self.bundles["safari"] {
            throw ProtocolFailure("cross_app_navigation", "Fixed example.com navigation is Safari-only")
        }
    }
}

final class BoundedHTTPParser {
    static let headerLimit = 16 * 1024
    static let bodyLimit = 64 * 1024
    private var buffer = Data()
    private var finished = false
    func append(_ data: Data) throws -> RunnerHTTPRequest? {
        guard !finished else { throw ProtocolFailure("request_complete", "One request per connection") }
        guard buffer.count + data.count <= Self.headerLimit + Self.bodyLimit else {
            throw ProtocolFailure("payload_too_large", "Request exceeds byte budget", status: 413)
        }
        buffer.append(data)
        let delimiter = Data("\r\n\r\n".utf8)
        guard let range = buffer.range(of: delimiter) else {
            guard buffer.count <= Self.headerLimit else { throw ProtocolFailure("headers_too_large", "Header budget exceeded", status: 413) }
            return nil
        }
        guard range.upperBound <= Self.headerLimit,
              let header = String(data: buffer[..<range.lowerBound], encoding: .utf8) else {
            throw ProtocolFailure("invalid_headers", "Invalid or oversized headers")
        }
        let lines = header.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")
        guard parts.count == 3, parts[2] == "HTTP/1.1" else { throw ProtocolFailure("invalid_request", "HTTP/1.1 required") }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { throw ProtocolFailure("invalid_headers", "Malformed header") }
            let key = String(line[..<colon]).lowercased()
            guard !key.isEmpty, headers[key] == nil else { throw ProtocolFailure("invalid_headers", "Duplicate header rejected") }
            headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard headers["transfer-encoding"] == nil else { throw ProtocolFailure("unsupported_encoding", "Chunked requests not supported") }
        let lengthText = headers["content-length"] ?? "0"
        guard !lengthText.isEmpty, lengthText.allSatisfy({ $0.isNumber }), let length = Int(lengthText), length >= 0 else {
            throw ProtocolFailure("invalid_length", "Invalid Content-Length")
        }
        guard length <= Self.bodyLimit else { throw ProtocolFailure("payload_too_large", "Body budget exceeded", status: 413) }
        let required = range.upperBound + length
        guard buffer.count >= required else { return nil }
        guard buffer.count == required else { throw ProtocolFailure("extra_bytes", "Pipelined or trailing bytes rejected") }
        finished = true
        return RunnerHTTPRequest(method: String(parts[0]), path: String(parts[1]), headers: headers, body: Data(buffer[range.upperBound..<required]))
    }
}

/// Receipts are session-local and bounded. A repeated ID never executes again,
/// including while the original action is still pending.
final class RequestLedger {
    static let maxCachedBytes = 32 * 1024 * 1024
    static let normalReceiptBytes = 512 * 1024
    static let screenshotReceiptBytes = 12 * 1024 * 1024
    private struct Entry { let fingerprint: Data; var envelope: [String: Any]; let reservedBytes: Int; let completed: Bool }
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var allocatedBytes = 0
    var cachedByteBudgetUsed: Int { lock.lock(); defer { lock.unlock() }; return allocatedBytes }
    var count: Int { lock.lock(); defer { lock.unlock() }; return entries.count }
    func claim(_ request: RunnerHTTPRequest) throws -> [String: Any]? {
        lock.lock(); defer { lock.unlock() }
        if let entry = entries[request.requestID] {
            guard entry.fingerprint == request.fingerprint else { throw ProtocolFailure("request_id_conflict", "Request ID was used for another payload", status: 409) }
            return entry.envelope
        }
        guard entries.count < 256 else { throw ProtocolFailure("receipt_budget", "Session receipt budget exhausted", status: 429) }
        let screenshot = request.path == "/screenshot" || (request.path == "/crossApp" && (try? request.jsonBody()["operation"] as? String) == "screenshot") || (request.path == "/environment" && (try? request.jsonBody()["operation"] as? String) == "screen")
        let responseBytes = screenshot ? Self.screenshotReceiptBytes : Self.normalReceiptBytes
        let reservation = request.fingerprint.count + responseBytes + 512
        guard allocatedBytes + reservation <= Self.maxCachedBytes else {
            throw ProtocolFailure("receipt_byte_budget", "Session receipt byte budget exhausted; start a new session", status: 429)
        }
        allocatedBytes += reservation
        entries[request.requestID] = Entry(fingerprint: request.fingerprint, envelope: ["status": "pending"], reservedBytes: reservation, completed: false)
        return nil
    }
    func complete(requestID: String, envelope: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries[requestID], !entry.completed else { return }
        let available = entry.reservedBytes - entry.fingerprint.count - 512
        let size = (try? JSONSerialization.data(withJSONObject: envelope).count) ?? Int.max
        var completed = envelope
        if size > available {
            completed["ok"] = false; completed["result"] = NSNull()
            completed["error"] = ["code": "receipt_size_budget", "message": "Receipt exceeded its reserved byte budget; action outcome requires independent verification"]
        }
        // Keep the original ID and fingerprint forever in this session, even
        // when the result exceeds budget. Never re-execute an evicted action.
        let retained = entry.fingerprint.count + ((try? JSONSerialization.data(withJSONObject: completed).count) ?? available) + 512
        allocatedBytes -= entry.reservedBytes - retained
        entries[requestID] = Entry(fingerprint: entry.fingerprint, envelope: completed, reservedBytes: retained, completed: true)
    }
    func receipt(_ requestID: String) -> [String: Any]? {
        lock.lock(); defer { lock.unlock() }; return entries[requestID]?.envelope
    }
}
