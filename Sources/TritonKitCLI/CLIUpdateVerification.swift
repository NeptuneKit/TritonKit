import Foundation

private struct HomebrewUpdateInfo: Decodable {
    struct Formula: Decodable {
        struct Versions: Decodable { let stable: String? }
        let versions: Versions
    }
    let formulae: [Formula]
}

func verifyHomebrewUpdateVersion(formulaJSON: String, expectedVersion: String) throws {
    let info = try? JSONDecoder().decode(HomebrewUpdateInfo.self, from: Data(formulaJSON.utf8))
    let actualVersion = info?.formulae.count == 1 ? info?.formulae.first?.versions.stable : nil
    guard actualVersion == expectedVersion else {
        throw CLIUpdateErrorDetail(
            code: "homebrew_version_mismatch",
            message: "Refreshed Homebrew formula version \(actualVersion ?? "unknown") does not match target \(expectedVersion); upgrade was not run.",
            hint: "The tap may lag the release or have advanced beyond an explicit pin. Retry when it serves the target release, or choose its current version."
        )
    }
}

func verifyInstalledCLIUpdateVersion(
    plan: CLIUpdateResponse,
    hostCommandRunner: (String, [String]) throws -> String
) throws -> String {
    struct InstalledVersion: Decodable { let ok: Bool; let version: String }
    let expected = plan.targetVersion!
    do {
        let binary: String
        if plan.installSource == .homebrew {
            let prefix = try hostCommandRunner("brew", ["--prefix", "neptunekit/tap/triton"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard prefix.hasPrefix("/"), !prefix.contains("\n") else {
                throw CLIUpdateErrorDetail(code: "installed_version_mismatch", message: "Homebrew did not return an absolute installed formula prefix.", hint: nil)
            }
            binary = URL(fileURLWithPath: prefix).appendingPathComponent("bin/triton").path
        } else {
            binary = plan.currentExecutable
        }
        let output = try hostCommandRunner(binary, ["version", "--json"])
        let result = try JSONDecoder().decode(InstalledVersion.self, from: Data(output.utf8))
        let actual = result.version
        guard result.ok, actual == expected else {
            throw CLIUpdateErrorDetail(code: "installed_version_mismatch", message: "Installed CLI reports \(actual), expected \(expected). Skills were not updated.", hint: "Inspect the installed executable and retry after CLI and target release agree.")
        }
        return actual
    } catch let detail as CLIUpdateErrorDetail where detail.code == "installed_version_mismatch" {
        throw detail
    } catch {
        throw CLIUpdateErrorDetail(code: "installed_version_mismatch", message: "Unable to verify installed CLI version: \(error). Skills were not updated.", hint: "Check the installed executable's version --json output.")
    }
}
