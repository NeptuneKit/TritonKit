import CoreGraphics
import Foundation
import Testing
@testable import TritonKit

@Suite
struct TKDisplayItemTests {
    @Test("flatItems returns depth-first hierarchy order")
    func flatItemsDepthFirst() {
        let leaf = TKDisplayItem(customDisplayTitle: "leaf", indentLevel: 2)
        let child = TKDisplayItem(subitems: [leaf], customDisplayTitle: "child", indentLevel: 1)
        let sibling = TKDisplayItem(customDisplayTitle: "sibling")
        let root = TKDisplayItem(subitems: [child, sibling], customDisplayTitle: "root")

        let titles = TKDisplayItem.flatItems(from: [root]).map(\.customDisplayTitle)

        #expect(titles == ["root", "child", "leaf", "sibling"])
    }

    @Test("display item encoding sanitizes non-finite geometry and layer values")
    func displayItemEncodingSanitizesNonFiniteValues() throws {
        let nan = CGFloat.nan
        let infinity = CGFloat.infinity
        let item = TKDisplayItem(
            alpha: nan,
            frame: CGRect(x: nan, y: infinity, width: 10, height: -infinity),
            bounds: CGRect(x: 0, y: 0, width: nan, height: 20),
            layerPosition: CGPoint(x: nan, y: 12),
            layerAnchorPoint: CGPoint(x: 0.5, y: infinity),
            layerZPosition: nan,
            layerTransform: [1, .nan, .infinity],
            layerSublayerTransform: [-.infinity, 1],
            layerCornerRadius: nan,
            layerOpacity: nan,
            layerContentsScale: infinity,
            layerContentsRect: CGRect(x: nan, y: 0, width: 1, height: infinity),
            layerBorderWidth: nan,
            layerShadowOpacity: nan,
            layerShadowRadius: infinity,
            layerShadowOffset: CGSize(width: nan, height: -infinity)
        )

        _ = try JSONEncoder().encode(item)

        #expect(item.alpha == 0)
        #expect(item.frame.origin.x == 0)
        #expect(item.frame.origin.y == 0)
        #expect(item.frame.size.height == 0)
        #expect(item.layerCornerRadius == 0)
        #expect(item.layerTransform == [1, 0, 0])
    }

    @Test("attribute value encoding sanitizes non-finite numbers")
    func attributeValueEncodingSanitizesNonFiniteNumbers() throws {
        let attributes = [
            TKAttribute(identifier: "number", attrType: 0, value: .number(.nan)),
            TKAttribute(identifier: "array", attrType: 0, value: .numberArray([1, .infinity, -.infinity]))
        ]

        let data = try JSONEncoder().encode(attributes)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("\"value\":0"))
        #expect(json.contains("[1,0,0]"))
    }
}
