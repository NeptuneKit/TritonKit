import Foundation
import ImageIO
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Android Framebuffer Service

final class CLIAndroidFramebufferService: @unchecked Sendable {
    static let shared = CLIAndroidFramebufferService()

    private let lock = NSLock()
    private var activeSessions = [String: AndroidSession]()
    private var sessionRefCount = [String: Int]()

    private init() {}

    func startStreaming(serial: String, adbPath: String = "adb") -> Bool {
        lock.lock()
        sessionRefCount[serial, default: 0] += 1
        if activeSessions[serial] != nil {
            lock.unlock()
            return true // Already streaming
        }

        let session = AndroidSession(serial: serial, adbPath: adbPath)
        session.start()
        activeSessions[serial] = session
        lock.unlock()
        return true
    }

    func stopStreaming(serial: String) {
        lock.lock()
        if let count = sessionRefCount[serial] {
            let newCount = count - 1
            sessionRefCount[serial] = newCount
            if newCount > 0 {
                lock.unlock()
                return // Still has other active clients
            }
        }
        sessionRefCount.removeValue(forKey: serial)
        let session = activeSessions.removeValue(forKey: serial)
        lock.unlock()

        session?.stop()
    }

    func getLatestFrameWithVersion(serial: String) -> (Data, UInt64)? {
        lock.lock()
        let session = activeSessions[serial]
        lock.unlock()
        return session?.getLatestFrameWithVersion()
    }
}

// MARK: - Android Session Implementation

final class AndroidSession: @unchecked Sendable {
    let serial: String
    let adbPath: String
    private let captureTimeout: TimeInterval
    var running: Bool { lock.lock(); defer { lock.unlock() }; return isRunning }

    private let lock = NSLock()
    private var latestJPEGData = Data()
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
               let jpegData = convertPNGToJPEG(pngData: result.stdout) {
                lock.lock()
                if isRunning, jpegData != latestJPEGData {
                    latestJPEGData = jpegData
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

    private func convertPNGToJPEG(pngData: Data) -> Data? {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        guard let imageSource = CGImageSourceCreateWithData(pngData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(outputData as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.6
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        if CGImageDestinationFinalize(destination) {
            return outputData as Data
        }
        #endif
        return nil
    }
}

// MARK: - Harmony Framebuffer Service

final class CLIHarmonyFramebufferService: @unchecked Sendable {
    static let shared = CLIHarmonyFramebufferService()

    private let lock = NSLock()
    private var activeSessions = [String: HarmonySession]()
    private var sessionRefCount = [String: Int]()

    private init() {}

    func startStreaming(target: String, hdcPath: String = "hdc") -> Bool {
        lock.lock()
        sessionRefCount[target, default: 0] += 1
        if activeSessions[target] != nil {
            lock.unlock()
            return true // Already streaming
        }

        let session = HarmonySession(target: target, hdcPath: hdcPath)
        session.start()
        activeSessions[target] = session
        lock.unlock()
        return true
    }

    func stopStreaming(target: String) {
        lock.lock()
        if let count = sessionRefCount[target] {
            let newCount = count - 1
            sessionRefCount[target] = newCount
            if newCount > 0 {
                lock.unlock()
                return // Still has other active clients
            }
        }
        sessionRefCount.removeValue(forKey: target)
        let session = activeSessions.removeValue(forKey: target)
        lock.unlock()

        session?.stop()
    }

    func getLatestFrameWithVersion(target: String) -> (Data, UInt64)? {
        lock.lock()
        let session = activeSessions[target]
        lock.unlock()
        return session?.getLatestFrameWithVersion()
    }
}

// MARK: - Harmony Session Implementation

final class HarmonySession: @unchecked Sendable {
    let target: String
    let hdcPath: String

    private let lock = NSLock()
    private var latestJPEGData = Data()
    private var latestFrameVersion: UInt64 = 0
    private var isRunning = false
    private var isStopped = false
    private var thread: Thread?
    private let captureProcess = FramebufferCaptureProcess()

    init(target: String, hdcPath: String) {
        self.target = target
        self.hdcPath = hdcPath
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

            guard let snapshot = captureProcess.run(executable: executable, arguments: prefix + ["shell", "snapshot_display", "-f", remotePath]) else { break }
            if snapshot.exitStatus == 0 {
                guard let received = captureProcess.run(executable: executable, arguments: prefix + ["file", "recv", remotePath, localURL.path]) else { break }
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
