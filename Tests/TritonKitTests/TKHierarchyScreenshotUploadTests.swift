import Foundation
import Testing
@testable import TritonKit

@Suite("Hierarchy screenshot transport")
struct TKHierarchyScreenshotUploadTests {
    @Test("group and solo keep distinct references through recursive upload")
    func separateReferences() async throws {
        var child = TKDisplayItem()
        child.groupScreenshot = Data([1])
        child.soloScreenshot = Data([2])
        let result = await TritonKitRequestHandler().uploadHierarchyScreenshots([TKDisplayItem(subitems: [child])]) {
            $0 == Data([1]) ? "group-ref" : "solo-ref"
        }
        let uploaded = try #require(result.first?.subitems.first)
        #expect(uploaded.groupScreenshotRef == "group-ref")
        #expect(uploaded.soloScreenshotRef == "solo-ref")
        #expect(uploaded.screenshotRef == "group-ref")
        #expect(uploaded.groupScreenshot == nil && uploaded.soloScreenshot == nil)
        let roundtrip = try JSONDecoder().decode(TKDisplayItem.self, from: JSONEncoder().encode(uploaded))
        #expect(roundtrip.soloScreenshotRef == "solo-ref")
        #expect(roundtrip.groupScreenshotRef == "group-ref")
    }

    @Test("a failed upload preserves that image's bytes")
    func failedUploadRetainsBytes() async throws {
        var item = TKDisplayItem()
        item.groupScreenshot = Data([1])
        item.soloScreenshot = Data([2])
        let result = await TritonKitRequestHandler().uploadHierarchyScreenshots([item]) { data in
            if data == Data([2]) { throw UploadFailure.failed }
            return "group-ref"
        }
        let uploaded = try #require(result.first)
        #expect(uploaded.groupScreenshot == nil)
        #expect(uploaded.groupScreenshotRef == "group-ref")
        #expect(uploaded.soloScreenshot == Data([2]))
        #expect(uploaded.soloScreenshotRef == nil)
    }

    @Test("old hierarchy JSON without the new references still decodes")
    func legacyJSON() throws {
        let encoded = try JSONEncoder().encode(TKDisplayItem())
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "soloScreenshotRef")
        object.removeValue(forKey: "groupScreenshotRef")
        let decoded = try JSONDecoder().decode(TKDisplayItem.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.soloScreenshotRef == nil && decoded.groupScreenshotRef == nil)
    }
}

private enum UploadFailure: Error { case failed }
