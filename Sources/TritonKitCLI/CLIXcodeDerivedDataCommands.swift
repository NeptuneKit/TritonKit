import ArgumentParser
import Foundation

struct XcodeDerivedData: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "derived-data", abstract: "Inspect or clean Xcode DerivedData", subcommands: [XcodeDerivedDataInspect.self, XcodeDerivedDataCleanup.self])
}

struct XcodeDerivedDataInspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect DerivedData without modifying files")
    @Option(help: "DerivedData root; defaults to .triton/DerivedData") var root: String = ".triton/DerivedData"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    func run() async throws { try XcodeDerivedDataService.execute(root: root, cleanup: false, confirm: false, format: effectiveFormat(format, json: json)) }
}

struct XcodeDerivedDataCleanup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "cleanup", abstract: "Clean DerivedData; dry-run unless --confirm")
    @Option(help: "DerivedData root; defaults to .triton/DerivedData") var root: String = ".triton/DerivedData"
    @Flag(help: "Actually delete top-level cache entries") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    func run() async throws { try XcodeDerivedDataService.execute(root: root, cleanup: true, confirm: confirm, format: effectiveFormat(format, json: json)) }
}

private enum XcodeDerivedDataService {
    struct Entry: Codable { let name: String; let path: String; let bytes: Int64; let fileCount: Int; let latestModification: Date?; let action: String }
    struct Output: Codable { let ok: Bool; let action: String; let root: String; let dryRun: Bool; let totalBytes: Int64; let fileCount: Int; let directoryCount: Int; let latestModification: Date?; let entries: [Entry]; let breakdown: [Entry]; let symlinkSkipped: [String]; let errors: [String] }
    static func execute(root: String, cleanup: Bool, confirm: Bool, format: ClientOutputFormat) throws {
        let url = URL(fileURLWithPath: root).standardizedFileURL
        let canonical = url.resolvingSymlinksInPath()
        let isGlobal = canonical.path == NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
        let isRepoLocal = canonical.path.contains("/.triton/DerivedData")
        guard canonical.path == url.path, canonical.path != "/", isGlobal || isRepoLocal else { throw ValidationError("DerivedData root must be a canonical repo-local .triton/DerivedData or the user's Xcode DerivedData root") }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: canonical.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw ValidationError("DerivedData root does not exist: \(canonical.path)") }
        var symlinkSkipped: [String] = []
        let scanned = try scan(canonical, symlinkSkipped: &symlinkSkipped)
        if cleanup && confirm { for entry in scanned { let current = URL(fileURLWithPath: entry.path).resolvingSymlinksInPath(); guard current.path == entry.path, current.deletingLastPathComponent().path == canonical.path else { throw ValidationError("cache path changed during cleanup: \(entry.path)") }; try FileManager.default.removeItem(atPath: entry.path) } }
        let entries = scanned.map { Entry(name: $0.name, path: $0.path, bytes: $0.bytes, fileCount: $0.fileCount, latestModification: $0.latestModification, action: cleanup && confirm ? "deleted" : "would-delete") }
        let output = Output(ok: true, action: cleanup ? "xcode.derived-data.cleanup" : "xcode.derived-data.inspect", root: canonical.path, dryRun: !confirm, totalBytes: entries.reduce(0) { $0 + $1.bytes }, fileCount: entries.reduce(0) { $0 + $1.fileCount }, directoryCount: entries.count, latestModification: entries.compactMap(\.latestModification).max(), entries: entries, breakdown: entries, symlinkSkipped: symlinkSkipped, errors: [])
        if format == .json { print(try encodeJSON(output)) } else { print("\(output.action): \(output.totalBytes) bytes, \(output.fileCount) files, dryRun=\(output.dryRun)") }
    }
    static func scan(_ root: URL, symlinkSkipped: inout [String]) throws -> [Entry] {
        let fm = FileManager.default
        return try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey], options: []).compactMap { item in
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isSymbolicLink != true else { symlinkSkipped.append(item.path); return nil }
            if values.isDirectory == true { let children = try scan(item, symlinkSkipped: &symlinkSkipped); return Entry(name: item.lastPathComponent, path: item.path, bytes: children.reduce(0) { $0 + $1.bytes }, fileCount: children.reduce(0) { $0 + $1.fileCount }, latestModification: children.compactMap(\.latestModification).max(), action: "directory") }
            return Entry(name: item.lastPathComponent, path: item.path, bytes: Int64(values.fileSize ?? 0), fileCount: 1, latestModification: values.contentModificationDate, action: "file")
        }
    }
}
