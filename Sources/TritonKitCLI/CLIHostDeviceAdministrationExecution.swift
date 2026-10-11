import ArgumentParser
import Darwin
import Foundation
import TritonKitShared

enum HostDeviceAdministrationError: Error, CustomStringConvertible {
    case policyRequired, invalidResult, identityMismatch, unsafeArtifact, artifactLimit, auditFailed, unsupported
    var code: String {
        switch self {
        case .policyRequired: "device_administration_policy_required"
        case .invalidResult: "device_administration_result_invalid"
        case .identityMismatch: "device_administration_identity_mismatch"
        case .unsafeArtifact: "device_administration_unsafe_artifact"
        case .artifactLimit: "device_administration_limit_exceeded"
        case .auditFailed: "device_administration_audit_failed"
        case .unsupported: "unsupported_device_administration"
        }
    }
    var description: String { "Device administration refused or incomplete (\(code)); inspect private local evidence. No automatic retry." }
}

struct HostDeviceAdministrationExecutionOutput: Encodable {
    let ok: Bool
    let action: String
    let runtimeScope = "host-device"
    let planOnly = false
    let executable = true
    let executed: Bool
    let status: String
    let target: String
    let riskLevel: String
    let verification = "native-file-json-and-independent-postcondition; backend-fixture-tested, physical-acceptance-not-performed"
    let auditToken: String
    let auditIntentPersisted: Bool
    let auditCompletionPersisted: Bool
    let nativeResultVerified: Bool
    let pairingStateVerified: Bool
    let pairingState: String?
    let diagnosticArchiveVerified: Bool
    let archiveBytes: Int?
    let error: TKCLIErrorDetail?
    let limitations = ["No physical administration or diagnostics acceptance performed by this implementation task.", "Native success requires exact file-JSON argv binding; unknown layouts remain partial, never inferred from exit zero.", "Timeout/failure may leave device changes or native temporary artifacts; never retry automatically.", "Diagnostics may include local host CoreDevice logs; disabling host sysdiagnose is not device-only collection.", "Native devicectl receives paths: workspace identity is checked before/after, but native IO cannot be fully FD-anchored or eliminate all same-user concurrent replacement races.", "Archive size limits acceptance/publication, not native collection, transport or peak disk usage. ZIP structure is checked without extraction; payload content/completeness and CRC are not verified."]
}

/// Strict common CoreDevice envelope contract, not a guessed operation-specific result shape.
func parseDeviceAdministrationResult(_ data: Data, command: TKHostCommand, nativeIdentifier: String) throws -> Bool {
    guard data.count <= 1_048_576,
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let info = root["info"] as? [String: Any], let argv = info["arguments"] as? [String],
          argv == command.arguments else { throw HostDeviceAdministrationError.identityMismatch }
    guard let outcome = info["outcome"] as? String, ["success", "failed"].contains(outcome) else { throw HostDeviceAdministrationError.invalidResult }
    guard outcome != "success" || root["error"] == nil else { throw HostDeviceAdministrationError.invalidResult }
    if outcome == "success", !(root["result"] is [String: Any]) { throw HostDeviceAdministrationError.invalidResult }
    if root.keys.contains("result"), !(root["result"] is [String: Any]) { throw HostDeviceAdministrationError.invalidResult }
    if let result = root["result"] as? [String: Any] {
        for key in ["identifier", "deviceIdentifier"] {
            if let identifier = result[key] { guard let value = identifier as? String, value == nativeIdentifier else { throw HostDeviceAdministrationError.identityMismatch } }
        }
        if let device = result["device"] {
            guard let value = device as? [String: Any], value["identifier"] as? String == nativeIdentifier else { throw HostDeviceAdministrationError.identityMismatch }
        }
        if let devices = result["devices"] {
            guard let values = devices as? [[String: Any]], values.count == 1,
                  values.first?["identifier"] as? String == nativeIdentifier else { throw HostDeviceAdministrationError.identityMismatch }
        }
    }
    return outcome == "success"
}

func makeDeviceAdministrationWorkspace() throws -> String {
    // Persistent, private audit tree. Reject symlinks in every path component.
    let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
    let root = home + "/.triton/device-administration"
    var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    guard fd >= 0 else { throw HostDeviceAdministrationError.auditFailed }
    defer { close(fd) }
    let parts = root.split(separator: "/").map(String.init)
    for (index, part) in parts.enumerated() {
        if index >= parts.count - 2, mkdirat(fd, part, 0o700) != 0 && errno != EEXIST { throw HostDeviceAdministrationError.auditFailed }
        let next = openat(fd, part, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard next >= 0 else { throw HostDeviceAdministrationError.auditFailed }
        close(fd); fd = next
        if index >= parts.count - 2 {
            var st = stat()
            guard fstat(fd, &st) == 0, st.st_uid == getuid(), st.st_mode & (index == parts.count - 1 ? 0o077 : 0o022) == 0 else { throw HostDeviceAdministrationError.auditFailed }
        }
    }
    let id = UUID().uuidString.lowercased()
    guard mkdirat(fd, id, 0o700) == 0, fsync(fd) == 0 else { throw HostDeviceAdministrationError.auditFailed }
    return root + "/" + id
}

/// Reopens all components without following links; caller retains FD for local IO.
func openDeviceAdministrationPrivateDirectory(_ path: String) throws -> Int32 {
    let parts = try validatedDeviceFSComponents(root: path)
    var fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
    do {
        for part in parts {
            let child = openat(fd, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard child >= 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
            close(fd); fd = child
            var st = stat()
            guard fstat(fd, &st) == 0, st.st_uid == 0 || st.st_uid == getuid(), st.st_mode & 0o022 == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
        }
        var st = stat()
        guard fstat(fd, &st) == 0, st.st_uid == getuid(), st.st_mode & 0o077 == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
        return fd
    } catch { close(fd); throw error }
}

func readDeviceAdministrationJSON(_ path: String) throws -> Data {
    let url = URL(fileURLWithPath: path)
    let parent = try openDeviceAdministrationPrivateDirectory(url.deletingLastPathComponent().path)
    defer { close(parent) }
    let fd = openat(parent, url.lastPathComponent, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
    guard fd >= 0 else { throw HostDeviceAdministrationError.invalidResult }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? handle.close() }
    var st = stat()
    guard fstat(fd, &st) == 0, st.st_mode & S_IFMT == S_IFREG, st.st_uid == getuid(), st.st_nlink == 1 else { throw HostDeviceAdministrationError.unsafeArtifact }
    guard st.st_size >= 0, st.st_size <= 1_048_576 else { throw HostDeviceAdministrationError.artifactLimit }
    let data = try handle.read(upToCount: 1_048_577) ?? Data()
    guard data.count <= 1_048_576 else { throw HostDeviceAdministrationError.artifactLimit }
    return data
}

func persistDeviceAdministrationAudit(_ value: [String: Any], directory: String, name: String) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    let parent = try openDeviceAdministrationPrivateDirectory(directory)
    defer { close(parent) }
    let fd = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard fd >= 0 else { throw HostDeviceAdministrationError.auditFailed }
    defer { close(fd) }
    let written = data.withUnsafeBytes { bytes -> Bool in
        var offset = 0
        while offset < bytes.count {
            let count = write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { return false }; offset += count
        }
        return true
    }
    guard written, fsync(fd) == 0, fsync(parent) == 0 else { throw HostDeviceAdministrationError.auditFailed }
}

func administrationPairingPostcondition(nativeIdentifier: String, directory: String, timeout: Double) throws -> String? {
    let json = directory + "/postcondition.json", log = directory + "/postcondition.log"
    let command = TKDevicectlCommand.deviceInfoDetails(identifier: nativeIdentifier, jsonOutput: json, logOutput: log).withTimeout(timeout)
    let result = try runHostCommand(command)
    guard result.exitCode == 0 else { return nil }
    let data = try readDeviceAdministrationJSON(json)
    return try parseAdministrationPairingPostcondition(data, command: command, nativeIdentifier: nativeIdentifier)
}

func parseAdministrationPairingPostcondition(_ data: Data, command: TKHostCommand, nativeIdentifier: String) throws -> String? {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let info = root["info"] as? [String: Any], info["outcome"] as? String == "success", root["error"] == nil,
          info["arguments"] as? [String] == command.arguments,
          let result = root["result"] as? [String: Any], result["identifier"] as? String == nativeIdentifier else { return nil }
    let connection: [String: Any]?
    if result.keys.contains("properties") {
        connection = (result["properties"] as? [String: Any])?["connection"] as? [String: Any]
    } else { connection = result["connectionProperties"] as? [String: Any] }
    guard let state = connection?["pairingState"] as? String, ["paired", "unpaired"].contains(state) else { return nil }
    return state
}

func executeDeviceAdministration(
    operation: DeviceAdministrationOperation, options: DeviceAdministrationOptions,
    resolver: ((HostDeviceSelectionRequest) throws -> HostDeviceSelectionResult)? = nil,
    commandProbe: (AppleHostCommandSpecification) -> HostAppleCommandSupport = { probeAppleHostCommand($0) },
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) },
    pairingProbe: (String, String, Double) throws -> String? = administrationPairingPostcondition,
    workspaceProvider: () throws -> String = makeDeviceAdministrationWorkspace
) throws -> HostDeviceAdministrationExecutionOutput {
    guard !options.planOnly, options.executeRunner, options.confirm,
          let audit = options.auditRecord, !audit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, audit.utf8.count <= 256,
          audit.rangeOfCharacter(from: .controlCharacters) == nil,
          (1...1_073_741_824).contains(options.maximumArchiveBytes) else { throw HostDeviceAdministrationError.policyRequired }
    // Reuse all existing pre-IO input, fresh identity and SDK safety checks.
    var planning = options; planning.planOnly = true
    var selected: HostDeviceSelectionResult?
    let plan = try makeDeviceAdministrationPlan(operation: operation, options: planning, resolver: { request in
        let value = try (resolver ?? { try resolveHostDeviceSelection(request: $0, hdc: "hdc", adb: "adb") })(request)
        selected = value; return value
    }, commandProbe: commandProbe)
    guard plan.commandSupport.supported, let selection = selected else { throw HostDeviceAdministrationError.unsupported }
    let publisher: DeviceDiagnosticArchive? = operation == .diagnose ? try DeviceDiagnosticArchive(destination: options.output!, maximumBytes: options.maximumArchiveBytes) : nil
    let directory: String
    do { directory = try workspaceProvider() } catch { throw HostDeviceAdministrationError.auditFailed }
    let workspaceFD = try openDeviceAdministrationPrivateDirectory(directory)
    defer { close(workspaceFD) }
    var workspaceIdentity = stat()
    guard fstat(workspaceFD, &workspaceIdentity) == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
    func verifyWorkspaceIdentity() throws {
        let current = try openDeviceAdministrationPrivateDirectory(directory)
        defer { close(current) }
        var st = stat()
        guard fstat(current, &st) == 0, st.st_dev == workspaceIdentity.st_dev, st.st_ino == workspaceIdentity.st_ino else { throw HostDeviceAdministrationError.unsafeArtifact }
    }
    let stagedArchive = directory + "/diagnostic.zip"
    let preview = plannedDeviceAdministrationCommand(operation: operation, nativeIdentifier: selection.target.rawTarget, archiveDestination: operation == .diagnose ? stagedArchive : nil, timeout: options.timeout)
    let arguments = preview.arguments.map { $0 == "<planned-private-json>" ? directory + "/result.json" : $0 == "<planned-private-log>" ? directory + "/native.log" : $0 }
    let privateIndexes = Set(arguments.indices.filter { arguments[$0] == selection.target.rawTarget || arguments[$0].hasPrefix(directory + "/") })
    let command = TKHostCommand(arguments: arguments, redactedArgumentIndexes: privateIndexes, riskLevel: preview.riskLevel, requiredConfig: preview.requiredConfig, defaultTimeoutSeconds: preview.defaultTimeoutSeconds, capturesArtifacts: true, sensitiveOutput: true)
    let token = URL(fileURLWithPath: directory).lastPathComponent
    let intent: [String: Any] = ["phase": "intent", "operation": operation.rawValue, "target": plan.target, "auditRecord": audit, "sourceCommand": hostSourceCommand(command), "createdAt": ISO8601DateFormatter().string(from: Date()), "riskConfirmed": true, "executionAuthorized": true]
    try persistDeviceAdministrationAudit(intent, directory: directory, name: "intent.json")
    try verifyWorkspaceIdentity()
    var status = "partial", native = false, pairingVerified = false, pairing: String?, bytes: Int?, code: String?
    var processSucceeded = false, executed = true
    do {
        let result = try runner(command)
        processSucceeded = result.exitCode == 0
        if !processSucceeded { status = "failed"; code = "device_administration_failed" }
    } catch HostCommandRunError.launchFailed { executed = false; status = "failed"; code = "device_administration_failed" }
    catch HostCommandRunError.timeout { status = "timed-out"; code = "device_administration_timeout" }
    catch { status = "failed"; code = "device_administration_failed" }
    if processSucceeded {
        do {
            try verifyWorkspaceIdentity()
            native = try parseDeviceAdministrationResult(readDeviceAdministrationJSON(directory + "/result.json"), command: command, nativeIdentifier: selection.target.rawTarget)
            if !native { status = "failed"; code = "device_administration_failed" }
            else if operation == .diagnose {
                bytes = try publisher!.publish(source: stagedArchive); status = "succeeded"
            } else {
                pairing = try pairingProbe(selection.target.rawTarget, directory, options.timeout ?? 30)
                try verifyWorkspaceIdentity()
                pairingVerified = operation == .pair ? pairing == "paired" : pairing == "unpaired"
                if pairingVerified { status = "succeeded" } else { code = "device_administration_postcondition_unverified" }
            }
        } catch let error as HostDeviceAdministrationError { code = error.code }
        catch { code = "device_administration_postcondition_unverified" }
    }
    // Tighten native files via no-follow descriptors only; never chmod a substituted symlink.
    for name in ["result.json", "native.log", "postcondition.json", "postcondition.log", "diagnostic.zip"] {
        let fd = openat(workspaceFD, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        if fd >= 0 { var st = stat(); if fstat(fd, &st) == 0 && st.st_uid == getuid() && st.st_mode & S_IFMT == S_IFREG { _ = fchmod(fd, 0o600) }; close(fd) }
    }
    var completion = true
    do { try verifyWorkspaceIdentity(); try persistDeviceAdministrationAudit(["phase": "completion", "operation": operation.rawValue, "target": plan.target, "status": status, "nativeResultVerified": native, "pairingStateVerified": pairingVerified, "diagnosticArchiveVerified": bytes != nil, "errorCode": code ?? "", "completedAt": ISO8601DateFormatter().string(from: Date())], directory: directory, name: "completion.json") }
    catch { completion = false; status = "partial"; code = "device_administration_audit_failed" }
    return HostDeviceAdministrationExecutionOutput(ok: status == "succeeded", action: "device." + operation.rawValue, executed: executed, status: status, target: plan.target, riskLevel: preview.riskLevel.rawValue, auditToken: token, auditIntentPersisted: true, auditCompletionPersisted: completion, nativeResultVerified: native, pairingStateVerified: pairingVerified, pairingState: pairing, diagnosticArchiveVerified: bytes != nil, archiveBytes: bytes, error: code.map { TKCLIErrorDetail(code: $0, message: "Administration \(status); device state may have changed. Inspect private audit evidence; do not automatically retry.") })
}
