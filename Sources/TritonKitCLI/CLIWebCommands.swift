import ArgumentParser
import Foundation
import TritonKitShared

struct Web: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "web",
        abstract: "Start the readonly Web Device Hub from a checkout or bundled release assets"
    )

    @Option(help: "TritonKit repository root or Web directory. Defaults to searching upward from the current directory.")
    var root: String?

    @Option(help: "Triton CLI binary injected into the Web host bridge. Defaults to TRITONKIT_TRITON_BIN or the current executable.")
    var tritonBin: String?

    @Option(help: "Web host bind address")
    var host: String = "127.0.0.1"

    @Option(help: "Web Device Hub port")
    var port: Int = 34127

    @Option(name: .customLong("bundled-web-root"), help: .hidden)
    var bundledWebRoot: String?

    @Flag(help: "Run npm install before starting Vite.")
    var install = false

    @Flag(help: "Skip npm install even when Web/node_modules is missing.")
    var noInstall = false

    @Flag(help: "Print the resolved launch plan without starting Vite.")
    var printCommand = false

    @Option(help: "Output format: text or json")
    var format: ClientOutputFormat = .text

    @Flag(name: .customLong("json"), help: "Alias for --format json")
    var json = false

    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard !(install && noInstall) else {
                throw WebCommandError.conflictingInstallOptions
            }
            let installMode: WebDependencyInstallMode = if install {
                .always
            } else if noInstall {
                .never
            } else {
                .auto
            }
            let plan = try makeWebLaunchPlan(
                explicitRoot: root,
                currentDirectory: FileManager.default.currentDirectoryPath,
                explicitTritonBin: tritonBin,
                currentExecutable: currentExecutablePath(),
                host: host,
                port: port,
                installMode: installMode,
                environment: ProcessInfo.processInfo.environment,
                explicitBundledWebRoot: bundledWebRoot
            )

            if printCommand {
                switch outputFormat {
                case .json:
                    print(try encodeJSON(plan))
                case .text:
                    print(renderWebLaunchPlanText(plan))
                }
                return
            }

            try await runWebLaunchPlan(plan)
        } catch let error as WebCommandError {
            switch outputFormat {
            case .json:
                let detail = TKCLIErrorDetail(code: error.code, message: error.description, hint: error.hint)
                print(try encodeJSON(TKCLIErrorResponse(error: detail)))
            case .text:
                print(error.description)
                print("hint: \(error.hint)")
            }
            throw ExitCode.failure
        }
    }
}
