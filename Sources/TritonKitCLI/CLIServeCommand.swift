import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Start server")

    @Option(name: .shortAndLong, help: "Port to listen on") var port: Int = 19421
    @Option(name: .shortAndLong, help: "Host to bind to") var host: String = "0.0.0.0"

    func run() async throws {
        let store = DataStore()
        let state = ConnectionState()
        let targetState = TargetState()
        let encoder = JSONEncoder()
        let counter = MessageCounter()

        let router = Router(context: BasicWebSocketRequestContext.self)

        // ---- HTTP Data Endpoints ----

        router.post("/data") { request, _ -> Response in
            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }
            guard !bodyData.isEmpty else {
                return Response(status: .badRequest, body: .init(byteBuffer: ByteBuffer(string: "Empty body")))
            }
            let id = store.put(bodyData)
            let resp = try JSONEncoder().encode(["id": id])
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: resp)))
        }

        router.get("/data/:id") { request, _ -> Response in
            guard let idStr = request.uri.path.split(separator: "/").last,
                  let id = UUID(uuidString: String(idStr)),
                  let data = store.get(id) else {
                return Response(status: .notFound)
            }
            return Response(status: .ok, headers: [.contentType: "application/octet-stream"],
                            body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        router.get("/health") { _, _ -> HTTPResponse.Status in .ok }

        router.get("/hierarchy/latest") { _, _ -> Response in
            guard let data = targetState.latestHierarchy else {
                return jsonError(
                    code: "hierarchy_unavailable",
                    message: "No hierarchy received yet",
                    endpoint: "/hierarchy/latest",
                    hint: "Connect an app that embeds TritonKit, then request `triton hierarchy --json`",
                    status: .notFound
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        router.get("/status") { _, _ -> Response in
            let cacheStatus = targetState.cacheStatus(connected: state.isConnected)
            return jsonResponse(TKStatusResponse(
                connected: state.isConnected,
                latestHierarchyAvailable: targetState.latestHierarchy != nil,
                targetCount: state.isConnected ? 1 : 0,
                activeHierarchyAvailable: cacheStatus.activeHierarchyAvailable,
                hierarchyCacheState: cacheStatus.hierarchyCacheState,
                targetConnectionState: state.isConnected ? "connected" : "disconnected"
            ))
        }

        router.get("/targets") { _, _ -> Response in
            let targets = targetState.summary(connected: state.isConnected).map { [$0] } ?? []
            return jsonResponse(TKTargetsResponse(targets: targets))
        }

        router.get("/geometry") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .geometry,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/geometry"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/geometry",
                    hint: "Connect an app that embeds TritonKit before requesting geometry",
                    status: .conflict
                )
            }
        }

        router.get("/accessibility") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .accessibility,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/accessibility"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/accessibility",
                    hint: "Connect an app that embeds TritonKit before requesting accessibility",
                    status: .conflict
                )
            }
        }

        router.post("/hit") { request, _ -> Response in
            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }
            guard let hit = try? JSONDecoder().decode(TKHitTestRequest.self, from: bodyData),
                  let hitPayload = try? JSONEncoder().encode(hit) else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported hit payload",
                    endpoint: "/hit",
                    hint: "Send JSON with numeric x and y fields",
                    status: .badRequest
                )
            }
            do {
                let payload = try await requestPayload(
                    type: .hitTest,
                    payload: hitPayload,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/hit"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/hit",
                    hint: "Connect an app that embeds TritonKit before hit testing",
                    status: .conflict
                )
            }
        }

        router.get("/screenshot") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .screenshot,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                guard let screenshot = try? JSONDecoder().decode(TKScreenshotResponse.self, from: payload),
                      let imageData = try? await screenshotImageData(screenshot, client: TritonKitHTTPClient(host: host, port: port)) else {
                    return jsonError(
                        code: "invalid_payload",
                        message: "Invalid screenshot payload",
                        endpoint: "/screenshot",
                        hint: "Retry after the connected runtime responds to screenshot",
                        status: .internalServerError
                    )
                }
                return Response(status: .ok, headers: [.contentType: "image/png"],
                                body: .init(byteBuffer: ByteBuffer(data: imageData)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/screenshot"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/screenshot",
                    hint: "Connect an app that embeds TritonKit before requesting screenshot",
                    status: .conflict
                )
            }
        }

        router.post("/command") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/command",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard
                let command = try? JSONDecoder().decode(TKCLICommandRequest.self, from: bodyData),
                let type = command.requestType
            else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported command",
                    endpoint: "/command",
                    hint: "Send JSON with a supported type such as ping, appInfo, or hierarchy",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: type, payload: command.payload), encoder: encoder)
            return jsonResponse(TKCLICommandResponse(id: id, type: type.rawValue))
        }

        router.post("/request") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/request",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard
                let command = try? JSONDecoder().decode(TKCLICommandRequest.self, from: bodyData),
                let type = command.requestType
            else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported command",
                    endpoint: "/request",
                    hint: "Send JSON with a supported type and optional payload",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: type, payload: command.payload), encoder: encoder)
            guard let payload = await targetState.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: type.rawValue, endpoint: "/request"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: payload)))
        }

        router.post("/input") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/input",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard let input = try? JSONDecoder().decode(TKInputRequest.self, from: bodyData),
                  let payload = try? JSONEncoder().encode(input) else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported input payload",
                    endpoint: "/input",
                    hint: "Send one TKInputRequest JSON object such as {\"type\":\"tap\",\"x\":1,\"y\":1}",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> input [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: .input, payload: payload), encoder: encoder)
            guard let responsePayload = await targetState.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: "input", endpoint: "/input"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: responsePayload)))
        }

        // ---- WebSocket Control Channel ----

        router.ws("/") { inbound, outbound, _ in
            log("[tritonkit] iOS device connected (ws)")
            let connectionID = state.connect(outbound)
            targetState.beginConnection()

            // Test ping first to verify bidirectional communication
            let pingId = counter.next()
            log("[tritonkit] -> ping [id:\(pingId)]")
            try await outbound.send(TKMessage(id: pingId, type: .ping), encoder: encoder)

            // Then request hierarchy
            let id = counter.next()
            log("[tritonkit] -> hierarchy [id:\(id)]")
            try await outbound.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)

            do {
                for try await frame in inbound {
                    let data: Data
                    switch frame.opcode {
                    case .binary: data = Data(frame.data.readableBytesView)
                    case .text: data = Data(String(buffer: frame.data).utf8)
                    default: continue
                    }
                    handleResponse(
                        data: data,
                        store: store,
                        targetState: targetState
                    )
                }
            } catch {
                log("[tritonkit] Connection error: \(error)")
            }

            log("[tritonkit] iOS device disconnected")
            if state.disconnect(connectionID: connectionID) {
                targetState.endConnection()
            }
        }

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(
                webSocketRouter: router,
                configuration: .init(maxFrameSize: tritonWebSocketMaxFrameSize, extensions: [])
            ),
            configuration: .init(address: .hostname(host, port: port))
        )

        log("[tritonkit] Control: ws://\(host):\(port)/")
        log("[tritonkit] Data:   http://\(host):\(port)/data")
        log("[tritonkit] Status: http://\(host):\(port)/status")
        log("[tritonkit] Command: POST http://\(host):\(port)/command")
        log("[tritonkit] Commands: h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")

        // Stdin
        Task {
            while let line = readLine() {
                switch line.trimmingCharacters(in: .whitespaces).lowercased() {
                case "q", "quit", "exit": log("[tritonkit] Shut down."); Darwin.exit(0)
                case "h", "hierarchy":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> hierarchy [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "a", "appinfo":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> appInfo [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .appInfo), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "p", "ping":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> ping [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .ping), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "help", "?": log("[tritonkit] h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")
                case "": break
                default: log("[tritonkit] Unknown: \(line)")
                }
            }
        }

        signal(SIGINT, SIG_IGN)
        let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sig.setEventHandler { log("\n[tritonkit] Interrupted."); Darwin.exit(0) }
        sig.resume()

        do { try await app.run() } catch { log("[tritonkit] Error: \(error)"); throw error }
    }
}

// MARK: - Client Commands
