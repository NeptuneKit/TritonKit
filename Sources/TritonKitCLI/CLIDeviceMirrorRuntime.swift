import CoreGraphics
import Darwin
import Foundation
import ImageIO
import TritonKitShared
import UniformTypeIdentifiers

private struct DeviceMirrorFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
func deviceMirrorScreenshotArguments(_ options: DeviceMirror, output: String) -> [String] {
    if options.platform == .ios, options.bundleID != nil {
        var arguments = ["device", "runner", "screenshot", "--device", options.device, "--bundle-id", options.bundleID!, "--output", output, "--timeout", String(min(20, options.timeout)), "--json"]
        if let root = options.sessionRoot { arguments += ["--session-root", root] }
        return arguments
    }
    return ["device", "screenshot", "--platform", options.platform.rawValue, "--device", options.device, "--scope", options.scope.rawValue, "--output", output, "--adb", options.adb, "--hdc", options.hdc, "--timeout", String(min(20, options.timeout)), "--json"]
}
private func deviceMirrorRunChild(_ arguments: [String], timeout: Double) throws {
    let command = TKHostCommand(executable: Bundle.main.executablePath ?? CommandLine.arguments[0], arguments: arguments, redactedArgumentIndexes: Set(arguments.indices), defaultTimeoutSeconds: max(0.1, timeout), sensitiveOutput: true)
    do { _ = try runHostCommand(command, maximumOutputBytes: 65_536) }
    catch { throw DeviceMirrorFailure(message: "Existing device CLI command failed; inspect the selected device and active Runner session with their standalone commands.") }
}
private struct DeviceMirrorFrame {
    let png: Data
    let sourceWidth: Int
    let sourceHeight: Int
}
private func deviceMirrorFrame(path: URL, options: DeviceMirror) throws -> DeviceMirrorFrame {
    let input = try FileHandle(forReadingFrom: path)
    defer { try? input.close() }
    let data = try input.read(upToCount: options.maxBytes + 1) ?? Data()
    guard data.count <= options.maxBytes,
          data.prefix(8) == Data([137, 80, 78, 71, 13, 10, 26, 10]),
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          (1...16384).contains(width), (1...16384).contains(height), width * height <= 67_108_864 else {
        throw DeviceMirrorFailure(message: "Screenshot is not a PNG inside the configured byte and pixel budgets.")
    }
    let settings: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: options.maxSize, kCGImageSourceCreateThumbnailWithTransform: true]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, settings as CFDictionary) else { throw DeviceMirrorFailure(message: "PNG screenshot cannot be decoded.") }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { throw DeviceMirrorFailure(message: "PNG renderer is unavailable.") }
    CGImageDestinationAddImage(destination, thumbnail, nil)
    guard CGImageDestinationFinalize(destination), output.length <= options.maxBytes else { throw DeviceMirrorFailure(message: "Rendered PNG exceeds the byte budget.") }
    return DeviceMirrorFrame(png: output as Data, sourceWidth: width, sourceHeight: height)
}
private final class DeviceMirrorStopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var stopped: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func stop() { lock.lock(); value = true; lock.unlock() }
}
private final class DeviceMirrorTerminal {
    private var original = termios()
    private let originalFlags: Int32
    private var active = false
    init() throws {
        guard isatty(STDIN_FILENO) == 1, isatty(STDOUT_FILENO) == 1, tcgetattr(STDIN_FILENO, &original) == 0 else { throw DeviceMirrorFailure(message: "Interactive mirror requires a terminal. Use --frames 1 --output <new-directory> to capture PNG images.") }
        originalFlags = fcntl(STDIN_FILENO, F_GETFL)
        var raw = original
        cfmakeraw(&raw)
        guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { throw DeviceMirrorFailure(message: "Terminal raw mode could not be enabled.") }
        active = true
        guard fcntl(STDIN_FILENO, F_SETFL, originalFlags | O_NONBLOCK) == 0 else { restore(); throw DeviceMirrorFailure(message: "Terminal input could not be configured.") }
        write("\u{1b}[?1049h\u{1b}[?25l\u{1b}[?1000h\u{1b}[?1006h")
    }
    func write(_ value: String) { try? FileHandle.standardOutput.write(contentsOf: Data(value.utf8)) }
    func read() -> Data {
        var bytes = [UInt8](repeating: 0, count: 4096)
        let count = Darwin.read(STDIN_FILENO, &bytes, bytes.count)
        return count > 0 ? Data(bytes.prefix(count)) : Data()
    }
    func layout(width: Int, height: Int) -> DeviceMirrorLayout {
        var size = winsize()
        _ = ioctl(STDOUT_FILENO, TIOCGWINSZ, &size)
        let columns = max(1, Int(size.ws_col)), rows = max(3, Int(size.ws_row))
        return DeviceMirrorLayout(sourceWidth: width, sourceHeight: height, terminalColumns: columns, terminalRows: rows, cellWidth: size.ws_xpixel > 0 ? max(1, Int(size.ws_xpixel) / columns) : 8, cellHeight: size.ws_ypixel > 0 ? max(1, Int(size.ws_ypixel) / rows) : 16)
    }
    func restore() {
        guard active else { return }
        write(deviceMirrorTerminalCleanup)
        _ = tcsetattr(STDIN_FILENO, TCSANOW, &original)
        _ = fcntl(STDIN_FILENO, F_SETFL, originalFlags)
        active = false
    }
    deinit { restore() }
}
struct DeviceMirrorDependencies {
    var pin: (DeviceMirror) throws -> DeviceMirror
    var run: ([String], Double) throws -> Void
    static var live: Self { Self(pin: deviceMirrorPinTarget, run: { try deviceMirrorRunChild($0, timeout: $1) }) }
}
private func deviceMirrorPinTarget(_ options: DeviceMirror) throws -> DeviceMirror {
    // Resolve once and pin the concrete selector, so 'current' cannot switch mid-session.
    let selection = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: options.device, platform: options.platform, scope: options.scope, ready: true), hdc: options.hdc, adb: options.adb)
    var pinned = options
    pinned.device = selection.target.rawTarget
    pinned.scope = HostDeviceScope(rawValue: selection.target.scope ?? "all") ?? options.scope
    if options.platform == .ios && selection.target.scope == "real" && options.bundleID == nil { throw DeviceMirrorFailure(message: "iOS real-device mirror requires --bundle-id and an existing Runner session.") }
    return pinned
}
func runDeviceMirror(_ options: DeviceMirror, dependencies: DeviceMirrorDependencies = .live) throws -> DeviceMirrorOutput {
    let protocolKind = options.imageProtocol == .auto ? DeviceMirrorProtocol.detect(environment: ProcessInfo.processInfo.environment) : options.imageProtocol
    if options.frames == nil, protocolKind == nil { throw DeviceMirrorFailure(message: "Terminal PNG protocol is unsupported. Use Kitty, Ghostty or iTerm2, or --frames 1 --output <new-directory>.") }
    let pinned = try dependencies.pin(options)
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("triton-mirror-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: temporary) }
    var outputDirectory: URL?
    if let output = options.output {
        let directory = URL(fileURLWithPath: output).standardizedFileURL
        guard !FileManager.default.fileExists(atPath: directory.path) else { throw DeviceMirrorFailure(message: "Frame output directory already exists; choose a new directory.") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        outputDirectory = directory
    }
    let terminal = options.frames == nil ? try DeviceMirrorTerminal() : nil
    defer { terminal?.restore() }
    let stop = DeviceMirrorStopFlag()
    let signalQueue = DispatchQueue(label: "triton.device-mirror.signals")
    let originalINT = signal(SIGINT, SIG_IGN), originalTERM = signal(SIGTERM, SIG_IGN), originalHUP = signal(SIGHUP, SIG_IGN)
    let sources = [SIGINT, SIGTERM, SIGHUP].map { number -> DispatchSourceSignal in
        let source = DispatchSource.makeSignalSource(signal: number, queue: signalQueue)
        source.setEventHandler { stop.stop() }; source.resume(); return source
    }
    defer { sources.forEach { $0.cancel() }; _ = signal(SIGINT, originalINT); _ = signal(SIGTERM, originalTERM); _ = signal(SIGHUP, originalHUP) }
    let deadline = Date().addingTimeInterval(options.timeout)
    var decoder = DeviceMirrorInputDecoder()
    var captured = 0, sourceWidth = 0, sourceHeight = 0
    var images: [String] = []
    var nextFrame = Date.distantPast
    var layout: DeviceMirrorLayout?
    var status = options.readOnly ? "read-only" : "click; type; Ctrl-H Home; Ctrl-B Back; Ctrl-A AppSwitch; Ctrl-C exit"
    while !stop.stopped, Date() < deadline, options.frames.map({ captured < $0 }) ?? true {
        if Date() >= nextFrame {
            let capturePath = temporary.appendingPathComponent("frame.png")
            if FileManager.default.fileExists(atPath: capturePath.path) { try FileManager.default.removeItem(at: capturePath) }
            try dependencies.run(deviceMirrorScreenshotArguments(pinned, output: capturePath.path), min(20, deadline.timeIntervalSinceNow))
            let frame = try deviceMirrorFrame(path: capturePath, options: options)
            sourceWidth = frame.sourceWidth; sourceHeight = frame.sourceHeight
            captured += 1
            if let directory = outputDirectory {
                let path = directory.appendingPathComponent(String(format: "frame-%04d.png", captured))
                try frame.png.write(to: path, options: [.withoutOverwriting])
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
                images.append(path.path)
            }
            if let terminal, let protocolKind {
                let current = terminal.layout(width: sourceWidth, height: sourceHeight); layout = current
                terminal.write("\u{1b}_Ga=d,d=I,i=31,q=2\u{1b}\\\u{1b}[H" + deviceMirrorRenderPNG(frame.png, protocolKind: protocolKind, columns: current.columns, rows: current.rows))
                terminal.write("\u{1b}[\(current.rows + 1);1H\u{1b}[2K\(options.platform.rawValue) device | \(sourceWidth)x\(sourceHeight) | \(captured) frames\u{1b}[\(current.rows + 2);1H\u{1b}[2K\(deviceMirrorSafeText(status))")
            }
            nextFrame = Date().addingTimeInterval(1 / options.fps)
        }
        if let terminal {
            for action in decoder.feed(terminal.read()) {
                if action == .quit { stop.stop(); break }
                if !options.readOnly {
                    do { try deviceMirrorApplyInput(action, layout: layout, options: pinned, temporary: temporary, timeout: min(20, deadline.timeIntervalSinceNow), runner: dependencies.run); status = "Input submitted; screenshot verification pending"; nextFrame = .distantPast }
                    catch { status = "Input unavailable/failed; inspect standalone device action contract" }
                }
            }
        }
        if !stop.stopped { Thread.sleep(forTimeInterval: min(0.02, max(0, deadline.timeIntervalSinceNow))) }
    }
    guard captured > 0 else { throw DeviceMirrorFailure(message: "Mirror ended before a screenshot was captured.") }
    return DeviceMirrorOutput(ok: true, action: "mirror", platform: options.platform.rawValue, mode: options.frames != nil ? "png-files" : protocolKind!.rawValue, frames: captured, images: images, sourceWidth: sourceWidth, sourceHeight: sourceHeight, businessReadinessVerified: false)
}
private func deviceMirrorApplyInput(_ input: DeviceMirrorInput, layout: DeviceMirrorLayout?, options: DeviceMirror, temporary: URL, timeout: Double, runner: ([String], Double) throws -> Void) throws {
    var arguments: [String]
    switch input {
    case .click(let column, let row):
        guard let layout, let point = layout.point(column: column, row: row) else { return }
        arguments = ["device", "tap", "--x", String(point.x), "--y", String(point.y), "--width", String(layout.sourceWidth), "--height", String(layout.sourceHeight)]
    case .press(let key): arguments = ["device", "press", "--button", key]
    case .text(let text):
        let file = temporary.appendingPathComponent("input.txt")
        try Data(text.utf8).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        arguments = ["device", "type", "--text-file", file.path]
    case .quit: return
    }
    arguments += ["--platform", options.platform.rawValue, "--device", options.device]
    if let orientation = options.orientation { arguments += ["--orientation", orientation] }
    if let observation = options.observationID { arguments += ["--observation-id", observation] }
    if let bundle = options.bundleID { arguments += ["--bundle-id", bundle] }
    try runner(arguments, timeout)
}
