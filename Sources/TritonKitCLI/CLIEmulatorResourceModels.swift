import Foundation
import TritonKitShared

enum EmulatorResourcePlatform: String, Codable, CaseIterable { case android, harmony }
enum EmulatorResourceKind: String, Codable { case package, bluetooth, service }

struct EmulatorResourceItem: Codable, Equatable {
    let id: String
    let feature: String
    let kind: EmulatorResourceKind
    let disabledValue: String
}

struct EmulatorResourceFeature: Codable, Equatable {
    let id: String
    let title: String
    let impact: String
    let defaultProfile: Bool
    let items: [EmulatorResourceItem]
}

struct EmulatorResourceIdentity: Codable, Equatable {
    let platform: EmulatorResourcePlatform
    let target: String
    let instance: String
    let image: String
    let bootID: String
}

struct EmulatorResourceState: Codable, Equatable {
    let item: EmulatorResourceItem
    let value: String?
    let available: Bool
    let reason: String?
    init(item: EmulatorResourceItem, value: String?, available: Bool = true, reason: String? = nil) {
        self.item = item; self.value = value; self.available = available; self.reason = reason
    }
}

struct EmulatorResourceProcessMemory: Codable, Equatable {
    let pid: Int32
    let name: String
    let pssBytes: UInt64
}

struct EmulatorResourceGuestMemory: Codable, Equatable {
    let metric: String
    let processes: [EmulatorResourceProcessMemory]
    let partial: Bool
    let reason: String?
}

struct EmulatorResourceError: Error, CustomStringConvertible {
    let code: String
    let message: String
    init(_ code: String, _ message: String) { self.code = code; self.message = message }
    var description: String { message }
}

typealias EmulatorResourceRunner = (TKHostCommand) throws -> HostProcessResult

protocol EmulatorResourceAdapter {
    func identity() throws -> EmulatorResourceIdentity
    func read(_ item: EmulatorResourceItem) throws -> EmulatorResourceState
    func write(_ item: EmulatorResourceItem, value: String) throws
    func measure() throws -> EmulatorResourceGuestMemory
}

enum EmulatorResourceCatalog {
    static let version = 1
    static func features(_ platform: EmulatorResourcePlatform) -> [EmulatorResourceFeature] {
        if platform == .android {
            func package(_ id: String, _ title: String, _ package: String, _ impact: String, _ preset: Bool = false) -> EmulatorResourceFeature {
                .init(id: id, title: title, impact: impact, defaultProfile: preset,
                      items: [.init(id: package, feature: id, kind: .package, disabledValue: "3")])
            }
            return [
                package("assistant", "Search and voice assistant", "com.google.android.googlequicksearchbox", "Disables Google search and voice assistant providers", true),
                package("youtube", "YouTube", "com.google.android.youtube", "Changes YouTube external-link routing", true),
                package("music", "YouTube Music", "com.google.android.apps.youtube.music", "Disables YouTube Music integration", true),
                package("wellbeing", "Digital Wellbeing", "com.google.android.apps.wellbeing", "Disables focus mode and usage-time features", true),
                .init(id: "bluetooth", title: "Bluetooth", impact: "Disables Bluetooth and BLE; do not use during Bluetooth tests", defaultProfile: true,
                      items: [.init(id: "bluetooth", feature: "bluetooth", kind: .bluetooth, disabledValue: "off")]),
                package("messaging", "Messages and RCS", "com.google.android.apps.messaging", "Changes SMS/RCS and default-message routing"),
                package("tts", "Text to speech", "com.google.android.tts", "Disables speech synthesis and accessibility speech"),
                package("intelligence", "System intelligence", "com.google.android.as", "Disables content and text prediction"),
                package("adservices", "Advertising privacy services", "com.google.android.adservices.api", "Affects advertising/privacy SDK tests")
            ]
        }
        func service(_ id: String, _ title: String, _ names: [String], _ impact: String) -> EmulatorResourceFeature {
            .init(id: id, title: title, impact: impact, defaultProfile: false,
                  items: names.map { .init(id: $0, feature: id, kind: .service, disabledValue: "stopped") })
        }
        return [
            service("camera", "Camera", ["camera_service"], "Disables camera/scanning/video calls; requires service-control permission"),
            service("audio", "Audio", ["audio_server", "audio_host"], "Disables audio/recording/calls; audio_server stop also stops audio_host"),
            service("analytics", "Analytics", ["hianalytics"], "Disables system analytics; requires service-control permission")
        ]
    }
    static func items(_ platform: EmulatorResourcePlatform) -> [EmulatorResourceItem] { features(platform).flatMap(\.items) }
    static func validate(_ item: EmulatorResourceItem, platform: EmulatorResourcePlatform, value: String) throws {
        guard items(platform).contains(item) else { throw EmulatorResourceError("resource_invalid_item", "Item is outside the managed allowlist") }
        let allowed: Set<String>
        switch item.kind { case .package: allowed = ["0", "1", "2", "3", "4"]; case .bluetooth: allowed = ["on", "off"]; case .service: allowed = ["running", "stopped"] }
        guard allowed.contains(value) else { throw EmulatorResourceError("resource_invalid_state", "Invalid managed state") }
    }
}
