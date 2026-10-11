import Foundation
import Testing
@testable import TritonKitShared

@Suite("Independent explicit Apple physical inventory")
struct TKApplePhysicalInventoryTests {
    func payload(_ devices: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["info": ["outcome": "success"], "result": ["devices": devices]])
    }
    @Test func allFamiliesWithExactProvenance() throws {
        let families = ["iOS", "iPadOS", "watchOS", "tvOS", "xrOS", "macOS"]
        let data = try payload(families.enumerated().map { index, family in
            ["identifier": "PRIVATE-\(index)", "properties": ["hardware": ["platform": family, "reality": "physical"]]]
        })
        let values = try TKApplePhysicalInventoryParser.parse(data)
        #expect(values.count == 6 && values.first { $0.matches(selector: "PRIVATE-2") }?.observation.systemFamily == .watchos)
        #expect(values.allSatisfy { $0.observation.reality == .physical && !$0.observation.actionCapabilitiesVerified })
        #expect(!String(decoding: try JSONEncoder().encode(values), as: UTF8.self).contains("PRIVATE"))
        #expect(values.contains { $0.matches(selector: "PRIVATE-0") })
        #expect(values[0].matches(selector: values[0].id))
        #expect(!values[0].matches(selector: "PRIVATE"))
    }
    @Test func noLegacyInferenceAndModernAuthority() throws {
        let data = try payload([
            ["identifier": "one", "hardwareProperties": ["platform": "watchOS", "reality": "physical"]],
            ["identifier": "two", "properties": NSNull(), "hardwareProperties": ["platform": "tvOS", "reality": "physical"]],
            ["identifier": "three", "properties": ["hardware": ["platform": "iOS", "reality": "simulated"]]],
            ["identifier": "four", "hardwareProperties": ["platform": "iOS"]]
        ])
        let values = try TKApplePhysicalInventoryParser.parse(data)
        #expect(values.count == 1 && values[0].observation.sourceLayout == "legacy-hardware-properties")
    }
    @Test func unknownPhysicalAndNoCapabilityInference() throws {
        let data = try payload([["identifier": "PRIVATE", "properties": ["hardware": ["platform": "UNRECOGNIZED", "deviceType": "AppleWatch Pro", "reality": "physical"], "capabilities": ["watch-control"]]]])
        let values = try TKApplePhysicalInventoryParser.parse(data)
        #expect(values.count == 1 && values[0].observation.systemFamily == .unknown && values[0].observation.deviceFamily == .unknown)
        let encoded = String(decoding: try JSONEncoder().encode(values), as: UTF8.self)
        #expect(!encoded.contains("UNRECOGNIZED") && !encoded.contains("watch-control") && !encoded.contains("PRIVATE"))
    }
    @Test func malformedErrorAndDuplicatesFail() throws {
        let record: [String: Any] = ["identifier": "one", "hardwareProperties": ["platform": "watchOS", "reality": "physical"]]
        #expect(throws: TKApplePhysicalInventoryError.self) { _ = try TKApplePhysicalInventoryParser.parse(payload([record, record])) }
        for json in [#"{}"#, #"{"result":{"devices":[]}}"#, #"{"info":null,"result":{"devices":[]}}"#, #"{"info":{"outcome":"failure"},"result":{"devices":[]}}"#, #"{"error":{},"result":{"devices":[]}}"#] {
            #expect(throws: TKApplePhysicalInventoryError.self) { _ = try TKApplePhysicalInventoryParser.parse(Data(json.utf8)) }
        }
    }
}
