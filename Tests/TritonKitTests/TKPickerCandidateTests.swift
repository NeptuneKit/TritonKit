import Testing
@testable import TritonKit
#if canImport(UIKit)
import UIKit

extension TKUIKitWindowTests {
@Suite(.serialized) @MainActor
struct TKPickerCandidateTests {
    @Test("candidate walks noninteractive text using window coordinates and skips hidden siblings")
    func labelHit() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 500)); window.isHidden = false
        defer { window.isHidden = true }
        let container = UIView(frame: CGRect(x: 20, y: 30, width: 100, height: 100))
        let label = UILabel(frame: CGRect(x: 10, y: 15, width: 60, height: 30))
        window.addSubview(container); container.addSubview(label)
        let hidden = UIView(frame: container.bounds); hidden.isHidden = true; container.addSubview(hidden)
        #expect(TKPickerSessionManager.candidate(at: CGPoint(x: 40, y: 55), in: window) === label)
        #expect(TKPickerSessionManager.candidate(at: CGPoint(x: 290, y: 490), in: window) == nil)
    }

    @Test("candidate honors clipping, transforms and sibling z-order")
    func clippingAndTransform() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 500)); window.isHidden = false
        defer { window.isHidden = true }
        let container = UIView(frame: CGRect(x: 20, y: 20, width: 50, height: 50))
        let child = UILabel(frame: CGRect(x: 40, y: 0, width: 80, height: 40))
        window.addSubview(container); container.addSubview(child)
        #expect(TKPickerSessionManager.candidate(at: CGPoint(x: 100, y: 40), in: window) === child)
        container.clipsToBounds = true
        #expect(TKPickerSessionManager.candidate(at: CGPoint(x: 100, y: 40), in: window) == nil)
        container.clipsToBounds = false
        container.transform = CGAffineTransform(translationX: 50, y: 50)
        #expect(TKPickerSessionManager.candidate(at: CGPoint(x: 150, y: 90), in: window) === child)
        let upper = UIView(frame: CGRect(x: 100, y: 50, width: 100, height: 100)); window.addSubview(upper)
        #expect(TKPickerSessionManager.candidate(at: CGPoint(x: 150, y: 90), in: window) === upper)
        container.layer.zPosition = 10
        #expect(TKPickerSessionManager.candidate(at: CGPoint(x: 150, y: 90), in: window) === child)
    }
}
}
#endif
