import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

extension TKUIKitWindowTests {
@MainActor
@Suite(.serialized)
struct TKSearchBarInputFocusTests {
    /// Models a composite control forwarding its child's focus state.
    final class FocusForwardingContainer: UIView {
        let textField = UITextField(frame: CGRect(x: 0, y: 0, width: 220, height: 44))
        override var isFirstResponder: Bool { textField.isFirstResponder }
        override init(frame: CGRect) {
            super.init(frame: frame)
            addSubview(textField)
        }
        required init?(coder: NSCoder) { fatalError("not used") }
    }

    @Test("focused child takes priority over a composite control forwarding focus")
    func forwardedFocusResolvesChild() throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let container = FocusForwardingContainer(frame: CGRect(x: 20, y: 70, width: 240, height: 44))
        window.addSubview(container)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        #expect(container.textField.becomeFirstResponder())
        #expect(container.isFirstResponder)
        #expect(findFirstResponder(in: container) === container.textField)
        let resolved = resolveTextInputResponder(TKInputRequest(type: .typeText, text: "sample", secure: true))
        #expect(resolved.responder === container.textField)
    }

    @Test("tap then unqualified type inserts into the actual UISearchBar text field")
    func searchFieldTapThenType() async throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        let searchBar = UISearchBar(frame: CGRect(x: 20, y: 80, width: 350, height: 56))
        window.addSubview(searchBar)
        window.makeKeyAndVisible()
        searchBar.layoutIfNeeded()
        defer { window.isHidden = true }
        let field = searchBar.searchTextField
        let center = field.convert(CGPoint(x: field.bounds.midX, y: field.bounds.midY), to: window)
        let tap = performTap(.tap(x: Double(center.x), y: Double(center.y)))
        #expect(tap.ok)
        #expect(field.isFirstResponder)
        #expect(findFirstResponder(in: searchBar) === field)
        let typed = await performInput(TKInputRequest(type: .typeText, text: "sample", secure: true))
        #expect(typed.ok)
        #expect(typed.targetOID == TKObjectRegistry.shared.register(field))
        #expect(field.text == "sample")
        #expect(typed.insertedLength == 6)
    }

    @Test("an unfocused search field cannot steal unqualified input from another editor")
    func unfocusedSearchFieldIsNotSelected() async throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        let searchBar = UISearchBar(frame: CGRect(x: 20, y: 80, width: 350, height: 56))
        let editor = UITextField(frame: CGRect(x: 20, y: 160, width: 300, height: 44))
        window.addSubview(searchBar)
        window.addSubview(editor)
        window.makeKeyAndVisible()
        searchBar.layoutIfNeeded()
        defer { window.isHidden = true }
        #expect(findFirstResponder(in: searchBar) == nil)
        #expect(editor.becomeFirstResponder())
        let typed = await performInput(TKInputRequest(type: .typeText, text: "other", secure: true))
        #expect(typed.ok)
        #expect(editor.text == "other")
        #expect(searchBar.text?.isEmpty != false)
        #expect(!searchBar.searchTextField.isFirstResponder)
        #expect(editor.resignFirstResponder())
        #expect(resolveTextInputResponder(.typeText("no-focus")).responder == nil)
    }
}
}
#endif
