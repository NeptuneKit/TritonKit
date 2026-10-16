// This file is also compiled by the CLI. Keep the two copies byte-identical;
// IOSRunnerResourcesTests verifies the shipped source against the client.
import CryptoKit
import Foundation

struct RunnerSecureChannelError: Error {
    let cause: String
    init(_ cause: String) { self.cause = cause }
}

/// Session PSK protocol v2. One fresh handshake, one request and one response per
/// connection. No token is transmitted, even inside the authenticated ciphertext.
/// This authenticates possession of the session key, not a process or device ID.
struct RunnerSecureChannel {
    static let magic = Data("TRITON2\n".utf8)
    static let helloSize = 40
    static let proofSize = 72
    static let maximumRequestBytes = 80 * 1024
    static let maximumResponseBytes = 12 * 1024 * 1024 + 16 * 1024
    let proof: Data
    private let transcript: Data
    private let requestKey: SymmetricKey
    private let responseKey: SymmetricKey

    static func clientHello() -> Data {
        magic + SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    private static func binding(session: String, hello: Data, serverNonce: Data) throws -> Data {
        guard hello.count == helloSize, hello.prefix(magic.count) == magic, serverNonce.count == 32,
              !session.isEmpty, session.utf8.count <= 256 else {
            throw RunnerSecureChannelError("authentication_handshake_invalid")
        }
        let sessionBytes = Data(session.utf8)
        return Data("TritonRunner/v2/server-proof\0".utf8) + lengthBytes(sessionBytes.count) + sessionBytes + hello + serverNonce
    }

    private init(token: String, session: String, hello: Data, serverNonce: Data) throws {
        guard token.utf8.count >= 16, token.utf8.count <= 4096 else {
            throw RunnerSecureChannelError("authentication_key_invalid")
        }
        transcript = try Self.binding(session: session, hello: hello, serverNonce: serverNonce)
        let key = SymmetricKey(data: Data(token.utf8))
        let proofKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: key, salt: hello + serverNonce,
            info: Data("TritonRunner/v2/proof-key".utf8), outputByteCount: 32)
        let tag = HMAC<SHA256>.authenticationCode(for: transcript, using: proofKey)
        proof = Self.magic + serverNonce + Data(tag)
        requestKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: key, salt: hello + serverNonce,
            info: Data("TritonRunner/v2/request-key\0".utf8) + transcript, outputByteCount: 32)
        responseKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: key, salt: hello + serverNonce,
            info: Data("TritonRunner/v2/response-key\0".utf8) + transcript, outputByteCount: 32)
    }

    static func server(token: String, session: String, hello: Data) throws -> Self {
        let nonce = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        return try Self(token: token, session: session, hello: hello, serverNonce: nonce)
    }

    static func client(token: String, session: String, hello: Data, proof: Data) throws -> Self {
        guard proof.count == proofSize, proof.prefix(magic.count) == magic else {
            throw RunnerSecureChannelError("authentication_handshake_invalid")
        }
        let nonce = Data(proof[8..<40])
        let channel = try Self(token: token, session: session, hello: hello, serverNonce: nonce)
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(token.utf8)), salt: hello + nonce,
            info: Data("TritonRunner/v2/proof-key".utf8), outputByteCount: 32)
        guard HMAC<SHA256>.isValidAuthenticationCode(Data(proof.suffix(32)), authenticating: channel.transcript, using: key) else {
            throw RunnerSecureChannelError("authentication_server_unverified")
        }
        return channel
    }

    private static func lengthBytes(_ value: Int) -> Data {
        let n = UInt32(value)
        return Data([UInt8(truncatingIfNeeded: n >> 24), UInt8(truncatingIfNeeded: n >> 16),
                     UInt8(truncatingIfNeeded: n >> 8), UInt8(truncatingIfNeeded: n)])
    }

    static func frameLength(_ header: Data, maximumPlaintext: Int) throws -> Int {
        guard header.count == 4 else { throw RunnerSecureChannelError("authentication_frame_invalid") }
        let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        // CryptoKit combined layout: 12-byte nonce, ciphertext, 16-byte tag.
        guard length >= 28, length <= maximumPlaintext + 28 else {
            throw RunnerSecureChannelError("authentication_frame_budget")
        }
        return Int(length)
    }

    private func seal(_ data: Data, key: SymmetricKey, direction: String, maximum: Int) throws -> Data {
        guard data.count <= maximum else { throw RunnerSecureChannelError("authentication_frame_budget") }
        let box = try AES.GCM.seal(data, using: key, authenticating: transcript + Data(direction.utf8))
        guard let combined = box.combined else { throw RunnerSecureChannelError("authentication_frame_invalid") }
        return Self.lengthBytes(combined.count) + combined
    }

    private func open(_ frame: Data, key: SymmetricKey, direction: String, maximum: Int) throws -> Data {
        let count = try Self.frameLength(Data(frame.prefix(4)), maximumPlaintext: maximum)
        guard frame.count == count + 4 else { throw RunnerSecureChannelError("authentication_frame_invalid") }
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: frame.dropFirst(4)), using: key,
                authenticating: transcript + Data(direction.utf8))
        } catch { throw RunnerSecureChannelError("authentication_message_invalid") }
    }

    func sealRequest(_ data: Data) throws -> Data {
        try seal(data, key: requestKey, direction: "request", maximum: Self.maximumRequestBytes)
    }
    func openRequest(_ frame: Data) throws -> Data {
        try open(frame, key: requestKey, direction: "request", maximum: Self.maximumRequestBytes)
    }
    func sealResponse(_ data: Data) throws -> Data {
        try seal(data, key: responseKey, direction: "response", maximum: Self.maximumResponseBytes)
    }
    func openResponse(_ frame: Data) throws -> Data {
        try open(frame, key: responseKey, direction: "response", maximum: Self.maximumResponseBytes)
    }
}
