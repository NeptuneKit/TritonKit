import Testing
@testable import TritonKitCLI

@Suite
struct SimulatorResourceCatalogTests {
    @Test("Pinned upstream catalog includes every category, feature and managed service")
    func completeCatalog() {
        #expect(SimulatorResourceCatalog.sourceCommit == "f3b979ecd913f56904a9b6100cad1f84fe01d228")
        #expect(SimulatorResourceCatalog.categories.map(\.id) == [
            "widgets", "siri", "search", "icloud", "store", "pim", "web", "family",
            "health", "photos", "apps", "messaging", "connectivity", "telemetry", "other",
        ])
        #expect(SimulatorResourceCatalog.features.count == 24)
        #expect(SimulatorResourceCatalog.slimmableLabels.count == 170)
        #expect(SimulatorResourceCatalog.managedLabels.count == 171)
        for feature in SimulatorResourceCatalog.features {
            #expect(Set(feature.labels).isSubset(of: SimulatorResourceCatalog.slimmableLabels))
        }
    }

    @Test("Keeping a category preserves its services shared with other disabled categories")
    func sharedLabelsStayEnabled() throws {
        let desired = try SimulatorResourceCatalog.desired(exceptCategories: ["store"])
        #expect(!desired.contains("com.apple.amsaccountsd"))
        #expect(!desired.contains("com.apple.passd"))
        #expect(!desired.contains("com.apple.financed"))
        #expect(desired.contains("com.apple.cloudd"))
        #expect(desired.contains("com.apple.merchantd"))
        #expect(!desired.contains("com.apple.sharingd"))
        let kept = try SimulatorResourceCatalog.desired(keep: ["com.apple.apsd"])
        #expect(!kept.contains("com.apple.apsd"))
    }

    @Test("StoreKit dependencies include payment sheet hosting, not only product lookup")
    func storekitDependencies() throws {
        let feature = try #require(SimulatorResourceCatalog.resolveFeatures(["storekit"]).first)
        #expect(Set(feature.labels) == [
            "com.apple.storekitd", "com.apple.itunesstored", "com.apple.amsaccountsd",
            "com.apple.amsengagementd", "com.apple.amsondevicestoraged", "com.apple.passd", "com.apple.financed",
        ])
    }

    @Test("Unknown selections fail instead of silently applying a different profile")
    func rejectsUnknownSelections() {
        #expect(throws: SimulatorResourceCatalogError.unknownCategory("typo")) {
            try SimulatorResourceCatalog.desired(exceptCategories: ["typo"])
        }
        #expect(throws: SimulatorResourceCatalogError.unknownLabel("com.apple.unknown")) {
            try SimulatorResourceCatalog.desired(keep: ["com.apple.unknown"])
        }
        #expect(throws: SimulatorResourceCatalogError.unknownFeature("storeKit")) {
            try SimulatorResourceCatalog.resolveFeatures(["storeKit"])
        }
    }

    @Test("Delta leaves unmanaged overrides untouched and repairs legacy sharingd disablement")
    func scopedDelta() {
        let delta = SimulatorResourceCatalog.delta(
            current: ["private.custom", "com.apple.sharingd", "com.apple.apsd"],
            desired: ["private.new", "com.apple.sharingd", "com.apple.searchd"])
        #expect(delta.disable == ["com.apple.searchd"])
        #expect(delta.enable == ["com.apple.apsd", "com.apple.sharingd"])
    }
}
