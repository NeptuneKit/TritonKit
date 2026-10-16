import Foundation
import Network

final class IOSRunnerServer {
    private let config: RunnerConfiguration
    private let perform: (String, [String: Any]) throws -> [String: Any]
    private let now: () -> TimeInterval
    private let scheduleUI: (@escaping () -> Void) -> Void
    private final class Client {
        let connection: NWConnection
        let deadline: TimeInterval
        var channel: RunnerSecureChannel?
        init(_ connection: NWConnection, deadline: TimeInterval) {
            self.connection = connection; self.deadline = deadline
        }
    }
    private let listener: NWListener
    private let queue = DispatchQueue(label: "dev.tritonkit.iosrunner.http")
    private let ledger = RequestLedger()
    private let lock = NSLock()
    private var stopRequested = false
    private var listenerError: String?
    var listenerFailure: String? { lock.lock(); defer { lock.unlock() }; return listenerError }
    private var clients: [ObjectIdentifier: Client] = [:]
    private var uiPending: [(RunnerHTTPRequest, [String: Any], Client)] = []
    private var uiBusy = false
    private let started: TimeInterval
    var stopped: Bool { lock.lock(); defer { lock.unlock() }; return stopRequested }
    init(config: RunnerConfiguration, port: NWEndpoint.Port? = nil, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }, scheduleUI: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }, perform: @escaping (String, [String: Any]) throws -> [String: Any]) throws {
        self.config = config; self.perform = perform; self.now = now; self.scheduleUI = scheduleUI; started = now()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port ?? NWEndpoint.Port(rawValue: config.port)!)
        listener = try NWListener(using: parameters)
    }
    func start(ready: ((UInt16) -> Void)? = nil) {
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state, let port = self?.listener.port { ready?(port.rawValue) }
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
            for client in self.clients.values { client.connection.cancel() }
            self.clients.removeAll()
        }
    }
    private func accept(_ connection: NWConnection) {
        guard !stopped, clients.count < 8 else { connection.cancel(); return }
        let id = ObjectIdentifier(connection)
        let client = Client(connection, deadline: now() + 20)
        clients[id] = client
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { self?.clients.removeValue(forKey: id) }
            if case .failed = state { self?.clients.removeValue(forKey: id) }
        }
        connection.start(queue: queue)
        // One deadline covers handshake, request, UI queue and response. An
        // already started XCTest action cannot be cancelled or replayed safely.
        queue.asyncAfter(deadline: .now() + 20) { connection.cancel() }
        receiveExactly(RunnerSecureChannel.helloSize, client: client) { [weak self] hello in
            guard let self else { return }
            do {
                let channel = try RunnerSecureChannel.server(token: self.config.token, session: self.config.session, hello: hello)
                client.channel = channel
                connection.send(content: channel.proof, completion: .contentProcessed { error in
                    guard error == nil else { connection.cancel(); return }
                    self.receiveFrame(client)
                })
            } catch { connection.cancel() }
        }
    }
    private func receiveExactly(_ count: Int, client: Client, accumulated: Data = Data(), completion: @escaping (Data) -> Void) {
        guard now() < client.deadline else { client.connection.cancel(); return }
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: min(8192, count - accumulated.count)) { [weak self] data, _, complete, error in
            guard let self else { return }
            var bytes = accumulated
            if let data { bytes.append(data) }
            guard error == nil, bytes.count <= count else { client.connection.cancel(); return }
            if bytes.count == count { completion(bytes); return }
            guard !complete else { client.connection.cancel(); return }
            self.receiveExactly(count, client: client, accumulated: bytes, completion: completion)
        }
    }
    private func receiveFrame(_ client: Client) {
        receiveExactly(4, client: client) { [weak self] header in
            guard let self else { return }
            do {
                let length = try RunnerSecureChannel.frameLength(header, maximumPlaintext: RunnerSecureChannel.maximumRequestBytes)
                self.receiveExactly(length, client: client) { [weak self] bytes in
                    guard let self, let channel = client.channel else { client.connection.cancel(); return }
                    let plaintext: Data
                    do { plaintext = try channel.openRequest(header + bytes) }
                    catch { client.connection.cancel(); return }
                    // Only authenticated plaintext reaches the HTTP parser and
                    // router. Authentication failures never get a plaintext error.
                    do {
                        guard let request = try BoundedHTTPParser().append(plaintext) else {
                            throw ProtocolFailure("incomplete_request", "Complete HTTP request required")
                        }
                        self.handle(request, client: client)
                    } catch {
                        self.send(self.failure(error, requestID: ""), status: (error as? ProtocolFailure)?.status ?? 400, client: client)
                    }
                }
            } catch { client.connection.cancel() }
        }
    }
    private func validateLifetime(_ client: Client) throws {
        guard !stopped else { throw ProtocolFailure("session_stopping", "Runner is stopping", status: 409) }
        let current = now()
        guard current >= started, current - started < config.ttl else {
            throw ProtocolFailure("session_expired", "Runner session expired", status: 409)
        }
        guard current < client.deadline else {
            throw ProtocolFailure("request_expired", "Request deadline expired", status: 408)
        }
    }
    private func envelope(ok: Bool, requestID: String, result: Any = NSNull(), error: Any = NSNull()) -> [String: Any] {
        ["ok": ok, "sessionID": config.session, "requestID": requestID, "result": result, "error": error]
    }
    private func failure(_ error: Error, requestID: String) -> [String: Any] {
        let value = error as? ProtocolFailure ?? ProtocolFailure("request_failed", "Request could not be completed")
        return envelope(ok: false, requestID: requestID, error: ["code": value.code, "message": value.message])
    }
    private func handle(_ request: RunnerHTTPRequest, client: Client) {
        do {
            try validateLifetime(client)
            try request.validate(session: config.session)
            let body = try request.jsonBody()
            if request.path == "/crossApp" { _ = try CrossAppRequest(body: body, allowedBundles: config.allowedBundles) }
            if request.path == "/environment" { _ = try RunnerEnvironmentRequest(body: body) }
            if request.path == "/health" {
                send(envelope(ok: true, requestID: request.requestID, result: ["listenerReady": true, "networkReady": true, "automationReady": false, "uptimeSeconds": now() - started, "ttlSeconds": config.ttl, "backend": "public-xctest-runner"]), client: client)
                return
            }
            if request.path == "/receipt" {
                guard let actionID = body["actionRequestID"] as? String, !actionID.isEmpty else { throw ProtocolFailure("invalid_receipt", "actionRequestID required") }
                send(envelope(ok: true, requestID: request.requestID, result: ["found": ledger.receipt(actionID) != nil, "receipt": ledger.receipt(actionID) ?? [:]]), client: client)
                return
            }
            if request.path == "/stop" {
                send(envelope(ok: true, requestID: request.requestID, result: ["stopping": true]), client: client, after: { [weak self] in self?.stop() })
                return
            }
            let isAction = ["/probe", "/snapshot", "/screenshot", "/tap", "/home", "/activateFixture", "/crossApp", "/environment"].contains(request.path)
            if isAction, let existing = try ledger.claim(request) {
                let value = existing["status"] as? String == "pending" ? envelope(ok: false, requestID: request.requestID, result: ["status": "pending"], error: ["code": "request_pending", "message": "Original action has not completed"]) : existing
                send(value, status: existing["status"] as? String == "pending" ? 202 : 200, client: client)
                return
            }
            guard uiPending.count < 8 else {
                let value = failure(ProtocolFailure("ui_queue_budget", "UI queue budget exhausted", status: 429), requestID: request.requestID)
                if isAction { ledger.complete(requestID: request.requestID, envelope: value) }
                send(value, status: 429, client: client)
                return
            }
            uiPending.append((request, body, client))
            drainUI()
        } catch {
            send(failure(error, requestID: request.requestID), status: (error as? ProtocolFailure)?.status ?? 400, client: client)
        }
    }
    private func drainUI() {
        guard !uiBusy, !uiPending.isEmpty else { return }
        uiBusy = true
        let (request, body, client) = uiPending.removeFirst()
        scheduleUI { [weak self] in
                guard let self else { return }
                let result: [String: Any]
                let status: Int
                do {
                    try self.validateLifetime(client)
                    result = self.envelope(ok: true, requestID: request.requestID, result: try self.perform(request.path, body))
                    status = 200
                } catch {
                    result = self.failure(error, requestID: request.requestID)
                    status = (error as? ProtocolFailure)?.status ?? 500
                }
                if ["/probe", "/snapshot", "/screenshot", "/tap", "/home", "/activateFixture", "/crossApp", "/environment"].contains(request.path) {
                    self.ledger.complete(requestID: request.requestID, envelope: result)
                }
                let delivered = self.ledger.receipt(request.requestID) ?? result
                self.queue.async {
                    self.send(delivered, status: delivered["ok"] as? Bool == false && status == 200 ? 413 : status, client: client)
                    self.uiBusy = false
                    self.drainUI()
                }
            }
    }
    private func send(_ body: [String: Any], status: Int = 200, client: Client, after: (() -> Void)? = nil) {
        guard let channel = client.channel,
              let json = try? JSONSerialization.data(withJSONObject: body), json.count <= 12 * 1024 * 1024 else {
            client.connection.cancel(); return
        }
        let requestID = body["requestID"] as? String ?? ""
        let header = "HTTP/1.1 \(status) Runner\r\nContent-Type: application/json\r\nContent-Length: \(json.count)\r\nConnection: close\r\nX-Request-ID: \(requestID)\r\n\r\n"
        guard let frame = try? channel.sealResponse(Data(header.utf8) + json) else { client.connection.cancel(); return }
        client.connection.send(content: frame, completion: .contentProcessed { _ in client.connection.cancel(); after?() })
    }
}
