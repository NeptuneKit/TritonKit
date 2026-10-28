import Testing
@testable import TritonKit
import TritonKitShared

#if canImport(UIKit)
import UIKit

extension TKUIKitWindowTests {
@MainActor
@Suite(.serialized)
struct TKRuntimeBarButtonTests {
    final class InertControl: UIControl {
        override func accessibilityActivate() -> Bool { false }
    }
    final class ActivatingControl: UIControl {
        var calls = 0
        override func accessibilityActivate() -> Bool { calls += 1; return true }
    }
    final class ActionRecorder: NSObject {
        var calls = 0
        @objc func submit(_ sender: Any?) { calls += 1 }
    }

    @Test("Real page sheet bar item refuses safely or uses a public activation without hitting background content")
    func pageSheetBarItem() async throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        defer { window.isHidden = true }
        let presenter = try #require(window.rootViewController)
        let background = ActionRecorder()
        let backgroundButton = UIButton(type: .system)
        backgroundButton.setTitle("Submit", for: .normal)
        backgroundButton.frame = CGRect(x: 20, y: 60, width: 100, height: 44)
        backgroundButton.addTarget(background, action: #selector(ActionRecorder.submit(_:)), for: .touchUpInside)
        presenter.view.addSubview(backgroundButton)
        let submitted = ActionRecorder()
        let content = UIViewController()
        content.view.backgroundColor = .systemBackground
        content.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit", style: .plain, target: submitted, action: #selector(ActionRecorder.submit(_:)))
        let sheet = UINavigationController(rootViewController: content)
        sheet.modalPresentationStyle = .pageSheet
        await withCheckedContinuation { continuation in
            presenter.present(sheet, animated: false) { continuation.resume() }
        }
        try #require(sheet.view.window === window)
        try #require(backgroundButton.window === window)
        sheet.view.layoutIfNeeded()
        let label = try #require(allSubviews(of: sheet.navigationBar, matching: UILabel.self).first { $0.text == "Submit" })
        let result = performTap(.tap(targetOID: TKObjectRegistry.shared.register(label)))
        if result.ok {
            #expect(submitted.calls == 1)
        } else {
            #expect(result.error?.code == "unsupported_capability")
            #expect(result.strategy == "bar-button-action-unsupported")
            #expect(submitted.calls == 0)
        }
        #expect(background.calls == 0)
        await withCheckedContinuation { continuation in
            sheet.dismiss(animated: false) { continuation.resume() }
        }
    }

    @Test("Unmapped navigation item control returns a typed refusal with explicit host recovery")
    func navigationRefusal() throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        defer { window.isHidden = true }
        let bar = UINavigationBar(frame: CGRect(x: 0, y: 40, width: 390, height: 44))
        window.rootViewController!.view.addSubview(bar)
        let control = InertControl(frame: CGRect(x: 280, y: 0, width: 80, height: 44))
        let label = UILabel(frame: control.bounds)
        label.text = "Submit"
        control.addSubview(label)
        bar.addSubview(control)
        try #require(control.window === window)
        let result = performTap(.tap(targetOID: TKObjectRegistry.shared.register(label)))
        #expect(!result.ok)
        #expect(result.error?.code == "unsupported_capability")
        #expect(result.strategy == "bar-button-action-unsupported")
        #expect(result.error?.hint?.contains("explicit simulator") == true)
        #expect(result.error?.hint?.contains("Runner") == true)
    }

    @Test("Toolbar control refusal preserves matched identity")
    func toolbarRefusal() {
        let bar = UIToolbar()
        let control = InertControl()
        bar.addSubview(control)
        let result = performControlTap(control, request: .tap(targetOID: nil), action: "tap", matchedView: nil, strategy: nil)
        #expect(result.error?.code == "unsupported_capability")
        #expect(result.strategy == "bar-button-action-unsupported")
        #expect(result.activationOID == TKObjectRegistry.shared.register(control))
    }

    @Test("Navigation bar public accessibility activation remains available")
    func publicActivation() {
        let bar = UINavigationBar()
        let control = ActivatingControl()
        bar.addSubview(control)
        let result = performControlTap(control, request: .tap(targetOID: nil), action: "tap", matchedView: nil, strategy: nil)
        #expect(result.ok)
        #expect(control.calls == 1)
    }
}
}
#endif
