#if canImport(UIKit)
import UIKit

/// A non-key, SDK-owned surface. Empty space and decorations never intercept
/// business touches; an already captured drag stays entirely within the dot.
@MainActor
final class TKPickerOverlayWindow: UIWindow, TKRuntimeInspectorOverlayWindow {
    @available(iOS 15.0, *)
    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let controller = rootViewController as? TKPickerOverlayViewController else { return nil }
        let local = controller.view.convert(point, from: self)
        guard controller.acceptsTouch(at: local) else { return nil }
        return super.hitTest(point, with: event)
    }
}

@MainActor
final class TKPickerOverlayCoordinator {
    private let manager: TKPickerSessionManager
    private var windows: [ObjectIdentifier: TKPickerOverlayWindow] = [:]
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    private var running = false

    init(manager: TKPickerSessionManager) { self.manager = manager }

    func start() {
        guard TritonKit.isRuntimeEnabled, !running else { return }
        running = true
        for name in [UIScene.didActivateNotification, UIScene.willDeactivateNotification,
                     UIScene.didDisconnectNotification, UIApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            })
        }
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        refresh()
    }

    func stop() {
        running = false
        refreshTimer?.invalidate()
        refreshTimer = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        for window in windows.values {
            (window.rootViewController as? TKPickerOverlayViewController)?.cancelInteraction()
            window.isHidden = true
            window.rootViewController = nil
        }
        windows.removeAll()
    }

    func show(in scene: UIWindowScene) {
        guard TritonKit.isRuntimeEnabled, running, scene.activationState == .foregroundActive else { return }
        let id = ObjectIdentifier(scene)
        guard windows[id] == nil else { return }
        let controller = TKPickerOverlayViewController(manager: manager)
        controller.businessWindowProvider = { [weak scene] in
            guard let scene, scene.activationState == .foregroundActive else { return nil }
            // Match runtime's action authority. A different simultaneously active
            // scene is not silently promoted into an executable coordinate space.
            guard let window = keyWindows().first, window.windowScene === scene else { return nil }
            return window
        }
        let window = TKPickerOverlayWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.backgroundColor = .clear
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.rootViewController = controller
        windows[id] = window
        window.isHidden = false // Deliberately never makeKeyAndVisible().
    }

    private func refresh() {
        guard running else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let active = Set(scenes.map { ObjectIdentifier($0) })
        for id in Array(windows.keys) where !active.contains(id) {
            let window = windows.removeValue(forKey: id)
            (window?.rootViewController as? TKPickerOverlayViewController)?.cancelInteraction()
            window?.isHidden = true
            window?.rootViewController = nil
        }
        scenes.forEach { show(in: $0) }
        for window in windows.values {
            (window.rootViewController as? TKPickerOverlayViewController)?.refreshSelection()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
#endif
