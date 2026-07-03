import Foundation
import CoreGraphics
import ObjectiveC
import TritonKitShared
import TritonKit

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
    static func frame(of element: NSObject) -> CGRect {
        let sel = NSSelectorFromString("accessibilityFrame")
        guard element.responds(to: sel),
              let imp = class_getMethodImplementation(type(of: element), sel) else { return .zero }
        typealias Fn = @convention(c) (AnyObject, Selector) -> CGRect
        return unsafeBitCast(imp, to: Fn.self)(element, sel)
    }
    static func children(of element: NSObject) -> [NSObject] {
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
    
    private func resolveDevice() -> NSObject? {
        _ = CLIHostSimulatorFramebufferService.shared
        guard let simServiceContextClass = NSClassFromString("SimServiceContext") else { return nil }
        let sharedContextSelector = NSSelectorFromString("sharedServiceContextForDeveloperDir:error:")
        guard let metaCls = object_getClass(simServiceContextClass),
              class_respondsToSelector(metaCls, sharedContextSelector) else { return nil }
        
        let developerDir = "/Applications/Xcode.app/Contents/Developer"
        
        typealias Fn = @convention(c) (AnyClass, Selector, NSString, UnsafeMutableRawPointer?) -> Unmanaged<AnyObject>?
        let imp = class_getMethodImplementation(metaCls, sharedContextSelector)
        guard let contextUnmanaged = unsafeBitCast(imp, to: Fn.self)(simServiceContextClass, sharedContextSelector, developerDir as NSString, nil) else { return nil }
        let context = contextUnmanaged.takeUnretainedValue()
        
        let defaultDeviceSetSelector = NSSelectorFromString("defaultDeviceSetWithError:")
        guard context.responds(to: defaultDeviceSetSelector) else { return nil }
        guard let deviceSetUnmanaged = context.perform(defaultDeviceSetSelector, with: nil) else { return nil }
        let actualDeviceSet = deviceSetUnmanaged.takeUnretainedValue()
        
        guard let devicesArray = actualDeviceSet.value(forKey: "devices") as? [AnyObject] else { return nil }
        
        for device in devicesArray {
            if let deviceUDIDValue = device.value(forKey: "UDID") {
                let deviceUDIDStr = "\(deviceUDIDValue)".uppercased()
                if deviceUDIDStr == udid.uppercased() {
                    return device as? NSObject
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
        guard Self.isAvailable else { return nil }
        guard let device = resolveDevice() else { return nil }

        let token = UUID().uuidString
        let deadline = Date().addingTimeInterval(Self.xpcTimeoutSeconds)
        Self.sharedDispatcher.register(device: device, token: token, deadline: deadline)
        defer { Self.sharedDispatcher.unregister(token: token) }

        guard let translator = Self.sharedTranslator else { return nil }

        guard let translation = Self.frontmostApplication(translator: translator, token: token) else { return nil }
        Self.stamp(token: token, on: translation)

        guard let frontmostRoot = Self.macPlatformElement(translator: translator, translation: translation) else { return nil }
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
        guard translator.responds(to: sel), let imp = class_getMethodImplementation(type(of: translator), sel) else { return nil }
        typealias Fn = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject?
        return unsafeBitCast(imp, to: Fn.self)(translator, sel, translation) as? NSObject
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
}

// MARK: - TokenDispatcher
@objc(AXPTranslatorTokenDispatcher)
protocol TokenDispatcherObjCProtocol {
    func accessibilityTranslationDelegateBridgeCallbackWithToken(_ token: String) -> @convention(block) (NSObject, @escaping @convention(block) (NSObject?, Error?) -> Void) -> Void
}

final class TokenDispatcher: NSObject, TokenDispatcherObjCProtocol {
    struct Entry {
        let device: NSObject
        let deadline: Date
    }

    private let queue = DispatchQueue(label: "TritonKit.AXPTokenDispatcher", qos: .userInteractive)
    private var entries: [String: Entry] = [:]

    func register(device: NSObject, token: String, deadline: Date) {
        queue.sync {
            entries[token] = Entry(device: device, deadline: deadline)
            entries = entries.filter { $0.value.deadline > Date() }
        }
    }

    func unregister(token: String) {
        queue.sync { _ = entries.removeValue(forKey: token) }
    }

    @objc dynamic func accessibilityTranslationDelegateBridgeCallbackWithToken(_ token: String) -> @convention(block) (NSObject, @escaping @convention(block) (NSObject?, Error?) -> Void) -> Void {
        return { [weak self] request, completion in
            guard let self = self else {
                completion(nil, NSError(domain: "TritonKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dispatcher deallocated"]))
                return
            }
            
            let entry: Entry? = self.queue.sync {
                guard let e = self.entries[token], e.deadline > Date() else { return nil }
                return e
            }
            guard let entry = entry else {
                completion(nil, NSError(domain: "TritonKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active TokenDispatcher entry"]))
                return
            }

            let sel = NSSelectorFromString("sendAccessibilityRequestAsync:withCompletion:")
            guard entry.device.responds(to: sel), let imp = class_getMethodImplementation(type(of: entry.device), sel) else {
                completion(nil, NSError(domain: "TritonKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "SimDevice missing sendAccessibilityRequestAsync"]))
                return
            }

            typealias WrappedCompletion = @convention(block) (NSObject?, Error?) -> Void
            typealias Fn = @convention(c) (AnyObject, Selector, AnyObject, WrappedCompletion) -> Void
            
            let completionBlock: WrappedCompletion = { result, error in
                completion(result, error)
            }
            
            unsafeBitCast(imp, to: Fn.self)(entry.device, sel, request, completionBlock)
        }
    }
}

#endif
