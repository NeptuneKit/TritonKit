import Foundation
import CoreImage
import IOSurface
import CoreGraphics

@globalActor
actor FramebufferActor {
    static let shared = FramebufferActor()
}

final class CLIHostSimulatorFramebufferService: @unchecked Sendable {
    static let shared = CLIHostSimulatorFramebufferService()

    private let lock = NSLock()
    private let frameworkLoader = FramebufferFrameworkLoader()
    private var selectedDeveloperDirectory: String?
    private var activeSessions = [String: FramebufferSession]()
    private var sessionRefCount = [String: Int]()

    private init() {}

    func loadPrivateFrameworks() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let plan = framebufferFrameworkPlan(developerDirectory: selectedXcodeDeveloperDirectory(environment: ProcessInfo.processInfo.environment)),
              frameworkLoader.load(plan, load: { dlopen($0, RTLD_LAZY | RTLD_LOCAL) != nil }) else { return false }
        selectedDeveloperDirectory = plan.developerDirectory
        return true
    }

    func startStreaming(udid: String) -> Bool {
        guard loadPrivateFrameworks() else { return false }
        let developerDirectory = lock.withLock { selectedDeveloperDirectory }
        guard let developerDirectory,
              case .binding(let binding) = probeSimulatorFramebufferDisplayBinding(
                target: udid, environment: ["DEVELOPER_DIR": developerDirectory]
              ) else { return false }

        lock.lock()
        defer { lock.unlock() }
        if let session = activeSessions[udid] {
            guard session.isBound(to: binding.displayUniqueID) else { return false }
            sessionRefCount[udid, default: 0] += 1
            return true
        }

        guard let simServiceContextClass = NSClassFromString("SimServiceContext") else {
            return false
        }

        let simServiceContextClassObj = simServiceContextClass as AnyObject
        let sharedContextSelector = Selector("sharedServiceContextForDeveloperDir:error:")

        guard class_getClassMethod(simServiceContextClass, sharedContextSelector) != nil else {
            return false
        }

        guard let contextUnmanaged = simServiceContextClassObj.perform(sharedContextSelector, with: selectedDeveloperDirectory, with: nil) else {
            return false
        }
        let context = contextUnmanaged.takeUnretainedValue()

        let defaultDeviceSetSelector = Selector("defaultDeviceSetWithError:")
        guard context.responds(to: defaultDeviceSetSelector) else {
            return false
        }

        guard let deviceSetUnmanaged = context.perform(defaultDeviceSetSelector, with: nil) else {
            return false
        }
        let actualDeviceSet = deviceSetUnmanaged.takeUnretainedValue()

        guard let devicesArray = actualDeviceSet.value(forKey: "devices") as? [AnyObject] else {
            return false
        }

        var targetDevice: AnyObject? = nil
        for device in devicesArray {
            if let deviceUDIDValue = device.value(forKey: "UDID") {
                let deviceUDIDStr = "\(deviceUDIDValue)".uppercased()
                if deviceUDIDStr == udid.uppercased() {
                    targetDevice = device
                    break
                }
            }
        }

        guard let simDevice = targetDevice else {
            return false
        }

        // 创建我们的 Framebuffer 接收代理并启动
        let session = FramebufferSession(udid: udid)
        guard session.start(simDevice: simDevice, primaryDisplayUUID: binding.displayUniqueID) else {
            return false
        }

        activeSessions[udid] = session
        sessionRefCount[udid] = 1

        return true
    }

    func stopStreaming(udid: String) {
        lock.lock()
        if let count = sessionRefCount[udid] {
            let newCount = count - 1
            sessionRefCount[udid] = newCount
            if newCount > 0 {
                lock.unlock()
                return // 仍有其他活跃监听者
            }
        }
        sessionRefCount.removeValue(forKey: udid)
        let session = activeSessions.removeValue(forKey: udid)
        lock.unlock()

        guard let actualSession = session else { return }
        actualSession.stop()
    }

    func getLatestFrame(udid: String) -> Data? {
        lock.lock()
        let session = activeSessions[udid]
        lock.unlock()
        return session?.getLatestFrameWithVersion()?.0
    }

    func getLatestFrameWithVersion(udid: String) -> (Data, UInt64)? {
        lock.lock()
        let session = activeSessions[udid]
        lock.unlock()
        return session?.getLatestFrameWithVersion()
    }
}

// ─── 帧捕获会话 ───
final class FramebufferSession: @unchecked Sendable {
    let udid: String

    private let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    private let queue = DispatchQueue(label: "com.neptunekit.tritonkit.framebuffer-encoding", qos: .userInteractive)

    let lock = NSLock()
    private var latestJPEGData: Data?
    private var latestFrameVersion: UInt64 = 0
    private var isStopped = false

    private var descriptors: [NSObject] = []
    private var primaryDisplayUUID: UUID?
    private var callbackUUIDs: [ObjectIdentifier: NSUUID] = [:]

    private var frameBlock: (@convention(block) () -> Void)?
    private var surfacesBlock: (@convention(block) () -> Void)?
    private var propertiesBlock: (@convention(block) () -> Void)?

    init(udid: String) {
        self.udid = udid
    }

    func start(simDevice: AnyObject, primaryDisplayUUID: UUID? = nil) -> Bool {
        guard lock.withLock({ !isStopped && descriptors.isEmpty }) else { return false }
        let device = simDevice as! NSObject

        let ioSel = NSSelectorFromString("io")
        guard let imp = class_getMethodImplementation(type(of: device), ioSel) else {
            return false
        }
        typealias IoFn = @convention(c) (AnyObject, Selector) -> AnyObject?
        guard let ioVal = unsafeBitCast(imp, to: IoFn.self)(device, ioSel) else {
            return false
        }
        let io = ioVal as! NSObject

        // Update IO ports
        let updateIOPortsSel = NSSelectorFromString("updateIOPorts")
        if let updateImp = class_getMethodImplementation(type(of: io), updateIOPortsSel) {
            typealias UpdateFn = @convention(c) (AnyObject, Selector) -> Void
            unsafeBitCast(updateImp, to: UpdateFn.self)(io, updateIOPortsSel)
        }

        guard let ports = io.value(forKey: "deviceIOPorts") as? [NSObject] else {
            return false
        }

        let pidSel = NSSelectorFromString("portIdentifier")
        let descSel = NSSelectorFromString("descriptor")
        let surfSel = NSSelectorFromString("framebufferSurface")

        var candidates: [NSObject] = []
        for port in ports {
            if port.responds(to: pidSel) {
                let pidVal = port.perform(pidSel)
                if let pid = pidVal?.takeUnretainedValue() {
                    let pidStr = "\(pid)"
                    if pidStr == "com.apple.framebuffer.display" {
                        if port.responds(to: descSel) {
                            if let desc = port.perform(descSel)?.takeUnretainedValue() as? NSObject {
                                if desc.responds(to: surfSel) {
                                    candidates.append(desc)
                                }
                            }
                        }
                    }
                }
            }
        }

        guard let primary = selectSimulatorPrimaryFramebufferDescriptor(candidates, primaryDisplayUUID: primaryDisplayUUID) else { return false }
        candidates = [primary]

        self.lock.lock()
        self.descriptors = candidates
        self.primaryDisplayUUID = primaryDisplayUUID
        self.isStopped = false
        self.lock.unlock()

        // Register callbacks
        let regSel = NSSelectorFromString(
            "registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:"
        )

        let frame: @convention(block) () -> Void = { [weak self] in
            self?.queue.async { self?.captureLatest() }
        }
        let surfaces: @convention(block) () -> Void = { [weak self] in
            self?.queue.async { self?.captureLatest() }
        }
        let props: @convention(block) () -> Void = { [weak self] in
            self?.queue.async { self?.captureLatest() }
        }

        self.frameBlock = frame
        self.surfacesBlock = surfaces
        self.propertiesBlock = props

        for desc in candidates {
            if desc.responds(to: regSel) {
                guard let imp = class_getMethodImplementation(type(of: desc), regSel) else {
                    continue
                }
                let uuid = NSUUID()
                callbackUUIDs[ObjectIdentifier(desc)] = uuid

                typealias Fn = @convention(c) (
                    AnyObject, Selector, AnyObject, AnyObject, AnyObject, AnyObject, AnyObject
                ) -> Void

                unsafeBitCast(imp, to: Fn.self)(
                    desc, regSel,
                    uuid, queue as AnyObject,
                    frame as AnyObject, surfaces as AnyObject, props as AnyObject
                )
            }
        }

        guard !callbackUUIDs.isEmpty else {
            stop()
            return false
        }

        // Trigger initial capture
        queue.async { [weak self] in
            self?.captureLatest()
        }

        return true
    }

    func isBound(to displayUniqueID: UUID) -> Bool {
        lock.withLock { !isStopped && primaryDisplayUUID == displayUniqueID }
    }

    private func captureLatest() {
        let surfSel = NSSelectorFromString("framebufferSurface")
        lock.lock()
        guard !isStopped else { lock.unlock(); return }
        let currentDescriptors = descriptors
        let expectedDisplayUUID = primaryDisplayUUID
        lock.unlock()
        guard let descriptor = selectSimulatorPrimaryFramebufferDescriptor(currentDescriptors, primaryDisplayUUID: expectedDisplayUUID),
              let surfaceObject = descriptor.perform(surfSel)?.takeUnretainedValue() else {
            // A missing or changed primary never authorizes another surface or a stale frame.
            lock.withLock { latestJPEGData = nil }
            return
        }
        processFrame(surface: unsafeBitCast(surfaceObject, to: IOSurface.self))
    }

    func processFrame(surface: IOSurfaceRef) {
        autoreleasepool {
            lock.lock()
            let stopped = isStopped
            lock.unlock()
            guard !stopped else { return }
            let ciImage = CIImage(ioSurface: surface)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let options: [CIImageRepresentationOption: Any] = [
                .init(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.6
            ]
            if let data = self.ciContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace, options: options) {
                self.lock.lock()
                if !self.isStopped, data != self.latestJPEGData {
                    self.latestJPEGData = data
                    self.latestFrameVersion += 1
                }
                self.lock.unlock()
            }
        }
    }

    func getLatestFrameWithVersion() -> (Data, UInt64)? {
        lock.lock()
        defer { lock.unlock() }
        if !isStopped, let data = latestJPEGData {
            return (data, latestFrameVersion)
        }
        return nil
    }

    func stop() {
        lock.lock()
        isStopped = true
        latestJPEGData = nil
        let currentDescriptors = descriptors
        descriptors.removeAll()
        primaryDisplayUUID = nil
        lock.unlock()
        // Serialize private descriptor teardown with already queued captures;
        // the public stop path never waits on a private framework callback.
        queue.async { [self] in
            let unregSel = NSSelectorFromString("unregisterScreenCallbacksWithUUID:")
            for desc in currentDescriptors {
                if let uuid = callbackUUIDs[ObjectIdentifier(desc)], desc.responds(to: unregSel) {
                    _ = desc.perform(unregSel, with: uuid)
                }
            }
            callbackUUIDs.removeAll()
            frameBlock = nil
            surfacesBlock = nil
            propertiesBlock = nil
        }
    }
}
