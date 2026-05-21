import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKRuntimeLoopModelsTests {
    @Test("snapshot response aggregates state observation and skipped artifacts")
    func snapshotShape() throws {
        let response = TKRuntimeSnapshotResponse(
            capturedAt: "2026-05-21T12:00:00Z",
            include: ["app", "scene", "route", "ax", "geometry", "screenshot-metadata"],
            app: TKRuntimeAppState(
                bundleIdentifier: "com.example.demo",
                displayName: "Demo",
                version: "1.0",
                build: "42",
                localeIdentifier: "en_US",
                preferredLanguages: ["en-US"],
                preferredContentSizeCategory: "UICTContentSizeCategoryM",
                userInterfaceStyle: "light",
                processUptimeSeconds: 10,
                sceneCount: 1,
                windowCount: 1
            ),
            geometry: TKGeometryResponse(
                bounds: TKRect(x: 0, y: 0, width: 390, height: 844),
                safeArea: TKInsets(top: 59, left: 0, bottom: 34, right: 0),
                scale: 3,
                orientation: "portrait"
            ),
            ax: [
                TKAXNode(
                    role: "button",
                    label: "Submit",
                    value: nil,
                    identifier: "submit",
                    title: nil,
                    frame: TKRect(x: 20, y: 40, width: 120, height: 44),
                    enabled: true,
                    focused: false,
                    hidden: false,
                    targetOID: 7,
                    className: "UIButton",
                    children: []
                ),
            ],
            screenshot: TKRuntimeScreenshotMetadata(format: "png", width: 390, height: 844, scale: 3),
            artifacts: [
                TKRuntimeSnapshotArtifact(name: "app", capturedAt: "2026-05-21T12:00:00Z", freshness: "fresh"),
            ],
            skipped: [
                TKRuntimeSnapshotSkipped(name: "hierarchy", reason: "not requested"),
            ],
            truncation: TKRuntimeSnapshotTruncation(truncated: false)
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRuntimeSnapshotResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.include.contains("ax"))
        #expect(decoded.app?.bundleIdentifier == "com.example.demo")
        #expect(decoded.ax?.first?.label == "Submit")
        #expect(decoded.screenshot?.dataIncluded == false)
        #expect(decoded.skipped.first?.name == "hierarchy")
        #expect(decoded.truncation.truncated == false)
    }

    @Test("semantic action response explains strategy target elapsed and redaction")
    func semanticActionShape() throws {
        let response = TKSemanticActionResponse(
            ok: true,
            action: .setText,
            strategy: "selector-oid",
            targetOID: 11,
            targetClassName: "UITextField",
            elapsedMs: 12,
            message: "Set redacted text",
            redaction: TKSemanticActionRedaction(secure: true, text: "length-only", insertedLength: 8)
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKSemanticActionResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.action == .setText)
        #expect(decoded.strategy == "selector-oid")
        #expect(decoded.targetOID == 11)
        #expect(decoded.redaction?.secure == true)
        #expect(decoded.redaction?.insertedLength == 8)
    }

    @Test("ledger response carries bounded redacted runtime entries")
    func ledgerShape() throws {
        let entry = TKRuntimeLedgerEntry(
            id: 1,
            timestamp: "2026-05-21T12:00:00Z",
            source: "cli",
            requestType: "semanticAction",
            action: "setText",
            ok: false,
            elapsedMs: 20,
            errorCode: "action_not_supported",
            message: "Target is not editable",
            redaction: TKSemanticActionRedaction(secure: true, text: "length-only", insertedLength: 0)
        )
        let response = TKRuntimeLedgerResponse(entries: [entry], limit: 50, maxEntries: 100)

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRuntimeLedgerResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.count == 1)
        #expect(decoded.limit == 50)
        #expect(decoded.entries.first?.errorCode == "action_not_supported")
        #expect(decoded.entries.first?.redaction?.text == "length-only")
    }
}
