import ArgumentParser
import Foundation

struct SimCameraConfig: Codable, Equatable {
    var schemaVersion: Int = 1
    var provider: String = "triton-sim-camera"
    var hookPath: String
    var socketPath: String
    var enabledBundles: [String]
}

struct SimCameraOutput: Encodable {
    let ok: Bool
    let action: String
    let configPath: String
    let provider: String
    let hookPath: String
    let socketPath: String
    let enabledBundles: [String]
    let note: String
}

enum SimCameraConfigStore {
    static let defaultSocketPath = "/tmp/tritonkit-sim-camera.sock"

    static func workspaceHookPath(workspace: String) -> String {
        URL(fileURLWithPath: workspace)
            .appendingPathComponent(".triton")
            .appendingPathComponent("sim-camera")
            .appendingPathComponent("libTritonSimCameraHook.dylib")
            .path
    }

    static func filePath(workspace: String) -> String {
        URL(fileURLWithPath: workspace)
            .appendingPathComponent(".triton")
            .appendingPathComponent("sim-camera.json")
            .path
    }

    static func defaultHookPath(workspace: String) -> String {
        if let override = ProcessInfo.processInfo.environment["TRITON_SIM_CAMERA_HOOK"], !override.isEmpty {
            return override
        }
        return workspaceHookPath(workspace: workspace)
    }

    static func load(workspace: String) throws -> SimCameraConfig {
        let path = filePath(workspace: workspace)
        guard FileManager.default.fileExists(atPath: path) else {
            return SimCameraConfig(
                hookPath: defaultHookPath(workspace: workspace),
                socketPath: defaultSocketPath,
                enabledBundles: []
            )
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(SimCameraConfig.self, from: data)
    }

    static func save(_ config: SimCameraConfig, workspace: String) throws {
        let path = filePath(workspace: workspace)
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }
}

func enableSimCamera(
    bundleID: String,
    hookPath: String?,
    socketPath: String?,
    workspace: String
) throws -> SimCameraConfig {
    let bundleID = try normalizedSimCameraBundleID(bundleID)
    var config = try SimCameraConfigStore.load(workspace: workspace)
    if let hookPath, !hookPath.isEmpty {
        config.hookPath = hookPath
    }
    if let socketPath, !socketPath.isEmpty {
        config.socketPath = socketPath
    }
    if hookPath == nil || hookPath?.isEmpty == true {
        config.hookPath = try ensureDefaultSimCameraHook(workspace: workspace)
    }
    try validateSimCameraHook(path: config.hookPath)
    config.enabledBundles = Array(Set(config.enabledBundles + [bundleID])).sorted()
    try SimCameraConfigStore.save(config, workspace: workspace)
    return config
}

func disableSimCamera(bundleID: String, workspace: String) throws -> SimCameraConfig {
    let bundleID = try normalizedSimCameraBundleID(bundleID)
    var config = try SimCameraConfigStore.load(workspace: workspace)
    config.enabledBundles.removeAll { $0 == bundleID }
    try SimCameraConfigStore.save(config, workspace: workspace)
    return config
}

func simCameraLaunchEnvironment(
    bundleID: String,
    baseEnvironment: [String: String],
    workspace: String
) throws -> [String: String] {
    let config = try SimCameraConfigStore.load(workspace: workspace)
    guard config.enabledBundles.contains(bundleID) else {
        return baseEnvironment
    }
    try validateSimCameraHook(path: config.hookPath)
    if let existing = baseEnvironment["DYLD_INSERT_LIBRARIES"], existing != config.hookPath {
        throw ValidationError("DYLD_INSERT_LIBRARIES is already set; remove the explicit --env or run `triton camera off --bundle-id \(bundleID)`.")
    }
    var environment = baseEnvironment
    environment["DYLD_INSERT_LIBRARIES"] = config.hookPath
    environment["TRITON_SIM_CAMERA_SOCKET"] = config.socketPath
    return environment
}

private func normalizedSimCameraBundleID(_ value: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
        throw ValidationError("Camera bundle id must be non-empty and must not contain whitespace.")
    }
    return trimmed
}

func validateSimCameraHook(path: String) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
        throw ValidationError("Simulator camera hook dylib not found: \(path)")
    }
}

struct Camera: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "camera",
        abstract: "Configure iOS Simulator camera injection for selected apps",
        subcommands: [CameraOn.self, CameraOff.self, CameraStatus.self, CameraBuildHook.self, CameraServe.self]
    )
}

struct CameraBuildHook: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "build-hook", abstract: "Build the bundled Simulator camera hook dylib")

    @Option(help: "Output dylib path; defaults to .triton/sim-camera/libTritonSimCameraHook.dylib") var output: String?
    @Option(help: "Override hook source path; defaults to bundled TritonKit resources") var source: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let workspace = FileManager.default.currentDirectoryPath
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let outputPath = output ?? SimCameraConfigStore.workspaceHookPath(workspace: workspace)
            let result = try buildSimCameraHook(outputPath: outputPath, sourcePath: source)
            switch outputFormat {
            case .json:
                print(try encodeJSON(result))
            case .text:
                print("camera.build-hook: \(result.outputPath)")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct CameraServe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "serve", abstract: "Serve synthetic BGRA frames for the Simulator camera hook")

    @Option(help: "Unix socket path for hook clients") var socket: String = SimCameraConfigStore.defaultSocketPath
    @Option(help: "Frame width") var width: Int = 1280
    @Option(help: "Frame height") var height: Int = 720
    @Option(help: "Frames per second") var fps: Double = 15
    @Option(help: "Stop after this many frames") var maxFrames: Int?
    @Flag(help: "Stop after the first client disconnects") var once = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try runSimCameraFrameServer(options: SimCameraServeOptions(
                socketPath: socket,
                width: width,
                height: height,
                fps: fps,
                maxFrames: maxFrames,
                once: once,
                jsonl: outputFormat == .json
            ))
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct CameraOn: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "on", abstract: "Enable Simulator camera injection for one bundle")

    @Option(help: "iOS app bundle identifier") var bundleID: String
    @Option(help: "Path to libTritonSimCameraHook.dylib; defaults to TritonKit resources") var hook: String?
    @Option(help: "Unix socket used by the Triton simulator camera frame server") var socket: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let workspace = FileManager.default.currentDirectoryPath
        do {
            let config = try enableSimCamera(bundleID: bundleID, hookPath: hook, socketPath: socket, workspace: workspace)
            try printSimCameraOutput(action: "camera.on", config: config, workspace: workspace, outputFormat: effectiveFormat(format, json: json))
        } catch {
            try failHostCommand(error, outputFormat: effectiveFormat(format, json: json))
        }
    }
}

struct CameraOff: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "off", abstract: "Disable Simulator camera injection for one bundle")

    @Option(help: "iOS app bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let workspace = FileManager.default.currentDirectoryPath
        do {
            let config = try disableSimCamera(bundleID: bundleID, workspace: workspace)
            try printSimCameraOutput(action: "camera.off", config: config, workspace: workspace, outputFormat: effectiveFormat(format, json: json))
        } catch {
            try failHostCommand(error, outputFormat: effectiveFormat(format, json: json))
        }
    }
}

struct CameraStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Show Simulator camera injection config")

    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let workspace = FileManager.default.currentDirectoryPath
        do {
            let config = try SimCameraConfigStore.load(workspace: workspace)
            try printSimCameraOutput(action: "camera.status", config: config, workspace: workspace, outputFormat: effectiveFormat(format, json: json))
        } catch {
            try failHostCommand(error, outputFormat: effectiveFormat(format, json: json))
        }
    }
}

private func printSimCameraOutput(
    action: String,
    config: SimCameraConfig,
    workspace: String,
    outputFormat: ClientOutputFormat
) throws {
    let note = "Camera injection is applied only when `triton app launch` starts an enabled iOS Simulator bundle."
    let output = SimCameraOutput(
        ok: true,
        action: action,
        configPath: SimCameraConfigStore.filePath(workspace: workspace),
        provider: config.provider,
        hookPath: config.hookPath,
        socketPath: config.socketPath,
        enabledBundles: config.enabledBundles,
        note: note
    )
    switch outputFormat {
    case .json:
        print(try encodeJSON(output))
    case .text:
        print("\(action): \(config.enabledBundles.joined(separator: ", "))")
        print(note)
    }
}
