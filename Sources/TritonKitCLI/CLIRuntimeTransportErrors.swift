import ArgumentParser
import Darwin
import Foundation
import TritonKit
import TritonKitShared

struct RuntimeError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

struct CLIHTTPError: Error, CustomStringConvertible {
    let statusCode: Int
    let data: Data
    let response: TKCLIErrorResponse?

    init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
        self.response = try? JSONDecoder().decode(TKCLIErrorResponse.self, from: data)
    }

    var description: String {
        if let response {
            return "HTTP \(statusCode) \(response.error.code): \(response.error.message)"
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return "HTTP \(statusCode) \(body)"
    }
}

struct RuntimeRequestTimeoutError: Error, CustomStringConvertible {
    let requestType: String

    var description: String {
        "Timed out waiting for \(requestType) response"
    }
}

func printCLIError(_ error: Error, endpoint: String, host: String, port: Int, surface: String? = nil) throws {
    print(try encodeJSON(cliErrorResponse(for: error, endpoint: endpoint, host: host, port: port, surface: surface)))
}

func printCLIErrorText(_ error: Error, endpoint: String, host: String, port: Int, language: CLILanguage = effectiveLanguage(nil)) {
    let detail = cliErrorDetail(for: error, endpoint: endpoint, host: host, port: port)
    switch language {
    case .en:
        fputs("\(detail.code): \(detail.message)\n", stderr)
    case .zh:
        fputs("\(detail.code): \(localizedErrorMessage(detail, language: language))\n", stderr)
    }
    if let endpoint = detail.endpoint {
        fputs("\(language == .zh ? "端点" : "endpoint"): \(endpoint)\n", stderr)
    }
    if let hint = detail.hint {
        fputs("\(language == .zh ? "提示" : "hint"): \(localizedHint(detail, fallback: hint, language: language))\n", stderr)
    }
    if let nextAction = detail.nextAction {
        let command = (["triton", nextAction.command] + nextAction.args).joined(separator: " ")
        fputs("\(language == .zh ? "下一步" : "next"): \(command)\n", stderr)
    }
    if let nearestCandidates = detail.nearestCandidates, !nearestCandidates.isEmpty {
        fputs("\(language == .zh ? "邻近候选" : "nearest"): \(nearestCandidates.joined(separator: " | "))\n", stderr)
    }
    if let suggestedCommands = detail.suggestedCommands, !suggestedCommands.isEmpty {
        fputs("\(language == .zh ? "建议命令" : "suggested"): \(suggestedCommands.joined(separator: " | "))\n", stderr)
    }
    if let candidateCount = detail.candidateCount {
        fputs("\(language == .zh ? "候选数" : "candidateCount"): \(candidateCount)\n", stderr)
    }
}

func failCommand(
    _ error: Error,
    outputFormat: ClientOutputFormat,
    endpoint: String,
    host: String,
    port: Int
) throws -> Never {
    switch outputFormat {
    case .json:
        print(try encodeJSON(cliErrorResponse(for: error, endpoint: endpoint, host: host, port: port)))
    case .text:
        printCLIErrorText(error, endpoint: endpoint, host: host, port: port)
    }
    throw ExitCode.failure
}

func cliErrorResponse(for error: Error, endpoint: String, host: String, port: Int, surface: String? = nil) -> TKCLIErrorResponse {
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        guard response.surface == nil, let surface else {
            return response
        }
        return TKCLIErrorResponse(error: response.error, surface: surface)
    }
    return TKCLIErrorResponse(error: cliErrorDetail(for: error, endpoint: endpoint, host: host, port: port), surface: surface)
}

func localizedErrorMessage(_ detail: TKCLIErrorDetail, language: CLILanguage) -> String {
    guard language == .zh else { return "\(detail.code) \(detail.message)" }
    switch detail.code {
    case "server_unavailable":
        return "服务器不可用：无法连接到本地 Triton 服务。"
    case "request_failed":
        return "请求失败：\(detail.message)"
    case "validation_failed":
        return "参数校验失败：\(detail.message)"
    default:
        return "\(detail.code)：\(detail.message)"
    }
}

func localizedHint(_ detail: TKCLIErrorDetail, fallback: String, language: CLILanguage) -> String {
    guard language == .zh else { return fallback }
    switch detail.code {
    case "server_unavailable":
        return "运行 `triton serve --host 127.0.0.1 --port 19421` 并连接 iOS App"
    default:
        return fallback
    }
}

func printValidationError(_ message: String) throws {
    let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
        code: "validation_failed",
        message: message,
        hint: "Run `triton schema --command act tap --json` to inspect required fields"
    ))
    print(try encodeJSON(response))
}

func cliErrorDetail(for error: Error, endpoint: String, host: String, port: Int) -> TKCLIErrorDetail {
    let url = endpointURL(endpoint, host: host, port: port)
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return response.error
    }
    if let hostAXError = error as? HostSimulatorAXError {
        return hostAXError.detail
    }
    if let aliasError = error as? NodeAliasResolutionError {
        return aliasError.detail(endpoint: url)
    }
    if let urlError = error as? URLError {
        return TKCLIErrorDetail(
            code: "server_unavailable",
            message: urlError.localizedDescription,
            endpoint: url,
            hint: "Run `triton serve --host \(host) --port \(port)` and connect the iOS app",
            nextAction: TKCLINextAction(
                command: "serve",
                args: ["--host", host, "--port", "\(port)"],
                requiresLongRunningProcess: true
            )
        )
    }
    if let runtime = error as? RuntimeError {
        return TKCLIErrorDetail(
            code: "request_failed",
            message: runtime.description,
            endpoint: url,
            hint: "Check `triton doctor --format json` for server and target state"
        )
    }
    if let targetError = error as? TKTargetResolutionError {
        let code: String
        switch targetError {
        case .ambiguous:
            code = "ambiguous_target"
        case .notFound:
            code = "target_not_found"
        }
        return TKCLIErrorDetail(
            code: code,
            message: targetError.description,
            endpoint: url,
            hint: "Run `triton list --json` and pass the exact --target id, or the simulator UDID for an iOS simulator runtime."
        )
    }
    if let tapError = error as? TKTapTargetResolutionFailure {
        return TKCLIErrorDetail(
            code: "text_not_found",
            message: tapError.message,
            endpoint: url,
            hint: "Run `triton act find \(tapError.query.isEmpty ? "''" : "'" + tapError.query.replacingOccurrences(of: "'", with: "'\\''") + "'") --all --json` and `triton screenshot --json` to inspect the current UI.",
            nearestCandidates: tapError.nearestCandidates,
            suggestedCommands: tapError.suggestedCommands,
            candidateCount: tapError.candidateCount
        )
    }
    return TKCLIErrorDetail(
        code: "request_failed",
        message: "\(error)",
        endpoint: url,
        hint: "Check `triton doctor --format json` for server and target state"
    )
}

func endpointURL(_ endpoint: String, host: String, port: Int) -> String {
    "http://\(host):\(port)\(endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)")"
}
