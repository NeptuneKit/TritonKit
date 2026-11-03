import CoreGraphics
import Foundation
import ImageIO
import Testing
import TritonKit
@testable import TritonKitCLI

struct HierarchyInlineImageTests {
    @Test func failedUploadsRetainDistinctInlineImages() throws {
        let png = try fixturePNG()
        var item = fixtureItem()
        item.soloScreenshot = png
        item.groupScreenshot = png
        let node = try #require(makeLegacyIosHierarchyScene(target: "fixture", displayItems: [item]).nodes.first)
        let url = "data:image/png;base64," + png.base64EncodedString()
        #expect(node.slice?.available == true)
        #expect(node.slice?.mode == "solo-screenshot-inline")
        #expect(node.slice?.source == "triton-runtime-inline-png")
        #expect(node.slice?.dataRef == nil)
        #expect(node.slice?.dataUrl == url)
        #expect(node.visualSources?.first { $0.kind == "layerOwnContents" }?.dataUrl == url)
        #expect(node.visualSources?.first { $0.kind == "subtreeSnapshot" }?.dataUrl == url)
        #expect(node.visualSources?.first { $0.kind == "subtreeSnapshot" }?.capturedBy == "CALayer.render")
    }

    @Test func soloInlineRemainsPreferredWhenGroupUploadSucceeded() throws {
        var item = fixtureItem()
        item.soloScreenshot = try fixturePNG()
        item.groupScreenshotRef = "group-ref"
        item.screenshotRef = "group-ref"
        let node = try #require(makeLegacyIosHierarchyScene(target: "fixture", displayItems: [item]).nodes.first)
        #expect(node.slice?.mode == "solo-screenshot-inline")
        #expect(node.visualSources?.count == 2)
        #expect(node.visualSources?.first { $0.kind == "subtreeSnapshot" }?.dataRef == "group-ref")
    }

    @Test func referencesWinOverDuplicateInlineBytes() throws {
        var item = fixtureItem()
        item.soloScreenshotRef = "solo-ref"
        item.groupScreenshotRef = "group-ref"
        item.soloScreenshot = Data("invalid duplicate".utf8)
        item.groupScreenshot = try fixturePNG()
        let node = try #require(makeLegacyIosHierarchyScene(target: "fixture", displayItems: [item]).nodes.first)
        #expect(node.slice?.mode == "solo-screenshot-ref")
        #expect(node.slice?.dataRef == "solo-ref")
        #expect(node.visualSources?.allSatisfy { $0.dataUrl == nil } == true)
    }

    @Test func groupInlineNeverBecomesOwnContents() throws {
        var item = fixtureItem()
        item.groupScreenshot = try fixturePNG()
        let node = try #require(makeLegacyIosHierarchyScene(target: "fixture", displayItems: [item]).nodes.first)
        #expect(node.slice?.mode == "group-screenshot-inline")
        #expect(node.visualSources?.count == 1)
        #expect(node.visualSources?.first?.kind == "subtreeSnapshot")
        #expect(node.visualSources?.first?.dataUrl?.hasPrefix("data:image/png;base64,") == true)
    }

    @Test func invalidAndOversizedImagesDoNotClaimAvailablePixels() throws {
        let png = try fixturePNG()
        let tooManyPixels = try fixturePNG(width: 1025, height: 1025)
        let tooManyBytes = png + Data(repeating: 0, count: 4 * 1024 * 1024)
        let missingPixels = Data(png.prefix(33)) + Data(png.suffix(12))
        for bytes in [Data(), Data("not a PNG".utf8), Data(png.dropLast(12)), missingPixels, tooManyPixels, tooManyBytes] {
            var item = fixtureItem()
            item.soloScreenshot = bytes
            item.groupScreenshot = bytes
            let node = try #require(makeLegacyIosHierarchyScene(target: "fixture", displayItems: [item]).nodes.first)
            #expect(node.slice?.available == false)
            #expect(node.visualSources?.map(\.kind) == ["styledFallback"])
            #expect(node.visualSources?.first?.dataUrl == nil)
        }
    }

    private func fixtureItem() -> TKDisplayItem {
        TKDisplayItem(frame: CGRect(x: 0, y: 0, width: 20, height: 20),
            layerObject: .init(oid: 7, memoryAddress: "0x7", classChainList: ["CALayer"]))
    }

    private func fixturePNG(width: Int = 2, height: Int = 2) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
