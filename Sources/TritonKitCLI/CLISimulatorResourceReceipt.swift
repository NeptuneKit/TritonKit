import Darwin
import Foundation
import TritonKitShared

/// File reads remain on a nofollow descriptor chain; allocation is bounded.
/// Receipts from older versions with absent label sets remain a safe no-op.
enum SimulatorResourceReceiptReader {
    static func read(_ path: String) throws -> TKSimulatorResourceReceipt {
        let receipt = try JSONDecoder().decode(TKSimulatorResourceReceipt.self, from: readData(path))
        try validate(receipt)
        return receipt
    }

    static func validate(_ receipt: TKSimulatorResourceReceipt) throws {
        guard UUID(uuidString: receipt.udid) != nil,
              receipt.previous.udid == receipt.udid, receipt.applied.udid == receipt.udid,
              receipt.previousManagedDisabled.union(receipt.appliedManagedDisabled).isSubset(of: SimulatorResourceCatalog.managedLabels) else {
            throw SimulatorResourceMutationError.invalidReceipt
        }
        try receipt.profile.validate()
    }

    static func readData(_ path: String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        let parent = try SimulatorResourceSafeFiles.openDirectory(url.deletingLastPathComponent().path)
        defer { close(parent) }
        guard let data = try SimulatorResourceSafeFiles.read(parent: parent, name: url.lastPathComponent) else {
            throw SimulatorResourceMutationError.invalidReceipt
        }
        return data
    }
}

enum SimulatorResourceSafeFiles {
    static func openDirectory(_ path: String) throws -> Int32 {
        guard path.hasPrefix("/"), !path.contains("\0") else { throw SimulatorResourceMutationError.invalidReceipt }
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.contains("."), !parts.contains("..") else { throw SimulatorResourceMutationError.invalidReceipt }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw SimulatorResourceMutationError.invalidReceipt }
        do {
            for part in parts {
                let child = openat(fd, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard child >= 0 else { throw SimulatorResourceMutationError.invalidReceipt }
                close(fd); fd = child
            }
            return fd
        } catch { close(fd); throw error }
    }

    static func read(parent: Int32, name: String, maximumBytes: Int = 1_048_576) throws -> Data? {
        let fd = openat(parent, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        if fd < 0, errno == ENOENT { return nil }
        guard fd >= 0 else { throw SimulatorResourceMutationError.invalidReceipt }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var before = stat()
        guard fstat(fd, &before) == 0, before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == getuid(), before.st_nlink == 1,
              before.st_size >= 0, before.st_size <= maximumBytes else { throw SimulatorResourceMutationError.invalidReceipt }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        var after = stat()
        guard data.count <= maximumBytes, data.count == before.st_size,
              fstat(fd, &after) == 0, before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else { throw SimulatorResourceMutationError.invalidReceipt }
        return data
    }
}
