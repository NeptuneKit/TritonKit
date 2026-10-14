import Testing
import TritonKitShared
@testable import TritonKit

@Suite
struct TKRuntimeForegroundWindowPolicyTests {
    @Test("background and inactive scene windows cannot become action surfaces")
    func backgroundScene() {
        let facts = [fact(0, state: .background), fact(1, state: .foregroundInactive), fact(2, state: .foregroundActive)]
        #expect(orderedRuntimeForegroundWindowIndices(facts, hasSceneEnvironment: true) == [2])
    }

    @Test("a scene environment cannot fall back to no-scene registry windows")
    func noBackgroundFallback() {
        #expect(orderedRuntimeForegroundWindowIndices([fact(0, state: .background), fact(1)], hasSceneEnvironment: true).isEmpty)
    }

    @Test("higher foreground window wins even when the underlying window is key")
    func higherNonKeyWindow() {
        let facts = [fact(0, state: .foregroundActive, key: true), fact(1, state: .foregroundActive, level: 2000)]
        #expect(orderedRuntimeForegroundWindowIndices(facts, hasSceneEnvironment: true) == [1, 0])
    }

    @Test("hostless fallback admits only visible no-scene windows")
    func hostlessFallback() {
        let facts = [fact(0), fact(1, state: .background), fact(2, visible: false)]
        #expect(orderedRuntimeForegroundWindowIndices(facts, hasSceneEnvironment: false) == [0])
    }

    @Test("equal-level windows prefer key then preserve stable source order")
    func equalLevels() {
        let facts = [fact(0), fact(1, key: true), fact(2)]
        #expect(orderedRuntimeForegroundWindowIndices(facts, hasSceneEnvironment: false) == [1, 0, 2])
    }

    @Test("only the exact observed UIKit input overlay identity can be excluded")
    func inputOverlayIdentity() {
        #expect(isRuntimeKnownInputOverlay(windowClassName: "UITextEffectsWindow", rootClassName: "UITrackingElementWindowController", windowDefinedByUIKit: true, rootDefinedByUIKit: true))
        for (window, root, systemWindow, systemRoot) in [
            ("AppUITextEffectsWindow", "UITrackingElementWindowController", true, true),
            ("UITextEffectsWindow", "AppTrackingController", true, true),
            ("UITextEffectsWindow", "UITrackingElementWindowController", false, true),
            ("UITextEffectsWindow", "UITrackingElementWindowController", true, false),
            ("UnknownSystemWindow", "UITrackingElementWindowController", true, true)
        ] {
            #expect(!isRuntimeKnownInputOverlay(windowClassName: window, rootClassName: root, windowDefinedByUIKit: systemWindow, rootDefinedByUIKit: systemRoot))
        }
        #expect(!isRuntimeKnownInputOverlay(windowClassName: "UITextEffectsWindow", rootClassName: nil, windowDefinedByUIKit: true, rootDefinedByUIKit: true))
    }

    @Test("known input overlay does not outrank business windows while unknown high windows still do")
    func inputOverlayRanking() {
        var overlay = fact(1, state: .foregroundActive, level: 1)
        overlay.isKnownInputOverlay = true
        let business = fact(0, state: .foregroundActive, key: true)
        let highBusiness = fact(2, state: .foregroundActive, level: 2000)
        #expect(orderedRuntimeForegroundWindowIndices([business, overlay, highBusiness], hasSceneEnvironment: true) == [2, 0])
        #expect(orderedRuntimeForegroundWindowIndices([fact(0, state: .background), overlay], hasSceneEnvironment: true).isEmpty)
    }

    private func fact(_ index: Int, state: RuntimeForegroundSceneState? = nil, visible: Bool = true, level: Double = 0, key: Bool = false) -> RuntimeForegroundWindowFact {
        RuntimeForegroundWindowFact(index: index, sceneState: state, visible: visible, level: level, key: key)
    }
}

#if canImport(UIKit)
import UIKit
#if canImport(WebKit)
import WebKit
#endif

extension TKUIKitWindowTests {
@Suite(.serialized)
@MainActor
struct TKRuntimeForegroundTargetTests {
    @Test("detached OIDs cannot bypass text and semantic-control resolution")
    func detachedResolvers() {
        let field = UITextField(); field.text = "Before"
        let fieldOID = TKObjectRegistry.shared.register(field)
        #expect(!performClear(.clear(targetOID: fieldOID)).ok)
        #expect(field.text == "Before")
        let toggle = UISwitch()
        let toggleOID = TKObjectRegistry.shared.register(toggle)
        #expect(resolveControl(TKSemanticActionRequest(action: .setSwitch, targetOID: toggleOID), as: UISwitch.self) == nil)
    }

    @Test("a real keyboard must not block the focused business text target")
    func focusedBusinessTarget() async throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { window.isHidden = true }
        let field = UITextField(frame: CGRect(x: 20, y: 20, width: 160, height: 40))
        field.text = "Before"
        window.rootViewController?.view.addSubview(field)
        try #require(field.becomeFirstResponder())
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && !UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).contains(where: { $0 !== window && !$0.isHidden && $0.windowLevel > window.windowLevel }) {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        // Require a real higher window before exercising the continuous
        // focus -> input route; a timeout cannot count as keyboard evidence.
        try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).contains { $0 !== window && !$0.isHidden && $0.windowLevel > window.windowLevel })
        #expect(runtimeForegroundTargetFailure(for: field) == nil)
        #expect(performClear(.clear(targetOID: TKObjectRegistry.shared.register(field))).ok)
        #expect(field.text == "")
    }

    @Test("higher non-key foreground window rejects underlying OIDs")
    func higherWindow() throws {
        let base = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let button = UIButton(type: .system); button.frame = CGRect(x: 20, y: 20, width: 100, height: 40)
        base.rootViewController?.view.addSubview(button)
        let overlay: UIWindow
        if let scene = base.windowScene { overlay = UIWindow(windowScene: scene) }
        else { overlay = UIWindow(frame: base.frame) }
        overlay.frame = base.frame
        overlay.rootViewController = UIViewController()
        overlay.windowLevel = .alert
        overlay.isHidden = false
        _ = TKObjectRegistry.shared.register(overlay)
        defer { overlay.endEditing(true); overlay.isHidden = true; base.isHidden = true }
        try #require(button.window === base)
        #expect(keyWindows().first === overlay)
        #expect(resolveView(targetOID: TKObjectRegistry.shared.register(button), x: nil, y: nil).view == nil)
    }

    @Test("mounted modal blocks old OID routes and dismissal restores them")
    func modalAndDismissal() async throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { window.isHidden = true }
        let root = try #require(window.rootViewController)
        let field = UITextField(frame: CGRect(x: 20, y: 20, width: 160, height: 40)); field.text = "Before"
        let toggle = UISwitch(frame: CGRect(x: 20, y: 80, width: 80, height: 40))
        root.view.addSubview(field); root.view.addSubview(toggle)
        let layout = UICollectionViewFlowLayout(); layout.itemSize = CGSize(width: 80, height: 80)
        let collection = UICollectionView(frame: CGRect(x: 20, y: 140, width: 100, height: 100), collectionViewLayout: layout)
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        let dataSource = ForegroundCollectionDataSource(); collection.dataSource = dataSource
        root.view.addSubview(collection); collection.reloadData(); collection.layoutIfNeeded()
        defer { withExtendedLifetime(dataSource) {} }
        let cell = try #require(collection.cellForItem(at: IndexPath(item: 0, section: 0)))
        let point = cell.convert(CGPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)
        let collectionRequest = TKInputRequest.tap(x: Double(point.x), y: Double(point.y))
        try #require(collectionCellContaining(request: collectionRequest) === cell, "Real background collection fixture must be actionable before presenting")
        let fieldOID = TKObjectRegistry.shared.register(field)
        let toggleOID = TKObjectRegistry.shared.register(toggle)
        let modal = UIViewController(); modal.modalPresentationStyle = .overFullScreen
        let modalField = UITextField(frame: field.frame); modalField.text = "Modal"
        modal.view.backgroundColor = .white; modal.view.addSubview(modalField)
        try await completed { completion in root.present(modal, animated: false, completion: completion) }
        try #require(modal.presentingViewController != nil && modal.view.window === window, "Presentation must complete and mount the actual modal")
        try #require(field.window === window, "Background OID must remain attached to expose the same-window bug")
        #expect(resolveView(targetOID: fieldOID, x: nil, y: nil).view == nil)
        #expect(!performClear(.clear(targetOID: fieldOID)).ok)
        #expect(field.text == "Before")
        #expect(collectionCellContaining(request: collectionRequest) == nil)
        #expect(resolveControl(TKSemanticActionRequest(action: .setSwitch, targetOID: toggleOID), as: UISwitch.self) == nil)
        #expect(performClear(.clear(targetOID: TKObjectRegistry.shared.register(modalField))).ok)
        try await completed { completion in modal.dismiss(animated: false, completion: completion) }
        try #require(root.presentedViewController == nil && modal.view.window == nil, "Dismissal must complete before unblocking the previous root")
        #expect(resolveView(targetOID: fieldOID, x: nil, y: nil).view === field)
        #expect(performClear(.clear(targetOID: fieldOID)).ok)
        #expect(resolveControl(TKSemanticActionRequest(action: .setSwitch, targetOID: toggleOID), as: UISwitch.self) === toggle)
    }

    #if canImport(WebKit)
    @Test("real WebView mutation gate rejects a mounted modal background and recovers after dismissal")
    func webViewModal() async throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { window.isHidden = true }
        let root = try #require(window.rootViewController)
        let webView = WKWebView(frame: root.view.bounds)
        root.view.addSubview(webView)
        webView.loadHTMLString("<html data-triton-form-input='1'><input id='field' value='Before'><button id='button' onclick='window.clicks += 1'>Go</button><script>window.clicks=0; window.__tritonBridge={methods:{update:function(){document.getElementById('field').value='Changed';}}};</script></html>", baseURL: nil)
        let deadline = Date().addingTimeInterval(5)
        var ready = false
        while Date() < deadline {
            ready = (try? await evaluateDOM("document.readyState === 'complete' && !!document.getElementById('field')", in: webView) as? Bool) == true
            if ready { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try #require(ready && webView.window === window, "Fixture must load the real form and mount the WebView")
        try requireForegroundWebViewMutation(webView)
        let webViewID = "ios-webkit:\(TKObjectRegistry.shared.register(webView))"
        try #require(currentWebViewListResponse().candidates.contains { $0.webViewID == webViewID }, "The actual producer must enumerate the mounted fixture before testing foreground rejection")
        let modal = UIViewController(); modal.modalPresentationStyle = .overFullScreen
        modal.view.backgroundColor = .white
        try await completed { completion in root.present(modal, animated: false, completion: completion) }
        try #require(modal.view.window === window && webView.window === window, "The background WebView must remain attached underneath the mounted modal")
        do {
            try requireForegroundWebViewMutation(webView)
            Issue.record("The modal background must reject WebView mutation")
        } catch let error as TKWebViewSelectionError {
            #expect(error.detail.code == .webViewElementNotInteractable)
        }
        #expect(currentWebViewListResponse().candidates.contains { $0.webViewID == webViewID })
        let tap = await currentWebViewTapResponse(TKWebViewTapRequest(webViewID: webViewID, selector: "#button"))
        let focus = await currentWebViewFocusResponse(TKWebViewFocusRequest(webViewID: webViewID, selector: "#field"))
        let input = await currentWebViewFormInputResponse(TKWebViewFormInputRequest(webViewID: webViewID, selector: "#field", mode: .setText, text: "private-secret", secure: true))
        let bridge = await performWebViewBridgeCall(TKWebViewBridgeCallRequest(webViewID: webViewID, method: "update"))
        #expect(!tap.ok && tap.error?.code == .webViewElementNotInteractable)
        #expect(!focus.ok && focus.error?.code == .webViewElementNotInteractable)
        #expect(!input.ok && input.error?.code == .webViewElementNotInteractable)
        #expect(!bridge.ok && bridge.error?.code == .webViewElementNotInteractable)
        #expect(try await evaluateDOM("document.getElementById('field').value", in: webView) as? String == "Before")
        #expect(try await evaluateDOM("window.clicks", in: webView) as? Int == 0)
        try await completed { completion in modal.dismiss(animated: false, completion: completion) }
        try #require(modal.view.window == nil && root.presentedViewController == nil)
        try requireForegroundWebViewMutation(webView)
        let result = await currentWebViewFormInputResponse(TKWebViewFormInputRequest(webViewID: webViewID, selector: "#field", mode: .setText, text: "Updated"))
        #expect(result.ok)
        #expect(try await evaluateDOM("document.getElementById('field').value", in: webView) as? String == "Updated")
    }

    private func evaluateDOM(_ script: String, in webView: WKWebView) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value ?? NSNull()) }
            }
        }
    }
    #endif

    private func completed(_ action: (@escaping () -> Void) -> Void) async throws {
        let succeeded = await withCheckedContinuation { continuation in
            var resumed = false
            let timeout = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !resumed { resumed = true; continuation.resume(returning: false) }
            }
            action {
                if !resumed { resumed = true; timeout.cancel(); continuation.resume(returning: true) }
            }
        }
        try #require(succeeded, "UIKit must call the actual presentation/dismissal completion; timeout is not acceptance")
    }
}
}

private final class ForegroundCollectionDataSource: NSObject, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 1 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    }
}
#endif
