import ArgumentParser
import CryptoKit
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Explicit DeviceFS mount-root listing")
struct DeviceFSListTests {
    private let policy = HostDeviceMountPolicy(allowMount: true, confirm: true, executeRunner: true, auditRecord: "fixture")
    private let primary = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    private let alias = "11111111-2222-3333-4444-555555555555"
    private let home = "/private/FIXTURE-HOME"
    private func selection(simulator: Bool = false) -> HostDeviceSelectionResult {
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: primary, state: "unknown", ready: false, blockedReasons: [], alternateIdentifiers: [alias], scope: simulator ? "simulator" : "real", kind: simulator ? "simulator" : "real-device", simulatorUDID: simulator ? primary : nil))
        return HostDeviceSelectionResult(platform: .ios, target: target, selector: target.id, source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios)))
    }
    private func path(_ identifier: String) -> String { home + "/Library/Developer/CoreDevice/DeviceFS/device-" + identifier + ".localized" }
    private func json(_ device: String, root: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["info": ["arguments": ["devicectl", "device", "info", "mountpoint", "--device", device, "--json-output", "/fixture/device-mountpoint.json", "--log-output", "/fixture/device-mountpoint.log"], "outcome": "success", "commandType": "devicectl.device.info.mountpoint"], "result": ["dataPath": root]])
    }
    private func artifacts(_ action: String) -> (json: String, log: String) { ("/fixture/" + action + ".json", "/fixture/" + action + ".log") }
    private func result(_ command: TKHostCommand) -> HostProcessResult {
        HostProcessResult(stdoutData: Data("SECRET-STDOUT".utf8), stderrData: Data(), exitCode: 0, sourceCommand: "UNTRUSTED " + primary, stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
    }
    @Test("standard home authority matches UTF8 bytes, not Swift canonical Unicode equality")
    func homeAuthorityBytes() throws {
        let nfc = "/private/café"; let nfd = "/private/cafe\u{301}"
        let tail = "/Library/Developer/CoreDevice/DeviceFS/device-" + primary + ".localized"
        #expect(nfc == nfd && Array(nfc.utf8) != Array(nfd.utf8))
        #expect(throws: HostDeviceFSError.rootMismatch) { _ = try boundDeviceFSRoot(path: nfd + tail, selection: selection(), homeDirectory: nfc) }
        #expect(throws: HostDeviceFSError.rootMismatch) { _ = try boundDeviceFSRoot(path: nfc + tail, selection: selection(), homeDirectory: nfd) }
        for home in [nfc, nfd] { #expect(Array(try boundDeviceFSRoot(path: home + tail, selection: selection(), homeDirectory: home).utf8) == Array((home + tail).utf8)) }
    }
    @Test("container-relative exact path and directory/entry scope isolation, private selection")
    func subdirectoryScope() throws {
        var tokens: Set<String> = []; var directories: Set<String> = []
        for path in ["PRIVATE-DIR/one", "PRIVATE-DIR/two", "café", "cafe\u{301}"] {
            let output = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: .appDataContainers, containerIdentifier: "SECRET-ID", subdirectory: path, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: self.path(primary)) }, listReader: { _, relative, _ in
                #expect(Array(relative!.utf8) == Array(("AppDataContainers/SECRET-ID/" + path).utf8))
                return [DeviceFSMetadataEntry(name: "same-name", kind: "directory", sizeBytes: nil)]
            })
            tokens.insert(output.entries[0].token); directories.insert(try #require(output.directoryToken))
            let text = try encodeJSON(output); #expect(!text.contains("PRIVATE-DIR") && !text.contains("SECRET-ID"))
        }
        #expect(tokens.count == 4 && directories.count == 4)
    }
    @Test("relative input before query, combined bound path before directory IO")
    func subdirectoryBeforeIO() throws {
        var queried = false; var read = false
        #expect(throws: (any Error).self) { _ = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: .appDataContainers, containerIdentifier: "id", subdirectory: "../PRIVATE-ESCAPE", artifactProvider: { queried = true; return artifacts($0) }, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { _, _, _ in read = true; return [] }) }
        #expect(!queried && !read)
        let deep = "/" + Array(repeating: "h", count: 57).joined(separator: "/")
        let native = deep + "/Library/Developer/CoreDevice/DeviceFS/device-" + primary + ".localized"
        var artifactCalls = 0; var runnerCalls = 0; var JSONCalls = 0
        #expect(throws: (any Error).self) { _ = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: .appDataContainers, containerIdentifier: "id", subdirectory: "Library", homeDirectory: deep, artifactProvider: { artifactCalls += 1; return artifacts($0) }, runner: { runnerCalls += 1; return result($0) }, JSONReader: { _, _ in JSONCalls += 1; return try json(primary, root: native) }, listReader: { _, _, _ in read = true; return [] }) }
        #expect(!read && artifactCalls == 0 && runnerCalls == 0 && JSONCalls == 0)
    }
    @Test("single container scopes directory and entry tokens, requested identifier always private")
    func containerSelection() throws {
        var directories: Set<String> = []; var entries: Set<String> = []
        for view in [DeviceFSView.appDataContainers, .appGroupContainers] {
            for identifier in ["SECRET-CONTAINER", "DIFFERENT-CONTAINER", "原始é"] {
                for sensitive in [false, true] {
                    let output = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: view, containerIdentifier: identifier, includeSensitive: sensitive, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { _, relative, _ in
                        #expect(relative == view.relativeDirectory! + "/" + identifier)
                        return [DeviceFSMetadataEntry(name: "same-name", kind: "directory", sizeBytes: nil)]
                    })
                    let directory = try #require(output.directoryToken)
                    #expect(directory.hasPrefix("directory:") && directory.count == 74)
                    directories.insert(directory); entries.insert(output.entries[0].token)
                    let text = try encodeJSON(output)
                    #expect(!text.contains(identifier) && !text.contains(path(primary)))
                    #expect(output.entries[0].name == (sensitive ? "same-name" : nil))
                }
            }
        }
        #expect(directories.count == 6 && entries.count == 6)
    }
    @Test("opt-in leaf names may coincide with a selector, without selection field echo")
    func containerLeafCoincidence() throws {
        let output = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: .appDataContainers, containerIdentifier: "same-name", includeSensitive: true, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { _, _, _ in [DeviceFSMetadataEntry(name: "same-name", kind: "directory", sizeBytes: nil)] })
        #expect(output.entries[0].name == "same-name")
        let object = try #require(JSONSerialization.jsonObject(with: Data(try encodeJSON(output).utf8)) as? [String: Any])
        #expect(object["containerIdentifier"] == nil && object["relativeDirectory"] == nil && output.directoryToken != nil)
    }
    @Test("255-byte success boundary and canonical equivalent names retain request UTF8 and distinct correlation tokens")
    func containerByteBoundaries() throws {
        var tokens: Set<String> = []
        for identifier in [String(repeating: "a", count: 255), String(repeating: "é", count: 127) + "a", "café", "cafe\u{301}"] {
            let output = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: .appDataContainers, containerIdentifier: identifier, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { _, relative, _ in
                #expect(Array(relative!.utf8) == Array(("AppDataContainers/" + identifier).utf8))
                return []
            })
            tokens.insert(try #require(output.directoryToken))
        }
        #expect(tokens.count == 4)
    }
    @Test("invalid container is rejected before artifact/runner/reader, no private input echo")
    func invalidContainer() throws {
        for view in DeviceFSView.allCases {
            let bad = view == .mountRoot ? ["valid-component"] : ["", ".", "..", "../outside", "/absolute", "a/b", "line\nfeed", "tab\t", "nul\0", String(repeating: "é", count: 128)]
            for identifier in bad {
                var queried = false; var read = false
                do {
                    _ = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: view, containerIdentifier: identifier, homeDirectory: home, artifactProvider: { queried = true; return artifacts($0) }, runner: { queried = true; return result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { _, _, _ in read = true; return [] })
                    Issue.record("Invalid selector was accepted")
                } catch let error as HostDeviceSelectionError {
                    if case .parameterConflict(let message) = error { #expect(!message.contains("valid-component") && !message.contains("outside")) } else { Issue.record("Wrong selector error") }
                }
                #expect(!queried && !read)
            }
        }
    }
    @Test("empty namespace is accepted metadata, never App/group existence", arguments: DeviceFSView.allCases)
    func emptyNamespace(view: DeviceFSView) throws {
        let output = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: view, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { _, _, _ in [] })
        #expect(output.ok && output.count == 0 && output.entries.isEmpty && output.view == view.rawValue)
        #expect(!output.contentsRead && !output.recursive && !output.mountStateVerified && !output.readWriteAuthorizationVerified && !output.businessReadinessVerified)
    }
    @Test("namespace selected by fixed view alone and token separates equal names; root token compatible")
    func namespaceTokens() throws {
        var tokens: [String] = []
        for (view, expected) in [(DeviceFSView.mountRoot, Optional<String>.none), (.appDataContainers, "AppDataContainers"), (.appGroupContainers, "AppGroupContainers")] {
            let output = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, view: view, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { root, relative, _ in
                #expect(root == path(primary) && relative == expected)
                return [DeviceFSMetadataEntry(name: "SAME-PRIVATE-NAME", kind: "symbolic-link", sizeBytes: nil)]
            })
            #expect(output.view == view.rawValue && output.entries[0].name == nil && output.entries[0].sizeBytes == nil)
            if view == .mountRoot {
                let oldKey = output.mountpointToken + "\0SAME-PRIVATE-NAME"
                #expect(output.entries[0].token == "file:" + SHA256.hash(data: Data(oldKey.utf8)).map { String(format: "%02x", $0) }.joined())
            }
            tokens.append(output.entries[0].token)
        }
        #expect(Set(tokens).count == 3)
    }
    @Test("only standard exact parent plus current UUID root is authorized; returned case remains untouched")
    func rootBinding() throws {
        #expect(try boundDeviceFSRoot(path: path(primary.lowercased()), selection: selection(), homeDirectory: home) == path(primary.lowercased()))
        #expect(try boundDeviceFSRoot(path: path(alias), selection: selection(simulator: true), homeDirectory: home) == path(alias))
        for root in [path(alias), path(primary) + "/root", path(primary) + "/", home + "/Library/Developer/CoreDevice/DeviceFS", "/foreign/device-" + primary + ".localized", path(primary).replacingOccurrences(of: "DeviceFS/", with: "DeviceFS/../DeviceFS/"), path(primary).replacingOccurrences(of: "Library", with: "library")] {
            #expect(throws: HostDeviceFSError.rootMismatch) { _ = try boundDeviceFSRoot(path: root, selection: selection(), homeDirectory: home) }
        }
    }
    @Test("fresh bound snapshot and private root entries expose only tokens unless opt-in", arguments: [false, true])
    func privacy(sensitive: Bool) throws {
        var queries = 0
        var reads = 0
        let output = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, includeSensitive: sensitive, timeout: 12, homeDirectory: home, artifactProvider: artifacts, runner: { command in queries += 1; #expect(command.defaultTimeoutSeconds == 12); return result(command) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { root, relative, limit in reads += 1; #expect(root == path(primary) && relative == nil && limit == 1000); return [DeviceFSMetadataEntry(name: "SECRET-NAME", kind: "directory", sizeBytes: nil)] })
        #expect(queries == 1 && reads == 1 && output.count == 1 && !output.contentsRead && !output.recursive && output.hostFilesystemInspected && !output.readWriteAuthorizationVerified)
        // Local private diagnostic references are intentional; native DeviceFS dataPath remains private.
        #expect(output.artifacts == ["/fixture/device-mountpoint.json", "/fixture/device-mountpoint.log"])
        #expect(output.sourceCommands.contains { $0.contains("/fixture/device-mountpoint.json") })
        let text = try encodeJSON(output)
        for secret in [home, primary, alias, "UNTRUSTED", "SECRET-STDOUT", "dataPath"] { #expect(!text.contains(secret)) }
        #expect(output.entries[0].name == (sensitive ? "SECRET-NAME" : nil))
        if !sensitive { #expect(!text.contains("SECRET-NAME")) }
    }
    @Test("unsafe returned root fails before reader; stale physical alias is never root authority")
    func preReadFailure() throws {
        #expect(throws: HostDeviceFSError.rootMismatch) { _ = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(alias)) }, listReader: { _, _, _ in Issue.record("No unbound path read"); return [] }) }
    }
    @Test("injected oversized list and actual reader limits reject, do not truncate")
    func limits() throws {
        let leaf = DeviceFSMetadataEntry(name: "SECRET", kind: "regular-file", sizeBytes: 1)
        #expect(throws: HostDeviceFSError.limitExceeded) { _ = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, maximumEntries: 1, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { _, _, _ in [leaf, leaf] }) }
        #expect(throws: HostDeviceFSError.limitExceeded) { _ = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, homeDirectory: home, artifactProvider: artifacts, runner: { result($0) }, JSONReader: { _, _ in try json(primary, root: path(primary)) }, listReader: { _, _, _ in throw DeviceFSReaderError.limitExceeded }) }
        for count in [0, 10001] {
            #expect(throws: HostDeviceSelectionError.self) { _ = try makeIOSDeviceFSListOutput(selection: selection(), mountPolicy: policy, maximumEntries: count, artifactProvider: { _ in Issue.record("No query on invalid budget"); return ("", "") }) }
        }
    }
    @Test("fs list dispatch is independent; no implicit devicectl files replacement")
    func dispatch() throws {
        let command = try TritonKitCLI.parseAsRoot(["device", "fs", "list", "--device", "fixture", "--json"])
        #expect(type(of: command).configuration.commandName == "list")
        #expect(throws: (any Error).self) { _ = try TritonKitCLI.parseAsRoot(["device", "fs", "list", "--hostpath", "root/tmp", "--json"]) }
    }
    @Test("machine schema declares mount-root-only inspection and privacy")
    func schema() throws {
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.usageForms.contains { $0.form.hasPrefix("fs list ") })
        let contract = try #require(schema.outputContracts.first { $0.selector == "host.device-fs-list" })
        #expect(contract.fields.contains { $0.name == "hostFilesystemInspected" })
        #expect(contract.fields.contains { $0.name == "contentsRead" })
        #expect(schema.failureCodes.contains("device_fs_root_mismatch"))
    }
}
