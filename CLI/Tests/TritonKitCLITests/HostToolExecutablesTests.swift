import Foundation
import Testing
@testable import TritonKitCLI

struct HostToolExecutablesTests {
    @Test func preservesSDKBeforePATHResolutionAndBareNameFallback() {
        let environment = ["HOME": "/fixture/home", "PATH": "/fixture/first:/fixture/second"]
        #expect(findAdbExecutable(environment: environment, fileExists: { _ in true }) == "/fixture/home/Library/Android/sdk/platform-tools/adb")
        #expect(findHdcExecutable(environment: environment, fileExists: { _ in true }) == "/fixture/home/harmonyOS-command-line-tools/bin/hdc")
        #expect(findHdcExecutable(environment: environment, fileExists: { $0.contains("openharmony/") }) == "/fixture/home/Library/Huawei/Sdk/openharmony/12/toolchains/hdc")
        #expect(findHdcExecutable(environment: environment, fileExists: { $0.contains("openharmony/11/") }) == "/fixture/home/Library/Huawei/Sdk/openharmony/11/toolchains/hdc")
        #expect(findAdbExecutable(environment: environment, fileExists: { $0 == "/fixture/second/adb" }) == "/fixture/second/adb")
        #expect(findHdcExecutable(environment: environment, fileExists: { $0 == "/fixture/first/hdc" }) == "/fixture/first/hdc")
        #expect(findAdbExecutable(environment: environment, fileExists: { _ in false }) == "adb")
        #expect(findHdcExecutable(environment: environment, fileExists: { _ in false }) == "hdc")
        #expect(findAdbExecutable(environment: [:], fileExists: { _ in true }) == "adb")
        #expect(findHdcExecutable(environment: ["HOME": "", "PATH": ""], fileExists: { _ in true }) == "hdc")
    }

    @Test func invalidSDKEntriesFallBackToExecutablePATHEntries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-tools-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let android = directory.appendingPathComponent("Library/Android/sdk/platform-tools/adb")
        let harmony = directory.appendingPathComponent("harmonyOS-command-line-tools/bin/hdc")
        let bin = directory.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: android.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "not executable".write(to: android, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: android.path)
        try FileManager.default.createDirectory(at: harmony, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        for name in ["adb", "hdc"] {
            let file = bin.appendingPathComponent(name)
            try "#!/bin/sh\nexit 0\n".write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        }
        let environment = ["HOME": directory.path, "PATH": bin.path]
        #expect(findAdbExecutable(environment: environment) == bin.appendingPathComponent("adb").path)
        #expect(findHdcExecutable(environment: environment) == bin.appendingPathComponent("hdc").path)
    }
}
