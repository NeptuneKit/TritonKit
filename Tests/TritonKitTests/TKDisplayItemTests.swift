import CoreGraphics
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
}
