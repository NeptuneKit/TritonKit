import Foundation

public enum TKAppleObservedSystemFamily: String, Codable, CaseIterable { case ios, ipados, watchos, tvos, visionos, macos, unknown }
public enum TKAppleObservedDeviceFamily: String, Codable { case iphone, ipad, watch, tv, spatial, mac, unknown }
public enum TKAppleObservedReality: String, Codable { case physical, simulated, unknown }

/// Structured hardware observations only, never dispatch, runtime marketing inference or controls.
public struct TKAppleHardwarePlatformObservation: Codable, Equatable {
    public let systemFamily: TKAppleObservedSystemFamily
    public let deviceFamily: TKAppleObservedDeviceFamily
    public let reality: TKAppleObservedReality
    public let sourceLayout: String
    public let authority: String
    public let legacyNamespaceIsOperatingSystemProof: Bool
    public let actionCapabilitiesVerified: Bool
    public let businessReadinessVerified: Bool
}
