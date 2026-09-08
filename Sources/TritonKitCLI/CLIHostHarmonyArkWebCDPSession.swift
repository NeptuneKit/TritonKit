import Foundation

/// Injectable transport keeps real CDP response parsing and deadline handling in tests.
protocol HarmonyArkWebCDPTransport: Sendable {
    func sendMessage(_ data: Data) async throws
    func receiveMessage() async throws -> Data
    func cancelTransport()
}

extension URLSessionWebSocketTask: HarmonyArkWebCDPTransport {
    func sendMessage(_ data: Data) async throws { try await send(.data(data)) }

    func receiveMessage() async throws -> Data {
        switch try await receive() {
        case .data(let data): return data
        case .string(let text): return Data(text.utf8)
        @unknown default: return Data()
        }
    }

    func cancelTransport() { cancel(with: .goingAway, reason: nil) }
}

/// One evaluate operation owns the complete send/event/response deadline.
final class HarmonyArkWebURLSessionCDPSession: HarmonyArkWebCDPSession {
    private let transport: any HarmonyArkWebCDPTransport
    private let lock = NSLock()
    private var nextMessageID = 1

    init(url: URL, session: URLSession = .shared) {
        let task = session.webSocketTask(with: url)
        transport = task
        task.resume()
    }

    init(transport: any HarmonyArkWebCDPTransport) { self.transport = transport }

    func evaluate(expression: String, timeoutSeconds: Double) async throws -> String? {
        let messageID = lock.withLock {
            defer { nextMessageID += 1 }
            return nextMessageID
        }
        let payload: [String: Any] = [
            "id": messageID,
            "method": "Runtime.evaluate",
            "params": ["expression": expression, "returnByValue": true],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let transport = self.transport
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: String?.self) { group in
                defer { group.cancelAll() }
                group.addTask {
                    try await transport.sendMessage(data)
                    while true {
                        try Task.checkCancellation()
                        let messageData = try await transport.receiveMessage()
                        guard let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
                              (json["id"] as? Int) == messageID else { continue }
                        if let error = json["error"] as? [String: Any] {
                            throw HarmonyArkWebBridgeCallError.javascriptError(
                                "CDP Runtime.evaluate failed: \(error["message"] as? String ?? "protocol error")"
                            )
                        }
                        guard let result = json["result"] as? [String: Any] else {
                            throw HarmonyArkWebBridgeCallError.javascriptError("CDP Runtime.evaluate response is missing result.")
                        }
                        if let exception = result["exceptionDetails"] as? [String: Any] {
                            throw HarmonyArkWebBridgeCallError.javascriptError(
                                exception["text"] as? String ?? "Runtime.evaluate threw"
                            )
                        }
                        guard let inner = result["result"] as? [String: Any] else {
                            throw HarmonyArkWebBridgeCallError.javascriptError("CDP Runtime.evaluate response is missing remote object.")
                        }
                        if let value = inner["value"] as? String { return value }
                        if (inner["type"] as? String) == "undefined" { return nil }
                        if let value = inner["value"] {
                            return String(data: try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]), encoding: .utf8)
                        }
                        return nil
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(max(0.001, min(timeoutSeconds, 300)) * 1_000_000_000))
                    // Cancelling the actual socket releases a pending receive before the
                    // structured task group waits for its children to exit.
                    transport.cancelTransport()
                    throw HarmonyArkWebBridgeCallError.bridgeTimeout("CDP Runtime.evaluate timed out after \(Int(timeoutSeconds * 1000)) ms.")
                }
                do {
                    return try await group.next() ?? nil
                } catch {
                    transport.cancelTransport()
                    if Date() >= deadline {
                        throw HarmonyArkWebBridgeCallError.bridgeTimeout("CDP Runtime.evaluate deadline exceeded.")
                    }
                    throw error
                }
            }
        } onCancel: {
            transport.cancelTransport()
        }
    }

    func close() async { transport.cancelTransport() }
}
