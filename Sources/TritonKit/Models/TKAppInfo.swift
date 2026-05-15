import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct TKAppInfo: Codable {
    public let appInfoIdentifier: UInt
    public let shouldUseCache: Bool
    public let serverVersion: Int
    public let serverReadableVersion: String
    public let swiftEnabledInLookinServer: Int
    public let screenshot: Data?
    public let appIcon: Data?
    public let appName: String
    public let appBundleIdentifier: String
    public let deviceDescription: String
    public let osDescription: String
    public let osMainVersion: UInt
    public let deviceType: TKDeviceType
    public let screenWidth: Double
    public let screenHeight: Double
    public let screenScale: Double

    public init(
        appInfoIdentifier: UInt = UInt(Date().timeIntervalSince1970),
        serverVersion: Int = 7,
        screenshot: Data? = nil,
        appIcon: Data? = nil
    ) {
        self.appInfoIdentifier = appInfoIdentifier
        self.shouldUseCache = false
        self.serverVersion = serverVersion
        self.serverReadableVersion = "1.0.0"
        self.swiftEnabledInLookinServer = 1
        self.screenshot = screenshot
        self.appIcon = appIcon
        self.appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? ""
        self.appBundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let device = UIDevice.current
        self.deviceDescription = device.model
        self.osDescription = device.systemVersion
        self.osMainVersion = UInt(device.systemVersion.split(separator: ".").first ?? "0") ?? 0
        self.deviceType = {
            #if targetEnvironment(simulator)
            return .simulator
            #else
            return device.userInterfaceIdiom == .pad ? .iPad : .others
            #endif
        }()
        let screen = UIScreen.main
        self.screenWidth = screen.bounds.width
        self.screenHeight = screen.bounds.height
        self.screenScale = screen.scale
    }
}
