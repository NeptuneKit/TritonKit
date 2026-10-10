import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Administration policy plan: no execution API")
struct DeviceAdministrationPlanTests {
    @Test("all resolver failures privacy-bound, stable code only, no raw candidate/log/path/probe IO")
    func resolverFailurePrivacy() throws {
        let command = TKHostCommand(arguments: ["devicectl", "list", "devices"])
        let result = HostProcessResult(stdoutData: Data("PRIVATE-STDOUT-ID".utf8), stderrData: Data("PRIVATE-STDERR-LOG".utf8), exitCode: 1, sourceCommand: "PRIVATE-COMMAND", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
        let failures: [(any Error, String)] = [
            (IOSDevicectlRunError.jsonMissing(path: "/private/PRIVATE-CACHE.json"), "devicectl_json_missing"),
            (IOSDevicectlRunError.jsonParseFailed(.malformedJSON("PRIVATE-JSON-ID")), "devicectl_json_parse_failed"),
            (HostCommandRunError.timeout(command: command, timeoutSeconds: 1, stdoutLogPath: "/private/PRIVATE-OUT", stderrLogPath: "/private/PRIVATE-ERR"), "host_command_timeout"),
            (HostCommandRunError.nonZeroExit(command: command, result: result), "host_action_failed"),
            (NSError(domain: "PRIVATE-DOMAIN", code: 1, userInfo: [NSLocalizedDescriptionKey: "PRIVATE-ERROR"]), "host_action_failed"),
            (HostDeviceSelectionError.ambiguousTargets([selection().target]), hostDeviceSelectionErrorDetail(.ambiguousTargets([selection().target])).detail.code)
        ]
        for (error, code) in failures {
            var probed = false
            do { _ = try makeDeviceAdministrationPlan(operation: .pair, options: options(.pair), resolver: { _ in throw error }, commandProbe: { spec in probed = true; return support(spec) }); Issue.record("expected discovery rejection") }
            catch {
                #expect(!String(describing: error).contains("PRIVATE"))
                if let safe = error as? HostDeviceAdministrationDiscoveryFailure {
                    let publicJSON = try encodeJSON(safe.detail)
                    #expect(safe.detail.code == code && !publicJSON.contains("PRIVATE"))
                } else { Issue.record("all metadata failures require typed static disclosure boundary") }
            }
            #expect(!probed)
        }
    }
    private func selection(simulator: Bool = false, identifier: String = "PRIVATE-IDENTIFIER") -> HostDeviceSelectionResult {
        let target = hostDeviceTarget(from: TKDevicectlDeviceTarget(identifier: identifier, state: "blocked", ready: false, blockedReasons: ["unpaired"], alternateIdentifiers: ["PRIVATE-ALIAS"], scope: simulator ? "simulator" : "real", kind: simulator ? "simulator" : "real-device", simulatorUDID: simulator ? "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" : nil))
        return HostDeviceSelectionResult(platform: .ios, target: target, selector: "PRIVATE-SELECTOR", source: .explicit, filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios)))
    }
    private func options(_ operation: DeviceAdministrationOperation) -> DeviceAdministrationOptions {
        var value = DeviceAdministrationOptions(); value.device = "private-friendly-alias"; value.planOnly = true
        value.platform = .ios; value.scope = .real; value.output = nil; value.timeout = nil; value.json = true; value.format = .json
        if operation == .diagnose { value.output = "/private/PRIVATE-ARCHIVE.zip" }
        return value
    }
    private func support(_ spec: AppleHostCommandSpecification) -> HostAppleCommandSupport {
        HostAppleCommandSupport(name: spec.name, supported: true, requiredOptions: spec.requiredOptions, missingOptions: [], sourceCommand: "xcrun " + spec.helpArguments.joined(separator: " "), error: nil)
    }
    @Test(arguments: DeviceAdministrationOperation.allCases)
    func safePlan(_ operation: DeviceAdministrationOperation) throws {
        let output = try makeDeviceAdministrationPlan(operation: operation, options: options(operation), resolver: { _ in selection() }, commandProbe: support)
        let text = try encodeJSON(output)
        #expect(!text.contains("PRIVATE-") && !text.contains("private-friendly-alias"))
        #expect(output.target.hasPrefix("ios-real:") && output.executable == false && output.executed == false)
        #expect(output.plannedRiskLevel == (operation == .diagnose ? "diagnostic" : "break-glass"))
        #expect(!output.blockedRequirements.isEmpty && !output.operationArtifactsCreated)
        let command = plannedDeviceAdministrationCommand(operation: operation, nativeIdentifier: "PRIVATE-IDENTIFIER", archiveDestination: operation == .diagnose ? "/private/PRIVATE-ARCHIVE.zip" : nil, timeout: 42)
        #expect(command.arguments.contains("--json-output") && command.arguments.contains("--log-output") && command.arguments.contains("--timeout") && command.defaultTimeoutSeconds == 42)
        #expect(!hostSourceCommand(command).contains("PRIVATE-"))
        if operation == .diagnose {
            #expect(command.arguments.prefix(2) == ["devicectl", "diagnose"])
            #expect(command.arguments.filter { $0 == "--devices" }.count == 1 && command.arguments.contains("--no-finder") && command.arguments.contains("--no-include-host-sysdiagnose") && command.arguments.contains("--archive-destination"))
            #expect(output.diagnosticScopeHint?.contains("host") == true)
        } else { #expect(Array(command.arguments.prefix(3)) == ["devicectl", "manage", operation.rawValue]) }
    }
    @Test("invalid input rejected before fresh discovery/help; no native runner in API")
    func invalidBeforeIO() throws {
        var variants: [(DeviceAdministrationOperation, DeviceAdministrationOptions)] = []
        var invalid = options(.pair); invalid.planOnly = false; variants.append((.pair, invalid))
        invalid = options(.pair); invalid.platform = .android; variants.append((.pair, invalid))
        invalid = options(.pair); invalid.scope = .simulator; variants.append((.pair, invalid))
        invalid = options(.pair); invalid.device = nil; variants.append((.pair, invalid))
        invalid = options(.pair); invalid.timeout = -.infinity; variants.append((.pair, invalid))
        invalid = options(.pair); invalid.output = "private.zip"; variants.append((.pair, invalid))
        invalid = options(.diagnose); invalid.output = nil; variants.append((.diagnose, invalid))
        invalid = options(.diagnose); invalid.output = "-"; variants.append((.diagnose, invalid))
        invalid = options(.diagnose); invalid.output = "PRIVATE\n.zip"; variants.append((.diagnose, invalid))
        for (operation, value) in variants {
            var resolved = false; var probed = false
            #expect(throws: HostDeviceSelectionError.self) { _ = try makeDeviceAdministrationPlan(operation: operation, options: value, resolver: { _ in resolved = true; return selection() }, commandProbe: { spec in probed = true; return support(spec) }) }
            #expect(!resolved && !probed)
        }
    }
    @Test("sim target and malicious native identifier refused before help, unsupported help only policy review")
    func targetAndSupport() throws {
        for target in [selection(simulator: true), selection(identifier: "--all"), selection(identifier: "PRIVATE\nID")] {
            var probed = false
            #expect(throws: HostDeviceSelectionError.self) { _ = try makeDeviceAdministrationPlan(operation: .pair, options: options(.pair), resolver: { _ in target }, commandProbe: { spec in probed = true; return support(spec) }) }
            #expect(!probed)
        }
        let output = try makeDeviceAdministrationPlan(operation: .diagnose, options: options(.diagnose), resolver: { _ in selection() }, commandProbe: { spec in HostAppleCommandSupport(name: spec.name, supported: false, requiredOptions: spec.requiredOptions, missingOptions: ["--no-finder"], sourceCommand: "xcrun devicectl diagnose --help", error: "PRIVATE-ERROR") })
        #expect(output.ok && !output.executable && output.plannedSourceCommand == nil && !output.blockedRequirements.isEmpty)
        #expect(!(try encodeJSON(output)).contains("PRIVATE-"))
    }
}
