import Foundation

struct TKWorkspaceHTTPRunRequest: Codable, Equatable {
    let runsDir: String?
    let runID: String?
    let target: String?
    let app: String
    let goal: String
    let actionPolicy: String?

    enum CodingKeys: String, CodingKey {
        case runsDir
        case runID = "runId"
        case target
        case app
        case goal
        case actionPolicy
    }
}

struct TKWorkspaceHTTPExportFlowRequest: Codable, Equatable {
    let runsDir: String?
    let output: String
}

func handleWorkspaceHTTPRun(body: Data) throws -> TKWorkspaceRunResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPRunRequest.self, from: body)
    return try runWorkspaceRun(TKWorkspaceRunRequest(
        runsDirectory: request.runsDir ?? ".triton/runs",
        runID: request.runID,
        target: request.target ?? "current",
        app: request.app,
        goal: request.goal,
        actionPolicy: request.actionPolicy ?? "explore"
    ))
}

func handleWorkspaceHTTPInspect(runID: String, runsDir: String?) throws -> TKWorkspaceInspectResponse {
    try inspectWorkspaceRun(runID: runID, runsDirectory: runsDir ?? ".triton/runs")
}

func handleWorkspaceHTTPStop(runID: String, runsDir: String?) throws -> TKWorkspaceInspectResponse {
    try stopWorkspaceRun(runID: runID, runsDirectory: runsDir ?? ".triton/runs")
}

func handleWorkspaceHTTPExportFlow(runID: String, body: Data) throws -> TKWorkspaceExportFlowResponse {
    let request = try decodeWorkspaceHTTP(TKWorkspaceHTTPExportFlowRequest.self, from: body)
    return try exportWorkspaceFlow(
        runID: runID,
        runsDirectory: request.runsDir ?? ".triton/runs",
        output: request.output
    )
}

private func decodeWorkspaceHTTP<T: Decodable>(_ type: T.Type, from body: Data) throws -> T {
    do {
        return try JSONDecoder().decode(type, from: body)
    } catch {
        throw RuntimeError("Invalid workspace HTTP payload: \(error)")
    }
}
