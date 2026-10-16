import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

#if canImport(UIKit)
/// The generation fences queued starts/stops; UIKit objects are used only on MainActor.
final class TKPickerRuntimeStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var enabled = false
    @MainActor private var manager: TKPickerSessionManager?
    @MainActor private var managerGeneration: UInt64?
    @MainActor private var overlay: TKPickerOverlayCoordinator?

    func invalidate(enabled: Bool) -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        generation &+= 1
        self.enabled = enabled
        return generation
    }
    func accepts(_ token: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return token == generation
    }
    var isEnabled: Bool {
        lock.lock(); defer { lock.unlock() }
        return enabled
    }
    private func isCurrentEnabledGeneration(_ token: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return enabled && token == generation
    }
    @MainActor func configure(token: UInt64, ttlSeconds: Int) {
        guard accepts(token) else { return }
        if managerGeneration == token, manager != nil { return }
        overlay?.stop(); overlay = nil
        manager?.shutdown(); manager = nil
        managerGeneration = nil
        guard isCurrentEnabledGeneration(token) else { return }
        let manager = TKPickerSessionManager(ttlSeconds: ttlSeconds)
        self.manager = manager
        managerGeneration = token
        let overlay = TKPickerOverlayCoordinator(manager: manager, onHide: {
            TritonKit.shared.setPickerEnabled(false)
        })
        self.overlay = overlay
        overlay.start()
    }
    @MainActor func updatePresentation(_ configuration: TritonKit.PickerConfiguration) {
        overlay?.updatePresentation(configuration)
    }
    @MainActor func current() -> TKPickerSessionManager? {
        // A new enabled configuration must not expose the previous selection
        // while its MainActor configure task is still queued. Check enabled and
        // generation in one lock snapshot, including cross-thread invalidation.
        guard let managerGeneration, isCurrentEnabledGeneration(managerGeneration) else { return nil }
        return manager
    }
}
#endif

extension TritonKit {
    func startPickerRuntime(_ configuration: Configuration) {
        #if canImport(UIKit)
        let enabled = Self.isRuntimeEnabled && configuration.features.contains(.inspector) && configuration.picker.enabled
        let token = pickerStorage.invalidate(enabled: enabled)
        let ttl = (1...300).contains(configuration.picker.ttlSeconds) ? configuration.picker.ttlSeconds : 300
        Task { @MainActor [pickerStorage] in
            pickerStorage.configure(token: token, ttlSeconds: ttl)
            if pickerStorage.accepts(token) { pickerStorage.updatePresentation(TritonKit.shared.configuration.picker) }
        }
        #endif
    }
    func stopPickerRuntime() {
        #if canImport(UIKit)
        let token = pickerStorage.invalidate(enabled: false)
        Task { @MainActor [pickerStorage] in pickerStorage.configure(token: token, ttlSeconds: 300) }
        #endif
    }
}
