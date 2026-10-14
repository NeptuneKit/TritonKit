import ArgumentParser
import CoreGraphics
import Foundation
import TritonKitShared

struct VisualCaptureInput {
    let data: Data
    let capturedAt: String
    let source: String
    let scale: Double?
}

/// A single pinned selection and private temporary directory prevent interleaving targets or
/// publishing screenshots into a caller's workspace. Captures are read-only observations.
final class VisualScreenshotProvider {
    private let selection: HostDeviceSelectionResult?
    private let runtimeClient: TritonKitHTTPClient?
    private let temporaryDirectory: URL?
    private let adb: String
    private let hdc: String

    private init(selection: HostDeviceSelectionResult?, runtimeClient: TritonKitHTTPClient?, temporaryDirectory: URL?, adb: String, hdc: String) {
        self.selection = selection
        self.runtimeClient = runtimeClient
        self.temporaryDirectory = temporaryDirectory
        self.adb = adb
        self.hdc = hdc
    }

    static func make(device: String?, target: String, host: String, port: Int, timeout: Double,
                     runtimeBaseURL: String? = nil, adb: String = "adb", hdc: String = "hdc",
                     platform: HostDevicePlatform? = nil, scope: HostDeviceScope? = nil) async throws -> VisualScreenshotProvider {
        guard timeout.isFinite, (0.000001...60).contains(timeout), (1...65535).contains(port) else {
            throw VisualFeedbackError.invalid("Visual screenshot timeout and server port must be finite and in range")
        }
        guard runtimeBaseURL == nil || device != nil else {
            throw VisualFeedbackError.invalid("Direct embedded HTTP has no screenshot-data route; use its connected server runtime target for visual observation")
        }
        if let device {
            guard target == TKLocalTargetID else { throw VisualFeedbackError.invalid("--device cannot be combined with --target") }
            let selection = try visualHostSelection(device: device, platform: platform, scope: scope, timeout: timeout, adb: adb, hdc: hdc)
            guard selection.target.scope != HostDeviceScope.real.rawValue else {
                throw VisualFeedbackError.invalid("Visual observation host capture currently requires a simulator or emulator; real devices require their dedicated workflow")
            }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-visual-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            return VisualScreenshotProvider(selection: selection, runtimeClient: nil, temporaryDirectory: directory, adb: adb, hdc: hdc)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let client = TritonKitHTTPClient(host: host, port: port, session: URLSession(configuration: configuration))
        let targets: TKTargetsResponse = try await client.getJSON("/targets")
        let selected = try TKResolveTargetSummary(target, in: targets.targets)
        return VisualScreenshotProvider(selection: nil, runtimeClient: TritonKitHTTPClient(host: host, port: port, target: selected.id, session: client.session), temporaryDirectory: nil, adb: adb, hdc: hdc)
    }

    deinit {
        if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
        runtimeClient?.session.invalidateAndCancel()
    }

    func capture(timeout: Double) async throws -> VisualCaptureInput {
        guard timeout.isFinite, timeout > 0 else { throw VisualFeedbackError.invalid("Screenshot deadline elapsed") }
        if let selection, let temporaryDirectory {
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            if selection.platform == .android {
                let result = try runHostCommand(TKAndroidADBCommand.screenshot(serial: selection.target.rawTarget, executable: adb).withTimeout(timeout), maximumOutputBytes: 64 * 1024 * 1024)
                guard !result.stdoutTruncated, ProcessInfo.processInfo.systemUptime < deadline else { throw VisualFeedbackError.invalid("Screenshot capture exceeded its deadline or byte budget") }
                _ = try validateRuntimeScreenshotPayload(result.stdoutData, declaredFormat: "png")
                return VisualCaptureInput(data: result.stdoutData, capturedAt: ISO8601DateFormatter().string(from: Date()), source: "host-android-screenshot", scale: nil)
            }
            let path = visualScreenshotCapturePath(in: temporaryDirectory)
            if selection.platform == .harmony {
                let remotePath = remoteHarmonyArtifactPath(prefix: "triton-visual", extension: "jpeg")
                defer {
                    let cleanupBudget = deadline - ProcessInfo.processInfo.systemUptime
                    if cleanupBudget > 0.05 {
                        _ = try? runHostCommand(TKHostCommand(executable: hdc, arguments: ["-t", selection.target.rawTarget, "shell", "rm", "-f", remotePath],
                                                           riskLevel: .evidence, requiredConfig: [.target, .timeout, .auditRecord],
                                                           defaultTimeoutSeconds: cleanupBudget))
                    }
                }
                _ = try runHostCommand(TKHarmonyHDCCommand.screenshot(target: selection.target.rawTarget, remotePath: remotePath, executable: hdc).withTimeout(timeout))
                let remaining = deadline - ProcessInfo.processInfo.systemUptime
                guard remaining > 0 else { throw VisualFeedbackError.invalid("Screenshot deadline elapsed") }
                _ = try runHostCommand(TKHarmonyHDCCommand.recvFile(target: selection.target.rawTarget, remotePath: remotePath, localPath: path, executable: hdc).withTimeout(remaining))
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw VisualFeedbackError.invalid("Screenshot deadline elapsed") }
                return VisualCaptureInput(data: try visualReadImageFile(path), capturedAt: ISO8601DateFormatter().string(from: Date()), source: "host-harmony-screenshot", scale: nil)
            }
            let response = try captureHostDeviceScreenshot(platform: selection.platform, target: selection.target, selection: selection, hdc: hdc, adb: adb, output: path, timeout: timeout)
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw VisualFeedbackError.invalid("Screenshot deadline elapsed") }
            return VisualCaptureInput(data: try visualReadImageFile(path), capturedAt: response.capturedAt,
                                      source: "host-\(selection.platform.rawValue)-screenshot", scale: nil)
        }
        guard let client = runtimeClient else { throw VisualFeedbackError.invalid("No screenshot provider") }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let bounded = TritonKitHTTPClient(host: client.host, port: client.port, target: client.target, session: session)
        let payload = try await bounded.request(type: "screenshot")
        let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: payload)
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else { throw VisualFeedbackError.invalid("Screenshot deadline elapsed") }
        let data: Data
        if let reference = screenshot.dataRef, !reference.isEmpty {
            let dataConfiguration = URLSessionConfiguration.ephemeral
            dataConfiguration.timeoutIntervalForRequest = remaining
            dataConfiguration.timeoutIntervalForResource = remaining
            let dataSession = URLSession(configuration: dataConfiguration)
            defer { dataSession.invalidateAndCancel() }
            data = try await TritonKitHTTPClient(host: client.host, port: client.port, target: client.target, session: dataSession).getData("/data/\(reference)")
        } else {
            data = try await screenshotImageData(screenshot, client: bounded)
        }
        _ = try validateRuntimeScreenshotPayload(data, declaredFormat: screenshot.format)
        return VisualCaptureInput(data: data, capturedAt: ISO8601DateFormatter().string(from: Date()), source: "embedded-runtime-screenshot", scale: screenshot.scale)
    }
}

func visualScreenshotCapturePath(in directory: URL) -> String {
    directory.appendingPathComponent("capture-\(UUID().uuidString).png").path
}

private func visualReadImageFile(_ path: String) throws -> Data {
    let url = URL(fileURLWithPath: path)
    let values = try url.resourceValues(forKeys: [.fileSizeKey])
    guard (values.fileSize ?? Int.max) <= 64 * 1024 * 1024 else { throw VisualFeedbackError.invalid("Screenshot file exceeds 64 MiB") }
    return try Data(contentsOf: url)
}

private func visualHostSelection(device: String, platform: HostDevicePlatform?, scope: HostDeviceScope?, timeout: Double, adb: String, hdc: String) throws -> HostDeviceSelectionResult {
    let aliases = try loadHostTargetAliasStore()
    let effectiveSelector = device == "current" ? (aliases.current ?? device) : device
    let inferred: HostDevicePlatform?
    if let alias = aliases.aliases[effectiveSelector] { inferred = alias.platform }
    else if effectiveSelector.hasPrefix("sim:") || effectiveSelector.hasPrefix("triton:ios-simulator:") || effectiveSelector == "booted" || UUID(uuidString: effectiveSelector) != nil { inferred = .ios }
    else if effectiveSelector.hasPrefix("android:") || effectiveSelector.hasPrefix("triton:android:") { inferred = .android }
    else if effectiveSelector.hasPrefix("harmony:") || effectiveSelector.hasPrefix("triton:harmony:") { inferred = .harmony }
    else { inferred = nil }
    guard let selectedPlatform = platform ?? inferred else {
        throw VisualFeedbackError.invalid("Use a platform-qualified simulator/emulator selector or --platform for visual capture")
    }
    let requestedScope = scope ?? (selectedPlatform == .ios ? .simulator : .emulator)
    guard requestedScope == .simulator || requestedScope == .emulator else { throw VisualFeedbackError.invalid("Visual host capture requires simulator/emulator scope") }
    let candidates: [HostDeviceTarget]
    switch selectedPlatform {
    case .ios:
        let result = try runHostCommand(TKSimctlCommand.listAvailableDevices().withTimeout(timeout))
        candidates = try TKSimctlDeviceListParser.parse(result.stdoutData).map(hostDeviceTarget(from:))
    case .android:
        let result = try runHostCommand(TKAndroidADBCommand.listDevices(executable: adb).withTimeout(timeout))
        candidates = TKAdbDeviceListParser.targets(TKAdbDeviceListParser.parse(result.stdout), matching: .emulator).map(hostDeviceTarget(from:))
    case .harmony:
        let result = try runHostCommand(TKHarmonyHDCCommand.listTargets(executable: hdc).withTimeout(timeout))
        candidates = TKHdcTargetListParser.parse([result.stdout, result.stderr].joined(separator: "\n")).map(hostDeviceTarget(from:))
    }
    return try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: device, platform: selectedPlatform, scope: requestedScope, ready: true), candidates: [selectedPlatform: candidates], aliases: aliases)
}

struct ObserveOCR: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ocr", abstract: "Explicit host Vision OCR of a screenshot; returns candidates only")
    @Option(help: "Existing image path; omit to capture the selected target") var image: String?
    @Option(help: "Simulator/emulator selector for host screenshots") var device: String?
    @Option(help: "Host screenshot platform: ios, android or harmony") var platform: HostDevicePlatform?
    @Option(help: "Host screenshot scope: simulator or emulator") var scope: HostDeviceScope?
    @Option(help: "Embedded runtime target") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Pixel-per-point scale; omit when unknown") var scale: Double?
    @Option(help: "OCR policy: explicit or structure-unavailable") var policy: VisualOCRPolicy = .explicit
    @Option(help: "Actual structural observation failure reason for the fallback policy") var structureUnavailableReason: String?
    @Option(help: "Minimum confidence 0...1") var minimumConfidence: Double = 0.5
    @Option(help: "Maximum OCR candidates 1...1000") var maxCandidates: Int = 200
    @Option(help: "Recognition languages, comma-separated BCP-47 tags; omit for automatic detection") var languages: String?
    @Option(help: "Capture timeout seconds, maximum 60") var timeout: Double = 5
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            try validateVisualOCRPolicy(policy, reason: structureUnavailableReason)
            guard timeout.isFinite, (0.05...60).contains(timeout), minimumConfidence.isFinite,
                  (0...1).contains(minimumConfidence), (1...1000).contains(maxCandidates) else {
                throw VisualFeedbackError.invalid("Invalid OCR confidence, candidate budget or capture timeout")
            }
            if let scale { _ = try visualOCRBounds(normalized: .zero, pixelWidth: 1, pixelHeight: 1, scale: scale) }
            guard device != nil || (platform == nil && scope == nil) else { throw VisualFeedbackError.invalid("--platform and --scope require --device") }
            let input: VisualCaptureInput
            if let image {
                guard device == nil, target == TKLocalTargetID, platform == nil, scope == nil else { throw VisualFeedbackError.invalid("--image cannot be combined with --device, --target, --platform or --scope") }
                let url = URL(fileURLWithPath: image)
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                guard (values.fileSize ?? Int.max) <= 64 * 1024 * 1024 else { throw VisualFeedbackError.invalid("OCR image exceeds 64 MiB") }
                let capturedAt = values.contentModificationDate.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown"
                input = VisualCaptureInput(data: try visualReadImageFile(image), capturedAt: capturedAt, source: "image-file-modification-time", scale: nil)
            } else {
                let captureStartedAt = ProcessInfo.processInfo.systemUptime
                let provider = try await VisualScreenshotProvider.make(device: device, target: target, host: host, port: port, timeout: timeout, platform: platform, scope: scope)
                input = try await provider.capture(timeout: timeout - (ProcessInfo.processInfo.systemUptime - captureStartedAt))
            }
            let result = try recognizeVisualText(data: input.data, capturedAt: input.capturedAt, screenshotSource: input.source,
                                                 scale: scale ?? input.scale, policy: policy, structureUnavailableReason: structureUnavailableReason,
                                                 minimumConfidence: minimumConfidence, maxCandidates: maxCandidates,
                                                 languages: languages?.split(separator: ",").map(String.init) ?? [])
            switch outputFormat {
            case .json: print(try encodeJSON(result))
            case .text: for candidate in result.candidates { print("\(candidate.confidence) \(candidate.text)") }
            }
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error is VisualFeedbackError ? ValidationError(String(describing: error)) : error, outputFormat: outputFormat)
        }
    }
}

struct ObserveSettle: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "settle", abstract: "Wait for bounded screenshot stability without verifying business state")
    @Option(help: "Simulator/emulator selector for host screenshots") var device: String?
    @Option(help: "Host screenshot platform: ios, android or harmony") var platform: HostDevicePlatform?
    @Option(help: "Host screenshot scope: simulator or emulator") var scope: HostDeviceScope?
    @Option(help: "Embedded runtime target") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Maximum changed area fraction 0...1") var changeThreshold: Double = 0.01
    @Option(help: "RGB per-pixel difference threshold 0...1") var pixelThreshold: Double = 0.04
    @Option(help: "Required consecutive stable window seconds") var stableWindow: Double = 0.5
    @Option(help: "Sample interval seconds") var interval: Double = 0.1
    @Option(help: "Overall deadline seconds, maximum 60") var timeout: Double = 5
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let configuration = try VisualSettleConfiguration(changeThreshold: changeThreshold, pixelThreshold: pixelThreshold,
                                                              stableWindow: stableWindow, interval: interval, timeout: timeout)
            guard device != nil || (platform == nil && scope == nil) else { throw VisualFeedbackError.invalid("--platform and --scope require --device") }
            guard device == nil || target == TKLocalTargetID else { throw VisualFeedbackError.invalid("--device cannot be combined with --target") }
            let start = ProcessInfo.processInfo.systemUptime
            let provider: VisualScreenshotProvider
            do {
                provider = try await VisualScreenshotProvider.make(device: device, target: target, host: host, port: port, timeout: timeout, platform: platform, scope: scope)
            } catch {
                let result = VisualSettleOutput(ok: false, action: "observe.settle", state: .unknown, reason: "screenshot_provider_unavailable",
                                               businessVerified: false, elapsedMs: max(0, Int((ProcessInfo.processInfo.systemUptime - start) * 1000)),
                                               sampleCount: 0, lastChangeFraction: nil, capturedAt: nil, source: nil,
                                               configuration: configuration, comparisonPolicy: "changed RGB pixel area on a raw-raster thumbnail of at most 384 pixels per axis")
                switch outputFormat {
                case .json: print(try encodeJSON(result))
                case .text: print("unknown: screenshot_provider_unavailable; businessVerified=false")
                }
                throw ExitCode.failure
            }
            let result = await runVisualSettle(configuration: configuration, capture: { budget in
                let input = try await provider.capture(timeout: budget)
                return try visualScreenshotFrame(data: input.data, capturedAt: input.capturedAt, source: input.source, scale: input.scale)
            }, startedAt: start)
            switch outputFormat {
            case .json: print(try encodeJSON(result))
            case .text: print("\(result.state.rawValue): \(result.reason); businessVerified=false")
            }
            if !result.ok { throw ExitCode.failure }
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error is VisualFeedbackError ? ValidationError(String(describing: error)) : error, outputFormat: outputFormat)
        }
    }
}
