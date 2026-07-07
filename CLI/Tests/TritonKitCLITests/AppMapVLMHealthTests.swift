import Foundation
import Testing
@testable import TritonKitCLI

@Suite("P21 app map VLM health")
struct AppMapVLMHealthTests {
    @Test("merge reads VLM grounding events into provider health")
    func mergeReadsVLMGroundingEventsIntoProviderHealth() throws {
        let fixture = try ScreenWorkspaceProjectionFixture()
        try fixture.writeVLMPassEvidence()
        let mapURL = fixture.root.appendingPathComponent(".tritonmap", isDirectory: true)

        _ = try mergeTritonAppMap(
            evidencePath: fixture.evidence.path,
            into: mapURL.path,
            confirm: true
        )

        let health = try inspectTritonAppMapVLMHealth(mapPath: mapURL.path, provider: "mock")
        #expect(health.kind == "triton.app-map.vlm-health-result")
        #expect(health.providerCount == 1)
        let provider = try #require(health.providers.first)
        #expect(provider.id == "mock")
        #expect(provider.groundingRuns == 1)
        #expect(provider.successRate == 1)
        #expect(provider.targets == ["Go Home button"])

        let paths = try listTritonAppMapPaths(mapPath: mapURL.path)
        let path = try #require(paths.paths.first)
        #expect(path.source == "vlm-assisted")
        #expect(path.vlmHealth?.providers["mock"]?.successCount == 1)
        let maybePathJSON = try jsonPath(in: paths)
        let pathJSON = try #require(maybePathJSON)
        #expect(pathJSON["requiresVLM"] as? Bool == true)
        let pathSuggestedCommands = try #require(pathJSON["suggestedCommands"] as? [String])
        let expectedFlow = mapURL.appendingPathComponent("flows/path-fixture-login-home.tritontest.yaml").path
        let expectedEvidence = mapURL.appendingPathComponent("evidence/path-fixture-login-home.tritonevidence").path
        #expect(pathSuggestedCommands.contains("triton map export-flow '\(mapURL.path)' --path path-fixture-login-home --out '\(expectedFlow)' --json"))
        #expect(pathSuggestedCommands.contains("triton test run '\(expectedFlow)' --json --evidence-dir '\(expectedEvidence)' --allow-vlm"))

        let show = try showTritonAppMapPath(mapPath: mapURL.path, pathID: path.pathID)
        let maybeShowPathJSON = try jsonPath(in: show)
        let showPathJSON = try #require(maybeShowPathJSON)
        #expect(showPathJSON["requiresVLM"] as? Bool == true)
        #expect((showPathJSON["suggestedCommands"] as? [String]) == pathSuggestedCommands)

        let output = fixture.root.appendingPathComponent("vlm-path.tritontest.yaml")
        let export = try exportTritonAppMapFlow(mapPath: mapURL.path, pathID: path.pathID, output: output.path)
        let exportJSON = try jsonObject(export)
        #expect(exportJSON["requiresVLM"] as? Bool == true)
        #expect((exportJSON["suggestedCommands"] as? [String]) == [
            "triton test validate '\(output.path)' --json",
            "triton test run '\(output.path)' --json --evidence-dir '\(output.deletingPathExtension().path).tritonevidence' --allow-vlm",
        ])

        let htmlURL = fixture.root.appendingPathComponent("viewer.html")
        _ = try exportTritonAppMapViewer(mapPath: mapURL.path, output: htmlURL.path)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(html.contains("VLM Provider Health"))
        #expect(html.contains("mock"))
    }

    private func jsonPath<T: Encodable>(in value: T) throws -> [String: Any]? {
        let object = try jsonObject(value)
        guard let paths = object["paths"] as? [[String: Any]], let path = paths.first else {
            return (object["path"] as? [String: Any])
        }
        return path
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
