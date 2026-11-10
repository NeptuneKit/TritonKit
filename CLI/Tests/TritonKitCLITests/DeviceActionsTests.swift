import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("typed device action contracts")
struct DeviceActionsTests {
    @Test func coordinateRequiresFreshFiniteGeometry() throws {
        let geometry = try DeviceActionGeometry(width: 390, height: 844, orientation: "portrait")
        let payload = try makeDeviceActionPayload(action: .doubleTap, device: "ios-real:test", platform: "ios", requestID: "tap-1", geometry: geometry, observationID: "obs-1", x: 10, y: 20)
        #expect(payload.action == .doubleTap)
        #expect(throws: DeviceActionError.self) { _ = try makeDeviceActionPayload(action: .tap, device: "ios-real:test", platform: "ios", requestID: "tap-2", geometry: geometry, observationID: "obs-2", x: 390, y: 20) }
        #expect(throws: DeviceActionError.self) { _ = try DeviceActionGeometry(width: .infinity, height: 1, orientation: "portrait") }
    }
    @Test func swipeDurationAndCoordinatesBounded() throws {
        let g = try DeviceActionGeometry(width: 100, height: 200, orientation: "landscape-left")
        #expect(throws: DeviceActionError.self) { _ = try makeDeviceActionPayload(action: .swipe, device: "sim:x", platform: "ios", requestID: "s", geometry: g, observationID: "o", x: 1, y: 2, endX: 3, endY: 4, duration: 0) }
        #expect(throws: DeviceActionError.self) { _ = try makeDeviceActionPayload(action: .swipe, device: "sim:x", platform: "ios", requestID: "s", geometry: g, observationID: "o", x: 1, y: 2, endX: 100, endY: 4, duration: 1) }
    }
    @Test("device action parser accepts optional lease binding")
    func actionParserAcceptsLease() throws {
        let command = try TritonKitCLI.parseAsRoot([
            "device", "tap",
            "--device", "sim:11111111-1111-1111-1111-111111111111",
            "--platform", "ios",
            "--x", "10", "--y", "20",
            "--width", "390", "--height", "844", "--orientation", "portrait",
            "--observation-id", "obs-1", "--lease", "lease-1"
        ])
        #expect(command is DeviceTap)
    }
    @Test("device action projection carries admission and delivery metadata")
    func deviceActionProjectionCarriesMetadata() throws {
        let target = HostDeviceTarget(platform: "android", id: "android:fixture", target: "fixture", state: "ready", ready: true, source: "fixture", name: nil, runtime: nil, transport: "adb", scope: "emulator")
        let geometry = try DeviceActionGeometry(width: 100, height: 200, orientation: "portrait")
        let payload = try makeDeviceActionPayload(action: .tap, device: "android:fixture", platform: "android", requestID: "device-action-1", geometry: geometry, observationID: "obs-1", x: 10, y: 20)
        let (context, digest) = try makeDeviceActionContext(payload, selected: target, leaseID: "lease-1")
        let admissions = TKActionAdmissionStore()
        let admission = try admissions.issue(actionID: context.actionID, contextDigest: digest, target: context.target, leaseID: context.leaseID, now: Date(), admissionID: "admission-device-1")
        _ = try admissions.consume(admissionID: admission.admissionID, contextDigest: digest, target: context.target, leaseID: context.leaseID, now: Date())
        let generations = TKActionGenerationStore()
        let generation = generations.begin(target: target.id, actionID: payload.requestID)
        let raw = try JSONSerialization.data(withJSONObject: ["ok": true, "action": "device.tap", "postconditionVerified": false])
        let output = try decorateDeviceActionResult(raw, context: context, contextDigest: digest, admissionID: admission.admissionID, generationStore: generations, generationToken: generation)
        let json = try #require(JSONSerialization.jsonObject(with: output) as? [String: Any])
        #expect(json["actionID"] as? String == payload.requestID)
        #expect(json["admissionID"] as? String == admission.admissionID)
        #expect(json["delivery"] as? String == "delivered")
        #expect(json["executed"] as? Bool == true)
        #expect(json["postcondition"] as? String == "unverified")
    }

    @Test("device action projection rejects a late generation")
    func deviceActionProjectionRejectsLateGeneration() throws {
        let target = HostDeviceTarget(platform: "android", id: "android:fixture", target: "fixture", state: "ready", ready: true, source: "fixture", name: nil, runtime: nil, transport: "adb", scope: "emulator")
        let geometry = try DeviceActionGeometry(width: 100, height: 200, orientation: "portrait")
        let payload = try makeDeviceActionPayload(action: .tap, device: "android:fixture", platform: "android", requestID: "device-action-old", geometry: geometry, observationID: "obs-1", x: 10, y: 20)
        let (context, digest) = try makeDeviceActionContext(payload, selected: target, leaseID: nil)
        let generations = TKActionGenerationStore()
        let old = generations.begin(target: target.id, actionID: payload.requestID)
        _ = generations.begin(target: target.id, actionID: "device-action-new")
        let raw = try JSONSerialization.data(withJSONObject: ["ok": true])
        do {
            _ = try decorateDeviceActionResult(raw, context: context, contextDigest: digest, admissionID: "admission-old", generationStore: generations, generationToken: old)
            Issue.record("Late generation unexpectedly projected a result")
        } catch let error as DeviceActionError {
            #expect(error == .generationStale)
        }
    }
    @Test("device action execution fixture emits admission metadata without host IO")
    func executionFixtureEmitsAdmissionMetadata() async throws {
        let command = try TritonKitCLI.parseAsRoot([
            "device", "tap",
            "--device", "android:fixture",
            "--platform", "android",
            "--x", "10", "--y", "20",
            "--width", "100", "--height", "200", "--orientation", "portrait",
            "--observation-id", "obs-1"
        ])
        let tap = try #require(command as? DeviceTap)
        let payload = try tap.payload()
        let fixture = HostDeviceTarget(platform: "android", id: "android:fixture", target: "fixture", state: "ready", ready: true, source: "fixture", name: nil, runtime: nil, transport: "adb", scope: "emulator")
        let process = HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: "adb fixture input tap 10 20", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
        let output = try await executeDeviceAction(payload, common: tap.common, targetResolver: { _ in fixture }, hostRunner: { _ in process })
        let json = try #require(JSONSerialization.jsonObject(with: output) as? [String: Any])
        #expect(json["actionID"] as? String == payload.requestID)
        #expect(json["delivery"] as? String == "delivered")
        #expect(json["executed"] as? Bool == true)
    }

    @Test("device action lease rejection happens before host runner")
    func executionFixtureLeaseRejectsBeforeHostRunner() async throws {
        let command = try TritonKitCLI.parseAsRoot([
            "device", "tap",
            "--device", "android:fixture",
            "--platform", "android",
            "--x", "10", "--y", "20",
            "--width", "100", "--height", "200", "--orientation", "portrait",
            "--observation-id", "obs-1", "--lease", "lease-1"
        ])
        let tap = try #require(command as? DeviceTap)
        let payload = try tap.payload()
        let fixture = HostDeviceTarget(platform: "android", id: "android:fixture", target: "fixture", state: "ready", ready: true, source: "fixture", name: nil, runtime: nil, transport: "adb", scope: "emulator")
        var hostCalls = 0
        do {
            _ = try await executeDeviceAction(payload, common: tap.common, targetResolver: { _ in fixture }, hostRunner: { _ in
                hostCalls += 1
                return HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
            }, leaseGate: { throw HostApplePlatformControlError(code: "target_lease_conflict", message: "held", hint: "release lease") })
            Issue.record("Lease rejection unexpectedly executed")
        } catch let error as HostApplePlatformControlError {
            #expect(error.code == "target_lease_conflict")
        }
        #expect(hostCalls == 0)
    }
    @Test func pressWhitelistAndTypeUsesFile() throws {
        #expect(throws: DeviceActionError.self) { _ = try makeDeviceActionPayload(action: .press, device: "emulator:x", platform: "android", requestID: "p", button: "unknown") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("triton-type-\(UUID().uuidString)")
        try Data("secret-free test".utf8).write(to: url); defer { try? FileManager.default.removeItem(at: url) }
        let value = try makeDeviceActionPayload(action: .type, device: "emulator:x", platform: "android", requestID: "t", textFile: url.path, identifier: nil, label: nil)
        #expect(value.textFile == url.path)
    }
}
