import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("SP-183 compatibility and safety audit fixtures")
struct CompatibilityAuditTests {
    @Test("legacy and modern devicectl inventory layouts keep the same readiness contract")
    func inventoryLayouts() throws {
        let legacy = Data(#"{"info":{"outcome":"success"},"result":{"devices":[{"identifier":"LEGACY-DEVICE","deviceProperties":{"name":"Fixture","osVersionNumber":"26.5","developerModeStatus":"enabled","ddiServicesAvailable":true},"hardwareProperties":{"platform":"iOS","udid":"PRIVATE-UDID"},"connectionProperties":{"transportType":"usb","pairingState":"paired","tunnelState":"connected"},"visibilityClass":"default"}]}}"#.utf8)
        let modern = Data(#"{"info":{"jsonVersion":5,"outcome":"success"},"result":{"devices":[{"identifier":"MODERN-DEVICE","properties":{"hardware":{"platform":"iOS","reality":"physical"},"connection":{"transportType":"usb","pairingState":"paired","state":"connected"},"state":{"name":"Fixture","developerModeStatus":{"enabled":{}},"visibilityClass":"default"},"software":{"osVersionNumber":{"stringValue":"26.5"}}}}]}}"#.utf8)
        let oldTarget = try #require(TKDevicectlDeviceListParser.parse(legacy).first)
        let newTarget = try #require(TKDevicectlDeviceListParser.parse(modern).first)
        #expect(oldTarget.platform == "ios" && newTarget.platform == "ios")
        #expect(oldTarget.scope == "real" && newTarget.scope == "real")
        #expect(oldTarget.kind == "real-device" && newTarget.kind == "real-device")
        #expect(oldTarget.ready && newTarget.ready)
        #expect(oldTarget.id != oldTarget.identifier && newTarget.id != newTarget.identifier)
        #expect(!String(decoding: try JSONEncoder().encode(newTarget), as: UTF8.self).contains("PRIVATE-UDID"))
    }

    @Test("old files envelope remains readable while modern envelope rejects contradictory metadata")
    func filesEnvelopeCompatibility() throws {
        let entry = #"{"name":"Report.ips","relativePath":"Report.ips","metadata":{"size":4},"resources":{"isDirectory":false,"isSymbolicLink":false}}"#
        let old = Data("{\"result\":{\"deviceIdentifier\":\"DEVICE\",\"domain\":\"systemCrashLogs\",\"files\":[\(entry)]}}".utf8)
        let modern = Data("{\"info\":{\"commandType\":\"devicectl.device.info.files\",\"outcome\":\"success\",\"arguments\":[\"--domain-type\",\"systemCrashLogs\"]},\"result\":{\"deviceIdentifier\":\"DEVICE\",\"domain\":\"systemCrashLogs\",\"files\":[\(entry)]}}".utf8)
        #expect(try TKDevicectlFilesParser.parse(old).domain == "systemCrashLogs")
        #expect(try TKDevicectlFilesParser.parse(modern).arguments == ["--domain-type", "systemCrashLogs"])
        let contradictory = Data(String(decoding: modern, as: UTF8.self).replacingOccurrences(of: "devicectl.device.info.files", with: "devicectl.device.info.apps").utf8)
        #expect(throws: TKDevicectlFilesError.self) { _ = try TKDevicectlFilesParser.parse(contradictory) }
        #expect(throws: TKDevicectlFilesError.self) { _ = try TKDevicectlFilesRequest(domain: "temporary") }
    }

    @Test("legacy SDK container layout never infers a path from app or directory names")
    func legacyContainerLayoutIsUnavailable() throws {
        let payload: [String: Any] = [
            "info": ["commandType": "devicectl.device.info.apps", "outcome": "success", "arguments": ["--device", "DEVICE", "--bundle-id", "example.app", "--include-all-apps", "--include-container-paths", "--include-app-group-identifiers"]],
            "result": ["deviceIdentifier": "DEVICE", "apps": [["bundleIdentifier": "example.app", "name": "Example App"]]],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = try TKAppContainerBindingParser.parse(data, bundleIdentifier: "example.app")
        #expect(result.bindingStatus == "unavailable")
        #expect(result.containerPath == nil)
        let group = try TKAppContainerBindingParser.parse(data, bundleIdentifier: "example.app", groupIdentifier: "group.example")
        #expect(group.bindingStatus == "unavailable" && group.containerPath == nil)
    }

    @Test("legacy Xcode arguments remain parseable and safety boundaries remain explicit")
    func xcodeAndSafetyCompatibility() throws {
        let build = try #require(TritonKitCLI.parseAsRoot(["xcode", "build", "--project", "Fixture.xcodeproj", "--scheme", "Fixture", "--device", "ios-real:fixture", "--jsonl"]) as? XcodeBuild)
        #expect(build.project == "Fixture.xcodeproj" && build.scheme == "Fixture")
        #expect(build.device == "ios-real:fixture")
        let request = try TKDevicectlFilesRequest(domain: "systemCrashLogs")
        #expect(request.domainIdentifier == nil)
        #expect(throws: TKDevicectlFilesError.self) { _ = try TKDevicectlFilesRequest(domain: "systemCrashLogs", domainIdentifier: "guessed") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("triton-compat-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("result.json")
        try Data("{}".utf8).write(to: source)
        let link = root.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        #expect(throws: HostDeviceFilesError.jsonMissing) { _ = try readBoundedDeviceFilesJSON(link.path, maximumBytes: 32) }
    }
}
