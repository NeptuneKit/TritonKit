import Testing
@testable import TritonKit
#if canImport(UIKit)
import UIKit
import TritonKitShared

@MainActor @Suite struct TKHighlightLifecycleTests {
    @Test func CleanupReferenceSurvivesOwnerAndOldCompletionCannotReleaseFence() throws {
        var storage: TKHighlightManagerStorage? = TKHighlightManagerStorage()
        let manager = TKHighlightSessionManager()
        storage?.set(manager)
        let first = try #require(storage?.beginCleanup())
        let second = try #require(storage?.beginCleanup())
        storage?.completeCleanup(first.1)
        #expect(storage?.cleanupPending == true)
        storage?.completeCleanup(second.1)
        #expect(storage?.cleanupPending == false)
        storage = nil
        #expect(first.0 === manager)
    }
    @Test func StopBeforeFirstManagerInvalidatesAlreadyAcceptedRequest() {
        let storage = TKHighlightManagerStorage()
        let previousGeneration = storage.currentGeneration
        let stop = storage.beginCleanup()
        #expect(stop.0 == nil)
        storage.completeCleanup(stop.1)
        var created = false
        let stale = storage.prepareApply(expectedGeneration: previousGeneration) {
            created = true
            return TKHighlightSessionManager()
        }
        #expect(stale == nil)
        #expect(!created)
        #expect(storage.prepareApply(expectedGeneration: storage.currentGeneration, create: { TKHighlightSessionManager() }) != nil)
    }
    @Test func RequestReceivedDuringStopStaysInvalidAfterCompletion() {
        let storage = TKHighlightManagerStorage()
        let stop = storage.beginCleanup()
        let captured = storage.requestGeneration
        _ = storage.performCleanup(manager: stop.0, generation: stop.1)
        #expect(storage.prepareApply(expectedGeneration: captured, create: { TKHighlightSessionManager() }) == nil)
    }
    @Test func OlderQueuedCleanupCannotClearNewSessionAfterNewerStop() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.isHidden = false
        defer { window.isHidden = true }
        let view = UIView(frame: CGRect(x: 20, y: 20, width: 100, height: 50))
        window.addSubview(view)
        let storage = TKHighlightManagerStorage()
        let manager = TKHighlightSessionManager(provider: TKUIKitHighlightProvider(roots: { [window] }))
        storage.set(manager)
        let first = storage.beginCleanup()
        let second = storage.beginCleanup()
        _ = storage.performCleanup(manager: second.0, generation: second.1)
        let result = await manager.apply(TKHighlightApplyRequest(operationID: "after-stop", spec: TKHighlightSpec(items: [TKHighlightItem(markID: "a", selector: TKHighlightSelector(oid: TKObjectRegistry.shared.register(view)))])))
        #expect(result.ok)
        #expect(storage.performCleanup(manager: first.0, generation: first.1) == nil)
        #expect(view.layer.borderWidth == 3)
        #expect(manager.clear(TKHighlightClearRequest(sessionID: try #require(result.sessionID))).ok)
    }
}
#endif
