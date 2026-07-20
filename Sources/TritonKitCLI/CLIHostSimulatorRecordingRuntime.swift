import AVFoundation
import Foundation
import TritonKitShared

struct HostSimulatorRecordingDurationValidation: Encodable, Equatable {
    let requestedDurationSeconds: Double
    let actualDurationSeconds: Double
    let minimumAcceptedDurationSeconds: Double
    let valid: Bool
}

enum HostSimulatorRecordingValidationError: Error, Equatable, CustomStringConvertible {
    case unreadable(reason: String)
    case truncated(requested: Double, actual: Double, minimum: Double)

    var description: String {
        switch self {
        case .unreadable(let reason):
            return "Simulator recording duration is unavailable: \(reason)"
        case .truncated(let requested, let actual, let minimum):
            return "Simulator recording is truncated: requested \(requested)s, actual \(actual)s, minimum accepted \(minimum)s."
        }
    }
}

private struct HostSimulatorRecordingMediaDurations {
    let containerDurationSeconds: Double
    let videoTrackDurationSeconds: [Double]
    let videoSampleDurationSeconds: Double?
}

func simulatorRecordingActualDuration(
    containerDurationSeconds: Double,
    videoTrackDurationSeconds: [Double],
    videoSampleDurationSeconds: Double?
) throws -> Double {
    guard let videoSampleDurationSeconds,
          videoSampleDurationSeconds.isFinite,
          videoSampleDurationSeconds > 0 else {
        throw HostSimulatorRecordingValidationError.unreadable(
            reason: "no positive finite video sample duration was found; container duration was \(containerDurationSeconds)s and track durations were \(videoTrackDurationSeconds)"
        )
    }
    return videoSampleDurationSeconds
}

func validateSimulatorRecordingDuration(
    requestedDurationSeconds: Double,
    actualDurationSeconds: Double
) throws -> HostSimulatorRecordingDurationValidation {
    guard actualDurationSeconds.isFinite, actualDurationSeconds > 0 else {
        throw HostSimulatorRecordingValidationError.unreadable(
            reason: "media duration must be a positive finite number"
        )
    }
    let minimumAcceptedDurationSeconds = requestedDurationSeconds * 0.75
    guard actualDurationSeconds >= minimumAcceptedDurationSeconds else {
        throw HostSimulatorRecordingValidationError.truncated(
            requested: requestedDurationSeconds,
            actual: actualDurationSeconds,
            minimum: minimumAcceptedDurationSeconds
        )
    }
    return HostSimulatorRecordingDurationValidation(
        requestedDurationSeconds: requestedDurationSeconds,
        actualDurationSeconds: actualDurationSeconds,
        minimumAcceptedDurationSeconds: minimumAcceptedDurationSeconds,
        valid: true
    )
}

private func simulatorRecordingMediaDurations(at path: String) async throws -> HostSimulatorRecordingMediaDurations {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    do {
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        var videoTrackDurationSeconds: [Double] = []
        for track in tracks {
            let timeRange = try await track.load(.timeRange)
            videoTrackDurationSeconds.append(CMTimeGetSeconds(timeRange.duration))
        }
        let videoSampleDurationSeconds = simulatorRecordingVideoSampleDurationSeconds(tracks: tracks)
        return HostSimulatorRecordingMediaDurations(
            containerDurationSeconds: CMTimeGetSeconds(duration),
            videoTrackDurationSeconds: videoTrackDurationSeconds,
            videoSampleDurationSeconds: videoSampleDurationSeconds
        )
    } catch {
        throw HostSimulatorRecordingValidationError.unreadable(reason: error.localizedDescription)
    }
}

private func simulatorRecordingVideoSampleDurationSeconds(tracks: [AVAssetTrack]) -> Double? {
    var durations: [Double] = []
    for track in tracks {
        guard let cursor = track.makeSampleCursorAtFirstSampleInDecodeOrder() else {
            continue
        }
        var earliestPresentationTime: CMTime?
        var latestPresentationEnd: CMTime?
        while true {
            let presentationTime = cursor.presentationTimeStamp
            let sampleDuration = cursor.currentSampleDuration
            guard presentationTime.isNumeric else {
                break
            }
            if let earliest = earliestPresentationTime {
                if CMTimeCompare(presentationTime, earliest) < 0 {
                    earliestPresentationTime = presentationTime
                }
            } else {
                earliestPresentationTime = presentationTime
            }
            let end = sampleDuration.isNumeric && sampleDuration > .zero
                ? CMTimeAdd(presentationTime, sampleDuration)
                : presentationTime
            if let latest = latestPresentationEnd {
                if CMTimeCompare(end, latest) > 0 {
                    latestPresentationEnd = end
                }
            } else {
                latestPresentationEnd = end
            }
            if cursor.stepInDecodeOrder(byCount: 1) <= 0 {
                break
            }
        }
        if let earliestPresentationTime, let latestPresentationEnd {
            durations.append(CMTimeGetSeconds(CMTimeSubtract(latestPresentationEnd, earliestPresentationTime)))
        }
    }
    return durations.filter { $0.isFinite && $0 > 0 }.max()
}

func runHostSimulatorRecordingCommand(
    simulator: String,
    command: TKHostCommand,
    outputPath: String,
    requestedDurationSeconds: Double,
    outputFormat: ClientOutputFormat
) async throws {
    do {
        let result = try runHostCommand(command, interruptAfter: requestedDurationSeconds)
        let mediaDurations = try await simulatorRecordingMediaDurations(at: outputPath)
        let actualDurationSeconds = try simulatorRecordingActualDuration(
            containerDurationSeconds: mediaDurations.containerDurationSeconds,
            videoTrackDurationSeconds: mediaDurations.videoTrackDurationSeconds,
            videoSampleDurationSeconds: mediaDurations.videoSampleDurationSeconds
        )
        let validation = try validateSimulatorRecordingDuration(
            requestedDurationSeconds: requestedDurationSeconds,
            actualDurationSeconds: actualDurationSeconds
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
        let fileBytes = (attributes[.size] as? NSNumber)?.uint64Value
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = HostSimulatorRecordingOutput(
            ok: true,
            action: "sim.record",
            runtimeScope: "host-simulator",
            target: "sim:\(simulator)",
            tool: command.executable,
            exitCode: result.exitCode,
            riskLevel: command.riskLevel.rawValue,
            sourceCommand: result.sourceCommand,
            stdoutTruncated: result.stdoutTruncated,
            stderrTruncated: result.stderrTruncated,
            stderr: stderr.isEmpty ? nil : stderr,
            artifacts: [outputPath],
            fileBytes: fileBytes,
            containerDurationSeconds: mediaDurations.containerDurationSeconds,
            videoTrackDurationSeconds: mediaDurations.videoTrackDurationSeconds,
            requestedDurationSeconds: validation.requestedDurationSeconds,
            actualDurationSeconds: validation.actualDurationSeconds,
            minimumAcceptedDurationSeconds: validation.minimumAcceptedDurationSeconds,
            durationValidation: "passed",
            note: "Host-side simulator video recording was validated and written."
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            print(outputPath)
            print("Recorded \(validation.actualDurationSeconds)s (requested \(validation.requestedDurationSeconds)s).")
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}
