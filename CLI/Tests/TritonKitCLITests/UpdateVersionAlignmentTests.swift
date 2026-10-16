import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct UpdateVersionAlignmentTests {
    @Test(arguments: [false, true])
    func checksResolveReleaseWithoutHostCommands(dryRun: Bool) async throws {
        let host = UpdateHostSpy()
        var resolutions = 0
        let result = try await runCLIUpdate(
            requestedVersion: nil, currentExecutable: host.oldBinary, architecture: "arm64",
            checkOnly: !dryRun, dryRun: dryRun, confirm: false, includeSkills: false,
            skillsDirectory: nil, repository: "NeptuneKit/TritonKit",
            latestReleaseTagResolver: { _ in resolutions += 1; return "v0.2.29" },
            hostCommandRunner: host.run, currentVersion: "0.2.19"
        )
        #expect(resolutions == 1)
        #expect(result.targetVersion == "0.2.29")
        #expect(result.updateAvailable)
        #expect(host.commands.isEmpty)
    }

    @Test(arguments: ["network", "empty"])
    func failedResolutionDoesNotReportUpToDate(kind: String) async {
        let host = UpdateHostSpy()
        do {
            _ = try await runCLIUpdate(
                requestedVersion: nil, currentExecutable: host.oldBinary, architecture: "arm64",
                checkOnly: true, dryRun: false, confirm: false, includeSkills: false,
                skillsDirectory: nil, repository: "NeptuneKit/TritonKit",
                latestReleaseTagResolver: { _ in
                    if kind == "network" { throw URLError(.notConnectedToInternet) }
                    return ""
                }, hostCommandRunner: host.run, currentVersion: "0.2.19"
            )
            Issue.record("Unknown latest release must fail")
        } catch let error as CLIUpdateErrorDetail {
            #expect(error.code == "release_resolution_failed")
        } catch { Issue.record(error) }
        #expect(host.commands.isEmpty)
    }

    @Test(arguments: ["latest", "garbage", "v0.2.29oops", "v0.2.29\n", " ", "v"])
    func invalidTargetIsRejected(target: String) async {
        let host = UpdateHostSpy()
        do {
            _ = try await runCLIUpdate(
                requestedVersion: target, currentExecutable: host.oldBinary, architecture: "arm64",
                checkOnly: true, dryRun: false, confirm: false, includeSkills: false,
                skillsDirectory: nil, repository: "NeptuneKit/TritonKit",
                hostCommandRunner: host.run, currentVersion: "0.2.19"
            )
            Issue.record("Invalid target must not report success")
        } catch let error as CLIUpdateErrorDetail { #expect(error.code == "release_resolution_failed") }
        catch { Issue.record(error) }
        #expect(host.commands.isEmpty)
    }

    @Test
    func unresolvedPlanIsNotSuccessful() {
        #expect(throws: CLIUpdateErrorDetail.self) {
            try makeCLIUpdatePlan(currentVersion: "0.2.19", requestedVersion: nil,
                currentExecutable: "/opt/homebrew/Cellar/triton/0.2.19/bin/triton", architecture: "arm64",
                checkOnly: true, dryRun: false, confirm: false, includeSkills: false,
                skillsDirectory: nil, repository: "NeptuneKit/TritonKit", environment: [:])
        }
    }

    @Test
    func updateRequiresConfirmationBeforeAnyHostCommand() async {
        let host = UpdateHostSpy()
        await expectUpdateFailure(host: host, confirm: false, expected: "confirmation_required")
        #expect(host.commands.isEmpty)
        #expect(host.skillInstalls == 0)
    }

    @Test(arguments: ["0.2.24", "0.2.30", "invalid-json"])
    func staleOrAdvancedFormulaRejectsUpgrade(formula: String) async {
        let host = UpdateHostSpy(formula: formula)
        await expectUpdateFailure(host: host, expected: "homebrew_version_mismatch")
        #expect(host.commands == [
            ["brew", "update"], ["brew", "info", "--json=v2", "neptunekit/tap/triton"]
        ])
        #expect(host.skillInstalls == 0)
    }

    @Test(arguments: ["0.2.19", "0.2.30", "invalid-json", "launch-failure", "false-envelope", "missing-ok"])
    func successfulBrewMustStillVerifyInstalledBinary(actual: String) async {
        let host = UpdateHostSpy(installed: actual)
        await expectUpdateFailure(host: host, expected: "installed_version_mismatch")
        #expect(host.commands.contains(["brew", "upgrade", "neptunekit/tap/triton"]))
        #expect(host.commands.last == [host.newBinary, "version", "--json"])
        #expect(host.skillInstalls == 0)
    }

    @Test
    func matchingUpgradeVerifiesNewFormulaBinaryBeforeSkills() async throws {
        let host = UpdateHostSpy()
        let result = try await update(host: host)
        #expect(result.updated)
        #expect(result.skillsUpdated)
        #expect(result.installedVersion == "0.2.29")
        #expect(host.commands == [
            ["brew", "update"], ["brew", "info", "--json=v2", "neptunekit/tap/triton"],
            ["brew", "upgrade", "neptunekit/tap/triton"],
            ["brew", "--prefix", "neptunekit/tap/triton"], [host.newBinary, "version", "--json"]
        ])
        #expect(host.skillInstalls == 1)
        #expect(host.commandsAtSkillInstall == host.commands)
    }

    @Test
    func skillsFailurePreservesVerifiedUpgrade() async throws {
        let host = UpdateHostSpy()
        do {
            _ = try await runCLIUpdate(
                requestedVersion: "v0.2.29", currentExecutable: host.oldBinary, architecture: "arm64",
                checkOnly: false, dryRun: false, confirm: true, includeSkills: true,
                skillsDirectory: "/test/skills", repository: "NeptuneKit/TritonKit",
                skillsBundleInstaller: { _, _, _ in
                    throw CLIUpdateErrorDetail(code: "skills_version_mismatch", message: "fixture", hint: nil)
                }, hostCommandRunner: host.run, currentVersion: "0.2.19"
            )
            Issue.record("Expected skills failure")
        } catch let failure as CLIUpdateExecutionFailure {
            let result = failure.response
            #expect(!result.ok)
            #expect(result.updated)
            #expect(result.cliUpdateAttempted)
            #expect(result.installedVersion == "0.2.29")
            #expect(result.installSource == .homebrew)
            #expect(result.targetVersion == "0.2.29")
            #expect(!result.skillsUpdated)
            #expect(result.error?.code == "skills_version_mismatch")
            let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any]
            #expect(object?["updated"] as? Bool == true)
            #expect(object?["installedVersion"] as? String == "0.2.29")
        }
    }

    @Test
    func skillsOnlyVerifiesInstalledCLI() async throws {
        let host = UpdateHostSpy()
        let result = try await update(host: host, currentVersion: "0.2.29")
        #expect(!result.updated)
        #expect(result.skillsUpdated)
        #expect(host.commands == [["brew", "--prefix", "neptunekit/tap/triton"], [host.newBinary, "version", "--json"]])
    }

    @Test
    func skillsOnlyMismatchDoesNotInstallSkills() async {
        let host = UpdateHostSpy(installed: "0.2.24")
        await expectUpdateFailure(host: host, currentVersion: "0.2.29", expected: "installed_version_mismatch")
        #expect(host.skillInstalls == 0)
    }

    @Test
    func olderTargetCannotDowngradeSkills() async {
        let host = UpdateHostSpy()
        await expectUpdateFailure(host: host, currentVersion: "0.2.30", expected: "downgrade_unsupported")
        #expect(host.commands.isEmpty)
        #expect(host.skillInstalls == 0)
    }

    @Test
    func latestUpgradeStillRequiresConfirmation() async {
        let host = UpdateHostSpy()
        do {
            _ = try await runCLIUpdate(
                requestedVersion: nil, currentExecutable: host.oldBinary, architecture: "arm64",
                checkOnly: false, dryRun: false, confirm: false, includeSkills: false,
                skillsDirectory: nil, repository: "NeptuneKit/TritonKit",
                latestReleaseTagResolver: { _ in "v0.2.29" },
                hostCommandRunner: host.run, currentVersion: "0.2.19"
            )
            Issue.record("Unpinned upgrade must require confirmation")
        } catch let error as CLIUpdateErrorDetail { #expect(error.code == "confirmation_required") }
        catch { Issue.record(error) }
        #expect(host.commands.isEmpty)
    }

    private func update(host: UpdateHostSpy, confirm: Bool = true, currentVersion: String = "0.2.19", requestedVersion: String? = "v0.2.29") async throws -> CLIUpdateResponse {
        try await runCLIUpdate(
            requestedVersion: requestedVersion, currentExecutable: host.oldBinary, architecture: "arm64",
            checkOnly: false, dryRun: false, confirm: confirm, includeSkills: true,
            skillsDirectory: "/test/skills", repository: "NeptuneKit/TritonKit",
            latestReleaseTagResolver: { _ in "v0.2.29" },
            skillsBundleInstaller: { _, _, _ in
                host.skillInstalls += 1
                host.commandsAtSkillInstall = host.commands
            }, hostCommandRunner: host.run, currentVersion: currentVersion
        )
    }

    private func expectUpdateFailure(host: UpdateHostSpy, confirm: Bool = true, currentVersion: String = "0.2.19", expected: String) async {
        do {
            _ = try await update(host: host, confirm: confirm, currentVersion: currentVersion)
            Issue.record("Expected \(expected)")
        } catch let error as CLIUpdateErrorDetail { #expect(error.code == expected) }
        catch let failure as CLIUpdateExecutionFailure {
            #expect(failure.response.error?.code == expected)
            #expect(!failure.response.updated)
            #expect(!failure.response.skillsUpdated)
            #expect(failure.response.cliUpdateAttempted == host.commands.contains(["brew", "upgrade", "neptunekit/tap/triton"]))
            #expect(failure.response.installedVersion == nil)
        } catch { Issue.record(error) }
    }
}

private final class UpdateHostSpy {
    let oldBinary = "/opt/homebrew/Cellar/triton/0.2.19/bin/triton"
    let prefix = "/opt/homebrew/Cellar/triton/0.2.29"
    var newBinary: String { prefix + "/bin/triton" }
    var commands: [[String]] = []
    var commandsAtSkillInstall: [[String]] = []
    var skillInstalls = 0
    let formula: String
    let installed: String
    init(formula: String = "0.2.29", installed: String = "0.2.29") {
        self.formula = formula
        self.installed = installed
    }
    func run(_ executable: String, _ arguments: [String]) throws -> String {
        commands.append([executable] + arguments)
        if executable == "brew" {
            switch arguments {
            case ["update"], ["upgrade", "neptunekit/tap/triton"]: return ""
            case ["info", "--json=v2", "neptunekit/tap/triton"]:
                return formula == "invalid-json" ? "{" : "{\"formulae\":[{\"versions\":{\"stable\":\"\(formula)\"}}]}"
            case ["--prefix", "neptunekit/tap/triton"]: return prefix + "\n"
            default: break
            }
        }
        if executable == newBinary && arguments == ["version", "--json"] {
            if installed == "launch-failure" { throw URLError(.cannotOpenFile) }
            if installed == "false-envelope" { return "{\"ok\":false,\"version\":\"0.2.29\"}" }
            if installed == "missing-ok" { return "{\"version\":\"0.2.29\"}" }
            return installed == "invalid-json" ? "{" : "{\"ok\":true,\"version\":\"\(installed)\"}"
        }
        Issue.record("Unexpected host command: \(commands.last!)")
        throw URLError(.unsupportedURL)
    }
}
