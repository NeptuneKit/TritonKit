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

    private let lock = NSLock()
    private var latestJPEGData = Data()
    private var latestFrameVersion: UInt64 = 0
    private var isRunning = false
    private var thread: Thread?

    init(serial: String, adbPath: String) {
        self.serial = serial
        self.adbPath = adbPath
    }

    func start() {
        lock.lock()
        guard !isRunning else {
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
        lock.unlock()
    }

    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        lock.lock()
        defer { lock.unlock() }
        guard !latestJPEGData.isEmpty else { return nil }
        return (latestJPEGData, latestFrameVersion)
    }

    private func runLoop() {
        var lastSuccessTime = Date().timeIntervalSince1970

        while true {
            lock.lock()
            let shouldRun = isRunning
            lock.unlock()
            guard shouldRun else { break }

            let startTime = Date().timeIntervalSince1970

            let process = Process()
            process.executableURL = URL(fileURLWithPath: adbPath.hasPrefix("/") ? adbPath : "/usr/bin/env")
            if !adbPath.hasPrefix("/") {
                process.arguments = [adbPath, "-s", serial, "exec-out", "screencap", "-p"]
            } else {
                process.arguments = ["-s", serial, "exec-out", "screencap", "-p"]
            }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                let stdoutData = try pipe.fileHandleForReading.readToEnd() ?? Data()
                process.waitUntilExit()

                if process.terminationStatus == 0 && !stdoutData.isEmpty {
                    if let jpegData = convertPNGToJPEG(pngData: stdoutData) {
                        lock.lock()
                        if jpegData != latestJPEGData {
                            latestJPEGData = jpegData
                            latestFrameVersion += 1
                            lastSuccessTime = Date().timeIntervalSince1970
                        }
                        lock.unlock()
                    }
                }
            } catch {
                // Ignore loop execution errors
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
    private var thread: Thread?

    init(target: String, hdcPath: String) {
        self.target = target
        self.hdcPath = hdcPath
    }

    func start() {
        lock.lock()
        guard !isRunning else {
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
        lock.unlock()

        // Cleanup remote and local temp files
        let remotePath = "/data/local/tmp/triton-stream.jpeg"
        let localTempPath = NSTemporaryDirectory() + "triton-harmony-\(target).jpeg"

        let deleteProcess = Process()
        deleteProcess.executableURL = URL(fileURLWithPath: hdcPath.hasPrefix("/") ? hdcPath : "/usr/bin/env")
        if !hdcPath.hasPrefix("/") {
            deleteProcess.arguments = [hdcPath, "-t", target, "shell", "rm", "-f", remotePath]
        } else {
            deleteProcess.arguments = ["-t", target, "shell", "rm", "-f", remotePath]
        }
        try? deleteProcess.run()
        try? FileManager.default.removeItem(atPath: localTempPath)
    }

    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        lock.lock()
        defer { lock.unlock() }
        guard !latestJPEGData.isEmpty else { return nil }
        return (latestJPEGData, latestFrameVersion)
    }

    private func runLoop() {
        let remotePath = "/data/local/tmp/triton-stream.jpeg"
        let localTempPath = NSTemporaryDirectory() + "triton-harmony-\(target).jpeg"
        var lastSuccessTime = Date().timeIntervalSince1970

        while true {
            lock.lock()
            let shouldRun = isRunning
            lock.unlock()
            guard shouldRun else { break }

            let startTime = Date().timeIntervalSince1970

            // 1. Run snapshot_display
            let snapProcess = Process()
            snapProcess.executableURL = URL(fileURLWithPath: hdcPath.hasPrefix("/") ? hdcPath : "/usr/bin/env")
            if !hdcPath.hasPrefix("/") {
                snapProcess.arguments = [hdcPath, "-t", target, "shell", "snapshot_display", "-f", remotePath]
            } else {
                snapProcess.arguments = ["-t", target, "shell", "snapshot_display", "-f", remotePath]
            }
            snapProcess.standardOutput = Pipe()
            snapProcess.standardError = Pipe()

            var snapSuccess = false
            do {
                try snapProcess.run()
                snapProcess.waitUntilExit()
                if snapProcess.terminationStatus == 0 {
                    snapSuccess = true
                }
            } catch {}

            if snapSuccess {
                // 2. Run hdc file recv
                let recvProcess = Process()
                recvProcess.executableURL = URL(fileURLWithPath: hdcPath.hasPrefix("/") ? hdcPath : "/usr/bin/env")
                if !hdcPath.hasPrefix("/") {
                    recvProcess.arguments = [hdcPath, "-t", target, "file", "recv", remotePath, localTempPath]
                } else {
                    recvProcess.arguments = ["-t", target, "file", "recv", remotePath, localTempPath]
                }
                recvProcess.standardOutput = Pipe()
                recvProcess.standardError = Pipe()

                do {
                    try recvProcess.run()
                    recvProcess.waitUntilExit()
                    if recvProcess.terminationStatus == 0 {
                        if let localData = try? Data(contentsOf: URL(fileURLWithPath: localTempPath)), !localData.isEmpty {
                            lock.lock()
                            if localData != latestJPEGData {
                                latestJPEGData = localData
                                latestFrameVersion += 1
                                lastSuccessTime = Date().timeIntervalSince1970
                            }
                            lock.unlock()
                        }
                    }
                } catch {}
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
