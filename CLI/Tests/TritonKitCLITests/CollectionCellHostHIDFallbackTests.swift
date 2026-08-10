import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct CollectionCellHostHIDFallbackTests {
    @Test("collection-cell fallback is opt-in and only recognizes the embedded unsupported result")
    func fallbackRecognitionIsFailClosed() {
        let unsupported = TKInputResult.unsupported(
            action: "tap",
            message: "UICollectionViewCell selection is not a safe public embedded-runtime activation",
            strategy: collectionCellEmbeddedUnsupportedStrategy,
            error: TKCLIErrorDetail(code: "unsupported_capability", message: "unsupported")
        )
        let otherStrategy = TKInputResult.unsupported(
            action: "tap",
            message: "unsupported",
            strategy: "tap-gesture-recognizer",
            error: TKCLIErrorDetail(code: "unsupported_capability", message: "unsupported")
        )
        let otherCode = TKInputResult.unsupported(
            action: "tap",
            message: "unsupported",
            strategy: collectionCellEmbeddedUnsupportedStrategy,
            error: TKCLIErrorDetail(code: "request_failed", message: "failed")
        )

        #expect(isUnsupportedCollectionCellResult(unsupported))
        #expect(!isUnsupportedCollectionCellResult(otherStrategy))
        #expect(!isUnsupportedCollectionCellResult(otherCode))
    }

    @Test("fallback helper does not bypass a non-collection embedded result")
    func fallbackHelperPreservesNonCollectionResult() {
        let embedded = TKInputResult.failure(
            action: "tap",
            message: "request failed",
            strategy: "coordinate",
            error: TKCLIErrorDetail(code: "request_failed", message: "failed")
        )
        var invocationCount = 0
        let result = collectionCellHostHIDFallbackResult(
            embeddedResult: embedded,
            resolution: makeResolution(frame: TKRect(x: 40, y: 100, width: 200, height: 80)),
            runtimeTarget: makeRuntimeTarget(),
            screenGeometry: nil,
            hostInput: { _, _ in
                invocationCount += 1
                return .success(action: "tap")
            }
        )

        #expect(result == embedded)
        #expect(invocationCount == 0)
    }

    @Test("fallback request uses matched center and fresh screen geometry")
    func fallbackRequestUsesMatchedCenterAndScreenGeometry() throws {
        let resolution = makeResolution(frame: TKRect(x: 40, y: 100, width: 200, height: 80))
        let geometry = TKGeometryResponse(
            bounds: TKRect(x: 0, y: 0, width: 390, height: 844),
            safeArea: TKInsets(top: 0, left: 0, bottom: 0, right: 0),
            scale: 3,
            orientation: "portrait"
        )

        let request = try collectionCellHostHIDTapRequest(resolution: resolution, screenGeometry: geometry).get()
        #expect(request.type == .tap)
        #expect(request.x == 140)
        #expect(request.y == 140)
        #expect(request.width == 390)
        #expect(request.height == 844)
        #expect(request.targetOID == 42)
        #expect(request.matchedOID == 42)
        #expect(request.activationStrategy == .exact)
    }

    @Test("AX resolution preserves source, matched node, frame, and one-match evidence")
    func axResolutionPreservesEvidence() {
        let node = TKAXNode(
            role: "cell",
            label: "Cell title",
            value: nil,
            identifier: "cell-1",
            title: nil,
            frame: TKRect(x: 40, y: 100, width: 200, height: 80),
            enabled: true,
            focused: false,
            hidden: false,
            targetOID: 42,
            viewOID: 42,
            layerOID: 7,
            className: "UICollectionViewCell",
            children: []
        )
        let request = TKInputRequest.tap(
            targetOID: 42,
            matchedOID: 42,
            matchedClassName: "UICollectionViewCell",
            activationStrategy: .exact
        )
        let resolution = collectionCellHostHIDAXResolution(
            node: node,
            query: "Cell title",
            request: request,
            activationStrategy: .exact
        )

        #expect(resolution.source == "ax")
        #expect(resolution.matchCount == 1)
        #expect(resolution.candidates == nil)
        #expect(resolution.viewOID == 42)
        #expect(resolution.layerOID == 7)
        #expect(resolution.frame == node.frame)
    }

    @Test("opt-in fallback returns host-hid source, strategy, matched geometry, and verification boundary")
    func fallbackSuccessIsAuditable() throws {
        let frame = TKRect(x: 40, y: 100, width: 200, height: 80)
        let resolution = makeResolution(frame: frame)
        let embedded = TKInputResult.unsupported(
            action: "tap",
            message: "UICollectionViewCell selection is not a safe public embedded-runtime activation",
            strategy: collectionCellEmbeddedUnsupportedStrategy,
            matchedOID: 42,
            matchedClassName: "UILabel",
            activationOID: 42,
            activationClassName: "UICollectionViewCell",
            error: TKCLIErrorDetail(code: "unsupported_capability", message: "unsupported")
        )
        let runtimeTarget = makeRuntimeTarget()
        let geometry = TKGeometryResponse(
            bounds: TKRect(x: 0, y: 0, width: 390, height: 844),
            safeArea: TKInsets(top: 0, left: 0, bottom: 0, right: 0),
            scale: 3,
            orientation: "portrait"
        )
        var capturedID: String?
        var capturedInput: TKInputRequest?

        let result = collectionCellHostHIDFallbackResult(
            embeddedResult: embedded,
            resolution: resolution,
            runtimeTarget: runtimeTarget,
            screenGeometry: geometry,
            hostInput: { id, input in
                capturedID = id
                capturedInput = input
                return .success(
                    action: "tap",
                    message: "submitted",
                    strategy: collectionCellHostHIDStrategy,
                    source: "host-hid",
                    sourceCommands: ["baguette tap --udid SIM-1 --x 140 --y 140 --width 390 --height 844"]
                )
            }
        )

        #expect(result.ok)
        #expect(result.strategy == collectionCellHostHIDStrategy)
        #expect(result.source == "host-hid")
        #expect(result.fallbackFromStrategy == collectionCellEmbeddedUnsupportedStrategy)
        #expect(result.matchedOID == 42)
        #expect(result.matchedClassName == "UILabel")
        #expect(result.geometry == frame)
        #expect(result.verification?.required == true)
        #expect(result.verification?.status == "not-verified")
        #expect(result.sourceCommands?.count == 1)
        #expect(capturedID == "host:ios:SIM-1")
        #expect(capturedInput?.x == 140)
        #expect(capturedInput?.y == 140)
        #expect(capturedInput?.width == 390)
        #expect(capturedInput?.height == 844)
    }

    @Test("fallback rejects real-device and non-iOS targets without invoking host input")
    func fallbackRejectsOutOfScopeTargets() {
        let resolution = makeResolution(frame: TKRect(x: 40, y: 100, width: 200, height: 80))
        let embedded = TKInputResult.unsupported(
            action: "tap",
            message: "unsupported",
            strategy: collectionCellEmbeddedUnsupportedStrategy,
            error: TKCLIErrorDetail(code: "unsupported_capability", message: "unsupported")
        )
        var invocationCount = 0
        let result = collectionCellHostHIDFallbackResult(
            embeddedResult: embedded,
            resolution: resolution,
            runtimeTarget: TKTargetSummary(
                id: "triton:connection:real",
                connected: true,
                latestHierarchyAvailable: true,
                simulatorUDID: nil,
                platform: "ios"
            ),
            screenGeometry: TKGeometryResponse(
                bounds: TKRect(x: 0, y: 0, width: 390, height: 844),
                safeArea: TKInsets(top: 0, left: 0, bottom: 0, right: 0),
                scale: 3,
                orientation: "portrait"
            ),
            hostInput: { _, _ in
                invocationCount += 1
                return .success(action: "tap")
            }
        )

        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_scope")
        #expect(result.source == "embedded")
        #expect(invocationCount == 0)
    }

    @Test("fallback fails closed when runtime geometry is unavailable")
    func fallbackRequiresGeometry() {
        let embedded = TKInputResult.unsupported(
            action: "tap",
            message: "unsupported",
            strategy: collectionCellEmbeddedUnsupportedStrategy,
            error: TKCLIErrorDetail(code: "unsupported_capability", message: "unsupported")
        )
        var invocationCount = 0
        let result = collectionCellHostHIDFallbackResult(
            embeddedResult: embedded,
            resolution: makeResolution(frame: TKRect(x: 40, y: 100, width: 200, height: 80)),
            runtimeTarget: makeRuntimeTarget(),
            screenGeometry: nil,
            hostInput: { _, _ in
                invocationCount += 1
                return .success(action: "tap")
            }
        )

        #expect(!result.ok)
        #expect(result.error?.code == "geometry_required")
        #expect(result.source == "embedded")
        #expect(result.fallbackFromStrategy == collectionCellEmbeddedUnsupportedStrategy)
        #expect(invocationCount == 0)
    }

    @Test("act tap schema exposes explicit host HID fallback and verification fields")
    func schemaExposesOptInFallback() throws {
        let schema = try #require(commandSchemaMap()["act"])
        let tap = try #require(schema.subcommands.first { $0.name == "tap" })
        #expect(tap.optionalOptions.contains("--allow-host-hid-fallback"))
        let output = try #require(schema.outputContracts.first { $0.selector == "input.result" })
        let fields = Set(output.fields.map(\.name))
        #expect(fields.contains("source"))
        #expect(fields.contains("geometry"))
        #expect(fields.contains("fallbackFromStrategy"))
        #expect(fields.contains("verification"))
        #expect(fields.contains("sourceCommands"))
    }

    private func makeResolution(frame: TKRect) -> TapTargetResolution {
        let request = TKInputRequest.tap(
            targetOID: 42,
            matchedOID: 42,
            matchedClassName: "UILabel",
            activationStrategy: .exact
        )
        let candidate = TapTargetCandidate(
            index: 1,
            query: "Cell title",
            source: "ax",
            strategy: "exact",
            role: "text",
            label: "Cell title",
            value: nil,
            identifier: nil,
            className: "UILabel",
            viewOID: 42,
            targetOID: 42,
            layerOID: 7,
            frame: frame,
            request: request
        )
        return TapTargetResolution(selected: candidate, candidates: [candidate], includeCandidates: false)
    }

    private func makeRuntimeTarget() -> TKTargetSummary {
        TKTargetSummary(
            id: "triton:ios-simulator:SIM-1",
            connected: true,
            latestHierarchyAvailable: true,
            simulatorUDID: "SIM-1",
            platform: "ios"
        )
    }
}
