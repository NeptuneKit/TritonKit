// Digitizer construction and Indigo dispatch adapted from tddworks/baguette,
// commit 51f8ea2e0ee6d81523e8a85165f9abe0f899a9df (Apache-2.0):
// Sources/Baguette/Infrastructure/Input/{IOHIDDigitizerDispatch,IndigoHIDInput,IndigoHIDMessage}.swift.
// TritonKit restricts this bridge to the existing main-screen digitizer, checks
// the entire known message layout before patching, and reports typed failures.
import Foundation
import CoreGraphics
import ObjectiveC
import Darwin
import IOKit
import TritonKitShared

enum NativeDigitizerPhase: Equatable {
    case down, move, up
    var eventMask: UInt32 { self == .up ? 0x06 : 0x07 }
    var range: Bool { self != .up }
    var touch: Bool { self != .up }
}

enum NativeDigitizerError: Error, Equatable {
    case frameworkMissing, frameworkLoadFailed, legacyClientUnavailable
    case clientInitializationFailed, symbolUnavailable, messageInvalid
    case sendFailed, timeout, geometryUnavailable, invalidPoint
    case targetUnavailable, targetNotBooted

    var detail: TKCLIErrorDetail {
        let code: String
        let message: String
        switch self {
        case .frameworkMissing:
            code = "framework_unavailable"; message = "The selected Xcode does not provide the required simulator frameworks."
        case .frameworkLoadFailed:
            code = "framework_load_failed"; message = "The selected simulator frameworks could not be loaded."
        case .legacyClientUnavailable:
            code = "legacy_backend_unavailable"; message = "The selected SimulatorKit does not provide the native HID client."
        case .clientInitializationFailed:
            code = "client_init_failed"; message = "The native simulator HID client could not be initialized."
        case .symbolUnavailable:
            code = "symbol_unavailable"; message = "A required native simulator HID symbol is unavailable."
        case .messageInvalid:
            code = "message_invalid"; message = "The native simulator digitizer message could not be validated."
        case .sendFailed:
            code = "send_failed"; message = "Native simulator HID transport reported a send failure."
        case .timeout:
            code = "send_timeout"; message = "Native simulator HID transport timed out; delivery outcome is unknown."
        case .geometryUnavailable:
            code = "geometry_unavailable"; message = "The simulator main-screen point geometry is unavailable."
        case .invalidPoint:
            code = "invalid_point"; message = "Native simulator touch coordinates must be finite normalized values between zero and one."
        case .targetUnavailable:
            code = "target_unavailable"; message = "The selected simulator target is unavailable in the selected developer context."
        case .targetNotBooted:
            code = "target_not_booted"; message = "The selected simulator target is not booted."
        }
        return TKCLIErrorDetail(code: "ios_host_hid_" + code, message: message)
    }
}

/// Loaded only inside the isolated native-input helper. This sender owns no
/// pointer/mouse services and performs no accessibility actions or recovery.
final class NativeSimulatorDigitizer {
    let pointSize: CGSize
    private let client: AnyObject
    private let createParent: CreateDigitizer
    private let createFinger: CreateFinger
    private let append: AppendEvent
    private let wrap: TrackpadWrapper
    private let sendFunction: SendMessage
    private let sendSelector = NSSelectorFromString("sendWithMessage:freeWhenDone:completionQueue:completion:")
    private let completionQueue = DispatchQueue(label: "triton.native-hid.completion")

    private typealias CreateDigitizer = @convention(c) (
        CFAllocator?, UInt64, UInt32, UInt32, UInt32, UInt32, UInt32,
        Double, Double, Double, Double, Double, Bool, Bool, UInt32
    ) -> Unmanaged<CFTypeRef>?
    private typealias CreateFinger = @convention(c) (
        CFAllocator?, UInt64, UInt32, UInt32, UInt32,
        Double, Double, Double, Double, Double, Bool, Bool, UInt32
    ) -> Unmanaged<CFTypeRef>?
    private typealias AppendEvent = @convention(c) (CFTypeRef, CFTypeRef, UInt32) -> Void
    private typealias TrackpadWrapper = @convention(c) (UnsafeRawPointer) -> UnsafeMutableRawPointer?
    private typealias SendMessage = @convention(c) (
        AnyObject, Selector, UnsafeMutableRawPointer, Bool, DispatchQueue?,
        (@convention(block) (NSError?) -> Void)?
    ) -> Void

    init(target: String, developerDirectory: String) throws {
        guard let targetID = UUID(uuidString: target) else { throw NativeDigitizerError.targetUnavailable }
        guard let plan = framebufferFrameworkPlan(developerDirectory: developerDirectory) else {
            throw NativeDigitizerError.frameworkMissing
        }
        // Framework classes and their IMPs live until helper exit; never dlclose.
        guard dlopen(plan.coreSimulator, RTLD_NOW | RTLD_LOCAL) != nil,
              let simulatorKit = dlopen(plan.simulatorKit, RTLD_NOW | RTLD_LOCAL) else {
            throw NativeDigitizerError.frameworkLoadFailed
        }
        let symbols = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        guard let parentSymbol = dlsym(symbols, "IOHIDEventCreateDigitizerEvent"),
              let fingerSymbol = dlsym(symbols, "IOHIDEventCreateDigitizerFingerEvent"),
              let appendSymbol = dlsym(symbols, "IOHIDEventAppendEvent"),
              let wrapperSymbol = dlsym(simulatorKit, "IndigoHIDMessageForTrackpadEventFromHIDEventRef") else {
            throw NativeDigitizerError.symbolUnavailable
        }
        createParent = unsafeBitCast(parentSymbol, to: CreateDigitizer.self)
        createFinger = unsafeBitCast(fingerSymbol, to: CreateFinger.self)
        append = unsafeBitCast(appendSymbol, to: AppendEvent.self)
        wrap = unsafeBitCast(wrapperSymbol, to: TrackpadWrapper.self)

        let device = try Self.resolveDevice(target: targetID, developerDirectory: plan.developerDirectory)
        do { pointSize = try AXPTranslatorAccessibility.devicePointSize(for: device) }
        catch { throw NativeDigitizerError.geometryUnavailable }
        let names = ["_TtC12SimulatorKit24SimDeviceLegacyHIDClient", "SimulatorKit.SimDeviceLegacyHIDClient", "SimDeviceLegacyHIDClient"]
        guard let cls = names.compactMap(NSClassFromString).first else {
            throw NativeDigitizerError.legacyClientUnavailable
        }
        let initialize = NSSelectorFromString("initWithDevice:error:")
        let allocate = NSSelectorFromString("alloc")
        guard let meta = object_getClass(cls),
              let allocator = class_getClassMethod(cls, allocate),
              let initializer = class_getInstanceMethod(cls, initialize),
              class_respondsToSelector(meta, allocate) else {
            throw NativeDigitizerError.clientInitializationFailed
        }
        // Match SimulatorKit's Objective-C alloc/init bridge. The initialized
        // client is retained by this instance for all transport completions.
        typealias Allocate = @convention(c) (AnyClass, Selector) -> AnyObject?
        typealias Initialize = @convention(c) (
            AnyObject, Selector, AnyObject, AutoreleasingUnsafeMutablePointer<NSError?>
        ) -> AnyObject?
        let allocateFn = unsafeBitCast(method_getImplementation(allocator), to: Allocate.self)
        let initializeFn = unsafeBitCast(method_getImplementation(initializer), to: Initialize.self)
        guard let allocated = allocateFn(cls, allocate) else {
            throw NativeDigitizerError.clientInitializationFailed
        }
        var error: NSError?
        guard let initialized = initializeFn(allocated, initialize, device, &error), error == nil else {
            throw NativeDigitizerError.clientInitializationFailed
        }
        let selector = NSSelectorFromString("sendWithMessage:freeWhenDone:completionQueue:completion:")
        guard let actualClass = object_getClass(initialized),
              let sendMethod = class_getInstanceMethod(actualClass, selector) else {
            throw NativeDigitizerError.symbolUnavailable
        }
        client = initialized
        sendFunction = unsafeBitCast(method_getImplementation(sendMethod), to: SendMessage.self)
    }

    static func validate(point: CGPoint) throws {
        guard point.x.isFinite, point.y.isFinite,
              (0...1).contains(point.x), (0...1).contains(point.y) else {
            throw NativeDigitizerError.invalidPoint
        }
    }

    /// Pure bounded patch, exposed to tests without allocating a HID event.
    /// The pinned trackpad wrapper emits two records in a 384-byte allocation.
    /// Reject even a shorter buffer that happens to cover the final patch slot.
    static func patch(message: UnsafeMutableRawPointer, allocationSize: Int) throws {
        guard allocationSize >= 384, allocationSize >= 0x110 else {
            throw NativeDigitizerError.messageInvalid
        }
        message.storeBytes(of: UInt32(0x32), toByteOffset: 0x6c, as: UInt32.self)
        message.storeBytes(of: UInt32(0x32), toByteOffset: 0x10c, as: UInt32.self)
        for offset in [0x3a, 0x3b, 0xda, 0xdb] {
            message.storeBytes(of: UInt8(0), toByteOffset: offset, as: UInt8.self)
        }
    }

    func send(point: CGPoint, phase: NativeDigitizerPhase, identifier: UInt32) throws {
        try Self.validate(point: point)
        let now = mach_absolute_time()
        guard let parentRef = createParent(nil, now, 2, 0, identifier, phase.eventMask, 0,
                                           Double(point.x), Double(point.y), 0, 0, 0, phase.range, phase.touch, 0) else {
            throw NativeDigitizerError.messageInvalid
        }
        let parent = parentRef.takeRetainedValue()
        // A parent without its finger produces an unusable stub. Never send it.
        guard let fingerRef = createFinger(nil, now, 0, identifier, phase.eventMask,
                                           Double(point.x), Double(point.y), 0, 0, 0, phase.range, phase.touch, 0) else {
            throw NativeDigitizerError.messageInvalid
        }
        let finger = fingerRef.takeRetainedValue()
        append(parent, finger, 0)
        let raw = withExtendedLifetime((parent, finger)) {
            wrap(UnsafeRawPointer(Unmanaged.passUnretained(parent as AnyObject).toOpaque()))
        }
        guard let raw else { throw NativeDigitizerError.messageInvalid }
        do { try Self.patch(message: raw, allocationSize: malloc_size(raw)) }
        catch { free(raw); throw error }

        let completed = DispatchSemaphore(value: 0)
        let result = NativeDigitizerCompletion()
        let completion: @convention(block) (NSError?) -> Void = { error in
            result.finish(failed: error != nil)
            completed.signal()
        }
        // Ownership passes to SimulatorKit, including after timeout. Do not
        // free, retry, or infer guest delivery from a transport acknowledgement.
        sendFunction(client, sendSelector, raw, true, completionQueue, completion)
        guard completed.wait(timeout: .now() + 2) == .success else { throw NativeDigitizerError.timeout }
        if result.failed { throw NativeDigitizerError.sendFailed }
    }

    private static func resolveDevice(target: UUID, developerDirectory: String) throws -> NSObject {
        let shared = NSSelectorFromString("sharedServiceContextForDeveloperDir:error:")
        guard let cls = NSClassFromString("SimServiceContext"),
              let method = class_getClassMethod(cls, shared) else { throw NativeDigitizerError.symbolUnavailable }
        typealias Context = @convention(c) (
            AnyClass, Selector, NSString, AutoreleasingUnsafeMutablePointer<NSError?>
        ) -> Unmanaged<AnyObject>?
        var error: NSError?
        let contextFn = unsafeBitCast(method_getImplementation(method), to: Context.self)
        guard let context = contextFn(cls, shared, developerDirectory as NSString, &error)?.takeUnretainedValue() as? NSObject,
              error == nil else { throw NativeDigitizerError.targetUnavailable }
        let defaultSet = NSSelectorFromString("defaultDeviceSetWithError:")
        guard let contextClass = object_getClass(context),
              let setMethod = class_getInstanceMethod(contextClass, defaultSet) else {
            throw NativeDigitizerError.symbolUnavailable
        }
        typealias DeviceSet = @convention(c) (
            AnyObject, Selector, AutoreleasingUnsafeMutablePointer<NSError?>
        ) -> Unmanaged<AnyObject>?
        let setFn = unsafeBitCast(method_getImplementation(setMethod), to: DeviceSet.self)
        guard let set = setFn(context, defaultSet, &error)?.takeUnretainedValue() as? NSObject,
              error == nil else { throw NativeDigitizerError.targetUnavailable }
        for key in ["devices", "availableDevices"] {
            guard let devices = objectProperty(set, key: key) as? [NSObject] else { continue }
            for device in devices {
                guard let id = objectProperty(device, key: "UDID") as? NSUUID,
                      id as UUID == target else { continue }
                let state = NSSelectorFromString("state")
                guard let deviceClass = object_getClass(device),
                      let stateMethod = class_getInstanceMethod(deviceClass, state) else {
                    throw NativeDigitizerError.targetUnavailable
                }
                typealias State = @convention(c) (AnyObject, Selector) -> UInt
                let stateFn = unsafeBitCast(method_getImplementation(stateMethod), to: State.self)
                guard stateFn(device, state) == 3 else { throw NativeDigitizerError.targetNotBooted }
                return device
            }
        }
        throw NativeDigitizerError.targetUnavailable
    }

    private static func objectProperty(_ object: NSObject, key: String) -> AnyObject? {
        let selector = NSSelectorFromString(key)
        guard let cls = object_getClass(object),
              let method = class_getInstanceMethod(cls, selector) else { return nil }
        typealias Getter = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        let getter = unsafeBitCast(method_getImplementation(method), to: Getter.self)
        return getter(object, selector)?.takeUnretainedValue()
    }
}

private final class NativeDigitizerCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var didFail = false
    func finish(failed: Bool) { lock.lock(); didFail = failed; lock.unlock() }
    var failed: Bool { lock.lock(); defer { lock.unlock() }; return didFail }
}
