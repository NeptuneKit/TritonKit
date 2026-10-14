import Foundation
import Testing
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
    @Test func pressWhitelistAndTypeUsesFile() throws {
        #expect(throws: DeviceActionError.self) { _ = try makeDeviceActionPayload(action: .press, device: "emulator:x", platform: "android", requestID: "p", button: "unknown") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("triton-type-\(UUID().uuidString)")
        try Data("secret-free test".utf8).write(to: url); defer { try? FileManager.default.removeItem(at: url) }
        let value = try makeDeviceActionPayload(action: .type, device: "emulator:x", platform: "android", requestID: "t", textFile: url.path, identifier: nil, label: nil)
        #expect(value.textFile == url.path)
    }
}
