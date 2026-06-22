import ArgumentParser
import Foundation

enum CLIUpdateInstallSource: String, Codable, Equatable, ExpressibleByArgument {
    case homebrew
    case manual
    case sourceCheckout
    case unknown
}

enum CLIUpdateActionKind: String, Codable, Equatable {
    case resolveRelease
    case homebrewUpdate
    case homebrewUpgrade
    case downloadCLIAsset
    case downloadChecksumManifest
    case verifyChecksum
    case extractCLIAsset
    case replaceBinary
    case downloadSkillsBundle
    case installSkillsBundle
}

struct CLIUpdateAction: Codable, Equatable {
    let id: String
    let kind: CLIUpdateActionKind
    let description: String
    let command: String?
    let args: [String]
    let path: String?
    let destructive: Bool
}

struct CLIUpdateResponse: Codable, Equatable {
    let ok: Bool
    let currentVersion: String
    let latestVersion: String?
    let targetVersion: String?
    let releaseTag: String?
    let updateAvailable: Bool
    let checkOnly: Bool
    let dryRun: Bool
    let requiresConfirmation: Bool
    let updated: Bool
    let skillsUpdated: Bool
    let installSource: CLIUpdateInstallSource
    let currentExecutable: String
    let repository: String
    let assetName: String?
    let checksumManifestName: String?
    let actions: [CLIUpdateAction]
    let manualInstructions: [String]
    let error: CLIUpdateErrorDetail?
}

struct CLIUpdateErrorDetail: Codable, Equatable, Error {
    let code: String
    let message: String
    let hint: String?
}

struct GitHubLatestReleaseResponse: Decodable {
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}
