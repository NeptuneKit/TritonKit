import ArgumentParser
import Foundation

struct Update: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Check or update the TritonKit CLI from GitHub Release/Homebrew"
    )

    @Flag(help: "Only check and print the update plan; never mutate local files")
    var check = false

    @Flag(help: "Print the update plan without executing mutating actions")
    var dryRun = false

    @Flag(help: "Confirm mutating update actions")
    var yes = false

    @Option(help: "Target release tag or version, for example v0.1.24")
    var version: String?

    @Flag(help: "Also update the public TritonKit.skills bundle from the same release")
    var includeSkills = false

    @Option(help: "Agent skills root directory used with --include-skills")
    var skillsDir: String?

    @Option(help: "GitHub repository, owner/name")
    var repository: String = "NeptuneKit/TritonKit"

    @Option(help: "Output format: text or json")
    var format: ClientOutputFormat = .text

    @Flag(name: .customLong("json"), help: "Alias for --format json")
    var json = false

    @Option(help: .hidden)
    var currentExecutable: String?

    @Option(help: .hidden)
    var architecture: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let response = try await runCLIUpdate(
                requestedVersion: version,
                currentExecutable: currentExecutable ?? currentTritonExecutablePath(),
                architecture: architecture ?? machineArchitecture(),
                checkOnly: check,
                dryRun: dryRun,
                confirm: yes,
                includeSkills: includeSkills,
                skillsDirectory: skillsDir,
                repository: repository
            )
            try printCLIUpdateResponse(response, format: outputFormat)
        } catch let detail as CLIUpdateErrorDetail {
            try printCLIUpdateError(detail, format: outputFormat)
            throw ExitCode.failure
        } catch {
            try printCLIUpdateError(
                CLIUpdateErrorDetail(
                    code: "update_failed",
                    message: String(describing: error),
                    hint: "Run triton update --dry-run --json to inspect the planned update."
                ),
                format: outputFormat
            )
            throw ExitCode.failure
        }
    }
}

private func machineArchitecture() -> String {
    #if arch(x86_64)
    return "x86_64"
    #else
    return "arm64"
    #endif
}

private func printCLIUpdateResponse(_ response: CLIUpdateResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("currentVersion: \(response.currentVersion)")
        if let targetVersion = response.targetVersion {
            print("targetVersion: \(targetVersion)")
        }
        print("installSource: \(response.installSource.rawValue)")
        print("updateAvailable: \(response.updateAvailable)")
        print("updated: \(response.updated)")
        if response.requiresConfirmation {
            print("requiresConfirmation: true")
            print("rerun with --yes to update")
        }
        if !response.actions.isEmpty {
            print("actions:")
            for action in response.actions {
                print("- \(action.id): \(action.description)")
            }
        }
        for instruction in response.manualInstructions {
            print("note: \(instruction)")
        }
    }
}

private func printCLIUpdateError(_ detail: CLIUpdateErrorDetail, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        let response = CLIUpdateResponse(
            ok: false,
            currentVersion: TritonKitBuildInfo.cliVersion,
            latestVersion: nil,
            targetVersion: nil,
            releaseTag: nil,
            updateAvailable: false,
            checkOnly: false,
            dryRun: false,
            requiresConfirmation: false,
            updated: false,
            skillsUpdated: false,
            installSource: .unknown,
            currentExecutable: currentTritonExecutablePath(),
            repository: "NeptuneKit/TritonKit",
            assetName: nil,
            checksumManifestName: nil,
            actions: [],
            manualInstructions: [],
            error: detail
        )
        print(try encodeJSON(response))
    case .text:
        FileHandle.standardError.write(Data("Error: \(detail.message)\n".utf8))
        if let hint = detail.hint {
            FileHandle.standardError.write(Data("Hint: \(hint)\n".utf8))
        }
    }
}
