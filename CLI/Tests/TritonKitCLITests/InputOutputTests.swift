import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct InputOutputTests {
    @Test("root command exposes P23 act workflow group before raw engine fallbacks")
    func rootCommandExposesP23ActWorkflowGroup() throws {
        #expect(TritonKitCLI.configuration.subcommands.contains { $0 == Act.self })
        #expect(Act.configuration.commandName == "act")
        #expect(Act.configuration.subcommands.contains { $0 == Tap.self })
        #expect(Act.configuration.subcommands.contains { $0 == SetText.self })
    }

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

    @Test("failed input result emits one JSON object and preserves runtime error")
    func failedInputResultEmitsOneJSONAndPreservesRuntimeError() throws {
        let result = TKInputResult.unsupported(
            action: "tap",
            message: "Visible primary-menu items require host HID activation",
            strategy: "button-primary-menu-item-unsupported",
            error: TKCLIErrorDetail(
                code: "unsupported_capability",
                message: "Visible primary-menu items require host HID activation"
            )
        )

        #expect(throws: ExitCode.self) {
            try requireInputResultSuccess(result)
        }
        let output = try encodeCompactJSON(result)
        let lines = output.split(whereSeparator: { $0.isNewline })
        #expect(lines.count == 1)
        let decoded = try JSONDecoder().decode(TKInputResult.self, from: Data(lines[0].utf8))
        #expect(decoded.error?.code == "unsupported_capability")
        #expect(decoded.strategy == "button-primary-menu-item-unsupported")
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
