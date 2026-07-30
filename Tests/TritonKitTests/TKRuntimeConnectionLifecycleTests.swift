import Testing
@testable import TritonKit

@Suite
struct TKRuntimeConnectionLifecycleTests {
    @Test("a new app process connection invalidates callbacks from the previous transport")
    func newConnectionInvalidatesPreviousTransportCallbacks() {
        let lifecycle = RuntimeConnectionLifecycle()
        let previous = lifecycle.beginConnection()
        let current = lifecycle.beginConnection()

        #expect(previous != current)
        #expect(!lifecycle.acceptsCallback(for: previous))
        #expect(lifecycle.acceptsCallback(for: current))
    }

    @Test("reconnect is single-flight and cannot survive a newer connection")
    func reconnectIsSingleFlightAndGenerationBound() {
        let lifecycle = RuntimeConnectionLifecycle()
        let disconnected = lifecycle.beginConnection()

        #expect(lifecycle.scheduleReconnect(for: disconnected))
        #expect(!lifecycle.scheduleReconnect(for: disconnected))
        #expect(lifecycle.hasPendingReconnect)

        let relaunched = lifecycle.beginConnection()
        #expect(!lifecycle.hasPendingReconnect)
        #expect(!lifecycle.consumeReconnect(for: disconnected))
        #expect(lifecycle.acceptsCallback(for: relaunched))
    }

    @Test("stop invalidates receive ping and reconnect callbacks")
    func stopInvalidatesAllOutstandingCallbacks() {
        let lifecycle = RuntimeConnectionLifecycle()
        let active = lifecycle.beginConnection()
        #expect(lifecycle.scheduleReconnect(for: active))

        lifecycle.stop()

        #expect(!lifecycle.acceptsCallback(for: active))
        #expect(!lifecycle.hasPendingReconnect)
        #expect(!lifecycle.consumeReconnect(for: active))
    }
}
