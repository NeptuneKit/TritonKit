import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKExportArchiveTests {
    @Test("JSON value preserves hierarchy-shaped objects")
    func jsonValueFromObject() throws {
        let object: [String: Any] = [
            "displayItems": [
                [
                    "oid": 1,
                    "className": "UIWindow",
                    "hidden": false,
                    "children": [],
                ],
            ],
        ]

        let value = try TKJSONValue.fromJSONObject(object)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(TKJSONValue.self, from: data)

        #expect(decoded == value)
    }

    @Test("export archive carries target hierarchy and observation payloads")
    func archiveShape() throws {
        let target = TKTargetSummary(
            connected: true,
            latestHierarchyAvailable: true,
            appName: "TritonKitDemo",
            bundleIdentifier: "com.neptunekit.tritonkit.demo"
        )
        let geometry = TKGeometryResponse(
            bounds: TKRect(x: 0, y: 0, width: 402, height: 874),
            safeArea: TKInsets(top: 62, left: 0, bottom: 34, right: 0),
            scale: 3,
            orientation: "portrait"
        )
        let screenshot = TKScreenshotResponse(
            format: "png",
            width: 402,
            height: 874,
            scale: 1,
            dataBase64: Data("png".utf8).base64EncodedString()
        )
        let archive = TKExportArchive(
            exportedAt: "2026-05-16T00:00:00Z",
            target: target,
            hierarchy: .object(["displayItems": .array([])]),
            geometry: geometry,
            accessibility: [],
            screenshot: screenshot
        )

        let data = try JSONEncoder().encode(archive)
        let decoded = try JSONDecoder().decode(TKExportArchive.self, from: data)

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.target.id == TKLocalTargetID)
        #expect(decoded.geometry?.bounds.width == 402)
        #expect(decoded.screenshot?.dataRef == nil)
        #expect(decoded.screenshot?.dataBase64 == screenshot.dataBase64)
    }
}
