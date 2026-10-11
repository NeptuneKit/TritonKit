import CryptoKit
import Foundation
import TritonKitShared

func validateDeviceMountpointLimits(timeout: Double?, maximumJSONBytes: Int) throws {
    guard (1...16_777_216).contains(maximumJSONBytes) else { throw HostDeviceSelectionError.parameterConflict("Mountpoint local JSON acceptance must be 1...16777216 bytes.") }
    if let timeout, !timeout.isFinite || timeout <= 0 { throw HostDeviceSelectionError.parameterConflict("Mountpoint query timeout must be positive finite.") }
}
struct BoundDeviceMountpointSnapshot {
    let output: HostDeviceMountpointOutput
    let payload: TKDevicectlMountpointPayload
}
func queryIOSDeviceMountpointSnapshot(
    selection: HostDeviceSelectionResult, mountPolicy: HostDeviceMountPolicy? = nil, timeout: Double? = nil, maximumJSONBytes: Int = 1_048_576,
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) },
    reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON
) throws -> BoundDeviceMountpointSnapshot {
    guard let mountPolicy else { throw HostDeviceMountPolicyError.required }
    try mountPolicy.validate()
    guard selection.platform == .ios, ["simulator", "real"].contains(selection.target.scope),
          (selection.target.scope == "simulator" && selection.target.kind == "simulator") || (selection.target.scope == "real" && selection.target.kind == "real-device") else { throw HostDeviceMountpointError.unsupportedPlatform }
    try validateDeviceMountpointLimits(timeout: timeout, maximumJSONBytes: maximumJSONBytes)
    let paths = try artifactProvider("device-mountpoint")
    let baseCommand = TKDevicectlCommand.deviceInfoMountpoint(identifier: selection.target.rawTarget, jsonOutput: paths.json, logOutput: paths.log)
    let command = TKHostCommand(arguments: baseCommand.arguments, redactedArgumentIndexes: baseCommand.redactedArgumentIndexes, riskLevel: .automation, requiredConfig: baseCommand.requiredConfig.union([.auditRecord]), defaultTimeoutSeconds: baseCommand.defaultTimeoutSeconds, capturesArtifacts: true, sensitiveOutput: true).withTimeout(timeout)
    defer {
        for path in [paths.json, paths.log] where FileManager.default.fileExists(atPath: path) {
            hardenPrivateArtifact(path: path)
        }
    }
    let result: HostProcessResult
    do { result = try runner(command) }
    catch HostCommandRunError.timeout { throw HostDeviceMountpointError.timeout }
    catch { throw HostDeviceMountpointError.queryFailed }
    guard result.exitCode == 0 else { throw HostDeviceMountpointError.queryFailed }
    let data: Data
    do { data = try reader(paths.json, maximumJSONBytes) }
    catch HostDeviceFilesError.limitExceeded { throw HostDeviceMountpointError.limitExceeded }
    catch { throw HostDeviceMountpointError.jsonMissing }
    let payload: TKDevicectlMountpointPayload
    do { try validateDeviceMountReceipt(data, command: command); payload = try TKDevicectlMountpointParser.parse(data, maximumJSONBytes: maximumJSONBytes) }
    catch TKDevicectlMountpointError.limitExceeded { throw HostDeviceMountpointError.limitExceeded }
    catch { throw HostDeviceMountpointError.invalidJSON }
    // No result identity in the observed protocol: bind exact echoed request, not path/alias guesses.
    guard payload.deviceArgument == selection.target.rawTarget else { throw HostDeviceMountpointError.identityMismatch }
    if let identifier = payload.deviceIdentifier {
        let identities = selection.target.scope == "simulator" ? [selection.target.rawTarget] + selection.target.rawTargetAliases : [selection.target.rawTarget]
        guard identities.contains(where: { $0 == identifier || (UUID(uuidString: $0) != nil && UUID(uuidString: $0) == UUID(uuidString: identifier)) }) else { throw HostDeviceMountpointError.identityMismatch }
    }
    // Never access/normalize the returned filesystem path; this is a correlation token, not authority.
    let key = selection.target.id + "\0" + payload.dataPath
    let token = "devicefs:" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    let output = HostDeviceMountpointOutput(target: selection.target, mountpointToken: token, maximumJSONBytes: maximumJSONBytes, sourceCommands: [hostSourceCommand(command)], artifacts: [paths.json, paths.log])
    return BoundDeviceMountpointSnapshot(output: output, payload: payload)
}
func makeIOSDeviceMountpointOutput(
    selection: HostDeviceSelectionResult, mountPolicy: HostDeviceMountPolicy? = nil, timeout: Double? = nil, maximumJSONBytes: Int = 1_048_576,
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) },
    reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON
) throws -> HostDeviceMountpointOutput {
    try queryIOSDeviceMountpointSnapshot(selection: selection, mountPolicy: mountPolicy, timeout: timeout, maximumJSONBytes: maximumJSONBytes, artifactProvider: artifactProvider, runner: runner, reader: reader).output
}
