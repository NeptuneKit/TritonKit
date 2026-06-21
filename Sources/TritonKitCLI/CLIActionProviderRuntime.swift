import ArgumentParser
import Foundation

enum TKActionProviderOption: String, ExpressibleByArgument {
    case uiTars = "ui-tars"
    case agentCPMGUI = "agentcpm-gui"
}

struct TKActionProviderParseResponse: Codable, Equatable {
    let ok: Bool
    let schemaVersion: Int
    let kind: String
    let provider: String
    let sourceFormat: String
    let primitive: String
    let action: String
    let coordinateSystem: String?
    let point: TKActionProviderPoint?
    let endPoint: TKActionProviderPoint?
    let text: String?
    let key: String?
    let status: String?
    let commandPreview: [String]

    init(
        provider: String,
        sourceFormat: String,
        primitive: String,
        action: String,
        coordinateSystem: String? = nil,
        point: TKActionProviderPoint? = nil,
        endPoint: TKActionProviderPoint? = nil,
        text: String? = nil,
        key: String? = nil,
        status: String? = nil,
        commandPreview: [String]
    ) {
        self.ok = true
        self.schemaVersion = 1
        self.kind = "triton.action-provider.parse-result"
        self.provider = provider
        self.sourceFormat = sourceFormat
        self.primitive = primitive
        self.action = action
        self.coordinateSystem = coordinateSystem
        self.point = point
        self.endPoint = endPoint
        self.text = text
        self.key = key
        self.status = status
        self.commandPreview = commandPreview
    }
}

struct TKActionProviderPoint: Codable, Equatable {
    let x: Double
    let y: Double
}

struct TKActionProviderParseFailure: Error, Equatable, CustomStringConvertible {
    let code: String
    let message: String

    var description: String { message }
}

func parseActionProviderOutput(provider: TKActionProviderOption, input: String) throws -> TKActionProviderParseResponse {
    switch provider {
    case .uiTars:
        return try parseUITARSAction(input)
    case .agentCPMGUI:
        return try parseAgentCPMGUIAction(input)
    }
}

private func parseUITARSAction(_ input: String) throws -> TKActionProviderParseResponse {
    let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = normalized.lowercased()
    if lower.contains("click(") || lower.contains("tap(") {
        let point = try firstPoint(in: normalized)
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.uiTars.rawValue,
            sourceFormat: "ui-tars-thought-action",
            primitive: "tap",
            action: "click",
            coordinateSystem: "normalized_0_1000",
            point: point,
            commandPreview: ["triton", "tap", "--x", formatProviderNumber(point.x), "--y", formatProviderNumber(point.y), "--json"]
        )
    }
    if lower.contains("swipe(") {
        let points = allPoints(in: normalized)
        guard points.count >= 2 else {
            throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "UI-TARS swipe requires start and end points.")
        }
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.uiTars.rawValue,
            sourceFormat: "ui-tars-thought-action",
            primitive: "swipe",
            action: "swipe",
            coordinateSystem: "normalized_0_1000",
            point: points[0],
            endPoint: points[1],
            commandPreview: [
                "triton", "swipe",
                "--start-x", formatProviderNumber(points[0].x),
                "--start-y", formatProviderNumber(points[0].y),
                "--end-x", formatProviderNumber(points[1].x),
                "--end-y", formatProviderNumber(points[1].y),
                "--json",
            ]
        )
    }
    if lower.contains("type(") {
        let text = try quotedArgument(in: normalized, names: ["content", "text"])
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.uiTars.rawValue,
            sourceFormat: "ui-tars-thought-action",
            primitive: "type",
            action: "type",
            text: text,
            commandPreview: ["triton", "type", text, "--json"]
        )
    }
    if lower.contains("press(") {
        let key = try quotedArgument(in: normalized, names: ["key", "button"])
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.uiTars.rawValue,
            sourceFormat: "ui-tars-thought-action",
            primitive: "press",
            action: "press",
            key: key,
            commandPreview: ["triton", "press", key, "--json"]
        )
    }
    if lower.contains("wait(") {
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.uiTars.rawValue,
            sourceFormat: "ui-tars-thought-action",
            primitive: "wait",
            action: "wait",
            status: "waiting",
            commandPreview: ["triton", "wait", "--idle", "--json"]
        )
    }
    if lower.contains("finished(") || lower.contains("status(") || lower.contains("done") {
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.uiTars.rawValue,
            sourceFormat: "ui-tars-thought-action",
            primitive: "status",
            action: "status",
            status: "done",
            commandPreview: ["triton", "status", "--json"]
        )
    }
    throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "Unsupported UI-TARS action.")
}

private func parseAgentCPMGUIAction(_ input: String) throws -> TKActionProviderParseResponse {
    guard let data = input.data(using: .utf8),
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "AgentCPM-GUI action must be a JSON object.")
    }
    let action = stringValue(object["action"] ?? object["type"] ?? object["action_type"])?.uppercased()
    guard let action else {
        throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "AgentCPM-GUI action is missing action/type.")
    }
    switch action {
    case "POINT", "CLICK", "TAP":
        let point = try pointValue(object["point"] ?? object["coordinate"] ?? object["position"], object: object)
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.agentCPMGUI.rawValue,
            sourceFormat: "agentcpm-gui-json",
            primitive: "tap",
            action: action,
            coordinateSystem: "normalized_0_1000",
            point: point,
            commandPreview: ["triton", "tap", "--x", formatProviderNumber(point.x), "--y", formatProviderNumber(point.y), "--json"]
        )
    case "SWIPE":
        let start = try pointValue(object["start"] ?? object["from"], object: object)
        let end = try pointValue(object["end"] ?? object["to"], object: object)
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.agentCPMGUI.rawValue,
            sourceFormat: "agentcpm-gui-json",
            primitive: "swipe",
            action: action,
            coordinateSystem: "normalized_0_1000",
            point: start,
            endPoint: end,
            commandPreview: [
                "triton", "swipe",
                "--start-x", formatProviderNumber(start.x),
                "--start-y", formatProviderNumber(start.y),
                "--end-x", formatProviderNumber(end.x),
                "--end-y", formatProviderNumber(end.y),
                "--json",
            ]
        )
    case "TYPE":
        guard let text = stringValue(object["text"] ?? object["content"]) else {
            throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "TYPE action requires text/content.")
        }
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.agentCPMGUI.rawValue,
            sourceFormat: "agentcpm-gui-json",
            primitive: "type",
            action: action,
            text: text,
            commandPreview: ["triton", "type", text, "--json"]
        )
    case "PRESS":
        guard let key = stringValue(object["key"] ?? object["button"]) else {
            throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "PRESS action requires key/button.")
        }
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.agentCPMGUI.rawValue,
            sourceFormat: "agentcpm-gui-json",
            primitive: "press",
            action: action,
            key: key,
            commandPreview: ["triton", "press", key, "--json"]
        )
    case "WAIT":
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.agentCPMGUI.rawValue,
            sourceFormat: "agentcpm-gui-json",
            primitive: "wait",
            action: action,
            status: "waiting",
            commandPreview: ["triton", "wait", "--idle", "--json"]
        )
    case "STATUS", "DONE":
        return TKActionProviderParseResponse(
            provider: TKActionProviderOption.agentCPMGUI.rawValue,
            sourceFormat: "agentcpm-gui-json",
            primitive: "status",
            action: action,
            status: stringValue(object["status"]) ?? "done",
            commandPreview: ["triton", "status", "--json"]
        )
    default:
        throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "Unsupported AgentCPM-GUI action: \(action).")
    }
}

private func allPoints(in value: String) -> [TKActionProviderPoint] {
    let pattern = #"'?\(([0-9]+(?:\.[0-9]+)?)\s*,\s*([0-9]+(?:\.[0-9]+)?)\)'?"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return regex.matches(in: value, range: range).compactMap { match in
        guard let xRange = Range(match.range(at: 1), in: value),
              let yRange = Range(match.range(at: 2), in: value),
              let x = Double(value[xRange]),
              let y = Double(value[yRange])
        else { return nil }
        return TKActionProviderPoint(x: x, y: y)
    }
}

private func firstPoint(in value: String) throws -> TKActionProviderPoint {
    guard let point = allPoints(in: value).first else {
        throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "Action point could not be parsed.")
    }
    return point
}

private func quotedArgument(in value: String, names: [String]) throws -> String {
    for name in names {
        let pattern = name + #"\s*=\s*['"]([^'"]+)['"]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        if let match = regex.firstMatch(in: value, range: range),
           let valueRange = Range(match.range(at: 1), in: value) {
            return String(value[valueRange])
        }
    }
    throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "Quoted action argument could not be parsed.")
}

private func pointValue(_ value: Any?, object: [String: Any]) throws -> TKActionProviderPoint {
    if let array = value as? [Any], array.count >= 2,
       let x = actionProviderDoubleValue(array[0]), let y = actionProviderDoubleValue(array[1]) {
        return TKActionProviderPoint(x: x, y: y)
    }
    if let dict = value as? [String: Any],
       let x = actionProviderDoubleValue(dict["x"]), let y = actionProviderDoubleValue(dict["y"]) {
        return TKActionProviderPoint(x: x, y: y)
    }
    if let x = actionProviderDoubleValue(object["x"]), let y = actionProviderDoubleValue(object["y"]) {
        return TKActionProviderPoint(x: x, y: y)
    }
    throw TKActionProviderParseFailure(code: "action_provider_parse_failed", message: "Action point requires x/y or a two-element array.")
}

private func stringValue(_ value: Any?) -> String? {
    if let string = value as? String, !string.isEmpty { return string }
    return nil
}

private func actionProviderDoubleValue(_ value: Any?) -> Double? {
    if let double = value as? Double { return double }
    if let int = value as? Int { return Double(int) }
    if let string = value as? String { return Double(string) }
    return nil
}

private func formatProviderNumber(_ value: Double) -> String {
    if value.rounded(.towardZero) == value {
        return String(Int(value))
    }
    return String(value)
}
