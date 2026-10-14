import Foundation

func validateDeviceActionRequestID(_ value: String) throws {
    guard !value.isEmpty, value.utf8.count <= 128,
          value.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else { throw DeviceActionError.invalidRequestID }
}

func validateDeviceActionCoordinate(_ value: Double?, limit: Double) throws -> Double {
    guard let value, value.isFinite, value >= 0, value < limit else { throw DeviceActionError.coordinateOutOfBounds }
    return value
}

func makeDeviceActionPayload(action: DeviceActionKind, device: String, platform: String, requestID: String,
                             geometry: DeviceActionGeometry? = nil, observationID: String? = nil,
                             x: Double? = nil, y: Double? = nil, endX: Double? = nil, endY: Double? = nil,
                             duration: Double? = nil, button: String? = nil, bundleID: String? = nil,
                             textFile: String? = nil, identifier: String? = nil, label: String? = nil) throws -> DeviceActionPayload {
    guard !device.isEmpty else { throw DeviceActionError.invalidDevice }
    guard ["ios", "android", "harmony"].contains(platform) else { throw DeviceActionError.invalidPlatform }
    try validateDeviceActionRequestID(requestID)
    if [.tap, .doubleTap, .swipe].contains(action) {
        guard let geometry, let observationID, !observationID.isEmpty else { throw DeviceActionError.missingObservation }
        _ = try validateDeviceActionCoordinate(x, limit: geometry.width)
        _ = try validateDeviceActionCoordinate(y, limit: geometry.height)
        if action == .swipe {
            _ = try validateDeviceActionCoordinate(endX, limit: geometry.width)
            _ = try validateDeviceActionCoordinate(endY, limit: geometry.height)
            guard let duration, duration.isFinite, (0.05...5).contains(duration) else { throw DeviceActionError.invalidDuration }
        }
    }
    if action == .press {
        guard let button, ["home", "back", "power", "volume-up", "volume-down", "app-switch"].contains(button) else { throw DeviceActionError.invalidButton }
    }
    if action == .type {
        guard let path = textFile, !path.isEmpty else { throw DeviceActionError.invalidTextFile }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard data.count > 0, data.count <= 4096, String(data: data, encoding: .utf8) != nil else { throw DeviceActionError.invalidTextFile }
    }
    if action == .type, platform == "ios", (identifier == nil) == (label == nil) { throw DeviceActionError.invalidSelector }
    return DeviceActionPayload(action: action, device: device, platform: platform, requestID: requestID, observationID: observationID,
                               geometry: geometry, x: x, y: y, endX: endX, endY: endY, duration: duration,
                               button: button, bundleID: bundleID, identifier: identifier, label: label, textFile: textFile)
}
