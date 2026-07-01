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
        let encoder = JSONEncoder()
        let counter = MessageCounter()
        let webHostTargetCache = WebHostDeviceTargetCache()

        let router = Router(context: BasicWebSocketRequestContext.self)
        let webSocketRouter = Router(context: BasicWebSocketRequestContext.self)

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

        router.get("/") { _, _ -> Response in
            singleDeviceWebPageResponse()
        }

        router.get("/web/device") { _, _ -> Response in
            singleDeviceWebPageResponse()
        }

        router.get("/simulators/:id") { request, _ -> Response in
            let target = request.uri.path
                .split(separator: "/", omittingEmptySubsequences: true)
                .last
                .map(String.init)?
                .removingPercentEncoding
            return singleDeviceWebPageResponse(initialTarget: target)
        }

        router.get("/hierarchy/latest") { request, _ -> Response in
            let connection: TargetConnection
            do {
                connection = try state.resolve(queryTarget(from: request))
            } catch {
                return jsonError(detail: cliErrorDetail(for: error, endpoint: "/hierarchy/latest", host: host, port: port), status: .conflict)
            }
            guard let data = connection.state.latestHierarchy else {
                return jsonError(
                    code: "hierarchy_unavailable",
                    message: "No hierarchy received yet",
                    endpoint: "/hierarchy/latest",
                    hint: "Connect an app that embeds TritonKit, then request `triton observe tree --json` or `triton debug hierarchy --json`",
                    status: .notFound
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        router.get("/status") { _, _ -> Response in
            let cacheStatus = state.cacheStatus()
            return jsonResponse(TKStatusResponse(
                connected: state.isConnected,
                latestHierarchyAvailable: cacheStatus.latestHierarchyAvailable,
                targetCount: state.targetCount,
                activeHierarchyAvailable: cacheStatus.activeHierarchyAvailable,
                hierarchyCacheState: cacheStatus.hierarchyCacheState,
                targetConnectionState: state.isConnected ? "connected" : "disconnected"
            ))
        }

        router.get("/targets") { _, _ -> Response in
            return jsonResponse(TKTargetsResponse(targets: state.summaries()))
        }

        router.get("/web/targets") { _, _ -> Response in
            let runtimeTargets = state.summaries()
            webHostTargetCache.refreshIfNeeded()
            let hostTargets = webHostTargetCache.cachedTargets()
            return jsonResponse(WebDeviceTargetsResponse(targets: webDeviceTargets(runtimeTargets: runtimeTargets, hostTargets: hostTargets)))
        }

        router.get("/web/target-registry") { _, _ -> Response in
            let runtimeTargets = state.summaries()
            webHostTargetCache.refreshIfNeeded()
            let hostTargets = webHostTargetCache.cachedTargets()
            return jsonResponse(makeWebTargetRegistry(runtimeTargets: runtimeTargets, hostTargets: hostTargets))
        }

        router.get("/v1/app-map/inspect") { request, _ -> Response in
            guard let map = queryParameter("map", from: request) else {
                return missingAppMapHTTPParameter("map", endpoint: "/v1/app-map/inspect")
            }
            do {
                return jsonResponse(try inspectTritonAppMap(mapPath: map))
            } catch {
                return jsonError(detail: appMapHTTPErrorDetail(error, endpoint: "/v1/app-map/inspect"), status: .conflict)
            }
        }

        router.get("/v1/app-map/paths") { request, _ -> Response in
            guard let map = queryParameter("map", from: request) else {
                return missingAppMapHTTPParameter("map", endpoint: "/v1/app-map/paths")
            }
            do {
                return jsonResponse(try listTritonAppMapPaths(mapPath: map))
            } catch {
                return jsonError(detail: appMapHTTPErrorDetail(error, endpoint: "/v1/app-map/paths"), status: .conflict)
            }
        }

        router.get("/v1/app-map/screens") { request, _ -> Response in
            guard let map = queryParameter("map", from: request) else {
                return missingAppMapHTTPParameter("map", endpoint: "/v1/app-map/screens")
            }
            do {
                return jsonResponse(try listTritonAppMapScreens(mapPath: map))
            } catch {
                return jsonError(detail: appMapHTTPErrorDetail(error, endpoint: "/v1/app-map/screens"), status: .conflict)
            }
        }

        router.get("/v1/app-map/transitions") { request, _ -> Response in
            guard let map = queryParameter("map", from: request) else {
                return missingAppMapHTTPParameter("map", endpoint: "/v1/app-map/transitions")
            }
            do {
                return jsonResponse(try listTritonAppMapTransitions(mapPath: map))
            } catch {
                return jsonError(detail: appMapHTTPErrorDetail(error, endpoint: "/v1/app-map/transitions"), status: .conflict)
            }
        }

        router.get("/v1/app-map/path") { request, _ -> Response in
            guard let map = queryParameter("map", from: request) else {
                return missingAppMapHTTPParameter("map", endpoint: "/v1/app-map/path")
            }
            guard let path = queryParameter("path", from: request) else {
                return missingAppMapHTTPParameter("path", endpoint: "/v1/app-map/path")
            }
            do {
                return jsonResponse(try showTritonAppMapPath(mapPath: map, pathID: path))
            } catch {
                return jsonError(detail: appMapHTTPErrorDetail(error, endpoint: "/v1/app-map/path"), status: .conflict)
            }
        }

        router.get("/v1/app-map/health") { request, _ -> Response in
            guard let map = queryParameter("map", from: request) else {
                return missingAppMapHTTPParameter("map", endpoint: "/v1/app-map/health")
            }
            do {
                return jsonResponse(try inspectTritonAppMapHealth(mapPath: map))
            } catch {
                return jsonError(detail: appMapHTTPErrorDetail(error, endpoint: "/v1/app-map/health"), status: .conflict)
            }
        }

        router.get("/v1/app-map/suite") { request, _ -> Response in
            guard let map = queryParameter("map", from: request) else {
                return missingAppMapHTTPParameter("map", endpoint: "/v1/app-map/suite")
            }
            let suite = queryParameter("suite", from: request) ?? "smoke"
            do {
                return jsonResponse(try inspectTritonAppMapSuite(mapPath: map, suiteID: suite))
            } catch {
                return jsonError(detail: appMapHTTPErrorDetail(error, endpoint: "/v1/app-map/suite"), status: .conflict)
            }
        }

        router.post("/v1/app-map/suite/run") { request, _ -> Response in
            let bodyData = try await requestBodyData(from: request)
            guard let body = try? JSONDecoder().decode(TKAppMapSuiteRunHTTPRequest.self, from: bodyData),
                  !body.map.isEmpty,
                  !body.evidenceRoot.isEmpty else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported app map suite run payload",
                    endpoint: "/v1/app-map/suite/run",
                    hint: "Send JSON with map and evidenceRoot fields; suite defaults to smoke.",
                    status: .badRequest
                )
            }
            do {
                let response = try await runTritonAppMapSuite(
                    mapPath: body.map,
                    suiteID: body.suite ?? "smoke",
                    evidenceRoot: body.evidenceRoot,
                    target: body.target ?? TKLocalTargetID,
                    host: body.host ?? host,
                    port: body.port ?? port,
                    allowVLM: body.allowVLM ?? false,
                    allowRemoteVLM: body.allowRemoteVLM ?? false,
                    vlmBaseURL: body.vlmBaseURL,
                    vlmModel: body.vlmModel,
                    vlmAPIKeyEnv: body.vlmAPIKeyEnv,
                    executor: TKLiveTestRunPrimitiveExecutor()
                )
                return jsonResponse(response, status: response.ok ? .ok : .conflict)
            } catch {
                return jsonError(detail: appMapHTTPErrorDetail(error, endpoint: "/v1/app-map/suite/run"), status: .conflict)
            }
        }

        router.post("/v1/test-recorder/sessions") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/sessions"
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPSessionCreate(body: bodyData))
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/sessions/:sessionId/events") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/sessions/{sessionId}/events"
            guard let sessionID = testRecorderHTTPSessionID(from: request, terminalComponent: "events") else {
                return jsonError(
                    code: "invalid_session_id",
                    message: "Missing or invalid test recorder session id.",
                    endpoint: endpoint,
                    hint: "Use POST /v1/test-recorder/sessions/{sessionId}/events with the sessionId returned by session create.",
                    status: .badRequest
                )
            }
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPEvent(sessionID: sessionID, body: bodyData))
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/sessions/:sessionId/stop") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/sessions/{sessionId}/stop"
            guard let sessionID = testRecorderHTTPSessionID(from: request, terminalComponent: "stop") else {
                return jsonError(
                    code: "invalid_session_id",
                    message: "Missing or invalid test recorder session id.",
                    endpoint: endpoint,
                    hint: "Use POST /v1/test-recorder/sessions/{sessionId}/stop with the sessionId returned by session create.",
                    status: .badRequest
                )
            }
            do {
                return jsonResponse(try handleTestRecorderHTTPSessionStop(sessionID: sessionID))
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/cases/inspect") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/cases/inspect"
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPInspect(body: bodyData))
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/cases/compile") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/cases/compile"
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPCompile(body: bodyData))
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/cases/proposals") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/cases/proposals"
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPProposals(body: bodyData))
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/cases/match-page") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/cases/match-page"
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPMatchPage(body: bodyData))
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/cases/replay-dry-run") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/cases/replay-dry-run"
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPReplayDryRun(body: bodyData))
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/cases/replay") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/cases/replay"
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPReplay(body: bodyData), status: .ok)
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.post("/v1/test-recorder/cases/matrix") { request, _ -> Response in
            let endpoint = "/v1/test-recorder/cases/matrix"
            let bodyData = try await requestBodyData(from: request)
            do {
                return jsonResponse(try handleTestRecorderHTTPMatrix(body: bodyData), status: .ok)
            } catch {
                return testRecorderHTTPErrorResponse(error, endpoint: endpoint)
            }
        }

        router.get("/web/geometry") { request, _ -> Response in
            if let target = queryTarget(from: request), parseWebHostTargetID(target) != nil {
                do {
                    return jsonResponse(try webHostDeviceGeometry(id: target))
                } catch {
                    return jsonError(
                        code: "host_geometry_failed",
                        message: "\(error)",
                        endpoint: "/web/geometry",
                        hint: "Boot the selected simulator/emulator, then retry the Web preview refresh.",
                        status: .conflict
                    )
                }
            }
            do {
                let payload = try await requestPayload(
                    type: .geometry,
                    state: state,
                    counter: counter,
                    encoder: encoder,
                    target: queryTarget(from: request)
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/web/geometry"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/web/geometry",
                    hint: "Connect an embedded runtime target or select a host emulator target",
                    status: .conflict
                )
            }
        }

        router.get("/geometry") { request, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .geometry,
                    state: state,
                    counter: counter,
                    encoder: encoder,
                    target: queryTarget(from: request)
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

        router.get("/accessibility") { request, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .accessibility,
                    state: state,
                    counter: counter,
                    encoder: encoder,
                    target: queryTarget(from: request)
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
                    counter: counter,
                    encoder: encoder,
                    target: queryTarget(from: request)
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

        router.get("/screenshot") { request, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .screenshot,
                    state: state,
                    counter: counter,
                    encoder: encoder,
                    target: queryTarget(from: request)
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

        router.get("/web/screenshot") { request, _ -> Response in
            let requestedTarget = queryTarget(from: request)
            if let target = requestedTarget, parseWebHostTargetID(target) != nil {
                do {
                    let screenshot = try captureWebHostDeviceScreenshotPayload(id: target)
                    return Response(status: .ok, headers: [.contentType: screenshot.contentType],
                                    body: .init(byteBuffer: ByteBuffer(data: screenshot.data)))
                } catch {
                    return jsonError(
                        code: "host_screenshot_failed",
                        message: "\(error)",
                        endpoint: "/web/screenshot",
                        hint: "Boot the selected simulator/emulator, then retry the Web preview refresh.",
                        status: .conflict
                    )
                }
            }
            do {
                let payload = try await requestPayload(
                    type: .screenshot,
                    state: state,
                    counter: counter,
                    encoder: encoder,
                    target: requestedTarget
                )
                guard let screenshot = try? JSONDecoder().decode(TKScreenshotResponse.self, from: payload),
                      let imageData = try? await screenshotImageData(screenshot, client: TritonKitHTTPClient(host: host, port: port)) else {
                    return jsonError(
                        code: "invalid_payload",
                        message: "Invalid screenshot payload",
                        endpoint: "/web/screenshot",
                        hint: "Retry after the connected runtime responds to screenshot",
                        status: .internalServerError
                    )
                }
                let format = screenshot.format.lowercased()
                let contentType = format == "png" ? "image/png" : "image/jpeg"
                return Response(status: .ok, headers: [.contentType: contentType],
                                body: .init(byteBuffer: ByteBuffer(data: imageData)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/web/screenshot"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/web/screenshot",
                    hint: "Connect an app that embeds TritonKit or select a host emulator target before requesting screenshot",
                    status: .conflict
                )
            }
        }

        router.post("/command") { request, _ -> Response in
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

            let connection: TargetConnection
            do {
                connection = try state.resolve(command.target)
            } catch {
                return jsonError(detail: cliErrorDetail(for: error, endpoint: "/command", host: host, port: port), status: .conflict)
            }

            let id = counter.next()
            log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
            try await connection.outbound.send(TKMessage(id: id, type: type, payload: command.payload), encoder: encoder)
            return jsonResponse(TKCLICommandResponse(id: id, type: type.rawValue))
        }

        router.post("/request") { request, _ -> Response in
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

            let connection: TargetConnection
            do {
                connection = try state.resolve(command.target)
            } catch {
                return jsonError(detail: cliErrorDetail(for: error, endpoint: "/request", host: host, port: port), status: .conflict)
            }

            let id = counter.next()
            log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
            try await connection.outbound.send(TKMessage(id: id, type: type, payload: command.payload), encoder: encoder)
            guard let payload = await connection.state.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: type.rawValue, endpoint: "/request"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: payload)))
        }

        router.post("/input") { request, _ -> Response in
            let connection: TargetConnection
            do {
                connection = try state.resolve(queryTarget(from: request))
            } catch {
                return jsonError(detail: cliErrorDetail(for: error, endpoint: "/input", host: host, port: port), status: .conflict)
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
            try await connection.outbound.send(TKMessage(id: id, type: .input, payload: payload), encoder: encoder)
            guard let responsePayload = await connection.state.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: "input", endpoint: "/input"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: responsePayload)))
        }

        router.post("/web/input") { request, _ -> Response in
            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard let input = try? JSONDecoder().decode(TKInputRequest.self, from: bodyData),
                  let payload = try? JSONEncoder().encode(input) else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported input payload",
                    endpoint: "/web/input",
                    hint: "Send one TKInputRequest JSON object such as {\"type\":\"tap\",\"x\":1,\"y\":1}",
                    status: .badRequest
                )
            }

            let requestedTarget = queryTarget(from: request)
            if let target = requestedTarget, parseWebHostTargetID(target) != nil {
                do {
                    return jsonResponse(try runWebHostDeviceInput(id: target, input: input))
                } catch {
                    return jsonError(
                        code: "host_input_failed",
                        message: "\(error)",
                        endpoint: "/web/input",
                        hint: "Verify the selected host emulator is ready, then retry the input action.",
                        status: .conflict
                    )
                }
            }

            let connection: TargetConnection
            do {
                connection = try state.resolve(requestedTarget)
            } catch {
                return jsonError(detail: cliErrorDetail(for: error, endpoint: "/web/input", host: host, port: port), status: .conflict)
            }

            let id = counter.next()
            log("[tritonkit] -> input [id:\(id)]")
            try await connection.outbound.send(TKMessage(id: id, type: .input, payload: payload), encoder: encoder)
            guard let responsePayload = await connection.state.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: "input", endpoint: "/web/input"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: responsePayload)))
        }

        // ---- WebSocket Control Channel ----

        webSocketRouter.ws("/") { inbound, outbound, _ in
            log("[tritonkit] iOS device connected (ws)")
            let connection = state.connect(outbound)
            let connectionID = connection.connectionID
            connection.state.beginConnection()

            // Test ping first to verify bidirectional communication
            let pingId = counter.next()
            log("[tritonkit] -> ping [id:\(pingId)]")
            try await outbound.send(TKMessage(id: pingId, type: .ping), encoder: encoder)
            let appInfoID = counter.next()
            log("[tritonkit] -> appInfo [id:\(appInfoID)]")
            try await outbound.send(TKMessage(id: appInfoID, type: .appInfo), encoder: encoder)

            // Then request hierarchy
            let id = counter.next()
            log("[tritonkit] -> hierarchy [id:\(id)]")
            try await outbound.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)

            let heartbeat = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if Task.isCancelled { break }
                    try? await outbound.send(TKMessage(id: 0, type: .ping), encoder: encoder)
                }
            }
            defer { heartbeat.cancel() }

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
                        targetState: connection.state
                    )
                }
            } catch {
                log("[tritonkit] Connection error: \(error)")
            }

            log("[tritonkit] iOS device disconnected")
            if state.disconnect(connectionID: connectionID) {
                connection.state.endConnection()
            }
        }

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(
                webSocketRouter: webSocketRouter,
                configuration: .init(maxFrameSize: tritonWebSocketMaxFrameSize, extensions: [])
            ),
            configuration: .init(address: .hostname(host, port: port))
        )

        log("[tritonkit] Control: ws://\(host):\(port)/")
        log("[tritonkit] Data:   http://\(host):\(port)/data")
        log("[tritonkit] Status: http://\(host):\(port)/status")
        log("[tritonkit] Web:    http://\(host):\(port)\(singleDeviceWebRoutePath)")
        log("[tritonkit] Command: POST http://\(host):\(port)/command")
        log("[tritonkit] Commands: h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")
        webHostTargetCache.refreshIfNeeded()
        let bonjourService = publishTritonBonjourService(port: port)
        if bonjourService != nil {
            log("[tritonkit] Bonjour: _tritonkit-server._tcp.local:\(port)")
        }

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

private func publishTritonBonjourService(port: Int) -> NetService? {
    guard port > 0 && port <= Int(Int32.max) else { return nil }
    let service = NetService(domain: "local.", type: "_tritonkit-server._tcp.", name: "TritonKit", port: Int32(port))
    service.publish()
    return service
}

private func queryTarget(from request: Request) -> String? {
    request.uri.queryParameters["target"].map(String.init)
}

private struct TKAppMapSuiteRunHTTPRequest: Decodable {
    let map: String
    let suite: String?
    let evidenceRoot: String
    let target: String?
    let host: String?
    let port: Int?
    let allowVLM: Bool?
    let allowRemoteVLM: Bool?
    let vlmBaseURL: String?
    let vlmModel: String?
    let vlmAPIKeyEnv: String?
}

private func queryParameter(_ name: String, from request: Request) -> String? {
    request.uri.queryParameters[Substring(name)].map(String.init)?.removingPercentEncoding
}

private func requestBodyData(from request: Request) async throws -> Data {
    var bodyData = Data()
    for try await chunk in request.body {
        bodyData.append(Data(buffer: chunk))
    }
    return bodyData
}

private func missingAppMapHTTPParameter(_ name: String, endpoint: String) -> Response {
    jsonError(
        code: "invalid_payload",
        message: "Missing required query parameter: \(name)",
        endpoint: endpoint,
        hint: "Pass \(name)=... in the query string.",
        status: .badRequest
    )
}

private func appMapHTTPErrorDetail(_ error: Error, endpoint: String) -> TKCLIErrorDetail {
    TKCLIErrorDetail(
        code: appMapFailureCode(error),
        message: "\(error)",
        endpoint: endpoint,
        hint: "Run `triton schema --command map --json` to inspect App Map commands"
    )
}

private func testRecorderHTTPSessionID(from request: Request, terminalComponent: String) -> String? {
    let components = request.uri.path
        .split(separator: "/", omittingEmptySubsequences: true)
        .map(String.init)
    guard components.count == 5,
          components[0] == "v1",
          components[1] == "test-recorder",
          components[2] == "sessions",
          components[4] == terminalComponent else {
        return nil
    }
    return components[3].removingPercentEncoding
}

private func testRecorderHTTPErrorResponse(_ error: Error, endpoint: String) -> Response {
    if let failure = error as? TKTestRecorderValidationFailure {
        return jsonResponse(TKTestRecorderValidationFailureResponse(failure), status: testRecorderHTTPStatus(for: failure))
    }
    return jsonError(
        code: "test_recorder_request_failed",
        message: "\(error)",
        endpoint: endpoint,
        hint: "Run triton schema --command testrec --json to inspect Test Recorder HTTP-equivalent contracts.",
        status: .conflict
    )
}

private func testRecorderHTTPStatus(for failure: TKTestRecorderValidationFailure) -> HTTPResponse.Status {
    switch failure.detail.code {
    case "invalid_json", "invalid_payload", "invalid_session_id", "unsupported_event_kind", "dry_run_required":
        .badRequest
    case "session_not_found":
        .notFound
    case "session_not_recording":
        .conflict
    default:
        .conflict
    }
}

// MARK: - Client Commands
