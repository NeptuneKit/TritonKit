import Foundation
import CoreFoundation
import Darwin

struct IOSRunnerDeadline {
    private let end: Double
    init(timeout: Double, now: Double = ProcessInfo.processInfo.systemUptime) throws {
        guard timeout.isFinite, timeout > 0, timeout <= 120, now.isFinite else { throw IOSRunnerWireError("timeout_invalid") }
        end = now + timeout
    }
    func remaining(now: Double = ProcessInfo.processInfo.systemUptime) throws -> Double {
        let interval = end - now
        guard interval > 0, interval.isFinite else { throw IOSRunnerWireError("deadline_exceeded") }
        return interval
    }
}

enum IOSRunnerMux {
    static let maximumPlistBytes = 1024 * 1024
    static func networkPort(_ port: UInt16) -> Int { Int(port.bigEndian) }
    private static func littleEndian32(_ value: UInt32) -> Data {
        Data([UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8),
              UInt8(truncatingIfNeeded: value >> 16), UInt8(truncatingIfNeeded: value >> 24)])
    }
    private static func readLittleEndian32(_ data: Data, at index: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | (UInt32(data[index + $1]) << (8 * $1)) }
    }
    static func frame(_ message: [String: Any], tag: UInt32) throws -> Data {
        var message = message
        message["ClientVersionString"] = "TritonKit/ios-runner"
        message["ProgName"] = "triton"
        let payload = try PropertyListSerialization.data(fromPropertyList: message, format: .xml, options: 0)
        guard payload.count <= maximumPlistBytes else { throw IOSRunnerWireError("usbmux_frame_budget") }
        return littleEndian32(UInt32(payload.count + 16)) + littleEndian32(1) + littleEndian32(8) + littleEndian32(tag) + payload
    }
    static func payloadLength(_ header: Data, expectedTag: UInt32) throws -> Int {
        guard header.count == 16, readLittleEndian32(header, at: 4) == 1,
              readLittleEndian32(header, at: 8) == 8, readLittleEndian32(header, at: 12) == expectedTag else {
            throw IOSRunnerWireError("usbmux_frame_invalid")
        }
        let length = Int(readLittleEndian32(header, at: 0))
        guard length > 16, length <= maximumPlistBytes + 16 else { throw IOSRunnerWireError("usbmux_frame_budget") }
        return length - 16
    }
    static func parseFrame(_ frame: Data, expectedTag: UInt32) throws -> [String: Any] {
        guard frame.count >= 16 else { throw IOSRunnerWireError("usbmux_frame_invalid") }
        let length = try payloadLength(Data(frame.prefix(16)), expectedTag: expectedTag)
        guard frame.count == length + 16,
              let message = try PropertyListSerialization.propertyList(from: Data(frame.dropFirst(16)), options: [], format: nil) as? [String: Any] else {
            throw IOSRunnerWireError("usbmux_plist_invalid")
        }
        return message
    }
    static func selectUSBDevice(_ records: Any?, serial: String) throws -> UInt32 {
        guard let records = records as? [[String: Any]] else { throw IOSRunnerWireError("usbmux_inventory_invalid") }
        var matches: [UInt32] = []
        for record in records {
            guard let properties = record["Properties"] as? [String: Any] else { throw IOSRunnerWireError("usbmux_inventory_invalid") }
            if properties["ConnectionType"] as? String == "USB", properties["SerialNumber"] as? String == serial {
                guard let id = IOSRunnerWire.strictInteger(record["DeviceID"]), id >= 0, id <= Int(UInt32.max) else {
                    throw IOSRunnerWireError("usbmux_inventory_invalid")
                }
                matches.append(UInt32(id))
            }
        }
        guard matches.count == 1 else { throw IOSRunnerWireError(matches.isEmpty ? "usbmux_target_not_found" : "usbmux_target_ambiguous") }
        return matches[0]
    }
}

/// One connection and one request per exchange. No redirect, retry, proxy, or external relay process.
enum IOSRunnerTransport {
    static func exchange(connection: IOSRunnerConnection, route: String, body: Data?, requestID: String, timeout: Double) -> IOSRunnerWireResponse {
        do {
            let deadline = try IOSRunnerDeadline(timeout: timeout)
            let request = try IOSRunnerWire.request(connection: connection, route: route, body: body, requestID: requestID)
            let socket = try IOSRunnerSocket(domain: connection.scope == "real" ? AF_UNIX : AF_INET)
            defer { socket.close() }
            if connection.scope == "real" {
                try socket.connectUSB(deadline: deadline)
                let inventory = try socket.mux(["MessageType": "ListDevices"], tag: 1, deadline: deadline)
                let device = try IOSRunnerMux.selectUSBDevice(inventory["DeviceList"], serial: connection.targetAddress)
                let result = try socket.mux(["MessageType": "Connect", "DeviceID": device,
                                             "PortNumber": IOSRunnerMux.networkPort(connection.port)], tag: 2, deadline: deadline)
                guard result["MessageType"] as? String == "Result", IOSRunnerWire.strictInteger(result["Number"]) == 0 else {
                    throw IOSRunnerWireError("usbmux_connect_rejected")
                }
            } else {
                try socket.connectLoopback(port: connection.port, deadline: deadline)
            }
            try socket.write(request, deadline: deadline)
            let response = try socket.readHTTP(deadline: deadline)
            _ = try deadline.remaining()
            let parsed = try IOSRunnerWire.parseHTTPResponse(response, sessionID: connection.sessionID, requestID: requestID)
            _ = try deadline.remaining()
            return parsed
        } catch {
            let cause = (error as? IOSRunnerWireError)?.cause ?? "socket_failed"
            return IOSRunnerWireResponse(envelope: ["ok": false, "sessionID": connection.sessionID, "requestID": requestID,
                "error": ["code": "ios_runner_transport_unknown", "cause": cause, "delivery": "unknown", "retryable": false]])
        }
    }
}

private final class IOSRunnerSocket {
    private var fd: Int32
    init(domain: Int32) throws {
        fd = Darwin.socket(domain, SOCK_STREAM, 0)
        guard fd >= 0 else { throw IOSRunnerWireError("socket_create_failed") }
        let flags = fcntl(fd, F_GETFL, 0)
        var enabled: Int32 = 1
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0,
              fcntl(fd, F_SETFD, FD_CLOEXEC) == 0,
              setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            Darwin.close(fd); fd = -1
            throw IOSRunnerWireError("socket_setup_failed")
        }
    }
    deinit { close() }
    func close() { if fd >= 0 { Darwin.close(fd); fd = -1 } }

    private func wait(_ events: Int16, deadline: IOSRunnerDeadline) throws {
        while true {
            let remaining = try deadline.remaining()
            var descriptor = pollfd(fd: fd, events: events, revents: 0)
            let result = Darwin.poll(&descriptor, 1, Int32(min(Double(Int32.max), ceil(remaining * 1000))))
            if result < 0, errno == EINTR { continue }
            guard result > 0 else { throw IOSRunnerWireError(result == 0 ? "deadline_exceeded" : "socket_poll_failed") }
            guard descriptor.revents & Int16(POLLNVAL) == 0 else { throw IOSRunnerWireError("socket_invalid") }
            if descriptor.revents & events != 0 { return }
            throw IOSRunnerWireError("socket_closed")
        }
    }
    private func connect(_ address: UnsafePointer<sockaddr>, length: socklen_t, deadline: IOSRunnerDeadline) throws {
        _ = try deadline.remaining()
        let result = Darwin.connect(fd, address, length)
        if result == 0 { return }
        guard errno == EINPROGRESS || errno == EWOULDBLOCK || errno == EINTR else { throw IOSRunnerWireError("socket_connect_failed") }
        try wait(Int16(POLLOUT), deadline: deadline)
        var error: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &size) == 0, error == 0 else {
            throw IOSRunnerWireError("socket_connect_failed")
        }
    }
    func connectUSB(deadline: IOSRunnerDeadline) throws {
        var address = sockaddr_un()
        let path = Array("/var/run/usbmuxd".utf8) + [0]
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in buffer.copyBytes(from: path) }
        try withUnsafePointer(to: &address) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try connect($0, length: socklen_t(MemoryLayout<sockaddr_un>.size), deadline: deadline)
            }
        }
    }
    func connectLoopback(port: UInt16, deadline: IOSRunnerDeadline) throws {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        try withUnsafePointer(to: &address) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try connect($0, length: socklen_t(MemoryLayout<sockaddr_in>.size), deadline: deadline)
            }
        }
    }
    func write(_ data: Data, deadline: IOSRunnerDeadline) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < data.count {
                try wait(Int16(POLLOUT), deadline: deadline)
                let count = Darwin.send(fd, buffer.baseAddress!.advanced(by: offset), data.count - offset, 0)
                if count < 0, errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK { continue }
                guard count > 0 else { throw IOSRunnerWireError("socket_write_failed") }
                offset += count
            }
        }
    }
    private func read(upTo limit: Int, deadline: IOSRunnerDeadline) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: limit)
        while true {
            try wait(Int16(POLLIN), deadline: deadline)
            let count = Darwin.recv(fd, &buffer, limit, 0)
            if count < 0, errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK { continue }
            guard count > 0 else { throw IOSRunnerWireError("socket_read_closed") }
            return Data(buffer.prefix(count))
        }
    }
    private func readExactly(_ size: Int, deadline: IOSRunnerDeadline) throws -> Data {
        var data = Data()
        while data.count < size { data.append(try read(upTo: min(65536, size - data.count), deadline: deadline)) }
        return data
    }
    func mux(_ message: [String: Any], tag: UInt32, deadline: IOSRunnerDeadline) throws -> [String: Any] {
        try write(IOSRunnerMux.frame(message, tag: tag), deadline: deadline)
        let header = try readExactly(16, deadline: deadline)
        let length = try IOSRunnerMux.payloadLength(header, expectedTag: tag)
        return try IOSRunnerMux.parseFrame(header + readExactly(length, deadline: deadline), expectedTag: tag)
    }
    func readHTTP(deadline: IOSRunnerDeadline) throws -> Data {
        var data = Data()
        while true {
            if let header = try IOSRunnerWire.httpHeader(data) {
                let expected = header.bodyOffset + header.bodyLength
                guard data.count <= expected else { throw IOSRunnerWireError("http_trailing_data") }
                while data.count < expected {
                    data.append(try read(upTo: min(65536, expected - data.count), deadline: deadline))
                }
                return data
            }
            data.append(try read(upTo: min(4096, IOSRunnerWire.maximumHeaderBytes + 1 - data.count), deadline: deadline))
        }
    }
}
