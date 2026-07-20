import ArgumentParser
import Foundation
import TritonKitShared

enum HostAppPullDomain: String, ExpressibleByArgument, Codable, Equatable {
    case appData = "app-data"
    case appGroup = "app-group"

    var devicectlDomainType: TKDevicectlFileDomainType {
        switch self {
        case .appData:
            return .appDataContainer
        case .appGroup:
            return .appGroupDataContainer
        }
    }
}

enum HostAppPullError: Error, Equatable, CustomStringConvertible {
    case realDeviceRequired
    case destinationMissing
    case directoryNotAllowed
    case artifactTooLarge
    case unsafeArtifact

    var description: String {
        switch self {
        case .realDeviceRequired:
            return "App pull requires a ready iOS real-device target."
        case .destinationMissing:
            return "devicectl completed without writing the requested destination artifact."
        case .directoryNotAllowed:
            return "The pulled artifact is a directory, but --allow-directory was not provided."
        case .artifactTooLarge:
            return "The pulled artifact exceeds the configured --max-bytes limit."
        case .unsafeArtifact:
            return "The pulled artifact contains a symbolic link or unsupported file type."
        }
    }
}

struct HostAppPullExecutionRequest {
    let selection: HostDeviceSelectionResult
    let domain: HostAppPullDomain
    let domainIdentifier: String
    let appIdentifier: String
    let source: String
    let destination: String
    let overwrite: Bool
    let allowDirectory: Bool
    let maxBytes: UInt64
    let devicectlArtifacts: (json: String, log: String)
}

struct HostAppPullArtifact: Encodable, Equatable {
    let path: String
    let kind: String
    let bytes: UInt64
    let entryCount: Int
}

struct HostAppPullOutput: Encodable {
    let ok: Bool
    let action: String
    let runtimeScope: String
    let target: String
    let selection: HostDeviceSelectionResult
    let domain: String
    let domainIdentifier: String
    let source: String
    let destination: String
    let overwrite: Bool
    let allowDirectory: Bool
    let maxBytes: UInt64
    let tool: String
    let exitCode: Int32
    let riskLevel: String
    let sourceCommand: String
    let artifact: HostAppPullArtifact
    let artifacts: [String]
    let note: String
}

typealias HostAppPullCommandRunner = (TKHostCommand) throws -> HostProcessResult

func makeHostAppPullExecutionRequest(
    selection: HostDeviceSelectionResult,
    domain: HostAppPullDomain,
    bundleID: String?,
    groupID: String?,
    source: String,
    destination: String,
    overwrite: Bool,
    allowDirectory: Bool,
    maxBytes: UInt64,
    devicectlArtifacts: (json: String, log: String)
) throws -> HostAppPullExecutionRequest {
    guard selection.platform == .ios, selection.target.scope == "real", selection.target.kind == "real-device" else {
        throw HostAppPullError.realDeviceRequired
    }
    guard selection.target.ready else {
        throw HostCommandRunError.deviceNotReady(target: selection.target.target, timeoutSeconds: 0)
    }
    let domainIdentifier: String
    let appIdentifier: String
    switch domain {
    case .appData:
        guard let bundleID = nonemptyHostAppPullValue(bundleID) else {
            throw ValidationError("app pull --domain app-data requires --bundle-id.")
        }
        guard nonemptyHostAppPullValue(groupID) == nil else {
            throw ValidationError("--group-id can only be used with --domain app-group.")
        }
        domainIdentifier = bundleID
        appIdentifier = bundleID
    case .appGroup:
        guard let groupID = nonemptyHostAppPullValue(groupID) else {
            throw ValidationError("app pull --domain app-group requires --group-id.")
        }
        guard nonemptyHostAppPullValue(bundleID) == nil else {
            throw ValidationError("--bundle-id can only be used with --domain app-data.")
        }
        domainIdentifier = groupID
        appIdentifier = groupID
    }
    guard let source = nonemptyHostAppPullValue(source) else {
        throw ValidationError("app pull requires a non-empty --source path.")
    }
    guard let destination = nonemptyHostAppPullValue(destination) else {
        throw ValidationError("app pull requires a non-empty --destination path.")
    }
    guard maxBytes > 0 else {
        throw ValidationError("--max-bytes must be greater than zero.")
    }
    let destinationURL = URL(fileURLWithPath: destination).standardizedFileURL
    guard destinationURL.path != "/" else {
        throw ValidationError("app pull destination cannot be the filesystem root.")
    }
    return HostAppPullExecutionRequest(
        selection: selection,
        domain: domain,
        domainIdentifier: domainIdentifier,
        appIdentifier: appIdentifier,
        source: source,
        destination: destinationURL.path,
        overwrite: overwrite,
        allowDirectory: allowDirectory,
        maxBytes: maxBytes,
        devicectlArtifacts: devicectlArtifacts
    )
}

func executeHostAppPull(
    request: HostAppPullExecutionRequest,
    runner: HostAppPullCommandRunner = { try runHostCommand($0) }
) throws -> HostAppPullOutput {
    let fileManager = FileManager.default
    let destinationURL = URL(fileURLWithPath: request.destination).standardizedFileURL
    try validateHostAppPullDestination(destinationURL, overwrite: request.overwrite)
    try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let stagingURL = destinationURL.deletingLastPathComponent()
        .appendingPathComponent(".triton-app-pull-\(UUID().uuidString)")
    try prepareHostArtifactOutputPath(stagingURL.path)
    defer {
        try? fileManager.removeItem(at: stagingURL)
    }

    let command = TKDevicectlCommand.copyFromDevice(
        identifier: request.selection.target.rawTarget,
        source: request.source,
        destination: stagingURL.path,
        domainType: request.domain.devicectlDomainType,
        domainIdentifier: request.domainIdentifier,
        jsonOutput: request.devicectlArtifacts.json,
        logOutput: request.devicectlArtifacts.log
    )
    let result = try runner(command)
    guard fileManager.fileExists(atPath: stagingURL.path) else {
        throw HostAppPullError.destinationMissing
    }
    let stagedArtifact = try inspectHostAppPullArtifact(
        at: stagingURL,
        allowDirectory: request.allowDirectory,
        maxBytes: request.maxBytes
    )

    do {
        try validateHostAppPullDestination(destinationURL, overwrite: request.overwrite)
        if fileManager.fileExists(atPath: destinationURL.path) {
            guard request.overwrite else {
                throw HostArtifactOutputError.rejected(path: destinationURL.path, reason: "path already exists")
            }
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: stagingURL)
        } else {
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
        }
    } catch {
        if let error = error as? HostArtifactOutputError {
            throw error
        }
        throw HostArtifactOutputError.rejected(path: destinationURL.path, reason: error.localizedDescription)
    }

    let sourceCommand = redactHostActionSourceCommand(result.sourceCommand, selection: request.selection)
    return HostAppPullOutput(
        ok: true,
        action: "app.pull",
        runtimeScope: "host-ios-real-device",
        target: "\(request.selection.target.target)/app:\(request.appIdentifier)",
        selection: request.selection,
        domain: request.domain.rawValue,
        domainIdentifier: request.domainIdentifier,
        source: request.source,
        destination: destinationURL.path,
        overwrite: request.overwrite,
        allowDirectory: request.allowDirectory,
        maxBytes: request.maxBytes,
        tool: command.executable,
        exitCode: result.exitCode,
        riskLevel: command.riskLevel.rawValue,
        sourceCommand: sourceCommand,
        artifact: HostAppPullArtifact(
            path: destinationURL.path,
            kind: stagedArtifact.kind,
            bytes: stagedArtifact.bytes,
            entryCount: stagedArtifact.entryCount
        ),
        artifacts: [destinationURL.path, request.devicectlArtifacts.json, request.devicectlArtifacts.log],
        note: "The host artifact was copied from an iOS real-device container and passed the configured directory and byte bounds."
    )
}

private func nonemptyHostAppPullValue(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

private func validateHostAppPullDestination(_ destinationURL: URL, overwrite: Bool) throws {
    let fileManager = FileManager.default
    if (try? fileManager.destinationOfSymbolicLink(atPath: destinationURL.path)) != nil {
        throw HostArtifactOutputError.rejected(
            path: destinationURL.path,
            reason: "symbolic links are not accepted for artifact output"
        )
    }
    if fileManager.fileExists(atPath: destinationURL.path), !overwrite {
        throw HostArtifactOutputError.rejected(path: destinationURL.path, reason: "path already exists")
    }
}

private func inspectHostAppPullArtifact(
    at url: URL,
    allowDirectory: Bool,
    maxBytes: UInt64
) throws -> HostAppPullArtifact {
    let fileManager = FileManager.default
    let rootValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    if rootValues.isSymbolicLink == true {
        throw HostAppPullError.unsafeArtifact
    }
    if rootValues.isDirectory == true {
        guard allowDirectory else {
            throw HostAppPullError.directoryNotAllowed
        }
        var enumerationError: Error?
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [],
            errorHandler: { _, error in
                enumerationError = error
                return false
            }
        ) else {
            throw HostAppPullError.unsafeArtifact
        }
        var bytes: UInt64 = 0
        var entries = 0
        for case let entryURL as URL in enumerator {
            let values = try entryURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true else {
                throw HostAppPullError.unsafeArtifact
            }
            guard values.isDirectory == true || values.isRegularFile == true else {
                throw HostAppPullError.unsafeArtifact
            }
            entries += 1
            if values.isRegularFile == true {
                bytes += UInt64(values.fileSize ?? 0)
                guard bytes <= maxBytes else {
                    throw HostAppPullError.artifactTooLarge
                }
            }
        }
        if enumerationError != nil {
            throw HostAppPullError.unsafeArtifact
        }
        return HostAppPullArtifact(path: url.path, kind: "directory", bytes: bytes, entryCount: entries)
    }
    guard rootValues.isRegularFile == true else {
        throw HostAppPullError.unsafeArtifact
    }
    let bytes = UInt64(rootValues.fileSize ?? 0)
    guard bytes <= maxBytes else {
        throw HostAppPullError.artifactTooLarge
    }
    return HostAppPullArtifact(path: url.path, kind: "file", bytes: bytes, entryCount: 1)
}

struct HostAppPull: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pull",
        abstract: "Copy a bounded artifact from an iOS real-device app container"
    )

    @Option(help: "Unified iOS real-device selector") var device: String?
    @Option(help: "Device scope; app pull requires real") var scope: HostDeviceScope = .real
    @Option(help: "Container domain: app-data or app-group") var domain: HostAppPullDomain = .appData
    @Option(help: "App bundle identifier for --domain app-data") var bundleID: String?
    @Option(help: "App group identifier for --domain app-group") var groupID: String?
    @Option(help: "Source path relative to the selected container") var source: String
    @Option(help: "Fresh host destination path") var destination: String
    @Flag(help: "Replace an existing non-symlink destination only after a successful bounded staging copy") var overwrite = false
    @Flag(help: "Allow a directory result; single files are accepted by default") var allowDirectory = false
    @Option(help: "Maximum accepted artifact bytes") var maxBytes: UInt64 = 104_857_600
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard scope == .real else {
                throw HostAppPullError.realDeviceRequired
            }
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(
                    device: device,
                    platform: .ios,
                    scope: .real,
                    ready: true
                ),
                hdc: "hdc"
            )
            let artifacts = try freshDevicectlArtifactPaths(action: "app-pull")
            let request = try makeHostAppPullExecutionRequest(
                selection: selection,
                domain: domain,
                bundleID: bundleID,
                groupID: groupID,
                source: source,
                destination: destination,
                overwrite: overwrite,
                allowDirectory: allowDirectory,
                maxBytes: maxBytes,
                devicectlArtifacts: artifacts
            )
            let output = try executeHostAppPull(request: request)
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print(output.destination)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
