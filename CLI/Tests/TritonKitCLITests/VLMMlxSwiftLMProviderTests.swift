import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("P17 local mlx-swift-lm provider")
struct VLMMlxSwiftLMProviderTests {
    @Test("provider list exposes mlx-swift-lm as experimental local provider")
    func providerListExposesMLXSwiftLM() throws {
        let response = vlmProviderListResponse()
        let provider = try #require(response.providers.first { $0.id == "mlx-swift-lm" })

        #expect(provider.kind == "local-vlm")
        #expect(provider.status == "experimental")
        #expect(provider.requiresNetwork == false)
        #expect(provider.requiresModel)
        #expect(provider.defaultEnabledInCI == false)
        #expect(provider.supports == ["point-grounding"])
        #expect(provider.coordinateOutputs.contains("normalized_0_1000"))
        #expect(provider.coordinateOutputs.contains("runtime-point"))
        #expect(provider.runnerIntegration?.requiresAllowVLM == true)
        #expect(provider.runnerIntegration?.defaultEnabled == false)
    }

    @Test("fake mlx-swift-lm grounding writes full P17 evidence artifacts")
    func fakeMLXSwiftLMGroundingWritesEvidence() throws {
        let fixture = try VLMGroundingFixture()
        let response = try groundVLMTarget(
            provider: "mlx-swift-lm",
            image: fixture.image.path,
            target: "Go Home button",
            coordinateContract: fixture.coordinateContract.path,
            outputDirectory: fixture.output.path,
            modelPath: "/tmp/triton-fake-mlx-model"
        )

        #expect(response.provider == "mlx-swift-lm")
        #expect(response.model == "/tmp/triton-fake-mlx-model")
        #expect(response.point.normalized.x == 500)
        #expect(response.point.normalized.y == 331)
        #expect(abs(response.point.runtimePoint.x - 201) < 0.001)
        #expect(abs(response.point.runtimePoint.y - 289.294) < 0.001)
        #expect(response.artifacts.request.hasSuffix("mlx-grounding-request.redacted.json"))
        #expect(response.artifacts.response.hasSuffix("mlx-grounding-response.json"))
        #expect(response.artifacts.overlay.hasSuffix("mlx-grounding-overlay.png"))

        let requiredArtifacts = [
            response.artifacts.request,
            response.artifacts.response,
            response.artifacts.overlay,
            try #require(response.artifacts.rawOutput),
            try #require(response.artifacts.parsedPoint),
            try #require(response.artifacts.transform),
            try #require(response.artifacts.modelMetadata),
        ]
        for artifact in requiredArtifacts {
            #expect(FileManager.default.fileExists(atPath: artifact), "missing artifact: \(artifact)")
        }

        let request = try JSONDecoder().decode(
            TKVLMGroundingRequestArtifact.self,
            from: Data(contentsOf: URL(fileURLWithPath: response.artifacts.request))
        )
        #expect(request.network == "local-helper")
        #expect(request.redaction == "target-text-only")

        let rawOutput = try String(contentsOfFile: try #require(response.artifacts.rawOutput), encoding: .utf8)
        #expect(rawOutput.contains(#""x":500"#))

        let parsed = try JSONDecoder().decode(
            TKVLMMLXParsedPointArtifact.self,
            from: Data(contentsOf: URL(fileURLWithPath: try #require(response.artifacts.parsedPoint)))
        )
        #expect(parsed.normalizedPoint.x == 500)
        #expect(parsed.normalizedPoint.y == 331)

        let metadata = try JSONDecoder().decode(
            TKVLMMLXModelMetadata.self,
            from: Data(contentsOf: URL(fileURLWithPath: try #require(response.artifacts.modelMetadata)))
        )
        #expect(metadata.provider == "mlx-swift-lm")
        #expect(metadata.modelPath == "/tmp/triton-fake-mlx-model")
        #expect(metadata.downloadAllowed == false)
        #expect(metadata.mode == "fake-helper")
    }

    @Test("mlx-swift-lm requires explicit model id or model path")
    func mlxSwiftLMRequiresModelConfiguration() throws {
        let fixture = try VLMGroundingFixture()

        do {
            _ = try groundVLMTarget(
                provider: "mlx-swift-lm",
                image: fixture.image.path,
                target: "Go Home button",
                coordinateContract: fixture.coordinateContract.path,
                outputDirectory: fixture.output.path
            )
            Issue.record("Expected mlx_model_load_failed")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "mlx_model_load_failed")
        }
    }
}

@Suite("P17 mlx-swift-lm parser")
struct VLMMlxSwiftLMParserTests {
    @Test("strict parser accepts JSON, wrapped JSON, and tuple points")
    func parserAcceptsSupportedPointShapes() throws {
        let json = try parseMLXSwiftLMGroundingOutput(#"{"x":512,"y":734,"scale":1000}"#)
        #expect(json.x == 512)
        #expect(json.y == 734)

        let wrapped = try parseMLXSwiftLMGroundingOutput(#"{"point":{"x":512,"y":734,"scale":1000}}"#)
        #expect(wrapped.x == 512)
        #expect(wrapped.y == 734)

        let tuple = try parseMLXSwiftLMGroundingOutput("(512, 734)")
        #expect(tuple.x == 512)
        #expect(tuple.y == 734)
    }

    @Test("strict parser maps target_not_visible to machine-readable failure")
    func parserMapsTargetNotVisible() throws {
        do {
            _ = try parseMLXSwiftLMGroundingOutput(#"{"error":"target_not_visible"}"#)
            Issue.record("Expected vlm_target_not_visible")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "vlm_target_not_visible")
        }
    }

    @Test("strict parser rejects empty free-form action and out-of-bounds outputs")
    func parserRejectsUnsupportedOutputs() throws {
        try expectMLXParseFailure("", code: "mlx_response_empty")
        try expectMLXParseFailure("The button is around the middle of the screen.", code: "mlx_parse_failed")
        try expectMLXParseFailure(#"click(512, 734) + type("hello")"#, code: "mlx_parse_failed")
        try expectMLXParseFailure(#"{"x":1200,"y":734,"scale":1000}"#, code: "vlm_point_out_of_bounds")
        try expectMLXParseFailure(#"{"x":512,"y":734,"scale":1}"#, code: "mlx_parse_failed")
    }
}

private func expectMLXParseFailure(_ rawOutput: String, code: String) throws {
    do {
        _ = try parseMLXSwiftLMGroundingOutput(rawOutput)
        Issue.record("Expected \(code)")
    } catch let failure as TKVLMGroundingFailure {
        #expect(failure.code == code)
    }
}
