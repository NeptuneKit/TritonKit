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

struct WebIOSBaguetteTouchEvent: Codable, Equatable {
    let type: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

struct WebIOSBaguetteSwipeLifecycle: Equatable {
    let command: TKHostCommand
    let events: [WebIOSBaguetteTouchEvent]
    let duration: Double
    let cadence: Double
    let terminalLinger: Double
}

typealias WebIOSBaguetteLifecycleRunner = (WebIOSBaguetteSwipeLifecycle) throws -> HostProcessResult

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
        return .all
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

func makeWebTargetRegistry(
    runtimeTargets: [TKTargetSummary],
    hostTargets: [HostDeviceTarget],
    usbTunnelAdapterAvailable: Bool = webIOSTunnelAdapterAvailable()
) -> TKWebTargetRegistryResponse {
    var matchedRuntimeIDs = Set<String>()
    let readyRealHosts = hostTargets.filter {
        $0.platform == HostDevicePlatform.ios.rawValue && $0.scope == HostDeviceScope.real.rawValue && $0.ready
    }
    let realRuntimeTargets = runtimeTargets.filter {
        $0.platform == HostDevicePlatform.ios.rawValue && $0.connected && $0.simulatorUDID == nil
    }
    let hostEntries = hostTargets.map { host -> TKWebTargetRegistryEntry in
        let ambiguousRuntimeCandidates = webAmbiguousRuntimeCandidates(
            host: host,
            readyRealHostCount: readyRealHosts.count,
            realRuntimeTargets: realRuntimeTargets
        )
        let runtime = ambiguousRuntimeCandidates.isEmpty
            ? matchingRuntimeTargetForRegistry(host: host, runtimeTargets: runtimeTargets, readyRealHostCount: readyRealHosts.count)
            : nil
        if let runtime {
            matchedRuntimeIDs.insert(runtime.id)
        }
        let hostStatus = TKWebTargetHost(
            target: host.target,
            name: host.name,
            runtime: host.runtime,
            scope: host.scope,
            kind: host.kind,
            source: host.source,
            state: host.state,
            ready: host.ready,
            transport: host.transport ?? host.source
        )
        let runtimeStatus = runtime.map(webTargetRuntime)
        let mirror = webTargetMirror(host: host, runtime: runtime, ambiguousRuntimeCandidates: ambiguousRuntimeCandidates)
        return TKWebTargetRegistryEntry(
            id: webTargetRegistryID(for: host),
            platform: host.platform,
            kind: host.kind ?? host.scope ?? "host-target",
            host: hostStatus,
            runtime: runtimeStatus,
            mirror: TKWebTargetMirror(state: mirror.state),
            diagnosis: mirror.diagnosis,
            nextAction: mirror.nextAction,
            transportDiagnostics: webTargetTransportDiagnostics(host: host, usbTunnelAdapterAvailable: usbTunnelAdapterAvailable),
            inputCapabilities: webHostInputCapabilities(platform: host.platform)
        )
    }

    let runtimeEntries = runtimeTargets
        .filter { !matchedRuntimeIDs.contains($0.id) }
        .map { runtime in
            let mirrorState: TKWebTargetMirrorState = runtime.latestHierarchyAvailable ? .ready : .mirrorUnavailable
            return TKWebTargetRegistryEntry(
                id: runtime.id,
                platform: runtime.platform,
                kind: "embedded-runtime",
                runtime: webTargetRuntime(runtime),
                mirror: TKWebTargetMirror(state: mirrorState),
                diagnosis: mirrorState == .ready ? nil : TKWebTargetDiagnosis(
                    code: .mirrorCapabilityUnavailable,
                    message: "Runtime is connected but mirror capabilities are unavailable."
                ),
                nextAction: mirrorState == .ready ? nil : TKWebTargetNextAction(
                    code: "inspect_runtime_capabilities",
                    title: "检查 Debug App runtime capabilities"
                ),
                inputCapabilities: webRuntimeInputCapabilities(runtime: runtime)
            )
        }

    return TKWebTargetRegistryResponse(targets: (hostEntries + runtimeEntries).sorted(by: webTargetRegistrySort))
}

func webHostInputCapabilities(platform: String) -> [TKWebInputCapability] {
    let supported = ["tap", "swipe", "longPress"]
    let unsupported = ["pinch", "rotate", "multiTouchPath"]
    return supported.map {
        TKWebInputCapability(action: $0, source: "host", supported: true)
    } + unsupported.map {
        TKWebInputCapability(action: $0, source: "host", supported: false, reason: "unsupported_capability")
    }
}

private func webRuntimeInputCapabilities(runtime: TKTargetSummary) -> [TKWebInputCapability] {
    let source = "runtime"
    return ["tap", "swipe", "longPress", "pinch"].map {
        TKWebInputCapability(action: $0, source: source, supported: true)
    } + ["rotate", "multiTouchPath"].map {
        TKWebInputCapability(action: $0, source: source, supported: false, reason: "unsupported_capability")
    }
}

func webIOSTunnelAdapterAvailable(path: String? = ProcessInfo.processInfo.environment["PATH"]) -> Bool {
    guard let path, !path.isEmpty else { return false }
    let fileManager = FileManager.default
    return path
        .split(separator: ":")
        .map(String.init)
        .contains { directory in
            let iproxy = URL(fileURLWithPath: directory).appendingPathComponent("iproxy").path
            return fileManager.isExecutableFile(atPath: iproxy)
        }
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
    // 快速通道：对于 iOS 宿主模拟器，直接从 ID 中提取 UDID 并命显存高刷，绕过同步执行子进程检索
    if id.hasPrefix("host:ios:") {
        let parts = id.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        if parts.count == 3 {
            let udid = String(parts[2])
            print("[TritonCLI] Entered fast-path for host:ios with UDID: \(udid)")
            fflush(stdout)
            _ = CLIHostSimulatorFramebufferService.shared.startStreaming(udid: udid)
            if let jpegData = CLIHostSimulatorFramebufferService.shared.getLatestFrame(udid: udid) {
                print("[TritonCLI] Hit framebuffer cache! Returning fast screenshot.")
                fflush(stdout)
                return WebHostDeviceScreenshot(
                    data: jpegData,
                    contentType: "image/jpeg",
                    width: 1290,
                    height: 2796
                )
            } else {
                print("[TritonCLI] Framebuffer cache was nil, falling back to slow resolve path.")
                fflush(stdout)
            }
        }
    }

    let resolved = try resolveWebHostDeviceTarget(id, hdc: hdc, adb: adb)

    if resolved.platform == .ios {
        let udid = resolved.target.rawTarget
        _ = CLIHostSimulatorFramebufferService.shared.startStreaming(udid: udid)
        if let jpegData = CLIHostSimulatorFramebufferService.shared.getLatestFrame(udid: udid) {
            return WebHostDeviceScreenshot(
                data: jpegData,
                contentType: "image/jpeg",
                width: 1290,
                height: 2796
            )
        }
    }

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
        guard runtime.platform == HostDevicePlatform.ios.rawValue, runtime.connected else {
            return false
        }
        if parsed.selector.hasPrefix("ios-real:") {
            return runtime.simulatorUDID == nil
        }
        return runtime.simulatorUDID == parsed.selector || runtime.id.hasSuffix(parsed.selector)
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

private func matchingRuntimeTargetForRegistry(
    host: HostDeviceTarget,
    runtimeTargets: [TKTargetSummary],
    readyRealHostCount: Int
) -> TKTargetSummary? {
    runtimeTargets.first { runtime in
        guard runtime.platform == host.platform, runtime.connected else { return false }
        if host.platform == HostDevicePlatform.ios.rawValue, host.scope == HostDeviceScope.real.rawValue {
            let realRuntimeTargets = runtimeTargets.filter {
                $0.platform == HostDevicePlatform.ios.rawValue && $0.connected && $0.simulatorUDID == nil
            }
            return readyRealHostCount == 1 && realRuntimeTargets.count == 1 && runtime.simulatorUDID == nil
                || runtime.simulatorUDID == nil && (runtime.id.hasSuffix(host.id) || runtime.id.hasSuffix(host.target))
        }
        return matchingRuntimeTarget(for: host, runtimeTargets: [runtime]) != nil
    }
}

private func webAmbiguousRuntimeCandidates(
    host: HostDeviceTarget,
    readyRealHostCount: Int,
    realRuntimeTargets: [TKTargetSummary]
) -> [String] {
    guard host.platform == HostDevicePlatform.ios.rawValue,
          host.scope == HostDeviceScope.real.rawValue,
          host.ready,
          readyRealHostCount > 1,
          !realRuntimeTargets.isEmpty else {
        return []
    }
    let directlyMatched = realRuntimeTargets.contains {
        $0.id.hasSuffix(host.id) || $0.id.hasSuffix(host.target)
    }
    return directlyMatched ? [] : realRuntimeTargets.map(\.id).sorted()
}

private func webTargetRegistryID(for host: HostDeviceTarget) -> String {
    if host.scope == HostDeviceScope.real.rawValue {
        return host.id
    }
    return webHostDeviceTargetID(host)
}

private func webTargetRuntime(_ runtime: TKTargetSummary) -> TKWebTargetRuntime {
    TKWebTargetRuntime(
        id: runtime.id,
        state: runtime.connected ? "connected" : "disconnected",
        transport: runtime.transport,
        appBundleId: runtime.bundleIdentifier,
        capabilities: runtime.latestHierarchyAvailable ? ["screenshot", "hierarchy"] : []
    )
}

private func webTargetMirror(
    host: HostDeviceTarget,
    runtime: TKTargetSummary?,
    ambiguousRuntimeCandidates: [String] = []
) -> (state: TKWebTargetMirrorState, diagnosis: TKWebTargetDiagnosis?, nextAction: TKWebTargetNextAction?) {
    guard host.ready else {
        return (
            .hostOffline,
            TKWebTargetDiagnosis(code: .runtimeNotFound, message: "Host target is not ready."),
            TKWebTargetNextAction(code: "connect_host_target", title: "连接或解锁设备")
        )
    }
    if host.scope != HostDeviceScope.real.rawValue && host.kind != "real-device" {
        return (.ready, nil, nil)
    }
    if !ambiguousRuntimeCandidates.isEmpty {
        return (
            .runtimeNotFound,
            TKWebTargetDiagnosis(
                code: .ambiguousRuntimeTarget,
                message: "Multiple ready iOS real devices exist and runtime target cannot be uniquely associated: \(ambiguousRuntimeCandidates.joined(separator: ", "))."
            ),
            TKWebTargetNextAction(code: "select_runtime_target", title: "手动选择真机 runtime 关联")
        )
    }
    guard let runtime else {
        return (
            .runtimeNotFound,
            TKWebTargetDiagnosis(code: .runtimeNotFound, message: "Host target is ready but no Debug App runtime is connected."),
            TKWebTargetNextAction(code: "start_debug_app", title: "启动已集成 TritonKit 的 Debug App")
        )
    }
    guard runtime.latestHierarchyAvailable else {
        return (
            .mirrorUnavailable,
            TKWebTargetDiagnosis(code: .mirrorCapabilityUnavailable, message: "Runtime is connected but screenshot or hierarchy is unavailable."),
            TKWebTargetNextAction(code: "inspect_runtime_capabilities", title: "检查 Debug App runtime capabilities")
        )
    }
    return (.ready, nil, nil)
}

private func webTargetTransportDiagnostics(
    host: HostDeviceTarget,
    usbTunnelAdapterAvailable: Bool
) -> [TKWebTargetDiagnosis] {
    guard host.platform == HostDevicePlatform.ios.rawValue,
          host.scope == HostDeviceScope.real.rawValue,
          host.ready else {
        return []
    }
    let transport = host.transport?.lowercased() ?? ""
    guard transport == "wired" || transport == "usb" else {
        return []
    }
    guard !usbTunnelAdapterAvailable else {
        return []
    }
    return [
        TKWebTargetDiagnosis(
            code: .iosUSBTunnelUnavailable,
            message: "No supported iOS USB tunnel adapter was found on PATH.",
            severity: "info"
        )
    ]
}

private func webTargetRegistrySort(_ lhs: TKWebTargetRegistryEntry, _ rhs: TKWebTargetRegistryEntry) -> Bool {
    let platformOrder = ["ios": 0, "android": 1, "harmony": 2]
    let leftPlatform = platformOrder[lhs.platform] ?? 99
    let rightPlatform = platformOrder[rhs.platform] ?? 99
    if leftPlatform != rightPlatform {
        return leftPlatform < rightPlatform
    }
    if lhs.mirror.state != rhs.mirror.state {
        return lhs.mirror.state == .ready
    }
    return lhs.id < rhs.id
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
    case .tap, .longPress:
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
    case .pinch:
        guard let centerX = input.centerX,
              let centerY = input.centerY,
              let startDistance = input.startDistance,
              let endDistance = input.endDistance else { return input }
        let distanceScale = (scaleX + scaleY) / 2
        return TKInputRequest(
            type: input.type,
            centerX: clampedRounded(Double(centerX) * scaleX, min: 0, max: screen.width),
            centerY: clampedRounded(Double(centerY) * scaleY, min: 0, max: screen.height),
            startDistance: Double(startDistance) * distanceScale,
            endDistance: Double(endDistance) * distanceScale,
            scale: input.scale,
            width: Double(screen.width),
            height: Double(screen.height),
            duration: input.duration
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
    case .button, .typeText, .paste, .clear, .deleteBackward:
        return input
    }
}

/// Resolve the simulator point-space width/height for a host HID command.
/// The simulator layout metadata is the source of truth: caller-provided
/// width/height only describe the caller's own coordinate space and are honored
/// when both are present and positive (matching `normalizeWebIOSSimulatorInput`);
/// otherwise the coordinates are already expressed in simulator points and the
/// target layout dimensions are used directly. This keeps `triton sim tap
/// --x <x> --y <y>` self-sufficient without requiring caller-supplied
/// width/height.
private func webIOSSimulatorPointSpace(
    input: TKInputRequest,
    screen: WebIOSSimulatorScreenLayout
) -> (width: Int, height: Int) {
    if let width = input.width, let height = input.height, width > 0, height > 0 {
        return (Int(width.rounded()), Int(height.rounded()))
    }
    return (screen.width, screen.height)
}

func webIOSBaguetteCommand(action: TKInputRequest, udid: String, screen: WebIOSSimulatorScreenLayout, executable: String = "baguette") throws -> TKHostCommand {
    let input = normalizeWebIOSSimulatorInput(action, screen: screen)
    switch input.type {
    case .tap:
        let x = try requireCoordinate(input.x, name: "x", action: "tap")
        let y = try requireCoordinate(input.y, name: "y", action: "tap")
        let pointSpace = webIOSSimulatorPointSpace(input: input, screen: screen)
        return TKHostCommand(executable: executable, arguments: [
            "tap",
            "--udid", udid,
            "--x", "\(x)",
            "--y", "\(y)",
            "--width", "\(pointSpace.width)",
            "--height", "\(pointSpace.height)"
        ])
    case .swipe:
        throw RuntimeError("iOS Simulator swipe requires the persistent Baguette input lifecycle session.")
    case .longPress:
        let x = try requireCoordinate(input.x, name: "x", action: "longPress")
        let y = try requireCoordinate(input.y, name: "y", action: "longPress")
        let pointSpace = webIOSSimulatorPointSpace(input: input, screen: screen)
        let hold = TKInputRequest.swipe(
            startX: Double(x),
            startY: Double(y),
            endX: Double(x),
            endY: Double(y),
            width: Double(pointSpace.width),
            height: Double(pointSpace.height),
            duration: input.duration ?? 0.65
        )
        return try webIOSBaguetteSwipeCommand(input: hold, udid: udid, executable: executable, action: "longPress")
    case .pinch, .button, .typeText, .paste, .clear, .deleteBackward:
        return TKHostCommand(executable: executable, arguments: [])
    }
}

private func webIOSBaguetteSwipeCommand(input: TKInputRequest, udid: String, executable: String, action: String) throws -> TKHostCommand {
    let startX = try requireCoordinate(input.startX, name: "startX", action: action)
    let startY = try requireCoordinate(input.startY, name: "startY", action: action)
    let endX = try requireCoordinate(input.endX, name: "endX", action: action)
    let endY = try requireCoordinate(input.endY, name: "endY", action: action)
    let width = try requireCoordinate(input.width, name: "width", action: action)
    let height = try requireCoordinate(input.height, name: "height", action: action)
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
}

func webIOSBaguetteSwipeLifecycle(
    input: TKInputRequest,
    udid: String,
    screen: WebIOSSimulatorScreenLayout,
    executable: String = "baguette",
    moveCount: Int = 10
) throws -> WebIOSBaguetteSwipeLifecycle {
    let normalized = normalizeWebIOSSimulatorInput(input, screen: screen)
    let startX = try requireCoordinate(normalized.startX, name: "startX", action: "swipe")
    let startY = try requireCoordinate(normalized.startY, name: "startY", action: "swipe")
    let endX = try requireCoordinate(normalized.endX, name: "endX", action: "swipe")
    let endY = try requireCoordinate(normalized.endY, name: "endY", action: "swipe")
    let pointSpace = webIOSSimulatorPointSpace(input: normalized, screen: screen)
    let width = pointSpace.width
    let height = pointSpace.height
    let duration = (normalized.duration ?? 0.25) > 0 ? (normalized.duration ?? 0.25) : 0.25
    let steps = max(1, moveCount)
    let cadence = duration / Double(steps + 1)
    let terminalLinger = max(0.1, cadence)

    var events = [
        WebIOSBaguetteTouchEvent(type: "touch1-down", x: startX, y: startY, width: width, height: height)
    ]
    for index in 1...steps {
        let progress = Double(index) / Double(steps)
        events.append(WebIOSBaguetteTouchEvent(
            type: "touch1-move",
            x: Int((Double(startX) + Double(endX - startX) * progress).rounded()),
            y: Int((Double(startY) + Double(endY - startY) * progress).rounded()),
            width: width,
            height: height
        ))
    }
    events.append(WebIOSBaguetteTouchEvent(type: "touch1-up", x: endX, y: endY, width: width, height: height))

    return WebIOSBaguetteSwipeLifecycle(
        command: TKHostCommand(
            executable: executable,
            arguments: ["input", "--udid", udid],
            defaultTimeoutSeconds: max(30, duration + terminalLinger + 5)
        ),
        events: events,
        duration: duration,
        cadence: cadence,
        terminalLinger: terminalLinger
    )
}

private struct WebIOSBaguetteInputAck: Decodable {
    let ok: Bool
    let error: String?
}

@discardableResult
func runWebIOSBaguetteLifecycle(
    _ lifecycle: WebIOSBaguetteSwipeLifecycle,
    runner: WebIOSBaguetteLifecycleRunner = runWebIOSBaguetteLifecycleProcess
) throws -> HostProcessResult {
    let result = try runner(lifecycle)
    let ackLines = result.stdout.split(whereSeparator: \.isNewline).map(String.init)
    guard ackLines.count == lifecycle.events.count else {
        throw RuntimeError("Baguette input acknowledged \(ackLines.count) of \(lifecycle.events.count) swipe lifecycle events; terminal touch-up was not confirmed.")
    }
    for (index, line) in ackLines.enumerated() {
        let ack = try JSONDecoder().decode(WebIOSBaguetteInputAck.self, from: Data(line.utf8))
        guard ack.ok else {
            throw RuntimeError("Baguette rejected swipe lifecycle event \(index + 1)/\(lifecycle.events.count): \(ack.error ?? "unknown error")")
        }
    }
    return result
}

private func runWebIOSBaguetteLifecycleProcess(_ lifecycle: WebIOSBaguetteSwipeLifecycle) throws -> HostProcessResult {
    let command = lifecycle.command
    let process = Process()
    configureHostProcessExecutable(process, command: command)
    let stdin = Pipe()
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
    } catch {
        throw HostCommandRunError.launchFailed(error.localizedDescription)
    }

    let timeoutWorkItem = DispatchWorkItem {
        if process.isRunning {
            process.terminate()
        }
    }
    DispatchQueue.global(qos: .utility).asyncAfter(
        deadline: .now() + command.defaultTimeoutSeconds,
        execute: timeoutWorkItem
    )

    let writer = stdin.fileHandleForWriting
    let reader = stdout.fileHandleForReading
    var acknowledged = Data()
    var ackBuffer = Data()
    defer {
        timeoutWorkItem.cancel()
        try? writer.close()
        if process.isRunning {
            process.terminate()
        }
    }

    do {
        for (index, event) in lifecycle.events.enumerated() {
            let payload = try JSONEncoder().encode(event)
            try writer.write(contentsOf: payload)
            try writer.write(contentsOf: Data([0x0A]))
            let ackLine = try readWebIOSBaguetteAckLine(from: reader, buffer: &ackBuffer)
            acknowledged.append(ackLine)
            acknowledged.append(0x0A)

            if index < lifecycle.events.count - 1 {
                Thread.sleep(forTimeInterval: lifecycle.cadence)
            } else {
                // Baguette's ack confirms enqueue, not UIKit delivery. Keep the
                // shared input process alive briefly so terminal up can flush.
                Thread.sleep(forTimeInterval: lifecycle.terminalLinger)
            }
        }
        try writer.close()
    } catch {
        try? writer.close()
        if process.isRunning {
            process.terminate()
        }
        throw error
    }

    process.waitUntilExit()
    timeoutWorkItem.cancel()
    let stderrData = (try? stderr.fileHandleForReading.readToEnd()) ?? Data()
    let result = HostProcessResult(
        stdoutData: acknowledged,
        stderrData: stderrData,
        exitCode: process.terminationStatus,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: false,
        stderrTruncated: false,
        stdoutLogPath: nil,
        stderrLogPath: nil,
        stdoutBytes: acknowledged.count,
        stderrBytes: stderrData.count
    )
    guard result.exitCode == 0 else {
        throw HostCommandRunError.nonZeroExit(command: command, result: result)
    }
    return result
}

private func readWebIOSBaguetteAckLine(from handle: FileHandle, buffer: inout Data, maximumBytes: Int = 16_384) throws -> Data {
    while buffer.count < maximumBytes {
        if let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            return line
        }
        let chunk = handle.availableData
        guard !chunk.isEmpty else {
            throw RuntimeError("Baguette input session ended before acknowledging terminal touch-up.")
        }
        buffer.append(chunk)
    }
    throw RuntimeError("Baguette input acknowledgement exceeded \(maximumBytes) bytes.")
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
    case .tap, .swipe, .longPress:
        let baguette = resolveBaguetteExecutable()
        let layoutCommand = TKHostCommand(executable: baguette, arguments: ["chrome", "layout", "--udid", selected.rawTarget])
        let layoutResult = try runHostCommand(layoutCommand)
        let layout = try JSONDecoder().decode(WebIOSBaguetteLayoutPayload.self, from: Data(layoutResult.stdout.utf8))
        let screen = WebIOSSimulatorScreenLayout(width: layout.screen.width, height: layout.screen.height)
        var sourceCommands = [layoutResult.sourceCommand]
        if input.type == .swipe {
            let lifecycle = try webIOSBaguetteSwipeLifecycle(
                input: input,
                udid: selected.rawTarget,
                screen: screen,
                executable: baguette
            )
            let lifecycleResult = try runWebIOSBaguetteLifecycle(lifecycle)
            sourceCommands.append(lifecycleResult.sourceCommand)
        } else {
            let inputCommand = try webIOSBaguetteCommand(action: input, udid: selected.rawTarget, screen: screen, executable: baguette)
            let inputResult = try runHostCommand(inputCommand)
            sourceCommands.append(inputResult.sourceCommand)
        }
        return .success(
            action: input.type.rawValue,
            message: "iOS Simulator \(input.type.rawValue) was submitted through Triton host-HID adapter; verify settled business state with AX, wait, or screenshot.",
            strategy: input.type == .tap ? "host-hid-coordinate-tap" : "host-hid-\(input.type.rawValue)",
            source: "host-hid",
            verification: TKInputVerificationBoundary(
                hint: "Host-HID submission only confirms coordinate delivery; verify the settled business postcondition separately.",
                suggestedCommands: [
                    "triton verify text-exists <expected-postcondition> --json",
                    "triton wait --text <expected-postcondition> --json",
                ]
            ),
            sourceCommands: sourceCommands
        )
    case .pinch, .button, .typeText, .paste, .clear, .deleteBackward:
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
    case .longPress:
        let x = try requireCoordinate(input.x, name: "x", action: "longPress")
        let y = try requireCoordinate(input.y, name: "y", action: "longPress")
        let durationMs = Int(((input.duration ?? 0.65) * 1000).rounded())
        _ = try runHostCommand(TKAndroidADBCommand.swipeCoordinate(serial: selected.rawTarget, startX: x, startY: y, endX: x, endY: y, durationMs: durationMs, executable: adb))
        return .success(action: "longPress", message: "Android longPress was submitted through adb input swipe hold.")
    case .swipe:
        let startX = try requireCoordinate(input.startX, name: "startX", action: "swipe")
        let startY = try requireCoordinate(input.startY, name: "startY", action: "swipe")
        let endX = try requireCoordinate(input.endX, name: "endX", action: "swipe")
        let endY = try requireCoordinate(input.endY, name: "endY", action: "swipe")
        let durationMs = input.duration.map { Int(($0 * 1000).rounded()) }
        _ = try runHostCommand(TKAndroidADBCommand.swipeCoordinate(serial: selected.rawTarget, startX: startX, startY: startY, endX: endX, endY: endY, durationMs: durationMs, executable: adb))
        return .success(action: "swipe", message: "Android swipe was submitted through adb input.")
    case .pinch:
        return .unsupported(action: "pinch", message: "Android host pinch is not exposed in the Web device surface yet.")
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
    case .deleteBackward:
        _ = try runHostCommand(TKAndroidADBCommand.keyEvent(serial: selected.rawTarget, keyCode: "KEYCODE_DEL", executable: adb))
        return .success(action: "deleteBackward", message: "Android deleteBackward was submitted through adb keyevent.", deletedLength: 1)
    }
}

private func runWebHarmonyInput(selected: HostDeviceTarget, input: TKInputRequest, hdc: String) throws -> TKInputResult {
    switch input.type {
    case .tap:
        let x = try requireCoordinate(input.x, name: "x", action: "tap")
        let y = try requireCoordinate(input.y, name: "y", action: "tap")
        _ = try runHostCommand(TKHarmonyHDCCommand.tapCoordinate(target: selected.rawTarget, x: x, y: y, executable: hdc))
        return .success(action: "tap", message: "Harmony tap was submitted through uitest.")
    case .longPress:
        let x = try requireCoordinate(input.x, name: "x", action: "longPress")
        let y = try requireCoordinate(input.y, name: "y", action: "longPress")
        let velocity = harmonySwipeVelocity(startX: Double(x), startY: Double(y), endX: Double(x), endY: Double(y), duration: input.duration)
        _ = try runHostCommand(TKHarmonyHDCCommand.swipeCoordinate(target: selected.rawTarget, startX: x, startY: y, endX: x, endY: y, velocity: velocity, executable: hdc))
        return .success(action: "longPress", message: "Harmony longPress was submitted through uitest same-point swipe hold.")
    case .swipe:
        let startX = try requireCoordinate(input.startX, name: "startX", action: "swipe")
        let startY = try requireCoordinate(input.startY, name: "startY", action: "swipe")
        let endX = try requireCoordinate(input.endX, name: "endX", action: "swipe")
        let endY = try requireCoordinate(input.endY, name: "endY", action: "swipe")
        _ = try runHostCommand(TKHarmonyHDCCommand.swipeCoordinate(target: selected.rawTarget, startX: startX, startY: startY, endX: endX, endY: endY, velocity: harmonySwipeVelocity(startX: Double(startX), startY: Double(startY), endX: Double(endX), endY: Double(endY), duration: input.duration), executable: hdc))
        return .success(action: "swipe", message: "Harmony swipe was submitted through uitest.")
    case .pinch:
        return .unsupported(action: "pinch", message: "Harmony host pinch is not exposed in the Web device surface yet.")
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
    case .deleteBackward:
        return .unsupported(action: "deleteBackward", message: "Harmony host deleteBackward is not exposed in the Web device surface yet.")
    }
}
