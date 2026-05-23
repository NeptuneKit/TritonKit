import ArgumentParser
import Foundation
import TritonKitShared

struct Smoke: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "smoke",
        abstract: "Run one-command smoke flows for real-project regression",
        subcommands: [SmokeIOS.self, SmokeHarmony.self]
    )
}

struct SmokeIOS: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ios", abstract: "Run one-command iOS smoke evidence flow")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Runtime target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "App bundle identifier") var bundleID: String
    @Option(help: "URL to open") var openURL: String
    @Option(name: .customLong("wait-text"), help: "Visible text to wait for") var waitText: String
    @Option(name: .customLong("assert-text"), help: "Visible text to assert after waiting") var assertText: String?
    @Option(name: .customLong("screenshot"), help: "Output simulator screenshot path") var screenshot: String?
    @Option(name: .customLong("evidence"), help: "Output evidence bundle directory path") var evidence: String
    @Option(name: .customLong("evidence-name"), help: "Name stored in evidence manifest") var evidenceName: String?
    @Option(name: .customLong("evidence-note"), help: "Note stored in evidence manifest") var evidenceNote: String?
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Timeout in seconds") var timeout: Double = 20
    @Option(help: "Polling interval in seconds") var interval: Double = 0.5
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let summary = try await runIOSSmoke(options: IOSSmokeOptions(
                simulator: simulator,
                target: target,
                bundleID: bundleID,
                openURL: openURL,
                waitText: waitText,
                assertText: assertText,
                screenshot: screenshot,
                evidence: evidence,
                evidenceName: evidenceName,
                evidenceNote: evidenceNote,
                host: host,
                port: port,
                timeout: timeout,
                interval: interval
            ))
            switch outputFormat {
            case .json:
                print(try encodeJSON(summary))
            case .text:
                print("status: \(summary.status.rawValue)")
                print("steps: \(summary.steps.count)")
                print("artifacts: \(summary.artifacts.count)")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SmokeHarmony: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "harmony", abstract: "Run one-command Harmony host-side smoke evidence flow")

    @Option(help: "Harmony target id, for example 127.0.0.1:10100") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Harmony bundle name") var bundle: String
    @Option(help: "Harmony ability name") var ability: String
    @Option(help: "Optional deep link URL to open with aa start -U") var openURL: String?
    @Option(name: .customLong("wait-text"), help: "Visible text to wait for after launch/open-url") var waitText: String
    @Option(name: .customLong("tap-text"), help: "Optional visible text to tap after the first wait passes") var tapText: String?
    @Option(name: .customLong("post-tap-wait-text"), help: "Optional visible text to wait for after --tap-text") var postTapWaitText: String?
    @Option(name: .customLong("screenshot"), help: "Output Harmony screenshot path, usually .jpeg") var screenshot: String?
    @Option(name: .customLong("evidence"), help: "Output evidence bundle directory path") var evidence: String
    @Option(name: .customLong("evidence-name"), help: "Name stored in evidence manifest") var evidenceName: String?
    @Option(name: .customLong("evidence-note"), help: "Note stored in evidence manifest") var evidenceNote: String?
    @Option(help: "Timeout in seconds") var timeout: Double = 20
    @Option(help: "Polling interval in seconds") var interval: Double = 0.5
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let summary = try await runHarmonySmoke(options: HarmonySmokeOptions(
                target: target,
                hdc: hdc,
                bundle: bundle,
                ability: ability,
                openURL: openURL,
                waitText: waitText,
                tapText: tapText,
                postTapWaitText: postTapWaitText,
                screenshot: screenshot,
                evidence: evidence,
                evidenceName: evidenceName,
                evidenceNote: evidenceNote,
                timeout: timeout,
                interval: interval
            ))
            switch outputFormat {
            case .json:
                print(try encodeJSON(summary))
            case .text:
                print("status: \(summary.status.rawValue)")
                print("steps: \(summary.steps.count)")
                print("artifacts: \(summary.artifacts.count)")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
