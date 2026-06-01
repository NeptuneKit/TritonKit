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

    final class TapRecorder: NSObject {
        var tapCount = 0

        @objc func didTap(_ sender: Any) {
            tapCount += 1
        }
    }

    final class TableDataSource: NSObject, UITableViewDataSource {
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            1
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "内科医生"
            return cell
        }
    }

    final class TableDelegate: NSObject, UITableViewDelegate {
        var selectedIndexPath: IndexPath?

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            selectedIndexPath = indexPath
        }
    }

    final class CollectionCell: UICollectionViewCell {
        let label = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            label.frame = CGRect(x: 16, y: 12, width: 160, height: 24)
            label.text = "查看不合适原因"
            contentView.addSubview(label)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    final class CollectionDataSource: NSObject, UICollectionViewDataSource {
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            1
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        }
    }

    final class CollectionDelegate: NSObject, UICollectionViewDelegate {
        var selectedIndexPath: IndexPath?

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            selectedIndexPath = indexPath
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

    @Test("smart tap activates parent UIControl for matched label nodes")
    func smartTapActivatesParentControlForLabel() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let control = UIControl(frame: CGRect(x: 24, y: 100, width: 240, height: 56))
        let label = UILabel(frame: CGRect(x: 12, y: 14, width: 160, height: 24))
        label.text = "查看不合适原因"
        control.addSubview(label)
        window.addSubview(control)
        let recorder = TapRecorder()
        control.addTarget(recorder, action: #selector(TapRecorder.didTap(_:)), for: .touchUpInside)

        let labelOID = TKObjectRegistry.shared.register(label)
        let controlOID = TKObjectRegistry.shared.register(control)
        let request = TKInputRequest.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .smart
        )
        let result = try await performInputRequest(request)

        #expect(result.ok)
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == controlOID)
        #expect(result.targetOID == controlOID)
        #expect(result.activationClassName == NSStringFromClass(UIControl.self))
        #expect(result.strategy == "ancestor-control-action")
        #expect(recorder.tapCount == 1)
    }

    @Test("smart tap selects table view cell ancestor for matched label nodes")
    func smartTapSelectsTableViewCellAncestorForLabel() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let tableView = UITableView(frame: CGRect(x: 0, y: 80, width: 390, height: 240))
        let dataSource = TableDataSource()
        let delegate = TableDelegate()
        tableView.dataSource = dataSource
        tableView.delegate = delegate
        window.addSubview(tableView)
        tableView.reloadData()
        tableView.layoutIfNeeded()

        let indexPath = IndexPath(row: 0, section: 0)
        let cell = try #require(tableView.cellForRow(at: indexPath))
        let label = try #require(cell.textLabel)
        let labelOID = TKObjectRegistry.shared.register(label)
        let cellOID = TKObjectRegistry.shared.register(cell)
        let request = TKInputRequest.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .smart
        )
        let result = try await performInputRequest(request)

        #expect(result.ok)
        #expect(delegate.selectedIndexPath == indexPath)
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == cellOID)
        #expect(result.targetOID == cellOID)
        #expect(result.activationClassName == NSStringFromClass(UITableViewCell.self))
        #expect(result.strategy == "ancestor-table-cell-selection")
    }

    @Test("smart tap selects collection view cell ancestor for matched label nodes")
    func smartTapSelectsCollectionViewCellAncestorForLabel() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 300, height: 60)
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 80, width: 390, height: 240), collectionViewLayout: layout)
        let dataSource = CollectionDataSource()
        let delegate = CollectionDelegate()
        collectionView.register(CollectionCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = dataSource
        collectionView.delegate = delegate
        window.addSubview(collectionView)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        let indexPath = IndexPath(item: 0, section: 0)
        let cell = try #require(collectionView.cellForItem(at: indexPath) as? CollectionCell)
        let labelOID = TKObjectRegistry.shared.register(cell.label)
        let cellOID = TKObjectRegistry.shared.register(cell)
        let request = TKInputRequest.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .smart
        )
        let result = try await performInputRequest(request)

        #expect(result.ok)
        #expect(delegate.selectedIndexPath == indexPath)
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == cellOID)
        #expect(result.targetOID == cellOID)
        #expect(result.activationClassName == NSStringFromClass(CollectionCell.self))
        #expect(result.strategy == "ancestor-collection-cell-selection")
    }

    @Test("smart tap reports gesture parent activation as an actionable unsupported strategy")
    func smartTapReportsGestureParentUnsupported() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let wrapper = UIView(frame: CGRect(x: 20, y: 120, width: 260, height: 72))
        let label = UILabel(frame: CGRect(x: 16, y: 20, width: 180, height: 24))
        label.text = "查看不合适原因"
        wrapper.addSubview(label)
        wrapper.addGestureRecognizer(UITapGestureRecognizer(target: TapRecorder(), action: #selector(TapRecorder.didTap(_:))))
        window.addSubview(wrapper)

        let labelOID = TKObjectRegistry.shared.register(label)
        let wrapperOID = TKObjectRegistry.shared.register(wrapper)
        let request = TKInputRequest.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .smart
        )
        let result = try await performInputRequest(request)

        #expect(!result.ok)
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == wrapperOID)
        #expect(result.targetOID == wrapperOID)
        #expect(result.activationClassName == NSStringFromClass(UIView.self))
        #expect(result.strategy == "ancestor-gesture-coordinate-unsupported")
        #expect(result.message?.contains("tap gesture") == true)
    }

    @Test("exact tap preserves matched metadata and exact strategy")
    func exactTapPreservesMatchedMetadataAndExactStrategy() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let control = UIControl(frame: CGRect(x: 24, y: 100, width: 240, height: 56))
        let label = UILabel(frame: CGRect(x: 12, y: 14, width: 160, height: 24))
        label.text = "查看不合适原因"
        control.addSubview(label)
        window.addSubview(control)
        let recorder = TapRecorder()
        control.addTarget(recorder, action: #selector(TapRecorder.didTap(_:)), for: .touchUpInside)

        let labelOID = TKObjectRegistry.shared.register(label)
        let controlOID = TKObjectRegistry.shared.register(control)
        let request = TKInputRequest.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .exact
        )
        let result = try await performInputRequest(request)

        #expect(result.ok)
        #expect(result.matchedOID == labelOID)
        #expect(result.matchedClassName == NSStringFromClass(UILabel.self))
        #expect(result.activationOID == controlOID)
        #expect(result.targetOID == controlOID)
        #expect(result.strategy == "exact")
        #expect(recorder.tapCount == 1)
    }

    private func performInputRequest(_ request: TKInputRequest) async throws -> TKInputResult {
        let message = TKMessage(id: 1, type: .input, payload: try JSONEncoder().encode(request))
        let response = await TritonKitRequestHandler().tritonKit(TritonKit.shared, didReceiveMessage: message)
        let payload = try #require(response?.payload)
        return try JSONDecoder().decode(TKInputResult.self, from: payload)
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
