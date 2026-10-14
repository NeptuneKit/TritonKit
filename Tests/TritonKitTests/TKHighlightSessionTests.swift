import Foundation
import Testing
@testable import TritonKit
import TritonKitShared
#if canImport(UIKit)
import UIKit

@MainActor
@Suite struct TKHighlightSessionTests {
    private func fixture() -> (UIWindow, UIView, TKHighlightSessionManager) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.isHidden = false
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 80, height: 40))
        view.accessibilityIdentifier = "target"
        window.addSubview(view)
        return (window, view, TKHighlightSessionManager(provider: TKUIKitHighlightProvider(roots: { [window] })))
    }
    private func request(_ view: UIView, operation: String = "op", ttl: Int = 30) -> TKHighlightApplyRequest {
        TKHighlightApplyRequest(operationID: operation, ttlSeconds: ttl, spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(oid: TKObjectRegistry.shared.register(view)))]))
    }
    @Test func nilColorRestoredAndRetryDoesNotResnapshot() async throws {
        let (window, view, manager) = fixture()
        defer { window.isHidden = true }
        view.layer.borderColor = nil
        view.layer.borderWidth = 1.25
        let applied = await manager.apply(request(view))
        #expect(applied.ok)
        #expect(view.layer.borderWidth == 3)
        let replay = await manager.apply(request(view))
        #expect(replay.sessionID == applied.sessionID)
        #expect(replay.expiresAt == applied.expiresAt)
        let cleared = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID)))
        #expect(cleared.ok)
        #expect(cleared.restorationVerified)
        #expect(view.layer.borderColor == nil)
        #expect(view.layer.borderWidth == 1.25)
        view.layer.borderWidth = 9
        _ = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID)))
        #expect(view.layer.borderWidth == 9)
    }
    @Test func businessColorConflictDoesNotPartiallyRestoreWidth() async throws {
        let (window, view, manager) = fixture()
        defer { window.isHidden = true }
        view.layer.borderWidth = 1
        let applied = await manager.apply(request(view))
        view.layer.borderColor = UIColor.green.cgColor
        let cleared = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID)))
        #expect(!cleared.ok)
        #expect(cleared.state == .needsAttention)
        #expect(view.layer.borderColor == UIColor.green.cgColor)
        #expect(view.layer.borderWidth == 3)
        view.layer.borderColor = UIColor(red: 1, green: 69.0/255, blue: 58.0/255, alpha: 1).cgColor
        _ = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID)))
        #expect(view.layer.borderWidth == 3)
    }
    @Test func batchPreflightRejectsCellWithoutWritingOtherTarget() async {
        let (window, view, manager) = fixture()
        defer { window.isHidden = true }
        let cell = UITableViewCell(frame: CGRect(x: 20, y: 100, width: 200, height: 40))
        window.addSubview(cell)
        var req = request(view)
        req.spec.items.append(TKHighlightItem(markID: "cell", selector: TKHighlightSelector(oid: TKObjectRegistry.shared.register(cell.contentView))))
        let result = await manager.apply(req)
        #expect(!result.ok)
        #expect(result.error?.code == "highlight_identity_unverifiable")
        #expect(view.layer.borderWidth == 0)
    }
    @Test func physicalLayerAliasesAndUnknownClearAreSafe() async throws {
        let (window, view, manager) = fixture()
        defer { window.isHidden = true }
        var req = request(view)
        req.spec.items.append(TKHighlightItem(markID: "layer", selector: TKHighlightSelector(oid: TKObjectRegistry.shared.register(view.layer))))
        let applied = await manager.apply(req)
        #expect(applied.ok)
        #expect(applied.marks.count == 1)
        #expect(applied.markAliases["layer"] == "a")
        let bad = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID), markIDs: ["unknown"]))
        #expect(!bad.ok)
        #expect(view.layer.borderWidth == 3)
        let cleared = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID), markIDs: ["layer"]))
        #expect(cleared.ok)
        #expect(view.layer.borderWidth == 0)
    }
    @Test func expiredSessionRestoresWithContinuousClockAndStopPreservesConflict() async throws {
        let (window, view, _) = fixture()
        defer { window.isHidden = true }
        var now: TimeInterval = 1
        let manager = TKHighlightSessionManager(provider: TKUIKitHighlightProvider(roots: { [window] }), now: { now })
        let applied = await manager.apply(request(view, ttl: 1))
        now = 3
        let status = manager.status(TKHighlightStatusRequest(sessionID: try #require(applied.sessionID)))
        #expect(status.state == .closed)
        #expect(view.layer.borderWidth == 0)
        let next = await manager.apply(request(view, operation: "next"))
        view.layer.borderWidth = 8
        #expect(manager.shutdown()?.cleanupComplete == false)
        #expect(manager.status(TKHighlightStatusRequest(sessionID: next.sessionID)).state == .needsAttention)
    }
    @Test func failedSetterCompensatesAndReplayPreservesApplyFailure() async throws {
        let (window, first, manager) = fixture()
        defer { window.isHidden = true }
        let firstOriginalColor = first.layer.borderColor
        let refusing = RefusingBorderView(frame: CGRect(x: 20, y: 150, width: 80, height: 40))
        window.addSubview(refusing)
        var req = request(first)
        req.spec.items.append(TKHighlightItem(markID: "rejecting", selector: TKHighlightSelector(oid: TKObjectRegistry.shared.register(refusing))))
        let failed = await manager.apply(req)
        #expect(!failed.ok)
        #expect(failed.cleanupComplete)
        #expect(first.layer.borderWidth == 0)
        #expect(first.layer.borderColor == firstOriginalColor)
        let replay = await manager.apply(req)
        #expect(!replay.ok)
        #expect(replay.error == failed.error)
        #expect(replay.sessionID == failed.sessionID)
        let query = manager.status(TKHighlightStatusRequest(operationID: "op"))
        #expect(query.ok)
        #expect(query.cleanupComplete)
    }
    @Test func partialClearAndExternalResolutionKeepPreciseOutcomes() async throws {
        let (window, first, manager) = fixture()
        defer { window.isHidden = true }
        let second = UIView(frame: CGRect(x: 20, y: 150, width: 80, height: 40))
        window.addSubview(second)
        var req = request(first)
        req.spec.items.append(TKHighlightItem(markID: "b", selector: TKHighlightSelector(oid: TKObjectRegistry.shared.register(second))))
        let applied = await manager.apply(req)
        let sessionID = try #require(applied.sessionID)
        let partial = manager.clear(TKHighlightClearRequest(sessionID: sessionID, markIDs: ["a"]))
        #expect(partial.ok)
        #expect(partial.state == .partiallyActive)
        #expect(!partial.cleanupComplete)
        #expect(first.layer.borderWidth == 0)
        #expect(second.layer.borderWidth == 3)
        second.layer.borderColor = UIColor.green.cgColor
        let conflict = manager.clear(TKHighlightClearRequest(sessionID: sessionID, markIDs: ["b"]))
        #expect(conflict.state == .needsAttention)
        #expect(!conflict.cleanupComplete)
        second.layer.borderWidth = 7
        let external = manager.clear(TKHighlightClearRequest(sessionID: sessionID, markIDs: ["b"]))
        #expect(external.cleanupComplete)
        #expect(!external.restorationVerified)
        #expect(external.marks.last?.outcome == .resolvedExternally)
        #expect(second.layer.borderWidth == 7)
        #expect(await manager.apply(request(first, operation: "next")).ok)
        _ = manager.shutdown()
    }
    @Test func detachedTargetDoesNotReceiveOriginalAndTerminalReceiptBudgetKeepsDedupe() async throws {
        let (window, view, _) = fixture()
        defer { window.isHidden = true }
        let manager = TKHighlightSessionManager(provider: TKUIKitHighlightProvider(roots: { [window] }), receiptCapacity: 1)
        let original = await manager.apply(request(view))
        _ = manager.clear(TKHighlightClearRequest(sessionID: try #require(original.sessionID)))
        let next = await manager.apply(request(view, operation: "next"))
        _ = manager.clear(TKHighlightClearRequest(sessionID: try #require(next.sessionID)))
        #expect(await manager.apply(request(view)).error?.code == "highlight_receipt_expired")
        let last = await manager.apply(request(view, operation: "last"))
        view.removeFromSuperview()
        let clear = manager.clear(TKHighlightClearRequest(sessionID: try #require(last.sessionID)))
        #expect(clear.marks.first?.outcome == .identityChanged)
        #expect(!clear.cleanupComplete)
        #expect(view.layer.borderWidth == 3)
    }
    @Test func releasedTargetIsCleanupCompleteButNotRestorationVerified() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.isHidden = false
        defer { window.isHidden = true }
        var view: UIView? = UIView(frame: CGRect(x: 20, y: 20, width: 80, height: 40))
        window.addSubview(view!)
        let manager = TKHighlightSessionManager(provider: TKUIKitHighlightProvider(roots: { [window] }))
        let applied = await manager.apply(request(view!))
        weak var releasedLayer = view?.layer
        view?.removeFromSuperview()
        view = nil
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        #expect(releasedLayer == nil)
        let cleared = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID)))
        #expect(cleared.cleanupComplete)
        #expect(!cleared.restorationVerified)
        #expect(!cleared.ok)
        #expect(cleared.residualState == .none)
        #expect(cleared.marks.first?.outcome == .targetGone)
    }
    @Test func identifiersAreUniqueScopedAndNoChangeDoesNotReserveActiveSession() async throws {
        let (window, first, manager) = fixture()
        defer { window.isHidden = true }
        let second = UIView(frame: CGRect(x: 20, y: 150, width: 80, height: 40))
        second.accessibilityIdentifier = "target"
        window.addSubview(second)
        let ambiguous = TKHighlightApplyRequest(operationID: "ambiguous", spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(identifier: "target"))]))
        #expect(await manager.apply(ambiguous).error?.code == "highlight_target_ambiguous")
        #expect(first.layer.borderWidth == 0)
        first.layer.borderColor = UIColor(red: 1, green: 69.0/255, blue: 58.0/255, alpha: 1).cgColor
        first.layer.borderWidth = 3
        let scoped = TKHighlightApplyRequest(operationID: "same", spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(identifier: "target", withinOID: TKObjectRegistry.shared.register(first)))]))
        let noop = await manager.apply(scoped)
        #expect(noop.reason == "no_change")
        #expect(noop.state == .closed)
        #expect(noop.marks.first?.changedKeys.isEmpty == true)
        let next = await manager.apply(request(second, operation: "next"))
        #expect(next.ok)
        _ = manager.shutdown()
    }
    @Test func originalColorSpaceAndGuardOnlyFieldsArePreserved() async throws {
        let (window, view, manager) = fixture()
        defer { window.isHidden = true }
        let p3 = UIColor(displayP3Red: 0.3, green: 0.5, blue: 0.8, alpha: 0.6).cgColor
        view.layer.borderColor = p3
        view.layer.borderWidth = 3
        let applied = await manager.apply(request(view))
        #expect(applied.marks.first?.changedKeys == ["borderColor"])
        let cleared = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID)))
        #expect(cleared.restorationVerified)
        #expect(view.layer.borderColor == p3)
        #expect(view.layer.borderColor?.colorSpace == p3.colorSpace)
        #expect(view.layer.borderWidth == 3)
    }
    @Test func partialClearDuringRenderOpportunityFailsApplyAndCompensatesRemainingMark() async throws {
        let (window, first, _) = fixture()
        defer { window.isHidden = true }
        let second = UIView(frame: CGRect(x: 20, y: 150, width: 80, height: 40))
        window.addSubview(second)
        let firstColor = first.layer.borderColor
        let secondColor = second.layer.borderColor
        let gate = HighlightOpportunityGate()
        let manager = TKHighlightSessionManager(provider: TKUIKitHighlightProvider(roots: { [window] }), renderOpportunity: { await gate.suspend() })
        var req = request(first)
        req.spec.items.append(TKHighlightItem(markID: "b", selector: TKHighlightSelector(oid: TKObjectRegistry.shared.register(second))))
        let pending = Task { @MainActor in await manager.apply(req) }
        await gate.waitForArrival()
        let session = manager.status(TKHighlightStatusRequest(operationID: "op"))
        let partial = manager.clear(TKHighlightClearRequest(sessionID: try #require(session.sessionID), markIDs: ["a"]))
        #expect(partial.ok)
        #expect(second.layer.borderWidth == 3)
        gate.open()
        let interrupted = await pending.value
        #expect(!interrupted.ok)
        #expect(interrupted.reason == "apply_invalidated")
        #expect(interrupted.cleanupComplete)
        #expect(interrupted.restorationVerified)
        #expect(first.layer.borderColor == firstColor)
        #expect(second.layer.borderColor == secondColor)
        #expect(first.layer.borderWidth == 0)
        #expect(second.layer.borderWidth == 0)
        let replay = await manager.apply(req)
        #expect(!replay.ok)
        #expect(replay.error == interrupted.error)
    }
    @Test func reparentedAncestorWithinSameWindowInvalidatesTargetIdentity() async throws {
        let (window, view, manager) = fixture()
        defer { window.isHidden = true }
        let firstContainer = UIView(frame: window.bounds)
        let secondContainer = UIView(frame: window.bounds)
        let movingContainer = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        window.addSubview(firstContainer)
        window.addSubview(secondContainer)
        firstContainer.addSubview(movingContainer)
        movingContainer.addSubview(view)
        let applied = await manager.apply(request(view))
        secondContainer.addSubview(movingContainer)
        #expect(view.window === window)
        #expect(view.superview === movingContainer)
        let cleared = manager.clear(TKHighlightClearRequest(sessionID: try #require(applied.sessionID)))
        #expect(cleared.marks.first?.outcome == .identityChanged)
        #expect(!cleared.cleanupComplete)
        #expect(!cleared.restorationVerified)
        #expect(view.layer.borderWidth == 3)
    }
    @Test func setterReentryChangingAnUnwrittenMarkDoesNotCreateResidualOwnership() async throws {
        let (window, second, manager) = fixture()
        defer { window.isHidden = true }
        let first = ReentrantBorderView(frame: CGRect(x: 20, y: 150, width: 80, height: 40))
        window.addSubview(first)
        let firstColor = first.layer.borderColor
        let callbackLayer = try #require(first.layer as? ReentrantBorderLayer)
        callbackLayer.afterColorWrite = { second.layer.borderColor = UIColor.green.cgColor; second.layer.borderWidth = 7 }
        var req = request(first)
        req.spec.items.append(TKHighlightItem(markID: "b", selector: TKHighlightSelector(oid: TKObjectRegistry.shared.register(second))))
        let failed = await manager.apply(req)
        callbackLayer.afterColorWrite = nil
        #expect(!failed.ok)
        #expect(failed.cleanupComplete)
        #expect(failed.residualState == .none)
        #expect(first.layer.borderColor == firstColor)
        #expect(first.layer.borderWidth == 0)
        #expect(second.layer.borderColor == UIColor.green.cgColor)
        #expect(second.layer.borderWidth == 7)
        #expect(failed.marks.last?.outcome == .noChange)
        #expect(failed.marks.last?.changedKeys.isEmpty == true)
        let next = await manager.apply(request(second, operation: "next"))
        #expect(next.ok)
        _ = manager.shutdown()
    }
    @Test func staleRuntimeAndCapacityDoNotWrite() async {
        let (window, view, _) = fixture()
        defer { window.isHidden = true }
        let manager = TKHighlightSessionManager(provider: TKUIKitHighlightProvider(roots: { [window] }), operationCapacity: 1)
        var stale = request(view)
        stale.runtimeInstanceID = "other"
        #expect(await manager.apply(stale).error?.code == "highlight_stale_runtime")
        let first = await manager.apply(request(view))
        _ = manager.clear(TKHighlightClearRequest(sessionID: first.sessionID!))
        #expect(await manager.apply(request(view, operation: "second")).error?.code == "highlight_capacity_exceeded")
        #expect(view.layer.borderWidth == 0)
    }
}

@MainActor private final class HighlightOpportunityGate {
    private var arrival: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?
    private var arrived = false
    func suspend() async {
        await withCheckedContinuation { continuation in
            release = continuation; arrived = true
            arrival?.resume(); arrival = nil
        }
    }
    func waitForArrival() async {
        if arrived { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func open() { release?.resume(); release = nil }
}
private final class ReentrantBorderLayer: CALayer {
    var afterColorWrite: (() -> Void)?
    override var borderColor: CGColor? {
        get { super.borderColor }
        set { super.borderColor = newValue; afterColorWrite?() }
    }
}
private final class ReentrantBorderView: UIView {
    override class var layerClass: AnyClass { ReentrantBorderLayer.self }
}
private final class RefusingBorderLayer: CALayer {
    override var borderWidth: CGFloat { get { super.borderWidth } set { if newValue != 3 { super.borderWidth = newValue } } }
}
private final class RefusingBorderView: UIView {
    override class var layerClass: AnyClass { RefusingBorderLayer.self }
}
#endif
