import SwiftUI

@main
struct RunnerFixtureApp: App {
    var body: some Scene {
        WindowGroup { CounterView() }
    }
}

private struct CounterView: View {
    @State private var counter = 0
    var body: some View {
        VStack(spacing: 24) {
            Text("TritonKit Runner Fixture").font(.headline)
            Text(String(counter))
                .font(.largeTitle)
                .accessibilityIdentifier("counterValue")
            Button("Increment") { counter += 1 }
                .accessibilityIdentifier("incrementButton")
        }.padding()
    }
}
