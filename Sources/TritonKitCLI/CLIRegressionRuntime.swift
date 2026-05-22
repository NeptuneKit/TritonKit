import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

func waitForHierarchy(client: TritonKitHTTPClient) async throws -> Data {
    var lastError: Error?
    for _ in 0..<10 {
        do {
            return try await client.getData("/hierarchy/latest")
        } catch {
            lastError = error
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }
    throw lastError ?? RuntimeError("No hierarchy snapshot available")
}

func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}

func encodeCompactJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}

func prettyJSON(_ data: Data) throws -> String {
    let json = try JSONSerialization.jsonObject(with: data)
    let pretty = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    return String(data: pretty, encoding: .utf8) ?? "{}"
}

func encodeJSONObject(_ value: Any) throws -> String {
    guard JSONSerialization.isValidJSONObject(value) else {
        throw RuntimeError("Value is not a valid JSON object")
    }
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    return String(data: data, encoding: .utf8) ?? "{}"
}

func writeOrPrint(_ text: String, output: String?) throws {
    if let output {
        try text.data(using: .utf8)?.write(to: URL(fileURLWithPath: output), options: .atomic)
    } else {
        print(text)
    }
}

func requestPayload(
    type: TKRequestType,
    payload: Data? = nil,
    state: ConnectionState,
    targetState: TargetState,
    counter: MessageCounter,
    encoder: JSONEncoder
) async throws -> Data {
    guard let ws = state.outbound else {
        throw RuntimeError("No iOS device connected")
    }
    let id = counter.next()
    log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
    try await ws.send(TKMessage(id: id, type: type, payload: payload), encoder: encoder)
    guard let responsePayload = await targetState.waitForResponse(id: id) else {
        throw RuntimeRequestTimeoutError(requestType: type.rawValue)
    }
    return responsePayload
}

func executeInputRequest(_ request: TKInputRequest, client: TritonKitHTTPClient) async throws -> TKInputResult {
    let payload = try JSONEncoder().encode(request)
    let data = try await client.request(type: "input", payload: payload)
    return try JSONDecoder().decode(TKInputResult.self, from: data)
}

struct WaitRequest {
    let condition: TKWaitCondition
    let query: String?
    let predicate: String?
    let role: String?
    let timeout: Double
    let interval: Double
}

func performWait(_ request: WaitRequest, client: TritonKitHTTPClient) async throws -> TKWaitResult {
    let start = Date()
    let deadline = start.addingTimeInterval(request.timeout)
    var pollCount = 0
    var lastObservation = TKWaitObservation()
    var stableHierarchyHash: String?
    var hierarchyChangeBaseline: String?

    if request.condition == .hierarchyChange {
        hierarchyChangeBaseline = try await latestHierarchyHash(client: client)
    }

    while true {
        pollCount += 1
        let observation = try await waitObservation(for: request.condition, client: client)
        lastObservation = observation

        let evaluation = try evaluateWait(request, observation: observation, stableHierarchyHash: stableHierarchyHash, hierarchyChangeBaseline: hierarchyChangeBaseline)
        if evaluation.matched {
            return waitResult(
                request: request,
                matched: true,
                timedOut: false,
                elapsedMs: elapsedMilliseconds(since: start),
                pollCount: pollCount,
                observation: observation,
                match: evaluation.match
            )
        }

        if request.condition == .idle, let hierarchyHash = observation.hierarchyHash {
            stableHierarchyHash = hierarchyHash
        }
        if request.condition == .hierarchyChange, hierarchyChangeBaseline == nil {
            hierarchyChangeBaseline = observation.hierarchyHash
        }

        if Date() >= deadline {
            return waitResult(
                request: request,
                matched: false,
                timedOut: true,
                elapsedMs: elapsedMilliseconds(since: start),
                pollCount: pollCount,
                observation: lastObservation,
                match: nil
            )
        }

        let remaining = deadline.timeIntervalSinceNow
        let sleepSeconds = max(0.01, min(request.interval, remaining))
        try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
    }
}

private func waitObservation(for condition: TKWaitCondition, client: TritonKitHTTPClient) async throws -> TKWaitObservation {
    let status: TKStatusResponse = try await client.getJSON("/status")
    switch condition {
    case .text, .gone, .predicate, .exists:
        let accessibilityData = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
        return TKWaitObservation(
            nodes: nodes,
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState
        )
    case .idle:
        let accessibilityData = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
        return TKWaitObservation(
            nodes: nodes,
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState,
            hierarchyHash: stableAXSignatureHash(nodes)
        )
    case .hierarchyChange:
        let hierarchyData = try await client.request(type: "hierarchy")
        return TKWaitObservation(
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState,
            hierarchyHash: stableDataHash(hierarchyData)
        )
    }
}

private func evaluateWait(
    _ request: WaitRequest,
    observation: TKWaitObservation,
    stableHierarchyHash: String?,
    hierarchyChangeBaseline: String?
) throws -> (matched: Bool, match: TKWaitMatch?) {
    switch request.condition {
    case .text, .exists:
        guard let query = request.query else { return (false, nil) }
        let match = TKWaitFindTextMatch(in: observation.nodes, query: query, role: request.role)
        return (match != nil, match)
    case .gone:
        guard let query = request.query else { return (false, nil) }
        let match = TKWaitFindTextMatch(in: observation.nodes, query: query, role: request.role)
        return (match == nil, nil)
    case .predicate:
        guard let predicate = request.predicate else { return (false, nil) }
        return (try TKWaitEvaluatePredicate(predicate, nodes: observation.nodes), nil)
    case .idle:
        guard observation.targetConnectionState == "connected",
              observation.hierarchyCacheState == "active",
              let hierarchyHash = observation.hierarchyHash,
              let stableHierarchyHash else {
            return (false, nil)
        }
        return (hierarchyHash == stableHierarchyHash, nil)
    case .hierarchyChange:
        guard let hierarchyHash = observation.hierarchyHash,
              let hierarchyChangeBaseline else {
            return (false, nil)
        }
        return (hierarchyHash != hierarchyChangeBaseline, nil)
    }
}

private func waitResult(
    request: WaitRequest,
    matched: Bool,
    timedOut: Bool,
    elapsedMs: Int,
    pollCount: Int,
    observation: TKWaitObservation,
    match: TKWaitMatch?
) -> TKWaitResult {
    TKWaitResult(
        ok: matched && !timedOut,
        matched: matched,
        condition: request.condition.rawValue,
        query: request.query,
        predicate: request.predicate,
        role: request.role,
        timedOut: timedOut,
        elapsedMs: elapsedMs,
        pollCount: pollCount,
        timeoutSeconds: request.timeout,
        intervalSeconds: request.interval,
        targetConnectionState: observation.targetConnectionState,
        hierarchyCacheState: observation.hierarchyCacheState,
        lastObservedNodeCount: observation.nodes.isEmpty ? nil : TKFlattenAXNodes(observation.nodes).count,
        lastObservedTextSample: TKWaitTextSample(from: observation.nodes),
        lastObservedHierarchyHash: observation.hierarchyHash,
        match: match
    )
}

private func latestHierarchyHash(client: TritonKitHTTPClient) async throws -> String? {
    do {
        let data = try await client.getData("/hierarchy/latest")
        return stableDataHash(data)
    } catch {
        return nil
    }
}

private func stableDataHash(_ data: Data) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in data {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return String(format: "%016llx", hash)
}

private func stableAXSignatureHash(_ nodes: [TKAXNode]) -> String {
    let signature = TKWaitVisibleTexts(from: nodes)
        .map { match in
            [
                match.source,
                match.role ?? "",
                match.text,
                match.frame.map(formatRect) ?? "",
            ].joined(separator: ":")
        }
        .joined(separator: "\n")
    return stableDataHash(Data(signature.utf8))
}

func elapsedMilliseconds(since start: Date) -> Int {
    max(0, Int(Date().timeIntervalSince(start) * 1000))
}

func printWaitResult(_ result: TKWaitResult, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeCompactJSON(result))
    case .text:
        print("ok: \(result.ok)")
        print("matched: \(result.matched)")
        print("condition: \(result.condition)")
        if let query = result.query {
            print("query: \(query)")
        }
        if let predicate = result.predicate {
            print("predicate: \(predicate)")
        }
        if let role = result.role {
            print("role: \(role)")
        }
        print("timedOut: \(result.timedOut)")
        print("elapsedMs: \(result.elapsedMs)")
        print("pollCount: \(result.pollCount)")
        if let targetConnectionState = result.targetConnectionState {
            print("targetConnectionState: \(targetConnectionState)")
        }
        if let hierarchyCacheState = result.hierarchyCacheState {
            print("hierarchyCacheState: \(hierarchyCacheState)")
        }
        if let match = result.match {
            print("match: \(match.text)")
            if let role = match.role { print("matchRole: \(role)") }
            if let frame = match.frame { print("matchFrame: \(formatRect(frame))") }
            if let targetOID = match.targetOID { print("matchTargetOID: \(targetOID)") }
        }
    }
}

func screenshotImageData(_ screenshot: TKScreenshotResponse, client: TritonKitHTTPClient) async throws -> Data {
    if let dataRef = screenshot.dataRef, !dataRef.isEmpty {
        return try await client.getData("/data/\(dataRef)")
    }
    guard let data = Data(base64Encoded: screenshot.dataBase64) else {
        throw RuntimeError("Invalid screenshot image data")
    }
    return data
}

func buildExportArchive(
    target: TKTargetSummary,
    hierarchyData: Data,
    client: TritonKitHTTPClient
) async throws -> TKExportArchive {
    let hierarchyObject = try JSONSerialization.jsonObject(with: hierarchyData)
    let hierarchy = try TKJSONValue.fromJSONObject(hierarchyObject)
    let geometryData = try await client.request(type: "geometry")
    let geometry = try JSONDecoder().decode(TKGeometryResponse.self, from: geometryData)
    let accessibilityData = try await client.request(type: "accessibility")
    let accessibility = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
    let screenshotData = try await client.request(type: "screenshot")
    let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: screenshotData)
    let imageData = try await screenshotImageData(screenshot, client: client)
    let embeddedScreenshot = TKScreenshotResponse(
        format: screenshot.format,
        width: screenshot.width,
        height: screenshot.height,
        scale: screenshot.scale,
        dataBase64: imageData.base64EncodedString()
    )

    return TKExportArchive(
        exportedAt: ISO8601DateFormatter().string(from: Date()),
        target: target,
        hierarchy: hierarchy,
        geometry: geometry,
        accessibility: accessibility,
        screenshot: embeddedScreenshot
    )
}
