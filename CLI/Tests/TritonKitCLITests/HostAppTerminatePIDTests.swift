import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct HostAppTerminatePIDTests {
    @Test("iOS real-device terminate fails closed before constructing a devicectl command")
    func realDeviceTerminateFailsClosed() {
        #expect(throws: HostAppTerminateError.pidResolutionUnavailable(bundleID: "com.example.demo", selector: "ios-real:abc123")) {
            _ = try planHostAppTerminate(
                selection: realDeviceSelection(),
                bundleID: "com.example.demo",
                packageName: nil,
                bundle: nil,
                adb: "adb",
                hdc: "hdc",
                devicectlArtifacts: ("/tmp/terminate.json", "/tmp/terminate.log")
            )
        }
    }

    @Test("real-device unsupported termination exposes one redacted recovery envelope")
    func realDeviceUnsupportedTerminationHasRecoveryContract() throws {
        let detail = hostAppTerminateErrorDetail(
            .pidResolutionUnavailable(bundleID: "com.example.demo", selector: "ios-real:abc123")
        )

        #expect(detail.code == "app_terminate_pid_resolution_unavailable")
        #expect(detail.message.contains("Xcode/CoreDevice"))
        #expect(detail.hint?.contains("PID") == true)
        #expect(detail.hint?.contains("optional cold-restart alternative") == true)
        #expect(detail.hint?.contains("does not mean terminate succeeded") == true)
        #expect(detail.nextAction?.command == "app")
        #expect(detail.nextAction?.args == [
            "launch", "--device", "ios-real:abc123", "--scope", "real", "--platform", "ios",
            "--bundle-id", "com.example.demo", "--json",
        ])

        let response = try JSONDecoder().decode(
            TKCLIErrorResponse.self,
            from: JSONEncoder().encode(TKCLIErrorResponse(error: detail))
        )
        #expect(response.ok == false)
        #expect(response.error.code == "app_terminate_pid_resolution_unavailable")
        #expect(response.error.nextAction == detail.nextAction)
        #expect(response.error.message.contains("00008110-PRIVATE") == false)
        #expect(response.error.hint?.contains("00008110-PRIVATE") == false)
        #expect(response.error.nextAction?.args.contains("00008110-PRIVATE") == false)
    }

    @Test("app schema exposes root and terminate PID-resolution contracts")
    func appSchemaExposesTerminatePIDResolutionContract() throws {
        let app = try #require(commandSchemas().first { $0.name == "app" })
        let terminate = try #require(app.subcommands.first { $0.name == "terminate" })

        #expect(app.failureCodes.contains("app_terminate_pid_resolution_unavailable"))
        #expect(terminate.summary.contains("iOS real-device"))
        #expect(terminate.summary.contains("fail closed"))
        #expect(terminate.summary.contains("verified PID"))
        #expect(terminate.failureCodes == [
            "app_terminate_failed",
            "app_terminate_pid_resolution_unavailable",
        ])
    }

    @Test("terminate plan keeps simulator Android and Harmony builders unchanged")
    func nonRealTerminatePlansUseExistingBuilders() throws {
        let simulatorBundleID = "com.example.simulator"
        let simulatorPlan = try planHostAppTerminate(
            selection: nonRealSelection(platform: .ios, scope: .simulator, id: "sim:SIM-1", target: "SIM-1", kind: "simulator"),
            bundleID: simulatorBundleID,
            packageName: nil,
            bundle: nil,
            adb: "adb",
            hdc: "hdc",
            devicectlArtifacts: nil
        )
        #expect(simulatorPlan.command == TKSimctlCommand.terminateApp(udid: "SIM-1", bundleID: simulatorBundleID))

        let androidPackage = "com.example.android"
        let androidPlan = try planHostAppTerminate(
            selection: nonRealSelection(platform: .android, scope: .emulator, id: "android-emulator", target: "emulator-5554", kind: "emulator"),
            bundleID: nil,
            packageName: androidPackage,
            bundle: nil,
            adb: "adb-fixture",
            hdc: "hdc",
            devicectlArtifacts: nil
        )
        #expect(androidPlan.command == TKAndroidADBCommand.forceStop(serial: "emulator-5554", packageName: androidPackage, executable: "adb-fixture"))

        let harmonyBundle = "com.example.harmony"
        let harmonyPlan = try planHostAppTerminate(
            selection: nonRealSelection(platform: .harmony, scope: .emulator, id: "harmony-emulator", target: "127.0.0.1:10100", kind: "emulator"),
            bundleID: nil,
            packageName: nil,
            bundle: harmonyBundle,
            adb: "adb",
            hdc: "hdc-fixture",
            devicectlArtifacts: nil
        )
        #expect(harmonyPlan.command == TKHarmonyHDCCommand.forceStop(target: "127.0.0.1:10100", bundleName: harmonyBundle, executable: "hdc-fixture"))
    }

    private func realDeviceSelection() -> HostDeviceSelectionResult {
        HostDeviceSelectionResult(
            platform: .ios,
            target: HostDeviceTarget(
                platform: "ios",
                id: "ios-real:canonical",
                target: "ios-real:abc123",
                state: "connected",
                ready: true,
                source: "devicectl",
                name: "Test iPhone",
                runtime: "iOS 26.5",
                transport: "wired",
                scope: "real",
                kind: "real-device",
                rawTarget: "00008110-PRIVATE"
            ),
            selector: "ios-real:abc123",
            source: .explicit,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "ios-real:abc123", platform: .ios, scope: .real))
        )
    }

    private func nonRealSelection(
        platform: HostDevicePlatform,
        scope: HostDeviceScope,
        id: String,
        target: String,
        kind: String
    ) -> HostDeviceSelectionResult {
        HostDeviceSelectionResult(
            platform: platform,
            target: HostDeviceTarget(
                platform: platform.rawValue,
                id: id,
                target: target,
                state: "ready",
                ready: true,
                source: "fixture",
                name: "Test " + platform.rawValue,
                runtime: nil,
                transport: nil,
                scope: scope.rawValue,
                kind: kind,
                rawTarget: target
            ),
            selector: id,
            source: .explicit,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: id, platform: platform, scope: scope, ready: true))
        )
    }
}
