import ArgumentParser
import Darwin
import Foundation
import TritonKitShared

enum XcodeCompilationCacheMode: String, ExpressibleByArgument { case shared }

struct XcodeCompilationCacheError: Error {
    let code: String
    let message: String

    static func invalid(_ message: String) -> Self {
        Self(code: "xcode_compilation_cache_invalid", message: message)
    }

    static let unsupported = Self(code: "xcode_compilation_cache_unsupported",
        message: "Shared compilation caching requires an iOS Simulator build with Xcode 27.1 or later within Xcode 27.")
}

struct XcodeCompilationCacheToolchain {
    let executable: String
    let developerDirectory: String
    let version: String

    static func supportedVersion(_ stdout: String) -> String? {
        guard let line = stdout.split(whereSeparator: \.isNewline).first, line.hasPrefix("Xcode ") else { return nil }
        let version = String(line.dropFirst("Xcode ".count))
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(components.count), components.allSatisfy({ Int($0) != nil && $0.utf8.allSatisfy { (48...57).contains($0) } }),
              Int(components[0]) == 27, let minor = Int(components[1]), minor >= 1 else { return nil }
        return version
    }

    static func selected() throws -> Self {
        do {
            let lookup = try runHostCommand(TKHostCommand(executable: "/usr/bin/xcrun", arguments: ["--find", "xcodebuild"], defaultTimeoutSeconds: 10), maximumOutputBytes: 4096)
            let path = lookup.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = "/usr/bin/xcodebuild"
            guard lookup.exitCode == 0, !lookup.stdoutTruncated, path.hasPrefix("/"), path.hasSuffix(suffix),
                  !path.contains(where: \.isNewline), FileManager.default.isExecutableFile(atPath: path) else { throw XcodeCompilationCacheError.unsupported }
            let developer = String(path.dropLast(suffix.count))
            let probe = try runHostCommand(TKHostCommand(executable: path, arguments: ["-version"], environment: ["DEVELOPER_DIR": developer], defaultTimeoutSeconds: 10), maximumOutputBytes: 4096)
            guard probe.exitCode == 0, !probe.stdoutTruncated, let version = supportedVersion(probe.stdout) else { throw XcodeCompilationCacheError.unsupported }
            return Self(executable: path, developerDirectory: developer, version: version)
        } catch {
            throw XcodeCompilationCacheError.unsupported
        }
    }
}

struct XcodeCompilationCacheConfiguration {
    let settings: [String]
    let derivedDataPath: String
    let toolchain: XcodeCompilationCacheToolchain

    func apply(to command: TKHostCommand) -> TKHostCommand {
        var environment = command.environment
        environment["DEVELOPER_DIR"] = toolchain.developerDirectory
        return TKHostCommand(executable: toolchain.executable, arguments: command.arguments,
            workingDirectory: command.workingDirectory, environment: environment,
            redactedEnvironmentKeys: command.redactedEnvironmentKeys, redactedArgumentIndexes: command.redactedArgumentIndexes,
            riskLevel: command.riskLevel, requiredConfig: command.requiredConfig, defaultTimeoutSeconds: command.defaultTimeoutSeconds,
            capturesArtifacts: command.capturesArtifacts, sensitiveOutput: command.sensitiveOutput, stdinData: command.stdinData)
    }
}

func validateXcodeCompilationCacheFlags(mode: XcodeCompilationCacheMode?, casPath: String?, root: String?, forTesting: Bool) throws {
    if mode == nil, casPath != nil || root != nil {
        throw XcodeCompilationCacheError.invalid("--cas-path and --cache-source-root require --compilation-cache shared.")
    }
    if mode != nil, forTesting {
        throw XcodeCompilationCacheError.invalid("--compilation-cache shared only supports plain build, not --for-testing.")
    }
}

func configureXcodeCompilationCache(
    mode: XcodeCompilationCacheMode?, casPath: String?, sourceRoot: String?, explicitDerivedData: String?,
    invocation: ResolvedXcodeInvocation, environment: [String: String] = ProcessInfo.processInfo.environment,
    toolchain: () throws -> XcodeCompilationCacheToolchain = XcodeCompilationCacheToolchain.selected
) throws -> XcodeCompilationCacheConfiguration? {
    try validateXcodeCompilationCacheFlags(mode: mode, casPath: casPath, root: sourceRoot, forTesting: false)
    guard mode == .shared else { return nil }
    guard !invocation.hasRealDeviceSelection,
          let destination = invocation.destination?.lowercased(),
          destination.split(separator: ",").contains(where: { $0 == "platform=ios simulator" || $0 == "generic/platform=ios simulator" }),
          let sdk = invocation.sdk?.lowercased(), sdk.hasPrefix("iphonesimulator") else { throw XcodeCompilationCacheError.unsupported }
    guard let casPath, let explicitDerivedData, let derivedData = invocation.derivedDataPath,
          casPath.hasPrefix("/"), explicitDerivedData.hasPrefix("/") else {
        throw XcodeCompilationCacheError.invalid("Shared caching requires explicit absolute --cas-path and --derived-data-path directories.")
    }
    if environment["XCODE_XCCONFIG_FILE"]?.isEmpty == false {
        throw XcodeCompilationCacheError.invalid("Unset XCODE_XCCONFIG_FILE before using shared caching; it can override the generated settings.")
    }
    if invocation.buildSettings.contains(where: { assignment in
        let name = String(assignment.prefix { $0 != "=" && $0 != "[" })
        return name.hasPrefix("COMPILATION_CACHE_") || ["SWIFT", "CLANG"].contains { family in
            ["ENABLE_COMPILE_CACHE", "ENABLE_PREFIX_MAPPING", "ENABLE_PROJECT_PREFIX_MAPPING", "OTHER_PREFIX_MAPPINGS"].contains { name == "\(family)_\($0)" }
        }
    }) {
        throw XcodeCompilationCacheError.invalid("Remove manual compilation-cache and prefix-mapping --build-setting overrides when using shared caching.")
    }
    guard let container = invocation.workspace ?? invocation.project ?? invocation.package, !container.isEmpty else {
        throw XcodeCompilationCacheError.invalid("Select one Xcode workspace, project, or Swift package.")
    }
    let containerURL = URL(fileURLWithPath: container)
    let packageDirectory = invocation.package != nil && containerURL.lastPathComponent != "Package.swift"
    let gitDirectory = packageDirectory ? containerURL.path : containerURL.deletingLastPathComponent().path
    guard let sourceRoot = sourceRoot ?? gitCacheSourceRoot(from: gitDirectory) else {
        throw XcodeCompilationCacheError.invalid("No Git root was found for the selected container; pass --cache-source-root explicitly.")
    }
    let source = try XcodeCompilationCachePath(sourceRoot, option: "--cache-source-root", mustExist: true)
    let derived = try XcodeCompilationCachePath(derivedData, option: "--derived-data-path")
    let cas = try XcodeCompilationCachePath(casPath, option: "--cas-path")
    guard let containerPhysical = resolveXcodeCachePath(containerURL.path)?.physical, source.contains(containerPhysical) else {
        throw XcodeCompilationCacheError.invalid("The selected Xcode container must be inside --cache-source-root.")
    }
    guard !source.overlaps(derived), !source.overlaps(cas), !derived.overlaps(cas) else {
        throw XcodeCompilationCacheError.invalid("Source root, DerivedData and CAS must be disjoint directories, including resolved aliases.")
    }
    let mappings = (source.spellings.map { "\($0)=/^wt" } + derived.spellings.map { "\($0)=/^dd" }).joined(separator: " ")
    let settings = ["COMPILATION_CACHE_ENABLE_CACHING=YES", "COMPILATION_CACHE_CAS_PATH=\(cas.path)", "COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES"]
        + ["SWIFT", "CLANG"].flatMap { ["\($0)_ENABLE_PREFIX_MAPPING=YES", "\($0)_ENABLE_PROJECT_PREFIX_MAPPING=NO", "\($0)_OTHER_PREFIX_MAPPINGS=\(mappings)"] }
    return XcodeCompilationCacheConfiguration(settings: settings, derivedDataPath: derived.path, toolchain: try toolchain())
}

private func gitCacheSourceRoot(from directory: String) -> String? {
    guard let result = try? runHostCommand(TKHostCommand(executable: "/usr/bin/git", arguments: ["-C", directory, "rev-parse", "--show-toplevel"], defaultTimeoutSeconds: 5), maximumOutputBytes: 4096),
          !result.stdoutTruncated, result.exitCode == 0 else { return nil }
    let root = result.stdout.trimmingCharacters(in: .newlines)
    return root.hasPrefix("/") && !root.contains(where: \.isNewline) ? root : nil
}

private struct XcodeCompilationCachePath {
    let path: String
    let spellings: [String]

    init(_ value: String, option: String, mustExist: Bool = false) throws {
        let invalid = XcodeCompilationCacheError.invalid("\(option) must be a non-root absolute directory without whitespace, controls, quotes, $, backslash, or =.")
        guard value.hasPrefix("/"), !value.split(separator: "/").contains(".."), XcodeCompilationCachePath.valid(value),
              let resolved = resolveXcodeCachePath(value, allowsMissingDirectories: !mustExist), resolved.physical != "/" else { throw invalid }
        let canonical = resolved.physical
        if mustExist {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: canonical, isDirectory: &isDirectory), isDirectory.boolValue else { throw invalid }
        }
        // Xcode and its SwiftPM adapter can use different spellings of one path (e.g. /tmp and /private/tmp).
        let spellings = [canonical, resolved.foundation, URL(fileURLWithPath: value).standardizedFileURL.path]
        guard spellings.allSatisfy(XcodeCompilationCachePath.valid) else { throw invalid }
        path = canonical
        var known = Set<String>()
        self.spellings = spellings.filter { known.insert($0).inserted }
    }

    func contains(_ other: String) -> Bool { other == path || other.hasPrefix(path + "/") }
    func overlaps(_ other: Self) -> Bool {
        // Missing siblings have no inode yet; disallow case-only separation even on case-sensitive volumes.
        let a = path.folding(options: .caseInsensitive, locale: nil)
        let b = other.path.folding(options: .caseInsensitive, locale: nil)
        return a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/")
    }

    private static func valid(_ path: String) -> Bool {
        let forbidden = CharacterSet.whitespacesAndNewlines.union(.controlCharacters).union(CharacterSet(charactersIn: "\"'=$\\"))
        return !path.unicodeScalars.contains(where: forbidden.contains)
    }
}

private func resolveXcodeCachePath(_ input: String, allowsMissingDirectories: Bool = false) -> (physical: String, foundation: String)? {
    var candidate = input
    var suffix: [String] = []
    while true {
        var info = stat()
        if candidate.withCString({ lstat($0, &info) }) == 0 {
            guard let resolved = candidate.withCString({ realpath($0, nil) }) else { return nil }
            defer { free(resolved) }
            let physical = String(cString: resolved)
            if allowsMissingDirectories || !suffix.isEmpty {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: physical, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            }
            // Standardizing a not-yet-created leaf leaves some macOS aliases intact.
            // Standardize the existing ancestor first, then append identical missing components.
            let foundation = URL(fileURLWithPath: physical).standardizedFileURL.path
            func withMissingSuffix(_ base: String) -> String {
                suffix.isEmpty ? base : ([base == "/" ? "" : base] + suffix.reversed()).joined(separator: "/")
            }
            return (withMissingSuffix(physical), withMissingSuffix(foundation))
        }
        guard allowsMissingDirectories, errno == ENOENT, candidate != "/" else { return nil }
        let path = candidate as NSString
        let parent = path.deletingLastPathComponent
        guard !parent.isEmpty, parent != candidate else { return nil }
        suffix.append(path.lastPathComponent)
        candidate = parent
    }
}
