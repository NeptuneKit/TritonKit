import AppKit
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("P4-P5 VLM grounding")
struct VLMGroundingTests {
    @Test("mock grounding writes runtime-point, transform, and evidence artifacts")
    func mockGroundingWritesArtifacts() throws {
        let fixture = try VLMGroundingFixture()
        let response = try groundVLMTarget(
            provider: "mock",
            image: fixture.image.path,
            target: "Go Home button",
            coordinateContract: fixture.coordinateContract.path,
            outputDirectory: fixture.output.path
        )

        #expect(response.ok)
        #expect(response.provider == "mock")
        #expect(response.image.width == 402)
        #expect(response.image.height == 874)
        #expect(response.coordinateContract.canonicalTapSpace == "runtime-point")
        #expect(response.point.coordinateSpace == "runtime-point")
        #expect(response.point.normalized.x == 500)
        #expect(abs(response.point.runtimePoint.x - 201) < 0.001)
        #expect(abs(response.point.runtimePoint.y - 289.5) < 0.001)
        #expect(response.transform.inputSpace == "normalized_0_1000")
        #expect(response.transform.imageSpace == "image-pixel")
        #expect(response.transform.outputSpace == "runtime-point")
        #expect(response.transform.runtimeWidth == 402)
        #expect(response.transform.runtimeHeight == 874)
        #expect(response.transform.scale == 3)
        #expect(response.transform.orientation == "portrait")
        #expect(FileManager.default.fileExists(atPath: response.artifacts.overlay))
        #expect(FileManager.default.fileExists(atPath: response.artifacts.request))
        #expect(FileManager.default.fileExists(atPath: response.artifacts.response))

        let overlaySize = try FileManager.default.attributesOfItem(atPath: response.artifacts.overlay)[.size] as? NSNumber
        #expect((overlaySize?.intValue ?? 0) > 0)

        let request = try JSONDecoder().decode(
            TKVLMGroundingRequestArtifact.self,
            from: Data(contentsOf: URL(fileURLWithPath: response.artifacts.request))
        )
        #expect(request.network == "not-used")
        #expect(request.redaction == "target-text-only")

        let providerResponse = try JSONDecoder().decode(
            TKVLMProviderResponseArtifact.self,
            from: Data(contentsOf: URL(fileURLWithPath: response.artifacts.response))
        )
        #expect(providerResponse.coordinateSpace == "normalized_0_1000")
    }

    @Test("openai-compatible provider parses localhost chat completion points")
    func openAICompatibleProviderParsesLocalhostPoint() throws {
        let fixture = try VLMGroundingFixture()
        var capturedURL: URL?
        var capturedHeaders: [String: String] = [:]
        var capturedBody: [String: Any] = [:]

        let response = try groundVLMTarget(
            provider: "openai-compatible",
            image: fixture.image.path,
            target: "Go Home button",
            coordinateContract: fixture.coordinateContract.path,
            outputDirectory: fixture.output.path,
            baseURL: "http://127.0.0.1:8000/v1",
            model: "UGround-V1-7B",
            httpTransport: { url, body, headers in
                capturedURL = url
                capturedHeaders = headers
                capturedBody = (try JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
                return Data(
                    """
                    {
                      "choices": [
                        { "message": { "content": "(500,331.2356979405034)" } }
                      ]
                    }
                    """.utf8
                )
            }
        )

        #expect(response.provider == "openai-compatible")
        #expect(response.model == "UGround-V1-7B")
        #expect(response.baseURL == "http://127.0.0.1:8000/v1")
        #expect(response.point.coordinateSpace == "runtime-point")
        #expect(abs(response.point.runtimePoint.x - 201) < 0.001)
        #expect(abs(response.point.runtimePoint.y - 289.5) < 0.001)
        #expect(response.transform.inputSpace == "normalized_0_1000")
        #expect(FileManager.default.fileExists(atPath: response.artifacts.overlay))
        #expect(capturedURL?.absoluteString == "http://127.0.0.1:8000/v1/chat/completions")
        #expect(capturedHeaders["Content-Type"] == "application/json")
        #expect(capturedBody["model"] as? String == "UGround-V1-7B")

        let request = try JSONDecoder().decode(
            TKVLMGroundingRequestArtifact.self,
            from: Data(contentsOf: URL(fileURLWithPath: response.artifacts.request))
        )
        #expect(request.network == "openai-compatible")
        #expect(request.baseURL == "http://127.0.0.1:8000/v1")
        #expect(request.model == "UGround-V1-7B")

        let providerResponse = try JSONDecoder().decode(
            TKVLMProviderResponseArtifact.self,
            from: Data(contentsOf: URL(fileURLWithPath: response.artifacts.response))
        )
        #expect(providerResponse.rawText == "(500,331.2356979405034)")
    }

    @Test("openai-compatible requires base url")
    func openAICompatibleRequiresBaseURL() throws {
        let fixture = try VLMGroundingFixture()

        do {
            _ = try groundVLMTarget(
                provider: "openai-compatible",
                image: fixture.image.path,
                target: "Go Home button",
                coordinateContract: fixture.coordinateContract.path,
                outputDirectory: fixture.output.path
            )
            Issue.record("Expected missing base URL failure")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "vlm_openai_base_url_required")
            #expect(!FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent("vlm-request.redacted.json").path))
        }
    }

    @Test("remote openai-compatible provider requires explicit approval")
    func remoteOpenAICompatibleRequiresApproval() throws {
        let fixture = try VLMGroundingFixture()

        do {
            _ = try groundVLMTarget(
                provider: "openai-compatible",
                image: fixture.image.path,
                target: "Go Home button",
                coordinateContract: fixture.coordinateContract.path,
                outputDirectory: fixture.output.path,
                baseURL: "https://example.com/v1",
                model: "remote-model"
            )
            Issue.record("Expected remote provider approval failure")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "vlm_remote_provider_requires_approval")
            #expect(!FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent("vlm-request.redacted.json").path))
        }
    }

    @Test("openai-compatible point parser accepts json point responses")
    func openAICompatiblePointParserAcceptsJSON() throws {
        let point = try parseVLMNormalizedPoint(#"{"point":{"x":"512","y":734,"scale":1000}}"#)
        #expect(point.x == 512)
        #expect(point.y == 734)
        #expect(point.scale == 1000)
    }

    @Test("unsupported providers fail closed without artifacts")
    func unsupportedProviderFailsClosed() throws {
        let fixture = try VLMGroundingFixture()

        do {
            _ = try groundVLMTarget(
                provider: "unknown",
                image: fixture.image.path,
                target: "Go Home button",
                coordinateContract: fixture.coordinateContract.path,
                outputDirectory: fixture.output.path
            )
            Issue.record("Expected unsupported provider failure")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "vlm_unsupported_provider")
            #expect(!FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent("vlm-request.redacted.json").path))
        }
    }

    @Test("out-of-bounds provider points fail before artifact write")
    func outOfBoundsPointFailsClosed() throws {
        let fixture = try VLMGroundingFixture()

        do {
            _ = try groundVLMTarget(
                provider: "mock",
                image: fixture.image.path,
                target: "out-of-bounds target",
                coordinateContract: fixture.coordinateContract.path,
                outputDirectory: fixture.output.path
            )
            Issue.record("Expected out-of-bounds failure")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "vlm_point_out_of_bounds")
            #expect(!FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent("vlm-request.redacted.json").path))
        }
    }

    @Test("invalid coordinate contract fails closed")
    func invalidCoordinateContractFailsClosed() throws {
        let fixture = try VLMGroundingFixture(canonicalTapSpace: "image-pixel")

        do {
            _ = try groundVLMTarget(
                provider: "mock",
                image: fixture.image.path,
                target: "Go Home button",
                coordinateContract: fixture.coordinateContract.path,
                outputDirectory: fixture.output.path
            )
            Issue.record("Expected invalid coordinate contract failure")
        } catch let failure as TKVLMGroundingFailure {
            #expect(failure.code == "vlm_coordinate_contract_invalid")
        }
    }
}

struct VLMGroundingFixture {
    let root: URL
    let image: URL
    let coordinateContract: URL
    let output: URL

    init(canonicalTapSpace: String = "runtime-point") throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tritonkit-vlm-grounding-\(UUID().uuidString)", isDirectory: true)
        image = root.appendingPathComponent("fixture.png")
        coordinateContract = root.appendingPathComponent("coordinate-contract.json")
        output = root.appendingPathComponent("grounding", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try writeFixtureImage(to: image)
        try writeCoordinateContract(to: coordinateContract, canonicalTapSpace: canonicalTapSpace)
    }
}

private func writeFixtureImage(to url: URL) throws {
    let width = 402
    let height = 874
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw RuntimeError("Could not allocate fixture bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    NSColor.black.set()
    ("Fixture Login" as NSString).draw(
        at: NSPoint(x: 120, y: 210),
        withAttributes: [.font: NSFont.systemFont(ofSize: 20)]
    )
    ("Go Home" as NSString).draw(
        at: NSPoint(x: 160, y: 290),
        withAttributes: [.font: NSFont.boldSystemFont(ofSize: 20)]
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw RuntimeError("Could not encode fixture image")
    }
    try data.write(to: url, options: .atomic)
}

private func writeCoordinateContract(to url: URL, canonicalTapSpace: String) throws {
    let json = """
    {
      "schemaVersion": 1,
      "canonicalTapSpace": "\(canonicalTapSpace)",
      "runtimeScreenshotSpace": {
        "kind": "runtime-point-sized-image",
        "width": 402,
        "height": 874,
        "scale": 1
      },
      "runtimeGeometry": {
        "width": 402,
        "height": 874,
        "scale": 3,
        "orientation": "portrait"
      },
      "vlmImageSpace": "not-supported-in-p0e",
      "hostFramebufferSpace": "not-supported-in-p0e"
    }
    """
    try json.data(using: .utf8)?.write(to: url, options: .atomic)
}
