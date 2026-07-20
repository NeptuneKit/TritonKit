import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct PublicSkillCommandSchemaTests {
    @Test("public skill command snapshot matches the current CLI schema")
    func snapshotMatchesCurrentSchema() throws {
        let snapshotURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs-linhay/scripts/public-skill-command-schema.json")
        let snapshot = try JSONDecoder().decode(
            PublicSkillCommandSchemaSnapshot.self,
            from: Data(contentsOf: snapshotURL)
        )
        let current = Dictionary(uniqueKeysWithValues: commandSchemas().map { command in
            (command.name, command.subcommands.map(\.name).sorted())
        })

        #expect(snapshot.schemaVersion == 1)
        #expect(snapshot.commands.mapValues { $0.sorted() } == current)
    }
}

private struct PublicSkillCommandSchemaSnapshot: Decodable {
    let schemaVersion: Int
    let commands: [String: [String]]
}
