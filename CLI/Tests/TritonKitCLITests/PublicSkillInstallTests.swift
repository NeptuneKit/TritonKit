import Foundation
import Testing
@testable import TritonKitCLI

@Suite struct PublicSkillInstallTests {
    private func fixture(_ root: URL, text: String) throws -> URL {
        let bundle = root.appendingPathComponent(UUID().uuidString)
        for name in publicSkillBundleNames {
            let dir = bundle.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: dir.appendingPathComponent("SKILL.md"))
        }
        return bundle
    }
    @Test func modifiedInstallationIsPreserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try fixture(root, text: "first")
        let destination = root.appendingPathComponent("agent")
        try installValidatedPublicSkillDirectory(source: first, destinationRoot: destination)
        let edited = destination.appendingPathComponent("TritonKit.skills/\(publicSkillBundleNames[0])/SKILL.md")
        try Data("local edit".utf8).write(to: edited)
        let next = try fixture(root, text: "next")
        #expect(throws: CLIUpdateErrorDetail.self) {
            try installValidatedPublicSkillDirectory(source: next, destinationRoot: destination)
        }
        #expect(try String(contentsOf: edited, encoding: .utf8) == "local edit")
    }
    @Test func cleanUpdateIsAtomicAndPreservesBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("agent")
        try installValidatedPublicSkillDirectory(source: fixture(root,text:"first"), destinationRoot: destination)
        try installValidatedPublicSkillDirectory(source: fixture(root,text:"next"), destinationRoot: destination)
        let backups = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix(".triton-skills-backup-") }
        #expect(backups.count == 1)
        let file = destination.appendingPathComponent("TritonKit.skills/\(publicSkillBundleNames[0])/SKILL.md")
        #expect(try String(contentsOf: file,encoding:.utf8) == "next")
        #expect(try String(contentsOf: backups[0].appendingPathComponent("\(publicSkillBundleNames[0])/SKILL.md"),encoding:.utf8) == "first")
        #expect((try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }
    @Test func invalidBundleAndSymlinkNeverDestroyCurrent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("agent")
        let valid = try fixture(root,text:"valid")
        try installValidatedPublicSkillDirectory(source: valid, destinationRoot: destination)
        try FileManager.default.removeItem(at: valid.appendingPathComponent(publicSkillBundleNames[0]))
        #expect(throws: CLIUpdateErrorDetail.self) { try installValidatedPublicSkillDirectory(source:valid,destinationRoot:destination) }
        let linked = root.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(at:linked,withDestinationURL:destination)
        #expect(throws: CLIUpdateErrorDetail.self) { try installValidatedPublicSkillDirectory(source:valid,destinationRoot:linked) }
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("TritonKit.skills/\(publicSkillBundleNames[0])/SKILL.md").path))
    }
    @Test func validArchiveExtractsRequiredBundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(root, text: "archive")
        let bundle = root.appendingPathComponent("TritonKit.skills")
        try FileManager.default.moveItem(at: source, to: bundle)
        let archive = root.appendingPathComponent("skills.tar.gz")
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", archive.path, "-C", root.path, "TritonKit.skills"]
        try process.run(); process.waitUntilExit(); #expect(process.terminationStatus == 0)
        let extracted = root.appendingPathComponent("extract")
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        let validated = try extractValidatedPublicSkillArchive(archive: archive, into: extracted)
        #expect(FileManager.default.fileExists(atPath: validated.appendingPathComponent("\(publicSkillBundleNames[0])/SKILL.md").path))
    }
    @Test func archiveManifestRejectsEscapesLinksAndDuplicateMembers() throws {
        #expect(throws: CLIUpdateErrorDetail.self) { try validatePublicSkillArchiveListing(names:"../outside\n",types:"-rw-r--r-- x\n") }
        #expect(throws: CLIUpdateErrorDetail.self) { try validatePublicSkillArchiveListing(names:"TritonKit.skills/link\n",types:"lrwxr-xr-x x\n") }
        #expect(throws: CLIUpdateErrorDetail.self) { try validatePublicSkillArchiveListing(names:"TritonKit.skills/a\nTritonKit.skills/a\n",types:"- x\n- x\n") }
    }
}
