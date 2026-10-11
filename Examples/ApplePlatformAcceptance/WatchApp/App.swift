import SwiftUI

@main
struct WatchAcceptanceApp: App {
    var body: some Scene { WindowGroup { CrownScreen() } }
}

struct CrownScreen: View {
    @State private var value = 0.0
    var body: some View {
        VStack {
            Text("Crown acceptance")
            Text(String(format: "%.3f", value))
                .accessibilityIdentifier("crown-value")
        }
        .focusable()
        .digitalCrownRotation($value, from: -10000, through: 10000, by: 0.1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: false)
    }
}
