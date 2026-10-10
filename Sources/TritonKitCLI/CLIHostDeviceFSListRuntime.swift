import CryptoKit
import Darwin
import Foundation
import TritonKitShared

func boundDeviceFSRoot(path: String, selection: HostDeviceSelectionResult, homeDirectory: String = NSHomeDirectory()) throws -> String {
    let prefix = homeDirectory + "/Library/Developer/CoreDevice/DeviceFS/device-"
    let suffix = ".localized"
    let bytes = Array(path.utf8), prefixBytes = Array(prefix.utf8), suffixBytes = Array(suffix.utf8)
    guard bytes.count == prefixBytes.count + 36 + suffixBytes.count,
          bytes.starts(with: prefixBytes), bytes.suffix(suffixBytes.count).elementsEqual(suffixBytes),
          let rawUUID = String(bytes: bytes.dropFirst(prefixBytes.count).prefix(36), encoding: .utf8),
          let uuid = UUID(uuidString: rawUUID), uuid.uuidString.lowercased() == rawUUID.lowercased() else { throw HostDeviceFSError.rootMismatch }
    let identities = selection.target.scope == "simulator" ? [selection.target.rawTarget] + selection.target.rawTargetAliases : [selection.target.rawTarget]
    guard identities.contains(where: { UUID(uuidString: $0) == uuid }) else { throw HostDeviceFSError.rootMismatch }
    do { _ = try validatedDeviceFSComponents(root: path) }
    catch { throw HostDeviceFSError.rootMismatch }
    // Return exact bytes: UUID equivalence is identity binding, not path normalization or mount verification.
    return path
}
func makeIOSDeviceFSListOutput(
    selection: HostDeviceSelectionResult, view: DeviceFSView = .mountRoot, containerIdentifier: String? = nil, subdirectory: String? = nil, includeSensitive: Bool = false, timeout: Double? = nil,
    maximumJSONBytes: Int = 1_048_576, maximumEntries: Int = 1000, homeDirectory: String = NSHomeDirectory(),
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) },
    JSONReader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON,
    listReader: (String, String?, Int) throws -> [DeviceFSMetadataEntry] = { try readDeviceFSShallowMetadata(root: $0, relativeDirectory: $1, maximumEntries: $2, requiredOwner: getuid()) }
) throws -> HostDeviceFSListOutput {
    guard selection.platform == .ios else { throw HostDeviceFSError.unsupportedPlatform }
    try validateDeviceFilesLimits(timeout: timeout, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries)
    let relativeDirectory = try deviceFSRelativeDirectory(view: view, containerIdentifier: containerIdentifier, subdirectory: subdirectory)
    try validateDeviceFSSelectionBudget(homeDirectory: homeDirectory, relativeDirectory: relativeDirectory)
    let snapshot = try queryIOSDeviceMountpointSnapshot(selection: selection, timeout: timeout, maximumJSONBytes: maximumJSONBytes, artifactProvider: artifactProvider, runner: runner, reader: JSONReader)
    let root = try boundDeviceFSRoot(path: snapshot.payload.dataPath, selection: selection, homeDirectory: homeDirectory)
    do { _ = try validatedDeviceFSComponents(root: root, relativeDirectory: relativeDirectory) }
    catch { throw HostDeviceSelectionError.parameterConflict("Combined DeviceFS directory selection exceeds local depth/path bounds; query artifacts may exist, directory IO not started.") }
    let metadata: [DeviceFSMetadataEntry]
    do { metadata = try listReader(root, relativeDirectory, maximumEntries) }
    catch DeviceFSReaderError.limitExceeded { throw HostDeviceFSError.limitExceeded }
    catch DeviceFSReaderError.unsafeDirectory { throw HostDeviceFSError.unsafeRoot }
    catch { throw HostDeviceFSError.readFailed }
    guard metadata.count <= maximumEntries else { throw HostDeviceFSError.limitExceeded }
    let scopeKey = snapshot.output.mountpointToken + "\0" + (view == .mountRoot ? "" : view.rawValue + "\0") + (containerIdentifier.map { $0 + "\0" } ?? "") + (subdirectory.map { $0 + "\0" } ?? "")
    let directoryToken = containerIdentifier.map { _ in "directory:" + SHA256.hash(data: Data(scopeKey.utf8)).map { String(format: "%02x", $0) }.joined() }
    let entries = metadata.map { item in
        let key = scopeKey + item.name
        let token = "file:" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return HostDeviceFileEntryOutput(token: token, kind: item.kind, sizeBytes: item.kind == "regular-file" ? item.sizeBytes : nil, modifiedAt: nil, isHidden: nil, isReadable: nil, name: includeSensitive ? item.name : nil, relativePath: nil)
    }
    return HostDeviceFSListOutput(view: view.rawValue, directoryToken: directoryToken, target: selection.target, mountpointToken: snapshot.output.mountpointToken, entries: entries, count: entries.count, sensitiveMetadataIncluded: includeSensitive, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries, sourceCommands: snapshot.output.sourceCommands, artifacts: snapshot.output.artifacts)
}
