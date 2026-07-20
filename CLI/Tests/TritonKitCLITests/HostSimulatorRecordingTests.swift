import Testing
@testable import TritonKitCLI

struct HostSimulatorRecordingTests {
    @Test("bounded simulator recording validates video track instead of container timeline")
    func selectsVideoTrackDuration() throws {
        let actual = try simulatorRecordingActualDuration(
            containerDurationSeconds: 3.035,
            videoTrackDurationSeconds: [3.035],
            videoSampleDurationSeconds: 0.066667
        )

        #expect(actual == 0.066667)
    }

    @Test("bounded simulator recording accepts duration within tolerance")
    func acceptsDurationWithinTolerance() throws {
        let validation = try validateSimulatorRecordingDuration(
            requestedDurationSeconds: 3,
            actualDurationSeconds: 2.7
        )

        #expect(validation.requestedDurationSeconds == 3)
        #expect(validation.actualDurationSeconds == 2.7)
        #expect(validation.minimumAcceptedDurationSeconds == 2.25)
        #expect(validation.valid)
    }

    @Test("bounded simulator recording rejects materially truncated artifact")
    func rejectsTruncatedArtifact() {
        #expect(throws: HostSimulatorRecordingValidationError.self) {
            try validateSimulatorRecordingDuration(
                requestedDurationSeconds: 3,
                actualDurationSeconds: 0.066667
            )
        }
    }

    @Test("bounded simulator recording rejects unreadable duration")
    func rejectsUnreadableDuration() {
        #expect(throws: HostSimulatorRecordingValidationError.self) {
            try validateSimulatorRecordingDuration(
                requestedDurationSeconds: 3,
                actualDurationSeconds: .nan
            )
        }
    }
}
