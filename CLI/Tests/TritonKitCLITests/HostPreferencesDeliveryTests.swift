import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct HostPreferencesDeliveryTests {
    @Test("presence distinguishes false zero empty and missing")
    func presence() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["false": false, "zero": 0, "empty": ""], format: .binary, options: 0)
        for key in ["false", "zero", "empty", "missing"] {
            let result = try hostPreferencePresence(existingData: data, key: key)
            #expect(result.present == (key != "missing"))
        }
    }

    @Test("strict plist import rejects Date even if outside whitelist")
    func rejectsUnsupportedPlist() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["selected": true, "ignored": Date()], format: .binary, options: 0)
        #expect(throws: (any Error).self) { try parseHostPreferenceImport(data: data, format: .plist, keys: ["selected"]) }
    }

    @Test("relaunch stages preserve disk success and stop before launch when terminate fails")
    func relaunchFailures() throws {
        for failedStage in ["terminate", "launch"] {
            var commands: [TKHostCommand] = []
            let result = performHostPreferencesRelaunch(simulator: "fixture", bundleID: "com.example.app", requested: true) { command in
                commands.append(command)
                let code: Int32 = command.arguments.contains(failedStage) ? 1 : 0
                return prefFixtureResult(code: code)
            }
            #expect(result.status == "\(failedStage)-failed")
            #expect(result.runtimeConsumptionVerified == false)
            #expect(commands.count == (failedStage == "terminate" ? 1 : 2))
        }
    }

    @Test("default relaunch makes zero process calls")
    func noDefaultRelaunch() {
        let result = performHostPreferencesRelaunch(simulator: "fixture", bundleID: "com.example.app", requested: false) { _ in
            Issue.record("unexpected process action"); return prefFixtureResult(code: 0)
        }
        #expect(result.status == "not-requested")
        #expect(result.runtimeConsumptionVerified == false)
    }
}

private func prefFixtureResult(code: Int32) -> HostProcessResult {
    HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: code, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
}

@Suite
struct HostPreferencesImportDiskTests {
    @Test("invalid package fails before path lookup and leaves bytes unchanged")
    func invalidPackageDoesNotWrite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("preferences.plist")
        let original = try PropertyListSerialization.data(fromPropertyList: ["keep": true], format: .binary, options: 0)
        try original.write(to: path)
        var calls = 0
        #expect(throws: (any Error).self) {
            try importHostPreferences(simulator: "fixture", bundleID: "com.example.app", inputData: Data(#"{"selected":false,"unselected":null}"#.utf8), inputFormat: .json, keys: ["selected"], pathProvider: { calls += 1; return path.path })
        }
        #expect(calls == 0)
        #expect(try Data(contentsOf: path) == original)
    }

    @Test("import keeps unselected existing keys and reports write success despite relaunch failure")
    func failureReceiptKeepsDiskResult() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("preferences.plist")
        try PropertyListSerialization.data(fromPropertyList: ["keep": "private-existing"], format: .binary, options: 0).write(to: path)
        let result = try importHostPreferences(simulator: "fixture", bundleID: "com.example.app", inputData: Data(#"{"selected":false,"ignored":"private-input"}"#.utf8), inputFormat: .json, keys: ["selected", "selected"], relaunch: true, pathProvider: { path.path }, runner: { _ in prefFixtureResult(code: 1) })
        #expect(result.diskWriteVerified)
        #expect(!result.ok)
        #expect(result.relaunch.status == "terminate-failed")
        let json = try encodeJSON(result)
        #expect(!json.contains("private-existing"))
        #expect(!json.contains("private-input"))
        let dict = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: path), options: [], format: nil) as? [String: Any])
        #expect(dict["keep"] as? String == "private-existing")
        #expect(dict["selected"] as? Bool == false)
        #expect(dict["ignored"] == nil)
    }

    @Test("prefs parser defaults relaunch off and accepts repeated whitelist keys")
    func parser() throws {
        let command = try #require(HostAppPrefsImport.parseAsRoot(["--bundle-id", "com.example.app", "--input", "input.json", "--key", "a", "--key", "b"]) as? HostAppPrefsImport)
        #expect(command.keys == ["a", "b"])
        #expect(command.inputFormat == .json)
        #expect(!command.relaunch)
        let set = try #require(HostAppPrefsSet.parseAsRoot(["a", "false", "--bundle-id", "com.example.app"]) as? HostAppPrefsSet)
        #expect(!set.relaunch)
    }
}
