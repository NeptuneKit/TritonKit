import ArgumentParser
import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing
@testable import TritonKitCLI

@Suite("SP-200 device parity integration")
struct DeviceParityIntegrationTests {
    @Test func deviceRootAdvertisesEveryIncludedFeatureAndNoCloudOrMCP() {
        let names = Set(Device.configuration.subcommands.map { $0.configuration.commandName ?? "" })
        for name in ["orientation", "fold", "location", "clipboard", "foreground", "recording", "logs", "crashes", "tap", "double-tap", "press", "mirror"] {
            #expect(names.contains(name), "Missing executable device \(name) command")
        }
        #expect(!names.contains("cloud"))
        #expect(!names.contains("mcp"))
    }

    @Test func parityCommandsHaveDiscoverableSchemas() {
        let schemas = commandSchemas()
        let deviceNames = Set(schemas.filter { $0.name == "device" }.flatMap { $0.subcommands.map(\.name) })
        for name in ["orientation", "fold", "location", "clipboard", "foreground", "recording", "logs", "crashes", "tap", "double-tap", "press", "mirror"] {
            #expect(deviceNames.contains(name), "Missing machine-readable device \(name) schema")
        }
    }

    @Test func httpCommandEnvelopePassesThroughWithoutSecondWrapper() async throws {
        let router = Router(context: BasicRequestContext.self)
        let raw = Data(#"{"ok":false,"error":{"code":"device_action_unknown","message":"Inspect before retry"}}"#.utf8)
        registerDeviceParityRoutes(on: router, execute: { arguments in
            #expect(arguments == ["device", "orientation", "get", "--platform", "android", "--device", "android:test", "--json"])
            return raw
        })
        try await Application(router: router).test(.router) { client in
            let response = try await client.execute(uri: "/v1/device/command", method: .post,
                body: ByteBuffer(string: #"{"arguments":["orientation","get","--platform","android","--device","android:test"]}"#))
            #expect(response.status == .conflict)
            #expect(Data(buffer: response.body) == raw)
        }
    }

    @Test func httpRejectsDisallowedRootsAndWorkerBeforeExecuting() async throws {
        let router = Router(context: BasicRequestContext.self)
        registerDeviceParityRoutes(on: router, execute: { _ in
            Issue.record("Invalid request reached executor")
            return Data(#"{"ok":true}"#.utf8)
        })
        try await Application(router: router).test(.router) { client in
            for body in [#"{"arguments":["recording","_worker","--session","/private/other"]}"#,
                         #"{"arguments":["mirror","--device","android:test"]}"#,
                         #"{"arguments":["cloud","allocate"]}"#,
                         #"{"arguments":["orientation","get","--device","android:test","--format","text"]}"#,
                         #"{"arguments":["orientation","get"]}"#] {
                let response = try await client.execute(uri: "/v1/device/command", method: .post, body: ByteBuffer(string: body))
                #expect(response.status == .badRequest)
            }
        }
    }
}
