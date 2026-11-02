import Foundation
import Testing
import XPC
@testable import TritonKitCLI

private final class DTUPeer: DTUHIDConnection {
    var messages: [DTUHIDMessage] = []
    var barriers = 0
    var cancelled = false
    var barrierFailure: NativeDigitizerError?
    var sendFailure: NativeDigitizerError?
    func barrier(timeout: Double) throws {
        #expect(timeout == 4)
        barriers += 1
        if let barrierFailure { throw barrierFailure }
        messages.append(.barrier)
    }
    func send(_ message: DTUHIDMessage) throws {
        messages.append(message)
        if let sendFailure { throw sendFailure }
    }
    func cancel() { cancelled = true }
}

private final class DTUDriver: NativeHIDInputDriver {
    let pointSize: CGSize
    let session: DTUHIDSession
    var backend: String { session.backend }
    init(_ peer: DTUPeer, size: CGSize) throws { pointSize = size; session = try DTUHIDSession(connection: peer) }
    func send(point: CGPoint, phase: NativeDigitizerPhase, identifier: UInt32) throws { try session.send(point: point, phase: phase, identifier: identifier) }
    func finish() throws { try session.finish() }
}

@Suite("DTUHID no-event handshake and fail-closed selection")
struct DTUHIDTransportTests {
    @Test func onlyMissingMethodOrExact405IsUnsupported() {
        #expect(DTUHIDLookup.unsupported(methodAvailable: false, port: 0, error: nil))
        #expect(DTUHIDLookup.unsupported(methodAvailable: true, port: 0, error: NSError(domain: "com.apple.CoreSimulator.SimError", code: 405)))
        for error in [nil, NSError(domain: "other", code: 405), NSError(domain: "com.apple.CoreSimulator.SimError", code: 406)] {
            #expect(!DTUHIDLookup.unsupported(methodAvailable: true, port: 0, error: error))
        }
        #expect(!DTUHIDLookup.unsupported(methodAvailable: true, port: 1, error: NSError(domain: "com.apple.CoreSimulator.SimError", code: 405)))
    }

    @Test func samePeerLivenessTouchesAndFinishAreOrdered() throws {
        let peer = DTUPeer()
        let session = try DTUHIDSession(connection: peer)
        for phase in [NativeDigitizerPhase.down, .move, .up] {
            try session.send(point: CGPoint(x: 0.25, y: 0.75), phase: phase, identifier: 1)
        }
        try session.finish()
        #expect(peer.messages == [.barrier, .touch(x: 0.25, y: 0.75, phase: 0), .touch(x: 0.25, y: 0.75, phase: 1), .touch(x: 0.25, y: 0.75, phase: 2), .barrier])
        #expect(session.backend == "dtuhid")
    }

    @Test func wireTypesAndBarrierCannotEmitCharacterOrTouch() {
        let barrier = DTUHIDMessage.barrier.xpc
        #expect(String(cString: xpc_dictionary_get_string(barrier, "messageType")!) == "IndigoKeyboardButtonEvent")
        #expect(xpc_dictionary_get_bool(barrier, "isBarrier"))
        let payload = xpc_dictionary_get_value(barrier, "payload")!
        #expect(xpc_dictionary_get_uint64(payload, "usageCode") == 0)
        #expect(xpc_dictionary_get_uint64(payload, "state") == 2)
        #expect(xpc_dictionary_get_value(payload, "pointOne") == nil)
        let touch = DTUHIDMessage.touch(x: 0.2, y: 0.7, phase: 1).xpc
        #expect(!xpc_dictionary_get_bool(touch, "isBarrier"))
        #expect(String(cString: xpc_dictionary_get_string(touch, "featureIdentifier")!) == DTUHIDLookup.service)
        let tp = xpc_dictionary_get_value(touch, "payload")!
        #expect(xpc_get_type(xpc_dictionary_get_value(tp, "eventType")!) == XPC_TYPE_UINT64)
        #expect(xpc_dictionary_get_uint64(tp, "eventType") == 1)
        #expect(xpc_dictionary_get_uint64(tp, "target") == 0)
        #expect(xpc_dictionary_get_uint64(tp, "edge") == 0)
        let point = xpc_dictionary_get_value(tp, "pointOne")!
        #expect(xpc_get_type(xpc_dictionary_get_value(point, "x")!) == XPC_TYPE_DOUBLE)
        #expect(xpc_dictionary_get_double(point, "x") == 0.2)
        #expect(xpc_dictionary_get_double(point, "y") == 0.7)
    }

    @Test func unknownLookupAndHandshakeFailuresNeverConstructLegacy() {
        for failure in [NativeDigitizerError.timeout, .sendFailed, .symbolUnavailable, .clientInitializationFailed] {
            var legacyCalls = 0
            #expect(throws: failure) {
                _ = try selectNativeDigitizer(modern: { throw failure }, legacy: { legacyCalls += 1; throw NativeDigitizerError.legacyClientUnavailable })
            }
            #expect(legacyCalls == 0)
            let peer = DTUPeer(); peer.barrierFailure = failure
            #expect(throws: failure) { _ = try DTUHIDSession(connection: peer) }
            #expect(peer.messages.isEmpty)
            #expect(peer.cancelled)
        }
        var legacyCalls = 0
        #expect(throws: NativeDigitizerError.legacyClientUnavailable) {
            _ = try selectNativeDigitizer(modern: { nil }, legacy: { legacyCalls += 1; throw NativeDigitizerError.legacyClientUnavailable })
        }
        #expect(legacyCalls == 1)
    }

    @Test func failuresDoNotReplayAndInvalidPointsNeverSend() throws {
        let peer = DTUPeer(); let session = try DTUHIDSession(connection: peer)
        #expect(throws: NativeDigitizerError.invalidPoint) { try session.send(point: CGPoint(x: CGFloat.nan, y: 0), phase: .down, identifier: 1) }
        #expect(peer.messages == [.barrier])
        peer.sendFailure = .sendFailed
        #expect(throws: NativeDigitizerError.sendFailed) { try session.send(point: .zero, phase: .down, identifier: 1) }
        #expect(peer.messages.count == 2)
        let finishingPeer = DTUPeer(); let finishing = try DTUHIDSession(connection: finishingPeer)
        finishingPeer.barrierFailure = .timeout
        #expect(throws: NativeDigitizerError.timeout) { try finishing.finish() }
        #expect(peer.messages.count == 2)
        #expect(finishingPeer.barriers == 2)
    }
    @Test func malformedRepliesCancellationAndLateCallbacksFailClosed() {
        #expect(!DTUHIDReply.valid(xpc_string_create("not a reply")))
        #expect(!DTUHIDReply.valid(XPC_ERROR_CONNECTION_INTERRUPTED))
        let error = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_bool(error, "error", true)
        #expect(!DTUHIDReply.valid(error))
        #expect(DTUHIDReply.valid(xpc_dictionary_create(nil, nil, 0)))
        let timed = DTUHIDReply()
        #expect(throws: NativeDigitizerError.timeout) { try timed.wait(timeout: 0.001) }
        timed.complete(valid: true)
        #expect(throws: NativeDigitizerError.sendFailed) { try timed.wait(timeout: 0.001) }
        let cancelled = DTUHIDReply()
        cancelled.complete(valid: false)
        DispatchQueue.global().async { cancelled.complete(valid: true) }
        #expect(throws: NativeDigitizerError.sendFailed) { try cancelled.wait(timeout: 1) }
    }

    @Test func contactStateRejectsDuplicateDownOrUpAndOnlyReleasesAfterFailure() throws {
        let peer = DTUPeer(); let session = try DTUHIDSession(connection: peer)
        #expect(throws: NativeDigitizerError.messageInvalid) { try session.send(point: .zero, phase: .up, identifier: 1) }
        try session.send(point: .zero, phase: .down, identifier: 1)
        #expect(throws: NativeDigitizerError.messageInvalid) { try session.send(point: .zero, phase: .down, identifier: 1) }
        peer.sendFailure = .sendFailed
        #expect(throws: NativeDigitizerError.sendFailed) { try session.send(point: .zero, phase: .move, identifier: 1) }
        let count = peer.messages.count
        #expect(throws: NativeDigitizerError.sendFailed) { try session.send(point: .zero, phase: .move, identifier: 1) }
        #expect(peer.messages.count == count)
        peer.sendFailure = nil
        try session.send(point: .zero, phase: .up, identifier: 1)
        #expect(throws: NativeDigitizerError.sendFailed) { try session.send(point: .zero, phase: .down, identifier: 1) }
        #expect(peer.messages.count == count + 1)
    }

    @Test func helperAdmissionReachesModernOnlyForUnclaimedUnchangedPrimary() throws {
        let screen = try nativeHIDScreen(NativeHIDRuntimeTests().fixture)
        let peer = DTUPeer()
        var snapshots = 0
        let backend = try performNativeHIDInput(input: .tap(x: 100, y: 200), snapshot: {
            snapshots += 1
            try classifyNativeHIDAttachment("com.apple.coredevice.dtuhidd.active 0")
            return screen
        }, makeDriver: { try DTUDriver(peer, size: screen.pointSize) }, sleep: { _ in })
        #expect(backend == "dtuhid")
        #expect(snapshots == 3)
        #expect(peer.messages.count == 4 && peer.messages.first == .barrier && peer.messages.last == .barrier)
        for ownership in ["1", "unknown"] {
            var created = false
            #expect(throws: NativeHIDControlError.self) {
                _ = try performNativeHIDInput(input: .tap(x: 100, y: 200), snapshot: {
                    try classifyNativeHIDAttachment("com.apple.coredevice.dtuhidd.active " + ownership)
                    return screen
                }, makeDriver: { created = true; return try DTUDriver(DTUPeer(), size: screen.pointSize) }, sleep: { _ in })
            }
            #expect(!created)
        }
        let mismatch = DTUPeer()
        #expect(throws: NativeHIDControlError.self) {
            _ = try performNativeHIDInput(input: .tap(x: 100, y: 200), snapshot: { screen }, makeDriver: {
                try DTUDriver(mismatch, size: CGSize(width: 1, height: 1))
            }, sleep: { _ in })
        }
        #expect(mismatch.messages == [.barrier])
    }

    @Test func activeObservationStrictAndTransitionsNeverReplay() throws {
        #expect(try nativeHIDDTUHIDActive("com.apple.coredevice.dtuhidd.active 1"))
        #expect(try !nativeHIDDTUHIDActive("com.apple.coredevice.dtuhidd.active 0"))
        for text in ["", "com.apple.coredevice.dtuhidd.active unknown", "other 1", "com.apple.coredevice.dtuhidd.active 1 extra"] {
            #expect(throws: NativeHIDControlError.self) { _ = try nativeHIDDTUHIDActive(text) }
        }
        let original = try nativeHIDScreen(NativeHIDRuntimeTests().fixture)
        for initial in [false, true] {
            for changeAt in [2, 3] {
                let peer = DTUPeer()
                var calls = 0
                #expect(throws: NativeHIDControlError.self) {
                    _ = try performNativeHIDInput(input: .tap(x: 100, y: 200), snapshot: {
                        calls += 1
                        var value = original
                        value.dtuhidActive = calls >= changeAt ? !initial : initial
                        return value
                    }, makeDriver: { try DTUDriver(peer, size: original.pointSize) }, sleep: { _ in })
                }
                #expect(peer.messages.count == (changeAt == 2 ? 1 : 4))
            }
        }
        let peer = DTUPeer(); var calls = 0
        do {
            _ = try performNativeHIDInput(input: .tap(x: 100, y: 200), snapshot: {
                calls += 1
                if calls == 3 { throw NativeHIDControlError(code: "ios_host_hid_attachment_unknown") }
                return original
            }, makeDriver: { try DTUDriver(peer, size: original.pointSize) }, sleep: { _ in })
            Issue.record("post-send unknown must fail")
        } catch let failure as NativeHIDControlError {
            #expect(failure.code == "ios_host_hid_surface_changed")
        }
        #expect(peer.messages.count == 4)
    }

    @Test func claimedPrimaryRequiresNegotiatedModernDriver() throws {
        let original = try nativeHIDScreen(NativeHIDRuntimeTests().fixture)
        let screen = NativeHIDScreen(pointSize: original.pointSize, dtuhidActive: true)
        let peer = DTUPeer()
        #expect(try performNativeHIDInput(input: .tap(x: 100, y: 200), snapshot: { screen },
            makeDriver: { try DTUDriver(peer, size: screen.pointSize) }, sleep: { _ in }) == "dtuhid")
        #expect(peer.messages.count == 4)
        let legacy = LegacyGateDriver(size: screen.pointSize)
        #expect(throws: NativeHIDControlError.self) {
            _ = try performNativeHIDInput(input: .tap(x: 100, y: 200), snapshot: { screen },
                makeDriver: { legacy }, sleep: { _ in })
        }
        #expect(legacy.sends == 0)
        #expect(throws: NativeHIDControlError.self) {
            _ = try performNativeHIDInput(input: .tap(x: 100, y: 200), preflightOnly: true,
                snapshot: { screen }, makeDriver: { legacy }, sleep: { _ in })
        }
    }

}

private final class LegacyGateDriver: NativeHIDInputDriver {
    let backend = "legacy"
    let pointSize: CGSize
    var sends = 0
    init(size: CGSize) { pointSize = size }
    func send(point: CGPoint, phase: NativeDigitizerPhase, identifier: UInt32) throws { sends += 1 }
    func finish() throws {}
}
