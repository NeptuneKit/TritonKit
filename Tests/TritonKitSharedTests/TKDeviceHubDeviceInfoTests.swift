import Foundation
import Testing
@testable import TritonKitShared

@Suite("Device Hub details and lock-state JSON")
struct TKDeviceHubDeviceInfoTests {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test("modern details preserve identity while projecting only safe hardware fields")
    func modernDetails() throws {
        let value = try TKDevicectlDeviceInfoParser.parseDetails(data(#"{"info":{"outcome":"success"},"result":{"identifier":"CORE-PRIVATE","properties":{"hardware":{"reality":"physical","platform":"iOS","productType":"iPhoneFixture,1","marketingName":"Fixture","cpuType":{"name":"arm64"},"serialNumber":"SECRET","udid":"PRIVATE-UDID","ecid":999},"state":{"name":"Fixture","bootState":"booted"},"connection":{"pairingState":"paired","state":"connected"}},"hardwareProperties":{"productType":"STALE"},"capabilities":[{"name":"must-not-enable"}]}}"#))
        #expect(value.device.identifier == "CORE-PRIVATE")
        #expect(value.hardware.productType == "iPhoneFixture,1")
        #expect(value.hardware.cpuType == "arm64")
        let encoded = String(decoding: try JSONEncoder().encode(value.hardware), as: UTF8.self)
        #expect(!encoded.contains("SECRET"))
        #expect(!encoded.contains("PRIVATE-UDID"))
        #expect(!encoded.contains("ecid"))
        #expect(!encoded.contains("capabilities"))
    }

    @Test("legacy details remain readable")
    func legacyDetails() throws {
        let value = try TKDevicectlDeviceInfoParser.parseDetails(data(#"{"result":{"identifier":"LEGACY","hardwareProperties":{"platform":"iOS","productType":"Legacy,1","cpuType":{"name":"arm64"}},"deviceProperties":{"name":"Legacy","osVersionNumber":"26.5"},"connectionProperties":{"pairingState":"paired"}}}"#))
        #expect(value.hardware.productType == "Legacy,1")
        #expect(value.device.runtime == "iOS 26.5")
    }

    @Test("present null or partial modern properties do not resurrect stale hardware", arguments: ["null", "{}", "{\"hardware\":{}}"])
    func modernUnknown(properties: String) throws {
        let value = try TKDevicectlDeviceInfoParser.parseDetails(data("{\"result\":{\"identifier\":\"PRIVATE\",\"properties\":\(properties),\"hardwareProperties\":{\"productType\":\"STALE\"}}}"))
        #expect(value.hardware.productType == nil)
        #expect(value.device.ready == false)
    }

    @Test("lock-state keeps observed booleans distinct from screen-lock/readiness claims")
    func lockState() throws {
        let value = try TKDevicectlDeviceInfoParser.parseLockState(data(#"{"info":{"outcome":"success"},"result":{"deviceIdentifier":"PRIVATE","passcodeRequired":false,"unlockedSinceBoot":true}}"#))
        #expect(value.deviceIdentifier == "PRIVATE")
        #expect(value.passcodeRequired == false)
        #expect(value.unlockedSinceBoot == true)
        let missing = try TKDevicectlDeviceInfoParser.parseLockState(data(#"{"result":{"deviceIdentifier":"PRIVATE"}}"#))
        #expect(missing.passcodeRequired == nil)
        #expect(missing.unlockedSinceBoot == nil)
    }

    @Test("unsupported lock classification requires exact structured CoreDevice failure")
    func unsupportedLockClassification() {
        let json = #"{"info":{"outcome":"failed"},"error":{"domain":"com.apple.dt.CoreDeviceError","code":1001,"userInfo":{"CapabilityFeatureIdentifier":{"string":"com.apple.coredevice.feature.getlockstate"}}}}"#
        #expect(TKDevicectlDeviceInfoParser.isLockStateUnsupported(data(json)))
        for (from, to) in [("failed", "success"), ("1001", "1002"), ("com.apple.dt.CoreDeviceError", "OtherError"), ("getlockstate", "otherfeature")] {
            #expect(!TKDevicectlDeviceInfoParser.isLockStateUnsupported(data(json.replacingOccurrences(of: from, with: to))))
        }
        #expect(!TKDevicectlDeviceInfoParser.isLockStateUnsupported(data("not-json")))
    }

    @Test("invalid envelopes and nonboolean lock values fail closed", arguments: [
        "not-json", #"{"result":null}"#, #"{"info":{"outcome":"failure"},"result":{"deviceIdentifier":"PRIVATE"}}"#,
        #"{"result":{"deviceIdentifier":"PRIVATE","passcodeRequired":1}}"#, #"{"result":{"deviceIdentifier":"PRIVATE","unlockedSinceBoot":"true"}}"#,
        #"{"result":{"passcodeRequired":false}}"#,
        #"{"error":{"code":1001},"result":{"deviceIdentifier":"PRIVATE"}}"#,
        #"{"info":{"outcome":"success"},"error":{"code":1001},"result":{"deviceIdentifier":"PRIVATE"}}"#,
    ])
    func invalidLockState(json: String) {
        #expect(throws: (any Error).self) { _ = try TKDevicectlDeviceInfoParser.parseLockState(data(json)) }
    }
}
