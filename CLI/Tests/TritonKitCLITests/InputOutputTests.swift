import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct InputOutputTests {
    @Test("exact tap request preserves matched metadata and exact strategy")
    func exactTapRequestPreservesMatchedMetadataAndStrategy() {
        let node = TKAXNode(
            role: "text",
            label: "查看不合适原因",
            value: nil,
            identifier: nil,
            title: nil,
            frame: TKRect(x: 24, y: 100, width: 240, height: 56),
            enabled: true,
            focused: false,
            hidden: false,
            targetOID: 42,
            className: "UILabel",
            children: []
        )

        let request = tapRequest(for: node, width: 390, height: 844, duration: 0.05, activationStrategy: .exact)

        #expect(request.activationStrategy == .exact)
        #expect(request.matchedOID == 42)
        #expect(request.matchedClassName == "UILabel")
        #expect(request.x != nil)
        #expect(request.y != nil)
    }

    @Test("input result text output includes matched activation and strategy")
    func inputResultTextOutputIncludesMatchedActivationAndStrategy() throws {
        let result = TKInputResult.success(
            action: "tap",
            message: "Dispatched UIControl.touchUpInside",
            targetOID: 11,
            targetClassName: "UIControl",
            matchedOID: 7,
            matchedClassName: "UILabel",
            activationOID: 11,
            activationClassName: "UIControl",
            strategy: "ancestor-control-action"
        )

        let output = try captureStandardOutput {
            try printInputResult(result, format: .text)
        }

        #expect(output.contains("targetOID: 11"))
        #expect(output.contains("matchedOID: 7"))
        #expect(output.contains("matchedClassName: UILabel"))
        #expect(output.contains("activationOID: 11"))
        #expect(output.contains("activationClassName: UIControl"))
        #expect(output.contains("strategy: ancestor-control-action"))
    }

    private func captureStandardOutput(_ body: () throws -> Void) throws -> String {
        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)

        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        do {
            try body()
        } catch {
            fflush(stdout)
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            pipe.fileHandleForWriting.closeFile()
            throw error
        }
        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}
