import Foundation
import Testing

@Suite("TKHierarchyBuilder source contracts")
struct TKHierarchyBuilderSourceContractsTests {
    @Test("display item building does not touch host view controller from view")
    func buildItemDoesNotRecomputeHostViewController() throws {
        let source = try Self.sourceFile("Sources/TritonKit/Server/TKHierarchyBuilder.swift")
        let buildItem = try #require(source.slice(from: "private static func buildItem(", to: "\n}\n#else"))

        #expect(!buildItem.contains("tk_hostViewController"))
        #expect(source.contains("let hostViewController: UIViewController?"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
            let parent = directory.deletingLastPathComponent()
            try #require(parent.path != directory.path)
            directory = parent
        }
        return try String(contentsOf: directory.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private extension String {
    func slice(from start: String, to end: String) -> String? {
        guard let startRange = range(of: start), let endRange = range(of: end, range: startRange.upperBound..<endIndex) else {
            return nil
        }
        return String(self[startRange.lowerBound..<endRange.lowerBound])
    }
}
