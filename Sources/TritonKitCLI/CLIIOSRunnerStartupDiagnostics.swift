import Foundation
import Darwin

/// Fixed, public stage facts. Native logs and transport error strings never enter
/// the response. Verified stages describe this start attempt, not current health.
struct IOSRunnerStartupDiagnostics {
    var launchVerified = false
    var transportVerified = false
    var healthVerified = false
    var json: [String: String] {
        ["launch": launchVerified ? "verified" : "unverified",
         "transport": transportVerified ? "verified" : "unverified",
         "health": healthVerified ? "verified" : "unverified",
         "uiAutomation": "unverified"]
    }
    func failure(driverChannelRefused: Bool, nativeExited: Bool) -> IOSRunnerFailure {
        if driverChannelRefused {
            return IOSRunnerFailure("ios_runner_xctest_driver_channel_refused",
                "Native XCTest refused its driver channel before Runner health was verified. Review pairing, UI Automation authorization and Xcode/device XCTest compatibility using the private native logs; unlocking alone is not a proven remedy. Stop/recover this session before starting a fresh one.", startup: self)
        }
        if nativeExited {
            return IOSRunnerFailure("ios_runner_native_exited",
                "Native XCTest process exited before UI automation readiness was verified. Inspect private native logs and verify Xcode/device XCTest setup before preparing a fresh session.", startup: self)
        }
        let stage = healthVerified ? "UI automation probe" : (transportVerified ? "authenticated health response" : "authenticated Runner transport")
        return IOSRunnerFailure("ios_runner_start_not_ready",
            "Runner did not verify its \(stage) within the readiness budget. Review the reported startup stages and private native logs; verify device unlock, authorization and XCTest setup, then recover or stop this session before starting another.", startup: self)
    }
}

/// Only inspect a bounded tail of each owned regular file. O_NONBLOCK prevents a
/// replaced FIFO from stalling startup; O_NOFOLLOW refuses a substituted symlink.
/// Logs can change while read. Absence of this signature is not a root-cause claim.
func iosRunnerDriverChannelRefused(directory: URL) -> Bool {
    let maximumBytes = 128 * 1024
    for name in ["native.stderr", "native.stdout"] {
        let fd = open(directory.appendingPathComponent(name).path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { continue }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), (info.st_mode & S_IFMT) == S_IFREG, info.st_size >= 0 else { continue }
        do {
            try handle.seek(toOffset: UInt64(max(0, info.st_size - Int64(maximumBytes))))
            let data = try handle.read(upToCount: maximumBytes) ?? Data()
            let found = String(decoding: data, as: UTF8.self).split(separator: "\n").contains { line in
                let line = line.lowercased()
                return line.contains("connection peer refused channel request") && line.contains("dtxproxy:xctestdriverinterface:xctestmanager_ideinterface")
            }
            if found { return true }
        } catch { continue }
    }
    return false
}
