import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct HarmonyActionAlignmentTests {
    @Test("Harmony swipe duration maps to bounded uitest velocity")
    func harmonySwipeVelocityMapping() {
        #expect(harmonySwipeVelocity(startX: 0, startY: 0, endX: 300, endY: 400, duration: nil) == nil)
        #expect(harmonySwipeVelocity(startX: 0, startY: 0, endX: 300, endY: 400, duration: 1) == 500)
        #expect(harmonySwipeVelocity(startX: 0, startY: 0, endX: 1, endY: 1, duration: 10) == 200)
        #expect(harmonySwipeVelocity(startX: 0, startY: 0, endX: 1000, endY: 0, duration: 0.001) == 40_000)
    }

    @Test("Harmony press maps common iOS-style button names to uitest key names")
    func harmonyPressKeyMapping() {
        #expect(harmonyKeyEventName(for: "home") == "Home")
        #expect(harmonyKeyEventName(for: "back") == "Back")
        #expect(harmonyKeyEventName(for: "lock") == "Power")
        #expect(harmonyKeyEventName(for: "Power") == "Power")
        #expect(harmonyKeyEventName(for: "2072") == "2072")
    }

    @Test("Harmony secure text source command redacts inserted text")
    func harmonySecureTextSourceCommandRedactsInsertedText() {
        let command = TKHarmonyHDCCommand.inputText(target: "127.0.0.1:10100", text: "secret value")

        let redacted = harmonyTextSourceCommand(command, text: "secret value", secure: true)
        let clear = harmonyTextSourceCommand(command, text: "secret value", secure: false)

        #expect(redacted.contains("secret value") == false)
        #expect(redacted.contains("<redacted:length=12>"))
        #expect(clear.contains("secret value"))
    }
}
