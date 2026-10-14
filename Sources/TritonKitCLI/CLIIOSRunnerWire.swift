import Foundation
import CoreFoundation

struct IOSRunnerConnection {
    let scope: String
    let targetAddress: String
    let port: UInt16
    let token: String
    let sessionID: String
}

struct IOSRunnerWireResponse {
    let envelope: [String: Any]
    var rawEnvelope: [String: Any] { envelope }
    var ok: Bool { envelope["ok"] as? Bool == true }
    var result: [String: Any]? { envelope["result"] as? [String: Any] }
    var error: [String: Any]? { envelope["error"] as? [String: Any] }
    var sessionID: String? { envelope["sessionID"] as? String }
    var requestID: String? { envelope["requestID"] as? String }
    func serializedEnvelope() throws -> Data {
        try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
    }

    func decodedScreenshot(maxPixels: UInt64 = 40_000_000) throws -> Data {
        guard ok, let result, let encoded = result["pngBase64"] as? String,
              encoded.utf8.count <= 11_184_812, let png = Data(base64Encoded: encoded),
              png.count >= 33, png.count <= 8 * 1024 * 1024,
              let byteCount = IOSRunnerWire.strictInteger(result["byteCount"]), byteCount == png.count,
              png.prefix(8) == Data([137, 80, 78, 71, 13, 10, 26, 10]),
              png[8..<16] == Data([0, 0, 0, 13, 73, 72, 68, 82]) else {
            throw IOSRunnerWireError("screenshot_invalid")
        }
        let width = UInt64(IOSRunnerWire.bigEndian32(png, at: 16))
        let height = UInt64(IOSRunnerWire.bigEndian32(png, at: 20))
        guard width > 0, height > 0, width <= 32768, height <= 32768,
              maxPixels > 0, width * height <= maxPixels else {
            throw IOSRunnerWireError("screenshot_dimension_budget")
        }
        return png
    }
}

struct IOSRunnerWireError: Error {
    let cause: String
    init(_ cause: String) { self.cause = cause }
}

enum IOSRunnerWire {
    static let maximumResponseBytes = 12 * 1024 * 1024
    static let maximumHeaderBytes = 16 * 1024
    static let maximumBodyBytes = 64 * 1024
    static let delimiter = Data("\r\n\r\n".utf8)

    static func strictInteger(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double.rounded(.towardZero) == double,
              double >= Double(Int.min), double < Double(Int.max) else { return nil }
        return number.intValue
    }

    static func bigEndian32(_ data: Data, at index: Int) -> UInt32 {
        data[index..<index + 4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    static func validHeaderValue(_ value: String, maximum: Int) -> Bool {
        !value.isEmpty && value.utf8.count <= maximum && value.utf8.allSatisfy { $0 > 32 && $0 < 127 }
    }

    static func request(connection: IOSRunnerConnection, route: String, body: Data?, requestID: String) throws -> Data {
        let normalized = route.hasPrefix("/") ? String(route.dropFirst()) : route
        let routes: Set<String> = ["health", "probe", "snapshot", "screenshot", "tap", "receipt", "stop", "home", "activateFixture", "crossApp", "environment"]
        guard routes.contains(normalized), connection.port > 0,
              ["real", "simulator"].contains(connection.scope),
              (connection.scope != "simulator" || connection.targetAddress == "127.0.0.1"),
              validHeaderValue(connection.targetAddress, maximum: 256),
              validHeaderValue(connection.token, maximum: 4096),
              validHeaderValue(connection.sessionID, maximum: 256),
              validHeaderValue(requestID, maximum: 128),
              requestID.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 95].contains($0) }) else {
            throw IOSRunnerWireError("request_invalid")
        }
        let payload = normalized == "health" ? Data() : (body ?? Data("{}".utf8))
        guard payload.count <= maximumBodyBytes else { throw IOSRunnerWireError("request_body_budget") }
        if normalized != "health" {
            guard (try? JSONSerialization.jsonObject(with: payload)) is [String: Any] else {
                throw IOSRunnerWireError("request_body_invalid")
            }
        } else if let body, !body.isEmpty { throw IOSRunnerWireError("request_body_invalid") }
        let method = normalized == "health" ? "GET" : "POST"
        let header = "\(method) /\(normalized) HTTP/1.1\r\nHost: 127.0.0.1:\(connection.port)\r\nAuthorization: Bearer \(connection.token)\r\nX-Session-ID: \(connection.sessionID)\r\nX-Request-ID: \(requestID)\r\nAccept: application/json\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        guard header.utf8.count <= maximumHeaderBytes else { throw IOSRunnerWireError("request_header_budget") }
        return Data(header.utf8) + payload
    }

    static func httpHeader(_ data: Data) throws -> (status: Int, bodyOffset: Int, bodyLength: Int)? {
        guard let range = data.range(of: delimiter) else {
            guard data.count <= maximumHeaderBytes else { throw IOSRunnerWireError("http_header_budget") }
            return nil
        }
        guard range.upperBound <= maximumHeaderBytes,
              let text = String(data: data[..<range.lowerBound], encoding: .utf8),
              text.utf8.allSatisfy({ $0 == 9 || $0 == 10 || $0 == 13 || (32...126).contains($0) }) else {
            throw IOSRunnerWireError("http_header_invalid")
        }
        let lines = text.components(separatedBy: "\r\n")
        let statusParts = lines[0].split(separator: " ", omittingEmptySubsequences: true)
        guard statusParts.count >= 2, ["HTTP/1.1", "HTTP/1.0"].contains(String(statusParts[0])),
              statusParts[1].count == 3, let status = Int(statusParts[1]), (200...599).contains(status),
              !(300...399).contains(status) else { throw IOSRunnerWireError("http_status_invalid") }
        var fields: [String: String] = [:]
        for line in lines.dropFirst() {
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"), let colon = line.firstIndex(of: ":") else {
                throw IOSRunnerWireError("http_header_invalid")
            }
            let name = String(line[..<colon]).lowercased()
            guard !name.isEmpty, name.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }),
                  fields[name] == nil else { throw IOSRunnerWireError("http_header_duplicate") }
            fields[name] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        guard fields["transfer-encoding"] == nil,
              let contentLength = fields["content-length"], !contentLength.isEmpty,
              contentLength.utf8.allSatisfy({ (48...57).contains($0) }), let length = Int(contentLength),
              length > 0, length <= maximumResponseBytes,
              let contentType = fields["content-type"], contentType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces).lowercased() == "application/json" else {
            throw IOSRunnerWireError("http_framing_invalid")
        }
        return (status, range.upperBound, length)
    }

    static func parseHTTPResponse(_ data: Data, sessionID: String, requestID: String) throws -> IOSRunnerWireResponse {
        guard let header = try httpHeader(data), data.count == header.bodyOffset + header.bodyLength,
              var envelope = (try? JSONSerialization.jsonObject(with: Data(data[header.bodyOffset...]))) as? [String: Any],
              let boolean = envelope["ok"] as? NSNumber, CFGetTypeID(boolean) == CFBooleanGetTypeID() else {
            throw IOSRunnerWireError("response_invalid")
        }
        guard envelope["sessionID"] as? String == sessionID else { throw IOSRunnerWireError("session_mismatch") }
        guard envelope["requestID"] as? String == requestID else { throw IOSRunnerWireError("request_mismatch") }
        if boolean.boolValue {
            guard (200...299).contains(header.status), envelope["result"] is [String: Any],
                  envelope["error"] == nil || envelope["error"] is NSNull else {
                throw IOSRunnerWireError("response_status_mismatch")
            }
        } else {
            guard var error = envelope["error"] as? [String: Any], let code = error["code"] as? String,
                  !code.isEmpty, code.utf8.count <= 256 else { throw IOSRunnerWireError("response_error_invalid") }
            error["retryable"] = false
            envelope["error"] = error
        }
        return IOSRunnerWireResponse(envelope: envelope)
    }
}
