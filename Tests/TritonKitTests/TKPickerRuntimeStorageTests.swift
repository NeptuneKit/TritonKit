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

    @Test("runtime toggle is immediate, idempotent and never restarts transport")
    func runtimeToggle() throws {
        let kit = TritonKit.shared
        kit.stop()
        let originalProbe = kit.endpointReadinessProbe
        var probes = 0
        kit.endpointReadinessProbe = { _, _, _ in probes += 1; return false }
        defer { kit.stop(); kit.endpointReadinessProbe = originalProbe }
        var configuration = TritonKit.Configuration(endpoint: .init(host: "127.0.0.1", port: 19422), autoReconnect: false)
        configuration.features.insert(.inspector)
        configuration.picker = .init(enabled: false, ttlSeconds: 45)
        try #require(kit.start(configuration))
        let delegate = kit.delegate
        let initialProbes = probes
        let state = kit.state
        #expect(!kit.isPickerEnabled)
        try #require(kit.setPickerEnabled(true))
        let manager = try #require(kit.pickerStorage.current())
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { window.isHidden = true }
        let label = UILabel(frame: CGRect(x: 20, y: 60, width: 140, height: 40))
        label.text = "Toggle target"
        window.rootViewController?.view.addSubview(label)
        let selected = manager.select(label)
        let selection = try #require(selected.selection)
        kit.setPickerPresentation(magnifier: false, guides: false, feedback: false)
        #expect(!kit.configuration.picker.magnifierEnabled)
        #expect(!kit.configuration.picker.guidesEnabled)
        #expect(!kit.configuration.picker.feedbackEnabled)
        #expect(kit.setPickerEnabled(true))
        #expect(kit.pickerStorage.current() === manager)
        #expect(manager.status().selection?.id == selection.id)
        #expect(kit.setPickerEnabled(false))
        #expect(!kit.isPickerEnabled)
        #expect(kit.pickerStorage.current() == nil)
        #expect(manager.status().state == "none")
        #expect(manager.selectedView == nil)
        #expect(kit.setPickerEnabled(true))
        let replacement = try #require(kit.pickerStorage.current())
        #expect(replacement.runtimeInstanceID != manager.runtimeInstanceID)
        #expect(replacement.status().state == "none")
        #expect(replacement.performGuardedTap(.init(runtimeInstanceID: manager.runtimeInstanceID,
            selectionID: selection.id, revision: selected.revision)).error?.code == "selection_stale")
        #expect(probes == initialProbes)
        #expect(kit.state == state)
        #expect(kit.delegate === delegate)
        #expect(kit.configuration.endpoint == configuration.endpoint)
        #expect(kit.configuration.features == configuration.features)
        #expect(kit.configuration.picker.ttlSeconds == 45)
        kit.stop()
        #expect(!kit.setPickerEnabled(true))
        #expect(!kit.isPickerEnabled)
    }

    @Test("runtime toggle never grants inspector permission")
    func toggleWithoutPermission() {
        let kit = TritonKit.shared
        let originalProbe = kit.endpointReadinessProbe
        kit.endpointReadinessProbe = { _, _, _ in false }
        defer { kit.stop(); kit.endpointReadinessProbe = originalProbe }
        var configuration = TritonKit.Configuration(autoReconnect: false)
        configuration.features.remove(.inspector)
        configuration.picker.enabled = false
        #expect(kit.start(configuration))
        #expect(!kit.setPickerEnabled(true))
        #expect(!kit.configuration.picker.enabled)
        #expect(!kit.isPickerEnabled)
    }

    @Test("immediate toggle wins over a queued configured startup")
    func toggleBeforeStartupQueueDrains() async throws {
        let kit = TritonKit.shared
        let originalProbe = kit.endpointReadinessProbe
        kit.endpointReadinessProbe = { _, _, _ in false }
        defer { kit.stop(); kit.endpointReadinessProbe = originalProbe }
        var configuration = TritonKit.Configuration(autoReconnect: false)
        configuration.features.insert(.inspector)
        configuration.picker.enabled = true
        try #require(kit.start(configuration))
        try #require(kit.setPickerEnabled(true))
        let manager = try #require(kit.pickerStorage.current())
        await Task.yield()
        #expect(kit.pickerStorage.current() === manager)
        #expect(kit.setPickerEnabled(false))
        await Task.yield()
        #expect(kit.pickerStorage.current() == nil)
        #expect(!kit.isPickerEnabled)
    }

    @Test("mutable invalid TTL uses the same fallback during runtime enabling")
    func toggleInvalidTTL() throws {
        let kit = TritonKit.shared
        let originalProbe = kit.endpointReadinessProbe
        kit.endpointReadinessProbe = { _, _, _ in false }
        defer { kit.stop(); kit.endpointReadinessProbe = originalProbe }
        var configuration = TritonKit.Configuration(autoReconnect: false)
        configuration.features.insert(.inspector)
        configuration.picker.enabled = false
        configuration.picker.ttlSeconds = -1
        try #require(kit.start(configuration))
        try #require(kit.setPickerEnabled(true))
        let window = try makeRuntimeTestWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { window.isHidden = true }
        let label = UILabel(frame: CGRect(x: 20, y: 60, width: 140, height: 40))
        label.text = "TTL"
        window.rootViewController?.view.addSubview(label)
        let manager = try #require(kit.pickerStorage.current())
        let selection = try #require(manager.select(label).selection)
        #expect(selection.expiresAt - selection.selectedAt == 300)
    }

    private func cleanup(_ storage: TKPickerRuntimeStorage) {
        let stop = storage.invalidate(enabled: false)
        storage.configure(token: stop, ttlSeconds: 300)
    }
}
}
#endif
