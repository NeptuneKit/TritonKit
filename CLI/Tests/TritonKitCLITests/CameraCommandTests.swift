import Foundation
import Darwin
import Testing
@testable import TritonKitCLI

@Suite
struct CameraCommandTests {
    @Test("camera config enables one bundle and app launch injects only that bundle")
    func cameraConfigInjectsEnabledBundleOnly() throws {
        let workspace = try temporaryWorkspace()
        let hook = workspace.appendingPathComponent("libTritonSimCameraHook.dylib").path
        FileManager.default.createFile(atPath: hook, contents: Data("fake dylib".utf8))

        let config = try enableSimCamera(
            bundleID: "com.example.camera",
            hookPath: hook,
            socketPath: "/tmp/tritonkit-test-camera.sock",
            workspace: workspace.path
        )

        #expect(config.enabledBundles == ["com.example.camera"])
        #expect(config.hookPath == hook)

        let injected = try simCameraLaunchEnvironment(
            bundleID: "com.example.camera",
            baseEnvironment: ["FEATURE_FLAG": "1"],
            workspace: workspace.path
        )
        #expect(injected["FEATURE_FLAG"] == "1")
        #expect(injected["DYLD_INSERT_LIBRARIES"] == hook)
        #expect(injected["TRITON_SIM_CAMERA_SOCKET"] == "/tmp/tritonkit-test-camera.sock")

        let untouched = try simCameraLaunchEnvironment(
            bundleID: "com.example.other",
            baseEnvironment: ["FEATURE_FLAG": "1"],
            workspace: workspace.path
        )
        #expect(untouched == ["FEATURE_FLAG": "1"])

        let plan = try planHostAppLaunch(
            selection: iosSimulatorSelection(),
            bundleID: "com.example.camera",
            packageName: nil,
            activity: nil,
            bundle: nil,
            ability: nil,
            payloadURL: nil,
            launchEnvironment: injected,
            adb: "adb",
            hdc: "hdc",
            devicectlArtifacts: nil
        )
        #expect(plan.command.environment["SIMCTL_CHILD_DYLD_INSERT_LIBRARIES"] == hook)
        #expect(plan.command.environment["SIMCTL_CHILD_TRITON_SIM_CAMERA_SOCKET"] == "/tmp/tritonkit-test-camera.sock")
        let source = hostSourceCommand(plan.command)
        #expect(source.contains("SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=<redacted>"))
        #expect(source.contains("SIMCTL_CHILD_TRITON_SIM_CAMERA_SOCKET=<redacted>"))
        #expect(source.contains(hook) == false)
    }

    @Test("camera config rejects missing hook")
    func cameraConfigRejectsMissingHook() throws {
        let workspace = try temporaryWorkspace()

        #expect(throws: Error.self) {
            try enableSimCamera(
                bundleID: "com.example.camera",
                hookPath: workspace.appendingPathComponent("missing.dylib").path,
                socketPath: "/tmp/tritonkit-test-camera.sock",
                workspace: workspace.path
            )
        }
    }

    @Test("camera frame protocol uses fixed 48 byte header and BGRA payload")
    func cameraFrameProtocolShape() throws {
        let frame = try makeSimCameraFrame(width: 2, height: 3, frameIndex: 0, hostTimeNs: 42)

        #expect(frame.header.count == SimCameraFrame.headerByteCount)
        #expect(frame.payload.count == 2 * 3 * 4)
        #expect(readUInt32(frame.header, offset: 0) == SimCameraFrame.magic)
        #expect(readUInt32(frame.header, offset: 4) == SimCameraFrame.protocolVersion)
        #expect(readUInt32(frame.header, offset: 8) == 2)
        #expect(readUInt32(frame.header, offset: 12) == 3)
        #expect(readUInt32(frame.header, offset: 16) == 8)
        #expect(readUInt32(frame.header, offset: 20) == SimCameraFrame.bgraPixelFormat)
        #expect(readUInt64(frame.header, offset: 24) == 42)
        #expect(readUInt32(frame.header, offset: 32) == UInt32(frame.payload.count))
    }

    @Test("camera frame server writes one frame over unix socket")
    func cameraFrameServerWritesFrame() throws {
        let socketPath = "/tmp/triton-camera-test-\(UUID().uuidString).sock"
        defer { try? FileManager.default.removeItem(atPath: socketPath) }
        let clientQueue = DispatchQueue(label: "triton.camera.test.client")
        let clientResult = LockedClientResult()

        clientQueue.asyncAfter(deadline: .now() + 0.2) {
            do {
                let data = try readOneCameraFrame(socketPath: socketPath)
                clientResult.set(.success(data))
            } catch {
                clientResult.set(.failure(error))
            }
        }

        let summary = try runSimCameraFrameServer(options: SimCameraServeOptions(
            socketPath: socketPath,
            width: 4,
            height: 2,
            fps: 30,
            maxFrames: 1,
            once: true,
            jsonl: false
        ))

        let frameData = try clientResult.wait()
        #expect(summary.framesServed == 1)
        #expect(frameData.count == SimCameraFrame.headerByteCount + 4 * 2 * 4)
        #expect(readUInt32(frameData, offset: 0) == SimCameraFrame.magic)
        #expect(readUInt32(frameData, offset: 32) == 4 * 2 * 4)
    }
}

private func iosSimulatorSelection() -> HostDeviceSelectionResult {
    HostDeviceSelectionResult(
        platform: .ios,
        target: HostDeviceTarget(
            platform: "ios",
            id: "sim:SIM-1",
            target: "SIM-1",
            state: "Booted",
            ready: true,
            source: "simctl",
            name: "iPhone 15",
            runtime: "iOS 26.5",
            transport: nil,
            scope: "simulator",
            kind: "simulator",
            rawTarget: "SIM-1"
        ),
        selector: "SIM-1",
        source: .explicit,
        filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "SIM-1", platform: .ios, scope: .simulator))
    )
}

private func temporaryWorkspace() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-camera-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func readUInt32(_ data: Data, offset: Int) -> UInt32 {
    data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { rawBuffer in
        UInt32(littleEndian: rawBuffer.load(as: UInt32.self))
    }
}

private func readUInt64(_ data: Data, offset: Int) -> UInt64 {
    data.subdata(in: offset..<(offset + 8)).withUnsafeBytes { rawBuffer in
        UInt64(littleEndian: rawBuffer.load(as: UInt64.self))
    }
}

private func readOneCameraFrame(socketPath: String) throws -> Data {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    defer { close(fd) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let maxPathLength = MemoryLayout.size(ofValue: addr.sun_path)
    guard socketPath.utf8.count < maxPathLength else {
        throw POSIXError(.ENAMETOOLONG)
    }
    _ = withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { target in
            strncpy(target, socketPath, maxPathLength - 1)
        }
    }
    let connectResult = withUnsafePointer(to: &addr) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            Darwin.connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard connectResult == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    let header = try readExactly(fd: fd, count: SimCameraFrame.headerByteCount)
    let payloadLength = Int(readUInt32(header, offset: 32))
    let payload = try readExactly(fd: fd, count: payloadLength)
    return header + payload
}

private func readExactly(fd: Int32, count: Int) throws -> Data {
    var data = Data(count: count)
    try data.withUnsafeMutableBytes { rawBuffer in
        guard var pointer = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
            return
        }
        var remaining = count
        while remaining > 0 {
            let readCount = Darwin.read(fd, pointer, remaining)
            if readCount <= 0 {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            pointer = pointer.advanced(by: readCount)
            remaining -= readCount
        }
    }
    return data
}

private final class LockedClientResult: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Data, Error>?

    func set(_ value: Result<Data, Error>) {
        lock.lock()
        result = value
        lock.unlock()
    }

    func wait() throws -> Data {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            lock.lock()
            let current = result
            lock.unlock()
            if let current {
                return try current.get()
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        throw POSIXError(.ETIMEDOUT)
    }
}
