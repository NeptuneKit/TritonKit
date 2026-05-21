import Foundation
import Testing
@testable import TritonKit

@Suite
struct TKPlatformFallbackTests {
    @Test("runtime is enabled only in DEBUG builds")
    func runtimeEnabledFlagMatchesBuildConfiguration() {
        #if DEBUG
        #expect(TritonKit.isRuntimeEnabled)
        #else
        #expect(!TritonKit.isRuntimeEnabled)
        #endif
    }

    @Test("start payload defaults to local Triton CLI endpoint")
    func startPayloadDefaultsToLocalEndpoint() {
        let payload = TritonKitStartPayload()

        #expect(payload.host == "127.0.0.1")
        #expect(payload.port == 19421)
        #expect(payload.dataURL == URL(string: "http://127.0.0.1:19421"))
    }

    @Test("start payload reads environment with stable fallbacks")
    func startPayloadReadsEnvironment() {
        let payload = TritonKitStartPayload.environment([
            "TRITON_HOST": "192.168.1.20",
            "TRITON_PORT": "19422"
        ])
        let fallbackPayload = TritonKitStartPayload.environment([
            "TRITON_PORT": "not-a-port"
        ])

        #expect(payload.host == "192.168.1.20")
        #expect(payload.port == 19422)
        #expect(payload.dataURL == URL(string: "http://192.168.1.20:19422"))
        #expect(fallbackPayload.host == "127.0.0.1")
        #expect(fallbackPayload.port == 19421)
    }

    @Test("hierarchy builder returns an empty fallback on non-UIKit platforms")
    func hierarchyBuilderFallback() async {
        #if !canImport(UIKit)
        let items = await TKHierarchyBuilder.buildHierarchy()

        #expect(items.isEmpty)
        #endif
    }

    @Test("hierarchy builder defaults cover deeply nested app containers")
    func hierarchyBuilderDefaultTraversalLimits() {
        #expect(TKHierarchyBuilder.defaultMaxDepth >= 32)
        #expect(TKHierarchyBuilder.defaultMaxChildrenPerNode >= 100)
    }
}
