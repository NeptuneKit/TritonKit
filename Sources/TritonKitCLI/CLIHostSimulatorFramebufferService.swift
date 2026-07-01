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
    private var isFrameworksLoaded = false
    private var activeSessions = [String: FramebufferSession]()
    private var sessionRefCount = [String: Int]()
    
    private init() {}
    
    func loadPrivateFrameworks() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if isFrameworksLoaded { return true }
        
        // 动态加载 CoreSimulator (自适应路径搜索)
        let developerDir = "/Applications/Xcode.app/Contents/Developer"
        let coreSimulatorPaths = [
            "\(developerDir)/Library/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator",
            "\(developerDir)/Library/PrivateFrameworks/CoreSimulator.framework/CoreSimulator",
            "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator"
        ]
        
        var coreSimulatorLoaded = false
        for path in coreSimulatorPaths {
            if dlopen(path, RTLD_LAZY) != nil {
                print("[TritonCLI] CoreSimulator loaded from: \(path)")
                fflush(stdout)
                coreSimulatorLoaded = true
                break
            }
        }
        
        guard coreSimulatorLoaded else {
            print("[TritonCLI] Failed to load CoreSimulator.framework from all locations")
            fflush(stdout)
            return false
        }
        
        // 动态加载 SimulatorKit (自适应路径搜索)
        let simulatorKitPaths = [
            "\(developerDir)/Library/PrivateFrameworks/SimulatorKit.framework/Versions/A/SimulatorKit",
            "\(developerDir)/Library/PrivateFrameworks/SimulatorKit.framework/SimulatorKit"
        ]
        
        var simulatorKitLoaded = false
        for path in simulatorKitPaths {
            if dlopen(path, RTLD_LAZY) != nil {
                print("[TritonCLI] SimulatorKit loaded from: \(path)")
                fflush(stdout)
                simulatorKitLoaded = true
                break
            }
        }
        
        guard simulatorKitLoaded else {
            print("[TritonCLI] Failed to load SimulatorKit.framework from all locations")
            fflush(stdout)
            return false
        }
        
        isFrameworksLoaded = true
        print("[TritonCLI] SimulatorKit and CoreSimulator frameworks loaded successfully.")
        fflush(stdout)
        return true
    }
    
    func startStreaming(udid: String) -> Bool {
        guard loadPrivateFrameworks() else { return false }
        
        lock.lock()
        sessionRefCount[udid, default: 0] += 1
        if activeSessions[udid] != nil {
            lock.unlock()
            return true // 已经在线
        }
        lock.unlock()
        
        guard let simServiceContextClass = NSClassFromString("SimServiceContext") else {
            print("[TritonCLI] Class SimServiceContext not found")
            fflush(stdout)
            return false
        }
        
        if let screenAdapterClass = NSClassFromString("SimulatorKit.SimDeviceScreenAdapter") {
            if let metaClass: AnyClass = object_getClass(screenAdapterClass) {
                var count: UInt32 = 0
                if let list = class_copyMethodList(metaClass, &count) {
                    print("[TritonCLI] SimDeviceScreenAdapter Class Methods (\(count)):")
                    for i in 0..<Int(count) {
                        print("  - \(method_getName(list[i]))")
                    }
                    free(list)
                }
            }
            var count: UInt32 = 0
            if let list = class_copyMethodList(screenAdapterClass, &count) {
                print("[TritonCLI] SimDeviceScreenAdapter Instance Methods (\(count)):")
                for i in 0..<Int(count) {
                    print("  - \(method_getName(list[i]))")
                }
                free(list)
            }
        } else {
            print("[TritonCLI] Class SimulatorKit.SimDeviceScreenAdapter not found")
        }
        fflush(stdout)
        
        let simServiceContextClassObj = simServiceContextClass as AnyObject
        let sharedContextSelector = Selector("sharedServiceContextForDeveloperDir:error:")
        
        guard class_getClassMethod(simServiceContextClass, sharedContextSelector) != nil else {
            print("[TritonCLI] Method sharedServiceContextForDeveloperDir:error: not found")
            fflush(stdout)
            return false
        }
        
        guard let contextUnmanaged = simServiceContextClassObj.perform(sharedContextSelector, with: nil, with: nil) else {
            print("[TritonCLI] Failed to create shared SimServiceContext")
            fflush(stdout)
            return false
        }
        let context = contextUnmanaged.takeUnretainedValue()
        
        let defaultDeviceSetSelector = Selector("defaultDeviceSetWithError:")
        guard context.responds(to: defaultDeviceSetSelector) else {
            print("[TritonCLI] Method defaultDeviceSetWithError: not found on SimServiceContext")
            fflush(stdout)
            return false
        }
        
        guard let deviceSetUnmanaged = context.perform(defaultDeviceSetSelector, with: nil) else {
            print("[TritonCLI] Failed to get defaultDeviceSet from SimServiceContext")
            fflush(stdout)
            return false
        }
        let actualDeviceSet = deviceSetUnmanaged.takeUnretainedValue()
        
        guard let devicesArray = actualDeviceSet.value(forKey: "devices") as? [AnyObject] else {
            print("[TritonCLI] Failed to read devices array from SimDeviceSet")
            fflush(stdout)
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
            print("[TritonCLI] Simulator with UDID \(udid) not found in devices list")
            fflush(stdout)
            return false
        }
        
        // 创建我们的 Framebuffer 接收代理并启动
        let session = FramebufferSession(udid: udid)
        guard session.start(simDevice: simDevice) else {
            print("[TritonCLI] Failed to start FramebufferSession for \(udid)")
            fflush(stdout)
            return false
        }
        
        lock.lock()
        activeSessions[udid] = session
        lock.unlock()
        
        print("[TritonCLI] Started host framebuffer streaming for \(udid)")
        fflush(stdout)
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
        print("[TritonCLI] Stopped host framebuffer streaming for \(udid)")
        fflush(stdout)
    }
    
    func getLatestFrame(udid: String) -> Data? {
        lock.lock()
        let session = activeSessions[udid]
        lock.unlock()
        return session?.getLatestJPEGData()
    }
}

// ─── 帧捕获会话 ───
final class FramebufferSession: @unchecked Sendable {
    let udid: String
    
    private let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    private let queue = DispatchQueue(label: "com.neptunekit.tritonkit.framebuffer-encoding", qos: .userInteractive)
    
    private let lock = NSLock()
    private var latestJPEGData: Data?
    
    private var descriptors: [AnyObject] = []
    private var callbackUUIDs: [ObjectIdentifier: NSUUID] = [:]
    
    private var frameBlock: (@convention(block) () -> Void)?
    private var surfacesBlock: (@convention(block) () -> Void)?
    private var propertiesBlock: (@convention(block) () -> Void)?
    
    init(udid: String) {
        self.udid = udid
    }
    
    func start(simDevice: AnyObject) -> Bool {
        let device = simDevice as! NSObject
        
        let ioSel = NSSelectorFromString("io")
        guard let imp = class_getMethodImplementation(type(of: device), ioSel) else {
            print("[TritonCLI] Failed to get io implementation from device")
            fflush(stdout)
            return false
        }
        typealias IoFn = @convention(c) (AnyObject, Selector) -> AnyObject?
        guard let ioVal = unsafeBitCast(imp, to: IoFn.self)(device, ioSel) else {
            print("[TritonCLI] Failed to get io value from device")
            fflush(stdout)
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
            print("[TritonCLI] No deviceIOPorts found")
            fflush(stdout)
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
        
        guard !candidates.isEmpty else {
            print("[TritonCLI] No display descriptors found on device")
            fflush(stdout)
            return false
        }
        
        self.descriptors = candidates
        
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
        let props: @convention(block) () -> Void = {}
        
        self.frameBlock = frame
        self.surfacesBlock = surfaces
        self.propertiesBlock = props
        
        for desc in candidates {
            if desc.responds(to: regSel) {
                let uuid = NSUUID()
                callbackUUIDs[ObjectIdentifier(desc)] = uuid
                
                guard let imp = class_getMethodImplementation(type(of: desc), regSel) else {
                    continue
                }
                
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
        
        // Trigger initial capture
        queue.async { [weak self] in
            self?.captureLatest()
        }
        
        return true
    }
    
    private func captureLatest() {
        let surfSel = NSSelectorFromString("framebufferSurface")
        var best: IOSurface?
        var bestArea = 0
        for desc in descriptors {
            if let surfObj = desc.perform(surfSel)?.takeUnretainedValue() {
                let surf = unsafeBitCast(surfObj, to: IOSurface.self)
                let area = IOSurfaceGetWidth(surf) * IOSurfaceGetHeight(surf)
                if area > bestArea {
                    best = surf
                    bestArea = area
                }
            }
        }
        if let best {
            processFrame(surface: best)
        }
    }
    
    private var hasPrintedFirstFrame = false
    
    func processFrame(surface: IOSurfaceRef) {
        if !hasPrintedFirstFrame {
            hasPrintedFirstFrame = true
            print("[TritonCLI] Successfully captured the first IOSurface framebuffer frame from Simulator!")
            fflush(stdout)
        }
        
        let ciImage = CIImage(ioSurface: surface)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let options: [CIImageRepresentationOption: Any] = [
            .init(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.6
        ]
        if let data = self.ciContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace, options: options) {
            self.lock.lock()
            self.latestJPEGData = data
            self.lock.unlock()
        }
    }
    
    func getLatestJPEGData() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return latestJPEGData
    }
    
    func stop() {
        let unregSel = NSSelectorFromString("unregisterScreenCallbacksWithUUID:")
        for desc in descriptors {
            if let uuid = callbackUUIDs[ObjectIdentifier(desc)] {
                if desc.responds(to: unregSel) {
                    _ = desc.perform(unregSel, with: uuid)
                }
            }
        }
        descriptors.removeAll()
        callbackUUIDs.removeAll()
        frameBlock = nil
        surfacesBlock = nil
        propertiesBlock = nil
    }
}
