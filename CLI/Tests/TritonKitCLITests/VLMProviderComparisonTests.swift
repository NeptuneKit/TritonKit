import Foundation
import Testing
@testable import TritonKitCLI

@Suite("P20 VLM provider comparison")
struct VLMProviderComparisonTests {
    @Test("compare records provider-level pass failure and agreement artifacts")
    func compareRecordsProviderLevelResults() throws {
        let fixture = try VLMGroundingFixture()
        let response = try compareVLMProviders(
            image: fixture.image.path,
            target: "Go Home button",
            coordinateContract: fixture.coordinateContract.path,
            providers: ["mock", "mlx-swift-lm", "openai-compatible"],
            outputDirectory: fixture.root.appendingPathComponent("compare", isDirectory: true).path,
            modelPath: "/tmp/triton-fake-mlx-model"
        )

        #expect(response.ok)
        #expect(response.kind == "triton.vlm.compare-result")
        #expect(response.results.count == 3)
        #expect(response.results.first { $0.provider == "mock" }?.status == "passed")
        #expect(response.results.first { $0.provider == "mlx-swift-lm" }?.status == "passed")
        #expect(response.results.first { $0.provider == "openai-compatible" }?.status == "failed")
        #expect(response.agreement.passedProviderCount == 2)
        #expect(response.agreement.failedProviderCount == 1)
        #expect(response.agreement.withinThreshold)
        #expect(FileManager.default.fileExists(atPath: response.artifacts.comparisonOverlay))
        #expect(FileManager.default.fileExists(atPath: response.artifacts.results))
    }
}
