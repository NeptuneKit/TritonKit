import Foundation
import Testing
@testable import TritonKitShared

@Suite("Device Hub official JSON adapter")
struct TKDeviceHubOfficialAdapterTests {
    // Minimized, anonymized shapes captured from devicectl 651.13.5 JSON v5.
    // New-only variants deliberately omit deprecated dictionaries: compatibility tests,
    // not a claim that the installed tool has already removed those dictionaries.
    private func payload(_ record: String) -> Data {
        Data("{\"info\":{\"jsonVersion\":5,\"outcome\":\"success\"},\"result\":{\"devices\":[\(record)]}}".utf8)
    }

    private func simulator(boot: String = "booted", reality: String = "simulated") -> String {
        """
        {"identifier":"CORE-SIM", "properties":{
          "hardware":{"platform":"iOS","reality":"\(reality)","udid":"SIM-UDID"},
          "connection":{"pairingState":"paired","state":"connected","transportType":"sameMachine"},
          "software":{"osVersionNumber":{"stringValue":"27.1","components":[27,1]}},
          "state":{"bootState":"\(boot)","name":"Fixture Simulator","visibilityClass":"simulators"}
        }}
        """
    }

    @Test("new-only simulator keeps canonical sim identity and typed OS version")
    func simulatorIdentity() throws {
        let target = try #require(TKDevicectlDeviceListParser.parse(payload(simulator())).first)
        #expect(target.kind == "simulator")
        #expect(target.scope == "simulator")
        #expect(target.id == "sim:SIM-UDID")
        #expect(target.name == "Fixture Simulator")
        #expect(target.runtime == "iOS 27.1")
        #expect(target.ready)
    }

    @Test("shutdown and unknown boot states do not become ready paired devices", arguments: ["shutdown", "unknown", "future-state"])
    func simulatorNotReady(boot: String) throws {
        let target = try #require(TKDevicectlDeviceListParser.parse(payload(simulator(boot: boot))).first)
        #expect(!target.ready)
        #expect(!target.blockedReasons.isEmpty)
    }

    @Test("authoritative new dictionaries win over deprecated connected/booted mirrors")
    func newFieldsWin() throws {
        var root = try #require(JSONSerialization.jsonObject(with: payload(simulator(boot: "shutdown"))) as? [String: Any])
        var result = try #require(root["result"] as? [String: Any])
        var devices = try #require(result["devices"] as? [[String: Any]])
        devices[0]["deviceProperties"] = ["name":"Stale mirror", "bootState":"booted", "developerModeStatus":"enabled"]
        devices[0]["hardwareProperties"] = ["reality":"physical", "udid":"PRIVATE-STALE-UDID"]
        devices[0]["connectionProperties"] = ["pairingState":"paired", "tunnelState":"connected"]
        result["devices"] = devices; root["result"] = result
        let target = try #require(TKDevicectlDeviceListParser.parse(JSONSerialization.data(withJSONObject: root)).first)
        #expect(target.scope == "simulator")
        #expect(target.id == "sim:SIM-UDID")
        #expect(target.name == "Fixture Simulator")
        #expect(!target.ready)
    }

    @Test("missing readiness and future reality stay unknown, not real/ready")
    func unknownMetadata() throws {
        for record in ["{\"identifier\":\"EMPTY\"}", simulator(reality: "future-kind")] {
            let target = try #require(TKDevicectlDeviceListParser.parse(payload(record)).first)
            #expect(!target.ready)
            #expect(target.kind == "unknown")
            #expect(target.scope == "unknown")
        }
    }

    @Test("physical v5 parses associated-value developer mode and sensitive aliases")
    func physicalIdentity() throws {
        let record = """
        {"identifier":"CORE-PHYSICAL","visibilityClass":"default","properties":{
          "hardware":{"platform":"iOS","reality":"physical","udid":"PRIVATE-UDID","ecid":123456,"serialNumber":"PRIVATE-SERIAL"},
          "connection":{"pairingState":"paired","state":"connected","transportType":"wired"},
          "software":{"osVersionNumber":{"stringValue":"26.5.2"}},
          "state":{"bootState":"booted","name":"Fixture Physical","developerModeStatus":{"enabled":{"mode":1}}}
        }}
        """
        let target = try #require(TKDevicectlDeviceListParser.parse(payload(record)).first)
        #expect(target.scope == "real")
        #expect(target.ready)
        #expect(target.runtime == "iOS 26.5.2")
        #expect(target.alternateIdentifiers.contains("123456"))
        let encoded = String(decoding: try JSONEncoder().encode(target), as: UTF8.self)
        #expect(!encoded.contains("PRIVATE-UDID"))
        #expect(!encoded.contains("PRIVATE-SERIAL"))
        #expect(!encoded.contains("123456"))
    }

    @Test("empty/null/incomplete modern properties never revive legacy ready mirrors", arguments: ["{}", "null", "{\"state\":{\"name\":\"Partial\"}}"])
    func incompleteProperties(properties: String) throws {
        let record = """
        {"identifier":"PARTIAL", "properties":\(properties),
         "deviceProperties":{"developerModeStatus":"enabled"},
         "connectionProperties":{"pairingState":"paired","tunnelState":"connected"},
         "hardwareProperties":{"platform":"iOS","reality":"physical"}}
        """
        let target = try #require(TKDevicectlDeviceListParser.parse(payload(record)).first)
        #expect(!target.ready)
        #expect(target.scope == "unknown")
    }

    @Test("modern paired lazy tunnel remains discovery eligible, not business ready")
    func modernLazyTunnel() throws {
        let record = """
        {"identifier":"LAZY", "properties":{
          "hardware":{"platform":"iOS","reality":"physical"},
          "connection":{"pairingState":"paired","state":"disconnected"},
          "state":{"developerModeStatus":{"enabled":{"mode":1}}}
        }}
        """
        let target = try #require(TKDevicectlDeviceListParser.parse(payload(record)).first)
        #expect(target.ready)
        #expect(target.scope == "real")
    }

    @Test("non-iOS and missing simulator UDID cannot authorize iOS dispatch")
    func unsupportedIdentities() throws {
        for record in [simulator().replacingOccurrences(of: "\"iOS\"", with: "\"tvOS\""), simulator().replacingOccurrences(of: ",\"udid\":\"SIM-UDID\"", with: "")] {
            let target = try #require(TKDevicectlDeviceListParser.parse(payload(record)).first)
            #expect(!target.ready)
            #expect(target.scope == "unknown")
        }
    }

    @Test("malformed identities are errors, never silently dropped inventory rows", arguments: ["{}", "{\"identifier\":\"\"}", "{\"identifier\":\"   \"}", "{\"identifier\":true}"])
    func malformedIdentities(record: String) {
        #expect(throws: TKDevicectlParserError.self) {
            _ = try TKDevicectlDeviceListParser.parse(payload(record))
        }
    }

    @Test("positive pairing cannot override unavailable or future physical state")
    func physicalStateUnknown() throws {
        for (boot, visibility) in [("shutdown", "default"), ("future-state", "default"), ("booted", "future-visibility")] {
            let record = """
            {"identifier":"PHYSICAL-STATE", "properties":{
              "hardware":{"platform":"iOS","reality":"physical"},
              "connection":{"pairingState":"paired","state":"connected"},
              "state":{"bootState":"\(boot)","visibilityClass":"\(visibility)","developerModeStatus":{"enabled":{"mode":1}}}
            }}
            """
            let target = try #require(TKDevicectlDeviceListParser.parse(payload(record)).first)
            #expect(!target.ready)
        }
    }

    @Test("failed outcome cannot publish a successful inventory")
    func failedOutcome() {
        let data = payload(simulator())
        let failed = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"outcome\":\"success\"", with: "\"outcome\":\"failure\"")
        #expect(throws: TKDevicectlParserError.self) {
            _ = try TKDevicectlDeviceListParser.parse(Data(failed.utf8))
        }
    }

    @Test("unknown physical developer mode is not ready")
    func unknownDeveloperMode() throws {
        let record = """
        {"identifier":"CORE-PHYSICAL","visibilityClass":"default","properties":{
          "hardware":{"platform":"iOS","reality":"physical"},
          "connection":{"pairingState":"paired","state":"connected"},
          "state":{"developerModeStatus":{"futureCase":{}}}
        }}
        """
        let target = try #require(TKDevicectlDeviceListParser.parse(payload(record)).first)
        #expect(!target.ready)
        #expect(target.blockedReasons.contains("readiness-unknown"))
    }
}
