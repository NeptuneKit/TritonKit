import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKWebTargetRegistryModelsTests {
    @Test("web target registry preserves mirror diagnosis and next action")
    func webTargetRegistryPreservesMirrorDiagnosisAndNextAction() throws {
        let response = TKWebTargetRegistryResponse(targets: [
            TKWebTargetRegistryEntry(
                id: "ios-real:73f725dfa795",
                platform: "ios",
                kind: "real-device",
                host: TKWebTargetHost(
                    target: "ios-real:73f725dfa795",
                    name: "iPhone",
                    runtime: "iOS 26.5",
                    scope: "real",
                    kind: "real-device",
                    source: "devicectl",
                    state: "connected",
                    ready: true,
                    transport: "wired"
                ),
                mirror: TKWebTargetMirror(state: .runtimeNotFound),
                diagnosis: TKWebTargetDiagnosis(code: .runtimeNotFound, message: "Debug App runtime is not connected."),
                nextAction: TKWebTargetNextAction(code: "start_debug_app", title: "启动 Debug App"),
                transportDiagnostics: [
                    TKWebTargetDiagnosis(
                        code: .iosUSBTunnelUnavailable,
                        message: "No supported iOS USB tunnel adapter was found on PATH.",
                        severity: "info"
                    )
                ]
            )
        ])

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKWebTargetRegistryResponse.self, from: data)
        let target = try #require(decoded.targets.first)

        #expect(target.id == "ios-real:73f725dfa795")
        #expect(target.host?.target == "ios-real:73f725dfa795")
        #expect(target.host?.name == "iPhone")
        #expect(target.host?.runtime == "iOS 26.5")
        #expect(target.host?.scope == "real")
        #expect(target.host?.transport == "wired")
        #expect(target.runtime == nil)
        #expect(target.mirror.state == .runtimeNotFound)
        #expect(target.diagnosis?.code == .runtimeNotFound)
        #expect(target.nextAction?.code == "start_debug_app")
        #expect(target.transportDiagnostics.map(\.code) == [.iosUSBTunnelUnavailable])
    }
}
