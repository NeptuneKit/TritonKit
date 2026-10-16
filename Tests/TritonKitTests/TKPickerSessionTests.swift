import Testing
import TritonKitShared
@testable import TritonKit

#if canImport(UIKit)
import UIKit

extension TKUIKitWindowTests {
@Suite(.serialized)
@MainActor
struct TKPickerSessionTests {
    @Test("selecting does not dispatch; guarded exact button dispatch happens once")
    func selectionThenTap() throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        let manager = TKPickerSessionManager()
        let result = manager.select(button)
        #expect(result.state == "valid")
        #expect(counter.count == 0)
        let selection = try #require(result.selection)
        #expect(manager.performGuardedTap(.init(runtimeInstanceID: result.runtimeInstanceID, selectionID: selection.id, revision: result.revision)).ok)
        #expect(counter.count == 1)
    }

    @Test("reselection, runtime mismatch and clear reject the old guard without dispatch")
    func oldGuard() throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        let manager = TKPickerSessionManager()
        let first = manager.select(button)
        let selection = try #require(first.selection)
        let old = TKSelectionGuard(runtimeInstanceID: first.runtimeInstanceID, selectionID: selection.id, revision: first.revision)
        #expect(manager.performGuardedTap(.init(runtimeInstanceID: first.runtimeInstanceID, selectionID: selection.id, revision: 0)).error?.code == "validation_failed")
        #expect(!manager.performGuardedTap(.init(runtimeInstanceID: "different", selectionID: selection.id, revision: first.revision)).ok)
        _ = manager.select(button)
        #expect(manager.performGuardedTap(old).error?.code == "selection_revision_mismatch")
        _ = manager.clear()
        #expect(manager.status().state == "none")
        #expect(manager.performGuardedTap(old).error?.code == "selection_missing")
        #expect(counter.count == 0)
    }

    @Test("changed content, ancestry and detachment latch stale")
    func staleIdentity() throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        let manager = TKPickerSessionManager()
        _ = manager.select(button)
        button.setTitle("Changed", for: .normal)
        #expect(manager.status().state == "stale")
        button.setTitle("Run", for: .normal)
        #expect(manager.status().state == "stale")
        _ = manager.select(button)
        let container = UIView(frame: window.bounds)
        window.rootViewController?.view.addSubview(container)
        container.addSubview(button)
        #expect(manager.status().state == "stale")
        _ = manager.select(button)
        button.removeFromSuperview()
        #expect(manager.status().state == "stale")
        #expect(counter.count == 0)
    }

    @Test("TTL expiry is enforced synchronously before dispatch")
    func expiry() throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        var now = Date(timeIntervalSince1970: 100)
        let manager = TKPickerSessionManager(ttlSeconds: 10, now: { now })
        let result = manager.select(button)
        let selection = try #require(result.selection)
        now = now.addingTimeInterval(11)
        #expect(manager.status().selection?.invalidReason == "expired")
        #expect(!manager.performGuardedTap(.init(runtimeInstanceID: result.runtimeInstanceID, selectionID: selection.id, revision: result.revision)).ok)
        #expect(counter.count == 0)
    }

    @Test("a reused cell descendant never gains an executable identity")
    func cellObservation() throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        let cell = UITableViewCell(frame: CGRect(x: 0, y: 0, width: 250, height: 150))
        window.rootViewController?.view.addSubview(cell)
        cell.contentView.addSubview(button)
        let manager = TKPickerSessionManager()
        let result = manager.select(button)
        let selection = try #require(result.selection)
        #expect(result.state == "observeOnly")
        #expect(selection.supportedActions.isEmpty)
        #expect(manager.performGuardedTap(.init(runtimeInstanceID: result.runtimeInstanceID, selectionID: selection.id, revision: result.revision)).error?.code == "selection_identity_unverifiable")
        #expect(counter.count == 0)
    }

    @Test("a noninteractive label can be selected without silently activating its button ancestor")
    func labelAndParent() throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        let label = UILabel(frame: button.bounds); label.text = "Child"
        button.addSubview(label)
        let manager = TKPickerSessionManager()
        let result = manager.select(label)
        let selection = try #require(result.selection)
        #expect(result.state == "observeOnly")
        #expect(selection.target.targetOID == TKObjectRegistry.shared.register(label))
        #expect(!manager.performGuardedTap(.init(runtimeInstanceID: result.runtimeInstanceID, selectionID: selection.id, revision: result.revision)).ok)
        let parent = manager.selectParent()
        #expect(parent.revision > result.revision)
        #expect(parent.selection?.rawHitOID == selection.rawHitOID)
        #expect(parent.selection?.resolutionReason == "explicit-parent")
        #expect(manager.selectedView === button)
        #expect(counter.count == 0)
    }

    @Test("clipping, sibling obstruction and disabled hierarchy refuse guarded actions")
    func obstruction() throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        let manager = TKPickerSessionManager()
        _ = manager.select(button)
        let cover = UIView(frame: button.frame)
        window.rootViewController?.view.addSubview(cover)
        #expect(manager.status().state == "stale")
        cover.removeFromSuperview()
        _ = manager.select(button)
        button.frame.origin.x = 5000
        #expect(manager.status().state == "stale")
        button.frame.origin.x = 20
        button.isUserInteractionEnabled = false
        #expect(manager.select(button).state == "observeOnly")
        #expect(counter.count == 0)
    }

    @Test("snapshot omits text entry values and bounds text metadata")
    func privacy() throws {
        let (window, _, _) = try fixture()
        defer { window.isHidden = true }
        let field = UITextField(frame: CGRect(x: 20, y: 120, width: 200, height: 40))
        field.text = "secret"; field.isSecureTextEntry = true
        field.accessibilityLabel = String(repeating: "x", count: 1000)
        window.rootViewController?.view.addSubview(field)
        let node = try #require(TKPickerSessionManager().select(field).selection?.target)
        #expect(node.value == nil)
        #expect((node.label?.count ?? 0) <= 256)
    }

    @Test("selection does not retain the selected view")
    func weakLifetime() throws {
        let (window, _, _) = try fixture()
        defer { window.isHidden = true }
        let manager = TKPickerSessionManager()
        weak var reference: UILabel?
        autoreleasepool {
            let label = UILabel(frame: CGRect(x: 20, y: 120, width: 100, height: 40))
            label.text = "Temporary"; reference = label
            window.rootViewController?.view.addSubview(label)
            _ = manager.select(label)
            label.removeFromSuperview()
        }
        #expect(reference == nil)
        #expect(manager.status().state == "stale")
    }

    @Test("a higher business window invalidates the current selection")
    func foregroundWindowChanged() throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        let manager = TKPickerSessionManager()
        let result = manager.select(button)
        let selection = try #require(result.selection)
        let upper: UIWindow
        if let scene = window.windowScene { upper = UIWindow(windowScene: scene) }
        else { upper = UIWindow(frame: window.frame) }
        upper.frame = window.frame
        upper.rootViewController = UIViewController()
        upper.windowLevel = .alert; upper.isHidden = false
        _ = TKObjectRegistry.shared.register(upper)
        defer { upper.isHidden = true }
        #expect(manager.status().state == "stale")
        #expect(manager.performGuardedTap(.init(runtimeInstanceID: result.runtimeInstanceID, selectionID: selection.id, revision: result.revision)).error?.code == "selection_stale")
        #expect(counter.count == 0)
        manager.shutdown()
        #expect(manager.selectedView == nil)
        #expect(manager.status().state == "none")
    }

    @Test("SDK inspector window is absent from hit testing, AX, hierarchy and ordinary screenshots")
    func overlayIsolation() async throws {
        let (window, button, counter) = try fixture()
        defer { window.isHidden = true }
        window.rootViewController?.view.backgroundColor = .white
        window.layoutIfNeeded()
        let beforeScreenshot = captureCurrentScreenshotData()
        let beforeHit = performHitTest(.init(x: 40, y: 60))
        let overlay: PickerIsolationWindow
        if let scene = window.windowScene { overlay = PickerIsolationWindow(windowScene: scene) }
        else { overlay = PickerIsolationWindow(frame: window.frame) }
        overlay.frame = window.frame
        overlay.rootViewController = UIViewController()
        overlay.rootViewController?.view.backgroundColor = .magenta
        overlay.windowLevel = UIWindow.Level(rawValue: 3000)
        overlay.isHidden = false
        _ = TKObjectRegistry.shared.register(overlay)
        defer { overlay.isHidden = true }
        #expect(keyWindows().first === window)
        #expect(!keyWindows().contains { $0 === overlay })
        #expect(TKPickerSessionManager.candidate(at: CGPoint(x: 40, y: 60), in: overlay) == nil)
        #expect(performHitTest(.init(x: 40, y: 60)).node?.targetOID == beforeHit.node?.targetOID)
        #expect(!beforeScreenshot.data.isEmpty)
        #expect(captureCurrentScreenshotData().data == beforeScreenshot.data)
        var context = AXBuildContext()
        let ax = buildBudgetedAXWindows(keyWindows(), context: &context)
        #expect(ax.contains { $0.targetOID == TKObjectRegistry.shared.register(window) })
        #expect(!ax.contains { $0.targetOID == TKObjectRegistry.shared.register(overlay) })
        let hierarchy = await TKHierarchyBuilder.buildHierarchy()
        #expect(hierarchy.contains { $0.viewObject?.oid == TKObjectRegistry.shared.register(window) })
        #expect(!hierarchy.contains { $0.viewObject?.oid == TKObjectRegistry.shared.register(overlay) })
        let manager = TKPickerSessionManager()
        let selected = manager.select(button)
        let selection = try #require(selected.selection)
        #expect(manager.performGuardedTap(.init(runtimeInstanceID: selected.runtimeInstanceID, selectionID: selection.id, revision: selected.revision)).ok)
        #expect(counter.count == 1)
    }

    @Test("node navigation supports children and siblings with visible boundaries")
    func navigationDirections() throws {
        let (window, _, _) = try fixture()
        defer { window.isHidden = true }
        let group = UIView(frame: CGRect(x: 10, y: 180, width: 290, height: 100))
        window.rootViewController?.view.addSubview(group)
        let children = (0..<3).map { index in
            let child = UILabel(frame: CGRect(x: 10 + index * 90, y: 20, width: 70, height: 40))
            child.text = "Node \(index)"
            group.addSubview(child)
            return child
        }
        let manager = TKPickerSessionManager()
        _ = manager.select(children[0])
        #expect(!manager.canNavigate(.previousSibling))
        let firstRevision = manager.status().revision
        #expect(!manager.navigate(.previousSibling).ok)
        #expect(manager.status().revision == firstRevision)
        #expect(manager.navigate(.nextSibling).ok)
        #expect(manager.selectedView === children[1])
        #expect(manager.status().revision > firstRevision)
        #expect(manager.navigate(.previousSibling).ok)
        #expect(manager.selectedView === children[0])
        children[1].isHidden = true
        #expect(manager.navigate(.nextSibling).ok)
        #expect(manager.selectedView === children[2])
        #expect(!manager.canNavigate(.nextSibling))
        #expect(!manager.canNavigate(.child))
        #expect(manager.navigate(.parent).ok)
        #expect(manager.selectedView === group)
        #expect(manager.navigate(.child).ok)
        #expect(manager.selectedView === children[2])
        _ = manager.clear()
        #expect(!manager.canNavigate(.child))
        #expect(!manager.navigate(.nextSibling).ok)
    }

    @Test("parent-child navigation remembers the last child at each level")
    func navigationRemembersNestedChildren() throws {
        let (window, _, _) = try fixture()
        defer { window.isHidden = true }
        let (group, children) = navigationFixture(in: window)
        let nested = UIView(frame: CGRect(x: 4, y: 4, width: 30, height: 25))
        children[2].addSubview(nested)
        let manager = TKPickerSessionManager()
        #expect(manager.select(nested).ok)
        #expect(manager.navigate(.parent).ok)
        #expect(manager.selectedView === children[2])
        #expect(manager.navigate(.parent).ok)
        #expect(manager.selectedView === group)
        #expect(manager.navigate(.child).ok)
        #expect(manager.selectedView === children[2])
        #expect(manager.navigate(.child).ok)
        #expect(manager.selectedView === nested)
    }

    @Test("a new direct selection and clear reset navigation memory")
    func navigationMemoryReset() throws {
        let (window, _, _) = try fixture()
        defer { window.isHidden = true }
        let (group, children) = navigationFixture(in: window)
        let manager = TKPickerSessionManager()
        for shouldClear in [false, true] {
            #expect(manager.select(children[2]).ok)
            #expect(manager.navigate(.parent).ok)
            if shouldClear { _ = manager.clear() }
            #expect(manager.select(group).ok)
            #expect(manager.navigate(.child).ok)
            #expect(manager.selectedView === children[0])
        }
    }

    @Test("hidden, detached, reparented, repurposed and obscured remembered children fall back to the first visible child")
    func navigationMemoryInvalidation() throws {
        let (window, _, _) = try fixture()
        defer { window.isHidden = true }
        let (group, children) = navigationFixture(in: window)
        let manager = TKPickerSessionManager()
        for mutation in 0..<5 {
            children[2].isHidden = false
            children[2].accessibilityIdentifier = nil
            group.addSubview(children[2])
            #expect(manager.select(children[2]).ok)
            #expect(manager.navigate(.parent).ok)
            switch mutation {
            case 0: children[2].isHidden = true
            case 1: children[2].removeFromSuperview()
            case 2: window.rootViewController?.view.addSubview(children[2])
            case 3: children[2].accessibilityIdentifier = "Repurposed"
            default: group.addSubview(UIView(frame: children[2].frame))
            }
            #expect(manager.canNavigate(.child))
            #expect(manager.navigate(.child).ok)
            #expect(manager.selectedView === children[0])
        }
    }

    @Test("navigation memory does not retain a removed business child")
    func navigationMemoryWeakLifetime() throws {
        let (window, _, _) = try fixture()
        defer { window.isHidden = true }
        let (group, children) = navigationFixture(in: window)
        let manager = TKPickerSessionManager()
        weak var reference: UIView?
        autoreleasepool {
            let temporary = UIView(frame: CGRect(x: 240, y: 70, width: 30, height: 25))
            reference = temporary
            group.addSubview(temporary)
            #expect(manager.select(temporary).ok)
            #expect(manager.navigate(.parent).ok)
            temporary.removeFromSuperview()
        }
        #expect(reference == nil)
        #expect(manager.navigate(.child).ok)
        #expect(manager.selectedView === children[0])
    }

    private func navigationFixture(in window: UIWindow) -> (UIView, [UIView]) {
        let group = UIView(frame: CGRect(x: 10, y: 180, width: 290, height: 110))
        window.rootViewController?.view.addSubview(group)
        let children = (0..<3).map { index in
            let child = UIView(frame: CGRect(x: 10 + index * 90, y: 20, width: 70, height: 40))
            group.addSubview(child)
            return child
        }
        return (group, children)
    }

    private func fixture() throws -> (UIWindow, UIButton, PickerCounter) {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: 40, width: 150, height: 50)
        button.setTitle("Run", for: .normal)
        let counter = PickerCounter()
        button.addTarget(counter, action: #selector(PickerCounter.tap), for: .touchUpInside)
        window.rootViewController?.view.addSubview(button)
        return (window, button, counter)
    }
}
}

@MainActor
private final class PickerIsolationWindow: UIWindow, TKRuntimeInspectorOverlayWindow {}

@MainActor
private final class PickerCounter: NSObject {
    var count = 0
    @objc func tap() { count += 1 }
}
#endif
