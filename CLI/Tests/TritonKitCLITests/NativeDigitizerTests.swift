import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Native digitizer wire safety")
struct NativeDigitizerTests {
    @Test func phasesPreserveTouchUntilLift() {
        #expect(NativeDigitizerPhase.down.eventMask == 0x07)
        #expect(NativeDigitizerPhase.move.eventMask == 0x07)
        #expect(NativeDigitizerPhase.up.eventMask == 0x06)
        #expect(NativeDigitizerPhase.down.range && NativeDigitizerPhase.down.touch)
        #expect(NativeDigitizerPhase.move.range && NativeDigitizerPhase.move.touch)
        #expect(!NativeDigitizerPhase.up.range && !NativeDigitizerPhase.up.touch)
    }

    @Test func rejectsNonNormalizedCoordinatesWithoutClamping() throws {
        for point in [CGPoint(x: -0.001, y: 0), CGPoint(x: 1.001, y: 0),
                      CGPoint(x: 0, y: -0.001), CGPoint(x: 0, y: 1.001),
                      CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 0, y: CGFloat.infinity)] {
            #expect(throws: NativeDigitizerError.invalidPoint) {
                try NativeSimulatorDigitizer.validate(point: point)
            }
        }
        for point in [CGPoint.zero, CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 0.75)] {
            try NativeSimulatorDigitizer.validate(point: point)
        }
    }

    @Test func truncatedMessagesAreRejectedBeforeAnyWrite() {
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: 512, alignment: 16)
        defer { buffer.deallocate() }
        for length in [0, 0x3b, 0x70, 192, 0x10f, 0x110, 383] {
            buffer.initializeMemory(as: UInt8.self, repeating: 0xa5, count: 512)
            #expect(throws: NativeDigitizerError.messageInvalid) {
                try NativeSimulatorDigitizer.patch(message: buffer, allocationSize: length)
            }
            #expect(Array(UnsafeRawBufferPointer(start: buffer, count: 512)).allSatisfy { $0 == 0xa5 })
        }
    }

    @Test func patchesBothMainScreenTargetsAndClearsOnlyEdgeSlots() throws {
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: 512, alignment: 16)
        defer { buffer.deallocate() }
        buffer.initializeMemory(as: UInt8.self, repeating: 0xa5, count: 512)
        try NativeSimulatorDigitizer.patch(message: buffer, allocationSize: 384)
        let expectedChanges = Set([0x3a, 0x3b, 0xda, 0xdb, 0x6c, 0x6d, 0x6e, 0x6f, 0x10c, 0x10d, 0x10e, 0x10f])
        for offset in 0..<512 {
            let value = buffer.load(fromByteOffset: offset, as: UInt8.self)
            if offset == 0x6c || offset == 0x10c { #expect(value == 0x32) }
            else if expectedChanges.contains(offset) { #expect(value == 0) }
            else { #expect(value == 0xa5) }
        }
    }

    @Test func timeoutExplicitlyPreservesUnknownDelivery() {
        #expect(NativeDigitizerError.timeout.detail.code == "ios_host_hid_send_timeout")
        #expect(NativeDigitizerError.timeout.detail.message.contains("unknown"))
    }
}
