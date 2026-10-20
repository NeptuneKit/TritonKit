import Foundation
import ImageIO
import Testing
import TritonKitShared
@testable import TritonKitCLI

// An unset/invalid ownership gate is a disabled test, never live acceptance.
private let sp196OwnedFramebufferSimulator: UUID? = ProcessInfo.processInfo.environment[
    "TRITON_SP196_OWNED_SIMULATOR"
].flatMap(UUID.init(uuidString:))

private enum FramebufferLiveIntegrationError: Error, CustomStringConvertible {
    case ownershipRequired
    case selectedXcodeUnavailable
    case readinessQueryFailed
    case readinessOutputInvalid
    case ownedTargetNotReady
    case resizeActive
    case resizeStateUnknown
    case jpegDeadlineExceeded

    var description: String {
        switch self {
        case .ownershipRequired: "An explicit owned Simulator UUID is required; no live capture was started."
        case .selectedXcodeUnavailable: "Selected Xcode framebuffer framework paths are unavailable."
        case .readinessQueryFailed: "Read-only Simulator readiness query failed; no live capture was started."
        case .readinessOutputInvalid: "Read-only Simulator readiness output was invalid or truncated."
        case .ownedTargetNotReady: "The owned Simulator is not uniquely available and Booted; no boot was attempted."
        case .resizeActive: "Resize Mode is active; no framebuffer capture was started."
        case .resizeStateUnknown: "Fresh Resize Mode state is unknown; no framebuffer capture was started."
        case .jpegDeadlineExceeded: "No decodable real JPEG arrived within the ten-second deadline."
        }
    }
}

@Suite("SP-196 owned Simulator live framebuffer", .serialized)
struct FramebufferLiveIntegrationTests {
    @Test(.enabled(
        if: sp196OwnedFramebufferSimulator != nil,
        "Requires TRITON_SP196_OWNED_SIMULATOR with an explicitly owned Simulator UUID; disabled is not live acceptance."
    ))
    func selectedXcodeProducesRealJPEGAndBalancesTwoSubscriptions() async throws {
        guard let ownedUUID = sp196OwnedFramebufferSimulator else {
            throw FramebufferLiveIntegrationError.ownershipRequired
        }
        let target = ownedUUID.uuidString
        let inherited = ProcessInfo.processInfo.environment
        guard let plan = framebufferFrameworkPlan(
            developerDirectory: selectedXcodeDeveloperDirectory(environment: inherited)
        ) else { throw FramebufferLiveIntegrationError.selectedXcodeUnavailable }

        // Bind both readonly checks to the same selected Xcode as the service.
        let environment = ["DEVELOPER_DIR": plan.developerDirectory]
        let query = TKHostCommand(
            executable: "/usr/bin/xcrun",
            arguments: TKSimctlCommand.listAvailableDevices().arguments,
            environment: environment,
            redactedEnvironmentKeys: ["DEVELOPER_DIR"],
            defaultTimeoutSeconds: 6,
            sensitiveOutput: true
        )
        let result: HostProcessResult
        do { result = try runHostCommand(query, maximumOutputBytes: 1_048_576) }
        catch { throw FramebufferLiveIntegrationError.readinessQueryFailed }
        guard !result.stdoutTruncated, !result.stderrTruncated,
              let devices = try? TKSimctlDeviceListParser.parse(result.stdoutData)
        else { throw FramebufferLiveIntegrationError.readinessOutputInvalid }
        let matches = devices.filter { UUID(uuidString: $0.udid) == ownedUUID }
        guard matches.count == 1, matches[0].isAvailable, matches[0].isBooted else {
            throw FramebufferLiveIntegrationError.ownedTargetNotReady
        }
        switch probeIOSSimulatorResize(target: target, environment: environment) {
        case .inactive: break
        case .active: throw FramebufferLiveIntegrationError.resizeActive
        case .unknown: throw FramebufferLiveIntegrationError.resizeStateUnknown
        }

        let service = CLIHostSimulatorFramebufferService.shared
        // The parent runs this in a fresh, dedicated test process. Reject a
        // stale visible frame; this getter alone cannot prove zero leases.
        let initiallyEmpty = service.getLatestFrame(udid: target) == nil
        try #require(initiallyEmpty, "Live acceptance requires an unused in-process capture target.")
        var ownedLeases = 0
        defer {
            while ownedLeases > 0 {
                service.stopStreaming(udid: target)
                ownedLeases -= 1
            }
        }

        // False is a compatibility failure, never an unsupported skip. Private
        // ABI crashes are intentionally left for the parent process to record.
        let firstStarted = service.startStreaming(udid: target)
        try #require(firstStarted, "Selected Xcode could not start the real framebuffer session.")
        ownedLeases += 1
        let firstJPEG = try await realJPEG(service: service, target: target)
        try requireJPEG(firstJPEG)

        let secondStarted = service.startStreaming(udid: target)
        try #require(secondStarted, "A second subscriber could not acquire the same framebuffer session.")
        ownedLeases += 1
        service.stopStreaming(udid: target)
        ownedLeases -= 1
        let remainingJPEG = try await realJPEG(service: service, target: target)
        try requireJPEG(remainingJPEG)

        service.stopStreaming(udid: target)
        ownedLeases -= 1
        let stoppedImmediately = service.getLatestFrame(udid: target) == nil
        let stoppedVersionImmediately = service.getLatestFrameWithVersion(udid: target) == nil
        #expect(stoppedImmediately, "The final stop must remove the public frame immediately.")
        #expect(stoppedVersionImmediately, "The final stop must remove the public versioned frame immediately.")
        // Observe the public state during queued callback teardown. No device
        // input, boot, launch, screenshot fallback or server is needed.
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(300))
        repeat {
            try await Task.sleep(for: .milliseconds(25))
            let stopped = service.getLatestFrameWithVersion(udid: target) == nil
            try #require(stopped, "Stopped capture must not publish a late queued frame.")
        } while clock.now < deadline
    }

    private func realJPEG(service: CLIHostSimulatorFramebufferService, target: String) async throws -> Data {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while clock.now < deadline {
            try Task.checkCancellation()
            if let data = service.getLatestFrame(udid: target), isDecodableJPEG(data) { return data }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw FramebufferLiveIntegrationError.jpegDeadlineExceeded
    }

    private func isDecodableJPEG(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source), type as String == "public.jpeg",
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return false }
        return image.width > 0 && image.height > 0
    }

    private func requireJPEG(_ data: Data) throws {
        let decoded = isDecodableJPEG(data)
        try #require(decoded, "The real framebuffer must produce JPEG bytes with positive decoded dimensions.")
    }
}
