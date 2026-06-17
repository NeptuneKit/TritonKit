import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct DiscoveryTimeoutTests {
    @Test("version and schema discovery paths stay static")
    func versionAndSchemaDiscoveryPathsStayStatic() throws {
        let version = TKCLIVersionResponse(version: TritonKitBuildInfo.cliVersion)
        let schema = try buildSchemaResponse(command: "device")

        #expect(!version.version.isEmpty)
        #expect(schema.commands.map(\.name) == ["device"])
    }

    @Test("Harmony discovery host commands are bounded below agent watchdog")
    func harmonyDiscoveryHostCommandsAreBoundedBelowAgentWatchdog() {
        #expect(TKHarmonyHDCCommand.version().defaultTimeoutSeconds < 5)
        #expect(TKHarmonyHDCCommand.listTargets().defaultTimeoutSeconds < 5)
        #expect(TKHarmonyHDCCommand.listTargetsPlain().defaultTimeoutSeconds < 5)
    }

    @Test("Harmony discovery timeout maps to stable JSON error code")
    func harmonyDiscoveryTimeoutMapsToStableJSONErrorCode() throws {
        let command = TKHarmonyHDCCommand.listTargets()
        let timeout = HostCommandRunError.timeout(
            command: command,
            timeoutSeconds: command.defaultTimeoutSeconds,
            stdoutLogPath: nil,
            stderrLogPath: nil
        )

        let detail = hostCommandTimeoutErrorDetail(command: command, message: "\(timeout)")
        let line = try encodeJSON(TKCLIErrorResponse(error: detail))
        let json = try jsonObject(line: line)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? String == "harmony_discovery_timeout")
        #expect((error["hint"] as? String)?.contains("triton device doctor --platform harmony --json") == true)
    }
}

private func jsonObject(line: String) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: Data(line.utf8))
    return try #require(object as? [String: Any])
}
