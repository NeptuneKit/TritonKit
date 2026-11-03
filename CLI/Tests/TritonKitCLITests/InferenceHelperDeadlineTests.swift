import Darwin
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Inference helper bounded lifecycle", .serialized)
struct InferenceHelperDeadlineTests {
    @Test("helper logs larger than a pipe buffer do not deadlock")
    func drainsLogsWhileRunning() throws {
        let fixture = try InferenceHelperFixture("print STDERR 'x' x 262144; print '{\"x\":500,\"y\":500}';")
        defer { fixture.remove() }
        let result = try runMLXSwiftLMHelper(path: fixture.helper.path, requestURL: fixture.request, timeoutSeconds: 0.5)
        #expect(result == #"{"x":500,"y":500}"#)
    }

    @Test("timeout terminates an uncooperative direct helper")
    func ignoresTerminate() throws {
        let fixture = try InferenceHelperFixture("$SIG{TERM}='IGNORE'; open(my $f,'>', $ARGV[2]) or die $!; print $f $$; close($f); sleep 5;")
        defer { fixture.remove() }
        let start = Date()
        #expect(throws: TKVLMGroundingFailure.self) {
            _ = try runMLXSwiftLMHelper(path: fixture.helper.path, requestURL: fixture.request, timeoutSeconds: 0.6)
        }
        #expect(Date().timeIntervalSince(start) < 4.8)
        let pid = try fixture.pid()
        #expect(kill(pid, 0) != 0, "Direct helper must no longer be alive when timeout returns")
    }

    @Test("a descendant retaining output cannot hold the caller beyond the drain budget")
    func inheritedPipe() throws {
        let fixture = try InferenceHelperFixture("my $pid=fork(); die $! unless defined $pid; if ($pid == 0) { sleep 2; exit 0; } open(my $f,'>', $ARGV[2]) or die $!; print $f $pid; close($f); print '{\"x\":500,\"y\":500}'; exit 0;")
        defer { fixture.remove() }
        let start = Date()
        #expect(throws: TKVLMGroundingFailure.self) {
            _ = try runMLXSwiftLMHelper(path: fixture.helper.path, requestURL: fixture.request, timeoutSeconds: 0.5)
        }
        #expect(Date().timeIntervalSince(start) < 1)
    }

    @Test("explicit download also bounds inherited pipe EOF without replay")
    func downloadInheritedPipe() throws {
        let fixture = try InferenceHelperFixture("my $pid=fork(); die $! unless defined $pid; if ($pid == 0) { sleep 2; exit 0; } open(my $f,'>', 'FIXTURE_PID') or die $!; print $f $pid; close($f); print '{}'; exit 0;")
        defer { fixture.remove() }
        let start = Date()
        do {
            _ = try downloadVLMModel("fixture/model", provider: "mlx-swift-lm", cacheDir: fixture.directory.appendingPathComponent("cache").path, helperPath: fixture.helper.path)
            Issue.record("Expected incomplete helper output failure")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "mlx_model_download_failed")
        }
        #expect(Date().timeIntervalSince(start) < 1)
    }

    @Test("oversized helper stdout is rejected rather than parsed as a complete result")
    func oversizedOutput() throws {
        let fixture = try InferenceHelperFixture("print 'x' x 1100000;")
        defer { fixture.remove() }
        #expect(throws: TKVLMGroundingFailure.self) {
            _ = try runMLXSwiftLMHelper(path: fixture.helper.path, requestURL: fixture.request, timeoutSeconds: 0.5)
        }
    }

    @Test("helper resource error stays a provider failure without a fallback")
    func resourceFailure() throws {
        let fixture = try InferenceHelperFixture("print STDERR 'fixture out of memory'; exit 42;")
        defer { fixture.remove() }
        do {
            _ = try runMLXSwiftLMHelper(path: fixture.helper.path, requestURL: fixture.request, timeoutSeconds: 1)
            Issue.record("Expected helper failure")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "mlx_generation_failed")
            #expect(failure.message.contains("42"))
            #expect(failure.message.contains("fixture out of memory"))
        }
    }
}

private struct InferenceHelperFixture {
    let directory: URL
    let helper: URL
    let request: URL
    init(_ script: String) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-inference-deadline-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        helper = directory.appendingPathComponent("helper")
        request = directory.appendingPathComponent("request.json")
        try ("#!/usr/bin/perl\n" + script.replacingOccurrences(of: "FIXTURE_PID", with: request.path) + "\n").write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
    }
    func pid() throws -> pid_t {
        let text = try String(contentsOf: request, encoding: .utf8)
        return try #require(pid_t(text))
    }
    func remove() {
        // This fixture writes only its own direct/descendant pid; never scans or kills user processes.
        if let owned = try? pid(), owned > 1 { _ = kill(owned, SIGKILL) }
        try? FileManager.default.removeItem(at: directory)
    }
}
