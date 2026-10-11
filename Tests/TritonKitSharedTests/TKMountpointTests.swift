import Foundation
import Testing
@testable import TritonKitShared

@Suite("DeviceFS mountpoint file-JSON")
struct TKMountpointTests {
    private let fixture = Data(#"{"info":{"arguments":["devicectl","device","info","mountpoint","--device","PRIVATE-ID"],"commandType":"devicectl.device.info.mountpoint","outcome":"success","jsonVersion":5},"result":{"dataPath":"/private/DeviceFS/device-PRIVATE-ID.localized","unknown":"IGNORE-ME"}}"#.utf8)
    @Test("real anonymous shape binds echoed device, not imagined result identity")
    func actualShape() throws {
        let payload = try TKDevicectlMountpointParser.parse(fixture)
        #expect(payload.deviceArgument == "PRIVATE-ID")
        #expect(payload.dataPath == "/private/DeviceFS/device-PRIVATE-ID.localized")
    }
    @Test("failed/contradictory/missing envelopes and unsafe paths fail closed", arguments: [
        ("\"outcome\":\"success\"", "\"outcome\":\"failed\""),
        ("\"commandType\":\"devicectl.device.info.mountpoint\"", "\"commandType\":\"devicectl.device.info.files\""),
        ("\"info\":", "\"error\":{\"code\":1001},\"info\":"),
        ("\"--device\",\"PRIVATE-ID\"", "\"--device\",\"PRIVATE-ID\",\"--device\",\"OTHER\""),
        ("\"--device\",\"PRIVATE-ID\"", "\"--device\""),
        ("\"--device\",\"PRIVATE-ID\"", "\"--device\",null"),
        ("/private/DeviceFS/device-PRIVATE-ID.localized", "relative/path"),
        ("/private/DeviceFS/device-PRIVATE-ID.localized", "/private/../escape"),
        ("/private/DeviceFS/device-PRIVATE-ID.localized", "/private//escape"),
        ("/private/DeviceFS/device-PRIVATE-ID.localized", "/"),
        ("/private/DeviceFS/device-PRIVATE-ID.localized", "/private/escape\\n")
    ])
    func malformed(input: (String, String)) {
        let data = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: input.0, with: input.1).utf8)
        #expect(throws: TKDevicectlMountpointError.malformedJSON) { _ = try TKDevicectlMountpointParser.parse(data) }
    }
    @Test("absent info/command type/outcome/argv or dataPath cannot attest identity")
    func absent() {
        for raw in ["{}", #"{"result":{"dataPath":"/private/path"}}"#, #"{"info":{"outcome":"success","arguments":["--device","PRIVATE-ID"]},"result":{"dataPath":"/private/path"}}"#] {
            #expect(throws: TKDevicectlMountpointError.malformedJSON) { _ = try TKDevicectlMountpointParser.parse(Data(raw.utf8)) }
        }
    }
    @Test("local JSON budgets are checked before decoding, including injected data")
    func limits() {
        for limit in [0, -1, 16_777_217, fixture.count - 1] {
            #expect(throws: TKDevicectlMountpointError.limitExceeded) { _ = try TKDevicectlMountpointParser.parse(fixture, maximumJSONBytes: limit) }
        }
    }
    @Test func nativeMountpointCommandDeclaresPossibleMountAutomation() {
        let command = TKDevicectlCommand.deviceInfoMountpoint(identifier: "fixture", jsonOutput: "/fixture/result.json", logOutput: "/fixture/native.log")
        #expect(command.riskLevel == .automation)
        #expect(command.requiredConfig.contains(.auditRecord))
    }

}
