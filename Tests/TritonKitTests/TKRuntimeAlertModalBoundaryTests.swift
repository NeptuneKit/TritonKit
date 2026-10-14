import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

extension TKUIKitWindowTests {
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
    func blocksCollectionFallback() async throws {
        let fixture = try makeFixture(actionCount: 2)
        defer { fixture.window.isHidden = true }
        let modalHitView = UIView(frame: CGRect(x: 80, y: 220, width: 220, height: 64))
        modalHitView.isAccessibilityElement = true
        modalHitView.accessibilityLabel = "Cancel"
        fixture.alert.view.addSubview(modalHitView)
        try #require(modalHitView.window === fixture.window)
        let frame = modalHitView.convert(modalHitView.bounds, to: nil)

        let request = TKInputRequest.tap(
            x: Double(frame.midX),
            y: Double(frame.midY),
            targetOID: TKObjectRegistry.shared.register(modalHitView)
        )
        try requireModalFallbackPreconditions(request, target: modalHitView, window: fixture.window,
            alert: fixture.alert, collectionView: fixture.collectionView)
        let result = performTap(request)
        await Task.yield()

        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_capability")
        #expect(result.error?.suggestedCommands?.contains(where: { $0.hasPrefix("triton sim tap --simulator booted") }) == true)
        #expect(result.strategy == "alert-action-unsupported")
        #expect(fixture.delegate.selectedIndexPath == nil)
        #expect(fixture.collectionView.indexPathsForSelectedItems?.isEmpty != false)
    }

    @Test("alert modal boundary blocks fallback when the hit view cannot map to an action")
    func blocksFallbackForUnmappedAlertView() async throws {
        let fixture = try makeFixture(actionCount: 2)
        defer { fixture.window.isHidden = true }
        let unmappedView = UIView(frame: CGRect(x: 80, y: 220, width: 220, height: 64))
        fixture.alert.view.addSubview(unmappedView)
        try #require(unmappedView.window === fixture.window)
        let frame = unmappedView.convert(unmappedView.bounds, to: nil)

        let request = TKInputRequest.tap(
            x: Double(frame.midX),
            y: Double(frame.midY),
            targetOID: TKObjectRegistry.shared.register(unmappedView)
        )
        try requireModalFallbackPreconditions(request, target: unmappedView, window: fixture.window,
            alert: fixture.alert, collectionView: fixture.collectionView)
        let result = performTap(request)
        await Task.yield()

        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_capability")
        #expect(result.strategy == "alert-action-unsupported")
        #expect(fixture.delegate.selectedIndexPath == nil)
        #expect(fixture.collectionView.indexPathsForSelectedItems?.isEmpty != false)
    }

    @Test("alert modal boundary uses accessibility activation without collection fallback")
    func usesAccessibilityActivation() async throws {
        let fixture = try makeFixture(actionCount: 1)
        defer { fixture.window.isHidden = true }
        let activatingView = AccessibilityActivatingView(frame: CGRect(x: 80, y: 220, width: 220, height: 64))
        activatingView.isAccessibilityElement = true
        activatingView.accessibilityLabel = "Cancel"
        var activationCallbackCount = 0
        activatingView.onActivate = { activationCallbackCount += 1 }
        fixture.alert.view.addSubview(activatingView)
        try #require(activatingView.window === fixture.window)
        let frame = activatingView.convert(activatingView.bounds, to: nil)

        let request = TKInputRequest.tap(
            x: Double(frame.midX),
            y: Double(frame.midY),
            targetOID: TKObjectRegistry.shared.register(activatingView)
        )
        try requireModalFallbackPreconditions(request, target: activatingView, window: fixture.window,
            alert: fixture.alert, collectionView: fixture.collectionView)
        let result = performTap(request)
        await Task.yield()

        #expect(result.ok)
        #expect(result.strategy == "alert-action-accessibility-activate")
        #expect(activatingView.activationCount == 1)
        #expect(activationCallbackCount == 1)
        #expect(fixture.delegate.selectedIndexPath == nil)
        #expect(fixture.collectionView.indexPathsForSelectedItems?.isEmpty != false)
    }

    private func makeFixture(actionCount: Int) throws -> (
        window: UIWindow,
        alert: UIAlertController,
        collectionView: UICollectionView,
        dataSource: CollectionDataSource,
        delegate: CollectionDelegate
    ) {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        var ready = false
        defer { if !ready { window.isHidden = true } }

        // This fixture tests responder-chain routing, not UIKit presentation.
        // Mount the real controller through UIWindow's public root API, keeping
        // the target attached and all runtime active-window checks in force.
        let alert = UIAlertController(title: "Delete items?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if actionCount > 1 {
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive))
        }
        window.isHidden = true
        window.rootViewController = alert
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        alert.view.frame = window.bounds
        try #require(window.rootViewController === alert)
        try #require(alert.view.window === window, "Real alert responder hierarchy must be attached to the fixture window")
        try #require(keyWindows().contains { $0 === window }, "Fixture must remain an active runtime window")

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
        // A visible same-window sibling remains discoverable by the actual
        // coordinate fallback collector even beneath the alert's view.
        window.insertSubview(collectionView, at: 0)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        window.layoutIfNeeded()
        try #require(collectionView.window === window)
        try #require(collectionView.cellForItem(at: IndexPath(item: 0, section: 0)), "Background fallback cell must be rendered")
        ready = true
        return (window, alert, collectionView, dataSource, delegate)
    }

    private func requireModalFallbackPreconditions(_ request: TKInputRequest, target: UIView,
        window: UIWindow, alert: UIAlertController, collectionView: UICollectionView) throws {
        try #require(target.window === window)
        try #require(nearestAlertController(from: target) === alert, "Target must resolve through the real alert responder chain")
        try #require(keyWindows().contains { $0 === window })
        let candidate = try #require(collectionCellContaining(request: request), "This exact tap must have a real background collection fallback candidate")
        let renderedCell = try #require(collectionView.cellForItem(at: IndexPath(item: 0, section: 0)))
        try #require(candidate === renderedCell)
        try #require(candidate.window === window)
    }
}
}
#endif
