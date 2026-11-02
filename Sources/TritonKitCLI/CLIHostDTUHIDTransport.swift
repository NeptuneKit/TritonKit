// DTUHID connection/wire reference: Loupe 180c60584867500b93b43ca6c8b556995bf8be7b
// and idb c793afad2a31092628f7013cf1aa96f266c85024 (MIT).
// Copyright (c) 2026 heoblitz; Copyright (c) Meta Platforms, Inc. and affiliates.
// See Resources/native-hid for complete notices. No upstream runtime dependency.
import Foundation
import CoreGraphics
import ObjectiveC
import Darwin
import XPC

protocol NativeDigitizerTransport: AnyObject {
    var backend: String { get }
    func send(point: CGPoint, phase: NativeDigitizerPhase, identifier: UInt32) throws
    func finish() throws
}

func selectNativeDigitizer(modern: () throws -> NativeDigitizerTransport?,
                          legacy: () throws -> NativeDigitizerTransport) throws -> NativeDigitizerTransport {
    // nil exclusively represents an explicit unsupported lookup. Errors escape.
    if let modern = try modern() { return modern }
    return try legacy()
}

protocol DTUHIDConnection: AnyObject {
    func send(_ message: DTUHIDMessage) throws
    func barrier(timeout: Double) throws
    func cancel()
}

final class DTUHIDSession: NativeDigitizerTransport {
    let backend = "dtuhid"
    private let connection: DTUHIDConnection
    private let lock = NSLock()
    private var active = false
    private var finished = false
    private var poisoned = false
    private var releaseAttempted = false

    init(connection: DTUHIDConnection) throws {
        self.connection = connection
        do { try connection.barrier(timeout: 4) }
        catch { connection.cancel(); throw error }
    }
    deinit { connection.cancel() }

    func send(point: CGPoint, phase: NativeDigitizerPhase, identifier: UInt32) throws {
        lock.lock(); defer { lock.unlock() }
        try NativeSimulatorDigitizer.validate(point: point)
        if poisoned && !(phase == .up && active && !releaseAttempted) { throw NativeDigitizerError.sendFailed }
        guard !finished, identifier == 1,
              (phase == .down && !active) || (phase != .down && active) else {
            throw NativeDigitizerError.messageInvalid
        }
        let value: UInt64 = phase == .down ? 0 : phase == .move ? 1 : 2
        // Mark an attempted down as ours even if delivery becomes unknown, so
        // the caller may attempt one terminal up on this same connection only.
        if phase == .down { active = true }
        if phase == .up { releaseAttempted = true }
        do { try connection.send(.touch(x: point.x, y: point.y, phase: value)) }
        catch { poisoned = true; throw error }
        if phase == .up { active = false }
    }

    func finish() throws {
        lock.lock(); defer { lock.unlock() }
        guard !finished, !active else { throw NativeDigitizerError.messageInvalid }
        guard !poisoned else { throw NativeDigitizerError.sendFailed }
        finished = true // failure cannot be retried or reopened
        do { try connection.barrier(timeout: 4) }
        catch { connection.cancel(); throw error }
    }

    static func open(device: NSObject) throws -> DTUHIDSession? {
        let selector = NSSelectorFromString("lookup:error:")
        guard device.responds(to: selector) else { return nil }
        guard let cls = object_getClass(device),
              let method = class_getInstanceMethod(cls, selector) else { throw NativeDigitizerError.symbolUnavailable }
        typealias Lookup = @convention(c) (AnyObject, Selector, NSString, AutoreleasingUnsafeMutablePointer<NSError?>) -> mach_port_t
        let lookup = unsafeBitCast(method_getImplementation(method), to: Lookup.self)
        var error: NSError?
        let port = lookup(device, selector, DTUHIDLookup.service as NSString, &error)
        if DTUHIDLookup.unsupported(methodAvailable: true, port: port, error: error) { return nil }
        guard port != MACH_PORT_NULL else { throw NativeDigitizerError.clientInitializationFailed }
        // A contradictory non-null port plus NSError is unknown, never fallback.
        guard error == nil else {
            mach_port_deallocate(mach_task_self_, port)
            throw NativeDigitizerError.clientInitializationFailed
        }
        return try DTUHIDSession(connection: DTUHIDXPCConnection(port: port))
    }
}

/// Heap-owned, one-shot reply latch. Timeout/cancellation and late callbacks
/// race through the same lock; a late reply cannot resurrect a failed wait.
final class DTUHIDReply: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Bool?
    func complete(valid: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard result == nil else { return }
        result = valid
        semaphore.signal()
    }
    func wait(timeout: Double) throws {
        if semaphore.wait(timeout: .now() + timeout) != .success {
            complete(valid: false)
            throw NativeDigitizerError.timeout
        }
        lock.lock(); defer { lock.unlock() }
        guard result == true else { throw NativeDigitizerError.sendFailed }
    }
    static func valid(_ reply: xpc_object_t) -> Bool {
        // No undocumented ACK payload is promoted to guest/business success.
        // A dictionary response is only a protocol responsiveness observation.
        xpc_get_type(reply) == XPC_TYPE_DICTIONARY && xpc_dictionary_get_value(reply, "error") == nil
    }
}

final class DTUHIDXPCConnection: DTUHIDConnection {
    private let connection: xpc_connection_t
    private let queue = DispatchQueue(label: "triton.dtuhid.xpc")
    private let lock = NSLock()
    private var failed = false
    private var pending: DTUHIDReply?

    convenience init(port: mach_port_t) throws {
        typealias Endpoint = @convention(c) (mach_port_t, UInt64, UInt64) -> Unmanaged<AnyObject>?
        typealias Connect = @convention(c) (xpc_object_t) -> Unmanaged<AnyObject>?
        typealias Enable = @convention(c) (xpc_connection_t) -> Void
        let symbols = UnsafeMutableRawPointer(bitPattern: -2)
        guard let ep = dlsym(symbols, "xpc_endpoint_create_mach_port_4sim"),
              let cp = dlsym(symbols, "xpc_connection_create_from_endpoint"),
              let en = dlsym(symbols, "xpc_connection_enable_sim2host_4sim") else {
            mach_port_deallocate(mach_task_self_, port)
            throw NativeDigitizerError.symbolUnavailable
        }
        let endpoint = unsafeBitCast(ep, to: Endpoint.self)
        let connect = unsafeBitCast(cp, to: Connect.self)
        // Endpoint creation consumes the lookup send right, including failure.
        guard let object = endpoint(port, 0, 0)?.takeRetainedValue() as? xpc_object_t,
              let connection = connect(object)?.takeRetainedValue() as? xpc_connection_t else {
            throw NativeDigitizerError.clientInitializationFailed
        }
        unsafeBitCast(en, to: Enable.self)(connection)
        self.init(connection: connection)
    }

    /// Internal initializer also exercises real callback/cancel wiring with a
    /// Triton-owned anonymous peer. It is never exposed as a CLI override.
    init(connection: xpc_connection_t) {
        self.connection = connection
        xpc_connection_set_target_queue(connection, queue)
        xpc_connection_set_event_handler(connection) { [weak self] event in
            if xpc_get_type(event) == XPC_TYPE_ERROR { self?.invalidate() }
        }
        xpc_connection_resume(connection)
    }
    deinit { xpc_connection_cancel(connection) }

    private func invalidate() {
        lock.lock(); failed = true; let waiting = pending; lock.unlock()
        waiting?.complete(valid: false)
    }
    func cancel() {
        invalidate()
        xpc_connection_cancel(connection)
    }
    func send(_ message: DTUHIDMessage) throws {
        lock.lock(); defer { lock.unlock() }
        guard !failed else { throw NativeDigitizerError.sendFailed }
        xpc_connection_send_message(connection, message.xpc)
    }
    func barrier(timeout: Double) throws {
        let reply = DTUHIDReply()
        lock.lock()
        guard !failed, pending == nil else { lock.unlock(); throw NativeDigitizerError.sendFailed }
        pending = reply
        xpc_connection_send_message_with_reply(connection, DTUHIDMessage.barrier.xpc, queue) { [weak self] object in
            let valid = DTUHIDReply.valid(object)
            if !valid { self?.invalidate() }
            reply.complete(valid: valid)
        }
        lock.unlock()
        defer { lock.lock(); pending = nil; lock.unlock() }
        do {
            try reply.wait(timeout: timeout)
            lock.lock(); let invalid = failed; lock.unlock()
            if invalid { throw NativeDigitizerError.sendFailed }
        } catch { cancel(); throw error }
    }
}
