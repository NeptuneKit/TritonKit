import ArgumentParser
import TritonKitShared

enum TKHarmonyRuntimeDefaults {
    static let hostAccessPort = 28767
    static let gatewayPort = 18765
    static let hostAccessBaseURL = "http://127.0.0.1:\(hostAccessPort)"
}

// MARK: - Entry Point

@main
struct TritonKitEntry {
    static func main() async {
        if shouldPrintChineseHelp() {
            printChineseHelp()
            return
        }
        await TritonKitCLI.main()
    }
}

struct TritonKitCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "triton",
        abstract: "TritonKit macOS CLI - WebSocket control + HTTP data server for iOS view debugging",
        version: TritonKitBuildInfo.cliVersion,
        subcommands: [
            Serve.self,
            Web.self,
            Version.self,
            Status.self,
            Doctor.self,
            Capabilities.self,
            Schema.self,
            Target.self,
            Build.self,
            Xcode.self,
            Xcresult.self,
            Xctrace.self,
            Coverage.self,
            Runtime.self,
            State.self,
            Snapshot.self,
            Plan.self,
            List.self,
            Inspect.self,
            Observe.self,
            WebView.self,
            Route.self,
            Hierarchy.self,
            Nodes.self,
            Node.self,
            Attrs.self,
            ObjectInfo.self,
            Export.self,
            Evidence.self,
            Capture.self,
            Smoke.self,
            UIAssert.self,
            Record.self,
            Replay.self,
            Find.self,
            Wait.self,
            Focus.self,
            SetText.self,
            SelectSegment.self,
            SetSwitch.self,
            Tap.self,
            Swipe.self,
            TypeText.self,
            PasteText.self,
            ClearText.self,
            Press.self,
            Geometry.self,
            AccessibilityTree.self,
            Hit.self,
            Screenshot.self,
            Input.self,
            Ledger.self,
            Device.self,
            Sim.self,
            HostApp.self,
        ],
        defaultSubcommand: List.self
    )
}
