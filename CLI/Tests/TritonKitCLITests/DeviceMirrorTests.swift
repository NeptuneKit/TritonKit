import ArgumentParser
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Terminal device mirror")
struct DeviceMirrorTests {
    @Test("Parser exposes bounded interactive and frame capture modes")
    func parser() throws {
        let command = try DeviceMirror.parse(["--platform", "android", "--device", "android:fixture", "--frames", "2", "--output", "/fixture/frames", "--fps", "2", "--timeout", "10"])
        #expect(command.frames == 2)
        #expect(command.fps == 2)
        #expect(throws: (any Error).self) { _ = try DeviceMirror.parse(["--platform", "android", "--device", "fixture", "--fps", "20"]) }
        #expect(throws: (any Error).self) { _ = try DeviceMirror.parse(["--platform", "android", "--device", "fixture", "--frames", "2"]) }
    }
    @Test("Unsupported terminal has an explicit image file alternative")
    func terminalDetection() {
        #expect(DeviceMirrorProtocol.detect(environment: ["TERM_PROGRAM": "ghostty"]) == .kitty)
        #expect(DeviceMirrorProtocol.detect(environment: ["TERM": "xterm-kitty"]) == .kitty)
        #expect(DeviceMirrorProtocol.detect(environment: ["TERM_PROGRAM": "iTerm.app"]) == .iterm2)
        #expect(DeviceMirrorProtocol.detect(environment: ["TERM": "xterm-256color"]) == nil)
    }
    @Test("Kitty PNG is chunked and last chunk terminates without a continuation flag")
    func imageProtocol() throws {
        let bytes = Data(repeating: 17, count: 7000)
        let encoded = deviceMirrorRenderPNG(bytes, protocolKind: .kitty, columns: 20, rows: 30)
        #expect(encoded.contains("a=T,f=100,t=d,i=31,c=20,r=30,q=2,m=1;"))
        #expect(encoded.contains("\u{1b}_Gm=0;"))
        let bodies = encoded.components(separatedBy: "\u{1b}_G").dropFirst().compactMap { $0.split(separator: ";", maxSplits: 1).last?.components(separatedBy: "\u{1b}\\").first }
        #expect(Data(base64Encoded: bodies.joined()) == bytes)
    }
    @Test("Terminal geometry maps the rendered area to source pixels and rejects the footer")
    func geometry() {
        let layout = DeviceMirrorLayout(sourceWidth: 1080, sourceHeight: 1920, terminalColumns: 80, terminalRows: 30, cellWidth: 8, cellHeight: 16)
        #expect(layout.rows <= 28)
        #expect(layout.columns <= 80)
        #expect(layout.point(column: 1, row: 1)?.x == 0)
        #expect(layout.point(column: layout.columns + 1, row: 1) == nil)
        #expect(layout.point(column: 1, row: layout.rows + 1) == nil)
        let last = layout.point(column: layout.columns, row: layout.rows)
        #expect((last?.x ?? 1080) < 1080)
        #expect((last?.y ?? 1920) < 1920)
    }
    @Test("Incremental mouse and text decoder handles split packets and control actions")
    func decoder() {
        var decoder = DeviceMirrorInputDecoder()
        #expect(decoder.feed(Data("\u{1b}[<0;12;".utf8)).isEmpty)
        #expect(decoder.feed(Data("7M".utf8)) == [.click(column: 12, row: 7)])
        #expect(decoder.feed(Data([8, 2, 1, 3])) == [.press("home"), .press("back"), .press("app-switch"), .quit])
        let text = Array("好".utf8)
        #expect(decoder.feed(Data(text.prefix(1))).isEmpty)
        #expect(decoder.feed(Data(text.dropFirst())) == [.text("好")])
        #expect(decoder.feed(Data("\u{1b}[<0;12;7m".utf8)).isEmpty)
    }
    @Test("Display strings cannot inject terminal control sequences")
    func displaySafety() {
        #expect(deviceMirrorSafeText("a\u{1b}[31m\nsecret\u{7}") == "a[31msecret")
        #expect(!deviceMirrorTerminalCleanup.contains("\u{1b}[?1006h"))
        #expect(deviceMirrorTerminalCleanup.contains("\u{1b}[?1006l"))
        #expect(deviceMirrorTerminalCleanup.contains("\u{1b}[?25h"))
        #expect(deviceMirrorTerminalCleanup.contains("\u{1b}[?1049l"))
    }
    @Test("Mirror child commands preserve untrusted values as argv")
    func argv() throws {
        let command = try DeviceMirror.parse(["--platform", "android", "--device", "android:fixture;$(touch /untrusted)"])
        let arguments = deviceMirrorScreenshotArguments(command, output: "/fixture/a b.png")
        #expect(arguments.contains(command.device))
        #expect(arguments.contains("/fixture/a b.png"))
        #expect(!arguments.contains("sh"))
    }
}
