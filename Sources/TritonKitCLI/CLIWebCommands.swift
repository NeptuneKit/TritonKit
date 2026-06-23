import ArgumentParser
import Foundation
import TritonKitShared

struct Web: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "web",
        abstract: "Start the readonly Web Device Hub from a checkout or bundled release assets",
        subcommands: [WebStatus.self, WebDoctor.self]
    )

    @Option(help: "TritonKit repository root or Web directory. Defaults to searching upward from the current directory.")
    var root: String?

    @Option(help: "Triton CLI binary injected into the Web host bridge. Defaults to TRITONKIT_TRITON_BIN or the current executable.")
    var tritonBin: String?

    @Option(help: "Web host bind address")
    var host: String = "127.0.0.1"

    @Option(help: "Web Device Hub port")
    var port: Int = 34127

    @Flag(help: "Only discover iOS Simulator targets; disables real-device USB and LAN discovery.")
    var simulatorOnly = false

    @Flag(name: .customLong("no-usb"), help: "Disable USB real-device runtime tunnel discovery.")
    var noUSB = false

    @Flag(name: .customLong("no-lan"), help: "Disable LAN / Bonjour runtime discovery.")
    var noLAN = false

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
                explicitBundledWebRoot: bundledWebRoot,
                discoveryOptions: WebAutoDiscoveryOptions(simulatorOnly: simulatorOnly, usb: !noUSB, lan: !noLAN)
            )

            if printCommand || outputFormat == .json {
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

struct WebStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Inspect the readonly Web Device Hub launch port without starting it"
    )

    @Option(help: "Web host address to inspect")
    var host: String = "127.0.0.1"

    @Option(help: "Web Device Hub port to inspect")
    var port: Int = 34127

    @Option(help: "Output format: text or json")
    var format: ClientOutputFormat = .text

    @Flag(name: .customLong("json"), help: "Alias for --format json")
    var json = false

    func run() async throws {
        let response = await makeWebStatusResponse(host: host, port: port)
        switch webDiagnosticOutputFormat(format, json: json) {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print(renderWebStatusText(response))
        }
    }
}

struct WebDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose the readonly Web Device Hub launch environment without starting it"
    )

    @Option(help: "Web host address to inspect")
    var host: String = "127.0.0.1"

    @Option(help: "Web Device Hub port to inspect")
    var port: Int = 34127

    @Option(help: "Output format: text or json")
    var format: ClientOutputFormat = .text

    @Flag(name: .customLong("json"), help: "Alias for --format json")
    var json = false

    func run() async throws {
        let status = await makeWebStatusResponse(host: host, port: port)
        let response = makeWebDoctorResponse(status: status)
        switch webDiagnosticOutputFormat(format, json: json) {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print(renderWebDoctorText(response))
        }
    }
}
