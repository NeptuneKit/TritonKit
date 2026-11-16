import CoreFoundation
import Darwin
import Foundation
import TritonKitShared

enum HostPreferencesRemoveError: Error {
    case unsafeStore
    case domainReadFailed
    case domainConflict
    case terminationFailed
    case deletionUnverified

    var detail: TKCLIErrorDetail {
        switch self {
        case .unsafeStore:
            .init(code: "preferences_store_unsafe", message: "The app preferences path could not be safely read.")
        case .domainReadFailed:
            .init(code: "preferences_domain_unavailable", message: "The Simulator did not return a bounded app-container preferences domain.",
                  hint: "Check that the selected Simulator is booted and its bundled defaults supports -container.")
        case .domainConflict:
            .init(code: "preferences_domain_conflict", message: "The native domain and disk state disagree. No deletion was attempted.",
                  hint: "Inspect the selected app's preferences and lifecycle before attempting another removal.")
        case .terminationFailed:
            .init(code: "preferences_relaunch_failed", message: "The Simulator could not confirm that the app stopped. No deletion was attempted.")
        case .deletionUnverified:
            .init(code: "preferences_removal_unverified", message: "The native deletion could not be verified.",
                  hint: "Read the preference and inspect the app's state before deciding whether to retry.")
        }
    }
}

/// Use the Simulator's per-container preferences service for a literal key.
/// A raw plist replacement can leave the value cached across app launches.
func removeHostPreference(
    simulator: String, bundleID: String, key: String, relaunch: Bool = false,
    containerProvider: () throws -> String,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0, maximumOutputBytes: 16_384) }
) throws -> HostPreferencesRemoveOutput {
    guard !key.isEmpty, key.utf8.count <= 1024,
          key.rangeOfCharacter(from: .controlCharacters) == nil else {
        throw RuntimeError("Preference key must contain 1...1024 UTF-8 bytes without control characters.")
    }
    guard !bundleID.isEmpty, !bundleID.hasPrefix("-"), bundleID != ".", bundleID != "..", bundleID.utf8.count <= 255,
          bundleID.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 95].contains($0) }) else {
        throw RuntimeError("Invalid bundle identifier for app preferences.")
    }
    let container = try containerProvider()
    let file = bundleID + ".plist"
    _ = try readPreferenceDisk(container: container, name: file)
    if relaunch, (try? runner(TKSimctlCommand.terminateApp(udid: simulator, bundleID: bundleID)).exitCode) != 0 {
        throw HostPreferencesRemoveError.terminationFailed
    }

    let domain = try readPreferenceDomain(simulator: simulator, container: container, bundleID: bundleID, runner: runner)
    let disk = try readPreferenceDisk(container: container, name: file)
    var expectedDomain = domain
    let existed = expectedDomain.removeValue(forKey: key) != nil
    var expectedDisk = disk
    let existedOnDisk = expectedDisk.removeValue(forKey: key) != nil
    guard (!existedOnDisk || existed), samePreferenceValue(expectedDomain, expectedDisk) else {
        throw HostPreferencesRemoveError.domainConflict
    }
    if existed {
        let delete = preferenceNativeCommand(simulator: simulator, container: container, operation: ["delete", bundleID, key])
        // Validate the current path again before letting the native provider open it.
        let current = try readPreferenceDisk(container: container, name: file)
        guard samePreferenceValue(current, disk) else { throw HostPreferencesRemoveError.domainConflict }
        do {
            let result = try runner(delete)
            guard result.exitCode == 0, !result.stdoutTruncated, !result.stderrTruncated else {
                throw HostPreferencesRemoveError.deletionUnverified
            }
            let finalDomain = try readPreferenceDomain(simulator: simulator, container: container, bundleID: bundleID, runner: runner)
            let finalDisk = try readPreferenceDisk(container: container, name: file)
            guard samePreferenceValue(finalDomain, expectedDomain), samePreferenceValue(finalDisk, expectedDisk) else {
                throw HostPreferencesRemoveError.deletionUnverified
            }
        } catch {
            throw HostPreferencesRemoveError.deletionUnverified
        }
    }

    let delivery: HostPreferencesRelaunchReceipt
    if relaunch {
        let launched = (try? runner(TKSimctlCommand.launchApp(udid: simulator, bundleID: bundleID)).exitCode) == 0
        delivery = .init(requested: true, status: launched ? "launched" : "launch-failed")
    } else {
        delivery = .init(requested: false, status: "not-requested")
    }
    return HostPreferencesRemoveOutput(ok: delivery.ok, simulatorUDID: simulator, bundleID: bundleID,
        key: key, existed: existed, removed: existed, diskWriteVerified: true, preferenceDomainVerified: true, relaunch: delivery)
}

private func preferenceNativeCommand(simulator: String, container: String, operation: [String]) -> TKHostCommand {
    TKHostCommand(arguments: ["simctl", "spawn", simulator, "defaults", "-container", container] + operation,
        environment: ["SIMCTL_CHILD_LC_ALL": "C"], redactedArgumentIndexes: [2, 5, 7, 8],
        riskLevel: operation.first == "delete" ? .automation : .readonly, defaultTimeoutSeconds: 15, sensitiveOutput: true)
}

private func readPreferenceDomain(
    simulator: String, container: String, bundleID: String, runner: (TKHostCommand) throws -> HostProcessResult
) throws -> [String: Any] {
    do {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("triton-prefs-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: directory) }
        let file = directory.appendingPathComponent("domain.plist")
        let command = preferenceNativeCommand(simulator: simulator, container: container, operation: ["export", bundleID, file.path])
        let result = try runner(command)
        guard result.exitCode == 0, !result.stdoutTruncated, !result.stderrTruncated else { throw HostPreferencesRemoveError.domainReadFailed }
        let descriptor = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw HostPreferencesRemoveError.domainReadFailed }
        defer { close(descriptor) }
        guard let data = try SimulatorResourceSafeFiles.read(parent: descriptor, name: file.lastPathComponent) else {
            throw HostPreferencesRemoveError.domainReadFailed
        }
        return try preferenceDictionary(data)
    } catch {
        throw HostPreferencesRemoveError.domainReadFailed
    }
}

private func readPreferenceDisk(container: String, name: String) throws -> [String: Any] {
    do {
        let root = try SimulatorResourceSafeFiles.openDirectory(container)
        defer { close(root) }
        let directoryFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        let library = openat(root, "Library", directoryFlags)
        if library < 0, errno == ENOENT { return [:] }
        guard library >= 0 else { throw HostPreferencesRemoveError.unsafeStore }
        defer { close(library) }
        let preferences = openat(library, "Preferences", directoryFlags)
        if preferences < 0, errno == ENOENT { return [:] }
        guard preferences >= 0 else { throw HostPreferencesRemoveError.unsafeStore }
        defer { close(preferences) }
        guard let data = try SimulatorResourceSafeFiles.read(parent: preferences, name: name) else { return [:] }
        return try preferenceDictionary(data)
    } catch {
        throw HostPreferencesRemoveError.unsafeStore
    }
}

private func preferenceDictionary(_ data: Data) throws -> [String: Any] {
    guard let dictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
        throw TKHostPreferencesError.invalidRoot
    }
    return dictionary
}

// Plist byte order can change across exports, and NSNumber equality alone conflates false and zero.
private func samePreferenceValue(_ lhs: Any, _ rhs: Any) -> Bool {
    let left = lhs as CFTypeRef
    let right = rhs as CFTypeRef
    let type = CFGetTypeID(left)
    guard type == CFGetTypeID(right) else { return false }
    if let a = lhs as? [String: Any], let b = rhs as? [String: Any] {
        return a.count == b.count && a.allSatisfy { key, value in
            b[key].map { samePreferenceValue(value, $0) } ?? false
        }
    }
    if let a = lhs as? [Any], let b = rhs as? [Any] {
        return a.count == b.count && zip(a, b).allSatisfy { samePreferenceValue($0, $1) }
    }
    if type == CFNumberGetTypeID(), let a = lhs as? NSNumber, let b = rhs as? NSNumber {
        guard CFNumberIsFloatType(a as CFNumber) == CFNumberIsFloatType(b as CFNumber) else { return false }
    }
    return CFEqual(left, right)
}
