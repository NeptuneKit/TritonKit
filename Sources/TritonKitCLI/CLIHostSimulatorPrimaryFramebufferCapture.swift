import Darwin
import Foundation
import ImageIO
import TritonKitShared

struct IOSSimulatorPrimaryFramebufferCapture {
    let result: HostProcessResult
    let evidence: IOSSimulatorPrimaryFramebufferEvidence
    let width: Int
    let height: Int
}

/// Explicit still-image path only. Its display evidence must never authorize input or streams.
func captureIOSSimulatorPrimaryFramebuffer(
    simulator: String,
    outputPath: String,
    resizeProbe: IOSSimulatorResizeProbe? = nil,
    displayProbe: IOSSimulatorPrimaryFramebufferDisplayProbe? = nil,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) }
) throws -> IOSSimulatorPrimaryFramebufferCapture {
    try prepareHostArtifactOutputPath(outputPath)
    let paths = try freshDeviceInfoArtifactPaths(action: "primary-framebuffer")
    let directory = URL(fileURLWithPath: paths.json).deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: directory) }
    let staging = directory.appendingPathComponent("screenshot.png")
    let route = try primaryFramebufferSimulatorScreenshotRoute(
        TKSimctlCommand.screenshot(udid: simulator, output: staging.path), simulator: simulator,
        resizeProbe: resizeProbe, displayProbe: displayProbe)
    let result = try runner(route.command)
    guard result.exitCode == 0 else { throw HostCommandRunError.nonZeroExit(command: route.command, result: result) }
    let fd = open(staging.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
    guard fd >= 0 else { throw primaryFramebufferArtifactError(outputPath) }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? handle.close() }
    var info = stat()
    let maximumBytes = 64 * 1_024 * 1_024
    guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
          info.st_size > 0, info.st_size <= maximumBytes,
          let data = try handle.read(upToCount: maximumBytes + 1), data.count == info.st_size,
          data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) == 1,
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 16_384, height <= 16_384,
          width * height <= 64_000_000,
          let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
          image.width == width, image.height == height,
          CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
        throw primaryFramebufferArtifactError(outputPath)
    }
    // Publish only complete validated bytes; link fails atomically if another writer won.
    let destination = URL(fileURLWithPath: outputPath)
    let temporary = destination.deletingLastPathComponent().appendingPathComponent(".triton-primary-" + UUID().uuidString)
    let outputFD = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard outputFD >= 0 else { throw primaryFramebufferArtifactError(outputPath) }
    let output = FileHandle(fileDescriptor: outputFD, closeOnDealloc: true)
    defer { try? output.close(); try? FileManager.default.removeItem(at: temporary) }
    try output.write(contentsOf: data)
    try output.synchronize()
    try output.close()
    guard link(temporary.path, destination.path) == 0 else {
        throw HostArtifactOutputError.rejected(path: outputPath, reason: "exclusive publication failed; existing outputs are never replaced")
    }
    return .init(result: result, evidence: route.evidence, width: width, height: height)
}

private func primaryFramebufferArtifactError(_ path: String) -> HostArtifactOutputError {
    .rejected(path: path, reason: "primary framebuffer capture requires a fresh, bounded, decodable PNG with positive dimensions")
}
