import Foundation
import Testing
@testable import TritonKitShared

@Suite("Android legacy input text shell contract")
struct TKAndroidInputTextTests {
    @Test func fakeADBReceivesQuotedPayloadAsOneArgvElement() throws {
        let value = "# ~ a'b\\c 你好\nnext"
        let command = TKAndroidADBCommand.inputText(serial: "fixture", text: value)
        let fakeADB = Process()
        fakeADB.executableURL = URL(fileURLWithPath: "/bin/sh")
        fakeADB.arguments = ["-c", "printf '%s\\0' \"$@\"", "fake-adb"] + command.arguments
        let pipe = Pipe(); fakeADB.standardOutput = pipe
        try fakeADB.run()
        let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
        fakeADB.waitUntilExit()
        #expect(fakeADB.terminationStatus == 0)
        #expect(String(decoding: bytes, as: UTF8.self).split(separator: "\0", omittingEmptySubsequences: false).dropLast().map(String.init) == command.arguments)
    }
    @Test func remoteShellPreservesLiteralArgument() throws {
        for value in ["#comment", "~", "hello world", "a'b\"c\\d", "你好 🌏", "line1\nline2", "$(printf injected); & | > *", ""] {
            let command = TKAndroidADBCommand.inputText(serial: "fixture", text: value)
            #expect(command.arguments == ["-s", "fixture", "shell", "input", "text", "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"])
            #expect(command.redactedArgumentIndexes.contains(5))
            // Model adb's documented argv joining; execute only a local printf fixture.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", "set -- " + command.arguments.dropFirst(5).joined(separator: " ") + "; [ \"$#\" -eq 1 ] || exit 9; printf '%s' \"$1\""]
            let pipe = Pipe(); process.standardOutput = pipe
            try process.run()
            let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
            #expect(String(data: bytes, encoding: .utf8) == value)
        }
    }
}
