import CoreGraphics
import Foundation
import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

@MainActor
@Suite
struct TKNodePropertyPatchTests {
    @Test("modifyAttribute patch writes UIView and CALayer properties")
    func modifyAttributePatchWritesViewAndLayerProperties() async throws {
        let view = UILabel(frame: CGRect(x: 10, y: 20, width: 120, height: 44))
        view.text = "Before"
        view.accessibilityIdentifier = "old-id"
        let oid = TKObjectRegistry.shared.register(view.layer)
        let request = TKNodePropertyPatchRequest(
            oid: oid,
            changes: TKNodePropertyChanges(
                frame: TKNodeFramePropertyChanges(x: 12, y: 22, width: 130, height: 50),
                view: TKNodeViewPropertyChanges(
                    isHidden: true,
                    alpha: 0.4,
                    isUserInteractionEnabled: true,
                    accessibilityIdentifier: "new-id",
                    accessibilityLabel: "New Label"
                ),
                layer: TKNodeLayerPropertyChanges(
                    isHidden: true,
                    masksToBounds: true,
                    opacity: 0.6,
                    cornerRadius: 8,
                    zPosition: 3
                ),
                style: TKNodeStylePropertyChanges(text: "After")
            )
        )
        let payload = try JSONEncoder().encode(request)
        let message = TKMessage(id: 1, type: .modifyAttribute, payload: payload)

        let response = try #require(await TritonKitRequestHandler().handleModifyAttribute(message))
        let responsePayload = try #require(response.payload)
        let result = try JSONDecoder().decode(TKNodePropertyPatchResponse.self, from: responsePayload)

        #expect(result.ok)
        #expect(result.applied.contains("frame.x"))
        #expect(result.applied.contains("view.accessibilityLabel"))
        #expect(result.applied.contains("layer.cornerRadius"))
        #expect(result.applied.contains("style.text"))
        #expect(view.frame == CGRect(x: 12, y: 22, width: 130, height: 50))
        #expect(view.isHidden)
        // Patches apply view fields before layer fields. UIView alpha and its
        // backing layer opacity are coupled; the later Float opacity wins.
        #expect(view.alpha == CGFloat(Float(0.6)))
        #expect(view.isUserInteractionEnabled)
        #expect(view.accessibilityIdentifier == "new-id")
        #expect(view.accessibilityLabel == "New Label")
        #expect(view.layer.isHidden)
        #expect(view.layer.masksToBounds)
        #expect(view.layer.opacity == 0.6)
        #expect(view.layer.cornerRadius == 8)
        #expect(view.layer.zPosition == 3)
        #expect(view.text == "After")
        let viewAlphaIndex = try #require(result.applied.firstIndex(of: "view.alpha"))
        let layerOpacityIndex = try #require(result.applied.firstIndex(of: "layer.opacity"))
        #expect(viewAlphaIndex < layerOpacityIndex)
    }

    @Test("view alpha patch alone updates UIKit's backing layer opacity")
    func viewAlphaPatchUpdatesBackingLayerOpacity() async throws {
        let view = UIView()
        let result = try await patch(view, changes: .init(view: .init(alpha: 0.5)))

        #expect(result.ok)
        #expect(result.applied == ["view.alpha"])
        #expect(result.skipped.isEmpty)
        #expect(view.alpha == 0.5)
        #expect(view.layer.opacity == 0.5)
    }

    @Test("layer opacity patch alone updates the hosting UIView alpha")
    func layerOpacityPatchUpdatesHostingViewAlpha() async throws {
        let view = UIView()
        let result = try await patch(view.layer, changes: .init(layer: .init(opacity: 0.25)))

        #expect(result.ok)
        #expect(result.applied == ["layer.opacity"])
        #expect(result.skipped.isEmpty)
        #expect(view.layer.opacity == 0.25)
        #expect(view.alpha == 0.25)
    }

    private func patch(_ object: AnyObject, changes: TKNodePropertyChanges) async throws -> TKNodePropertyPatchResponse {
        let request = TKNodePropertyPatchRequest(oid: TKObjectRegistry.shared.register(object), changes: changes)
        let message = TKMessage(id: 1, type: .modifyAttribute, payload: try JSONEncoder().encode(request))
        let response = try #require(await TritonKitRequestHandler().handleModifyAttribute(message))
        let payload = try #require(response.payload)
        return try JSONDecoder().decode(TKNodePropertyPatchResponse.self, from: payload)
    }
}
#endif
