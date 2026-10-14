import ArgumentParser
import Foundation

struct DeviceRecording: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "recording", abstract: "Start, inspect and stop an owned background screen recording", subcommands: [DeviceRecordingStart.self, DeviceRecordingStatus.self, DeviceRecordingStop.self, DeviceRecordingWorker.self])
}
struct DeviceRecordingStart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start", abstract: "Start a bounded background recording; other device actions remain available")
    @Option(help: "Explicit typed device selector") var device: String
    @Option(help: "Fresh absolute MP4 destination; never overwritten") var output: String
    @Option(help: "Maximum session duration in seconds, 1...180") var maximumDuration: Double = 180
    @Option(help: "ADB executable") var adb: String = "adb"
    @Option(help: "HDC executable") var hdc: String = "hdc"
    @Flag var json = false
    @Option var format: ClientOutputFormat = .json
    func run() async throws {
        try await emitDeviceRecording(action: "start", format: effectiveFormat(format, json: json)) {
            try await startDeviceRecording(device: device, output: output, maximumDuration: maximumDuration, adb: adb, hdc: hdc)
        }
    }
}
struct DeviceRecordingStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Read session state and verify background worker identity")
    @Option var session: String
    @Option(help: "Optional exact original target guard") var device: String?
    @Flag var json = false
    @Option var format: ClientOutputFormat = .json
    func run() async throws {
        try await emitDeviceRecording(action: "status", format: effectiveFormat(format, json: json)) { try inspectDeviceRecording(session: session, device: device) }
    }
}
struct DeviceRecordingStop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop", abstract: "Ask the owning worker to finalize its artifact with a bounded wait")
    @Option var session: String
    @Option(help: "Optional exact original target guard") var device: String?
    @Flag var json = false
    @Option var format: ClientOutputFormat = .json
    func run() async throws {
        try await emitDeviceRecording(action: "stop", format: effectiveFormat(format, json: json)) { try await stopDeviceRecording(session: session, device: device) }
    }
}
struct DeviceRecordingWorker: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "_worker", abstract: "Internal owned recording worker", shouldDisplay: false)
    @Option var session: String
    func run() async throws { try await runDeviceRecordingWorker(session: session) }
}
func emitDeviceRecording(action: String, format: ClientOutputFormat, operation: () async throws -> DeviceRecordingSession) async throws {
    do {
        let record = try await operation()
        let duration = max(0, (record.endedAt ?? Date()).timeIntervalSince(record.startedAt))
        let output = DeviceRecordingOutput(ok: record.state != "failed", action: "device.recording.\(action)", session: record,
                                           wallClockDurationSeconds: duration,
                                           captureMethod: record.platform == "ios" && record.scope == "real" ? "runner-snapshot-sequence" : "native-screen-recording",
                                           artifacts: record.state == "completed" ? [record.output] : [])
        switch format { case .json: print(try encodeJSON(output)); case .text: print("\(record.sessionID)\t\(record.state)\t\(record.target)\t\(record.output)") }
        if record.state == "failed" { throw ExitCode.failure }
    } catch let error as DeviceRecordingFailure {
        try failHostValidation(code: error.code, message: error.description, hint: "Inspect the session and use its original owner and target; no unrelated process is signalled.", outputFormat: format)
    } catch { try failHostCommand(error, outputFormat: format) }
}
