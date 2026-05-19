import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKMessageTests {
    @Test("TKMessage preserves request type, id, and payload across JSON")
    func roundTripsMessage() throws {
        let payload = try JSONEncoder().encode(TKErrorPayload(message: "pong", code: 7))
        let message = TKMessage(id: 42, type: .ping, payload: payload)

        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(TKMessage.self, from: encoded)
        let decodedPayload = try #require(decoded.payload)
        let error = try JSONDecoder().decode(TKErrorPayload.self, from: decodedPayload)

        #expect(decoded.id == 42)
        #expect(decoded.type == .ping)
        #expect(error.message == "pong")
        #expect(error.code == 7)
    }
}
