import Foundation
import Testing
@testable import TritonKitShared

@Suite("Explicit hardware platform observation, not legacy dispatch inference")
struct TKAppleHardwareObservationTests {
    private func details(_ hardware: [String: Any], modern: Bool = true) throws -> TKDevicectlDeviceDetails {
        var result: [String: Any] = ["identifier": "PRIVATE-ID", "deviceProperties": ["name": "iPad-PRO-PRIVATE", "osVersionNumber": "27.1"]]
        if modern { result["properties"] = ["hardware": hardware, "state": ["name": "iPad-PRIVATE", "osVersionNumber": "27.1"]]; result["hardwareProperties"] = ["platform": "tvOS", "deviceType": "AppleTV", "reality": "simulated"] }
        else { result["hardwareProperties"] = hardware }
        return try TKDevicectlDeviceInfoParser.parseDetails(JSONSerialization.data(withJSONObject: ["result": result]))
    }
    @Test func explicitModernAndLegacy() throws {
        for modern in [true, false] {
            let value = try details(["platform": "iOS", "deviceType": "iPad", "reality": "physical", "productType": "iPhone-PRIVATE", "marketingName": "Apple Vision Pro"], modern: modern)
            let observation = try #require(value.hardware.platformObservation)
            #expect(observation.systemFamily == .ios && observation.deviceFamily == .ipad && observation.reality == .physical)
            #expect(observation.sourceLayout == (modern ? "modern-properties-hardware" : "legacy-hardware-properties"))
            #expect(observation.authority == "explicit-sdk-hardware-only")
            #expect(!observation.actionCapabilitiesVerified && !observation.businessReadinessVerified && !observation.legacyNamespaceIsOperatingSystemProof)
            #expect(value.device.platform == "ios")
        }
    }
    @Test func knownSystemFamilies() throws {
        for (raw, expected) in [("iOS", TKAppleObservedSystemFamily.ios), ("iPadOS", .ipados), ("watchOS", .watchos), ("tvOS", .tvos), ("xrOS", .visionos), ("visionOS", .visionos), ("macOS", .macos)] {
            let observation = try #require(details(["platform": raw, "reality": "simulated"]).hardware.platformObservation)
            #expect(observation.systemFamily == expected && observation.reality == .simulated && observation.deviceFamily == .unknown)
        }
        for (raw, expected) in [("iPhone", TKAppleObservedDeviceFamily.iphone), ("iPad", .ipad), ("AppleWatch", .watch), ("Watch", .watch), ("AppleTV", .tv), ("RealityDevice", .spatial), ("Mac", .mac)] {
            let observation = try #require(details(["deviceType": raw]).hardware.platformObservation)
            #expect(observation.deviceFamily == expected && observation.systemFamily == .unknown && observation.reality == .unknown)
        }
    }
    @Test func neverInferOrEchoUnknown() throws {
        for hardware: [String: Any] in [[:], ["platform": NSNull(), "deviceType": 1, "reality": true], ["platform": "PRIVATE-PLATFORM", "deviceType": "PRIVATE-TYPE", "reality": "PRIVATE-REALITY"], ["platform": " iOS", "deviceType": "iPad Pro", "reality": "Physical"], ["platform": "iOS\n", "reality": "physical\n"], ["platform": "ｉＯＳ", "reality": "simulated\u{0}"]] {
            var input = hardware; input["marketingName"] = "iPad"; input["productType"] = "iPad99,1"; input["capabilities"] = ["control-all"]
            let value = try details(input)
            let observation = try #require(value.hardware.platformObservation)
            #expect(observation.systemFamily == .unknown && observation.deviceFamily == .unknown && observation.reality == .unknown)
            let encoded = String(decoding: try JSONEncoder().encode(observation), as: UTF8.self)
            #expect(!encoded.contains("PRIVATE") && !encoded.contains("control-all") && !encoded.contains("iPad99"))
        }
    }
    @Test func modernPresenceNeverResurrectsLegacy() throws {
        for properties: Any in [NSNull(), [String: Any](), ["hardware": NSNull()], "bad", ["hardware": ["platform": NSNull()]]] {
            let data = try JSONSerialization.data(withJSONObject: ["result": ["identifier": "PRIVATE", "properties": properties, "hardwareProperties": ["platform": "iOS", "deviceType": "iPad", "reality": "physical"]]])
            let observation = try #require(TKDevicectlDeviceInfoParser.parseDetails(data).hardware.platformObservation)
            #expect(observation.systemFamily == .unknown && observation.deviceFamily == .unknown && observation.reality == .unknown && observation.sourceLayout == "modern-properties-hardware")
        }
    }
    @Test func oldHardwareCodableAndNestedRoundtrip() throws {
        let old = try JSONDecoder().decode(TKDevicectlHardwareInfo.self, from: Data(#"{"productType":"Fixture,1","cpuType":"arm64"}"#.utf8))
        #expect(old.platformObservation == nil)
        let hardware = try details(["platform": "iOS", "deviceType": "iPhone", "reality": "physical"]).hardware
        #expect(try JSONDecoder().decode(TKDevicectlHardwareInfo.self, from: JSONEncoder().encode(hardware)) == hardware)
        #expect(hardware.platformObservation?.deviceFamily == .iphone)
    }
}
