import Foundation
import CoreGraphics
import ObjectiveC
import TritonKitShared
import TritonKit

enum HostSimulatorAXError: Error, CustomStringConvertible, Equatable {
    case unsupportedPlatform
    case privateFrameworkUnavailable
    case translatorUnavailable
    case targetNotFound(String)
    case frontmostApplicationUnavailable(String)
    case platformElementUnavailable(String)
    case treeUnavailable(String)
    case actionUnavailable(String)

    var detail: TKCLIErrorDetail {
        TKCLIErrorDetail(
            code: code,
            message: message,
            hint: hint,
            nextAction: nextAction,
            suggestedCommands: suggestedCommands
        )
    }

    var description: String { "\(code): \(message)" }

    private var code: String {
        switch self {
        case .unsupportedPlatform:
            return "ios_host_ax_unsupported_platform"
        case .privateFrameworkUnavailable, .translatorUnavailable:
            return "ios_host_ax_unavailable"
        case .targetNotFound:
            return "simulator_not_found"
        case .frontmostApplicationUnavailable:
            return "ios_host_ax_frontmost_unavailable"
        case .platformElementUnavailable:
            return "ios_host_ax_platform_element_unavailable"
        case .treeUnavailable:
            return "ios_host_ax_tree_unavailable"
        case .actionUnavailable:
            return "ios_host_ax_action_unavailable"
        }
    }

    private var message: String {
        switch self {
        case .unsupportedPlatform:
            return "Host-side iOS Simulator AX is available only on macOS."
        case .privateFrameworkUnavailable:
            return "AccessibilityPlatformTranslation private framework is not available."
        case .translatorUnavailable:
            return "AXPTranslator shared instance is not available."
        case .targetNotFound(let target):
            return "Simulator target not found: \(target)."
        case .frontmostApplicationUnavailable(let udid):
            return "Unable to read the frontmost application AX root for simulator \(udid)."
        case .platformElementUnavailable(let udid):
            return "Unable to convert the AX translation into a macOS platform element for simulator \(udid)."
        case .treeUnavailable(let udid):
            return "Unable to build the host-side AX tree for simulator \(udid)."
        case .actionUnavailable(let target):
            return "Unable to submit host-side AX press for simulator target \(target)."
        }
    }

    private var hint: String? {
        switch self {
        case .unsupportedPlatform:
            return "Run this command from macOS with Xcode installed."
        case .privateFrameworkUnavailable, .translatorUnavailable:
            return "Use `triton device doctor --platform ios --json` and verify the local Xcode / Simulator private-framework environment."
        case .targetNotFound:
            return "Run `triton sim list --json` and pass a booted simulator UDID with `triton sim ax --device <udid> --json`."
        case .frontmostApplicationUnavailable, .platformElementUnavailable, .treeUnavailable:
            return "Bring the simulator window forward, verify the target is booted, then retry `triton sim ax --device <udid> --json`."
        case .actionUnavailable:
            return "Run `triton observe tree --platform ios --device <selector> --json` and choose a visible tappable node or coordinate."
        }
    }

    private var nextAction: TKCLINextAction? {
        switch self {
        case .targetNotFound:
            return TKCLINextAction(command: "sim", args: ["list", "--json"], category: "diagnose")
        case .unsupportedPlatform, .privateFrameworkUnavailable, .translatorUnavailable:
            return TKCLINextAction(command: "device", args: ["doctor", "--platform", "ios", "--json"], category: "diagnose")
        case .frontmostApplicationUnavailable, .platformElementUnavailable, .treeUnavailable:
            return TKCLINextAction(command: "sim", args: ["ax", "--device", "<udid>", "--json"], category: "observe")
        case .actionUnavailable:
            return TKCLINextAction(command: "observe", args: ["tree", "--platform", "ios", "--device", "<selector>", "--json"], category: "observe")
        }
    }

    private var suggestedCommands: [String] {
        switch self {
        case .targetNotFound:
            return ["triton sim list --json", "triton sim boot <udid> --wait --jsonl"]
        case .unsupportedPlatform, .privateFrameworkUnavailable, .translatorUnavailable:
            return ["triton device doctor --platform ios --json", "triton schema --command sim --json"]
        case .frontmostApplicationUnavailable, .platformElementUnavailable, .treeUnavailable:
            return ["triton sim list --json", "triton sim screenshot --simulator <udid> --output <path.png> --json"]
        case .actionUnavailable:
            return ["triton observe tree --platform ios --device <selector> --json", "triton node resolve --platform ios --device <selector> --text <text> --json"]
        }
    }
}

#if os(macOS)

// MARK: - AX Element Reader
enum AXElementReader {
    static func string(_ obj: NSObject, _ key: String) -> String? {
        guard let s = obj.value(forKey: key) as? String, !s.isEmpty else { return nil }
        return s
    }
    static func stringOrNumber(_ obj: NSObject, _ key: String) -> String? {
        let raw = obj.value(forKey: key)
        if let s = raw as? String { return s.isEmpty ? nil : s }
        if let n = raw as? NSNumber { return n.stringValue }
        return nil
    }
    static func bool(_ obj: NSObject, _ key: String, default fallback: Bool) -> Bool {
        if let n = obj.value(forKey: key) as? NSNumber { return n.boolValue }
        return fallback
    }
    static func frame(of element: NSObject?) -> CGRect {
        guard let element = element else { return .zero }
        let sel = NSSelectorFromString("accessibilityFrame")
        guard element.responds(to: sel),
              let imp = class_getMethodImplementation(type(of: element), sel) else { return .zero }
        typealias Fn = @convention(c) (AnyObject, Selector) -> CGRect
        return unsafeBitCast(imp, to: Fn.self)(element, sel)
    }
    static func children(of element: NSObject?) -> [NSObject] {
        guard let element = element else { return [] }
        guard let raw = element.value(forKey: "accessibilityChildren") else { return [] }
        if let arr = raw as? [NSObject] { return arr }
        return []
    }
}

// MARK: - AX Frame Transform
struct AXFrameTransform: Equatable, Sendable {
    let rootFrame: CGRect
    let pointSize: CGSize

    func map(_ macFrame: CGRect) -> CGRect {
        guard rootFrame.width > 0, rootFrame.height > 0, pointSize.width > 0, pointSize.height > 0 else { return macFrame }
        let scale = pointSize.width / rootFrame.width
        let yOffset = (pointSize.height - rootFrame.height * scale) / 2
        return CGRect(
            x: (macFrame.origin.x - rootFrame.origin.x) * scale,
            y: (macFrame.origin.y - rootFrame.origin.y) * scale + yOffset,
            width: macFrame.size.width * scale,
            height: macFrame.size.height * scale
        )
    }

    func unmap(_ devicePoint: CGPoint) -> CGPoint {
        guard rootFrame.width > 0, rootFrame.height > 0, pointSize.width > 0, pointSize.height > 0 else { return devicePoint }
        let scale = pointSize.width / rootFrame.width
        let yOffset = (pointSize.height - rootFrame.height * scale) / 2
        return CGPoint(
            x: devicePoint.x / scale + rootFrame.origin.x,
            y: (devicePoint.y - yOffset) / scale + rootFrame.origin.y
        )
    }
}

// MARK: - AXP Translator Accessibility
class AXPTranslatorAccessibility {
    let udid: String

    init(udid: String) {
        self.udid = udid
    }
    
    private static let coreSimLoaded: Bool = {
        // Try both known locations for CoreSimulator.framework
        let candidates = [
            "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator",
            "/Applications/Xcode.app/Contents/SharedFrameworks/CoreSimulator.framework/CoreSimulator",
            "/Applications/Xcode.app/Contents/Developer/Library/PrivateFrameworks/CoreSimulator.framework/CoreSimulator",
        ]
        for path in candidates {
            if dlopen(path, RTLD_NOW | RTLD_GLOBAL) != nil { return true }
        }
        return false
    }()

    private func resolveDevice() -> NSObject? {
        _ = Self.coreSimLoaded

        // Method 1: SimDeviceSet.defaultSetWithError (no dev dir needed)
        if let simDeviceSetClass = NSClassFromString("SimDeviceSet") {
            let sel = NSSelectorFromString("defaultSetWithError:")
            if let metaCls = object_getClass(simDeviceSetClass),
               class_respondsToSelector(metaCls, sel) {
                typealias Fn = @convention(c) (AnyClass, Selector, UnsafeMutableRawPointer?) -> Unmanaged<AnyObject>?
                let imp = class_getMethodImplementation(metaCls, sel)
                if let setUnmanaged = unsafeBitCast(imp, to: Fn.self)(simDeviceSetClass, sel, nil) {
                    let deviceSet = setUnmanaged.takeUnretainedValue()
                    if let devicesArray = (deviceSet as AnyObject).value(forKey: "devices") as? [AnyObject] {
                        for device in devicesArray {
                            if let val = device.value(forKey: "UDID") {
                                if "\(val)".uppercased() == udid.uppercased() {
                                    return device as? NSObject
                                }
                            }
                        }
                    }
                }
            }
        }

        // Method 2: SimServiceContext (Xcode-style)
        if let simServiceContextClass = NSClassFromString("SimServiceContext") {
            let sharedContextSelector = NSSelectorFromString("sharedServiceContextForDeveloperDir:error:")
            if let metaCls = object_getClass(simServiceContextClass),
               class_respondsToSelector(metaCls, sharedContextSelector) {
                let developerDir = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
                    ?? "/Applications/Xcode.app/Contents/Developer"
                typealias Fn = @convention(c) (AnyClass, Selector, NSString, UnsafeMutableRawPointer?) -> Unmanaged<AnyObject>?
                let imp = class_getMethodImplementation(metaCls, sharedContextSelector)
                if let contextUnmanaged = unsafeBitCast(imp, to: Fn.self)(simServiceContextClass, sharedContextSelector, developerDir as NSString, nil) {
                    let context = contextUnmanaged.takeUnretainedValue()
                    let defaultDeviceSetSelector = NSSelectorFromString("defaultDeviceSetWithError:")
                    if (context as AnyObject).responds(to: defaultDeviceSetSelector),
                       let deviceSetUnmanaged = (context as AnyObject).perform(defaultDeviceSetSelector, with: nil) {
                        let actualDeviceSet = deviceSetUnmanaged.takeUnretainedValue()
                        if let devicesArray = (actualDeviceSet as AnyObject).value(forKey: "devices") as? [AnyObject] {
                            for device in devicesArray {
                                if let val = device.value(forKey: "UDID") {
                                    if "\(val)".uppercased() == udid.uppercased() {
                                        return device as? NSObject
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        return nil
    }


    func describeAll() throws -> TKAXNode? {
        return try fetchTree(hitTest: nil)
    }

    func describeAt(point: CGPoint) throws -> TKAXNode? {
        if Self.supportsServerSideHitTest {
            if let hit = try hitTestServerSide(point: point) {
                return hit
            }
        }
        guard let root = try describeAll() else { return nil }
        return findNodeLocally(node: root, point: point)
    }

    func press(query: String?, point: CGPoint?, index: Int?, within: TKRect?) throws -> TKAXNode {
        if let index, index <= 0 {
            throw RuntimeError("--index must be greater than 0")
        }
        guard let pressedNode = try withAXPContext({ ctx in
            Self.stampElementTranslation(token: ctx.token, on: ctx.frontmostRoot)
            Self.stampSubtree(ctx.frontmostRoot, token: ctx.token, depthCap: Self.maxDepth)

            let selected: ElementNodeMatch?
            if let point {
                selected = Self.elementAtPoint(point, context: ctx)
            } else if let query {
                let candidates = Self.elementMatches(
                    root: ctx.frontmostRoot,
                    query: query,
                    transform: ctx.transform,
                    depthCap: Self.maxDepth,
                    within: within,
                    deadline: ctx.deadline
                )
                let selectedIndex = index ?? 1
                guard selectedIndex <= candidates.count else {
                    throw RuntimeError(candidates.isEmpty
                        ? "No current UI node matched query: \(query)"
                        : "Only \(candidates.count) UI node(s) matched query: \(query); cannot select --index \(selectedIndex)")
                }
                selected = candidates[selectedIndex - 1]
            } else {
                selected = nil
            }

            guard let selected else { throw HostSimulatorAXError.actionUnavailable(udid) }
            guard Self.performPress(on: selected.element) else { throw HostSimulatorAXError.actionUnavailable(udid) }
            return selected.node
        }) else {
            throw HostSimulatorAXError.actionUnavailable(udid)
        }
        return pressedNode
    }
    
    private func findNodeLocally(node: TKAXNode, point: CGPoint) -> TKAXNode? {
        guard contains(node.frame, point) else { return nil }
        for child in node.children {
            if let hit = findNodeLocally(node: child, point: point) {
                return hit
            }
        }
        return node
    }
    
    private func contains(_ r: TKRect, _ p: CGPoint) -> Bool {
        return r.contains(x: p.x, y: p.y)
    }

    private struct AXPContext {
        let translator: NSObject
        let token: String
        let frontmostRoot: NSObject
        let transform: AXFrameTransform
        let deadline: Date
    }

    private func withAXPContext<T>(_ body: (AXPContext) throws -> T?) throws -> T? {
        if let error = Self.availabilityError {
            throw error
        }
        guard let device = resolveDevice() else { throw HostSimulatorAXError.targetNotFound(udid) }

        let token = UUID().uuidString
        let deadline = Date().addingTimeInterval(Self.xpcTimeoutSeconds)
        Self.sharedDispatcher.register(device: device, token: token, deadline: deadline)
        defer { Self.sharedDispatcher.unregister(token: token) }

        guard let translator = Self.sharedTranslator else { throw HostSimulatorAXError.translatorUnavailable }

        guard let translation = Self.frontmostApplication(translator: translator, token: token) else {
            throw HostSimulatorAXError.frontmostApplicationUnavailable(udid)
        }
        Self.stamp(token: token, on: translation)

        guard let frontmostRoot = Self.macPlatformElement(translator: translator, translation: translation) else {
            throw HostSimulatorAXError.platformElementUnavailable(udid)
        }
        let pointSize = Self.devicePointSize(for: device)
        let rootFrame = AXElementReader.frame(of: frontmostRoot)
        let transform = AXFrameTransform(rootFrame: rootFrame, pointSize: pointSize)

        return try body(AXPContext(translator: translator, token: token, frontmostRoot: frontmostRoot, transform: transform, deadline: deadline))
    }

    private func fetchTree(hitTest: CGPoint?) throws -> TKAXNode? {
        try withAXPContext { ctx in
            Self.stampElementTranslation(token: ctx.token, on: ctx.frontmostRoot)
            Self.stampSubtree(ctx.frontmostRoot, token: ctx.token, depthCap: Self.maxDepth)
            return buildTKAXNode(from: ctx.frontmostRoot, transform: ctx.transform, depthCap: Self.maxDepth, deadline: ctx.deadline)
        }
    }

    private func hitTestServerSide(point: CGPoint) throws -> TKAXNode? {
        try withAXPContext { ctx in
            let hostPoint = ctx.transform.unmap(CGPoint(x: point.x, y: point.y))
            guard let hitTranslation = Self.objectAtPoint(translator: ctx.translator, point: hostPoint, displayId: 0, token: ctx.token) else { return nil }
            Self.stamp(token: ctx.token, on: hitTranslation)
            guard let hitElement = Self.macPlatformElement(translator: ctx.translator, translation: hitTranslation) else { return nil }
            Self.stampElementTranslation(token: ctx.token, on: hitElement)
            Self.stampSubtree(hitElement, token: ctx.token, depthCap: Self.maxDepth)
            return buildTKAXNode(from: hitElement, transform: ctx.transform, depthCap: Self.maxDepth, deadline: ctx.deadline)
        }
    }

    private static func stampSubtree(_ element: NSObject, token: String, depthCap: Int, depth: Int = 0) {
        guard depth < depthCap else { return }
        for kid in AXElementReader.children(of: element) {
            stampElementTranslation(token: token, on: kid)
            stampSubtree(kid, token: token, depthCap: depthCap, depth: depth + 1)
        }
    }

    static var isAvailable: Bool { sharedTranslator != nil }
    static var availabilityError: HostSimulatorAXError? {
        if !frameworksLoaded { return .privateFrameworkUnavailable }
        if sharedTranslator == nil { return .translatorUnavailable }
        return nil
    }
    private static let frameworksLoaded: Bool = {
        let path = "/System/Library/PrivateFrameworks/AccessibilityPlatformTranslation.framework/AccessibilityPlatformTranslation"
        return dlopen(path, RTLD_NOW | RTLD_GLOBAL) != nil
    }()

    private static let sharedTranslator: NSObject? = {
        guard frameworksLoaded else { return nil }
        guard let cls = NSClassFromString("AXPTranslator") else { return nil }
        let sel = NSSelectorFromString("sharedInstance")
        guard let metaCls = object_getClass(cls), let imp = class_getMethodImplementation(metaCls, sel) else { return nil }
        typealias Fn = @convention(c) (AnyClass, Selector) -> AnyObject?
        guard let inst = unsafeBitCast(imp, to: Fn.self)(cls, sel) as? NSObject else { return nil }
        inst.setValue(sharedDispatcher, forKey: "bridgeTokenDelegate")
        return inst
    }()

    static let sharedDispatcher = TokenDispatcher()

    private static func frontmostApplication(translator: NSObject, token: String) -> NSObject? {
        let sel = NSSelectorFromString("frontmostApplicationWithDisplayId:bridgeDelegateToken:")
        guard translator.responds(to: sel), let imp = class_getMethodImplementation(type(of: translator), sel) else { return nil }
        typealias Fn = @convention(c) (AnyObject, Selector, UInt32, AnyObject) -> AnyObject?
        return unsafeBitCast(imp, to: Fn.self)(translator, sel, 0, token as NSString) as? NSObject
    }

    private static func macPlatformElement(translator: NSObject, translation: NSObject) -> NSObject? {
        let sel = NSSelectorFromString("macPlatformElementFromTranslation:")
        guard translator.responds(to: sel) else { return nil }
        return translator.perform(sel, with: translation)?.takeUnretainedValue() as? NSObject
    }

    private static func objectAtPoint(translator: NSObject, point: CGPoint, displayId: UInt32, token: String) -> NSObject? {
        let sel = NSSelectorFromString("objectAtPoint:displayId:bridgeDelegateToken:")
        guard translator.responds(to: sel), let imp = class_getMethodImplementation(type(of: translator), sel) else { return nil }
        typealias Fn = @convention(c) (AnyObject, Selector, CGPoint, UInt32, AnyObject) -> AnyObject?
        return unsafeBitCast(imp, to: Fn.self)(translator, sel, point, displayId, token as NSString) as? NSObject
    }

    static var supportsServerSideHitTest: Bool {
        guard let translator = sharedTranslator else { return false }
        return translator.responds(to: NSSelectorFromString("objectAtPoint:displayId:bridgeDelegateToken:"))
    }

    private static func stamp(token: String, on translation: NSObject) {
        translation.setValue(token, forKey: "bridgeDelegateToken")
    }

    private static func stampElementTranslation(token: String, on element: NSObject) {
        if let trans = element.value(forKey: "translation") as? NSObject {
            stamp(token: token, on: trans)
        }
    }

    static func devicePointSize(for device: NSObject) -> CGSize {
        let fallback = CGSize(width: 393, height: 852)
        guard let deviceType = device.value(forKey: "deviceType") as? NSObject else { return fallback }
        let pixelSize: CGSize
        if let raw = deviceType.value(forKey: "mainScreenSize") as? CGSize {
            pixelSize = raw
        } else if let nsv = deviceType.value(forKey: "mainScreenSize") as? NSValue {
            pixelSize = nsv.sizeValue
        } else {
            return fallback
        }
        let scale = (deviceType.value(forKey: "mainScreenScale") as? NSNumber)?.doubleValue ?? 3.0
        guard scale > 0 else { return fallback }
        return CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
    }

    private static let maxDepth: Int = 80
    private static let xpcTimeoutSeconds: TimeInterval = 2.0
    
    private func buildTKAXNode(from element: NSObject, transform: AXFrameTransform, depthCap: Int, deadline: Date) -> TKAXNode {
        return Self.walkInternal(element: element, depth: 0, transform: transform, depthCap: depthCap, deadline: deadline)
    }

    private static func walkInternal(element: NSObject, depth: Int, transform: AXFrameTransform, depthCap: Int, deadline: Date) -> TKAXNode {
        let role = AXElementReader.string(element, "accessibilityRole") ?? "AXUnknown"
        let macFrame = AXElementReader.frame(of: element)
        let projected = transform.map(macFrame)

        let children: [TKAXNode]
        if depth >= depthCap || Date() >= deadline {
            children = []
        } else {
            let kids = AXElementReader.children(of: element)
            children = kids.map { walkInternal(element: $0, depth: depth + 1, transform: transform, depthCap: depthCap, deadline: deadline) }
        }

        return TKAXNode(
            role: role,
            label: AXElementReader.string(element, "accessibilityLabel"),
            value: AXElementReader.stringOrNumber(element, "accessibilityValue"),
            identifier: AXElementReader.string(element, "accessibilityIdentifier"),
            title: AXElementReader.string(element, "accessibilityTitle"),
            frame: TKRect(x: Double(projected.origin.x), y: Double(projected.origin.y), width: Double(projected.size.width), height: Double(projected.size.height)),
            enabled: AXElementReader.bool(element, "accessibilityEnabled", default: true) || AXElementReader.bool(element, "isAccessibilityEnabled", default: false),
            focused: AXElementReader.bool(element, "isAccessibilityFocused", default: false) || AXElementReader.bool(element, "accessibilityFocused", default: false),
            hidden:  AXElementReader.bool(element, "isAccessibilityHidden", default: false) || AXElementReader.bool(element, "accessibilityHidden", default: false),
            targetOID: nil,
            className: nil,
            children: children
        )
    }

    private struct ElementNodeMatch {
        let element: NSObject
        let node: TKAXNode
        let depth: Int
    }

    private static func elementAtPoint(_ point: CGPoint, context: AXPContext) -> ElementNodeMatch? {
        if supportsServerSideHitTest,
           let hitTranslation = objectAtPoint(translator: context.translator, point: context.transform.unmap(point), displayId: 0, token: context.token) {
            stamp(token: context.token, on: hitTranslation)
            if let hitElement = macPlatformElement(translator: context.translator, translation: hitTranslation) {
                stampElementTranslation(token: context.token, on: hitElement)
                return ElementNodeMatch(
                    element: hitElement,
                    node: summaryNode(from: hitElement, transform: context.transform),
                    depth: 0
                )
            }
        }
        return elementContainingPoint(
            context.frontmostRoot,
            point: point,
            transform: context.transform,
            depthCap: maxDepth,
            deadline: context.deadline
        )
    }

    private static func elementMatches(
        root: NSObject,
        query: String,
        transform: AXFrameTransform,
        depthCap: Int,
        within: TKRect?,
        deadline: Date
    ) -> [ElementNodeMatch] {
        var matches: [ElementNodeMatch] = []
        collectElementMatches(
            root,
            query: query,
            transform: transform,
            depthCap: depthCap,
            depth: 0,
            within: within,
            deadline: deadline,
            matches: &matches
        )
        return matches
    }

    private static func collectElementMatches(
        _ element: NSObject,
        query: String,
        transform: AXFrameTransform,
        depthCap: Int,
        depth: Int,
        within: TKRect?,
        deadline: Date,
        matches: inout [ElementNodeMatch]
    ) {
        guard depth <= depthCap, Date() < deadline else { return }
        let node = summaryNode(from: element, transform: transform)
        if nodeMatches(node, query: query) && nodeMatchesBounds(node, within: within) {
            matches.append(ElementNodeMatch(element: element, node: node, depth: depth))
        }
        for child in AXElementReader.children(of: element) {
            collectElementMatches(
                child,
                query: query,
                transform: transform,
                depthCap: depthCap,
                depth: depth + 1,
                within: within,
                deadline: deadline,
                matches: &matches
            )
        }
    }

    private static func elementContainingPoint(
        _ element: NSObject,
        point: CGPoint,
        transform: AXFrameTransform,
        depthCap: Int,
        depth: Int = 0,
        deadline: Date
    ) -> ElementNodeMatch? {
        guard depth <= depthCap, Date() < deadline else { return nil }
        let node = summaryNode(from: element, transform: transform)
        guard node.frame.contains(x: point.x, y: point.y) else { return nil }
        for child in AXElementReader.children(of: element) {
            if let match = elementContainingPoint(
                child,
                point: point,
                transform: transform,
                depthCap: depthCap,
                depth: depth + 1,
                deadline: deadline
            ) {
                return match
            }
        }
        return ElementNodeMatch(element: element, node: node, depth: depth)
    }

    private static func summaryNode(from element: NSObject, transform: AXFrameTransform) -> TKAXNode {
        let role = AXElementReader.string(element, "accessibilityRole") ?? "AXUnknown"
        let projected = transform.map(AXElementReader.frame(of: element))
        return TKAXNode(
            role: role,
            label: AXElementReader.string(element, "accessibilityLabel"),
            value: AXElementReader.stringOrNumber(element, "accessibilityValue"),
            identifier: AXElementReader.string(element, "accessibilityIdentifier"),
            title: AXElementReader.string(element, "accessibilityTitle"),
            frame: TKRect(
                x: Double(projected.origin.x),
                y: Double(projected.origin.y),
                width: Double(projected.size.width),
                height: Double(projected.size.height)
            ),
            enabled: AXElementReader.bool(element, "accessibilityEnabled", default: true) || AXElementReader.bool(element, "isAccessibilityEnabled", default: false),
            focused: AXElementReader.bool(element, "isAccessibilityFocused", default: false) || AXElementReader.bool(element, "accessibilityFocused", default: false),
            hidden: AXElementReader.bool(element, "isAccessibilityHidden", default: false) || AXElementReader.bool(element, "accessibilityHidden", default: false),
            targetOID: nil,
            className: nil,
            children: []
        )
    }

    private static func nodeMatches(_ node: TKAXNode, query: String) -> Bool {
        [node.label, node.value, node.identifier, node.title, node.role]
            .compactMap { $0 }
            .contains(query)
    }

    private static func nodeMatchesBounds(_ node: TKAXNode, within: TKRect?) -> Bool {
        guard let within else { return true }
        return TKRectIntersects(node.frame, within)
    }

    private static func performPress(on element: NSObject) -> Bool {
        let pressSelector = NSSelectorFromString("accessibilityPerformPress")
        if element.responds(to: pressSelector),
           let imp = class_getMethodImplementation(type(of: element), pressSelector) {
            typealias Fn = @convention(c) (AnyObject, Selector) -> Bool
            if unsafeBitCast(imp, to: Fn.self)(element, pressSelector) {
                return true
            }
        }

        let performActionSelector = NSSelectorFromString("accessibilityPerformAction:")
        if element.responds(to: performActionSelector) {
            _ = element.perform(performActionSelector, with: "AXPress" as NSString)
            return true
        }

        return false
    }
}

struct SwiftBlock {
    let isa: UnsafeRawPointer
    let flags: Int32
    let reserved: Int32
    let invoke: UnsafeRawPointer
    let descriptor: UnsafeRawPointer
}

struct BlockDescriptor {
    let reserved: Int
    let size: Int
    let copy: UnsafeRawPointer?
    let dispose: UnsafeRawPointer?
    let signature: UnsafePointer<CChar>?
    let layout: UnsafePointer<CChar>?
}

private var descriptor = BlockDescriptor(
    reserved: 0,
    size: MemoryLayout<SwiftBlock>.size,
    copy: nil,
    dispose: nil,
    signature: nil,
    layout: nil
)

private let invokeFunc: @convention(c) (UnsafeRawPointer, UnsafeRawPointer?, UnsafeRawPointer?, UInt64, UnsafeRawPointer?) -> UnsafeRawPointer? = { block, request, token, displayId, completionObj in
    
    let dispatcher = AXPTranslatorAccessibility.sharedDispatcher
    let entry = dispatcher.queue.sync {
        dispatcher.entries.values.first { $0.deadline > Date() }
    }
    
    guard let entry = entry else {
        return nil
    }

    let sel1 = NSSelectorFromString("sendAccessibilityRequestAsync:withCompletion:")
    let sel2 = NSSelectorFromString("sendAccessibilityRequestAsync:completionQueue:completionHandler:")
    // Use UnsafeRawPointer to avoid Swift ARC auto-retain/release on parameters
    typealias SwiftCompletionBlock = @convention(block) (UnsafeRawPointer?, UnsafeRawPointer?) -> Void

    guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else {
        print("[TritonKit] failed to find objc_msgSend")
        return nil
    }

    guard let retainSym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_retain") else {
        print("[TritonKit] failed to find objc_retain")
        return nil
    }

    guard let requestPtr = request else {
        print("[TritonKit] request is nil")
        return nil
    }
    let requestObj = unsafeBitCast(requestPtr, to: AnyObject.self)

    // Store a +1 retained pointer so the caller (AXPTranslator) can safely retain it again
    let resultStorage = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 1)
    resultStorage.pointee = nil
    let semaphore = DispatchSemaphore(value: 0)
    
    // Manually retain the result to balance the caller's retain
    typealias ObjcRetainFn = @convention(c) (UnsafeRawPointer) -> UnsafeRawPointer
    let objcRetain = unsafeBitCast(retainSym, to: ObjcRetainFn.self)
    
    let completionBlock: SwiftCompletionBlock = { result, error in
        if let result = result {
            // Manually retain so the object stays alive past this block scope
            let retained = objcRetain(result)
            resultStorage.pointee = retained
        }
        semaphore.signal()
    }

    if entry.device.responds(to: sel1) {
        typealias MsgSendFn = @convention(c) (AnyObject, Selector, AnyObject, SwiftCompletionBlock) -> Void
        let msgSend = unsafeBitCast(sym, to: MsgSendFn.self)
        msgSend(entry.device, sel1, requestObj, completionBlock)
        semaphore.wait()
    } else if entry.device.responds(to: sel2) {
        typealias MsgSendFn = @convention(c) (AnyObject, Selector, AnyObject, DispatchQueue, SwiftCompletionBlock) -> Void
        let msgSend = unsafeBitCast(sym, to: MsgSendFn.self)
        msgSend(entry.device, sel2, requestObj, DispatchQueue.global(qos: .userInteractive), completionBlock)
        semaphore.wait()
    }
    
    let finalResult = resultStorage.pointee
    resultStorage.deallocate()
    return finalResult
}

private var globalBlock: SwiftBlock = {
    let handle = dlopen(nil, RTLD_NOW)
    let isaSym = dlsym(handle, "_NSConcreteGlobalBlock")!
    return SwiftBlock(
        isa: isaSym,
        flags: 0x30000000,
        reserved: 0,
        invoke: unsafeBitCast(invokeFunc, to: UnsafeRawPointer.self),
        descriptor: UnsafeRawPointer(&descriptor)
    )
}()

private let bridgeCallbackImp: @convention(c) (AnyObject, Selector, AnyObject) -> UnsafeRawPointer = { selfObj, selector, token in
    return withUnsafePointer(to: &globalBlock) { UnsafeRawPointer($0) }
}

private let rootParentImp: @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject? = { selfObj, selector, token in
    nil
}

final class TokenDispatcher: NSObject {
    struct Entry {
        let device: NSObject
        let deadline: Date
    }

    fileprivate let queue = DispatchQueue(label: "TritonKit.AXPTokenDispatcher", qos: .userInteractive)
    fileprivate var entries: [String: Entry] = [:]
    fileprivate var semaphores: [String: DispatchSemaphore] = [:]

    override init() {
        super.init()
        let sel = NSSelectorFromString("accessibilityTranslationDelegateBridgeCallbackWithToken:")
        let imp = unsafeBitCast(bridgeCallbackImp, to: IMP.self)
        class_addMethod(TokenDispatcher.self, sel, imp, "@@:@")
        let rootParentSelector = NSSelectorFromString("accessibilityTranslationRootParentWithToken:")
        let rootParentMethod = unsafeBitCast(rootParentImp, to: IMP.self)
        class_addMethod(TokenDispatcher.self, rootParentSelector, rootParentMethod, "@@:@")
    }

    func register(device: NSObject, token: String, deadline: Date) {
        queue.sync {
            entries[token] = Entry(device: device, deadline: deadline)
        }
    }

    func unregister(token: String) {
        queue.sync {
            entries.removeValue(forKey: token)
            semaphores.removeValue(forKey: token)
        }
    }

    /// Called by AXPTranslator to convert a Mac-screen-space frame to the
    /// simulator's coordinate space. We return the frame unchanged here and
    /// let our own AXFrameTransform handle the iOS point-space mapping later.
    @objc func accessibilityTranslationConvertPlatformFrameToSystem(
        _ frame: CGRect, withToken token: String
    ) -> CGRect {
        return frame
    }
}

#endif
