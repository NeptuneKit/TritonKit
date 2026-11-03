import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Inference HTTP wall deadlines", .serialized)
struct InferenceDeadlineTests {
    @Test("stalled response is cancelled at the total deadline")
    func stalledResponse() throws {
        let fixture = DeadlineProtocolFixture()
        defer { fixture.session.invalidateAndCancel() }
        let start = Date()
        do {
            _ = try postAIJSON(url: URL(string: "http://inference.invalid/stall")!, body: Data(), headers: [:], timeoutSeconds: 0.1, session: fixture.session)
            Issue.record("Expected total deadline error")
        } catch {
            #expect((error as? URLError)?.code == .timedOut)
        }
        #expect(Date().timeIntervalSince(start) < 0.5)
        #expect(DeadlineURLProtocol.stopped.wait(timeout: .now() + 0.3) == .success)
    }

    @Test("ongoing bytes cannot extend the overall inference budget")
    func drippingResponse() throws {
        let fixture = DeadlineProtocolFixture()
        defer { fixture.session.invalidateAndCancel() }
        let start = Date()
        do {
            _ = try postAIJSON(url: URL(string: "http://inference.invalid/drip")!, body: Data(), headers: [:], timeoutSeconds: 0.15, session: fixture.session)
            Issue.record("Expected total deadline despite ongoing data")
        } catch {
            #expect((error as? URLError)?.code == .timedOut)
        }
        #expect(Date().timeIntervalSince(start) < 0.5)
        #expect(DeadlineURLProtocol.stopped.wait(timeout: .now() + 0.3) == .success)
    }

    @Test("completed response keeps body and HTTP status for provider-specific errors")
    func completedResponse() throws {
        let fixture = DeadlineProtocolFixture()
        defer { fixture.session.invalidateAndCancel() }
        let (data, response) = try postAIJSON(url: URL(string: "http://inference.invalid/status")!, body: Data("request".utf8), headers: ["X-Fixture": "yes"], timeoutSeconds: 1, session: fixture.session)
        #expect((response as? HTTPURLResponse)?.statusCode == 503)
        #expect(String(decoding: data, as: UTF8.self) == "provider unavailable")
    }
}

private struct DeadlineProtocolFixture {
    let session: URLSession
    init() {
        DeadlineURLProtocol.stopped = DispatchSemaphore(value: 0)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeadlineURLProtocol.self]
        session = URLSession(configuration: configuration)
    }
}

private final class DeadlineURLProtocol: URLProtocol, @unchecked Sendable {
    static var stopped = DispatchSemaphore(value: 0)
    private let queue = DispatchQueue(label: "test.inference.deadline")
    private var cancelled = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        queue.async {
            let status = self.request.url!.path == "/status" ? 503 : 200
            self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            if status == 503 {
                self.client?.urlProtocol(self, didLoad: Data("provider unavailable".utf8))
                self.client?.urlProtocolDidFinishLoading(self)
                return
            }
            if self.request.url!.path == "/drip" {
                for index in 1...12 {
                    self.queue.asyncAfter(deadline: .now() + Double(index) * 0.04) {
                        guard !self.cancelled else { return }
                        self.client?.urlProtocol(self, didLoad: Data(" ".utf8))
                    }
                }
            }
            // Always finishes, including the RED version: no hung test or server.
            self.queue.asyncAfter(deadline: .now() + 0.65) {
                guard !self.cancelled else { return }
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    override func stopLoading() {
        queue.async {
            self.cancelled = true
            Self.stopped.signal()
        }
    }
}
