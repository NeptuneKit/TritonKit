import ArgumentParser
import Foundation

struct DeviceMirror: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "mirror", abstract: "Mirror PNG device frames in Kitty/Ghostty/iTerm2; clicks and keyboard actions reuse device CLI commands")
    @Option(help: "Platform: ios|android|harmony") var platform: HostDevicePlatform
    @Option(help: "Explicit device selector; no automatic target switching") var device: String
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "iOS Runner allowlisted bundle; required for iOS real devices") var bundleID: String?
    @Option(help: "Existing private iOS Runner session root") var sessionRoot: String?
    @Option(help: "Latest Runner inspect observation id for iOS real-device coordinate taps") var observationID: String?
    @Option(help: "Latest Runner inspect orientation for iOS real-device coordinate taps") var orientation: String?
    @Option(help: "ADB executable") var adb: String = "adb"
    @Option(help: "HDC executable") var hdc: String = "hdc"
    @Option(name: .customLong("protocol"), help: "Terminal PNG protocol: auto|kitty|iterm2") var imageProtocol: DeviceMirrorProtocol = .auto
    @Option(help: "Maximum refresh rate, 0.1...5 frames/second") var fps: Double = 1
    @Option(help: "Total session budget, 1...3600 seconds") var timeout: Double = 300
    @Option(help: "Capture a bounded frame count without a terminal, 1...100; requires --output") var frames: Int?
    @Option(help: "New output directory for --frames; never overwrite existing images") var output: String?
    @Option(help: "Maximum rendered PNG dimension, 64...4096 pixels") var maxSize: Int = 1600
    @Option(help: "Maximum source PNG bytes, 1024...33554432") var maxBytes: Int = 16_777_216
    @Flag(help: "Mirror screenshots without accepting mouse or keyboard device actions") var readOnly = false
    @Flag(help: "Print the final single JSON receipt") var json = false
    mutating func validate() throws {
        guard !device.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ValidationError("--device must be explicit") }
        guard fps.isFinite, (0.1...5).contains(fps), timeout.isFinite, (1...3600).contains(timeout) else { throw ValidationError("--fps must be 0.1...5 and --timeout 1...3600") }
        guard (64...4096).contains(maxSize), (1024...33_554_432).contains(maxBytes) else { throw ValidationError("Invalid --max-size or --max-bytes budget") }
        guard (frames == nil && output == nil) || (frames.map { (1...100).contains($0) } == true && output?.isEmpty == false) else { throw ValidationError("Use --frames 1...100 together with --output <new-directory>") }
        if platform == .ios && (scope == .real || device.hasPrefix("ios-real:")) {
            guard bundleID?.isEmpty == false, observationID?.isEmpty == false, orientation?.isEmpty == false else { throw ValidationError("iOS real-device mirror requires --bundle-id, --observation-id, --orientation, and an existing Runner session") }
        }
    }
    func run() async throws {
        do {
            let receipt = try runDeviceMirror(self)
            if json || frames != nil { print(try encodeJSON(receipt)) }
        } catch let exit as ExitCode { throw exit }
        catch { try failHostValidation(code: "device_mirror_failed", message: "Device mirror failed: \(deviceMirrorSafeText(error.localizedDescription))", hint: "Inspect device readiness and existing Runner session; unsupported terminals can use --frames 1 --output <new-directory> to save real PNG images.", outputFormat: .json) }
    }
}
