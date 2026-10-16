import Foundation
import Yams

private struct PublicSkillReleaseIdentity: Decodable {
    struct Skill: Decodable {
        let name: String
        let path: String
        let version: String
    }
    let name: String
    let bundlePath: String
    let version: String
    let releaseTag: String
    let skills: [Skill]
}

/// Release downloads must identify the requested release in both the manifest and
/// every skill front matter. Validate before the installer changes any files.
@discardableResult
func validatePublicSkillRelease(source: URL, expectedTag: String) throws -> String {
    let target = normalizedReleaseTarget(expectedTag)
    func mismatch(_ reason: String) -> CLIUpdateErrorDetail {
        CLIUpdateErrorDetail(
            code: "skills_version_mismatch",
            message: "Public skills do not match \(expectedTag): \(reason)",
            hint: "Verify BUILD_INFO.json and every SKILL.md against the selected release; do not force replacement."
        )
    }
    func read(_ file: URL) throws -> Data {
        let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= 1024 * 1024 else {
            throw mismatch("metadata must be a regular file no larger than 1 MiB")
        }
        return try Data(contentsOf: file)
    }
    do {
        guard let version = target.version, !version.isEmpty, let tag = target.tag else {
            throw mismatch("missing target version")
        }
        let info = try JSONDecoder().decode(PublicSkillReleaseIdentity.self, from: read(source.appendingPathComponent("BUILD_INFO.json")))
        guard info.name == "tritonkit-skills", info.bundlePath == "TritonKit.skills/",
              info.version == version, info.releaseTag == tag else {
            throw mismatch("BUILD_INFO release identity differs from the requested release")
        }
        guard info.skills.count == publicSkillBundleNames.count,
              Set(info.skills.map(\.name)) == Set(publicSkillBundleNames) else {
            throw mismatch("BUILD_INFO must list each required skill exactly once")
        }
        for skill in info.skills {
            guard skill.version == version, skill.path == "TritonKit.skills/\(skill.name)/" else {
                throw mismatch("BUILD_INFO skill entry differs from the requested release")
            }
            let data = try read(source.appendingPathComponent(skill.name).appendingPathComponent("SKILL.md"))
            guard let text = String(data: data, encoding: .utf8) else { throw mismatch("SKILL.md is not UTF-8") }
            let lines = text.components(separatedBy: .newlines)
            guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else {
                throw mismatch("SKILL.md has no YAML front matter")
            }
            let yaml = lines[1..<end].joined(separator: "\n")
            let object = try Yams.load(yaml: yaml) as? [String: Any]
            let metadata = object?["metadata"] as? [String: Any]
            guard object?["name"] as? String == skill.name, metadata?["version"] as? String == version else {
                throw mismatch("\(skill.name) front matter differs from the requested release")
            }
        }
        return version
    } catch let error as CLIUpdateErrorDetail {
        throw error
    } catch {
        throw mismatch("missing, unreadable or malformed release metadata")
    }
}
