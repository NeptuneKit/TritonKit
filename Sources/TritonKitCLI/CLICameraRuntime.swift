import Darwin
import ArgumentParser
import Foundation
import TritonKitShared

struct SimCameraHookBuildOutput: Encodable {
    let ok: Bool
    let action: String
    let sourcePath: String
    let outputPath: String
    let sourceCommand: String
    let codesignCommand: String?
    let note: String
}

struct SimCameraServeEvent: Encodable {
    let ok: Bool
    let action: String
    let socketPath: String
    let protocolVersion: UInt32
    let width: Int
    let height: Int
    let fps: Double
    let framesServed: Int
    let clientAccepted: Bool
    let note: String?
}

struct SimCameraServeOptions {
    var socketPath: String
    var width: Int
    var height: Int
    var fps: Double
    var maxFrames: Int?
    var once: Bool
    var jsonl: Bool
}

struct SimCameraFrame {
    static let headerByteCount = 48
    static let magic: UInt32 = 0x434D_4953
    static let protocolVersion: UInt32 = 2
    static let bgraPixelFormat: UInt32 = 0x4152_4742

    let header: Data
    let payload: Data
}

func ensureDefaultSimCameraHook(workspace: String) throws -> String {
    let outputPath = SimCameraConfigStore.workspaceHookPath(workspace: workspace)
    if FileManager.default.fileExists(atPath: outputPath) {
        try validateSimCameraHook(path: outputPath)
        return outputPath
    }
    _ = try buildSimCameraHook(outputPath: outputPath)
    return outputPath
}

func bundledSimCameraHookSourcePath() throws -> String {
    let candidates = [
        Bundle.module.resourceURL?
            .appendingPathComponent("TritonSimCameraHook.m"),
        Bundle.module.resourceURL?
            .appendingPathComponent("sim-camera")
            .appendingPathComponent("TritonSimCameraHook.m"),
        Bundle.main.resourceURL?
            .appendingPathComponent("TritonSimCameraHook.m"),
        Bundle.main.resourceURL?
            .appendingPathComponent("sim-camera")
            .appendingPathComponent("TritonSimCameraHook.m"),
    ].compactMap { $0 }
    for url in candidates where FileManager.default.fileExists(atPath: url.path) {
        return url.path
    }
    throw ValidationError("Bundled simulator camera hook source was not found in TritonKit CLI resources.")
}

func buildSimCameraHook(outputPath: String, sourcePath explicitSourcePath: String? = nil) throws -> SimCameraHookBuildOutput {
    let sourcePath: String
    if let explicitSourcePath {
        sourcePath = explicitSourcePath
    } else {
        sourcePath = try bundledSimCameraHookSourcePath()
    }
    guard FileManager.default.fileExists(atPath: sourcePath) else {
        throw ValidationError("Simulator camera hook source not found: \(sourcePath)")
    }
    try ensureParentDirectory(for: outputPath)
    if FileManager.default.fileExists(atPath: outputPath) {
        try FileManager.default.removeItem(atPath: outputPath)
    }

    let command = TKHostCommand(
        executable: "xcrun",
        arguments: [
            "--sdk", "iphonesimulator",
            "clang",
            "-dynamiclib",
            "-fobjc-arc",
            "-isysroot", "$(xcrun --sdk iphonesimulator --show-sdk-path)",
            "-mios-simulator-version-min=13.0",
            "-framework", "Foundation",
            "-framework", "AVFoundation",
            "-framework", "CoreMedia",
            "-framework", "CoreVideo",
            "-framework", "CoreGraphics",
            "-framework", "QuartzCore",
            sourcePath,
            "-o", outputPath,
        ],
        riskLevel: .automation,
        requiredConfig: [.timeout, .auditRecord],
        defaultTimeoutSeconds: 120,
        capturesArtifacts: true,
        sensitiveOutput: false
    )

    var arguments = command.arguments
    if let sdkIndex = arguments.firstIndex(of: "-isysroot"),
       arguments.indices.contains(arguments.index(after: sdkIndex)) {
        let sdkPathResult = try runHostCommand(TKHostCommand(
            executable: "xcrun",
            arguments: ["--sdk", "iphonesimulator", "--show-sdk-path"],
            defaultTimeoutSeconds: 10
        ))
        let sdkPath = sdkPathResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sdkPath.isEmpty else {
            throw ValidationError("Unable to resolve iphonesimulator SDK path with xcrun.")
        }
        arguments[arguments.index(after: sdkIndex)] = sdkPath
    }

    let resolvedCommand = TKHostCommand(
        executable: command.executable,
        arguments: arguments,
        riskLevel: command.riskLevel,
        requiredConfig: command.requiredConfig,
        defaultTimeoutSeconds: command.defaultTimeoutSeconds,
        capturesArtifacts: command.capturesArtifacts,
        sensitiveOutput: command.sensitiveOutput
    )
    _ = try runHostCommand(resolvedCommand)

    var codesignSource: String?
    let codesignCommand = TKHostCommand(
        executable: "codesign",
        arguments: ["--force", "--sign", "-", outputPath],
        riskLevel: .automation,
        requiredConfig: [.timeout, .auditRecord],
        defaultTimeoutSeconds: 30
    )
    do {
        _ = try runHostCommand(codesignCommand)
        codesignSource = hostSourceCommand(codesignCommand)
    } catch {
        codesignSource = nil
    }

    try validateSimCameraHook(path: outputPath)
    return SimCameraHookBuildOutput(
        ok: true,
        action: "camera.build-hook",
        sourcePath: sourcePath,
        outputPath: outputPath,
        sourceCommand: hostSourceCommand(resolvedCommand),
        codesignCommand: codesignSource,
        note: "Built the TritonKit simulator camera hook dylib from bundled resources."
    )
}

func makeSimCameraFrame(width: Int, height: Int, frameIndex: Int, hostTimeNs: UInt64) throws -> SimCameraFrame {
    guard width > 0, height > 0 else {
        throw ValidationError("Camera frame width and height must be positive.")
    }
    let bytesPerRow = width * 4
    var payload = Data(count: bytesPerRow * height)
    payload.withUnsafeMutableBytes { rawBuffer in
        guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
            return
        }
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * 4)
                bytes[offset] = UInt8((x + frameIndex * 3) % 256)
                bytes[offset + 1] = UInt8((y + frameIndex * 5) % 256)
                bytes[offset + 2] = UInt8((x + y + frameIndex * 7) % 256)
                bytes[offset + 3] = 255
            }
        }
    }

    var header = Data()
    appendLittleEndianUInt32(SimCameraFrame.magic, to: &header)
    appendLittleEndianUInt32(SimCameraFrame.protocolVersion, to: &header)
    appendLittleEndianUInt32(UInt32(width), to: &header)
    appendLittleEndianUInt32(UInt32(height), to: &header)
    appendLittleEndianUInt32(UInt32(bytesPerRow), to: &header)
    appendLittleEndianUInt32(SimCameraFrame.bgraPixelFormat, to: &header)
    appendLittleEndianUInt64(hostTimeNs, to: &header)
    appendLittleEndianUInt32(UInt32(payload.count), to: &header)
    appendLittleEndianUInt32(0, to: &header)
    appendLittleEndianUInt32(0, to: &header)
    appendLittleEndianUInt32(0, to: &header)
    guard header.count == SimCameraFrame.headerByteCount else {
        throw ValidationError("Internal camera frame header size mismatch: \(header.count)")
    }
    return SimCameraFrame(header: header, payload: payload)
}

func runSimCameraFrameServer(options: SimCameraServeOptions) throws -> SimCameraServeEvent {
    guard options.width > 0, options.height > 0 else {
        throw ValidationError("Camera frame width and height must be positive.")
    }
    guard options.fps > 0 else {
        throw ValidationError("Camera fps must be positive.")
    }
    if let maxFrames = options.maxFrames, maxFrames <= 0 {
        throw ValidationError("Camera max frames must be positive when provided.")
    }

    signal(SIGPIPE, SIG_IGN)
    try? FileManager.default.removeItem(atPath: options.socketPath)
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    defer {
        close(fd)
        try? FileManager.default.removeItem(atPath: options.socketPath)
    }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let maxPathLength = MemoryLayout.size(ofValue: addr.sun_path)
    guard options.socketPath.utf8.count < maxPathLength else {
        throw ValidationError("Camera socket path is too long: \(options.socketPath)")
    }
    _ = withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { target in
            strncpy(target, options.socketPath, maxPathLength - 1)
        }
    }
    let bindResult = withUnsafePointer(to: &addr) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            Darwin.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard bindResult == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    guard listen(fd, 1) == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    try printSimCameraServeEvent(
        SimCameraServeEvent(
            ok: true,
            action: "camera.serve.ready",
            socketPath: options.socketPath,
            protocolVersion: SimCameraFrame.protocolVersion,
            width: options.width,
            height: options.height,
            fps: options.fps,
            framesServed: 0,
            clientAccepted: false,
            note: "Waiting for Triton simulator camera hook clients."
        ),
        jsonl: options.jsonl
    )

    var framesServed = 0
    repeat {
        let client = accept(fd, nil, nil)
        if client < 0 {
            if errno == EINTR {
                continue
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { close(client) }
        try printSimCameraServeEvent(
            SimCameraServeEvent(
                ok: true,
                action: "camera.serve.client",
                socketPath: options.socketPath,
                protocolVersion: SimCameraFrame.protocolVersion,
                width: options.width,
                height: options.height,
                fps: options.fps,
                framesServed: framesServed,
                clientAccepted: true,
                note: nil
            ),
            jsonl: options.jsonl
        )

        while options.maxFrames.map({ framesServed < $0 }) ?? true {
            let frame = try makeSimCameraFrame(
                width: options.width,
                height: options.height,
                frameIndex: framesServed,
                hostTimeNs: UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
            )
            if !writeAll(frame.header, fd: client) || !writeAll(frame.payload, fd: client) {
                break
            }
            framesServed += 1
            if options.maxFrames.map({ framesServed >= $0 }) ?? false {
                break
            }
            Thread.sleep(forTimeInterval: 1.0 / options.fps)
        }
    } while !options.once && options.maxFrames == nil

    let summary = SimCameraServeEvent(
        ok: true,
        action: "camera.serve.summary",
        socketPath: options.socketPath,
        protocolVersion: SimCameraFrame.protocolVersion,
        width: options.width,
        height: options.height,
        fps: options.fps,
        framesServed: framesServed,
        clientAccepted: framesServed > 0,
        note: "Simulator camera frame server stopped."
    )
    try printSimCameraServeEvent(summary, jsonl: options.jsonl)
    return summary
}

private func appendLittleEndianUInt32(_ value: UInt32, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

private func appendLittleEndianUInt64(_ value: UInt64, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

private func writeAll(_ data: Data, fd: Int32) -> Bool {
    data.withUnsafeBytes { rawBuffer in
        guard var pointer = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
            return false
        }
        var remaining = data.count
        while remaining > 0 {
            let written = Darwin.write(fd, pointer, remaining)
            if written <= 0 {
                return false
            }
            pointer = pointer.advanced(by: written)
            remaining -= written
        }
        return true
    }
}

private func printSimCameraServeEvent(_ event: SimCameraServeEvent, jsonl: Bool) throws {
    if jsonl {
        print(try encodeJSON(event))
    } else {
        print("\(event.action): \(event.socketPath) frames=\(event.framesServed)")
    }
    fflush(stdout)
}
