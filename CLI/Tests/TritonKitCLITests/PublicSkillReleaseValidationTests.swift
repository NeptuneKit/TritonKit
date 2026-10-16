import Foundation
import Testing
@testable import TritonKitCLI

@Suite struct PublicSkillReleaseValidationTests {
    private func bundle() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let skills = publicSkillBundleNames.map { ["name": $0, "path": "TritonKit.skills/\($0)/", "version": "0.2.30"] }
        let info: [String: Any] = ["name": "tritonkit-skills", "bundlePath": "TritonKit.skills/", "version": "0.2.30", "releaseTag": "v0.2.30", "skills": skills]
        try JSONSerialization.data(withJSONObject: info).write(to: root.appendingPathComponent("BUILD_INFO.json"))
        for name in publicSkillBundleNames {
            let dir = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("---\nname: \(name)\nmetadata:\n  version: 0.2.30\n---\n# Skill\n".utf8).write(to: dir.appendingPathComponent("SKILL.md"))
        }
        return root
    }

    @Test func matchingBundleIsAccepted() throws {
        let root = try bundle(); defer { try? FileManager.default.removeItem(at: root) }
        #expect(try validatePublicSkillRelease(source: root, expectedTag: "v0.2.30") == "0.2.30")
    }

    @Test(arguments: ["missing", "version", "tag", "skill-entry", "skill-file", "duplicate", "invalid-json"])
    func inconsistentBundleIsRejected(kind: String) throws {
        let root = try bundle(); defer { try? FileManager.default.removeItem(at: root) }
        let infoURL = root.appendingPathComponent("BUILD_INFO.json")
        var info = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: infoURL)) as? [String: Any])
        switch kind {
        case "missing": try FileManager.default.removeItem(at: infoURL)
        case "version": info["version"] = "0.2.19"
        case "tag": info["releaseTag"] = "v0.2.19"
        case "skill-entry":
            var entries = try #require(info["skills"] as? [[String: String]])
            entries[0]["version"] = "0.2.19"; info["skills"] = entries
        case "duplicate":
            var entries = try #require(info["skills"] as? [[String: String]])
            entries[1] = entries[0]; info["skills"] = entries
        case "skill-file":
            try Data("---\nname: old\nmetadata:\n  version: 0.2.19\n---\n".utf8).write(to: root.appendingPathComponent("\(publicSkillBundleNames[0])/SKILL.md"))
        default: try Data("not json".utf8).write(to: infoURL)
        }
        if ["version", "tag", "skill-entry", "duplicate"].contains(kind) {
            try JSONSerialization.data(withJSONObject: info).write(to: infoURL)
        }
        do {
            _ = try validatePublicSkillRelease(source: root, expectedTag: "v0.2.30")
            Issue.record("Expected release identity mismatch to fail before installation")
        } catch let error as CLIUpdateErrorDetail {
            #expect(error.code == "skills_version_mismatch")
        }
    }
}
