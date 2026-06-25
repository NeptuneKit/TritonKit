import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct UpdateCommandTests {
    @Test("update plan check reports available release without mutating local install")
    func updatePlanCheckReportsAvailableReleaseWithoutMutatingLocalInstall() throws {
        let plan = try makeCLIUpdatePlan(
            currentVersion: "0.1.0",
            requestedVersion: "v0.1.1",
            currentExecutable: "/usr/local/bin/triton",
            architecture: "arm64",
            checkOnly: true,
            dryRun: false,
            confirm: false,
            includeSkills: false,
            skillsDirectory: nil,
            repository: "NeptuneKit/TritonKit",
            environment: [:]
        )

        #expect(plan.ok)
        #expect(plan.currentVersion == "0.1.0")
        #expect(plan.targetVersion == "0.1.1")
        #expect(plan.releaseTag == "v0.1.1")
        #expect(plan.updateAvailable == true)
        #expect(plan.checkOnly == true)
        #expect(plan.requiresConfirmation == false)
        #expect(plan.updated == false)
        #expect(plan.installSource == .manual)
        #expect(plan.assetName == "triton-macos-arm64.tar.gz")
        #expect(plan.actions.contains(where: { $0.kind == .downloadCLIAsset }))
        #expect(plan.actions.contains(where: { $0.kind == .verifyChecksum }))
        #expect(plan.actions.contains(where: { $0.kind == .replaceBinary }))
    }

    @Test("homebrew install source plans brew commands and never direct binary replacement")
    func homebrewInstallSourcePlansBrewCommandsAndNeverDirectBinaryReplacement() throws {
        let root = try temporaryUpdateDirectory()
        let cellarBin = root
            .appendingPathComponent("Cellar", isDirectory: true)
            .appendingPathComponent("triton", isDirectory: true)
            .appendingPathComponent("0.1.0", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("triton")
        try FileManager.default.createDirectory(at: cellarBin.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: cellarBin)

        let plan = try makeCLIUpdatePlan(
            currentVersion: "0.1.0",
            requestedVersion: "v0.1.1",
            currentExecutable: cellarBin.path,
            architecture: "arm64",
            checkOnly: false,
            dryRun: false,
            confirm: true,
            includeSkills: false,
            skillsDirectory: nil,
            repository: "NeptuneKit/TritonKit",
            environment: [:]
        )

        #expect(plan.installSource == .homebrew)
        #expect(plan.actions.map(\.kind) == [.homebrewUpdate, .homebrewUpgrade])
        #expect(!plan.actions.contains(where: { $0.kind == .replaceBinary }))
        #expect(plan.requiresConfirmation == false)
    }

    @Test("homebrew update without explicit version does not require GitHub latest")
    func homebrewUpdateWithoutExplicitVersionDoesNotRequireGitHubLatest() async throws {
        let root = try temporaryUpdateDirectory()
        let cellarBin = root
            .appendingPathComponent("Homebrew", isDirectory: true)
            .appendingPathComponent("Cellar", isDirectory: true)
            .appendingPathComponent("triton", isDirectory: true)
            .appendingPathComponent("0.1.0", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("triton")
        try FileManager.default.createDirectory(at: cellarBin.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: cellarBin)

        let plan = try await runCLIUpdate(
            requestedVersion: nil,
            currentExecutable: cellarBin.path,
            architecture: "arm64",
            checkOnly: true,
            dryRun: false,
            confirm: false,
            includeSkills: false,
            skillsDirectory: nil,
            repository: "NeptuneKit/TritonKit",
            latestReleaseTagResolver: { _ in
                throw CLIUpdateErrorDetail(
                    code: "unexpected_latest_resolution",
                    message: "Homebrew update should not require GitHub latest resolution.",
                    hint: nil
                )
            }
        )

        #expect(plan.installSource == .homebrew)
        #expect(plan.releaseTag == nil)
        #expect(plan.latestVersion == nil)
        #expect(plan.targetVersion == nil)
        #expect(plan.updateAvailable == false)
        #expect(plan.requiresConfirmation == false)
        #expect(plan.actions.map(\.kind) == [.homebrewUpdate, .homebrewUpgrade])
    }

    @Test("relative host command launches through env instead of cwd path")
    func relativeHostCommandLaunchesThroughEnvInsteadOfCwdPath() {
        let launch = makeCLIUpdateProcessLaunch(executable: "brew", arguments: ["update"])

        #expect(launch.executable == "/usr/bin/env")
        #expect(launch.arguments == ["brew", "update"])
    }

    @Test("github latest release redirect URL resolves tag")
    func githubLatestReleaseRedirectURLResolvesTag() throws {
        let url = try #require(URL(string: "https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.5"))

        #expect(githubLatestReleaseTag(from: url) == "v0.2.5")
    }

    @Test("manual install source requires explicit confirmation for mutating update")
    func manualInstallSourceRequiresExplicitConfirmationForMutatingUpdate() throws {
        let plan = try makeCLIUpdatePlan(
            currentVersion: "0.1.0",
            requestedVersion: "v0.1.1",
            currentExecutable: "/Users/example/bin/triton",
            architecture: "x86_64",
            checkOnly: false,
            dryRun: false,
            confirm: false,
            includeSkills: false,
            skillsDirectory: nil,
            repository: "NeptuneKit/TritonKit",
            environment: [:]
        )

        #expect(plan.installSource == .manual)
        #expect(plan.assetName == "triton-macos-x86_64.tar.gz")
        #expect(plan.requiresConfirmation == true)
        #expect(plan.updated == false)
        #expect(plan.actions.contains(where: { $0.kind == .replaceBinary }))
    }

    @Test("checksum manifest parser selects expected release asset hash")
    func checksumManifestParserSelectsExpectedReleaseAssetHash() throws {
        let checksums = try parseTritonReleaseChecksums(
            """
            1111111111111111111111111111111111111111111111111111111111111111  triton-macos-arm64.tar.gz
            2222222222222222222222222222222222222222222222222222222222222222  triton-macos-x86_64.tar.gz
            """
        )

        #expect(checksums["triton-macos-arm64.tar.gz"] == "1111111111111111111111111111111111111111111111111111111111111111")
        #expect(checksums["triton-macos-x86_64.tar.gz"] == "2222222222222222222222222222222222222222222222222222222222222222")
    }

    @Test("root command registers update subcommand")
    func rootCommandRegistersUpdateSubcommand() {
        let commandNames = TritonKitCLI.configuration.subcommands.map { $0.configuration.commandName }

        #expect(commandNames.contains("update"))
    }

    @Test("update schema exposes machine readable update contract")
    func updateSchemaExposesMachineReadableUpdateContract() throws {
        let schema = try buildSchemaResponse(command: "update")
        let update = try #require(schema.commands.first)

        #expect(update.name == "update")
        #expect(update.requiresServer == false)
        #expect(update.providedCapabilities.contains("cli-update"))
        #expect(update.outputFormats.contains("json"))
        #expect(update.options.contains(where: { $0.name == "--check" }))
        #expect(update.options.contains(where: { $0.name == "--yes" }))
        #expect(update.options.contains(where: { $0.name == "--include-skills" }))
        #expect(update.failureCodes.contains("checksum_mismatch"))
        #expect(update.failureCodes.contains("confirmation_required"))
        #expect(update.outputContracts.contains(where: { $0.selector == "update.plan" }))
    }
}

private func temporaryUpdateDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-update-command-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
