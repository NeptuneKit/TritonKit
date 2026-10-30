import Foundation
import XCTest
@testable import TritonKitCLI

final class EmulatorResourceRuntimeTests: XCTestCase {
    final class Fake: EmulatorResourceAdapter {
        var current = EmulatorResourceIdentity(platform: .android, target: "emulator-5556", instance: "test", image: "image", bootID: "boot")
        var states = Dictionary(uniqueKeysWithValues: EmulatorResourceCatalog.items(.android).map { ($0.id, $0.kind == .package ? "0" : "on") })
        var writes: [(String, String)] = []
        var failAfterWrite = false
        func identity() throws -> EmulatorResourceIdentity { current }
        func read(_ item: EmulatorResourceItem) throws -> EmulatorResourceState { .init(item: item, value: states[item.id]) }
        func write(_ item: EmulatorResourceItem, value: String) throws {
            writes.append((item.id, value)); states[item.id] = value
            if failAfterWrite { throw EmulatorResourceError("resource_command_failed", "uncertain") }
        }
        func measure() throws -> EmulatorResourceGuestMemory { .init(metric: "guest_pss", processes: [], partial: false, reason: nil) }
    }
    func location() throws -> URL {
        // Foundation on macOS 27 preserves the /var alias even after resolvingSymlinksInPath.
        // The production store deliberately rejects symlink path components.
        let url = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url.appendingPathComponent("receipt.json")
    }
    func testPlanHasNoWritesAndKeepExcludesBluetooth() throws {
        let adapter = Fake(), engine = EmulatorResourceEngine()
        let plan = try engine.plan(adapter: adapter, platform: .android, profile: "ui-minimal", disable: nil, keep: "bluetooth")
        XCTAssertEqual(plan.states?.count, 4); XCTAssertTrue(adapter.writes.isEmpty)
    }
    func testApplyRequiresConfirmationAndReceiptBeforeMutation() throws {
        let adapter = Fake(), engine = EmulatorResourceEngine()
        let path = try location().path
        XCTAssertThrowsError(try engine.apply(adapter: adapter, platform: .android, profile: "ui-minimal", disable: "youtube", keep: nil, receiptPath: path, confirm: false))
        XCTAssertTrue(adapter.writes.isEmpty)
        let out = try engine.apply(adapter: adapter, platform: .android, profile: "custom", disable: "youtube", keep: nil, receiptPath: path, confirm: true)
        XCTAssertTrue(out.ok); XCTAssertEqual(adapter.writes.count, 1)
        let receipt = try EmulatorResourceStore.read(path)
        XCTAssertEqual(receipt.entries[0].previous, "0")
        XCTAssertThrowsError(try engine.apply(adapter: adapter, platform: .android, profile: "custom", disable: "music", keep: nil, receiptPath: path, confirm: true))
        XCTAssertEqual(adapter.writes.count, 1)
    }
    func testRestoreDefaultAndPreserveExternalConflict() throws {
        let adapter = Fake(), engine = EmulatorResourceEngine(), path = try location().path
        _ = try engine.apply(adapter: adapter, platform: .android, profile: "custom", disable: "youtube,music", keep: nil, receiptPath: path, confirm: true)
        adapter.states["com.google.android.youtube"] = "1"
        let out = try engine.restore(adapter: adapter, platform: .android, receiptPath: path, confirm: true)
        XCTAssertFalse(out.ok); XCTAssertTrue(out.partial)
        XCTAssertEqual(adapter.states["com.google.android.youtube"], "1")
        XCTAssertEqual(adapter.states["com.google.android.apps.youtube.music"], "0")
    }
    func testUncertainWriteRetainsRecoveryIntent() throws {
        let adapter = Fake(), engine = EmulatorResourceEngine(), path = try location().path
        adapter.failAfterWrite = true
        let out = try engine.apply(adapter: adapter, platform: .android, profile: "custom", disable: "youtube", keep: nil, receiptPath: path, confirm: true)
        XCTAssertFalse(out.ok); XCTAssertTrue(out.partial)
        XCTAssertEqual(try EmulatorResourceStore.read(path).entries[0].phase, "intent")
        adapter.failAfterWrite = false
        XCTAssertTrue(try engine.restore(adapter: adapter, platform: .android, receiptPath: path, confirm: true).ok)
        XCTAssertEqual(adapter.states["com.google.android.youtube"], "0")
    }
    func testVerifyCannotHideAnUnfinishedMultiItemApply() throws {
        let adapter = Fake(), engine = EmulatorResourceEngine(), path = try location().path
        adapter.failAfterWrite = true
        _ = try engine.apply(adapter: adapter, platform: .android, profile: "custom", disable: "youtube,music", keep: nil, receiptPath: path, confirm: true)
        let result = try engine.verify(adapter: adapter, platform: .android, receiptPath: path)
        XCTAssertFalse(result.ok); XCTAssertTrue(result.partial)
    }
    func testIdentityMismatchAndForgedReceiptNeverWrite() throws {
        let adapter = Fake(), engine = EmulatorResourceEngine(), path = try location().path
        _ = try engine.apply(adapter: adapter, platform: .android, profile: "custom", disable: "youtube", keep: nil, receiptPath: path, confirm: true)
        adapter.writes = []
        adapter.current = .init(platform: .android, target: "emulator-5556", instance: "other", image: "image", bootID: "boot")
        XCTAssertThrowsError(try engine.restore(adapter: adapter, platform: .android, receiptPath: path, confirm: true))
        XCTAssertTrue(adapter.writes.isEmpty)
        try Data("{}".utf8).write(to: URL(fileURLWithPath: path))
        XCTAssertThrowsError(try engine.restore(adapter: adapter, platform: .android, receiptPath: path, confirm: true))
        XCTAssertTrue(adapter.writes.isEmpty)
    }
    func testUnknownFeatureAndEmptyCustomRejected() throws {
        let engine = EmulatorResourceEngine(), adapter = Fake()
        for value in ["systemui", "youtube,,music", ""] {
            XCTAssertThrowsError(try engine.plan(adapter: adapter, platform: .android, profile: "custom", disable: value, keep: nil))
        }
    }
    func testSymlinkReceiptAndExistingReceiptAreRejectedBeforeWrite() throws {
        let adapter = Fake(), engine = EmulatorResourceEngine(), path = try location()
        let other = path.deletingLastPathComponent().appendingPathComponent("other.json")
        try Data("unchanged".utf8).write(to: other)
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: other)
        XCTAssertThrowsError(try engine.apply(adapter: adapter, platform: .android, profile: "custom", disable: "youtube", keep: nil, receiptPath: path.path, confirm: true))
        XCTAssertTrue(adapter.writes.isEmpty)
        XCTAssertEqual(try String(contentsOf: other), "unchanged")
    }
    func testIndependentReceiptCannotBypassTargetLock() throws {
        let adapter = Fake(), engine = EmulatorResourceEngine(), path = try location().path
        let lock = try EmulatorResourceLock(identity: adapter.current)
        defer { withExtendedLifetime(lock) {} }
        XCTAssertThrowsError(try engine.apply(adapter: adapter, platform: .android, profile: "custom", disable: "youtube", keep: nil, receiptPath: path, confirm: true))
        XCTAssertTrue(adapter.writes.isEmpty)
    }
    func testAudioReceiptCannotReorderDependencies() throws {
        let items = EmulatorResourceCatalog.items(.harmony).filter { $0.feature == "audio" }
        let receipt = EmulatorResourceReceipt(version: 1, id: UUID().uuidString, identity: .init(platform: .harmony, target: "127.0.0.1:10101", instance: "test", image: "image", bootID: "boot"), createdAt: Date(), entries: items.reversed().map { .init(item: $0, previous: "running", applied: "stopped", phase: "applied") })
        XCTAssertThrowsError(try EmulatorResourceStore.validate(receipt))
    }
}
