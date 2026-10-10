import Foundation
import TritonKitShared

func freshDeviceInfoArtifactPaths(action: String) throws -> (json: String, log: String) {
    let paths = try freshDevicectlArtifactPaths(action: action)
    let directory = URL(fileURLWithPath: paths.json).deletingLastPathComponent().path
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory)
    return paths
}

func makeIOSDeviceInfoOutput(
    selection: HostDeviceSelectionResult,
    includeLockState: Bool = false,
    timeout: Double? = nil,
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) },
    reader: (String) throws -> Data = { try Data(contentsOf: URL(fileURLWithPath: $0)) }
) throws -> HostDeviceInfoOutput {
    guard selection.platform == .ios, ["simulator", "real"].contains(selection.target.scope) else {
        throw HostDeviceInfoError.unsupportedPlatform
    }
    if let timeout, !timeout.isFinite || timeout <= 0 {
        throw HostDeviceSelectionError.parameterConflict("Device info timeout must be finite and greater than zero.")
    }
    var sourceCommands: [String] = []
    var artifacts: [String] = []
    var identities = Set([selection.target.rawTarget] + selection.target.rawTargetAliases)

    func matches(_ identifier: String) -> Bool {
        identities.contains { candidate in
            candidate == identifier || (UUID(uuidString: candidate) != nil && UUID(uuidString: candidate) == UUID(uuidString: identifier))
        }
    }
    func redact(_ source: String) -> String {
        identities.sorted { $0.count > $1.count }.reduce(source) { value, identifier in
            guard !identifier.isEmpty else { return value }
            return value.replacingOccurrences(of: identifier, with: selection.target.target)
        }
    }
    func query(_ phase: String, builder: (String, String) -> TKHostCommand) throws -> Data {
        let paths = try artifactProvider("device-info-\(phase)")
        let command = redactingXcodeRealDeviceCommand(builder(paths.json, paths.log), rawTarget: selection.target.rawTarget).withTimeout(timeout)
        defer {
            for path in [paths.json, paths.log] where FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            }
        }
        func failure() -> HostDeviceInfoError {
            if phase == "lockState", let data = try? reader(paths.json), TKDevicectlDeviceInfoParser.isLockStateUnsupported(data) {
                return .queryUnsupported(phase)
            }
            return .queryFailed(phase)
        }
        let result: HostProcessResult
        do { result = try runner(command) }
        catch HostCommandRunError.timeout { throw HostDeviceInfoError.queryTimedOut(phase) }
        catch HostCommandRunError.nonZeroExit { throw failure() }
        catch { throw HostDeviceInfoError.queryFailed(phase) }
        // Injected runners, like real process runners, must not turn a nonzero exit into success.
        guard result.exitCode == 0 else { throw failure() }
        sourceCommands.append(result.sourceCommand)
        artifacts.append(contentsOf: [paths.json, paths.log])
        do { return try reader(paths.json) }
        catch { throw HostDeviceInfoError.jsonMissing }
    }

    let detailsData = try query("details") { json, log in
        TKDevicectlCommand.deviceInfoDetails(identifier: selection.target.rawTarget, jsonOutput: json, logOutput: log)
    }
    let details: TKDevicectlDeviceDetails
    do { details = try TKDevicectlDeviceInfoParser.parseDetails(detailsData) }
    catch { throw HostDeviceInfoError.invalidJSON }
    let simulatorIdentityMatches = selection.target.scope == "simulator"
        && details.device.scope == "simulator"
        && details.device.alternateIdentifiers.contains(where: matches)
    guard matches(details.device.identifier) || simulatorIdentityMatches,
          details.device.scope == "unknown" || details.device.scope == selection.target.scope else {
        throw HostDeviceInfoError.identityMismatch
    }
    identities.formUnion([details.device.identifier] + details.device.alternateIdentifiers)
    var lockOutput = HostDeviceLockStateOutput(requested: false, verification: "not-probed", passcodeRequired: nil, unlockedSinceBoot: nil)
    if includeLockState {
        let data = try query("lockState") { json, log in
            TKDevicectlCommand.deviceInfoLockState(identifier: selection.target.rawTarget, jsonOutput: json, logOutput: log)
        }
        let lock: TKDevicectlLockState
        do { lock = try TKDevicectlDeviceInfoParser.parseLockState(data) }
        catch { throw HostDeviceInfoError.invalidJSON }
        guard matches(lock.deviceIdentifier) else { throw HostDeviceInfoError.identityMismatch }
        lockOutput = HostDeviceLockStateOutput(requested: true, verification: "executed-file-json", passcodeRequired: lock.passcodeRequired, unlockedSinceBoot: lock.unlockedSinceBoot)
    }
    return HostDeviceInfoOutput(ok: true, target: hostDeviceTarget(from: details.device), hardware: details.hardware, lockState: lockOutput, sourceCommands: sourceCommands.map(redact), artifacts: artifacts)
}
