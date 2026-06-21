import ArgumentParser
import Foundation
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
        if let retiredRoot = retiredRootInvocation() {
            writeStandardError(
                """
                Error: Unknown subcommand '\(retiredRoot)'
                Usage: triton <subcommand>
                  See 'triton --help' for available product commands.

                """
            )
            Foundation.exit(64)
        }
        if shouldPrintChineseHelp() {
            printChineseHelp()
            return
        }
        await TritonKitCLI.main()
    }

    private static let retiredRootCommandNames: Set<String> = [
        "find", "tap", "type", "paste", "clear", "swipe", "press", "focus", "set-text", "select-segment", "set-switch", "input",
        "assert", "capture",
        "runtime", "state", "snapshot", "hierarchy", "nodes", "node", "attrs", "object", "geometry", "ax", "hit", "ledger",
    ]

    private static func retiredRootInvocation() -> String? {
        let args = Array(CommandLine.arguments.dropFirst())
        if let helpIndex = args.firstIndex(of: "help") {
            let targetIndex = args.index(after: helpIndex)
            if targetIndex < args.endIndex, retiredRootCommandNames.contains(args[targetIndex]) {
                return args[targetIndex]
            }
        }
        guard let first = args.first, !first.hasPrefix("-") else {
            return nil
        }
        if retiredRootCommandNames.contains(first) {
            return first
        }
        if first == "help",
           let helpTarget = args.dropFirst().first,
           retiredRootCommandNames.contains(helpTarget) {
            return helpTarget
        }
        return nil
    }

    private static func writeStandardError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
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
            TestCommand.self,
            ActionProvider.self,
            Target.self,
            Build.self,
            Xcode.self,
            Xcresult.self,
            Xctrace.self,
            Coverage.self,
            Plan.self,
            List.self,
            Inspect.self,
            Observe.self,
            Debug.self,
            WebView.self,
            Route.self,
            Export.self,
            Evidence.self,
            AppMap.self,
            VLM.self,
            Act.self,
            Smoke.self,
            Verify.self,
            Record.self,
            Replay.self,
            Wait.self,
            Screenshot.self,
            Device.self,
            Sim.self,
            HostApp.self,
        ]
    )
}
