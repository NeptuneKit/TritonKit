import CoreGraphics
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Built-in Simulator HID runtime")
struct NativeHIDRuntimeTests {
    @Test func nativeFailuresNeverRecommendActionReplay() {
        for code in schemaIOSNativeHIDFailureCodes {
            #expect(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: code) == ["diagnose", "observe", "plan"])
        }
    }

    let fixture = """
    Port:
        Class: DisplayAdapter
        Connected Screens:
        (1) LCD:
            Screen ID: 1
            Device Name: primary
            Screen Type: Integrated
            Pixel Size: {1170, 2532}
            Preferred UI Scale: 3
            UI Orientation: Portrait
    Port:
        Class: LegacyHID
    """

    @Test func ownershipMustBeExplicitlyInactive() throws {
        try classifyNativeHIDAttachment("com.apple.coredevice.dtuhidd.active 0\n")
        for text in ["com.apple.coredevice.dtuhidd.active 1", "", "PRIVATE ERROR", "other.key 0", "com.apple.coredevice.dtuhidd.active 0 trailing", "com.apple.coredevice.dtuhidd.active 2"] {
            #expect(throws: NativeHIDControlError.self) { try classifyNativeHIDAttachment(text) }
        }
    }

    @Test func onlyKnownPrimaryScreenGeometryIsAccepted() throws {
        let screen = try nativeHIDScreen(fixture)
        #expect(screen.pointSize == CGSize(width: 390, height: 844))
        for text in ["", fixture.replacingOccurrences(of: "primary", with: "cover"), fixture.replacingOccurrences(of: "Portrait", with: "LandscapeLeft"), fixture.replacingOccurrences(of: "Integrated", with: "Scene"), fixture.replacingOccurrences(of: "Scale: 3", with: "Scale: 0"), fixture.replacingOccurrences(of: "1170", with: "nan"), fixture.replacingOccurrences(of: "Screen ID: 1", with: "Screen ID: 3"), fixture + fixture] {
            #expect(throws: NativeHIDControlError.self) { try nativeHIDScreen(text) }
        }
        for pixels in ["{1170,PRIVATE,2532}", "{1170,,2532}", "{1170,2532,}", "{,2532}"] {
            #expect(throws: NativeHIDControlError.self) { try nativeHIDScreen(fixture.replacingOccurrences(of: "{1170, 2532}", with: pixels)) }
        }
    }

    @Test func freshGuardPreventsSendAndPostGuardCannotClaimSuccess() throws {
        let screen = try nativeHIDScreen(fixture)
        var sent = false
        #expect(throws: NativeHIDControlError.self) {
            try executeGuardedNativeHIDGesture(expectedScreen: screen, snapshot: {
                throw NativeHIDControlError(code: "ios_host_hid_device_hub_attached")
            }) { sent = true }
        }
        #expect(!sent)
        var snapshots = 0
        do {
            try executeGuardedNativeHIDGesture(expectedScreen: screen, snapshot: {
                snapshots += 1
                if snapshots == 2 { throw NativeHIDControlError(code: "ios_host_hid_device_hub_attached") }
                return screen
            }) { sent = true }
            Issue.record("Changed ownership must not claim transport success")
        } catch let error as NativeHIDControlError {
            #expect(error.code == "ios_host_hid_surface_changed")
            #expect(error.detail.message.contains("may already"))
            #expect(!error.detail.message.contains("no gesture was sent"))
        }
        #expect(sent && snapshots == 2)
    }

    @Test(arguments: [NativeDigitizerPhase.down, .move, .up])
    func anySendFailureRetainsCodeAndUnknownDelivery(failedPhase: NativeDigitizerPhase) throws {
        let screen = try nativeHIDScreen(fixture)
        let gesture = try nativeHIDContacts(input: .swipe(startX: 195, startY: 600, endX: 195, endY: 200), screen: screen)
        var events: [NativeDigitizerPhase] = []
        do {
            try executeGuardedNativeHIDGesture(expectedScreen: screen, snapshot: { screen }) {
                try executeNativeHIDContacts(gesture.contacts, cadence: gesture.cadence, sleep: { _ in }) { contact in
                    events.append(contact.phase)
                    if contact.phase == failedPhase { throw NativeDigitizerError.timeout }
                }
            }
            Issue.record("A send timeout must fail")
        } catch let error as NativeHIDDeliveryError {
            #expect(error.detail.code == "ios_host_hid_send_timeout")
            #expect(error.detail.message.contains("partial gesture"))
            #expect(error.detail.message.contains("Do not replay automatically"))
        }
        #expect(events.filter { $0 == .down }.count == 1)
        #expect(events.filter { $0 == .up }.count == 1)
        if failedPhase == .down { #expect(events == [.down, .up]) }
        if failedPhase == .move { #expect(events == [.down, .move, .up]) }
    }

    @Test func tapAndSwipeShareOneNormalizedContactSequence() throws {
        let screen = try nativeHIDScreen(fixture)
        let tap = try nativeHIDContacts(input: .tap(x: 195, y: 422), screen: screen)
        #expect(tap.contacts.count == 2)
        #expect(tap.contacts.first?.point == CGPoint(x: 0.5, y: 0.5))
        #expect(tap.contacts.first?.phase == .down && tap.contacts.last?.phase == .up)
        let swipe = try nativeHIDContacts(input: .swipe(startX: 390, startY: 844, endX: 0, endY: 0, duration: 0.6), screen: screen)
        #expect(swipe.contacts.count == 12)
        #expect(swipe.contacts.first?.point == CGPoint(x: 1, y: 1))
        #expect(swipe.contacts.last?.point == .zero)
        #expect(abs(swipe.cadence * 11 - 0.6) < 0.00001)
        for request in [TKInputRequest.tap(x: -1, y: 0), .tap(x: .infinity, y: 0), .tap(x: 400, y: 0), .swipe(startX: 0, startY: 0, endX: 1, endY: 1, duration: 11)] {
            #expect(throws: NativeHIDControlError.self) { try nativeHIDContacts(input: request, screen: screen) }
        }
    }

    @Test func failedMoveReleasesLastPointOnceAndDoesNotReplay() throws {
        let gesture = try nativeHIDContacts(input: .swipe(startX: 195, startY: 600, endX: 195, endY: 200), screen: nativeHIDScreen(fixture))
        var events: [NativeHIDContact] = []
        #expect(throws: NativeHIDControlError.self) {
            try executeNativeHIDContacts(gesture.contacts, cadence: gesture.cadence, sleep: { _ in }) { contact in
                events.append(contact)
                if contact.phase == .move { throw NativeHIDControlError(code: "ios_host_hid_helper_failed") }
            }
        }
        #expect(events.map(\.phase) == [.down, .move, .up])
        #expect(events.last?.point == events[1].point)
    }

    @Test func childIsCurrentTritonAndDoesNotResolveExternalAdapter() throws {
        let command = try nativeHIDHelperCommand(target: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", input: .tap(x: 1, y: 2), executable: "/fixture/triton", developerDirectory: "/fixture/Xcode.app/Contents/Developer")
        #expect(command.executable == "/fixture/triton")
        #expect(Array(command.arguments.prefix(3)) == ["device", "hid-input", "--device"])
        #expect(!command.arguments.contains("chrome"))
        #expect(!command.arguments.contains("baguette"))
        #expect(command.environment["DEVELOPER_DIR"] == "/fixture/Xcode.app/Contents/Developer")
        #expect(command.defaultTimeoutSeconds >= 150)
    }

    @Test func childFailureMustBeSingleTypedBoundEnvelope() throws {
        let input = TKInputRequest.tap(x: 1, y: 2)
        let error = NativeHIDControlError(code: "ios_host_hid_device_hub_attached").detail
        let result = try runNativeSimulatorInput(target: "SIM-1", input: input) { command in
            let failure = HostProcessResult(stdoutData: try JSONEncoder().encode(TKInputResult.failure(action: "tap", message: error.message, error: error)), stderrData: Data("PRIVATE RAW LOG".utf8), exitCode: 1, sourceCommand: "private command", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
            throw HostCommandRunError.nonZeroExit(command: command, result: failure)
        }
        #expect(!result.ok && result.error?.code == "ios_host_hid_device_hub_attached")
        #expect(try !String(decoding: JSONEncoder().encode(result), as: UTF8.self).contains("PRIVATE"))
        #expect(throws: NativeHIDControlError.self) {
            _ = try runNativeSimulatorInput(target: "SIM-1", input: input) { _ in
                HostProcessResult(stdoutData: Data("{} {}".utf8), stderrData: Data(), exitCode: 0, sourceCommand: "private command", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
            }
        }
    }
}
