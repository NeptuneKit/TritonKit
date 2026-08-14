import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

/// Shared iOS embedded-runtime text-query contract for GitHub #203.
///
/// For the same explicit runtime target and the same visible/enabled AX text node:
/// - `observe tree` / `observe current` expose the node text (authoritative);
/// - `wait --text` matches it;
/// - `act find` matches it;
/// and all three share the same text normalization (trim + case/diacritic fold +
/// substring) and the same visibility rule (hidden nodes are excluded from
/// wait/find but still listed by observe with `hidden` metadata).
///
/// `act find` must never return a successful envelope with zero matches: on "no
/// match" it throws a structured not-found failure that maps to `text_not_found`
/// and a non-zero exit.
@Suite(.serialized)
struct IOSTextQueryConsistencyTests {
    // MARK: Shared fixture

    /// A shared embedded-runtime AX fixture used by observe / wait / find.
    /// Mirrors what `TKRuntimeAXBuilder` emits for a visible UIKit window:
    /// trimmed text, non-hidden nodes only, stable target OIDs.
    private func iosRuntimeTextFixture() -> [TKAXNode] {
        [
            TKAXNode(
                role: "button",
                label: "登录",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 24, y: 120, width: 96, height: 44),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 10,
                className: "UIButton",
                children: []
            ),
            TKAXNode(
                role: "text",
                label: "Complex harness: 1",
                value: nil,
                identifier: "harness-count",
                title: nil,
                frame: TKRect(x: 24, y: 200, width: 200, height: 24),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 11,
                className: "UILabel",
                children: []
            ),
            TKAXNode(
                role: "button",
                label: "Login",
                value: nil,
                identifier: "login-button",
                title: nil,
                frame: TKRect(x: 24, y: 260, width: 120, height: 44),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 12,
                className: "UIButton",
                children: []
            ),
            TKAXNode(
                role: "text",
                label: "Café",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 24, y: 320, width: 80, height: 24),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 13,
                className: "UILabel",
                children: []
            ),
            // Intentionally hidden: wait/find must exclude it, observe still lists it.
            TKAXNode(
                role: "text",
                label: "隐藏子节点",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 24, y: 380, width: 80, height: 24),
                enabled: true,
                focused: false,
                hidden: true,
                targetOID: 14,
                className: "UILabel",
                children: []
            ),
        ]
    }

    // MARK: Shared normalization contract

    @Test("observe exposes the same text that wait and find match with shared normalization")
    func observeWaitFindShareNormalizedText() {
        let nodes = iosRuntimeTextFixture()

        // observe tree / observe current expose the node text (authoritative).
        let observed = observeNodes(fromAX: nodes, source: "runtime-tree", prefix: "ios-runtime")
        let observedTexts = observed.compactMap(\.text)
        #expect(observedTexts.contains("登录"))
        #expect(observedTexts.contains("Complex harness: 1"))
        #expect(observedTexts.contains("Login"))
        #expect(observedTexts.contains("Café"))

        // wait matches the same nodes: whitespace-trimmed query, substring,
        // case-insensitive, diacritic-insensitive.
        #expect(TKWaitFindTextMatch(in: nodes, query: " 登录 ")?.targetOID == 10)
        #expect(TKWaitFindTextMatch(in: nodes, query: "harness")?.targetOID == 11)
        #expect(TKWaitFindTextMatch(in: nodes, query: "login")?.targetOID == 12)
        #expect(TKWaitFindTextMatch(in: nodes, query: "cafe")?.targetOID == 13)

        // act find matches the same nodes under the same normalization.
        #expect(selectAXNodesByQuery(nodes, query: " 登录 ").first?.targetOID == 10)
        #expect(selectAXNodesByQuery(nodes, query: "harness").first?.targetOID == 11)
        #expect(selectAXNodesByQuery(nodes, query: "login").first?.targetOID == 12)
        #expect(selectAXNodesByQuery(nodes, query: "cafe").first?.targetOID == 13)
    }

    @Test("wait and find share the hidden-node visibility rule while observe stays authoritative")
    func waitFindShareHiddenVisibilityRule() {
        let nodes = iosRuntimeTextFixture()

        // observe still lists the hidden node with hidden metadata (authoritative).
        let observed = observeNodes(fromAX: nodes, source: "runtime-tree", prefix: "ios-runtime")
        #expect(observed.contains { $0.text == "隐藏子节点" && $0.hidden == true })

        // wait excludes the hidden node.
        #expect(TKWaitFindTextMatch(in: nodes, query: "隐藏子节点") == nil)

        // act find excludes the hidden node.
        #expect(selectAXNodesByQuery(nodes, query: "隐藏子节点").isEmpty)
    }

    // MARK: act find not-found contract (forbids success + empty stdout)

    @Test("act find returns a structured not-found failure instead of success with empty output")
    func actFindNoMatchReturnsStructuredNotFoundEnvelope() async throws {
        let server = ActFindContractFakeServer(nodes: [])
        defer { server.stop() }
        let client = TritonKitHTTPClient(
            host: server.host,
            port: server.port,
            target: "triton:ios-simulator:demo",
            session: server.session
        )

        let failure = await actFindFailure(query: "登录", client: client)
        let notFound = try #require(failure)
        #expect(notFound.candidateCount == 0)
        #expect(notFound.query == "登录")
        #expect(notFound.message.contains("登录"))

        let detail = cliErrorDetail(for: notFound, endpoint: "/request", host: server.host, port: server.port)
        #expect(detail.code == "text_not_found")
        #expect(detail.suggestedCommands?.contains("triton act find '登录' --all --json") == true)
    }

    @Test("act find returns matches for a present node and never a zero-match success envelope")
    func actFindReturnsMatchesForPresentNode() async throws {
        let server = ActFindContractFakeServer(nodes: iosRuntimeTextFixture())
        defer { server.stop() }
        let client = TritonKitHTTPClient(
            host: server.host,
            port: server.port,
            target: "triton:ios-simulator:demo",
            session: server.session
        )

        // Whitespace-padded, mixed-case query must resolve the same visible node
        // that observe lists and wait matches.
        let resolution = try await resolveTapTarget(
            " 登录 ",
            client: client,
            width: nil,
            height: nil,
            duration: nil,
            includeCandidates: true
        )
        #expect(resolution.matchCount >= 1)
        #expect(resolution.matchIndex >= 1)
        #expect(resolution.label == "登录")
        #expect(resolution.targetOID == 10)
        let candidates = try #require(resolution.candidates)
        #expect(!candidates.isEmpty)
        #expect(candidates.contains { $0.targetOID == 10 })

        // A success envelope must never carry zero matches: print the full JSON
        // (what `act find --json` emits) and require it to be non-empty.
        let json = try encodeJSON(resolution)
        #expect(!json.isEmpty)
        #expect(resolution.matchCount > 0)
    }

    // MARK: Helpers

    private func actFindFailure(
        query: String,
        client: TritonKitHTTPClient
    ) async -> TKTapTargetResolutionFailure? {
        do {
            _ = try await resolveTapTarget(
                query,
                client: client,
                width: nil,
                height: nil,
                duration: nil,
                includeCandidates: true
            )
            return nil
        } catch let failure as TKTapTargetResolutionFailure {
            return failure
        } catch {
            return nil
        }
    }
}

/// Fake embedded runtime serving `accessibility` / `hierarchy` over a canned
/// URLProtocol session so `act find` resolution never touches the network.
private final class ActFindContractFakeServer {
    let host = "127.0.0.1"
    let port: Int
    let session: URLSession

    private let protocolClass: URLProtocol.Type = ActFindContractURLProtocol.self

    init(nodes: [TKAXNode]) {
        self.port = Int.random(in: 20_000...40_000)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        self.session = URLSession(configuration: configuration)
        ActFindContractURLProtocol.configure(port: port, nodes: nodes)
        URLProtocol.registerClass(protocolClass)
    }

    func stop() {
        URLProtocol.unregisterClass(protocolClass)
        ActFindContractURLProtocol.reset()
    }
}

private final class ActFindContractURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var configuredPort: Int?
    private static var configuredNodes: [TKAXNode] = []

    static func configure(port: Int, nodes: [TKAXNode]) {
        lock.lock()
        defer { lock.unlock() }
        configuredPort = port
        configuredNodes = nodes
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        configuredPort = nil
        configuredNodes = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return lock.withLock {
            url.scheme == "http"
                && url.host == "127.0.0.1"
                && url.port == configuredPort
        }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let response = try Self.response(for: request)
            client?.urlProtocol(
                self,
                didReceive: HTTPURLResponse(
                    url: request.url!,
                    statusCode: response.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": response.contentType]
                )!,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func response(for request: URLRequest) throws -> (statusCode: Int, contentType: String, data: Data) {
        switch (request.httpMethod ?? "GET", request.url?.path) {
        case ("POST", "/request"):
            let body = request.httpBodyStream.map(readBodyStream) ?? request.httpBody ?? Data()
            let command = try JSONDecoder().decode(TKCLICommandRequest.self, from: body)
            switch command.type {
            case "accessibility":
                let nodes = lock.withLock { configuredNodes }
                return (200, "application/json", try JSONEncoder().encode(nodes))
            case "hierarchy":
                let payload: [String: Any] = [
                    "displayItems": [],
                    "appInfo": [
                        "appName": "Demo",
                        "deviceDescription": "iPhone",
                        "osDescription": "iOS 26",
                    ],
                ]
                return (200, "application/json", try JSONSerialization.data(withJSONObject: payload))
            default:
                return (400, "text/plain", Data("unsupported request".utf8))
            }
        default:
            return (404, "text/plain", Data("not found".utf8))
        }
    }

    private static func readBodyStream(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
