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

        let htmlURL = fixture.root.appendingPathComponent("viewer.html")
        _ = try exportTritonAppMapViewer(mapPath: mapURL.path, output: htmlURL.path)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(html.contains("VLM Provider Health"))
        #expect(html.contains("mock"))
    }
}
