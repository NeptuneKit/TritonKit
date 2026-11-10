import Foundation

/// Completion may race cancellation. All callback state stays synchronized and
/// remains alive for a late URLSession callback after the caller has returned.
private final class AIHTTPResult: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<(Data, URLResponse), Error>?

    func store(_ value: Result<(Data, URLResponse), Error>) {
        lock.lock()
        result = value
        lock.unlock()
    }

    func get() throws -> (Data, URLResponse) {
        lock.lock()
        let value = result
        lock.unlock()
        guard let value else { throw URLError(.badServerResponse) }
        return try value.get()
    }
}

/// A total wall-clock budget, independent of URLSession's inactivity timeout.
/// HTTP status interpretation belongs to the selected provider; there is no retry
/// or fallback here. Session/deadline injection is for controlled transport tests.
func postAIJSON(
    url: URL,
    body: Data,
    headers: [String: String],
    timeoutSeconds: TimeInterval = 30,
    session: URLSession = .shared
) throws -> (Data, URLResponse) {
    guard timeoutSeconds.isFinite, timeoutSeconds > 0 else { throw URLError(.timedOut) }
    let deadline = DispatchTime.now() + timeoutSeconds
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.timeoutInterval = timeoutSeconds
    for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
    let completion = DispatchSemaphore(value: 0)
    let result = AIHTTPResult()
    let task = session.dataTask(with: request) { data, response, error in
        if let error {
            result.store(.failure(error))
        } else if let response {
            result.store(.success((data ?? Data(), response)))
        } else {
            result.store(.failure(URLError(.badServerResponse)))
        }
        completion.signal()
    }
    task.resume()
    guard completion.wait(timeout: deadline) == .success else {
        task.cancel()
        throw URLError(.timedOut)
    }
    return try result.get()
}
