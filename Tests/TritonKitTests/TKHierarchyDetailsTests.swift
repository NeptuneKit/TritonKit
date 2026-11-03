import Foundation
import Testing
@testable import TritonKit
import TritonKitShared

@Suite("Hierarchy details contract")
struct TKHierarchyDetailsTests {
    @Test("request defaults and boundaries are explicit")
    func requestDefaultsAndBoundaries() throws {
        let decoded = try JSONDecoder().decode(TKHierarchyDetailsRequest.self, from: Data(#"{"oids":[1]}"#.utf8))
        #expect(decoded == .init(oids: [1]))
        #expect(decoded.validationError == nil)
        for request in [
            TKHierarchyDetailsRequest(oids: []), .init(oids: [0]), .init(oids: [1, 1]),
            .init(oids: Array(1...9)), .init(oids: [1], maxPixelCount: 0),
            .init(oids: [1], maxPixelCount: TKHierarchyDetailsRequest.maximumPixelCount + 1)
        ] {
            #expect(request.validationError != nil)
        }
    }

    @Test("malformed detail request fails explicitly rather than returning an empty success")
    func malformedRequestFails() async throws {
        let handler = TritonKitRequestHandler()
        let message = TKMessage(id: 501, type: .hierarchyDetails, payload: Data(#"{"oids":[]}"#.utf8))
        let response = try #require(await handler.handleLegacyInspection(message))
        let result = try JSONDecoder().decode(TKHierarchyDetailsResponse.self, from: #require(response.payload))
        #expect(!result.ok)
        #expect(!result.partial)
        #expect(result.error?.code == "validation_failed")
        #expect(result.details.isEmpty)
    }

    #if !canImport(UIKit)
    @Test("unsupported runtime does not report a successful empty capture")
    func unsupportedRuntimeFails() async throws {
        let message = TKMessage(id: 502, type: .hierarchyDetails,
                                payload: try JSONEncoder().encode(TKHierarchyDetailsRequest(oids: [1])))
        let response = try #require(await TritonKitRequestHandler().handleLegacyInspection(message))
        let result = try JSONDecoder().decode(TKHierarchyDetailsResponse.self, from: #require(response.payload))
        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_platform" || result.error?.code == "runtime_disabled")
    }
    #endif
}

#if canImport(UIKit)
import UIKit

extension TKUIKitWindowTests {
    @MainActor
    @Suite("Lookin core UIKit capture")
    struct HierarchyCore {
        @Test("hierarchy retains naked layers and their descendants")
        func nakedLayerTree() async throws {
            let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 300))
            defer { window.isHidden = true }
            let root = try #require(window.rootViewController?.view)
            let bare = CALayer()
            bare.frame = CGRect(x: 17, y: 23, width: 70, height: 80)
            root.layer.addSublayer(bare)
            let nested = CALayer()
            nested.frame = CGRect(x: 5, y: 7, width: 20, height: 25)
            bare.addSublayer(nested)
            let bareOID = TKObjectRegistry.shared.register(bare)
            let nestedOID = TKObjectRegistry.shared.register(nested)
            let items = TKDisplayItem.flatItems(from: await TKHierarchyBuilder.buildHierarchy())
            let parent = try #require(items.first { $0.layerObject?.oid == bareOID })
            let child = try #require(parent.subitems.first { $0.layerObject?.oid == nestedOID })
            #expect(parent.viewObject == nil)
            #expect(parent.layerObject?.classChainList.first == "CALayer")
            #expect(child.frame.origin == CGPoint(x: 22, y: 30))
        }

        @Test("solo excludes descendants and restores visible and hidden child state")
        func soloAndGroupPixels() async throws {
            let parent = CALayer()
            parent.bounds = CGRect(x: 10, y: 20, width: 40, height: 40)
            parent.backgroundColor = UIColor.red.cgColor
            let child = CALayer()
            child.frame = CGRect(x: 10, y: 20, width: 20, height: 20)
            child.backgroundColor = UIColor.blue.cgColor
            let hidden = CALayer()
            hidden.frame = parent.bounds
            hidden.backgroundColor = UIColor.green.cgColor
            hidden.isHidden = true
            parent.addSublayer(child)
            parent.addSublayer(hidden)
            let oid = TKObjectRegistry.shared.register(parent)
            let result = try await details(.init(oids: [oid], maxPixelCount: 1_600))
            #expect(result.ok)
            let detail = try #require(result.details.first)
            let soloData = try #require(detail.soloScreenshot)
            let groupData = try #require(detail.groupScreenshot)
            let solo = try #require(UIImage(data: soloData)?.cgImage)
            let group = try #require(UIImage(data: groupData)?.cgImage)
            #expect(solo.width * solo.height <= 1_600)
            #expect(group.width == solo.width && group.height == solo.height)
            #expect(try pixel(solo, x: 5, y: 5) == [255, 0, 0, 255])
            #expect(try pixel(group, x: 5, y: 5) == [0, 0, 255, 255])
            #expect(try pixel(group, x: 30, y: 30) == [255, 0, 0, 255])
            #expect(!child.isHidden && hidden.isHidden)
            #expect(parent.sublayers?.first === child)
            #expect(parent.sublayers?.last === hidden)
            #expect(parent.bounds == CGRect(x: 10, y: 20, width: 40, height: 40))
        }

        @Test("details preserve valid results alongside expired objects")
        func partialAndReleasedObjects() async throws {
            let layer = CALayer()
            layer.frame = CGRect(x: 1, y: 2, width: 12, height: 14)
            layer.cornerRadius = 4
            let oid = TKObjectRegistry.shared.register(layer)
            var staleOID: UInt = 0
            weak var weakLayer: CALayer?
            autoreleasepool {
                let expired = CALayer()
                staleOID = TKObjectRegistry.shared.register(expired)
                weakLayer = expired
            }
            try #require(weakLayer == nil)
            let result = try await details(.init(oids: [oid, staleOID], screenshots: .none))
            #expect(!result.ok && result.partial)
            #expect(result.details.count == 2)
            #expect(result.details[0].failureCode == 0)
            #expect(!result.details[0].attributesGroupList.isEmpty)
            #expect(result.details[1].failureCode != 0)
            #expect(result.details[1].groupScreenshot == nil)
        }

        @Test("small pixel budgets downsample without mutating layer state")
        func downsamplingAndEmptyGeometry() async throws {
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 800, height: 400)
            layer.backgroundColor = UIColor.red.cgColor
            let child = CALayer()
            child.frame = layer.bounds
            layer.addSublayer(child)
            let oid = TKObjectRegistry.shared.register(layer)
            let result = try await details(.init(oids: [oid], screenshots: .solo, maxPixelCount: 100))
            let detail = try #require(result.details.first)
            let screenshotData = try #require(detail.soloScreenshot)
            let image = try #require(UIImage(data: screenshotData)?.cgImage)
            #expect(result.ok)
            #expect(image.width * image.height <= 100)
            #expect((detail.screenshotScale ?? 1) < 1)
            #expect(!child.isHidden)
            #expect(layer.frame.size == CGSize(width: 800, height: 400))
            layer.bounds = .zero
            let empty = try await details(.init(oids: [oid]))
            #expect(!empty.ok)
            #expect(empty.details.first?.failureReason == "screenshot_unavailable")
            #expect(!child.isHidden)
        }

        @Test("bare layer property patch can be read back through details")
        func nakedLayerPatchReadback() async throws {
            let layer = CALayer()
            layer.frame = CGRect(x: 1, y: 2, width: 12, height: 14)
            let oid = TKObjectRegistry.shared.register(layer)
            let patch = TKNodePropertyPatchRequest(oid: oid,
                changes: .init(layer: .init(cornerRadius: 6, zPosition: 3)))
            let message = TKMessage(id: 702, type: .modifyAttribute, payload: try JSONEncoder().encode(patch))
            _ = try #require(await TritonKitRequestHandler().handleModifyAttribute(message))
            let result = try await details(.init(oids: [oid], screenshots: .none))
            let attrs = try #require(result.details.first).attributesGroupList
                .flatMap { $0.attrSections }.flatMap { $0.attributes }
            guard case .number(let radius)? = attrs.first(where: { $0.identifier == "corner_radius" })?.value,
                  case .number(let z)? = attrs.first(where: { $0.identifier == "z_position" })?.value else {
                Issue.record("Layer attributes must contain numeric radius and z position")
                return
            }
            #expect(radius == 6 && z == 3)
            #expect(!attrs.contains { $0.identifier == "user_interaction" })
            #expect(layer.cornerRadius == 6 && layer.zPosition == 3)
        }

        @Test("a naked layer's UIView delegate is not a patchable backing view")
        func nonBackingDelegateDoesNotReceiveViewPatch() async throws {
            let view = UILabel()
            view.text = "Unchanged"
            let layer = CALayer()
            layer.delegate = view
            let oid = TKObjectRegistry.shared.register(layer)
            let patch = TKNodePropertyPatchRequest(oid: oid,
                changes: .init(view: .init(accessibilityLabel: "Wrong view"),
                               layer: .init(cornerRadius: 7), style: .init(text: "Wrong text")))
            let message = TKMessage(id: 703, type: .modifyAttribute, payload: try JSONEncoder().encode(patch))
            let response = try #require(await TritonKitRequestHandler().handleModifyAttribute(message))
            let result = try JSONDecoder().decode(TKNodePropertyPatchResponse.self, from: #require(response.payload))
            #expect(result.applied == ["layer.cornerRadius"])
            #expect(result.skipped.contains("view.accessibilityLabel"))
            #expect(result.skipped.contains("style.text"))
            #expect(view.text == "Unchanged" && view.accessibilityLabel == nil)
            #expect(layer.cornerRadius == 7)
            #expect(layer.tk_hostView == nil)
        }

        @Test("hidden layer screenshot failure preserves usable metadata as partial")
        func hiddenLayerIsPartial() async throws {
            let layer = CALayer()
            layer.frame = CGRect(x: 3, y: 5, width: 40, height: 50)
            layer.isHidden = true
            let oid = TKObjectRegistry.shared.register(layer)
            let result = try await details(.init(oids: [oid], screenshots: .both))
            let detail = try #require(result.details.first)
            #expect(!result.ok && result.partial)
            #expect(result.error?.code == "details_partial")
            #expect(detail.failureReason == "screenshot_unavailable")
            #expect(detail.hiddenValue && detail.boundsValue.size == CGSize(width: 40, height: 50))
            #expect(!detail.attributesGroupList.isEmpty)
            #expect(detail.soloScreenshot == nil && detail.groupScreenshot == nil)
            #expect(layer.isHidden)
        }


        private func details(_ request: TKHierarchyDetailsRequest) async throws -> TKHierarchyDetailsResponse {
            let message = TKMessage(id: 701, type: .hierarchyDetails, payload: try JSONEncoder().encode(request))
            let response = try #require(await TritonKitRequestHandler().handleLegacyInspection(message))
            return try JSONDecoder().decode(TKHierarchyDetailsResponse.self, from: #require(response.payload))
        }

        private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let ok = pixels.withUnsafeMutableBytes { storage -> Bool in
                guard let context = CGContext(data: storage.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
                return true
            }
            try #require(ok)
            let offset = (y * image.width + x) * 4
            return Array(pixels[offset..<(offset + 4)])
        }
    }
}
#if !TRITONKIT_RUNTIME_ENABLED
@MainActor
@Suite("Release layer capture")
struct TKHierarchyCaptureReleaseTests {
    @Test("Release capture helper returns no pixels even when called directly")
    func releaseCaptureHelperIsDisabled() {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 20, height: 20)
        layer.backgroundColor = UIColor.red.cgColor
        let result = TKLayerScreenshotCapture.capture(layer, solo: true, maxPixelCount: 400)
        #expect(result.data == nil && result.pixelCount == 0)
        #expect(result.failureReason == "runtime_disabled")
    }
}
#endif
#endif
