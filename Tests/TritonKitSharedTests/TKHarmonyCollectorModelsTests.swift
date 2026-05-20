import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKHarmonyCollectorModelsTests {
    @Test("debug manifest exposes Harmony embedded collector identity and capabilities")
    func debugManifestShape() throws {
        let manifest = TKHarmonyCollectorManifest.debugDefault()

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.platform == "harmony")
        #expect(manifest.transport == "embedded-websocket")
        #expect(manifest.runtimeMode == .debug)
        #expect(manifest.enabled)
        #expect(manifest.capabilities.contains(.appInfo))
        #expect(manifest.capabilities.contains(.viewSnapshot))
        #expect(manifest.capabilities.contains(.accessibility))
        #expect(manifest.capabilities.contains(.geometry))
        #expect(manifest.capabilities.contains(.screenshotMetadata))

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(TKHarmonyCollectorManifest.self, from: data)

        #expect(decoded == manifest)
    }

    @Test("release manifest is a no-op surface that keeps API shape but disables collection")
    func releaseManifestIsDisabled() throws {
        let manifest = TKHarmonyCollectorManifest.releaseDisabled()
        let configuration = TKHarmonyCollectorConfiguration.releaseDisabled()

        #expect(manifest.platform == "harmony")
        #expect(manifest.runtimeMode == .release)
        #expect(!manifest.enabled)
        #expect(manifest.capabilities.isEmpty)
        #expect(!configuration.enabled)
        #expect(configuration.runtimeMode == .release)
        #expect(!configuration.allowScreenshots)
        #expect(!configuration.includesScreenshotData)

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(TKHarmonyCollectorConfiguration.self, from: data)

        #expect(decoded == configuration)
    }

    @Test("snapshot envelope reuses shared geometry and accessibility models")
    func snapshotEnvelopeShape() throws {
        let snapshot = TKHarmonyCollectorSnapshot(
            capturedAt: "2026-05-20T10:00:00Z",
            app: TKHarmonyCollectorAppInfo(
                bundleName: "com.example.harmony",
                appName: "Harmony Demo",
                version: "1.0",
                build: "42",
                processID: 1001
            ),
            page: TKHarmonyCollectorPageState(
                abilityName: "EntryAbility",
                pageName: "LoginPage",
                route: "/login",
                state: ["isReady": .bool(true)]
            ),
            geometry: TKGeometryResponse(
                bounds: TKRect(x: 0, y: 0, width: 360, height: 780),
                safeArea: TKInsets(top: 24, left: 0, bottom: 0, right: 0),
                scale: 3,
                orientation: "portrait"
            ),
            accessibility: [
                TKAXNode(
                    role: "button",
                    label: "登录",
                    value: nil,
                    identifier: "loginButton",
                    title: nil,
                    frame: TKRect(x: 40, y: 320, width: 280, height: 48),
                    enabled: true,
                    focused: false,
                    hidden: false,
                    targetOID: nil,
                    className: "Button",
                    children: []
                ),
            ],
            screenshot: TKHarmonyCollectorScreenshotMetadata(
                format: "png",
                width: 1080,
                height: 2340,
                scale: 3,
                dataRef: "artifacts/harmony-login.png"
            ),
            redactionStatus: TKHarmonyCollectorRedactionStatus(
                policy: "summary",
                status: "redacted",
                redactedFields: ["page.state.password"],
                notes: ["screenshot stored as artifact reference"]
            ),
            extras: ["arkUIVersion": .string("API 23")]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TKHarmonyCollectorSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.platform == "harmony")
        #expect(decoded.page.route == "/login")
        #expect(decoded.page.state["isReady"] == .bool(true))
        #expect(decoded.geometry?.bounds.width == 360)
        #expect(decoded.accessibility.first?.identifier == "loginButton")
        #expect(decoded.screenshot?.dataRef == "artifacts/harmony-login.png")
        #expect(decoded.redactionStatus.status == "redacted")
        #expect(decoded.extras["arkUIVersion"] == .string("API 23"))
    }

    @Test("screenshot metadata never carries inline image bytes")
    func screenshotMetadataHasNoInlinePayload() throws {
        let metadata = TKHarmonyCollectorScreenshotMetadata(
            format: "png",
            width: 1080,
            height: 2340,
            scale: 3,
            dataRef: "artifacts/current.png"
        )

        let data = try JSONEncoder().encode(metadata)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["format"] as? String == "png")
        #expect(object["dataRef"] as? String == "artifacts/current.png")
        #expect(object["dataBase64"] == nil)
    }
}
