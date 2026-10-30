import CryptoKit
import Darwin
import Foundation

struct EmulatorResourceReceipt: Codable {
    struct Entry: Codable {
        let item: EmulatorResourceItem
        let previous: String
        let applied: String
        var phase: String
    }
    let version: Int
    let id: String
    let identity: EmulatorResourceIdentity
    let createdAt: Date
    var entries: [Entry]
}

/// One lock per physical selector, independent of the receipt path.
final class EmulatorResourceLock {
    private let fd: Int32
    init(identity: EmulatorResourceIdentity) throws {
        let parent = try SimulatorResourceSafeFiles.openDirectory("/private/var/tmp")
        defer { close(parent) }
        let root = "triton-resource-\(getuid())"
        if mkdirat(parent, root, 0o700) != 0, errno != EEXIST { throw EmulatorResourceError("resource_lock_failed", "Cannot create resource lock directory") }
        let directory = openat(parent, root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else { throw EmulatorResourceError("resource_lock_failed", "Invalid resource lock directory") }
        defer { close(directory) }
        var info = stat()
        guard fstat(directory, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o077 == 0 else { throw EmulatorResourceError("resource_lock_failed", "Unsafe resource lock directory") }
        let key = "\(identity.platform.rawValue):\(identity.target)"
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        fd = openat(directory, name, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
        guard fd >= 0 else { throw EmulatorResourceError("resource_lock_failed", "Cannot open resource lock") }
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_nlink == 1, info.st_mode & S_IFMT == S_IFREG, flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd); throw EmulatorResourceError("resource_busy", "Another resource mutation owns this target")
        }
    }
    deinit { flock(fd, LOCK_UN); close(fd) }
}

enum EmulatorResourceStore {
    static func read(_ path: String) throws -> EmulatorResourceReceipt {
        do {
            let receipt = try JSONDecoder().decode(EmulatorResourceReceipt.self, from: SimulatorResourceReceiptReader.readData(path))
            try validate(receipt)
            return receipt
        } catch let error as EmulatorResourceError { throw error }
        catch { throw EmulatorResourceError("resource_invalid_receipt", "Receipt is missing, unsafe, or invalid") }
    }
    static func validate(_ receipt: EmulatorResourceReceipt) throws {
        guard receipt.version == 1, UUID(uuidString: receipt.id) != nil,
              !receipt.identity.target.isEmpty, !receipt.identity.instance.isEmpty, !receipt.identity.image.isEmpty, !receipt.identity.bootID.isEmpty,
              Set(receipt.entries.map(\.item.id)).count == receipt.entries.count else {
            throw EmulatorResourceError("resource_invalid_receipt", "Receipt identity, version, or entries are invalid")
        }
        for entry in receipt.entries {
            try EmulatorResourceCatalog.validate(entry.item, platform: receipt.identity.platform, value: entry.previous)
            guard entry.applied == entry.item.disabledValue,
                  ["pending", "intent", "applied", "restored", "conflict"].contains(entry.phase), entry.previous != entry.applied else {
                throw EmulatorResourceError("resource_invalid_receipt", "Receipt includes an invalid transition")
            }
        }
        let order = EmulatorResourceCatalog.items(receipt.identity.platform).map(\.id)
        let actual = receipt.entries.map(\.item.id)
        guard order.filter({ actual.contains($0) }) == actual else { throw EmulatorResourceError("resource_invalid_receipt", "Receipt dependency order is invalid") }
    }
    static func write(_ receipt: EmulatorResourceReceipt, path: String, create: Bool = false) throws {
        try validate(receipt)
        let url = URL(fileURLWithPath: path)
        do {
            let parent = try SimulatorResourceSafeFiles.openDirectory(url.deletingLastPathComponent().path)
            defer { close(parent) }
            var info = stat()
            guard fstat(parent, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o022 == 0 else { throw EmulatorResourceError("resource_receipt_write_failed", "Receipt parent must be owned and not group/world writable") }
            let existing = try SimulatorResourceSafeFiles.read(parent: parent, name: url.lastPathComponent)
            if create {
                guard existing == nil else { throw EmulatorResourceError("resource_receipt_exists", "Use a new receipt path; existing receipts are never overwritten") }
            } else {
                guard let existing, let old = try? JSONDecoder().decode(EmulatorResourceReceipt.self, from: existing), old.id == receipt.id else { throw EmulatorResourceError("resource_invalid_receipt", "Receipt changed during operation") }
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(receipt)
            guard data.count <= 1_048_576 else { throw EmulatorResourceError("resource_receipt_write_failed", "Receipt exceeds size limit") }
            let temporary = ".triton-resource-\(UUID().uuidString)"
            let fd = openat(parent, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard fd >= 0 else { throw EmulatorResourceError("resource_receipt_write_failed", "Cannot create receipt") }
            defer { unlinkat(parent, temporary, 0) }
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            guard fsync(fd) == 0 else { throw EmulatorResourceError("resource_receipt_write_failed", "Cannot sync receipt") }
            let result = create ? linkat(parent, temporary, parent, url.lastPathComponent, 0) : renameat(parent, temporary, parent, url.lastPathComponent)
            guard result == 0 else { throw EmulatorResourceError("resource_receipt_write_failed", "Cannot publish receipt") }
            if create, unlinkat(parent, temporary, 0) != 0 { throw EmulatorResourceError("resource_receipt_write_failed", "Cannot finalize receipt") }
            guard fsync(parent) == 0 else { throw EmulatorResourceError("resource_receipt_write_failed", "Cannot sync receipt directory") }
        } catch let error as EmulatorResourceError { throw error }
        catch { throw EmulatorResourceError("resource_receipt_write_failed", "Cannot safely persist receipt") }
    }
}
