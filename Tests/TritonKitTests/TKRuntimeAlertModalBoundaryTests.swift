import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

@MainActor
@Suite(.serialized)
struct TKRuntimeAlertModalBoundaryTests {
    final class CollectionCell: UICollectionViewCell {}

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

    final class AccessibilityActivatingView: UIView {
        var activationCount = 0
        var onActivate: (() -> Void)?

        override func accessibilityActivate() -> Bool {
            activationCount += 1
            onActivate?()
            return true
        }
    }

    @Test("alert modal boundary blocks coordinate fallback to collection cell")
    func blocksCollectionFallback() async {
        let fixture = makeFixture(actionCount: 2)
        defer { fixture.window.isHidden = true }
        let modalHitView = UIView(frame: CGRect(x: 80, y: 220, width: 220, height: 64))
        modalHitView.isAccessibilityElement = true
        modalHitView.accessibilityLabel = "Cancel"
        fixture.alert.view.addSubview(modalHitView)
        let frame = modalHitView.convert(modalHitView.bounds, to: nil)

        let result = performTap(.tap(
            x: Double(frame.midX),
            y: Double(frame.midY),
            targetOID: TKObjectRegistry.shared.register(modalHitView)
        ))
        await Task.yield()

        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_capability")
        #expect(result.error?.suggestedCommands?.contains(where: { $0.hasPrefix("triton sim tap --simulator booted") }) == true)
        #expect(result.strategy == "alert-action-unsupported")
        #expect(fixture.delegate.selectedIndexPath == nil)
        #expect(fixture.collectionView.indexPathsForSelectedItems?.isEmpty != false)
    }

    @Test("alert modal boundary blocks fallback when the hit view cannot map to an action")
    func blocksFallbackForUnmappedAlertView() async {
        let fixture = makeFixture(actionCount: 2)
        defer { fixture.window.isHidden = true }
        let unmappedView = UIView(frame: CGRect(x: 80, y: 220, width: 220, height: 64))
        fixture.alert.view.addSubview(unmappedView)
        let frame = unmappedView.convert(unmappedView.bounds, to: nil)

        let result = performTap(.tap(
            x: Double(frame.midX),
            y: Double(frame.midY),
            targetOID: TKObjectRegistry.shared.register(unmappedView)
        ))
        await Task.yield()

        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_capability")
        #expect(result.strategy == "alert-action-unsupported")
        #expect(fixture.delegate.selectedIndexPath == nil)
        #expect(fixture.collectionView.indexPathsForSelectedItems?.isEmpty != false)
    }

    @Test("alert modal boundary uses accessibility activation without collection fallback")
    func usesAccessibilityActivation() async {
        let fixture = makeFixture(actionCount: 1)
        defer { fixture.window.isHidden = true }
        let activatingView = AccessibilityActivatingView(frame: CGRect(x: 80, y: 220, width: 220, height: 64))
        activatingView.isAccessibilityElement = true
        activatingView.accessibilityLabel = "Cancel"
        activatingView.onActivate = { fixture.alert.dismiss(animated: false) }
        fixture.alert.view.addSubview(activatingView)
        let frame = activatingView.convert(activatingView.bounds, to: nil)

        let result = performTap(.tap(
            x: Double(frame.midX),
            y: Double(frame.midY),
            targetOID: TKObjectRegistry.shared.register(activatingView)
        ))
        await Task.yield()

        #expect(result.ok)
        #expect(result.strategy == "alert-action-accessibility-activate")
        #expect(activatingView.activationCount == 1)
        #expect(fixture.delegate.selectedIndexPath == nil)
        #expect(fixture.collectionView.indexPathsForSelectedItems?.isEmpty != false)
    }

    private func makeFixture(actionCount: Int) -> (
        window: UIWindow,
        alert: UIAlertController,
        collectionView: UICollectionView,
        dataSource: CollectionDataSource,
        delegate: CollectionDelegate
    ) {
        let window = makeVisibleTestWindow()
        _ = TKObjectRegistry.shared.register(window)
        let root = UIViewController()
        window.rootViewController = root

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 390, height: 700)
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: layout
        )
        let dataSource = CollectionDataSource()
        let delegate = CollectionDelegate()
        collectionView.register(CollectionCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = dataSource
        collectionView.delegate = delegate
        root.view.addSubview(collectionView)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        let alert = UIAlertController(title: "Delete items?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if actionCount > 1 {
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive))
        }
        root.present(alert, animated: false)
        alert.loadViewIfNeeded()
        alert.view.frame = window.bounds
        return (window, alert, collectionView, dataSource, delegate)
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
