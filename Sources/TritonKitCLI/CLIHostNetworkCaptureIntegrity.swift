import Darwin
import Foundation

/// Local limits are acceptance bounds, never silent truncation or a retention sweep.
let networkCaptureMaximumBytes = 64 * 1024 * 1024
let networkCaptureMaximumLineBytes = 256 * 1024
let networkCaptureMaximumRecords = 100_000
let networkCaptureURLRedaction = "headers-names-only,url-credentials-query-removed"

struct ValidatedNetworkCapture {
    let events: [NetworkProxyServeEvent]
    let data: Data
    let summary: NetworkProxyCaptureExportSummary
}

func readValidatedNetworkCapture(
    sourceURL: URL,
    maximumBytes: Int = networkCaptureMaximumBytes,
    maximumLineBytes: Int = networkCaptureMaximumLineBytes,
    maximumRecords: Int = networkCaptureMaximumRecords
) throws -> ValidatedNetworkCapture {
    guard maximumBytes > 0, maximumLineBytes > 0, maximumRecords > 0 else {
        throw RuntimeError("network_capture_invalid_limit")
    }
    var markerStatus = stat()
    guard lstat(networkCaptureIncompleteMarker(sourceURL).path, &markerStatus) != 0, errno == ENOENT else {
        throw RuntimeError("network_capture_incomplete_source")
    }
    let fd = open(sourceURL.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
    guard fd >= 0 else { throw RuntimeError("network_capture_unreadable_source") }
    var sourceStatus = stat()
    guard fstat(fd, &sourceStatus) == 0, sourceStatus.st_mode & S_IFMT == S_IFREG else {
        close(fd)
        throw RuntimeError("network_capture_nonregular_source")
    }
    guard flock(fd, LOCK_SH) == 0 else {
        close(fd)
        throw RuntimeError("network_capture_lock_failed")
    }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
    defer { _ = flock(fd, LOCK_UN); try? handle.close() }
    var pending = Data()
    var accepted = Data()
    var events: [NetworkProxyServeEvent] = []
    var byteCount = 0
    var recordCount = 0
    var placeholders = 0
    while let chunk = try handle.read(upToCount: 32 * 1024), !chunk.isEmpty {
        byteCount += chunk.count
        guard byteCount <= maximumBytes else { throw RuntimeError("network_capture_byte_limit") }
        pending.append(chunk)
        while let newline = pending.firstIndex(of: 0x0a) {
            let line = Data(pending[..<newline])
            pending.removeSubrange(...newline)
            guard !line.isEmpty, line.count <= maximumLineBytes,
                  String(data: line, encoding: .utf8) != nil else {
                throw RuntimeError("network_capture_invalid_record")
            }
            recordCount += 1
            guard recordCount <= maximumRecords else { throw RuntimeError("network_capture_record_limit") }
            guard let object = try JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let schema = object["schemaVersion"] as? String else {
                throw RuntimeError("network_capture_invalid_record")
            }
            if schema == "triton.proxy.capture.v1" {
                let event = try JSONDecoder().decode(NetworkProxyServeEvent.self, from: line)
                guard event.surface == "host.device-proxy-serve",
                      ["proxy.serve.ready", "proxy.serve.request", "proxy.serve.connection-failed"].contains(event.event),
                      event.redaction == "headers-names-only" || event.redaction == networkCaptureURLRedaction else {
                    throw RuntimeError("network_capture_unknown_record")
                }
                if event.event == "proxy.serve.request" {
                    guard event.ok, let method = event.method, !method.isEmpty,
                          event.url != nil, event.host != nil, event.path != nil else {
                        throw RuntimeError("network_capture_invalid_request")
                    }
                }
                let redacted = try redactedNetworkCaptureEvent(event)
                events.append(redacted)
                accepted.append(Data((try encodeCompactJSON(redacted) + "\n").utf8))
            } else if schema == "triton.network.v1" {
                // This older host-proxy artifact is an explicit unobserved placeholder,
                // not an event summary that may claim arbitrary observed counts.
                guard (object["requestCount"] as? Int) == 0,
                      (object["eventCount"] as? Int) == 0,
                      (object["failureCount"] as? Int) == 0,
                      (object["events"] as? [String])?.isEmpty == true,
                      (object["visibility"] as? String) == "partial",
                      (object["redaction"] as? String) == "default" else {
                    throw RuntimeError("network_capture_invalid_placeholder")
                }
                guard Set(object.keys) == Set(["schemaVersion", "platform", "target", "requestCount", "eventCount", "failureCount", "redaction", "visibility", "events"]),
                      object["platform"] is String, object["target"] is String else {
                    throw RuntimeError("network_capture_invalid_placeholder")
                }
                placeholders += 1
                accepted.append(try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
                accepted.append(0x0a)
            } else {
                throw RuntimeError("network_capture_unknown_schema")
            }
        }
        guard pending.count <= maximumLineBytes else { throw RuntimeError("network_capture_line_limit") }
    }
    guard pending.isEmpty else { throw RuntimeError("network_capture_partial_record") }
    guard recordCount > 0 else { throw RuntimeError("network_capture_empty") }
    guard lstat(networkCaptureIncompleteMarker(sourceURL).path, &markerStatus) != 0, errno == ENOENT else {
        throw RuntimeError("network_capture_incomplete_source")
    }
    let requestCount = events.filter { $0.ok && $0.event == "proxy.serve.request" }.count
    return ValidatedNetworkCapture(
        events: events,
        data: accepted,
        summary: NetworkProxyCaptureExportSummary(
            requestCount: requestCount,
            eventCount: events.count,
            failureCount: events.filter { !$0.ok || $0.event == "proxy.serve.connection-failed" }.count,
            redaction: events.isEmpty ? "default" : networkCaptureURLRedaction,
            truncation: requestCount == 0 ? "not-observed" : (placeholders > 0 ? "partial-source" : "none")
        )
    )
}

func redactedNetworkCaptureURL(_ raw: String) -> String {
    guard var components = URLComponents(string: raw) else { return "<redacted-url>" }
    components.user = nil
    components.password = nil
    components.query = nil
    components.fragment = nil
    return components.string ?? "<redacted-url>"
}

func redactedNetworkCaptureEvent(_ event: NetworkProxyServeEvent) throws -> NetworkProxyServeEvent {
    guard var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any] else {
        throw RuntimeError("network_capture_invalid_event")
    }
    if let url = event.url { object["url"] = redactedNetworkCaptureURL(url) }
    if let path = event.path { object["path"] = redactedNetworkCaptureURL(path) }
    // Failure text can contain the raw request line. Preserve the event classification.
    if event.error != nil { object["error"] = "proxy connection failed; inspect local execution diagnostics" }
    object["redaction"] = networkCaptureURLRedaction
    return try JSONDecoder().decode(NetworkProxyServeEvent.self, from: JSONSerialization.data(withJSONObject: object))
}

func networkCaptureIncompleteMarker(_ sourceURL: URL) -> URL {
    sourceURL.appendingPathExtension("incomplete")
}

func markNetworkCaptureIncomplete(_ sourceURL: URL) throws {
    let markerURL = networkCaptureIncompleteMarker(sourceURL)
    let fd = open(markerURL.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
    if fd < 0 {
        if errno == EEXIST { return }
        throw RuntimeError("network_capture_incomplete_marker_failed")
    }
    defer { close(fd) }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
    try handle.write(contentsOf: Data("network_capture_capacity_exceeded\n".utf8))
}
