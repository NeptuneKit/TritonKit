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
