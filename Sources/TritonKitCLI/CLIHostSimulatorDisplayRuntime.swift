import CoreFoundation
import Foundation
import TritonKitShared

struct IOSSimulatorDisplay: Equatable {
    let id: String
    let primary: Bool
    let active: Bool
    let integrated: Bool
}

enum IOSSimulatorDisplayTopology: Equatable {
    case primary(IOSSimulatorDisplay)
    case unknown(IOSSimulatorDisplayUnknownReason)
}

enum IOSSimulatorDisplayUnknownReason: String, Equatable { case invalidResponse, identityMismatch, duplicateID, multipleActive, missingField, truncated, timedOut, unsupported, queryFailed }

enum IOSSimulatorDisplayError: Error, Equatable, LocalizedError {
    case topologyUnknown(IOSSimulatorDisplayUnknownReason)
    var errorDescription: String? { detail.message }
    var detail: TKCLIErrorDetail {
        TKCLIErrorDetail(code: "ios_simulator_display_safety_unknown", message: "Simulator main-display routing could not be verified (\(reason.rawValue)); no AX, touch, or capture action was started.", hint: "Run the selected Xcode display topology query again and require one exact active primary integrated display before retrying.", nextAction: TKCLINextAction(command: "device", args: ["doctor", "--platform", "ios", "--scope", "simulator", "--json"], category: "diagnose"))
    }
    private var reason: IOSSimulatorDisplayUnknownReason { if case .topologyUnknown(let r) = self { return r }; return .queryFailed }
}

private func displayBool(_ value: Any?) -> Bool? {
    guard let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return nil }
    return n.boolValue
}

func classifyIOSSimulatorDisplayTopology(data: Data, target: String, exitCode: Int32) -> IOSSimulatorDisplayTopology {
    guard data.count <= 1_048_576 else { return .unknown(.truncated) }
    guard exitCode == 0, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let info = root["info"] as? [String: Any], info["commandType"] as? String == "devicectl.device.info.displayTopology",
          info["outcome"] as? String == "success", let args = info["arguments"] as? [String],
          let i = args.firstIndex(of: "--device"), args.indices.contains(i + 1), args[i + 1] == target,
          let result = root["result"] as? [String: Any], let raw = result["displays"] as? [[String: Any]], !raw.isEmpty else { return .unknown(.invalidResponse) }
    var ids = Set<String>(); var displays = [IOSSimulatorDisplay]()
    for item in raw {
        guard let id = item["id"] as? String, !id.isEmpty else { return .unknown(.missingField) }
        guard ids.insert(id).inserted else { return .unknown(.duplicateID) }
        guard let primary = displayBool(item["primary"]), let active = displayBool(item["active"]), let integrated = displayBool(item["integrated"]) else { return .unknown(.missingField) }
        displays.append(IOSSimulatorDisplay(id: id, primary: primary, active: active, integrated: integrated))
    }
    guard displays.filter({ $0.active }).count == 1 else { return .unknown(.multipleActive) }
    guard let primary = displays.first(where: { $0.primary && $0.active && $0.integrated }) else { return .unknown(.missingField) }
    return .primary(primary)
}

typealias IOSSimulatorDisplayProbe = (String, [String: String]) -> IOSSimulatorDisplayTopology

func iosSimulatorDisplayTopologyQueryCommand(target: String, json: String, log: String, environment: [String: String]) -> TKHostCommand {
    TKHostCommand(executable: "xcrun", arguments: ["devicectl", "device", "info", "displayTopology", "--device", target, "--json-output", json, "--log-output", log, "--timeout", "5", "--quiet"], environment: environment, redactedArgumentIndexes: [5, 7, 9], defaultTimeoutSeconds: 6, capturesArtifacts: true, sensitiveOutput: true)
}

func probeIOSSimulatorDisplay(target: String, environment: [String: String] = [:], artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths, runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0, maximumOutputBytes: 16_384) }, reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON) -> IOSSimulatorDisplayTopology {
    guard UUID(uuidString: target) != nil else { return .unknown(.identityMismatch) }
    let paths: (json: String, log: String)
    do { paths = try artifactProvider("simulator-display-topology") } catch { return .unknown(.queryFailed) }
    defer { for path in [paths.json, paths.log] { try? FileManager.default.removeItem(atPath: path) }; _ = rmdir(URL(fileURLWithPath: paths.json).deletingLastPathComponent().path) }
    let command = iosSimulatorDisplayTopologyQueryCommand(target: target, json: paths.json, log: paths.log, environment: environment)
    let result: HostProcessResult
    do { result = try runner(command) } catch HostCommandRunError.timeout { return .unknown(.timedOut) } catch HostCommandRunError.nonZeroExit(_, let failure) { result = failure } catch { return .unknown(.queryFailed) }
    let data: Data
    do { data = try reader(paths.json, 1_048_576) } catch {
        let stderr = result.stderr.lowercased()
        if result.exitCode == 64 && (stderr.contains("displaytopology") || stderr.contains("display topology")) && (stderr.contains("unrecognized") || stderr.contains("unknown subcommand")) { return .unknown(.unsupported) }
        return .unknown(.queryFailed)
    }
    return classifyIOSSimulatorDisplayTopology(data: data, target: target, exitCode: result.exitCode)
}

func assertIOSSimulatorMainDisplayAllowed(target: String, environment: [String: String] = [:], probe: IOSSimulatorDisplayProbe) throws {
    let result = probe(target, environment)
    guard case .primary = result else { if case .unknown(let reason) = result { throw IOSSimulatorDisplayError.topologyUnknown(reason) }; throw IOSSimulatorDisplayError.topologyUnknown(.queryFailed) }
}
