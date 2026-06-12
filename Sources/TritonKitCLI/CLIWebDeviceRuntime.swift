import Foundation
import Hummingbird
import NIOCore
import TritonKitShared

struct WebDeviceTargetSummary: Codable, Equatable {
    let id: String
    let source: String
    let platform: String
    let scope: String?
    let kind: String?
    let transport: String?
    let connected: Bool
    let ready: Bool
    let latestHierarchyAvailable: Bool
    let appName: String?
    let bundleIdentifier: String?
    let deviceDescription: String?
    let osDescription: String?
    let simulatorUDID: String?
    let activeHierarchyAvailable: Bool?
    let cachedHierarchyAvailable: Bool?
    let hierarchyCacheState: String?
    let identityState: String?
}

struct WebDeviceTargetsResponse: Codable, Equatable {
    let targets: [WebDeviceTargetSummary]
}

struct WebHostTargetID: Equatable {
    let platform: HostDevicePlatform
    let selector: String
}

struct WebHostDeviceScreenshot {
    let data: Data
    let contentType: String
    let width: Int?
    let height: Int?
}

struct WebIOSSimulatorScreenLayout: Codable, Equatable {
    let width: Int
    let height: Int
}

final class WebHostDeviceTargetCache: @unchecked Sendable {
    private let ttl: TimeInterval
    private let lock = NSLock()
    private var targets: [HostDeviceTarget] = []
    private var lastRefresh: Date = .distantPast
    private var refreshing = false

    init(ttl: TimeInterval = 10) {
        self.ttl = ttl
    }

    func cachedTargets() -> [HostDeviceTarget] {
        lock.withLock { targets }
    }

    func refreshIfNeeded(hdc: String = "hdc", adb: String = "adb") {
        let shouldRefresh = lock.withLock {
            guard !refreshing, Date().timeIntervalSince(lastRefresh) >= ttl else {
                return false
            }
            refreshing = true
            return true
        }
        guard shouldRefresh else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let discovered = discoverWebHostDeviceTargets(hdc: hdc, adb: adb)
            self?.lock.withLock {
                self?.targets = discovered
                self?.lastRefresh = Date()
                self?.refreshing = false
            }
        }
    }
}

func webHostDeviceTargetID(_ target: HostDeviceTarget) -> String {
    "host:\(target.platform):\(target.target)"
}

func parseWebHostTargetID(_ id: String) -> WebHostTargetID? {
    let parts = id.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count == 3,
          parts[0] == "host",
          let platform = HostDevicePlatform(rawValue: String(parts[1])) else {
        return nil
    }
    let selector = String(parts[2])
    guard !selector.isEmpty else { return nil }
    return WebHostTargetID(platform: platform, selector: selector)
}

func webHostDeviceScope(for platform: HostDevicePlatform) -> HostDeviceScope {
    switch platform {
    case .ios:
        return .simulator
    case .android, .harmony:
        return .emulator
    }
}

func discoverWebHostDeviceTargets(hdc: String = "hdc", adb: String = "adb") -> [HostDeviceTarget] {
    HostDevicePlatform.allWebDevicePlatforms.flatMap { platform in
        (try? hostDeviceTargets(platform: platform, scope: webHostDeviceScope(for: platform), hdc: hdc, adb: adb).targets) ?? []
    }
}

func webDeviceTargets(runtimeTargets: [TKTargetSummary], hostTargets: [HostDeviceTarget]) -> [WebDeviceTargetSummary] {
    var matchedRuntimeIDs = Set<String>()
    let hostSummaries = hostTargets
        .filter { $0.scope != HostDeviceScope.real.rawValue && $0.ready }
        .map { host -> WebDeviceTargetSummary in
            let runtime = matchingRuntimeTarget(for: host, runtimeTargets: runtimeTargets)
            if let runtime {
                matchedRuntimeIDs.insert(runtime.id)
            }
            return WebDeviceTargetSummary(
                id: webHostDeviceTargetID(host),
                source: "host",
                platform: host.platform,
                scope: host.scope,
                kind: host.kind,
                transport: host.transport ?? host.source,
                connected: host.ready || runtime?.connected == true,
                ready: host.ready,
                latestHierarchyAvailable: runtime?.latestHierarchyAvailable ?? false,
                appName: runtime?.appName ?? host.name,
                bundleIdentifier: runtime?.bundleIdentifier,
                deviceDescription: host.name ?? runtime?.deviceDescription,
                osDescription: host.runtime ?? runtime?.osDescription,
                simulatorUDID: host.platform == HostDevicePlatform.ios.rawValue ? host.target : runtime?.simulatorUDID,
                activeHierarchyAvailable: runtime?.activeHierarchyAvailable,
                cachedHierarchyAvailable: runtime?.cachedHierarchyAvailable,
                hierarchyCacheState: runtime?.hierarchyCacheState,
                identityState: runtime?.identityState
            )
        }

    let runtimeSummaries = runtimeTargets
        .filter { !matchedRuntimeIDs.contains($0.id) }
        .map { runtime in
            WebDeviceTargetSummary(
                id: runtime.id,
                source: "runtime",
                platform: runtime.platform,
                scope: runtime.platform == HostDevicePlatform.ios.rawValue ? HostDeviceScope.simulator.rawValue : nil,
                kind: "embedded-runtime",
                transport: runtime.transport,
                connected: runtime.connected,
                ready: runtime.connected,
                latestHierarchyAvailable: runtime.latestHierarchyAvailable,
                appName: runtime.appName,
                bundleIdentifier: runtime.bundleIdentifier,
                deviceDescription: runtime.deviceDescription,
                osDescription: runtime.osDescription,
                simulatorUDID: runtime.simulatorUDID,
                activeHierarchyAvailable: runtime.activeHierarchyAvailable,
                cachedHierarchyAvailable: runtime.cachedHierarchyAvailable,
                hierarchyCacheState: runtime.hierarchyCacheState,
                identityState: runtime.identityState
            )
        }

    return (hostSummaries + runtimeSummaries).sorted(by: webDeviceTargetSort)
}

func resolveWebHostDeviceTarget(_ id: String, hdc: String = "hdc", adb: String = "adb") throws -> (platform: HostDevicePlatform, target: HostDeviceTarget) {
    guard let parsed = parseWebHostTargetID(id) else {
        throw HostDeviceSelectionError.targetNotFound(id)
    }
    if parsed.platform == .ios {
        return (
            parsed.platform,
            HostDeviceTarget(
                platform: HostDevicePlatform.ios.rawValue,
                id: "triton:ios-simulator:\(parsed.selector)",
                target: parsed.selector,
                state: "Booted",
                ready: true,
                source: "simctl",
                name: nil,
                runtime: nil,
                transport: nil,
                scope: HostDeviceScope.simulator.rawValue,
                kind: "simulator"
            )
        )
    }
    let targets = try hostDeviceTargets(platform: parsed.platform, scope: webHostDeviceScope(for: parsed.platform), hdc: hdc, adb: adb).targets
    guard let selected = selectHostDeviceTarget(target: parsed.selector, candidates: targets) else {
        throw HostDeviceSelectionError.targetNotFound(parsed.selector)
    }
    return (parsed.platform, selected)
}

func captureWebHostDeviceScreenshot(id: String, hdc: String = "hdc", adb: String = "adb") throws -> Data {
    try captureWebHostDeviceScreenshotPayload(id: id, hdc: hdc, adb: adb).data
}

func captureWebHostDeviceScreenshotPayload(id: String, hdc: String = "hdc", adb: String = "adb") throws -> WebHostDeviceScreenshot {
    let resolved = try resolveWebHostDeviceTarget(id, hdc: hdc, adb: adb)
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-web-device-\(UUID().uuidString).\(webHostDeviceScreenshotFileExtension(for: resolved.platform))")
        .path
    _ = try captureHostDeviceScreenshot(
        platform: resolved.platform,
        target: resolved.target,
        hdc: hdc,
        adb: adb,
        output: output
    )
    defer { try? FileManager.default.removeItem(atPath: output) }
    let data = try Data(contentsOf: URL(fileURLWithPath: output))
    let dimensions = imagePixelSize(path: output)
    return WebHostDeviceScreenshot(
        data: data,
        contentType: webHostDeviceImageContentType(data),
        width: dimensions?.width,
        height: dimensions?.height
    )
}

func webHostDeviceGeometry(id: String, hdc: String = "hdc", adb: String = "adb") throws -> TKGeometryResponse {
    let resolved = try resolveWebHostDeviceTarget(id, hdc: hdc, adb: adb)
    switch resolved.platform {
    case .android:
        return try webAndroidDeviceGeometry(selected: resolved.target, adb: adb)
    case .harmony:
        if let geometry = try? webHarmonyDeviceGeometry(selected: resolved.target, hdc: hdc) {
            return geometry
        }
        if let geometry = webHarmonyGeometryFromInstalledProfiles() {
            return geometry
        }
        return try webHostGeometryResponse(width: 1308, height: 2880)
    case .ios:
        let size = webIOSSimulatorFallbackSize(for: resolved.target)
        return try webHostGeometryResponse(width: size.width, height: size.height)
    }
}

func runWebHostDeviceInput(id: String, input: TKInputRequest, hdc: String = "hdc", adb: String = "adb") throws -> TKInputResult {
    let resolved = try resolveWebHostDeviceTarget(id, hdc: hdc, adb: adb)
    switch resolved.platform {
    case .ios:
        return try runWebIOSSimulatorInput(selected: resolved.target, input: input)
    case .android:
        return try runWebAndroidInput(selected: resolved.target, input: input, adb: adb)
    case .harmony:
        return try runWebHarmonyInput(selected: resolved.target, input: input, hdc: hdc)
    }
}

func webRuntimeInputFallbackTargetID(forHostID id: String, runtimeTargets: [TKTargetSummary]) -> String? {
    guard let parsed = parseWebHostTargetID(id), parsed.platform == .ios else {
        return nil
    }
    return runtimeTargets.first { runtime in
        runtime.platform == HostDevicePlatform.ios.rawValue
            && (runtime.simulatorUDID == parsed.selector || runtime.id.hasSuffix(parsed.selector))
            && runtime.connected
    }?.id
}

func webHostGeometryResponse(width: Int, height: Int) throws -> TKGeometryResponse {
    guard width > 0, height > 0 else {
        throw RuntimeError("Host geometry dimensions must be positive.")
    }
    return TKGeometryResponse(
        bounds: TKRect(x: 0, y: 0, width: Double(width), height: Double(height)),
        safeArea: TKInsets(top: 0, left: 0, bottom: 0, right: 0),
        scale: 1,
        orientation: width >= height ? "landscape" : "portrait"
    )
}

private extension HostDevicePlatform {
    static let allWebDevicePlatforms: [HostDevicePlatform] = [.ios, .android, .harmony]
}

func webHostDeviceScreenshotFileExtension(for platform: HostDevicePlatform) -> String {
    switch platform {
    case .harmony:
        return "jpeg"
    case .ios, .android:
        return "png"
    }
}

func webHostDeviceImageContentType(_ data: Data) -> String {
    let bytes = Array(data.prefix(12))
    if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
        return "image/png"
    }
    if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
        return "image/jpeg"
    }
    return "application/octet-stream"
}

private func matchingRuntimeTarget(for host: HostDeviceTarget, runtimeTargets: [TKTargetSummary]) -> TKTargetSummary? {
    runtimeTargets.first { runtime in
        guard runtime.platform == host.platform else { return false }
        if host.platform == HostDevicePlatform.ios.rawValue {
            return runtime.simulatorUDID == host.target || runtime.id.hasSuffix(host.target)
        }
        return runtime.id == host.id || runtime.id.hasSuffix(host.target) || runtime.deviceDescription == host.name
    }
}

private func webDeviceTargetSort(_ lhs: WebDeviceTargetSummary, _ rhs: WebDeviceTargetSummary) -> Bool {
    let platformOrder = ["ios": 0, "android": 1, "harmony": 2]
    let leftPlatform = platformOrder[lhs.platform] ?? 99
    let rightPlatform = platformOrder[rhs.platform] ?? 99
    if leftPlatform != rightPlatform {
        return leftPlatform < rightPlatform
    }
    if lhs.ready != rhs.ready {
        return lhs.ready && !rhs.ready
    }
    if lhs.source != rhs.source {
        return lhs.source == "host"
    }
    return lhs.id < rhs.id
}

private func webAndroidDeviceGeometry(selected: HostDeviceTarget, adb: String) throws -> TKGeometryResponse {
    let result = try runHostCommand(TKAndroidADBCommand.wmSize(serial: selected.rawTarget, executable: adb))
    guard let size = TKAndroidWMSizeParser.parse(result.stdout) else {
        throw RuntimeError("Android wm size output did not include a display size.")
    }
    return try webHostGeometryResponse(width: size.width, height: size.height)
}

private func webHarmonyDeviceGeometry(selected: HostDeviceTarget, hdc: String) throws -> TKGeometryResponse {
    let dumpResult = try runHostCommand(TKHarmonyHDCCommand.dumpLayout(target: selected.rawTarget, executable: hdc))
    let remotePath = try TKHarmonyDumpLayoutParser.remotePath(from: dumpResult.stdout)
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-web-device-layout-\(UUID().uuidString).json")
        .path
    defer { try? FileManager.default.removeItem(atPath: output) }
    _ = try runHostCommand(TKHarmonyHDCCommand.recvFile(target: selected.rawTarget, remotePath: remotePath, localPath: output, executable: hdc))
    let data = try Data(contentsOf: URL(fileURLWithPath: output))
    let nodes = try TKHarmonyLayoutParser.nodeSummaries(in: data)
    guard let bounds = webHarmonyRootBounds(from: nodes) else {
        throw RuntimeError("Harmony layout did not include root bounds.")
    }
    return try webHostGeometryResponse(width: Int(bounds.width.rounded()), height: Int(bounds.height.rounded()))
}

private func webHarmonyRootBounds(from nodes: [TKHarmonyLayoutNodeSummary]) -> TKRect? {
    if let root = nodes.first(where: { $0.depth == 0 && ($0.bounds?.width ?? 0) > 0 && ($0.bounds?.height ?? 0) > 0 }) {
        return root.bounds
    }
    let bounds = nodes.compactMap(\.bounds).filter { $0.width > 0 && $0.height > 0 }
    guard !bounds.isEmpty else { return nil }
    let maxX = bounds.map { $0.x + $0.width }.max() ?? 0
    let maxY = bounds.map { $0.y + $0.height }.max() ?? 0
    guard maxX > 0, maxY > 0 else { return nil }
    return TKRect(x: 0, y: 0, width: maxX, height: maxY)
}

func webHarmonyGeometryFromProfile(_ profile: String) -> TKGeometryResponse? {
    var values: [String: String] = [:]
    for line in profile.split(whereSeparator: \.isNewline) {
        let raw = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !raw.hasPrefix("#"), let separator = raw.firstIndex(of: "=") else {
            continue
        }
        let key = raw[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = raw[raw.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !value.isEmpty else { continue }
        values[key] = value
    }
    guard
        let widthText = values["hw.lcd.single.width"] ?? values["hw.lcd.width"],
        let heightText = values["hw.lcd.single.height"] ?? values["hw.lcd.height"],
        let width = Int(widthText),
        let height = Int(heightText)
    else {
        return nil
    }
    return try? webHostGeometryResponse(width: width, height: height)
}

private func webHarmonyGeometryFromInstalledProfiles() -> TKGeometryResponse? {
    let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".Huawei")
        .appendingPathComponent("Emulator")
        .appendingPathComponent("deployed")
    guard let entries = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
        return nil
    }
    let geometries = entries.compactMap { entry -> TKGeometryResponse? in
        let config = entry.appendingPathComponent("config.ini")
        guard let profile = try? String(contentsOf: config, encoding: .utf8) else {
            return nil
        }
        return webHarmonyGeometryFromProfile(profile)
    }
    guard !geometries.isEmpty else { return nil }
    let first = geometries[0]
    let allSame = geometries.allSatisfy {
        $0.bounds.width == first.bounds.width && $0.bounds.height == first.bounds.height
    }
    return allSame ? first : nil
}

private func webIOSSimulatorFallbackSize(for target: HostDeviceTarget) -> (width: Int, height: Int) {
    let name = (target.name ?? "").lowercased()
    if name.contains("ipad") {
        return (1668, 2388)
    }
    if name.contains("pro max") || name.contains("plus") {
        return (1320, 2868)
    }
    if name.contains("pro") {
        return (1206, 2622)
    }
    if name.contains("mini") || name.contains("se") {
        return (750, 1334)
    }
    return (1206, 2622)
}

func normalizeWebIOSSimulatorInput(_ input: TKInputRequest, screen: WebIOSSimulatorScreenLayout) -> TKInputRequest {
    guard screen.width > 0, screen.height > 0, let width = input.width, let height = input.height, width > 0, height > 0 else {
        return input
    }
    let scaleX = Double(screen.width) / width
    let scaleY = Double(screen.height) / height

    switch input.type {
    case .tap:
        guard let x = input.x, let y = input.y else { return input }
        return TKInputRequest(
            type: input.type,
            targetOID: input.targetOID,
            matchedOID: input.matchedOID,
            matchedClassName: input.matchedClassName,
            activationStrategy: input.activationStrategy,
            x: clampedRounded(Double(x) * scaleX, min: 0, max: screen.width),
            y: clampedRounded(Double(y) * scaleY, min: 0, max: screen.height),
            width: Double(screen.width),
            height: Double(screen.height),
            duration: input.duration,
            text: input.text,
            button: input.button,
            secure: input.secure
        )
    case .swipe:
        guard let startX = input.startX, let startY = input.startY, let endX = input.endX, let endY = input.endY else { return input }
        return TKInputRequest(
            type: input.type,
            startX: clampedRounded(Double(startX) * scaleX, min: 0, max: screen.width),
            startY: clampedRounded(Double(startY) * scaleY, min: 0, max: screen.height),
            endX: clampedRounded(Double(endX) * scaleX, min: 0, max: screen.width),
            endY: clampedRounded(Double(endY) * scaleY, min: 0, max: screen.height),
            width: Double(screen.width),
            height: Double(screen.height),
            duration: input.duration
        )
    case .button, .typeText, .paste, .clear:
        return input
    }
}

func webIOSBaguetteCommand(action: TKInputRequest, udid: String, screen: WebIOSSimulatorScreenLayout, executable: String = "baguette") throws -> TKHostCommand {
    let input = normalizeWebIOSSimulatorInput(action, screen: screen)
    switch input.type {
    case .tap:
        let x = try requireCoordinate(input.x, name: "x", action: "tap")
        let y = try requireCoordinate(input.y, name: "y", action: "tap")
        let width = try requireCoordinate(input.width, name: "width", action: "tap")
        let height = try requireCoordinate(input.height, name: "height", action: "tap")
        return TKHostCommand(executable: executable, arguments: [
            "tap",
            "--udid", udid,
            "--x", "\(x)",
            "--y", "\(y)",
            "--width", "\(width)",
            "--height", "\(height)"
        ])
    case .swipe:
        let startX = try requireCoordinate(input.startX, name: "startX", action: "swipe")
        let startY = try requireCoordinate(input.startY, name: "startY", action: "swipe")
        let endX = try requireCoordinate(input.endX, name: "endX", action: "swipe")
        let endY = try requireCoordinate(input.endY, name: "endY", action: "swipe")
        let width = try requireCoordinate(input.width, name: "width", action: "swipe")
        let height = try requireCoordinate(input.height, name: "height", action: "swipe")
        var arguments = [
            "swipe",
            "--udid", udid,
            "--start-x", "\(startX)",
            "--start-y", "\(startY)",
            "--end-x", "\(endX)",
            "--end-y", "\(endY)",
            "--width", "\(width)",
            "--height", "\(height)"
        ]
        if let duration = input.duration {
            arguments.append(contentsOf: ["--duration", "\(duration)"])
        }
        return TKHostCommand(executable: executable, arguments: arguments)
    case .button, .typeText, .paste, .clear:
        return TKHostCommand(executable: executable, arguments: [])
    }
}

private func clampedRounded(_ value: Double, min: Int, max: Int) -> Double {
    Double(Swift.max(min, Swift.min(max, Int(value.rounded()))))
}

private func requireCoordinate(_ value: Double?, name: String, action: String) throws -> Int {
    guard let value else {
        throw RuntimeError("\(action) requires \(name).")
    }
    return Int(value.rounded())
}

private struct WebIOSBaguetteLayoutPayload: Decodable {
    struct Screen: Decodable {
        let width: Int
        let height: Int
    }

    let screen: Screen
}

private func runWebIOSSimulatorInput(selected: HostDeviceTarget, input: TKInputRequest) throws -> TKInputResult {
    switch input.type {
    case .tap, .swipe:
        let baguette = resolveBaguetteExecutable()
        let layoutCommand = TKHostCommand(executable: baguette, arguments: ["chrome", "layout", "--udid", selected.rawTarget])
        let layoutResult = try runHostCommand(layoutCommand)
        let layout = try JSONDecoder().decode(WebIOSBaguetteLayoutPayload.self, from: Data(layoutResult.stdout.utf8))
        let screen = WebIOSSimulatorScreenLayout(width: layout.screen.width, height: layout.screen.height)
        let inputCommand = try webIOSBaguetteCommand(action: input, udid: selected.rawTarget, screen: screen, executable: baguette)
        _ = try runHostCommand(inputCommand)
        return .success(
            action: input.type.rawValue,
            message: "iOS Simulator \(input.type.rawValue) was submitted through Triton host-HID adapter."
        )
    case .button, .typeText, .paste, .clear:
        return .unsupported(
            action: input.type.rawValue,
            message: "iOS Simulator host-side \(input.type.rawValue) is not exposed in the Web device surface yet."
        )
    }
}

private func resolveBaguetteExecutable() -> String {
    let candidates = [
        ProcessInfo.processInfo.environment["TRITONKIT_BAGUETTE_BIN"],
        "/opt/homebrew/bin/baguette",
        "/usr/local/bin/baguette",
        "baguette"
    ].compactMap { $0 }.filter { !$0.isEmpty }
    return candidates.first { candidate in
        candidate == "baguette" || FileManager.default.isExecutableFile(atPath: candidate)
    } ?? "baguette"
}

private func runWebAndroidInput(selected: HostDeviceTarget, input: TKInputRequest, adb: String) throws -> TKInputResult {
    switch input.type {
    case .tap:
        let x = try requireCoordinate(input.x, name: "x", action: "tap")
        let y = try requireCoordinate(input.y, name: "y", action: "tap")
        _ = try runHostCommand(TKAndroidADBCommand.tapCoordinate(serial: selected.rawTarget, x: x, y: y, executable: adb))
        return .success(action: "tap", message: "Android tap was submitted through adb input.")
    case .swipe:
        let startX = try requireCoordinate(input.startX, name: "startX", action: "swipe")
        let startY = try requireCoordinate(input.startY, name: "startY", action: "swipe")
        let endX = try requireCoordinate(input.endX, name: "endX", action: "swipe")
        let endY = try requireCoordinate(input.endY, name: "endY", action: "swipe")
        let durationMs = input.duration.map { Int(($0 * 1000).rounded()) }
        _ = try runHostCommand(TKAndroidADBCommand.swipeCoordinate(serial: selected.rawTarget, startX: startX, startY: startY, endX: endX, endY: endY, durationMs: durationMs, executable: adb))
        return .success(action: "swipe", message: "Android swipe was submitted through adb input.")
    case .typeText, .paste:
        let text = input.text ?? ""
        _ = try runHostCommand(TKAndroidADBCommand.inputText(serial: selected.rawTarget, text: text, executable: adb))
        return .success(action: input.type.rawValue, message: "Android text input was submitted through adb input.", secure: input.secure, redacted: input.secure, insertedLength: text.count)
    case .button:
        let button = input.button ?? "home"
        let keyCode = androidKeyEventName(for: button)
        _ = try runHostCommand(TKAndroidADBCommand.keyEvent(serial: selected.rawTarget, keyCode: keyCode, executable: adb))
        return .success(action: "button", message: "Android keyevent \(keyCode) was submitted through adb input.")
    case .clear:
        return .unsupported(action: "clear", message: "Android host clear is not exposed in the Web device surface yet.")
    }
}

private func runWebHarmonyInput(selected: HostDeviceTarget, input: TKInputRequest, hdc: String) throws -> TKInputResult {
    switch input.type {
    case .tap:
        let x = try requireCoordinate(input.x, name: "x", action: "tap")
        let y = try requireCoordinate(input.y, name: "y", action: "tap")
        _ = try runHostCommand(TKHarmonyHDCCommand.tapCoordinate(target: selected.rawTarget, x: x, y: y, executable: hdc))
        return .success(action: "tap", message: "Harmony tap was submitted through uitest.")
    case .swipe:
        let startX = try requireCoordinate(input.startX, name: "startX", action: "swipe")
        let startY = try requireCoordinate(input.startY, name: "startY", action: "swipe")
        let endX = try requireCoordinate(input.endX, name: "endX", action: "swipe")
        let endY = try requireCoordinate(input.endY, name: "endY", action: "swipe")
        _ = try runHostCommand(TKHarmonyHDCCommand.swipeCoordinate(target: selected.rawTarget, startX: startX, startY: startY, endX: endX, endY: endY, velocity: harmonySwipeVelocity(startX: Double(startX), startY: Double(startY), endX: Double(endX), endY: Double(endY), duration: input.duration), executable: hdc))
        return .success(action: "swipe", message: "Harmony swipe was submitted through uitest.")
    case .typeText, .paste:
        let text = input.text ?? ""
        _ = try runHostCommand(TKHarmonyHDCCommand.inputText(target: selected.rawTarget, text: text, executable: hdc))
        return .success(action: input.type.rawValue, message: "Harmony text input was submitted through uitest.", secure: input.secure, redacted: input.secure, insertedLength: text.count)
    case .button:
        let key = input.button ?? "home"
        _ = try runHostCommand(TKHarmonyHDCCommand.keyEvent(target: selected.rawTarget, key: key, executable: hdc))
        return .success(action: "button", message: "Harmony keyEvent \(key) was submitted through uitest.")
    case .clear:
        return .unsupported(action: "clear", message: "Harmony host clear is not exposed in the Web device surface yet.")
    }
}
