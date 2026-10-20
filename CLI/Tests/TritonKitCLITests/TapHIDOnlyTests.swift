import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("SP-218 HID-only tap boundaries")
struct TapHIDOnlyTests {
    @Test("HID-only explicitly accepts local Simulator selectors without AX resolution")
    func acceptsSimulatorCoordinates() throws {
        let uuid = "A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"
        for platform in [[], ["--platform", "ios"]] {
            for selector in ["booted", "current", uuid, "sim:\(uuid)"] {
                let command = try Tap.parse(platform + ["--device", selector, "--at", "470,1000", "--hid-only"])
                let request = try #require(try command.hidOnlyCoordinateTapRequest())
                #expect(request.device == selector)
                #expect(request.x == 470)
                #expect(request.y == 1000)
            }
        }
        let command = try Tap.parse(["--platform", "ios", "--x", "12.5", "--y", "20", "--hid-only"])
        let request = try #require(try command.hidOnlyCoordinateTapRequest())
        #expect(request.device == nil)
        #expect(request.x == 12.5)
    }

    @Test("HID-only rejects non-host and non-iOS targets before any I/O")
    func rejectsUnsupportedTargets() throws {
        let invalid: [[String]] = [
            [], ["--platform", "android"], ["--platform", "harmony"],
            ["--device", "local"], ["--device", "sim:invalid"],
            ["--device", "ios-real:phone"], ["--device", "android:emulator-5554"],
            ["--device", "triton:ios-simulator:A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D/app:com.example.fixture"],
            ["--platform", "ios", "--device", "triton:ios-simulator:A0B1C2D3-E4F5-4A6B-8C9D-0E1F2A3B4C5D"],
        ]
        for arguments in invalid {
            let command = try Tap.parse(arguments + ["--at", "10,20", "--hid-only"])
            #expect(throws: HIDOnlyTapValidationError.self) { try command.hidOnlyCoordinateTapRequest() }
        }
    }

    @Test("HID-only rejects semantic, selection, WebView and incompatible tap options before I/O")
    func rejectsIncompatibleOptions() throws {
        let invalid: [[String]] = [
            ["Continue"], ["--text", "Continue"], ["--oid", "1"], ["--ax-oid", "1"], ["--ax-label", "Continue"],
            ["--selection", "selection-1"], ["--selection-revision", "1"], ["--runtime-instance-id", "runtime-1"],
            ["--webview-aware"], ["--selector", "button"], ["--webview-id", "web-1"],
            ["--page-session-id", "page-1"], ["--expect-text", "Done"], ["--timeout", "1"],
            ["--strategy", "exact"], ["--index", "1"], ["--within", "0,0,100,100"],
            ["--allow-host-hid-fallback"], ["--duration", "1"], ["--width", "100"], ["--height", "100"],
        ]
        for arguments in invalid {
            let command = try Tap.parse(["--device", "booted", "--at", "10,20", "--hid-only"] + arguments)
            #expect(throws: HIDOnlyTapValidationError.self) { try command.hidOnlyCoordinateTapRequest() }
        }
    }

    @Test("HID-only requires exactly one finite coordinate pair")
    func requiresFiniteCoordinatePair() throws {
        for arguments in [[], ["--x", "10"], ["--y", "20"], ["--at", "nan,20"], ["--at", "10,inf"], ["--at", "bad"], ["--at", "10,20", "--x", "10", "--y", "20"]] {
            let command = try Tap.parse(["--device", "booted", "--hid-only"] + arguments)
            #expect(throws: HIDOnlyTapValidationError.self) { try command.hidOnlyCoordinateTapRequest() }
        }
        for value in [Double.nan, .infinity, -.infinity] {
            var command = try Tap.parse(["--device", "booted", "--hid-only", "--x", "10", "--y", "20"])
            command.x = value
            #expect(throws: HIDOnlyTapValidationError.self) { try command.hidOnlyCoordinateTapRequest() }
        }
    }

    @Test("default explicit iOS remains AX and help makes the dispatch distinction explicit")
    func preservesDefaultAXRouting() throws {
        let command = try Tap.parse(["--platform", "ios", "--device", "booted", "--at", "10,20"])
        #expect(!command.hidOnly)
        #expect(try command.hidOnlyCoordinateTapRequest() == nil)
        #expect(!shouldRouteImplicitIOSHostCoordinateTap(platform: command.platform, target: command.target, query: nil, x: nil, y: nil, at: command.at, oid: nil, axOID: nil, axLabel: nil))
        let help = Tap.helpMessage()
        #expect(help.contains("--hid-only"))
        #expect(help.contains("AX"))
        #expect(help.contains("HID"))
    }

    @Test("AX receipts expose their strategy and required business-state verification")
    func axReceiptAndSchemaExposeVerification() throws {
        let target = HostDeviceTarget(platform: "ios", id: "sim:fixture", target: "fixture", state: "booted", ready: true, source: "simctl", name: nil, runtime: nil, transport: nil)
        let match = TKAXNode(role: "button", label: "Continue", value: nil, identifier: nil, title: nil, frame: .init(x: 0, y: 0, width: 20, height: 20), enabled: true, focused: false, hidden: false, targetOID: nil, className: nil, children: [])
        let receipt = HostIOSTapOutput(ok: true, action: "tap", platform: "ios", target: target, query: "Continue", x: 10, y: 10, match: match, sourceCommands: [], note: "Verify the business state")
        let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
        #expect(object["source"] as? String == "host-ax")
        #expect(object["strategy"] as? String == "accessibility-perform-press")
        #expect((object["verification"] as? [String: Any])?["required"] as? Bool == true)
        let fields = hostIOSTapOutputContract().fields
        for name in ["source", "strategy", "verification", "verification.required"] {
            #expect(fields.contains { $0.name == name && $0.required })
        }
    }
}
