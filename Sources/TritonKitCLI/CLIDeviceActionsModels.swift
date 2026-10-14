import Foundation

/// Typed host/device action payload. Coordinates are always expressed in the
/// caller's latest observed geometry; no implicit display-size inference.
struct DeviceActionGeometry: Codable, Equatable {
    let width: Double
    let height: Double
    let orientation: String
    static let orientations: Set<String> = ["portrait", "landscape-left", "landscape-right", "portrait-upside-down"]
    init(width: Double, height: Double, orientation: String) throws {
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              width <= 32768, height <= 32768, Self.orientations.contains(orientation) else {
            throw DeviceActionError.invalidGeometry
        }
        self.width = width; self.height = height; self.orientation = orientation
    }
}

enum DeviceActionKind: String, Codable, CaseIterable {
    case tap, doubleTap, swipe, press, type
}

struct DeviceActionPayload: Codable, Equatable {
    let action: DeviceActionKind
    let device: String
    let platform: String
    let requestID: String
    let observationID: String?
    let geometry: DeviceActionGeometry?
    let x: Double?
    let y: Double?
    let endX: Double?
    let endY: Double?
    let duration: Double?
    let button: String?
    let bundleID: String?
    let identifier: String?
    let label: String?
    let textFile: String?
}

enum DeviceActionError: Error, Equatable {
    case invalidDevice
    case invalidPlatform
    case invalidRequestID
    case invalidGeometry
    case missingGeometry
    case coordinateOutOfBounds
    case invalidDuration
    case missingObservation
    case invalidSelector
    case invalidButton
    case invalidTextFile
}
