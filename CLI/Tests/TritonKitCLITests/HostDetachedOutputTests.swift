import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct HostDetachedOutputTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("triton-detached-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("prechecked leaf claimed by another writer is rejected without mutation", arguments: ["regular", "hardlink", "symlink", "fifo"])
    func claimedLeaf(_ kind: String) throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let leaf = dir.appendingPathComponent("log").path
        let target = dir.appendingPathComponent("target")
        let sentinel = Data("competitor-content".utf8)
        try sentinel.write(to: target)
        var keeper: Int32 = -1
        defer { if keeper >= 0 { close(keeper) } }
        var failure: Error?
        var claimedStat = stat()
        do {
            let handle = try hostDetachedOutputHandle(path: leaf) {
                switch kind {
                case "regular": try sentinel.write(to: URL(fileURLWithPath: leaf))
                case "hardlink": try #require(link(target.path, leaf) == 0)
                case "symlink": try #require(symlink(target.path, leaf) == 0)
                default:
                    try #require(mkfifo(leaf, 0o600) == 0)
                    // Keep both ends open so even the old blocking writer cannot hang the fixture.
                    keeper = open(leaf, O_RDWR | O_NONBLOCK)
                    try #require(keeper >= 0)
                }
                try #require(lstat(leaf, &claimedStat) == 0)
            }
            defer { try? handle.close() }
            try handle.write(contentsOf: Data("unexpected-write".utf8))
        } catch { failure = error }
        #expect(failure is HostArtifactOutputError)
        #expect(try Data(contentsOf: target) == sentinel)
        var after = stat()
        #expect(lstat(leaf, &after) == 0)
        #expect(after.st_ino == claimedStat.st_ino)
        #expect(after.st_mode == claimedStat.st_mode)
        if kind == "regular" || kind == "hardlink" {
            #expect(try Data(contentsOf: URL(fileURLWithPath: leaf)) == sentinel)
        } else if kind == "fifo", keeper >= 0 {
            var byte: UInt8 = 0
            #expect(read(keeper, &byte, 1) == -1)
            #expect(errno == EAGAIN)
        }
    }

    @Test("fresh output is private and close-on-exec, existing output stays intact")
    func freshOutput() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("nested/log").path
        let handle = try hostDetachedOutputHandle(path: path)
        defer { try? handle.close() }
        var info = stat()
        #expect(fstat(handle.fileDescriptor, &info) == 0)
        #expect(info.st_mode & 0o777 == 0o600)
        let flags = fcntl(handle.fileDescriptor, F_GETFD)
        try #require(flags >= 0)
        #expect(flags & FD_CLOEXEC != 0)
        try handle.write(contentsOf: Data("keep".utf8))
        #expect(throws: HostArtifactOutputError.self) { try hostDetachedOutputHandle(path: path) }
        #expect(try String(contentsOfFile: path) == "keep")
    }

    @Test("stderr open and launch failures explicitly close every acquired output", arguments: [true, false])
    func failedSetup(_ failStderr: Bool) throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var handles: [FileHandle] = [] // Retain to distinguish explicit close from deallocation.
        var descriptors: [Int32] = []
        let marker = dir.appendingPathComponent("launched")
        let command = TKHostCommand(executable: failStderr ? "/bin/sh" : dir.appendingPathComponent("missing").path,
                                    arguments: ["-c", "touch \(shellEscaped(marker.path))"], defaultTimeoutSeconds: 1)
        var failure: Error?
        do {
            _ = try runHostCommandDetached(command, stdoutLogPath: "stdout", stderrLogPath: "stderr") { path in
                if failStderr && path == "stderr" {
                    throw HostArtifactOutputError.rejected(path: "stderr", reason: "fixture")
                }
                let handle = try hostDetachedOutputHandle(path: dir.appendingPathComponent(try #require(path)).path)
                handles.append(handle)
                descriptors.append(handle.fileDescriptor)
                return handle
            }
        } catch { failure = error }
        if failStderr {
            #expect(failure is HostArtifactOutputError)
        } else {
            let launchFailure = try #require(failure as? HostCommandRunError)
            if case .launchFailed = launchFailure {} else { Issue.record("Expected launchFailed") }
        }
        for fd in descriptors {
            #expect(fcntl(fd, F_GETFD) == -1)
            #expect(errno == EBADF)
        }
        #expect(handles.count == (failStderr ? 1 : 2))
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        for handle in handles { try? handle.close() }
    }

    @Test("detached short fixture writes both logs and nil outputs remain usable")
    func successfulLaunch() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("stdout").path
        let err = dir.appendingPathComponent("stderr").path
        let done = dir.appendingPathComponent("done").path
        let script = "printf output; printf error >&2; touch \(shellEscaped(done))"
        var handles: [FileHandle] = []
        var descriptors: [Int32] = []
        let opener: (String?) throws -> FileHandle = { path in
            let handle = try hostDetachedOutputHandle(path: path)
            handles.append(handle)
            descriptors.append(handle.fileDescriptor)
            return handle
        }
        let result = try runHostCommandDetached(TKHostCommand(executable: "/bin/sh", arguments: ["-c", script]), stdoutLogPath: out, stderrLogPath: err, outputHandle: opener)
        #expect(result.pid > 0)
        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: done), Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        #expect(FileManager.default.fileExists(atPath: done))
        #expect(try String(contentsOfFile: out) == "output")
        #expect(try String(contentsOfFile: err) == "error")
        let null = try hostDetachedOutputHandle(path: nil)
        try null.write(contentsOf: Data("discard".utf8))
        try null.close()
        _ = try runHostCommandDetached(TKHostCommand(executable: "/usr/bin/true", arguments: []), outputHandle: opener)
        #expect(handles.count == 4)
        for fd in descriptors {
            #expect(fcntl(fd, F_GETFD) == -1)
            #expect(errno == EBADF)
        }
    }
}
