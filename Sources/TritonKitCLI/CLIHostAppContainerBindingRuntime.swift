import CryptoKit
import Darwin
import Foundation
import TritonKitShared

func validateAppContainerBindingRequest(bundleIdentifier: String, groupIdentifier: String?, timeout: Double?, maximumJSONBytes: Int, maximumEntries: Int) throws {
    try validateDeviceFilesLimits(timeout: timeout, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries)
    for value in [bundleIdentifier, groupIdentifier].compactMap({ $0 }) {
        guard !value.isEmpty, value.utf8.count <= 4096, !value.hasPrefix("-"), value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              value.rangeOfCharacter(from: .controlCharacters) == nil, !value.contains("/") else { throw HostDeviceSelectionError.parameterConflict("Bundle/group selection requires bounded nonempty exact identifiers without whitespace, control characters or slash.") }
    }
}

func boundSimulatorAppContainerPath(path: String, selection: HostDeviceSelectionResult, group: Bool, homeDirectory: String = NSHomeDirectory()) throws -> String {
    guard selection.target.scope == "simulator", selection.target.kind == "simulator", UUID(uuidString: selection.target.rawTarget) != nil else { throw HostAppContainerBindingError.rootMismatch }
    let root = homeDirectory + "/Library/Developer/CoreSimulator/Devices/" + selection.target.rawTarget
    let prefix = root + (group ? "/data/Containers/Shared/AppGroup/" : "/data/Containers/Data/Application/")
    let bytes = Array(path.utf8), prefixBytes = Array(prefix.utf8)
    guard bytes.count == prefixBytes.count + 36, bytes.starts(with: prefixBytes),
          let component = String(bytes: bytes.suffix(36), encoding: .utf8), UUID(uuidString: component) != nil else { throw HostAppContainerBindingError.rootMismatch }
    do { _ = try validatedDeviceFSComponents(root: path) } catch { throw HostAppContainerBindingError.rootMismatch }
    return path
}

func makeAppContainerBindingOutput(
    selection: HostDeviceSelectionResult, bundleIdentifier: String, groupIdentifier: String? = nil, list: Bool = false,
    timeout: Double? = nil, maximumJSONBytes: Int = 1_048_576, maximumEntries: Int = 1000, homeDirectory: String = NSHomeDirectory(),
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) },
    reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON,
    listReader: (String, String?, Int) throws -> [DeviceFSMetadataEntry] = { try readDeviceFSShallowMetadata(root: $0, relativeDirectory: $1, maximumEntries: $2, requiredOwner: getuid()) }
) throws -> HostAppContainerBindingOutput {
    guard selection.platform == .ios, ["simulator", "real"].contains(selection.target.scope),
          (selection.target.scope == "simulator" && selection.target.kind == "simulator") || (selection.target.scope == "real" && selection.target.kind == "real-device") else { throw HostAppContainerBindingError.unsupportedPlatform }
    try validateAppContainerBindingRequest(bundleIdentifier: bundleIdentifier, groupIdentifier: groupIdentifier, timeout: timeout, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries)
    if list && selection.target.scope != "simulator" { throw HostAppContainerBindingError.unsupportedListing }
    let helpCommand = TKHostCommand(arguments: ["devicectl", "device", "info", "apps", "--help"]).withTimeout(timeout)
    let help: HostProcessResult
    do { help = try runner(helpCommand) }
    catch HostCommandRunError.timeout { throw HostAppContainerBindingError.timeout }
    catch { throw HostAppContainerBindingError.unsupportedSDK }
    let helpText = String(decoding: help.stdoutData, as: UTF8.self)
    let tokens = Set(helpText.split(whereSeparator: { $0.isWhitespace || $0 == "/" }).map(String.init))
    guard help.exitCode == 0, !help.stdoutTruncated,
          ["--bundle-id", "--include-all-apps", "--include-container-paths", "--include-app-group-identifiers", "--device", "--json-output", "--log-output"].allSatisfy(tokens.contains) else { throw HostAppContainerBindingError.unsupportedSDK }
    let paths = try artifactProvider("app-containers")
    let command = TKHostCommand(arguments: ["devicectl", "device", "info", "apps", "--device", selection.target.rawTarget, "--bundle-id", bundleIdentifier, "--include-all-apps", "--include-container-paths", "--include-app-group-identifiers", "--json-output", paths.json, "--log-output", paths.log], redactedArgumentIndexes: [5, 7], requiredConfig: [.target, .timeout, .artifactDir, .redactionPolicy], capturesArtifacts: true, sensitiveOutput: true).withTimeout(timeout)
    defer {
        for path in [paths.json, paths.log] {
            let descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
            if descriptor >= 0 {
                var info = stat()
                if fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid() { _ = fchmod(descriptor, 0o600) }
                close(descriptor)
            }
        }
    }
    let result: HostProcessResult
    do { result = try runner(command) }
    catch HostCommandRunError.timeout { throw HostAppContainerBindingError.timeout }
    catch { throw HostAppContainerBindingError.queryFailed }
    guard result.exitCode == 0 else { throw HostAppContainerBindingError.queryFailed }
    let data: Data
    do { data = try reader(paths.json, maximumJSONBytes) }
    catch HostDeviceFilesError.limitExceeded { throw HostAppContainerBindingError.limitExceeded }
    catch { throw HostAppContainerBindingError.jsonMissing }
    let payload: TKAppContainerBindingPayload
    do { payload = try TKAppContainerBindingParser.parse(data, bundleIdentifier: bundleIdentifier, groupIdentifier: groupIdentifier, maximumJSONBytes: maximumJSONBytes) }
    catch TKAppContainerBindingError.limitExceeded { throw HostAppContainerBindingError.limitExceeded }
    catch { throw HostAppContainerBindingError.invalidJSON }
    let identities = selection.target.scope == "simulator" ? [selection.target.rawTarget] + selection.target.rawTargetAliases : [selection.target.rawTarget]
    guard payload.deviceArgument == selection.target.rawTarget,
          identities.contains(where: { $0 == payload.deviceIdentifier || (UUID(uuidString: $0) != nil && UUID(uuidString: $0) == UUID(uuidString: payload.deviceIdentifier)) }) else { throw HostAppContainerBindingError.identityMismatch }
    if let path = payload.containerPath, selection.target.scope == "simulator" {
        _ = try boundSimulatorAppContainerPath(path: path, selection: selection, group: groupIdentifier != nil, homeDirectory: homeDirectory)
    }
    func token(_ type: String, _ key: String) -> String { type + ":" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined() }
    let key = selection.target.id + "\0" + bundleIdentifier + "\0" + (groupIdentifier ?? "")
    let containerToken = payload.containerPath.map { token("container", key + "\0" + $0) }
    var entries: [HostDeviceFileEntryOutput] = []
    if list {
        guard let path = payload.containerPath else { throw HostAppContainerBindingError.unavailable }
        // Start ownership enforcement at the selected Simulator root and retain it for every descendant.
        let root = homeDirectory + "/Library/Developer/CoreSimulator/Devices/" + selection.target.rawTarget
        let relative = String(decoding: path.utf8.dropFirst(root.utf8.count + 1), as: UTF8.self)
        let metadata: [DeviceFSMetadataEntry]
        do { metadata = try listReader(root, relative, maximumEntries) }
        catch DeviceFSReaderError.limitExceeded { throw HostAppContainerBindingError.limitExceeded }
        catch DeviceFSReaderError.directoryUnavailable { throw HostAppContainerBindingError.unavailable }
        catch DeviceFSReaderError.unsafeDirectory { throw HostAppContainerBindingError.unsafeRoot }
        catch { throw HostAppContainerBindingError.readFailed }
        guard metadata.count <= maximumEntries else { throw HostAppContainerBindingError.limitExceeded }
        entries = metadata.map { entry in
            HostDeviceFileEntryOutput(token: token("file", key + "\0" + path + "\0" + entry.name), kind: entry.kind, sizeBytes: entry.kind == "regular-file" ? entry.sizeBytes : nil, modifiedAt: nil, isHidden: nil, isReadable: nil, name: nil, relativePath: nil)
        }
    }
    return HostAppContainerBindingOutput(target: selection.target, backend: list ? "coresimulator-native" : "sdk-metadata", bindingStatus: payload.bindingStatus, containerKind: groupIdentifier == nil ? "app-data" : "app-group", applicationToken: token("application", selection.target.id + "\0" + bundleIdentifier), groupToken: groupIdentifier.map { token("group", selection.target.id + "\0" + $0) }, containerToken: containerToken, containerAccessible: payload.containerAccessible, hostFilesystemInspected: list, entries: entries, count: entries.count, maximumJSONBytes: maximumJSONBytes, maximumEntries: maximumEntries, verification: list ? "executed-file-json-and-descriptor-metadata" : "executed-file-json", sourceCommands: [hostSourceCommand(helpCommand), hostSourceCommand(command)], artifacts: [paths.json, paths.log])
}
