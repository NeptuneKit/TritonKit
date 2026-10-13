import ArgumentParser
import Foundation

struct XcodeDerivedData: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "derived-data", abstract: "Inspect or clean Xcode DerivedData", subcommands: [XcodeDerivedDataInspect.self, XcodeDerivedDataCleanup.self])
}

struct XcodeDerivedDataInspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect DerivedData without modifying files")
    @Option(help: "DerivedData root; defaults to Xcode's user-level DerivedData folder") var root: String = defaultXcodeDerivedDataPath
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    func run() async throws {
        do {
            try XcodeDerivedDataService.execute(root: root, cleanup: false, confirm: false, format: effectiveFormat(format, json: json))
        } catch let error as XcodeDerivedDataSafetyError {
            try failHostValidation(code: error.code, message: error.description, hint: error.hint, outputFormat: effectiveFormat(format, json: json))
        } catch {
            try failHostCommand(error, outputFormat: effectiveFormat(format, json: json))
        }
    }
}

struct XcodeDerivedDataCleanup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "cleanup", abstract: "Preview DerivedData cleanup; confirmed deletion is temporarily unavailable")
    @Option(help: "DerivedData root; defaults to Xcode's user-level DerivedData folder") var root: String = defaultXcodeDerivedDataPath
    @Flag(help: "Request deletion (currently fails closed until safe deletion is available)") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    func run() async throws {
        do {
            try XcodeDerivedDataService.execute(root: root, cleanup: true, confirm: confirm, format: effectiveFormat(format, json: json))
        } catch let error as XcodeDerivedDataSafetyError {
            try failHostValidation(code: error.code, message: error.description, hint: error.hint, outputFormat: effectiveFormat(format, json: json))
        } catch {
            try failHostCommand(error, outputFormat: effectiveFormat(format, json: json))
        }
    }
}

enum XcodeDerivedDataSafetyError: Error, CustomStringConvertible {
    case invalidRoot(String)
    case missingRoot(String)
    case activeBuild(String)
    case cleanupUnavailable

    var code: String {
        switch self {
        case .invalidRoot: return "derived_data_root_rejected"
        case .missingRoot: return "derived_data_root_missing"
        case .activeBuild: return "xcode_not_idle"
        case .cleanupUnavailable: return "derived_data_cleanup_unavailable"
        }
    }

    var description: String {
        switch self {
        case .invalidRoot(let message), .missingRoot(let message), .activeBuild(let message): return message
        case .cleanupUnavailable: return "Confirmed DerivedData deletion is unavailable until race-safe cleanup and build coordination are implemented. No cache entries were deleted."
        }
    }

    var hint: String {
        switch self {
        case .invalidRoot: return "Use an existing canonical path ending in /.triton/DerivedData or the user's Xcode DerivedData root."
        case .missingRoot: return "Run `triton xcode derived-data inspect --root <path> --json` after creating the DerivedData directory."
        case .activeBuild: return "Wait for `triton xcode wait-idle --json` before retrying confirmed cleanup."
        case .cleanupUnavailable: return "Use inspect or cleanup without --confirm to review cache usage. Track GitHub issue #214 for safe deletion support."
        }
    }
}

enum XcodeDerivedDataService {
    struct Entry: Codable { let name: String; let path: String; let bytes: Int64; let fileCount: Int; let latestModification: Date?; let action: String }
    struct Output: Codable { let ok: Bool; let action: String; let root: String; let dryRun: Bool; let totalBytes: Int64; let fileCount: Int; let directoryCount: Int; let latestModification: Date?; let guidance: String; let entries: [Entry]; let breakdown: [Entry]; let symlinkSkipped: [String]; let errors: [String] }
    static func execute(
        root: String,
        cleanup: Bool,
        confirm: Bool,
        format: ClientOutputFormat,
        activeStatusProvider: () throws -> XcodeProcessStatusOutput = { try currentXcodeProcessStatus() }
    ) throws {
        let url = URL(fileURLWithPath: root).standardizedFileURL
        let canonical = url.resolvingSymlinksInPath()
        let isGlobal = canonical.path == defaultXcodeDerivedDataPath
        let components = canonical.path.split(separator: "/").map(String.init)
        let isRepoLocal = components.count >= 3 && Array(components.suffix(2)) == [".triton", "DerivedData"]
        guard canonical.path == url.path, canonical.path != "/", isGlobal || isRepoLocal else {
            throw XcodeDerivedDataSafetyError.invalidRoot("DerivedData root must be a canonical repo-local .triton/DerivedData or the user's Xcode DerivedData root")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: canonical.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw XcodeDerivedDataSafetyError.missingRoot("DerivedData root does not exist: \(canonical.path)")
        }
        var symlinkSkipped: [String] = []
        let scanned = try scan(canonical, symlinkSkipped: &symlinkSkipped)
        if cleanup && confirm {
            let status = try activeStatusProvider()
            // Process argv does not establish another process's working directory or
            // all GUI build activity. Any observed build-related process blocks cleanup.
            if !status.ok || status.active {
                throw XcodeDerivedDataSafetyError.activeBuild("Refusing to clean DerivedData while Xcode build activity is present or unknown")
            }
        }
        if cleanup && confirm {
            // A process snapshot and URL re-resolution cannot guarantee exclusion
            // against new builds or path replacement. Never reach removeItem here.
            throw XcodeDerivedDataSafetyError.cleanupUnavailable
        }
        let entries = scanned.map { entry in
            Entry(name: entry.name, path: entry.path, bytes: entry.bytes, fileCount: entry.fileCount, latestModification: entry.latestModification, action: cleanup ? "would-delete" : "inspect")
        }
        let output = Output(ok: true, action: cleanup ? "xcode.derived-data.cleanup" : "xcode.derived-data.inspect", root: canonical.path, dryRun: true, totalBytes: entries.reduce(0) { $0 + $1.bytes }, fileCount: entries.reduce(0) { $0 + $1.fileCount }, directoryCount: scanned.filter { $0.action == "directory" }.count, latestModification: entries.compactMap(\.latestModification).max(), guidance: xcodeDerivedDataGuidance(path: canonical.path), entries: entries, breakdown: entries, symlinkSkipped: symlinkSkipped, errors: [])
        if format == .json { print(try encodeJSON(output)) } else { print("\(output.action): \(output.totalBytes) bytes, \(output.fileCount) files, dryRun=\(output.dryRun)\n\(output.guidance)") }
    }

    static func scan(_ root: URL, symlinkSkipped: inout [String]) throws -> [Entry] {
        let fm = FileManager.default
        return try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey], options: []).compactMap { item -> Entry? in
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isSymbolicLink != true else { symlinkSkipped.append(item.path); return nil }
            if values.isDirectory == true {
                let children = try scan(item, symlinkSkipped: &symlinkSkipped)
                let latestModification = ([values.contentModificationDate] + children.map(\.latestModification)).compactMap { $0 }.max()
                return Entry(name: item.lastPathComponent, path: item.path, bytes: children.reduce(0) { $0 + $1.bytes }, fileCount: children.reduce(0) { $0 + $1.fileCount }, latestModification: latestModification, action: "directory")
            }
            return Entry(name: item.lastPathComponent, path: item.path, bytes: Int64(values.fileSize ?? 0), fileCount: 1, latestModification: values.contentModificationDate, action: "file")
        }
    }
}
