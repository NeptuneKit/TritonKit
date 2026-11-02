import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct HarmonyWaitRoleTests {
    private let target = TKHarmonyTarget(target: "role-fixture", state: "Connected", transport: "USB")
    private let layout = Data(#"{"attributes":{"type":"Column","bounds":"[0,0][200,500]"},"children":[{"attributes":{"type":"Text","text":"Shared","bounds":"[0,0][200,20]"}},{"attributes":{"type":"Button","text":"Shared","bounds":"[0,40][200,60]"}},{"attributes":{"type":"Text","text":"Item0","bounds":"[0,80][200,100]","clickable":"true"}},{"attributes":{"text":"NoType","bounds":"[0,120][200,140]"}},{"attributes":{"type":"Button","text":"NoBounds"}}]}"#.utf8)

    @Test("Role and text must belong to the same native ArkUI node")
    func sameNodeRoleMatch() throws {
        let match = try #require(try harmonyWaitTextMatch(in: layout, text: "Shared", role: " button "))
        #expect(match.bounds.y == 40)
        #expect(try harmonyWaitTextMatch(in: layout, text: "Item0", role: "Button") == nil)
        #expect(try harmonyWaitTextMatch(in: layout, text: "Absent", role: "Button") == nil)
    }

    @Test("Role comparison is case-insensitive exact native type, not a broad semantic alias")
    func exactNativeType() throws {
        #expect(try harmonyWaitTextMatch(in: layout, text: "Item0", role: "TeXT") != nil)
        #expect(try harmonyWaitTextMatch(in: layout, text: "Item0", role: "AXStaticText") == nil)
        #expect(try harmonyWaitTextMatch(in: layout, text: "NoType", role: "Button") == nil)
        #expect(try harmonyWaitTextMatch(in: layout, text: "NoBounds", role: "Button") == nil)
    }

    @Test("Omitting role preserves the previous exact-text selection")
    func absentRoleCompatibility() throws {
        #expect(try harmonyWaitTextMatch(in: layout, text: "Shared", role: nil)?.bounds.y == 0)
        #expect(try harmonyWaitTextMatch(in: layout, text: "NoType", role: nil) != nil)
        #expect(try harmonyWaitTextMatch(in: layout, text: "Item", role: nil) == nil)
    }

    @Test("Harmony wait applies role during each captured layout")
    func waitRolePositiveAndNegative() async throws {
        for (text, role, gone, expected) in [
            ("Shared", "BUTTON", false, true),
            ("Item0", "text", false, true),
            ("Item0", "button", false, false),
            ("Absent", "button", false, false),
            ("Shared", "button", true, false),
            ("Item0", "button", true, true),
            ("Absent", "button", true, true),
        ] {
            let result = try await waitForHarmonyText(
                selected: target,
                hdc: "fixture-only",
                text: text,
                role: role,
                timeout: 0.6,
                interval: 0.001,
                gone: gone,
                captureLayout: { _, _, _, _ in
                    HarmonyLayoutCapture(localPath: "synthetic", remotePath: "synthetic", sourceCommands: [], data: layout)
                }
            )
            #expect(result.matched == expected)
            #expect(result.ok == expected)
            #expect(result.timedOut == !expected)
            #expect(result.pollCount > 0)
        }
    }
    @Test("Empty role is invalid, never evidence that a node is gone")
    func emptyRoleRejectsBeforeLayoutCapture() async throws {
        for role in ["", "   ", "\t\n"] {
            #expect(throws: HarmonyWaitRoleValidationError.self) {
                try harmonyWaitTextMatch(in: layout, text: "Item0", role: role)
            }
            for gone in [false, true] {
                var captures = 0
                do {
                    _ = try await waitForHarmonyText(
                        selected: target, hdc: "fixture-only", text: "Item0", role: role,
                        timeout: 0.6, interval: 0.001, gone: gone,
                        captureLayout: { _, _, _, _ in
                            captures += 1
                            return HarmonyLayoutCapture(localPath: "synthetic", remotePath: "synthetic", sourceCommands: [], data: layout)
                        }
                    )
                    Issue.record("Empty role must throw before capture")
                } catch {
                    #expect(error is HarmonyWaitRoleValidationError)
                }
                #expect(captures == 0)
            }
        }
    }

    @Test("All Harmony text selectors reject empty role with one validation envelope and zero backend calls")
    func emptyRoleCommandValidation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sp267-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let hdc = root.appendingPathComponent("hdc")
        let calls = root.appendingPathComponent("calls")
        try "#!/bin/sh\nprintf called >> '\(calls.path)'\nexit 9\n".write(to: hdc, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hdc.path)
        for selector in ["--text", "--exists", "--gone"] {
            for role in ["", "   ", "\t\n"] {
                let command = try Wait.parse(["--platform", "harmony", "--device", "role-fixture", "--hdc", hdc.path, selector, "Item0", "--role", role, "--json"])
                let pipe = Pipe()
                let original = dup(STDOUT_FILENO)
                fflush(stdout)
                dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
                var failure: Error?
                do { try await command.run() } catch { failure = error }
                fflush(stdout)
                dup2(original, STDOUT_FILENO)
                close(original)
                try pipe.fileHandleForWriting.close()
                let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: pipe.fileHandleForReading.readDataToEndOfFile())
                #expect(failure is ExitCode)
                #expect(response.error.code == "validation_failed")
                #expect(!FileManager.default.fileExists(atPath: calls.path))
            }
        }
    }

}
