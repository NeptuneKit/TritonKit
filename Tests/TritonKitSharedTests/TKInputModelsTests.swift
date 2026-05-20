import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKInputModelsTests {
    @Test("tap request keeps Baguette-style wire fields")
    func tapRequestWireShape() throws {
        let request = TKInputRequest.tap(x: 12, y: 34, width: 390, height: 844, duration: 0.05)
        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["type"] as? String == "tap")
        #expect(json["x"] as? Double == 12)
        #expect(json["y"] as? Double == 34)
        #expect(json["width"] as? Double == 390)
        #expect(json["height"] as? Double == 844)
        #expect(json["duration"] as? Double == 0.05)
    }

    @Test("input command maps to shared request type")
    func inputCommandMapsToRequestType() {
        #expect(TKCLICommandRequest(type: "input").requestType == .input)
    }

    @Test("input result preserves unsupported message")
    func inputResultUnsupported() throws {
        let result = TKInputResult.unsupported(action: "button", message: "Host-side HID is not available")
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TKInputResult.self, from: data)

        #expect(!decoded.ok)
        #expect(decoded.action == "button")
        #expect(decoded.message == "Host-side HID is not available")
    }

    @Test("paste request preserves secure redaction intent")
    func pasteRequestWireShape() throws {
        let request = TKInputRequest.paste("aa123654", x: 180, y: 304, secure: true)
        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["type"] as? String == "paste")
        #expect(json["text"] as? String == "aa123654")
        #expect(json["x"] as? Double == 180)
        #expect(json["y"] as? Double == 304)
        #expect(json["secure"] as? Bool == true)
    }

    @Test("secure input result reports length without text")
    func secureInputResultShape() throws {
        let result = TKInputResult.success(
            action: "paste",
            message: "Inserted redacted text",
            secure: true,
            redacted: true,
            insertedLength: 8
        )

        let data = try JSONEncoder().encode(result)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let decoded = try JSONDecoder().decode(TKInputResult.self, from: data)

        #expect(json["secure"] as? Bool == true)
        #expect(json["redacted"] as? Bool == true)
        #expect(json["insertedLength"] as? Int == 8)
        #expect(json["text"] == nil)
        #expect(decoded.secure == true)
        #expect(decoded.redacted == true)
        #expect(decoded.insertedLength == 8)
    }
}
