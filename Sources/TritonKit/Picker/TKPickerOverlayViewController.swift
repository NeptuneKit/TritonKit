#if canImport(UIKit)
import UIKit

@MainActor
final class TKPickerOverlayViewController: UIViewController, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate {
    let dot = UIButton(type: .custom)
    var businessWindowProvider: (() -> UIWindow?)?
    private let manager: TKPickerSessionManager
    private let outline = UIView()
    private let caption = UILabel()
    private let menu = UIView()
    private var settingsNavigation: UINavigationController?
    private var pendingSettingsDismissal: (animated: Bool, completion: (() -> Void)?)?
    private var presentation = TritonKit.PickerConfiguration()
    private let guides = CAShapeLayer()
    private let crosshair = CAShapeLayer()
    private let magnifier = TKPickerMagnifierView()
    private let haptic = UISelectionFeedbackGenerator()
    private var guideDwellOrigin: CGPoint?
    private var guideDwellStartedAt: TimeInterval = 0
    private var lastFeedbackAt: TimeInterval = -.infinity
    private var menuIsPlaced = false
    private var navigationButtons: [(UIButton, TKPickerSessionManager.NavigationDirection)] = []
    private let accent = UIColor(red: 0.12, green: 0.83, blue: 0.72, alpha: 1)
    private let surface = UIColor(red: 0.08, green: 0.12, blue: 0.15, alpha: 0.96)
    private weak var candidate: UIView?
    private var picking = false
    private var movingEntry = false
    private var entryOrigin = CGPoint.zero
    private var placedEntry = false
    private var lastPickPoint: CGPoint?

    private let clock: () -> TimeInterval
    private let selectionFeedback: (() -> Void)?
    private let onHide: (() -> Void)?

    init(manager: TKPickerSessionManager, clock: @escaping () -> TimeInterval = { CACurrentMediaTime() },
         selectionFeedback: (() -> Void)? = nil, onHide: (() -> Void)? = nil) {
        self.clock = clock
        self.selectionFeedback = selectionFeedback
        self.onHide = onHide
        self.manager = manager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
        guides.name = "triton.picker.guides"
        guides.strokeColor = accent.withAlphaComponent(0.42).cgColor
        guides.fillColor = UIColor.clear.cgColor
        guides.lineWidth = 1
        guides.lineDashPattern = [3, 3]
        guides.isHidden = true
        view.layer.addSublayer(guides)
        outline.isUserInteractionEnabled = false
        outline.accessibilityIdentifier = "triton.picker.preview"
        outline.layer.borderWidth = 2
        outline.layer.borderColor = accent.cgColor
        outline.layer.cornerRadius = 8
        outline.backgroundColor = accent.withAlphaComponent(0.10)
        outline.isHidden = true
        view.addSubview(outline)
        caption.accessibilityIdentifier = "triton.picker.caption"
        caption.font = .systemFont(ofSize: 12, weight: .semibold)
        caption.textColor = .white
        caption.backgroundColor = surface
        caption.layer.cornerRadius = 12
        caption.layer.cornerCurve = .continuous
        caption.layer.borderWidth = 0.5
        caption.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        caption.clipsToBounds = true
        caption.numberOfLines = 2
        caption.lineBreakMode = .byTruncatingTail
        caption.textAlignment = .center
        caption.isUserInteractionEnabled = false
        caption.text = "拖动选控件 · 长按移动"
        view.addSubview(caption)
        view.addSubview(magnifier)
        dot.frame.size = CGSize(width: 44, height: 44)
        dot.setImage(UIImage(systemName: "viewfinder", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)), for: .normal)
        dot.tintColor = accent
        dot.backgroundColor = surface
        dot.layer.cornerRadius = 22
        dot.layer.borderWidth = 1
        dot.layer.borderColor = accent.withAlphaComponent(0.65).cgColor
        dot.layer.shadowColor = UIColor.black.cgColor
        dot.layer.shadowOpacity = 0.20
        dot.layer.shadowRadius = 8
        dot.layer.shadowOffset = CGSize(width: 0, height: 3)
        crosshair.name = "triton.picker.crosshair"
        crosshair.frame = dot.bounds
        crosshair.strokeColor = accent.cgColor
        crosshair.fillColor = UIColor.clear.cgColor
        crosshair.lineWidth = 2
        crosshair.lineCap = .round
        crosshair.shadowColor = UIColor.black.cgColor
        crosshair.shadowOpacity = 0.8
        crosshair.shadowRadius = 1
        crosshair.shadowOffset = .zero
        let cross = UIBezierPath()
        for (start, end) in [(CGPoint(x: 3, y: 22), CGPoint(x: 16, y: 22)),
                             (CGPoint(x: 28, y: 22), CGPoint(x: 41, y: 22)),
                             (CGPoint(x: 22, y: 3), CGPoint(x: 22, y: 16)),
                             (CGPoint(x: 22, y: 28), CGPoint(x: 22, y: 41))] {
            cross.move(to: start); cross.addLine(to: end)
        }
        cross.append(UIBezierPath(ovalIn: CGRect(x: 19, y: 19, width: 6, height: 6)))
        crosshair.path = cross.cgPath
        crosshair.isHidden = true
        dot.layer.addSublayer(crosshair)
        dot.accessibilityLabel = "Triton 控件选择器"
        dot.accessibilityHint = "拖动实时预览控件，松手选中，长按拖动移动圆球，轻点打开 TritonKit SDK 设置"
        dot.accessibilityIdentifier = "triton.picker.dot"
        dot.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panEntry(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        pan.delegate = self
        dot.addGestureRecognizer(pan)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressEntry(_:)))
        press.minimumPressDuration = 0.4
        press.allowableMovement = 10
        press.cancelsTouchesInView = true
        press.delegate = self
        dot.addGestureRecognizer(press)
        view.addSubview(dot)
        menu.accessibilityIdentifier = "triton.picker.navigation"
        menu.backgroundColor = .clear
        menu.isHidden = true
        let actions: [(String, String, Selector, TKPickerSessionManager.NavigationDirection?)] = [
            ("选择父级", "arrow.up", #selector(selectParent), .parent),
            ("选择子级", "arrow.down", #selector(selectChild), .child),
            ("前一同级", "arrow.left", #selector(selectPrevious), .previousSibling),
            ("后一同级", "arrow.right", #selector(selectNext), .nextSibling),
            ("收起导航", "xmark", #selector(toggleMenu), nil),
            ("清除标记", "trash", #selector(clearSelection), nil)
        ]
        for (title, _, selector, direction) in actions {
            let button = UIButton(type: .system)
            button.accessibilityLabel = title
            let labels = ["选择父级": "↑\n父级", "选择子级": "↓\n子级", "前一同级": "←\n前同级", "后一同级": "→\n后同级", "收起导航": "×", "清除标记": "清除标记"]
            button.setTitle(labels[title], for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: title == "收起导航" ? 23 : 12, weight: .semibold)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.setTitleColor(title == "清除标记" ? .systemPink : accent, for: .normal)
            button.setTitleColor(.gray, for: .disabled)
            button.backgroundColor = surface
            button.layer.cornerRadius = title == "收起导航" ? 22 : 13
            button.layer.cornerCurve = .continuous
            button.layer.borderWidth = 0.5
            button.layer.borderColor = accent.withAlphaComponent(0.3).cgColor
            let frames: [String: CGRect] = [
                "选择父级": CGRect(x: 52, y: 4, width: 44, height: 44),
                "选择子级": CGRect(x: 52, y: 100, width: 44, height: 44),
                "前一同级": CGRect(x: 4, y: 52, width: 44, height: 44),
                "后一同级": CGRect(x: 100, y: 52, width: 44, height: 44),
                "收起导航": CGRect(x: 52, y: 52, width: 44, height: 44),
                "清除标记": CGRect(x: 26, y: 152, width: 96, height: 44)
            ]
            button.frame = frames[title] ?? .zero
            if let direction { navigationButtons.append((button, direction)) }
            button.addTarget(self, action: selector, for: .touchUpInside)
            menu.addSubview(button)
        }
        view.addSubview(menu)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !placedEntry {
            let safe = usableBounds
            dot.center = CGPoint(x: safe.maxX - 22, y: safe.minY + min(100, safe.height / 3))
            placedEntry = true
        }
        if !picking { moveEntry(to: dot.center) }
        refreshSelection()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // A rotation changes the active coordinate space mid-gesture. Keep the
        // previous selection, rather than committing the old touch location.
        cancelInteraction()
        super.viewWillTransition(to: size, with: coordinator)
    }

    private var usableBounds: CGRect {
        let safe = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 8, dy: 8)
        return safe.width >= 44 && safe.height >= 44 ? safe : view.bounds
    }

    func acceptsTouch(at point: CGPoint) -> Bool {
        // UIKit owns the sheet and its dimming view. Never pass modal touches
        // through the SDK window into the host app.
        if settingsNavigation != nil || presentedViewController != nil { return true }
        if !dot.isHidden && dot.frame.contains(point) { return true }
        guard !menu.isHidden else { return false }
        let local = view.convert(point, to: menu)
        return menu.subviews.contains { $0 is UIButton && !$0.isHidden && $0.frame.contains(local) }
    }

    func moveEntry(to point: CGPoint) {
        let safe = usableBounds
        dot.center = CGPoint(x: min(max(point.x, safe.minX + 22), max(safe.minX + 22, safe.maxX - 22)),
                             y: min(max(point.y, safe.minY + 22), max(safe.minY + 22, safe.maxY - 22)))
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Pan supplies immediate selection; a recognized long press owns the
        // remainder of this touch sequence. Both cancel UIButton touchUpInside.
        true
    }

    @objc private func panEntry(_ pan: UIPanGestureRecognizer) {
        // A long press recognized before movement owns relocation for this touch.
        guard !movingEntry else { return }
        let point = pan.location(in: view)
        switch pan.state {
        case .began: beginPicking(at: point)
        case .changed: updatePicking(at: point)
        case .ended: finishPicking(at: point, cancelled: false)
        case .cancelled, .failed: finishPicking(at: point, cancelled: true)
        default: break
        }
    }

    @objc private func pressEntry(_ press: UILongPressGestureRecognizer) {
        switch press.state {
        case .began:
            guard !picking else { return }
            if presentation.feedbackEnabled { UISelectionFeedbackGenerator().selectionChanged() }
            beginMoving()
            refreshSelection()
        case .changed:
            guard movingEntry else { return }
            moveEntry(to: press.location(in: view))
            refreshSelection()
        case .ended: finishMoving(cancelled: false)
        case .cancelled, .failed: finishMoving(cancelled: true)
        default: break
        }
    }

    func beginMoving() {
        dismissSettings(animated: false)
        guard !picking else { return }
        entryOrigin = dot.center
        movingEntry = true
        menu.isHidden = true
    }

    func updateMoving(translation: CGPoint) {
        guard movingEntry else { return }
        moveEntry(to: CGPoint(x: entryOrigin.x + translation.x, y: entryOrigin.y + translation.y))
        refreshSelection()
    }

    func finishMoving(cancelled: Bool) {
        guard movingEntry else { return }
        if cancelled { moveEntry(to: entryOrigin) }
        movingEntry = false
        refreshSelection()
        view.setNeedsLayout()
    }

    func beginPicking(at point: CGPoint) {
        dismissSettings(animated: false)
        entryOrigin = dot.center
        movingEntry = false
        picking = true
        candidate = nil
        guideDwellOrigin = nil
        lastFeedbackAt = -.infinity
        haptic.prepare()
        menu.isHidden = true
        menuIsPlaced = false
        setCrosshair(true)
        updatePicking(at: point)
    }

    func updatePicking(at point: CGPoint) {
        guard picking else { return }
        lastPickPoint = point
        dot.center = point
        guard let window = businessWindowProvider?() else {
            candidate = nil
            guideDwellOrigin = nil
            magnifier.clear()
            updateGuides(around: nil)
            display(nil, text: "当前场景不可选取")
            return
        }
        let local = view.convert(point, to: window)
        let next = TKPickerSessionManager.candidate(at: local, in: window)
        let changed = candidate !== next
        let time = clock()
        if presentation.feedbackEnabled, changed, next != nil, time - lastFeedbackAt >= 0.08 {
            if let selectionFeedback { selectionFeedback() }
            else { haptic.selectionChanged(); haptic.prepare() }
            lastFeedbackAt = time
        }
        candidate = next
        if changed || guideDwellOrigin == nil || guideDwellOrigin.map({ hypot(point.x - $0.x, point.y - $0.y) > 12 }) == true {
            guideDwellOrigin = point
            guideDwellStartedAt = time
        }
        updateGuides(around: presentation.guidesEnabled && time - guideDwellStartedAt >= 0.25 ? candidate : nil)
        if let candidate, presentation.magnifierEnabled {
            placeMagnifier(at: point)
            magnifier.update(window: window, point: local, targetRect: visibleRect(candidate, in: window),
                             time: time, force: changed)
        } else {
            magnifier.clear()
        }
        display(candidate, text: candidate.map { "松手选中  ·  \(String(describing: type(of: $0)))\(previewName(for: $0))" } ?? "此处没有可选控件")
    }

    func finishPicking(at point: CGPoint, cancelled: Bool) {
        guard picking else { return }
        var committed = false
        if !cancelled {
            updatePicking(at: point)
            if let candidate { committed = manager.select(candidate, rawHit: candidate).ok }
        }
        picking = false
        candidate = nil
        lastPickPoint = nil
        guideDwellOrigin = nil
        magnifier.clear()
        moveEntry(to: entryOrigin)
        setCrosshair(false)
        updateGuides(around: nil)
        menu.isHidden = !committed
        menuIsPlaced = false
        refreshSelection()
    }

    func cancelInteraction() {
        dismissSettings(animated: false)
        finishPicking(at: .zero, cancelled: true)
        finishMoving(cancelled: true)
        menu.isHidden = true
    }

    func refreshSelection() {
        guard isViewLoaded else { return }
        if let navigation = settingsNavigation {
            (navigation.topViewController as? TKSDKSettingsViewController)?.refreshSnapshot()
            dot.isHidden = true
            outline.isHidden = true
            caption.isHidden = true
            menu.isHidden = true
            return
        }
        dot.isHidden = false
        caption.isHidden = false
        if !menu.isHidden {
            for (button, direction) in navigationButtons {
                button.isEnabled = manager.canNavigate(direction)
                button.alpha = button.isEnabled ? 1 : 0.4
            }
        }
        if picking {
            if let point = lastPickPoint { updatePicking(at: point) }
            return
        }
        if movingEntry { display(nil, text: "松手放置圆球"); return }
        let status = manager.status()
        guard let selected = manager.selectedView else {
            display(nil, text: "拖动选控件 · 长按移动")
            return
        }
        guard status.state != "stale" else {
            display(nil, text: "标记已失效，请重新选择")
            return
        }
        guard let targetWindow = selected.window,
              view.window == nil || targetWindow.windowScene === view.window?.windowScene else {
            display(nil, text: "标记位于另一场景")
            return
        }
        let revision = status.selection?.revision ?? 0
        let suffix = status.state == "observeOnly" ? " · 仅观察" : ""
        display(selected, text: "#\(revision) \(String(describing: type(of: selected)))\(suffix)\(previewName(for: selected))")
    }

    private func setCrosshair(_ active: Bool) {
        dot.backgroundColor = active ? .clear : surface
        dot.layer.borderWidth = active ? 0 : 1
        dot.layer.shadowOpacity = active ? 0 : 0.2
        dot.imageView?.isHidden = active
        crosshair.isHidden = !active
    }

    private func updateGuides(around target: UIView?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guides.path = nil
        guides.isHidden = true
        guard let target, let window = target.window else { return }
        // Use the nearest populated ancestor; never add decoration to business layers.
        var scope: UIView? = target
        var boxes: [CGRect] = []
        for _ in 0..<5 {
            guard let current = scope, !(current is UIWindow) else { break }
            var budget = 240
            var found: [CGRect] = []
            func visit(_ item: UIView, depth: Int) {
                guard budget > 0, depth < 8, found.count < 48,
                      !item.isHidden, item.alpha > 0.01,
                      !item.layer.isHidden, item.layer.opacity > 0.01 else { return }
                budget -= 1
                let rect = visibleRect(item, in: window)
                guard !rect.isNull, !rect.isEmpty else { return }
                if item is UIControl || item is UILabel || item.isAccessibilityElement {
                    if rect.width >= 4 && rect.height >= 4 { found.append(rect) }
                    if item is UIControl { return }
                }
                for child in item.subviews { visit(child, depth: depth + 1) }
            }
            visit(current, depth: 0)
            if found.count >= 4 { boxes = found; break }
            scope = current.superview
        }
        guard !boxes.isEmpty else { return }
        let path = UIBezierPath()
        for box in boxes {
            path.append(UIBezierPath(roundedRect: view.convert(box, from: window), cornerRadius: 4))
        }
        guides.frame = view.bounds
        guides.path = path.cgPath
        guides.isHidden = false
    }

    private func visibleRect(_ target: UIView, in window: UIWindow) -> CGRect {
        var rect = target.convert(target.bounds, to: window)
        var ancestor = target.superview
        while let current = ancestor {
            if current.isHidden || current.alpha <= 0.01 || current.layer.isHidden || current.layer.opacity <= 0.01 { return .null }
            if current.clipsToBounds { rect = rect.intersection(current.convert(current.bounds, to: window)) }
            ancestor = current.superview
        }
        return rect.intersection(window.bounds)
    }

    private func previewName(for target: UIView) -> String {
        let name = (target as? UILabel)?.text ?? (target as? UIButton)?.currentTitle
            ?? target.accessibilityLabel ?? target.accessibilityIdentifier
        guard let name, !name.isEmpty else { return "" }
        return "\n" + String(name.prefix(32))
    }

    private func display(_ target: UIView?, text: String) {
        outline.isHidden = true
        if let target, let window = target.window {
            let rect = visibleRect(target, in: window)
            if !rect.isNull && !rect.isEmpty {
                outline.frame = view.convert(rect, from: window)
                outline.isHidden = false
            }
        }
        caption.text = text
        let safe = usableBounds
        let width = min(max(caption.sizeThatFits(CGSize(width: 244, height: 60)).width + 24, 120), safe.width)
        let height: CGFloat = text.contains("\n") ? 52 : 34
        let anchor = lastPickPoint ?? (outline.isHidden ? dot.center : CGPoint(x: outline.frame.midX, y: outline.frame.minY))
        let gap: CGFloat = lastPickPoint == nil && !outline.isHidden ? 10 : 34
        let above = anchor.y - gap - height
        let y = above >= safe.minY ? above : anchor.y + gap
        caption.frame = CGRect(x: min(max(anchor.x - width / 2, safe.minX), safe.maxX - width),
                               y: min(max(y, safe.minY), safe.maxY - height), width: width, height: height)
        if !magnifier.isHidden {
            placePickingCaption(size: CGSize(width: width, height: height))
        }
        placeMenu()
    }

    private func placeMagnifier(at point: CGPoint) {
        let safe = usableBounds
        let size = CGSize(width: min(128, safe.width), height: min(96, safe.height))
        let x = min(max(point.x - size.width / 2, safe.minX), safe.maxX - size.width)
        // Reserve room for the name below the lens and clear the finger by 34pt.
        let above = point.y - 34 - 58 - size.height
        let y = above >= safe.minY ? above : point.y + 34
        magnifier.frame = CGRect(x: x, y: min(max(y, safe.minY), safe.maxY - size.height),
                                 width: size.width, height: size.height)
    }

    private func placePickingCaption(size: CGSize) {
        let safe = usableBounds
        let lens = magnifier.frame
        let x = min(max(lens.midX - size.width / 2, safe.minX), safe.maxX - size.width)
        let positions = [CGPoint(x: x, y: lens.maxY + 6),
                         CGPoint(x: x, y: lens.minY - size.height - 6),
                         CGPoint(x: safe.minX, y: safe.minY),
                         CGPoint(x: safe.maxX - size.width, y: safe.maxY - size.height)]
        let frames = positions.map { CGRect(origin: $0, size: size) }
        if let free = frames.first(where: { safe.contains($0) && !$0.intersects(lens) && !$0.intersects(dot.frame.insetBy(dx: -6, dy: -6)) }) {
            caption.frame = free
        } else {
            // Very short windows: keep the target feedback and drop the lens.
            magnifier.clear()
        }
    }

    private func placeMenu() {
        guard !menu.isHidden else { return }
        let safe = usableBounds
        let size = CGSize(width: 148, height: 196)
        let right = safe.maxX - size.width
        let left = safe.minX
        let bottom = safe.maxY - size.height
        var placements = [CGRect(origin: CGPoint(x: right, y: bottom), size: size),
                          CGRect(origin: CGPoint(x: left, y: bottom), size: size),
                          CGRect(origin: CGPoint(x: right, y: safe.minY), size: size),
                          CGRect(origin: CGPoint(x: left, y: safe.minY), size: size)]
        if !outline.isHidden {
            placements += [CGRect(x: right, y: outline.frame.maxY + 12, width: size.width, height: size.height),
                           CGRect(x: right, y: outline.frame.minY - size.height - 12, width: size.width, height: size.height)]
        }
        let obstacles = (outline.isHidden ? [] : [outline.frame.insetBy(dx: -8, dy: -8)]) + [caption.frame, dot.frame]
        func overlap(_ frame: CGRect) -> CGFloat {
            obstacles.reduce(0) { sum, obstacle in
                let intersection = frame.intersection(obstacle)
                return sum + (intersection.isNull ? 0 : intersection.width * intersection.height)
            }
        }
        let best = placements.filter { safe.contains($0) }.min { overlap($0) < overlap($1) }
            ?? CGRect(x: safe.minX, y: safe.minY, width: size.width, height: size.height)
        if menuIsPlaced, safe.contains(menu.frame) {
            let currentOverlap = overlap(menu.frame)
            // Preserve motor memory. A small caption shift or a full-screen
            // ancestor must not repeatedly pull buttons away from the finger.
            if currentOverlap == 0 || currentOverlap - overlap(best) < 44 * 22 { return }
        }
        menu.frame = best
        menuIsPlaced = true
    }

    func updatePresentation(_ configuration: TritonKit.PickerConfiguration) {
        presentation = configuration
        for page in settingsNavigation?.viewControllers ?? [] {
            (page as? TKSDKSettingsViewController)?.update(configuration)
        }
        refreshSelection()
    }

    @objc private func toggleSettings() {
        guard settingsNavigation == nil else { dismissSettings(); return }
        guard view.window != nil, presentedViewController == nil else { return }
        let root = TKSDKSettingsViewController(configuration: presentation, snapshotProvider: {
            let kit = TritonKit.shared
            let bundle = Bundle.main
            return TKSDKSettingsSnapshot(configuration: kit.configuration, state: kit.state, appInfo: [
                "displayName": kit.configuration.appIdentity?.name ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "",
                "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                "build": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                "bundleIdentifier": bundle.bundleIdentifier ?? "",
                "os": UIDevice.current.systemName + " " + UIDevice.current.systemVersion
            ])
        }, onChange: { [weak self] magnifier, guides, feedback in
            guard let self else { return }
            self.presentation.magnifierEnabled = magnifier
            self.presentation.guidesEnabled = guides
            self.presentation.feedbackEnabled = feedback
            TritonKit.shared.setPickerPresentation(magnifier: magnifier, guides: guides, feedback: feedback)
        }, onHide: { [weak self] in
            self?.dismissSettings { [weak self] in self?.onHide?() }
        })
        root.onClose = { [weak self] in self?.dismissSettings() }
        let navigation = UINavigationController(rootViewController: root)
        navigation.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            let sheet = navigation.sheetPresentationController
            sheet?.detents = [.medium(), .large()]
            sheet?.selectedDetentIdentifier = .medium
            sheet?.prefersGrabberVisible = true
            sheet?.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        settingsNavigation = navigation
        navigation.presentationController?.delegate = self
        menu.isHidden = true
        guides.isHidden = true
        magnifier.isHidden = true
        refreshSelection()
        present(navigation, animated: true) { [weak self] in
            guard let self, let pending = self.pendingSettingsDismissal else { return }
            self.pendingSettingsDismissal = nil
            self.dismissSettings(animated: pending.animated, completion: pending.completion)
        }
    }

    private func dismissSettings(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let navigation = settingsNavigation else { completion?(); return }
        if navigation.isBeingPresented {
            pendingSettingsDismissal = (animated, completion)
            return
        }
        // Dismiss from the presenting root so a confirmation alert cannot
        // leave the settings navigation controller stranded underneath.
        dismiss(animated: animated) { [weak self, weak navigation] in
            guard let self else { completion?(); return }
            if self.settingsNavigation === navigation {
                self.settingsNavigation = nil
                self.refreshSelection()
            }
            completion?()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === settingsNavigation else { return }
        settingsNavigation = nil
        pendingSettingsDismissal = nil
        refreshSelection()
    }

    func showNavigation() {
        dismissSettings(animated: false)
        menu.isHidden = true
        toggleMenu()
    }

    @objc private func toggleMenu() {
        menu.isHidden.toggle()
        if !menu.isHidden { menuIsPlaced = false }
        refreshSelection()
        view.setNeedsLayout()
    }

    @objc private func selectParent() {
        _ = manager.selectParent()
        refreshSelection()
    }

    @objc private func selectChild() {
        _ = manager.navigate(.child)
        refreshSelection()
    }

    @objc private func selectPrevious() {
        _ = manager.navigate(.previousSibling)
        refreshSelection()
    }

    @objc private func selectNext() {
        _ = manager.navigate(.nextSibling)
        refreshSelection()
    }

    @objc private func clearSelection() {
        _ = manager.clear()
        menu.isHidden = true
        refreshSelection()
    }


}
#endif
