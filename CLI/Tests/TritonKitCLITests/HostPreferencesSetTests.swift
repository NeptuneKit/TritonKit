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

    @Test("preference snapshot encodes data values with stable plist envelope")
    func encodesDataPreferenceEnvelope() throws {
        let bytes = Data(#"{"screen":"checkout"}"#.utf8)
        let original: [String: Any] = ["SeedState": bytes]
        let data = try PropertyListSerialization.data(fromPropertyList: original, format: .binary, options: 0)
        let snapshot = try TKHostPreferencesSnapshot(bundleID: "com.example.app", plistPath: "/tmp/com.example.app.plist", data: data)

        #expect(snapshot.value(forKey: "SeedState") == .data(bytes.base64EncodedString()))

        let output = HostPreferencesOutput(
            ok: true,
            action: "app.prefs.get",
            simulatorUDID: "booted",
            bundleID: "com.example.app",
            plistPath: "/tmp/com.example.app.plist",
            key: "SeedState",
            value: snapshot.value(forKey: "SeedState"),
            valuePlistType: snapshot.value(forKey: "SeedState")?.kind,
            preferences: nil,
            preferencesPlistTypes: nil
        )

        let json = try encodeJSON(output)
        #expect(json.contains(#""plistType" : "data""#))
        #expect(json.contains(#""base64" : "\#(bytes.base64EncodedString())""#))
        #expect(json.contains(#""length" : \#(bytes.count)"#))
        #expect(json.contains(#""valuePlistType" : "data""#))
        #expect(!json.contains(#""value" : []"#))
    }

    @Test("preference plist update writes explicit base64 data as plist Data")
    func writesExplicitBase64DataPreference() throws {
        let bytes = Data([0x5B, 0x7B, 0x7D, 0x5D])
        let newValue = try parseHostPreferenceSetValue(type: .data, value: nil, base64: bytes.base64EncodedString(), hex: nil)

        let result = try updatingPreferencePlistData(
            existingData: nil,
            bundleID: "com.example.app",
            plistPath: "/tmp/com.example.app.plist",
            key: "SeedState",
            newValue: newValue
        )

        let plist = try PropertyListSerialization.propertyList(from: result.data, options: [], format: nil)
        let dictionary = try #require(plist as? [String: Any])
        let stored = try #require(dictionary["SeedState"] as? Data)
        #expect(stored == bytes)
        #expect(result.newValue == .data(bytes.base64EncodedString()))
    }

    @Test("preference data value parser accepts defaults-style hex")
    func parsesExplicitHexDataPreference() throws {
        let value = try parseHostPreferenceSetValue(type: .data, value: nil, base64: nil, hex: "0x5b7b7d5d")
        #expect(value == .data(Data([0x5B, 0x7B, 0x7D, 0x5D]).base64EncodedString()))
    }

    @Test("preference data value parser rejects ambiguous data inputs")
    func rejectsAmbiguousDataInputs() throws {
        do {
            _ = try parseHostPreferenceSetValue(type: .data, value: nil, base64: nil, hex: nil)
            Issue.record("Expected missing data payload to be rejected")
        } catch let error as RuntimeError {
            #expect(error.description.contains("requires exactly one of --base64 or --hex"))
        }

        do {
            _ = try parseHostPreferenceSetValue(type: .data, value: nil, base64: "AA==", hex: "00")
            Issue.record("Expected multiple data payloads to be rejected")
        } catch let error as RuntimeError {
            #expect(error.description.contains("requires exactly one of --base64 or --hex"))
        }
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
            previousPlistType: "string",
            newPlistType: "dictionary",
            restartAdvice: "Restart if needed."
        )

        let json = try encodeJSON(output)
        #expect(json.contains(#""previousValue" : "old""#))
        #expect(json.contains(#""enabled" : true"#))
        #expect(json.contains(#""count" : 2"#))
        #expect(json.contains(#""previousPlistType" : "string""#))
        #expect(json.contains(#""newPlistType" : "dictionary""#))
        #expect(!json.contains(#""_0""#))
    }
}
