import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Device Hub HID boundaries", .serialized)
struct DeviceHubHIDFailureTests {
    @Test func guestOwnershipFailureIsTypedWithoutClaimingInput() throws {
        do {
            try classifyNativeHIDAttachment("com.apple.coredevice.dtuhidd.active 1")
            Issue.record("Device Hub ownership must refuse input")
        } catch let error as NativeHIDControlError {
            #expect(error.code == "ios_host_hid_device_hub_attached")
            #expect(error.detail.message.contains("no gesture was sent"))
        }
        try classifyNativeHIDAttachment("com.apple.coredevice.dtuhidd.active 0")
    }

    @Test func selectedBundleLayoutDoesNotProveDeviceChromeOrHID() throws {
        let developer = "/fixture/Selected Xcode.app/Contents/Developer"
        for (classic, hub, expected) in [(false, true, "device-hub-only"), (true, false, "classic-simulator"), (true, true, "classic-and-device-hub"), (false, false, "not-found")] {
            var paths: [String] = []
            let probe = probeIOSHostHID(selectedDevice: "SIM-1", developerDirectory: developer, fileExists: { path in
                paths.append(path)
                if path.hasSuffix("/Developer/Applications/Simulator.app") { return classic }
                if path.hasSuffix("/Applications/DeviceHub.app") { return hub }
                return path.contains("SimulatorKit.framework")
            }, loader: { _ in .init(loaded: true, legacyClientAvailable: true, modernClientAvailable: true, error: nil) })
            #expect(probe.hostChromeLayout == expected)
            #expect(!probe.chromeLookupVerified)
            #expect(probe.compatible && !probe.available && !probe.inputDispatchVerified)
            #expect(paths.allSatisfy { $0.hasPrefix("/fixture/Selected Xcode.app/") })
            if !classic && hub { #expect(probe.hint.contains("Device Hub")) }
            let json = String(decoding: try JSONEncoder().encode(probe), as: UTF8.self)
            #expect(!json.contains("/fixture"))
        }
    }

    @Test func nativePreflightPreservesSingleRedactedFailureEnvelope() throws {
        let operations: [(code: String, operation: () throws -> Void)] = [
            ("ios_host_hid_device_hub_attached", {
                try classifyNativeHIDAttachment("com.apple.coredevice.dtuhidd.active 1")
            }),
            ("ios_host_hid_attachment_unknown", {
                try classifyNativeHIDAttachment("PRIVATE-TARGET /private/secret")
            }),
            ("ios_host_hid_display_unsupported", {
                _ = try nativeHIDScreen("PRIVATE-TARGET /private/secret")
            }),
        ]
        for (code, operation) in operations {
            var failure: Error?
            do { try operation() } catch { failure = error }
            let error = try #require(failure)
            let pipe = Pipe()
            let original = dup(STDOUT_FILENO)
            fflush(stdout)
            dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
            do { try failHostCommand(error, outputFormat: .json) } catch { }
            fflush(stdout)
            dup2(original, STDOUT_FILENO)
            close(original)
            try pipe.fileHandleForWriting.close()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            try pipe.fileHandleForReading.close()
            let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: data)
            #expect(!response.ok)
            #expect(response.error.code == code)
            #expect(response.error.hint?.contains("Device Hub") == true)
            #expect(response.error.hint?.contains("swipe") == true)
            #expect(response.error.nextAction?.command == "device")
            #expect(response.error.nextAction?.args.first == "doctor")
            let output = String(decoding: data, as: UTF8.self)
            #expect(!output.contains("PRIVATE-TARGET"))
            #expect(!output.contains("/private/secret"))
        }
    }

    @Test func actionAndSimulatorSchemasPublishNativeGuardFailures() throws {
        let codes = ["ios_host_hid_device_hub_attached", "ios_host_hid_attachment_unknown", "ios_host_hid_display_unsupported"]
        for name in ["act", "sim"] {
            let schema = try #require(commandSchemas().first { $0.name == name })
            for code in codes { #expect(schema.failureCodes.contains(code)) }
            for leaf in schema.subcommands where ["tap", "swipe"].contains(leaf.name) {
                for code in codes { #expect(leaf.failureCodes.contains(code)) }
            }
        }
    }
}
