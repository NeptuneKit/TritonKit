import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct HostPreferencesSetTests {
    @Test("preference JSON value parser accepts property-list compatible values")
    func parsesPropertyListCompatibleJSON() throws {
        #expect(try parseHostPreferenceJSONValue(#""enabled""#) == .string("enabled"))
        #expect(try parseHostPreferenceJSONValue("true") == .bool(true))
        #expect(try parseHostPreferenceJSONValue("42") == .int(42))
        #expect(try parseHostPreferenceJSONValue("3.5") == .double(3.5))
        #expect(try parseHostPreferenceJSONValue(#"["a", 1, false]"#) == .array([.string("a"), .int(1), .bool(false)]))
        #expect(try parseHostPreferenceJSONValue(#"{"mode":"debug","count":2}"#) == .dictionary(["mode": .string("debug"), "count": .int(2)]))
    }

    @Test("preference JSON value parser rejects null")
    func rejectsNull() throws {
        do {
            _ = try parseHostPreferenceJSONValue("null")
            Issue.record("Expected null to be rejected")
        } catch let error as RuntimeError {
            #expect(error.description.contains("Property list preferences do not support null"))
        }
    }

    @Test("preference plist update records previous and new value")
    func updatesPreferencePlist() throws {
        let original: [String: Any] = ["Existing": "old"]
        let data = try PropertyListSerialization.data(fromPropertyList: original, format: .binary, options: 0)

        let result = try updatingPreferencePlistData(
            existingData: data,
            bundleID: "com.example.app",
            plistPath: "/tmp/com.example.app.plist",
            key: "Existing",
            newValue: .dictionary(["enabled": .bool(true)])
        )

        #expect(result.previousValue == .string("old"))
        #expect(result.newValue == .dictionary(["enabled": .bool(true)]))
        let snapshot = try TKHostPreferencesSnapshot(bundleID: "com.example.app", plistPath: "/tmp/com.example.app.plist", data: result.data)
        #expect(snapshot.value(forKey: "Existing") == .dictionary(["enabled": .bool(true)]))
    }

    @Test("preference values encode as natural JSON values")
    func encodesNaturalJSONValues() throws {
        let output = HostPreferencesSetOutput(
            ok: true,
            action: "app.prefs.set",
            simulatorUDID: "booted",
            bundleID: "com.example.app",
            plistPath: "/tmp/com.example.app.plist",
            key: "Config",
            previousValue: .string("old"),
            newValue: .dictionary(["enabled": .bool(true), "count": .int(2)]),
            restartAdvice: "Restart if needed."
        )

        let json = try encodeJSON(output)
        #expect(json.contains(#""previousValue" : "old""#))
        #expect(json.contains(#""enabled" : true"#))
        #expect(json.contains(#""count" : 2"#))
        #expect(!json.contains(#""_0""#))
    }
}
