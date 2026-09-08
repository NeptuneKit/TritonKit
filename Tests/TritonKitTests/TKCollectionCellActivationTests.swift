import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

/// Issue #209 BDD fixtures: a private-app style custom UICollectionViewCell that
/// must be activated through the same public-selection contract as
/// `ancestor-table-cell-selection` (eligibility → selectItem → didSelectItemAt).
@MainActor
@Suite(.serialized)
struct TKCollectionCellActivationTests {

    // MARK: - Fixtures

    final class ActivationCollectionCell: UICollectionViewCell {
        let label = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            label.frame = CGRect(x: 16, y: 12, width: 200, height: 24)
            contentView.addSubview(label)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    final class TwoItemDataSource: NSObject, UICollectionViewDataSource {
        let titles = ["First session", "Second session"]

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            titles.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "activation-cell", for: indexPath)
            (cell as? ActivationCollectionCell)?.label.text = titles[indexPath.item]
            return cell
        }
    }

    /// Records public delegate callback order so tests can assert the
    /// shouldSelectItemAt → didSelectItemAt sequence.
    final class SelectionDelegateRecorder: NSObject, UICollectionViewDelegate {
        var events: [String] = []
        var selectedIndexPath: IndexPath?
        var didSelectCount = 0
        var shouldSelectResult = true

        func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
            events.append("shouldSelect:\(indexPath.item)")
            return shouldSelectResult
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            events.append("didSelect:\(indexPath.item)")
            selectedIndexPath = indexPath
            didSelectCount += 1
        }
    }

    // MARK: - Harness

    private func makeCollectionViewWindow(
        allowsSelection: Bool = true
    ) -> (window: UIWindow, collectionView: UICollectionView, dataSource: TwoItemDataSource, delegate: SelectionDelegateRecorder) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 300, height: 60)
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 80, width: 390, height: 240), collectionViewLayout: layout)
        collectionView.register(ActivationCollectionCell.self, forCellWithReuseIdentifier: "activation-cell")
        collectionView.allowsSelection = allowsSelection
        let dataSource = TwoItemDataSource()
        let delegate = SelectionDelegateRecorder()
        collectionView.dataSource = dataSource
        collectionView.delegate = delegate
        window.addSubview(collectionView)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        window.makeKeyAndVisible()
        return (window, collectionView, dataSource, delegate)
    }

    private func smartTapRequest(targetOID: UInt) -> TKInputRequest {
        .tap(
            targetOID: targetOID,
            matchedOID: targetOID,
            matchedClassName: NSStringFromClass(UILabel.self),
            activationStrategy: .smart
        )
    }

    // MARK: - Scenario 1: text resolution → safe selection

    @Test("text match selects resolved collection cell through public delegate callbacks")
    func textMatchTapSelectsResolvedCollectionCell() throws {
        let (window, collectionView, _, delegate) = makeCollectionViewWindow()
        defer { window.isHidden = true }

        let indexPath = IndexPath(item: 1, section: 0)
        let cell = try #require(collectionView.cellForItem(at: indexPath) as? ActivationCollectionCell)
        let labelOID = TKObjectRegistry.shared.register(cell.label)
        let cellOID = TKObjectRegistry.shared.register(cell)

        let result = performTap(smartTapRequest(targetOID: labelOID))

        #expect(result.ok)
        #expect(result.strategy == "ancestor-collection-cell-selection")
        #expect(result.message == "Selected UICollectionViewCell ancestor and invoked delegate callback")
        #expect(result.matchedOID == labelOID)
        #expect(result.activationOID == cellOID)
        #expect(result.targetOID == cellOID)
        #expect(result.activationClassName == NSStringFromClass(ActivationCollectionCell.self))
        #expect(delegate.events == ["shouldSelect:1", "didSelect:1"])
        #expect(delegate.selectedIndexPath == indexPath)
        #expect(delegate.didSelectCount == 1)
        #expect(collectionView.indexPathsForSelectedItems == [indexPath])
        #expect(result.verification?.required == true)
        #expect(result.verification?.status == "not-verified")
        #expect(result.verification?.suggestedCommands.isEmpty == false)
    }

    // MARK: - Scenario 2: coordinate resolution → same selection path

    @Test("coordinate tap selects collection cell containing the hit point")
    func coordinateTapSelectsCollectionCellContainingPoint() throws {
        let (window, collectionView, _, delegate) = makeCollectionViewWindow()
        defer { window.isHidden = true }

        let indexPath = IndexPath(item: 1, section: 0)
        let cell = try #require(collectionView.cellForItem(at: indexPath) as? ActivationCollectionCell)
        let cellOID = TKObjectRegistry.shared.register(cell)
        let frame = cell.convert(cell.bounds, to: nil)

        let result = performTap(.tap(x: Double(frame.midX), y: Double(frame.midY)))

        #expect(result.ok)
        #expect(result.strategy == "ancestor-collection-cell-selection")
        #expect(result.activationOID == cellOID)
        #expect(result.activationClassName == NSStringFromClass(ActivationCollectionCell.self))
        #expect(delegate.events == ["shouldSelect:1", "didSelect:1"])
        #expect(delegate.selectedIndexPath == indexPath)
        #expect(delegate.didSelectCount == 1)
        #expect(collectionView.indexPathsForSelectedItems == [indexPath])
        #expect(result.verification?.required == true)
    }

    // MARK: - Scenario 3a: allowsSelection == false fails closed

    @Test("selection-disabled collection view fails closed without delegate callbacks")
    func selectionDisabledCollectionViewFailsClosed() throws {
        let (window, collectionView, _, delegate) = makeCollectionViewWindow(allowsSelection: false)
        defer { window.isHidden = true }

        let indexPath = IndexPath(item: 1, section: 0)
        let cell = try #require(collectionView.cellForItem(at: indexPath) as? ActivationCollectionCell)
        let labelOID = TKObjectRegistry.shared.register(cell.label)

        let result = performTap(smartTapRequest(targetOID: labelOID))

        #expect(!result.ok)
        #expect(result.strategy == "ancestor-collection-cell-selection-blocked")
        #expect(result.error?.code == "collection_cell_selection_blocked")
        #expect(delegate.events.isEmpty)
        #expect(delegate.didSelectCount == 0)
        #expect((collectionView.indexPathsForSelectedItems ?? []).isEmpty)
    }

    // MARK: - Scenario 3b: shouldSelectItemAt denial fails closed

    @Test("delegate shouldSelectItemAt denial fails closed without didSelect callback")
    func delegateDenialFailsClosedWithoutDidSelect() throws {
        let (window, collectionView, _, delegate) = makeCollectionViewWindow()
        defer { window.isHidden = true }
        delegate.shouldSelectResult = false

        let indexPath = IndexPath(item: 1, section: 0)
        let cell = try #require(collectionView.cellForItem(at: indexPath) as? ActivationCollectionCell)
        let labelOID = TKObjectRegistry.shared.register(cell.label)

        let result = performTap(smartTapRequest(targetOID: labelOID))

        #expect(!result.ok)
        #expect(result.strategy == "ancestor-collection-cell-selection-denied")
        #expect(result.error?.code == "collection_cell_selection_denied")
        #expect(delegate.events == ["shouldSelect:1"])
        #expect(delegate.didSelectCount == 0)
        #expect((collectionView.indexPathsForSelectedItems ?? []).isEmpty)
    }

    // MARK: - Helper contract: selection state and callback settle before success

    @Test("collection cell helper completes selection and delegate callback before success")
    func collectionCellHelperCompletesSelectionAndCallback() throws {
        let (window, collectionView, _, delegate) = makeCollectionViewWindow()
        defer { window.isHidden = true }

        let indexPath = IndexPath(item: 0, section: 0)
        let cell = try #require(collectionView.cellForItem(at: indexPath) as? ActivationCollectionCell)
        let result = try #require(performCollectionCellTap(
            cell,
            request: .tap(targetOID: TKObjectRegistry.shared.register(cell)),
            action: "tap",
            matchedView: cell
        ))

        #expect(result.ok)
        #expect(collectionView.indexPathsForSelectedItems == [indexPath])
        #expect(delegate.selectedIndexPath == indexPath)
        #expect(delegate.didSelectCount == 1)
        #expect(delegate.events == ["shouldSelect:0", "didSelect:0"])
        #expect(result.message == "Selected UICollectionViewCell ancestor and invoked delegate callback")
        #expect(result.verification?.required == true)
    }

    // MARK: - Fallback: unresolvable cell keeps the typed unsupported boundary

    @Test("unresolvable collection cell keeps typed unsupported fallback")
    func unresolvableCollectionCellKeepsTypedUnsupportedFallback() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let orphanCell = ActivationCollectionCell(frame: CGRect(x: 20, y: 120, width: 300, height: 60))
        orphanCell.label.text = "Orphan cell"
        window.addSubview(orphanCell)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let labelOID = TKObjectRegistry.shared.register(orphanCell.label)
        let result = performTap(smartTapRequest(targetOID: labelOID))

        #expect(!result.ok)
        #expect(result.strategy == "ancestor-collection-cell-unsupported")
        #expect(result.error?.code == "unsupported_capability")
        #expect(result.verification?.required == true)
    }
}
#endif
