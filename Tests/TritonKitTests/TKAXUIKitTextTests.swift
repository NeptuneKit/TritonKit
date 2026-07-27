import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

@MainActor
@Suite(.serialized)
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

    final class AccessibleTapGestureSurface: UIView {
        var activationCount = 0

        override func accessibilityActivate() -> Bool {
            activationCount += 1
            return true
        }
    }

    final class TableDataSource: NSObject, UITableViewDataSource {
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            2
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = indexPath.row == 0 ? "内科医生" : "外科医生"
            return cell
        }
    }

    final class TableDelegate: NSObject, UITableViewDelegate {
        var selectedIndexPath: IndexPath?
        var didSelectCount = 0
        var selectionTransform: ((IndexPath) -> IndexPath?)?
        var deniesSelection = false

        func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
            if deniesSelection { return nil }
            return selectionTransform?(indexPath) ?? indexPath
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            selectedIndexPath = indexPath
            didSelectCount += 1
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
        var didSelectCount = 0

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            selectedIndexPath = indexPath
            didSelectCount += 1
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
        _ = TKObjectRegistry.shared.register(window)

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
        await Task.yield()

        #expect(result.ok)
        #expect(delegate.selectedIndexPath == indexPath)
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == cellOID)
        #expect(result.targetOID == cellOID)
        #expect(result.activationClassName == NSStringFromClass(UITableViewCell.self))
        #expect(result.strategy == "ancestor-table-cell-selection")
    }

    @Test("ancestor tap selects table view cell ancestor for matched label nodes")
    func ancestorTapSelectsTableViewCellAncestorForLabel() async throws {
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
            activationStrategy: .ancestor
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

    @Test("table cell helper completes selection and delegate callback before success")
    func tableCellHelperCompletesSelectionAndCallbackBeforeSuccess() throws {
        let window = makeVisibleTestWindow()
        defer { window.isHidden = true }
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
        let result = try #require(performTableCellTap(
            cell,
            request: .tap(targetOID: TKObjectRegistry.shared.register(label)),
            action: "tap",
            matchedView: label
        ))

        #expect(result.ok)
        #expect(tableView.indexPathForSelectedRow == indexPath)
        #expect(delegate.selectedIndexPath == indexPath)
        #expect(delegate.didSelectCount == 1)
        #expect(result.message == "Selected UITableViewCell ancestor and invoked delegate callback")
    }

    @Test("table cell helper honors willSelect redirect")
    func tableCellHelperHonorsWillSelectRedirect() throws {
        let window = makeVisibleTestWindow()
        defer { window.isHidden = true }
        let tableView = UITableView(frame: CGRect(x: 0, y: 80, width: 390, height: 240))
        let dataSource = TableDataSource()
        let delegate = TableDelegate()
        let redirected = IndexPath(row: 1, section: 0)
        delegate.selectionTransform = { _ in redirected }
        tableView.dataSource = dataSource
        tableView.delegate = delegate
        window.addSubview(tableView)
        tableView.reloadData()
        tableView.layoutIfNeeded()

        let original = IndexPath(row: 0, section: 0)
        let cell = try #require(tableView.cellForRow(at: original))
        let result = try #require(performTableCellTap(
            cell,
            request: .tap(targetOID: TKObjectRegistry.shared.register(cell)),
            action: "tap",
            matchedView: cell
        ))

        #expect(result.ok)
        #expect(tableView.indexPathForSelectedRow == redirected)
        #expect(delegate.selectedIndexPath == redirected)
        #expect(delegate.didSelectCount == 1)
    }

    @Test("table cell helper reports willSelect denial without callback")
    func tableCellHelperReportsWillSelectDenial() throws {
        let window = makeVisibleTestWindow()
        defer { window.isHidden = true }
        let tableView = UITableView(frame: CGRect(x: 0, y: 80, width: 390, height: 240))
        let dataSource = TableDataSource()
        let delegate = TableDelegate()
        delegate.deniesSelection = true
        tableView.dataSource = dataSource
        tableView.delegate = delegate
        window.addSubview(tableView)
        tableView.reloadData()
        tableView.layoutIfNeeded()

        let indexPath = IndexPath(row: 0, section: 0)
        let cell = try #require(tableView.cellForRow(at: indexPath))
        let result = try #require(performTableCellTap(
            cell,
            request: .tap(targetOID: TKObjectRegistry.shared.register(cell)),
            action: "tap",
            matchedView: cell
        ))

        #expect(!result.ok)
        #expect(result.strategy == "ancestor-table-cell-selection-denied")
        #expect(tableView.indexPathForSelectedRow == nil)
        #expect(delegate.didSelectCount == 0)
    }

    @Test("coordinate table cell tap completes callback before returning")
    func coordinateTableCellTapCompletesCallbackBeforeReturning() throws {
        let window = makeVisibleTestWindow()
        defer { window.isHidden = true }
        let tableView = UITableView(frame: CGRect(x: 0, y: 80, width: 390, height: 240))
        let dataSource = TableDataSource()
        let delegate = TableDelegate()
        tableView.dataSource = dataSource
        tableView.delegate = delegate
        window.addSubview(tableView)
        tableView.reloadData()
        tableView.layoutIfNeeded()
        window.isHidden = false
        _ = TKObjectRegistry.shared.register(window)

        let indexPath = IndexPath(row: 0, section: 0)
        let cell = try #require(tableView.cellForRow(at: indexPath))
        let frame = cell.convert(cell.bounds, to: nil)
        let result = performTap(.tap(x: Double(frame.midX), y: Double(frame.midY)))

        #expect(result.ok)
        #expect(result.strategy == "ancestor-table-cell-selection")
        #expect(tableView.indexPathForSelectedRow == indexPath)
        #expect(delegate.selectedIndexPath == indexPath)
        #expect(delegate.didSelectCount == 1)
    }

    @Test("smart tap rejects collection view cell ancestor without selecting it")
    func smartTapRejectsCollectionViewCellAncestorForLabel() async throws {
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
        await Task.yield()

        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_capability")
        #expect(delegate.selectedIndexPath == nil)
        #expect(delegate.didSelectCount == 0)
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == cellOID)
        #expect(result.targetOID == cellOID)
        #expect(result.activationClassName == NSStringFromClass(CollectionCell.self))
        #expect(result.strategy == "ancestor-collection-cell-unsupported")
    }

    @Test("ancestor tap rejects collection view cell ancestor without selecting it")
    func ancestorTapRejectsCollectionViewCellAncestorForLabel() async throws {
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
            activationStrategy: .ancestor
        )
        let result = try await performInputRequest(request)
        await Task.yield()

        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_capability")
        #expect(delegate.selectedIndexPath == nil)
        #expect(delegate.didSelectCount == 0)
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == cellOID)
        #expect(result.targetOID == cellOID)
        #expect(result.activationClassName == NSStringFromClass(CollectionCell.self))
        #expect(result.strategy == "ancestor-collection-cell-unsupported")
    }

    @Test("coordinate tap rejects collection view cell without selecting it")
    func coordinateTapRejectsCollectionViewCellContainingPoint() async throws {
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
        let cellFrame = cell.convert(cell.bounds, to: nil)
        let request = TKInputRequest.tap(
            x: Double(cellFrame.midX),
            y: Double(cellFrame.midY)
        )
        let result = try await performInputRequest(request)
        await Task.yield()

        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_capability")
        #expect(delegate.selectedIndexPath == nil)
        #expect(delegate.didSelectCount == 0)
        #expect(result.activationOID == TKObjectRegistry.shared.register(cell))
        #expect(result.activationClassName == NSStringFromClass(CollectionCell.self))
        #expect(result.strategy == "ancestor-collection-cell-unsupported")
    }

    @Test("smart tap keeps a nearer UIControl action inside a collection cell")
    func smartTapKeepsNearerControlActionInsideCollectionCell() async throws {
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
        let control = UIControl(frame: CGRect(x: 180, y: 12, width: 96, height: 28))
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 96, height: 28))
        let recorder = TapRecorder()
        label.text = "Safe control"
        control.addSubview(label)
        control.addTarget(recorder, action: #selector(TapRecorder.didTap(_:)), for: .touchUpInside)
        cell.contentView.addSubview(control)

        let labelOID = TKObjectRegistry.shared.register(label)
        let result = try await performInputRequest(.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .smart
        ))
        await Task.yield()

        #expect(result.ok)
        #expect(result.strategy == "ancestor-control-action")
        #expect(recorder.tapCount == 1)
        #expect(delegate.selectedIndexPath == nil)
        #expect(delegate.didSelectCount == 0)
    }

    @Test("smart tap keeps accessibility activation for a nearer gesture inside a collection cell")
    func smartTapKeepsAccessibleGestureInsideCollectionCell() async throws {
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
        let gestureSurface = AccessibleTapGestureSurface(frame: CGRect(x: 180, y: 12, width: 96, height: 28))
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 96, height: 28))
        label.text = "Safe gesture"
        gestureSurface.addSubview(label)
        gestureSurface.addGestureRecognizer(UITapGestureRecognizer())
        cell.contentView.addSubview(gestureSurface)

        let labelOID = TKObjectRegistry.shared.register(label)
        let result = try await performInputRequest(.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .smart
        ))
        await Task.yield()

        #expect(result.ok)
        #expect(result.strategy == "tap-gesture-accessibility-activate")
        #expect(gestureSurface.activationCount == 1)
        #expect(delegate.selectedIndexPath == nil)
        #expect(delegate.didSelectCount == 0)
    }

    @Test("collection cell tap does not escape to an outer accessible gesture")
    func collectionCellTapRejectsOuterAccessibleGesture() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let outerGestureSurface = AccessibleTapGestureSurface(frame: window.bounds)
        outerGestureSurface.addGestureRecognizer(UITapGestureRecognizer())
        window.addSubview(outerGestureSurface)

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 300, height: 60)
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 80, width: 390, height: 240), collectionViewLayout: layout)
        let dataSource = CollectionDataSource()
        let delegate = CollectionDelegate()
        collectionView.register(CollectionCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = dataSource
        collectionView.delegate = delegate
        outerGestureSurface.addSubview(collectionView)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        for gesture in collectionView.gestureRecognizers?.compactMap({ $0 as? UITapGestureRecognizer }) ?? [] {
            gesture.isEnabled = false
        }

        let indexPath = IndexPath(item: 0, section: 0)
        let cell = try #require(collectionView.cellForItem(at: indexPath) as? CollectionCell)
        let labelOID = TKObjectRegistry.shared.register(cell.label)

        let smart = try await performInputRequest(.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .smart
        ))
        let exact = try await performInputRequest(.tap(
            targetOID: labelOID,
            matchedOID: labelOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .exact
        ))
        await Task.yield()

        #expect(!smart.ok)
        #expect(smart.error?.code == "unsupported_capability")
        #expect(!exact.ok)
        #expect(exact.error?.code == "unsupported_capability")
        #expect(outerGestureSurface.activationCount == 0)
        #expect(delegate.selectedIndexPath == nil)
        #expect(delegate.didSelectCount == 0)
    }

    @Test("smart tap reports gesture parent unsupported without private introspection")
    func smartTapReportsGestureParentUnsupportedWithoutPrivateIntrospection() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let wrapper = UIView(frame: CGRect(x: 20, y: 120, width: 260, height: 72))
        let label = UILabel(frame: CGRect(x: 16, y: 20, width: 180, height: 24))
        let recorder = TapRecorder()
        label.text = "查看不合适原因"
        wrapper.addSubview(label)
        wrapper.addGestureRecognizer(UITapGestureRecognizer(target: recorder, action: #selector(TapRecorder.didTap(_:))))
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
        await Task.yield()

        #expect(!result.ok)
        #expect(recorder.tapCount == 0)
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == wrapperOID)
        #expect(result.targetOID == wrapperOID)
        #expect(result.activationClassName == NSStringFromClass(UIView.self))
        #expect(result.strategy == "ancestor-tap-gesture-recognizer")
        #expect(result.message == "UITapGestureRecognizer target actions are not exposed through public UIKit runtime APIs")
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

    @Test("horizontal swipe inside nested vertical scroll view selects horizontal pager ancestor")
    func horizontalSwipeInsideNestedVerticalScrollViewSelectsHorizontalAncestor() async throws {
        let window = makeVisibleTestWindow()
        defer {
            window.isHidden = true
        }

        let pager = UIScrollView(frame: CGRect(x: 0, y: 80, width: 390, height: 320))
        pager.contentSize = CGSize(width: 780, height: 320)
        pager.contentOffset = CGPoint(x: 390, y: 0)
        window.addSubview(pager)

        let list = UIScrollView(frame: CGRect(x: 390, y: 0, width: 390, height: 320))
        list.contentSize = CGSize(width: 390, height: 960)
        list.contentOffset = CGPoint(x: 0, y: 120)
        pager.addSubview(list)

        let row = UILabel(frame: CGRect(x: 24, y: 140, width: 180, height: 40))
        row.text = "创作中心"
        list.addSubview(row)

        let pagerOID = TKObjectRegistry.shared.register(pager)
        let request = TKInputRequest.swipe(
            startX: 210,
            startY: 240,
            endX: 330,
            endY: 242,
            width: 390,
            height: 844,
            duration: 0.2
        )
        let result = try await performInputRequest(request)

        #expect(result.ok)
        #expect(result.targetOID == pagerOID)
        #expect(result.targetClassName == NSStringFromClass(UIScrollView.self))
        #expect(pager.contentOffset.x == 270)
        #expect(list.contentOffset.y == 120)
        #expect(result.strategy == "axis-matched-scroll-ancestor")
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
