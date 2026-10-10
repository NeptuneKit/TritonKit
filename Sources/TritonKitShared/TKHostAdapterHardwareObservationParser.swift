import Foundation

enum TKDevicectlHardwareObservationParser {
    static func parse(_ hardware: [String: Any], modern: Bool) -> TKAppleHardwarePlatformObservation {
        func exactASCII(_ key: String) -> String? {
            guard let value = hardware[key] as? String, !value.isEmpty, value.utf8.count <= 64,
                  value.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 }) else { return nil }
            return value
        }
        let systems: [String: TKAppleObservedSystemFamily] = ["iOS": .ios, "iPadOS": .ipados, "watchOS": .watchos, "tvOS": .tvos, "xrOS": .visionos, "visionOS": .visionos, "macOS": .macos]
        let devices: [String: TKAppleObservedDeviceFamily] = ["iPhone": .iphone, "iPad": .ipad, "AppleWatch": .watch, "Watch": .watch, "AppleTV": .tv, "RealityDevice": .spatial, "Mac": .mac]
        let realities: [String: TKAppleObservedReality] = ["physical": .physical, "simulated": .simulated]
        return TKAppleHardwarePlatformObservation(
            systemFamily: exactASCII("platform").flatMap { systems[$0] } ?? .unknown,
            deviceFamily: exactASCII("deviceType").flatMap { devices[$0] } ?? .unknown,
            reality: exactASCII("reality").flatMap { realities[$0] } ?? .unknown,
            sourceLayout: modern ? "modern-properties-hardware" : "legacy-hardware-properties",
            authority: "explicit-sdk-hardware-only", legacyNamespaceIsOperatingSystemProof: false,
            actionCapabilitiesVerified: false, businessReadinessVerified: false
        )
    }
}
