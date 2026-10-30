import Foundation

// MARK: - Android Framebuffer Service

final class CLIAndroidFramebufferService: @unchecked Sendable {
    static let shared = CLIAndroidFramebufferService()

    private let streams = FramebufferStreamRegistry()

    func subscribe(serial: String, adbPath: String = "adb") -> FramebufferStreamSubscription {
        streams.subscribe(target: serial) {
            AndroidSession(serial: serial, adbPath: adbPath)
        }
    }
}

// MARK: - Android Session Implementation

final class AndroidSession: FramebufferCaptureSession, @unchecked Sendable {
    let serial: String
    let adbPath: String
    private let captureTimeout: TimeInterval
    var running: Bool { lock.lock(); defer { lock.unlock() }; return isRunning }
    var imageFormat: FramebufferImageFormat { .png }

    private let lock = NSLock()
    private var latestFrameData = Data()
    private var latestFrameVersion: UInt64 = 0
    private var isRunning = false
    private var isStopped = false
    private var thread: Thread?
    private let captureProcess = FramebufferCaptureProcess()

    init(serial: String, adbPath: String, captureTimeout: TimeInterval = 5) {
        self.serial = serial
        self.adbPath = adbPath
        self.captureTimeout = captureTimeout
    }

    func start() {
        lock.lock()
        guard !isRunning, !isStopped else {
            lock.unlock()
            return
        }
        isRunning = true
        lock.unlock()

        thread = Thread { [weak self] in
            self?.runLoop()
        }
        thread?.name = "com.neptunekit.tritonkit.android-framebuffer-\(serial)"
        thread?.start()
    }

    func stop() {
        lock.lock()
        isRunning = false
        isStopped = true
        latestFrameData = Data()
        lock.unlock()
        captureProcess.cancel()
    }

    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        lock.lock()
        defer { lock.unlock() }
        guard !latestFrameData.isEmpty else { return nil }
        return (latestFrameData, latestFrameVersion)
    }

    private func runLoop() {
        defer { stop() }
        var lastSuccessTime = Date().timeIntervalSince1970

        while true {
            lock.lock()
            let shouldRun = isRunning
            lock.unlock()
            guard shouldRun else { break }

            let startTime = Date().timeIntervalSince1970

            let executable = adbPath.hasPrefix("/") ? adbPath : "/usr/bin/env"
            let arguments = (adbPath.hasPrefix("/") ? [] : [adbPath]) + ["-s", serial, "exec-out", "screencap", "-p"]
            guard let result = captureProcess.run(executable: executable, arguments: arguments, timeout: captureTimeout) else { break }
            if result.exitStatus == 0,
               let pngData = validatedAndroidFramebufferPNG(result.stdout) {
                lock.lock()
                if isRunning, pngData != latestFrameData {
                    latestFrameData = pngData
                    latestFrameVersion += 1
                    lastSuccessTime = Date().timeIntervalSince1970
                }
                lock.unlock()
            }

            let elapsed = Date().timeIntervalSince1970 - startTime

            // Frame rate control: limit to max 30 FPS (~33ms per frame)
            // If screen is static, drop down to 2.5 FPS (~400ms delay) to preserve CPU/battery
            let isStatic = (Date().timeIntervalSince1970 - lastSuccessTime) > 1.5
            let targetDelay = isStatic ? 0.4 : 0.033
            let sleepTime = max(0.005, targetDelay - elapsed)

            Thread.sleep(forTimeInterval: sleepTime)
        }
    }

}

// MARK: - Harmony Framebuffer Service

final class CLIHarmonyFramebufferService: @unchecked Sendable {
    static let shared = CLIHarmonyFramebufferService()

    private let streams = FramebufferStreamRegistry()

    func subscribe(target: String, hdcPath: String = "hdc") -> FramebufferStreamSubscription {
        streams.subscribe(target: target) {
            HarmonySession(target: target, hdcPath: hdcPath)
        }
    }
}

// MARK: - Harmony Session Implementation

final class HarmonySession: FramebufferCaptureSession, @unchecked Sendable {
    let target: String
    let hdcPath: String
    private let captureTimeout: TimeInterval
    var running: Bool { lock.lock(); defer { lock.unlock() }; return isRunning }

    private let lock = NSLock()
    private var latestJPEGData = Data()
    private var latestFrameVersion: UInt64 = 0
    private var isRunning = false
    private var isStopped = false
    private var thread: Thread?
    private let captureProcess = FramebufferCaptureProcess()

    // Harmony snapshot and transfer can exceed five seconds under host load.
    // Bound each stage independently; cancellation still stops the owned helper immediately.
    init(target: String, hdcPath: String, captureTimeout: TimeInterval = 15) {
        self.target = target
        self.hdcPath = hdcPath
        self.captureTimeout = captureTimeout
    }

    func start() {
        lock.lock()
        guard !isRunning, !isStopped else {
            lock.unlock()
            return
        }
        isRunning = true
        lock.unlock()

        thread = Thread { [weak self] in
            self?.runLoop()
        }
        thread?.name = "com.neptunekit.tritonkit.harmony-framebuffer-\(target)"
        thread?.start()
    }

    func stop() {
        lock.lock()
        isRunning = false
        isStopped = true
        latestJPEGData = Data()
        lock.unlock()
        captureProcess.cancel()
    }

    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        lock.lock()
        defer { lock.unlock() }
        guard !latestJPEGData.isEmpty else { return nil }
        return (latestJPEGData, latestFrameVersion)
    }

    private func runLoop() {
        defer { stop() }
        let sessionID = UUID().uuidString
        let remotePath = "/data/local/tmp/triton-stream-\(sessionID).jpeg"
        let localDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("triton-harmony-\(sessionID)", isDirectory: true)
        let localURL = localDirectory.appendingPathComponent("frame.jpeg")
        guard (try? FileManager.default.createDirectory(at: localDirectory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])) != nil else { return }
        let executable = hdcPath.hasPrefix("/") ? hdcPath : "/usr/bin/env"
        let prefix = (hdcPath.hasPrefix("/") ? [] : [hdcPath]) + ["-t", target]
        defer {
            // A separate bounded cleanup can run after capture cancellation.
            _ = FramebufferCaptureProcess().run(executable: executable, arguments: prefix + ["shell", "rm", "-f", remotePath], timeout: 2, maximumOutputBytes: 65536)
            try? FileManager.default.removeItem(at: localDirectory)
        }
        var lastSuccessTime = Date().timeIntervalSince1970

        while true {
            lock.lock()
            let shouldRun = isRunning
            lock.unlock()
            guard shouldRun else { break }

            let startTime = Date().timeIntervalSince1970

            guard let snapshot = captureProcess.run(executable: executable, arguments: prefix + ["shell", "snapshot_display", "-f", remotePath], timeout: captureTimeout) else { break }
            if snapshot.exitStatus == 0 {
                guard let received = captureProcess.run(executable: executable, arguments: prefix + ["file", "recv", remotePath, localURL.path], timeout: captureTimeout) else { break }
                if received.exitStatus == 0,
                   let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
                   attributes[.type] as? FileAttributeType == .typeRegular,
                   let size = attributes[.size] as? NSNumber, size.intValue > 0, size.intValue <= 16 * 1024 * 1024,
                   let localData = try? Data(contentsOf: localURL), !localData.isEmpty {
                    lock.lock()
                    if isRunning, localData != latestJPEGData {
                        latestJPEGData = localData
                        latestFrameVersion += 1
                        lastSuccessTime = Date().timeIntervalSince1970
                    }
                    lock.unlock()
                }
            }

            let elapsed = Date().timeIntervalSince1970 - startTime

            // Harmony loop has higher overhead (~100-150ms), so we cap target delay to 10 FPS (~100ms)
            // If screen is static, drop down to 2 FPS (~500ms delay) to preserve CPU/battery
            let isStatic = (Date().timeIntervalSince1970 - lastSuccessTime) > 1.5
            let targetDelay = isStatic ? 0.5 : 0.1
            let sleepTime = max(0.01, targetDelay - elapsed)

            Thread.sleep(forTimeInterval: sleepTime)
        }
    }
}
