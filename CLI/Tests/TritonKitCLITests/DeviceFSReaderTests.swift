import Darwin
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Internal DeviceFS no-follow descriptor metadata reader")
struct DeviceFSReaderTests {
    @Test("actual DeviceFS synthetic dirent IDs admit only same-device same-kind stable double-stat; other filesystems strict")
    func syntheticInodes() {
        var first = stat(); first.st_ino = 271384831241098846; first.st_dev = 42; first.st_mode = S_IFDIR
        let directoryInode: UInt64 = 8566465760407218799
        #expect(deviceFSEntryIdentityAccepted(directoryInode: directoryInode, first: first, second: first, filesystemType: "devicefs"))
        for type in ["apfs", "unknown", "DeviceFS", "fuse", "devicefs-spoof"] {
            #expect(!deviceFSEntryIdentityAccepted(directoryInode: directoryInode, first: first, second: first, filesystemType: type))
            #expect(!deviceFSEntryIdentityAccepted(directoryInode: 0, first: first, second: first, filesystemType: type))
        }
        #expect(deviceFSEntryIdentityAccepted(directoryInode: first.st_ino, first: first, second: first, filesystemType: "apfs"))
        var changed = first; changed.st_ino += 1
        #expect(!deviceFSEntryIdentityAccepted(directoryInode: directoryInode, first: first, second: changed, filesystemType: "devicefs"))
        changed = first; changed.st_dev += 1
        #expect(!deviceFSEntryIdentityAccepted(directoryInode: directoryInode, first: first, second: changed, filesystemType: "devicefs"))
        changed = first; changed.st_mode = S_IFLNK
        #expect(!deviceFSEntryIdentityAccepted(directoryInode: directoryInode, first: first, second: changed, filesystemType: "devicefs"))
    }
    @Test("root-owner mismatch is rejected even when selected namespace owner matches; no path reopening")
    func rootOwnerBeforeRelative() throws {
        let owned = try fixture()
        var parent = stat()
        try #require(lstat("/private/tmp", &parent) == 0)
        try #require(parent.st_uid != getuid(), "This fixture requires normal user owned child beneath system-owned private/tmp")
        #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: "/private/tmp", relativeDirectory: owned.lastPathComponent, requiredOwner: getuid()) }
        // Reverse the expected owner to prove namespace owner is independently checked after root passes.
        #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: "/private/tmp", relativeDirectory: owned.lastPathComponent, requiredOwner: parent.st_uid) }
    }
    @Test("final owner check runs on same descriptor before listing")
    func ownerBinding() throws {
        let root = try fixture()
        #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: root.path, requiredOwner: getuid() == 0 ? 1 : 0) }
        #expect(try readDeviceFSShallowMetadata(root: root.path, requiredOwner: getuid()).isEmpty)
    }
    // /tmp on macOS is a symlink; explicit fixture root uses /private/tmp, never realpath on untrusted input.
    private func fixture() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("SP183-FS-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return root
    }
    @Test("selected relative subdirectory is shallow and middle/selected links rejected")
    func selectedSubdirectory() throws {
        let root = try fixture(); let container = root.appendingPathComponent("AppDataContainers/id")
        let selected = container.appendingPathComponent("Library/Selected")
        try FileManager.default.createDirectory(at: selected.appendingPathComponent("deeper"), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try Data("PRIVATE-CONTENT".utf8).write(to: selected.appendingPathComponent("deeper/not-listed"))
        let listed = try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: "AppDataContainers/id/Library/Selected", requiredOwner: getuid())
        #expect(listed.map(\.name) == ["deeper"] && listed[0].kind == "directory")
        try FileManager.default.createSymbolicLink(at: container.appendingPathComponent("middle-link"), withDestinationURL: selected.deletingLastPathComponent())
        try FileManager.default.createSymbolicLink(at: selected.deletingLastPathComponent().appendingPathComponent("selected-link"), withDestinationURL: selected)
        for relative in ["AppDataContainers/id/middle-link/Selected", "AppDataContainers/id/Library/selected-link"] {
            #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: relative, requiredOwner: getuid()) }
        }
    }
    @Test("two-layer native container metadata preserves owner/nofollow, excludes nested contents and blocks container links")
    func containerDirectory() throws {
        let root = try fixture(); let namespace = root.appendingPathComponent("AppDataContainers")
        let container = namespace.appendingPathComponent("explicit-child")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.createDirectory(at: container.appendingPathComponent("nested"), withIntermediateDirectories: false)
        try Data("NEVER-READ".utf8).write(to: container.appendingPathComponent("nested/hidden"))
        #expect(mkfifo(container.appendingPathComponent("fifo").path, 0o600) == 0)
        try FileManager.default.createSymbolicLink(atPath: container.appendingPathComponent("leaf-link").path, withDestinationPath: "/never-existing/private")
        let entries = try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: "AppDataContainers/explicit-child", requiredOwner: getuid())
        #expect(Set(entries.map(\.name)) == ["nested", "fifo", "leaf-link"])
        #expect(entries.first { $0.name == "leaf-link" }?.kind == "symbolic-link")
        #expect(throws: DeviceFSReaderError.limitExceeded) { _ = try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: "AppDataContainers/explicit-child", maximumEntries: 1, requiredOwner: getuid()) }
        try FileManager.default.createSymbolicLink(at: namespace.appendingPathComponent("container-link"), withDestinationURL: container)
        #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: "AppDataContainers/container-link", requiredOwner: getuid()) }
    }
    @Test("private shallow metadata does not follow leaf/dangling links or read contents")
    func metadata() throws {
        let root = try fixture()
        try Data("SECRET-CONTENT".utf8).write(to: root.appendingPathComponent("file"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("folder"), withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent("dangling").path, withDestinationPath: "/never-existing/SECRET")
        let result = try readDeviceFSShallowMetadata(root: root.path)
        #expect(result.count == 3)
        #expect(result.first { $0.name == "file" }?.sizeBytes == 14)
        #expect(result.first { $0.name == "folder" }?.kind == "directory")
        #expect(result.first { $0.name == "folder" }?.sizeBytes == nil)
        #expect(result.first { $0.name == "dangling" }?.kind == "symbolic-link")
    }
    @Test("root, ancestor and relative directory symlinks are rejected")
    func links() throws {
        let root = try fixture()
        let child = root.appendingPathComponent("child")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: child)
        #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: root.appendingPathComponent("link").path) }
        #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: "link") }
        #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: "/tmp" + root.path.dropFirst("/private/tmp".count)) }
        try Data().write(to: root.appendingPathComponent("file"))
        #expect(throws: DeviceFSReaderError.unsafeDirectory) { _ = try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: "file") }
    }
    @Test("entry acceptance bound rejects rather than truncates and accepts exact bound")
    func countBound() throws {
        let root = try fixture()
        for name in ["a", "b"] { try Data().write(to: root.appendingPathComponent(name)) }
        #expect(throws: DeviceFSReaderError.limitExceeded) { _ = try readDeviceFSShallowMetadata(root: root.path, maximumEntries: 1) }
        #expect(try readDeviceFSShallowMetadata(root: root.path, maximumEntries: 2).count == 2)
    }
    @Test("invalid paths and limits fail before filesystem use")
    func validation() {
        for root in ["relative", "/", "/a/../b", "/a//b", "/a/./b", "/a/", "/a\u{0}b"] {
            #expect(throws: DeviceFSReaderError.invalidPath) { _ = try readDeviceFSShallowMetadata(root: root) }
        }
        for relative in ["", ".", "..", "../x", "x/../y", "/absolute", "a//b", "a/", "a\nb", String(repeating: "a/", count: 65) + "a"] {
            #expect(throws: DeviceFSReaderError.invalidPath) { _ = try readDeviceFSShallowMetadata(root: "/private/fixture", relativeDirectory: relative) }
        }
        for limit in [0, -1, 10001] {
            #expect(throws: DeviceFSReaderError.invalidLimit) { _ = try readDeviceFSShallowMetadata(root: "/private/fixture", maximumEntries: limit) }
        }
    }
    @Test("dirent declared record and null terminator bound name extraction before byte access")
    func recordBoundary() throws {
        var entry = dirent()
        let offset = try #require(MemoryLayout<dirent>.offset(of: \.d_name))
        entry.d_namlen = 1
        withUnsafeMutableBytes(of: &entry) { bytes in bytes[offset] = 0x61; bytes[offset + 1] = 0 }
        entry.d_reclen = UInt16(offset + 1)
        #expect(throws: DeviceFSReaderError.enumerationFailed) { _ = try withUnsafePointer(to: &entry) { try decodedDeviceFSDirent($0) } }
        entry.d_reclen = UInt16(offset + 2)
        #expect(try withUnsafePointer(to: &entry) { try decodedDeviceFSDirent($0) } == "a")
        withUnsafeMutableBytes(of: &entry) { $0[offset + 1] = 0x62 }
        #expect(throws: DeviceFSReaderError.enumerationFailed) { _ = try withUnsafePointer(to: &entry) { try decodedDeviceFSDirent($0) } }
    }
    @Test("exact path budget counts separator only when relative directory exists; no filesystem access")
    func byteBudget() throws {
        let root = "/" + String(repeating: "a", count: 16383)
        #expect(try validatedDeviceFSComponents(root: root).count == 1)
        #expect(throws: DeviceFSReaderError.invalidPath) { _ = try validatedDeviceFSComponents(root: root + "a") }
        #expect(throws: DeviceFSReaderError.invalidPath) { _ = try validatedDeviceFSComponents(root: root, relativeDirectory: "a") }
        #expect(try validatedDeviceFSComponents(root: String(root.dropLast(2)), relativeDirectory: "a").count == 2)
    }
    @Test("short Darwin record next to guard page is decoded without reading whole d_name tuple")
    func guardPage() throws {
        let page = Int(getpagesize())
        let allocation = try #require(mmap(nil, page * 2, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0))
        try #require(allocation != MAP_FAILED)
        defer { munmap(allocation, page * 2) }
        try #require(mprotect(allocation.advanced(by: page), page, PROT_NONE) == 0)
        let raw = allocation.advanced(by: page - 32)
        let nameOffset = try #require(MemoryLayout<dirent>.offset(of: \.d_name))
        let lengthOffset = try #require(MemoryLayout<dirent>.offset(of: \.d_namlen))
        let recordOffset = try #require(MemoryLayout<dirent>.offset(of: \.d_reclen))
        try #require(nameOffset + 2 <= 32)
        raw.storeBytes(of: UInt16(1), toByteOffset: lengthOffset, as: UInt16.self)
        raw.storeBytes(of: UInt16(32), toByteOffset: recordOffset, as: UInt16.self)
        raw.storeBytes(of: UInt8(0x61), toByteOffset: nameOffset, as: UInt8.self)
        raw.storeBytes(of: UInt8(0), toByteOffset: nameOffset + 1, as: UInt8.self)
        #expect(try decodedDeviceFSDirent(UnsafePointer(raw.assumingMemoryBound(to: dirent.self))) == "a")
    }
    @Test("nested directory and special leaf report metadata only, never block opening FIFO contents")
    func nestedAndFIFO() throws {
        let root = try fixture()
        let directory = root.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try #require(mkfifo(directory.appendingPathComponent("pipe").path, 0o600) == 0)
        let entries = try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: "folder")
        #expect(entries.count == 1 && entries[0].kind == "other" && entries[0].sizeBytes == nil)
    }
    @Test("invalid UTF8 entry fails closed rather than substituting or leaking a wrong name")
    func invalidUTF8() throws {
        // APFS rejects invalid UTF8 creation itself; test the exact readdir byte-decoder boundary.
        for bytes in [Data([0xff]), Data(), Data("a/b".utf8), Data([0x61, 0])] {
            #expect(throws: DeviceFSReaderError.enumerationFailed) { _ = try decodedDeviceFSName(bytes) }
        }
        #expect(try decodedDeviceFSName(Data("中文 name".utf8)) == "中文 name")
    }
}
