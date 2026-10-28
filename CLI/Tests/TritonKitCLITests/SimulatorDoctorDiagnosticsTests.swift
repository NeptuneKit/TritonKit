import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized) struct SimulatorDoctorDiagnosticsTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

    @Test func noSelectedTargetMeansNoGeometryQueries() {
        let report = simulatorDoctorDiagnostics(target: nil, resizeProbe: { _, _ in Issue.record("unexpected resize query"); return .inactive }, displayProbe: { _, _ in Issue.record("unexpected display query"); return .unknown(.queryFailed) })
        #expect(report == nil)
    }

    @Test func separateProbeStatesAndBoundRecovery() throws {
        var calls: [String] = []
        let report = try #require(simulatorDoctorDiagnostics(target: target, environment: ["DEVELOPER_DIR": "/fixture/Xcode"], resizeProbe: { selected, environment in
            calls.append(selected); #expect(environment["DEVELOPER_DIR"] == "/fixture/Xcode"); return .unknown(.unsupportedQuery)
        }, displayProbe: { selected, _ in calls.append(selected); return .primary(.init(id: "1", primary: true, active: true, integrated: true)) }))
        #expect(calls == [target, target])
        #expect(report.resize.state == "unknown")
        #expect(report.resize.reason == "unsupportedQuery")
        #expect(report.display.state == "primary")
        #expect(!report.inputDispatchVerified && !report.captureVerified)
        #expect(report.nextAction.args.contains("sim:" + target))
        let json = String(decoding: try JSONEncoder().encode(report), as: UTF8.self)
        #expect(!json.contains("/fixture"))
    }

    @Test func unknownDisplayDoesNotHideActiveResize() throws {
        let report = try #require(simulatorDoctorDiagnostics(target: target, resizeProbe: { _, _ in .active(.init(displayUniqueID: "11111111-1111-1111-1111-111111111111", width: 400, height: 800)) }, displayProbe: { _, _ in .unknown(.timedOut) }))
        #expect(report.resize.state == "active")
        #expect(report.display.reason == "timedOut")
        #expect(!report.captureVerified)
    }

    @Test func targetBoundErrorsPreserveFailureAndDoNotCapture() throws {
        var captureCalls = 0
        do {
            _ = try withSimulatorDiagnosticTarget(target) {
                try resizeAwareSimulatorScreenshotCommand(TKSimctlCommand.screenshot(udid: target, output: "/unused.png"), simulator: target, probe: { _, _ in .inactive }, displayProbe: { _, _ in .unknown(.queryFailed) })
            }
            captureCalls += 1
        } catch let error as SimulatorTargetDiagnosticError {
            #expect(error.detail.code == "ios_simulator_display_safety_unknown")
            #expect(error.detail.nextAction?.args.contains("sim:" + target) == true)
        }
        #expect(captureCalls == 0)
    }

    @Test func doctorDefaultOmitsTargetDiagnosticsAndExplicitReportIsPublished() throws {
        func tool(_ name: String, _ command: TKHostCommand) -> HostToolProbeOutput {
            .init(name: name, path: name, available: true, versionSummary: nil, error: nil, sourceCommand: "fixture")
        }
        #expect(iosHostDeviceDoctor(scope: .simulator, probe: tool).simulatorDiagnostics == nil)
        let report = simulatorDoctorDiagnostics(target: target, resizeProbe: { _, _ in .unknown(.queryFailed) }, displayProbe: { _, _ in .unknown(.unsupported) })
        let doctor = iosHostDeviceDoctor(scope: .simulator, simulatorDiagnostics: report, probe: tool)
        #expect(doctor.ok) // Tool health is separate from target state.
        #expect(doctor.simulatorDiagnostics?.resize.reason == "queryFailed")
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.outputContracts.first { $0.selector == "host.device-doctor" }?.fields.contains { $0.name == "simulatorDiagnostics.resize.reason" } == true)
    }

    @Test func displayFailurePreservesOneTypedEnvelope() throws {
        let failures: [Error] = [IOSSimulatorDisplayError.topologyUnknown(.queryFailed), SimulatorTargetDiagnosticError(detail: simulatorTargetBoundDetail(IOSSimulatorDisplayError.topologyUnknown(.timedOut).detail, target: target))]
        for failure in failures {
            let pipe = Pipe()
            let original = dup(STDOUT_FILENO)
            fflush(stdout)
            dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
            do { try failHostCommand(failure, outputFormat: .json) } catch { }
            fflush(stdout)
            dup2(original, STDOUT_FILENO)
            close(original)
            try pipe.fileHandleForWriting.close()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            try pipe.fileHandleForReading.close()
            let output = try JSONDecoder().decode(TKCLIErrorResponse.self, from: data)
            #expect(!output.ok && output.error.code == "ios_simulator_display_safety_unknown")
        }
    }

    @Test func invalidTargetNeverProbesOrReflectsUntrustedSelector() {
        #expect(simulatorDoctorDiagnostics(target: "private-id\nargument", resizeProbe: { _, _ in Issue.record("unexpected"); return .inactive }, displayProbe: { _, _ in Issue.record("unexpected"); return .unknown(.queryFailed) }) == nil)
    }
}
