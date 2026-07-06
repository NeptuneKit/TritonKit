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
        // Auto-complete system PATH environment variable to locate adb and hdc under dev environment
        let env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let home = env["HOME"] ?? ""

        var extraPaths = ["/usr/local/bin", "/opt/homebrew/bin"]
        if !home.isEmpty {
            extraPaths.append("\(home)/Library/Android/sdk/platform-tools")
            extraPaths.append("\(home)/harmonyOS-command-line-tools/bin")
            extraPaths.append("\(home)/Library/Huawei/Sdk/openharmony/12/toolchains")
        }

        let newPath = ([currentPath] + extraPaths).joined(separator: ":")
        setenv("PATH", newPath, 1)

        if let retiredRoot = retiredRootInvocation() {
            writeStandardError(
                """
                Error: Unknown subcommand '\(retiredRoot)'
                Usage: triton <subcommand>
                  See 'triton --help' for available product commands.
                \(retiredRootHint(retiredRoot))

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
        "runtime", "state", "snapshot", "hierarchy", "nodes", "attrs", "object", "geometry", "ax", "hit", "ledger",
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

    private static func retiredRootHint(_ root: String) -> String {
        guard root == "state" else { return "" }
        return "Hint: use `triton debug state route --json` for raw route diagnostics, or `triton observe current --json` for the workflow observation entry."
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
            Workspace.self,
            TestCommand.self,
            TestRecorderCommand.self,
            Update.self,
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
            NodeWorkflow.self,
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
            Camera.self,
            HostApp.self,
        ]
    )
}
