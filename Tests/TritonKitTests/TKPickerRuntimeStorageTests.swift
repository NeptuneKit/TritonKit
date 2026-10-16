import Testing
@testable import TritonKit

#if canImport(UIKit)
import UIKit

extension TKUIKitWindowTests {
@Suite(.serialized)
@MainActor
struct TKPickerRuntimeStorageTests {
    @Test("reenabling fences the previous manager before queued configure executes")
    func enabledGenerationFence() throws {
        let storage = TKPickerRuntimeStorage()
        defer { cleanup(storage) }
        let initialToken = storage.invalidate(enabled: true)
        storage.configure(token: initialToken, ttlSeconds: 300)
        let initial = try #require(storage.current())
        let replacementToken = storage.invalidate(enabled: true)
        #expect(storage.current() == nil)
        storage.configure(token: initialToken, ttlSeconds: 300)
        #expect(storage.current() == nil)
        storage.configure(token: replacementToken, ttlSeconds: 300)
        let replacement = try #require(storage.current())
        #expect(replacement !== initial)
        #expect(replacement.runtimeInstanceID != initial.runtimeInstanceID)
    }

    @Test("disabling immediately hides the manager before UIKit cleanup executes")
    func disabledImmediately() throws {
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { window.isHidden = true }
        let label = UILabel(frame: CGRect(x: 20, y: 60, width: 140, height: 40))
        label.text = "Before stop"
        window.rootViewController?.view.addSubview(label)
        let storage = TKPickerRuntimeStorage()
        defer { cleanup(storage) }
        let enabled = storage.invalidate(enabled: true)
        storage.configure(token: enabled, ttlSeconds: 300)
        let initial = try #require(storage.current())
        try #require(initial.select(label).selection != nil)
        let disabled = storage.invalidate(enabled: false)
        #expect(storage.current() == nil)
        storage.configure(token: disabled, ttlSeconds: 300)
        #expect(storage.current() == nil)
        #expect(initial.status().state == "none")
        #expect(initial.selectedView == nil)
        storage.configure(token: enabled, ttlSeconds: 300)
        #expect(storage.current() == nil)
    }

    @Test("out-of-order start-stop-start configure cannot tear down the newest manager")
    func outOfOrderConfigure() throws {
        let storage = TKPickerRuntimeStorage()
        defer { cleanup(storage) }
        let firstStart = storage.invalidate(enabled: true)
        let stop = storage.invalidate(enabled: false)
        let finalStart = storage.invalidate(enabled: true)
        storage.configure(token: finalStart, ttlSeconds: 300)
        let final = try #require(storage.current())
        storage.configure(token: stop, ttlSeconds: 300)
        storage.configure(token: firstStart, ttlSeconds: 300)
        #expect(storage.current() === final)
        #expect(!storage.accepts(firstStart))
        #expect(!storage.accepts(stop))
        #expect(storage.accepts(finalStart))
    }

    @Test("queued MainActor starts and stops converge only to the latest generation")
    func queuedConfigure() async throws {
        let storage = TKPickerRuntimeStorage()
        defer { cleanup(storage) }
        let firstStart = storage.invalidate(enabled: true)
        let firstTask = Task { @MainActor in storage.configure(token: firstStart, ttlSeconds: 300) }
        let stop = storage.invalidate(enabled: false)
        let stopTask = Task { @MainActor in storage.configure(token: stop, ttlSeconds: 300) }
        let finalStart = storage.invalidate(enabled: true)
        let finalTask = Task { @MainActor in storage.configure(token: finalStart, ttlSeconds: 300) }
        #expect(storage.current() == nil)
        await firstTask.value
        await stopTask.value
        await finalTask.value
        let final = try #require(storage.current())
        #expect(final.status().state == "none")
        #expect(storage.accepts(finalStart))
        #expect(!storage.accepts(stop))
    }

    private func cleanup(_ storage: TKPickerRuntimeStorage) {
        let stop = storage.invalidate(enabled: false)
        storage.configure(token: stop, ttlSeconds: 300)
    }
}
}
#endif
