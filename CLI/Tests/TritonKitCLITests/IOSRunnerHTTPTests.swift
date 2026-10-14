import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing
@testable import TritonKitCLI

@Suite("iOS resident Runner HTTP contracts")
struct IOSRunnerHTTPTests {
    @Test func serviceEnvelopePassesThroughWithoutWrapping() async throws {
        let raw = Data(#"{"ok":false,"sessionID":"s","requestID":"r","error":{"code":"outcome_unknown","message":"Lookup receipt"}}"#.utf8)
        let router = Router(context: BasicRequestContext.self)
        registerIOSRunnerRoutes(on: router, execute: { operation, payload in
            #expect(operation == "request")
            let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
            #expect(object?["device"] as? String == "ios-real:test")
            return raw
        })
        try await Application(router: router).test(.router) { client in
            let response = try await client.execute(uri: "/v1/device/runner/request", method: .post, headers: [.contentType: "application/json"], body: ByteBuffer(string: #"{"device":"ios-real:test","body":{"operation":"tap"}}"#))
            #expect(response.status == .conflict)
            #expect(Data(buffer: response.body) == raw)
        }
    }
    @Test func invalidAndOversizedBodiesDoNotReachService() async throws {
        let router = Router(context: BasicRequestContext.self)
        registerIOSRunnerRoutes(on: router, execute: { _, _ in
            Issue.record("Invalid payload must not execute")
            return Data(#"{"ok":true}"#.utf8)
        })
        try await Application(router: router).test(.router) { client in
            for raw in ["[]", "{}", #"{"device":""}"#] {
                let response = try await client.execute(uri: "/v1/device/runner/start", method: .post, body: ByteBuffer(string: raw))
                #expect(response.status == .badRequest)
            }
            let large = try await client.execute(uri: "/v1/device/runner/request", method: .post, body: ByteBuffer(bytes: [UInt8](repeating: 32, count: 65537)))
            #expect(large.status == .contentTooLarge)
        }
    }
    @Test func getStatusSelectsExplicitDeviceWithoutEmbeddedRuntime() async throws {
        let router = Router(context: BasicRequestContext.self)
        registerIOSRunnerRoutes(on: router, execute: { operation, payload in
            #expect(operation == "status")
            let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
            #expect(object?["device"] as? String == "sim:test")
            return Data(#"{"ok":true,"result":{"ready":false,"state":"not-started"}}"#.utf8)
        })
        try await Application(router: router).test(.router) { client in
            let response = try await client.execute(uri: "/v1/device/runner/status?device=sim:test", method: .get)
            #expect(response.status == .ok)
        }
    }
    @Test func receiptScreenshotRecoveryPayloadPassesThrough() async throws {
        let router = Router(context: BasicRequestContext.self)
        registerIOSRunnerRoutes(on: router, execute: { operation, payload in
            #expect(operation == "receipt")
            let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
            #expect(object?["requestID"] as? String == "shot-1")
            #expect(object?["screenshotOutput"] as? String == "/private/recovered.png")
            return Data(#"{"ok":true,"result":{"state":"completed","response":{"ok":true,"result":{"artifact":{"path":"/private/recovered.png"}}}}}"#.utf8)
        })
        try await Application(router: router).test(.router) { client in
            let response = try await client.execute(uri: "/v1/device/runner/receipt", method: .post,
                body: ByteBuffer(string: #"{"device":"sim:test","requestID":"shot-1","screenshotOutput":"/private/recovered.png"}"#))
            #expect(response.status == .ok)
        }
    }
    @Test func thrownServiceFailureIsSingleSanitizedEnvelope() async throws {
        let router = Router(context: BasicRequestContext.self)
        registerIOSRunnerRoutes(on: router, execute: { _, _ in throw NSError(domain: "secret-token", code: 9) })
        try await Application(router: router).test(.router) { client in
            let response = try await client.execute(uri: "/v1/device/runner/stop", method: .post, body: ByteBuffer(string: #"{"device":"sim:test"}"#))
            let string = String(decoding: Data(buffer: response.body), as: UTF8.self)
            #expect(!string.contains("secret-token"))
            let envelope = try #require(try JSONSerialization.jsonObject(with: Data(buffer: response.body)) as? [String: Any])
            #expect(envelope["ok"] as? Bool == false)
            #expect(envelope["result"] == nil)
        }
    }
}
