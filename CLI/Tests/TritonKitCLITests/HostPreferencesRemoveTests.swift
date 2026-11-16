import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct HostPreferencesRemoveTests {
    @Test("remove deletes one literal key through the native domain between terminate and launch", arguments: [false, true])
    func removes(relaunch: Bool) throws {
        let fixture = try PreferenceFixture()
        defer { fixture.cleanUp() }
        let keep: [String: Any] = [
            "zero": 0, "false": false, "empty": "", "data": Data([0, 255]),
            "date": Date(timeIntervalSince1970: 123.456), "nested": ["a": [1, 2]]
        ]
        var domain = keep
        domain["a.b"] = "temporary"
        try fixture.write(domain)
        var calls: [[String]] = []
        let result = try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: "a.b",
            relaunch: relaunch, containerProvider: { fixture.root.path }, runner: { command in
                calls.append(command.arguments)
                switch command.arguments[1] {
                case "terminate", "launch": return fixture.reply()
                default:
                    #expect(command.arguments[0...5] == ["simctl", "spawn", "fixture", "defaults", "-container", fixture.root.path][...])
                    #expect(command.sensitiveOutput)
                    if command.arguments[6] == "export" {
                        return try fixture.export(fixture.plist(domain), for: command)
                    }
                    #expect(Array(command.arguments.suffix(3)) == ["delete", PreferenceFixture.bundleID, "a.b"])
                    domain.removeValue(forKey: "a.b")
                    try fixture.write(domain)
                    return fixture.reply()
                }
            })
        let actual = try #require(PropertyListSerialization.propertyList(from: fixture.read(), options: [], format: nil) as? [String: Any])
        #expect(NSDictionary(dictionary: actual).isEqual(to: keep))
        #expect(result.ok && result.existed && result.removed && !result.present && result.diskWriteVerified)
        #expect(result.preferenceDomainVerified)
        #expect(!result.runtimeConsumptionVerified)
        let order = calls.map { $0[1] == "spawn" ? $0[6] : $0[1] }
        #expect(order == (relaunch ? ["terminate", "export", "delete", "export", "launch"] : ["export", "delete", "export"]))
    }

    @Test("absent key preserves original bytes and missing plist is not created", arguments: [false, true])
    func absent(existing: Bool) throws {
        let fixture = try PreferenceFixture(createPreferencesDirectory: existing)
        defer { fixture.cleanUp() }
        let domain = existing ? ["keep": false] : [:]
        let bytes = try PropertyListSerialization.data(fromPropertyList: domain, format: .xml, options: 0)
        if existing { try bytes.write(to: fixture.file) }
        let result = try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: "absent",
            containerProvider: { fixture.root.path }, runner: { command in
                #expect(command.arguments[6] == "export")
                return try fixture.export(bytes, for: command)
            })
        #expect(result.ok && !result.existed && !result.removed && !result.present && result.preferenceDomainVerified)
        if existing { #expect(try Data(contentsOf: fixture.file) == bytes) }
        else { #expect(!FileManager.default.fileExists(atPath: fixture.directory.path)) }
    }

    @Test("native-only cached key is removed even if the disk key was already absent")
    func cachedKey() throws {
        let fixture = try PreferenceFixture()
        defer { fixture.cleanUp() }
        try fixture.write(["keep": false])
        var domain: [String: Any] = ["keep": false, "stale": "cached"]
        let result = try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: "stale",
            containerProvider: { fixture.root.path }, runner: { command in
                if command.arguments[6] == "delete" { domain.removeValue(forKey: "stale"); return fixture.reply() }
                return try fixture.export(fixture.plist(domain), for: command)
            })
        #expect(result.removed && result.preferenceDomainVerified && !result.present)
        #expect(try fixture.read() == fixture.plist(["keep": false]))
    }

    @Test("invalid keys reject before path lookup", arguments: ["", "bad\nkey", String(repeating: "a", count: 1025)])
    func invalidKey(key: String) {
        #expect(throws: (any Error).self) {
            try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: key,
                containerProvider: { Issue.record("unexpected path lookup"); return "unused" })
        }
    }

    @Test("unsafe plist or preferences parent fails before commands", arguments: ["malformed", "file-link", "parent-link"])
    func unsafePlist(kind: String) throws {
        let fixture = try PreferenceFixture(createPreferencesDirectory: kind != "parent-link")
        defer { fixture.cleanUp() }
        let source = fixture.root.appendingPathComponent("source")
        let bytes = Data("invalid plist".utf8)
        switch kind {
        case "file-link":
            try bytes.write(to: source)
            try FileManager.default.createSymbolicLink(at: fixture.file, withDestinationURL: source)
        case "parent-link":
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
            try bytes.write(to: source.appendingPathComponent(fixture.file.lastPathComponent))
            try FileManager.default.createDirectory(at: fixture.directory.deletingLastPathComponent(), withIntermediateDirectories: false)
            try FileManager.default.createSymbolicLink(at: fixture.directory, withDestinationURL: source)
        default: try bytes.write(to: fixture.file)
        }
        #expect(throws: (any Error).self) {
            try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: "key",
                relaunch: true, containerProvider: { fixture.root.path }, runner: { _ in
                    Issue.record("unsafe path reached native command")
                    return fixture.reply()
                })
        }
        #expect(try Data(contentsOf: fixture.file) == bytes)
    }

    @Test("mismatched unrelated native values reject before any deletion")
    func siblingMismatch() throws {
        let fixture = try PreferenceFixture()
        defer { fixture.cleanUp() }
        let original: [String: Any] = ["key": 1, "keep": false]
        try fixture.write(original)
        #expect(throws: (any Error).self) {
            try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: "key",
                containerProvider: { fixture.root.path }, runner: { command in
                    #expect(command.arguments[6] == "export")
                    return try fixture.export(fixture.plist(["key": 1, "keep": 0]), for: command)
                })
        }
        #expect(try fixture.read() == fixture.plist(original))
    }

    @Test("unknown native deletion is not retried and does not launch")
    func unknownDelete() throws {
        let fixture = try PreferenceFixture()
        defer { fixture.cleanUp() }
        try fixture.write(["key": true])
        var order: [String] = []
        #expect(throws: (any Error).self) {
            try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: "key",
                relaunch: true, containerProvider: { fixture.root.path }, runner: { command in
                    let operation = command.arguments[1] == "spawn" ? command.arguments[6] : command.arguments[1]
                    order.append(operation)
                    if operation == "delete" { throw RuntimeError("fixture") }
                    return operation == "export" ? try fixture.export(fixture.plist(["key": true]), for: command) : fixture.reply()
                })
        }
        #expect(order == ["terminate", "export", "delete"])
    }

    @Test("terminate failure does not delete and launch failure preserves verified deletion")
    func lifecycleFailures() throws {
        let fixture = try PreferenceFixture()
        defer { fixture.cleanUp() }
        try fixture.write(["remove": true])
        #expect(throws: (any Error).self) {
            try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: "remove",
                relaunch: true, containerProvider: { fixture.root.path }, runner: { command in
                    #expect(command.arguments[1] == "terminate")
                    throw RuntimeError("fixture")
                })
        }
        #expect(try fixture.read() == fixture.plist(["remove": true]))
        let result = try removeHostPreference(simulator: "fixture", bundleID: PreferenceFixture.bundleID, key: "remove",
            relaunch: true, containerProvider: { fixture.root.path }, runner: { command in
                switch command.arguments[1] {
                case "terminate": return fixture.reply()
                case "launch": throw RuntimeError("fixture")
                default:
                    if command.arguments[6] == "export" { return try fixture.export(fixture.read(), for: command) }
                    try fixture.write([:])
                    return fixture.reply()
                }
            })
        let json = try #require(JSONSerialization.jsonObject(with: Data(encodeJSON(result).utf8)) as? [String: Any])
        #expect(!result.ok && result.diskWriteVerified && result.preferenceDomainVerified && !result.present)
        #expect((json["error"] as? [String: Any])?["code"] as? String == "preferences_relaunch_failed")
    }

    @Test("actual root parser registers remove and optional relaunch")
    func parser() throws {
        let command = try #require(TritonKitCLI.parseAsRoot(["app", "prefs", "remove", "key", "--bundle-id", "com.example.fixture", "--device", "sim:fixture", "--relaunch", "--json"]) as? HostAppPrefsRemove)
        #expect(command.key == "key" && command.relaunch && command.json)
        let schema = try #require(commandSchemas().first { $0.name == "app" })
        let leaf = try #require(schema.subcommands.first { $0.name == "prefs" }?.subcommands.first { $0.name == "remove" })
        #expect(leaf.outputSelectors == ["host.app-prefs-remove"])
        #expect(schema.outputContracts.contains { $0.selector == "host.app-prefs-remove" && $0.fields.contains { $0.name == "preferenceDomainVerified" } })
    }
}

private struct PreferenceFixture {
    static let bundleID = "com.example.fixture"
    let root: URL
    var directory: URL { root.appendingPathComponent("Library/Preferences") }
    var file: URL { directory.appendingPathComponent(Self.bundleID + ".plist") }

    init(createPreferencesDirectory: Bool = true) throws {
        root = URL(fileURLWithPath: "/private/tmp", isDirectory: true).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: createPreferencesDirectory ? directory : root, withIntermediateDirectories: true)
    }

    func plist(_ value: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }

    func write(_ value: [String: Any]) throws { try plist(value).write(to: file) }
    func read() throws -> Data { try Data(contentsOf: file) }
    func cleanUp() { try? FileManager.default.removeItem(at: root) }

    func export(_ data: Data, for command: TKHostCommand) throws -> HostProcessResult {
        let file = try #require(command.arguments.last)
        try data.write(to: URL(fileURLWithPath: file))
        return reply()
    }

    func reply() -> HostProcessResult {
        HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: "fixture",
            stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil,
            stdoutBytes: 0, stderrBytes: 0)
    }
}
