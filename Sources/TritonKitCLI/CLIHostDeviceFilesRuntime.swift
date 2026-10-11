import CryptoKit
import Darwin
import Foundation
import TritonKitShared

func validateDeviceFilesLimits(timeout: Double?, maximumJSONBytes: Int, maximumEntries: Int) throws {
    guard (1...16_777_216).contains(maximumJSONBytes), (1...10_000).contains(maximumEntries),
          timeout == nil || (timeout!.isFinite && timeout! > 0) else {
        throw HostDeviceSelectionError.parameterConflict("File timeout must be positive finite, JSON limit 1...16777216 bytes, entry limit 1...10000.")
    }
}

/// Bound allocation and reject final file/direct-parent symlinks. The producer uses a fresh private directory.
func readBoundedDeviceFilesJSON(_ path: String, maximumBytes: Int) throws -> Data {
    guard (1...16_777_216).contains(maximumBytes) else { throw HostDeviceFilesError.limitExceeded }
    var parent = stat()
    guard lstat(URL(fileURLWithPath: path).deletingLastPathComponent().path, &parent) == 0,
          parent.st_mode & S_IFMT == S_IFDIR, parent.st_uid == getuid(), parent.st_mode & 0o077 == 0 else { throw HostDeviceFilesError.jsonMissing }
    let descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
    guard descriptor >= 0 else { throw HostDeviceFilesError.jsonMissing }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    defer { try? handle.close() }
    var info = stat()
    guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid() else { throw HostDeviceFilesError.jsonMissing }
    guard info.st_size >= 0, info.st_size <= maximumBytes else { throw HostDeviceFilesError.limitExceeded }
    let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
    guard data.count <= maximumBytes else { throw HostDeviceFilesError.limitExceeded }
    return data
}

func makeIOSDeviceFilesOutput(
    selection: HostDeviceSelectionResult, request: TKDevicectlFilesRequest,
    includeSensitive: Bool = false, timeout: Double? = nil, maximumJSONBytes: Int = 1_048_576, maximumEntries: Int = 1000, temporaryPolicy: HostTemporaryDomainPolicy? = nil,
    temporaryWorkspaceProvider: () throws -> String = makeDeviceAdministrationWorkspace,
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) },
    reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON
) throws -> HostDeviceFilesOutput {
    guard selection.platform == .ios, ["simulator", "real"].contains(selection.target.scope) else { throw HostDeviceFilesError.unsupportedPlatform }
    try validateDeviceFilesLimits(timeout: timeout, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries)
    var auditArtifacts: [String] = []
    func query() throws -> HostDeviceFilesOutput {
        try acceptedIOSDeviceFilesOutput(selection: selection, request: request, includeSensitive: includeSensitive, timeout: timeout, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries, artifactProvider: { action in
            let paths = try artifactProvider(action)
            auditArtifacts = [paths.json, paths.log]
            return paths
        }, runner: runner, reader: reader)
    }
    if request.domain == "temporary" {
        guard let temporaryPolicy else { throw TKDevicectlFilesError.temporaryRequiresPolicy }
        return try withTemporaryDomainAudit(policy: temporaryPolicy, target: selection.target.id, domainIdentifier: request.domainIdentifier ?? "", workspace: temporaryWorkspaceProvider, artifacts: { auditArtifacts }) { token in
            var output = try query()
            output.riskLevel = "automation"
            output.temporaryDomainPolicy = "explicit-possible-creation-authorized; actual-creation-state-unknown"
            output.auditToken = token
            return output
        }
    }
    guard temporaryPolicy == nil else { throw HostDeviceSelectionError.parameterConflict("Temporary creation policy applies only to the temporary domain.") }
    return try query()
}

private func acceptedIOSDeviceFilesOutput(
    selection: HostDeviceSelectionResult, request: TKDevicectlFilesRequest,
    includeSensitive: Bool = false, timeout: Double? = nil, maximumJSONBytes: Int = 1_048_576, maximumEntries: Int = 1000,
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) },
    reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON
) throws -> HostDeviceFilesOutput {
    guard selection.platform == .ios, ["simulator", "real"].contains(selection.target.scope) else { throw HostDeviceFilesError.unsupportedPlatform }
    try validateDeviceFilesLimits(timeout: timeout, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries)
    let paths = try artifactProvider("device-files")
    let command = TKDevicectlCommand.deviceInfoFiles(identifier: selection.target.rawTarget, request: request, jsonOutput: paths.json, logOutput: paths.log).withTimeout(timeout)
    defer {
        for path in [paths.json, paths.log] where FileManager.default.fileExists(atPath: path) {
            hardenPrivateArtifact(path: path)
        }
    }
    func failure() -> HostDeviceFilesError {
        if let data = try? reader(paths.json, maximumJSONBytes), data.count <= maximumJSONBytes, TKDevicectlFilesParser.isUnsupported(data) { return .queryUnsupported }
        return .queryFailed
    }
    let result: HostProcessResult
    do { result = try runner(command) }
    catch HostCommandRunError.timeout { throw HostDeviceFilesError.timeout }
    catch HostCommandRunError.nonZeroExit { throw failure() }
    catch { throw HostDeviceFilesError.queryFailed }
    guard result.exitCode == 0 else { throw failure() }
    let data: Data
    do { data = try reader(paths.json, maximumJSONBytes) }
    catch let error as HostDeviceFilesError { throw error }
    catch { throw HostDeviceFilesError.jsonMissing }
    if request.domain == "temporary" { try validateTemporaryFilesReceipt(data, command: command) }
    let payload: TKDevicectlFilesPayload
    do { payload = try TKDevicectlFilesParser.parse(data, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries) }
    catch TKDevicectlFilesError.limitExceeded { throw HostDeviceFilesError.limitExceeded }
    catch { throw HostDeviceFilesError.invalidJSON }
    let identities = selection.target.scope == "simulator" ? [selection.target.rawTarget] + selection.target.rawTargetAliases : [selection.target.rawTarget]
    guard identities.contains(where: { $0 == payload.deviceIdentifier || (UUID(uuidString: $0) != nil && UUID(uuidString: $0) == UUID(uuidString: payload.deviceIdentifier)) }) else { throw HostDeviceFilesError.identityMismatch }
    guard payload.domain == request.domain else { throw HostDeviceFilesError.domainMismatch }
    if let actual = payload.domainIdentifier, actual != request.domainIdentifier { throw HostDeviceFilesError.domainMismatch }
    if let identifier = request.domainIdentifier {
        if let arguments = payload.arguments {
            let indexes = arguments.indices.filter { arguments[$0] == "--domain-identifier" }
            guard indexes.count == 1, let index = indexes.first, index + 1 < arguments.count, arguments[index + 1] == identifier else { throw HostDeviceFilesError.domainMismatch }
        } else if payload.domainIdentifier != identifier { throw HostDeviceFilesError.domainMismatch }
    }
    // Directory/user scope has no result-side identity field: require exact file-JSON argv binding.
    for (flag, expected) in [("--subdirectory", request.subdirectory), ("--username", request.username)] {
        let arguments = payload.arguments ?? []
        let indexes = arguments.indices.filter { arguments[$0] == flag }
        if let expected {
            guard indexes.count == 1, let index = indexes.first, index + 1 < arguments.count, arguments[index + 1] == expected else { throw HostDeviceFilesError.domainMismatch }
        } else if !indexes.isEmpty { throw HostDeviceFilesError.domainMismatch }
    }
    if let arguments = payload.arguments {
        for (flag, expected) in [("--device", selection.target.rawTarget), ("--domain-type", request.domain)] {
            let indexes = arguments.indices.filter { arguments[$0] == flag }
            if !indexes.isEmpty {
                guard indexes.count == 1, let index = indexes.first, index + 1 < arguments.count, arguments[index + 1] == expected else { throw HostDeviceFilesError.domainMismatch }
            }
        }
        if request.domainIdentifier == nil, arguments.contains("--domain-identifier") { throw HostDeviceFilesError.domainMismatch }
        if arguments.contains("--recurse") { throw HostDeviceFilesError.invalidJSON }
    }
    let entries = try payload.files.map { file in
        let components = file.relativePath.split(separator: "/").map(String.init)
        let requested = request.subdirectory?.split(separator: "/").map(String.init) ?? []
        guard components.count == 1 || (!requested.isEmpty && components == requested + [file.name]) else { throw HostDeviceFilesError.invalidJSON }
        let key = selection.target.id + "\0" + request.domain + "\0" + (request.domainIdentifier ?? "") + "\0" + (request.subdirectory ?? "") + "\0" + file.relativePath
        let token = "file:" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return HostDeviceFileEntryOutput(token: token, kind: file.kind, sizeBytes: file.sizeBytes, modifiedAt: file.modifiedAt, isHidden: file.isHidden, isReadable: file.isReadable, name: includeSensitive ? file.name : nil, relativePath: includeSensitive ? file.relativePath : nil)
    }
    return HostDeviceFilesOutput(target: selection.target, domain: request.domain, sensitiveMetadataIncluded: includeSensitive, entries: entries, count: entries.count, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries, sourceCommands: [hostSourceCommand(command)], artifacts: [paths.json, paths.log])
}
