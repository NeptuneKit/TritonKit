import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

@MainActor
@Suite
struct TKAXUIKitTextTests {
    @Test("AX export expands visible collection view text through deep UIKit wrappers")
    func collectionViewTextIsDiscoverable() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 100, width: 390, height: 500), collectionViewLayout: layout)
        collectionView.accessibilityIdentifier = "ProfileCollection"
        window.addSubview(collectionView)

        let imageView = UIImageView(frame: CGRect(x: 12, y: 12, width: 40, height: 40))
        collectionView.addSubview(imageView)

        let cell = UICollectionViewCell(frame: CGRect(x: 0, y: 0, width: 390, height: 96))
        collectionView.addSubview(cell)

        var parent: UIView = cell.contentView
        for _ in 0..<14 {
            let wrapper = UIView(frame: parent.bounds)
            parent.addSubview(wrapper)
            parent = wrapper
        }

        let label = UILabel(frame: CGRect(x: 24, y: 24, width: 160, height: 24))
        label.text = "创作中心"
        parent.addSubview(label)

        var context = AXBuildContext(maxNodes: 40, maxDepth: 32)
        let root = buildAXWindowNode(for: window, context: &context)
        let flattened = TKFlattenAXNodes([root]).map(\.node)

        let collectionNode = flattened.first { $0.identifier == "ProfileCollection" }
        #expect(collectionNode?.children.isEmpty == false)
        #expect(flattened.contains { $0.label == "创作中心" })
        #expect(!flattened.contains { $0.className == NSStringFromClass(UIImageView.self) && $0.label == nil && $0.identifier == nil })
    }
}
#endif
