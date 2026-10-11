import Foundation
import Testing
@testable import TritonKitShared

@Suite("SDK explicit application container binding")
struct TKAppContainerBindingTests {
    private func data(apps: [[String: Any]], arguments: [String] = ["--device", "fixture-device", "--bundle-id", "example.app", "--include-all-apps", "--include-container-paths", "--include-app-group-identifiers"], outcome: String = "success", error: Bool = false) throws -> Data {
        var root: [String: Any] = ["info": ["commandType": "devicectl.device.info.apps", "outcome": outcome, "arguments": arguments], "result": ["deviceIdentifier": "fixture-device", "apps": apps]]
        if error { root["error"] = ["message": "private failure"] }
        return try JSONSerialization.data(withJSONObject: root)
    }
    private var app: [String: Any] { ["bundleIdentifier": "example.app", "name": "not-identity", "containerAccessible": true, "dataContainerPath": "/private/app", "appGroupIdentifiers": ["group.example"], "groupContainerPaths": ["group.example": "/private/group"]] }
    @Test func explicitBindingAndLegacyUnavailable() throws {
        let bound = try TKAppContainerBindingParser.parse(data(apps: [app]), bundleIdentifier: "example.app")
        #expect(bound.containerPath == "/private/app" && bound.bindingStatus == "sdk-bound")
        let group = try TKAppContainerBindingParser.parse(data(apps: [app]), bundleIdentifier: "example.app", groupIdentifier: "group.example")
        #expect(group.containerPath == "/private/group")
        let legacy = try TKAppContainerBindingParser.parse(data(apps: [["bundleIdentifier": "example.app"]]), bundleIdentifier: "example.app")
        #expect(legacy.bindingStatus == "unavailable" && legacy.containerPath == nil)
    }
    @Test func rejectsAmbiguousInvalidAndUnboundReplies() throws {
        var wrong = app; wrong["bundleIdentifier"] = "different.app"
        var escape = app; escape["dataContainerPath"] = "/private/../outside"
        var badGroup = app; badGroup["appGroupIdentifiers"] = ["group.other"]
        for apps in [[], [app, app], [wrong], [escape]] {
            #expect(throws: TKAppContainerBindingError.self) { _ = try TKAppContainerBindingParser.parse(data(apps: apps), bundleIdentifier: "example.app") }
        }
        #expect(throws: TKAppContainerBindingError.self) { _ = try TKAppContainerBindingParser.parse(data(apps: [badGroup]), bundleIdentifier: "example.app", groupIdentifier: "group.example") }
        for (outcome, error) in [("failed", false), ("success", true)] {
            #expect(throws: TKAppContainerBindingError.self) { _ = try TKAppContainerBindingParser.parse(data(apps: [app], outcome: outcome, error: error), bundleIdentifier: "example.app") }
        }
        #expect(throws: TKAppContainerBindingError.self) { _ = try TKAppContainerBindingParser.parse(data(apps: [app], arguments: ["--device", "fixture-device", "--device", "fixture-device"]), bundleIdentifier: "example.app") }
        #expect(throws: TKAppContainerBindingError.limitExceeded) { _ = try TKAppContainerBindingParser.parse(data(apps: [app]), bundleIdentifier: "example.app", maximumJSONBytes: 1) }
    }
    @Test func groupRequiresMembershipAndExplicitPathAndKeepsByteIdentity() throws {
        var missingMap = app; missingMap.removeValue(forKey: "groupContainerPaths")
        var missingMembership = app; missingMembership.removeValue(forKey: "appGroupIdentifiers")
        var duplicates = app; duplicates["appGroupIdentifiers"] = ["group.example", "group.example"]
        for item in [missingMap, missingMembership, duplicates] {
            #expect(throws: TKAppContainerBindingError.self) { _ = try TKAppContainerBindingParser.parse(data(apps: [item]), bundleIdentifier: "example.app", groupIdentifier: "group.example") }
        }
        var canonicallyEquivalent = app; canonicallyEquivalent["bundleIdentifier"] = "example.cafe\u{301}"
        #expect(throws: TKAppContainerBindingError.self) { _ = try TKAppContainerBindingParser.parse(data(apps: [canonicallyEquivalent], arguments: ["--device", "fixture-device", "--bundle-id", "example.café", "--include-all-apps", "--include-container-paths", "--include-app-group-identifiers"]), bundleIdentifier: "example.café") }
    }

}
