import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

@MainActor
@Suite
struct TKAXUIKitTextTests {
    final class CustomEditorView: UIView, UIKeyInput {
        var insertedText = ""

        override var canBecomeFirstResponder: Bool { true }
        var hasText: Bool { !insertedText.isEmpty }

        func insertText(_ text: String) {
            insertedText += text
        }

        func deleteBackward() {
            _ = insertedText.popLast()
        }
    }

    @Test("AX export expands visible collection view text through deep UIKit wrappers")
    func collectionViewTextIsDiscoverable() {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }
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

    @Test("coordinate tap focuses non-control UIKeyInput editor views")
    func coordinateTapFocusesCustomEditorView() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let editor = CustomEditorView(frame: CGRect(x: 40, y: 80, width: 260, height: 120))
        window.addSubview(editor)
        TKObjectRegistry.shared.register(window)

        let request = TKInputRequest.tap(x: 70, y: 135)
        let message = TKMessage(id: 1, type: .input, payload: try JSONEncoder().encode(request))
        let response = await TritonKitRequestHandler().tritonKit(TritonKit.shared, didReceiveMessage: message)
        let payload = try #require(response?.payload)
        let result = try JSONDecoder().decode(TKInputResult.self, from: payload)

        #expect(result.ok)
        #expect(result.targetClassName == NSStringFromClass(CustomEditorView.self))
        #expect(editor.isFirstResponder)
    }

    private func makeVisibleTestWindow() -> UIWindow {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.makeKeyAndVisible()
            return window
        }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()
        return window
    }
}
#endif
