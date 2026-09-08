import Foundation
import Testing
@testable import TritonKit

@Suite
struct TKAttributedTextRunsTests {
    @Test func preservesUTF16RangesAndSanitizesValues() throws {
        let text = NSMutableAttributedString(string: "🔒42kg")
        text.addAttribute(.init("test-color"), value: "red", range: NSRange(location: 2, length: 2))
        text.addAttribute(.init("private-link"), value: "https://secret.invalid", range: NSRange(location: 0, length: 2))
        let result = TKAttributedTextRuns.collect(text) { values in
            [TKAttribute(identifier: "color", attrType: 0, value: .string(values[.init("test-color")] as? String ?? "default"))]
        }
        #expect(result.utf16Length == 6)
        #expect(result.coveredUTF16Length == 6)
        #expect(!result.truncated)
        #expect(result.sections.count == 3)
        let encoded = String(decoding: try JSONEncoder().encode(result.sections), as: UTF8.self)
        #expect(!encoded.contains("secret.invalid"))
        #expect(!encoded.contains("🔒"))
        #expect(encoded.contains("range_location"))
        #expect(number(result.sections[1], "range_location") == 2)
        #expect(number(result.sections[1], "range_length") == 2)
    }

    @Test func boundsRunsAndUTF16Coverage() {
        let text = NSMutableAttributedString(string: "abcdef")
        for i in 0..<text.length {
            text.addAttribute(.init("color"), value: i, range: NSRange(location: i, length: 1))
        }
        let byRuns = TKAttributedTextRuns.collect(text, maxRuns: 2, maxUTF16Length: 6) { _ in [] }
        #expect(byRuns.sections.count == 2)
        #expect(byRuns.coveredUTF16Length == 2)
        #expect(byRuns.truncated)
        let byLength = TKAttributedTextRuns.collect(text, maxRuns: 8, maxUTF16Length: 3) { _ in [] }
        #expect(byLength.sections.count == 3)
        #expect(byLength.coveredUTF16Length == 3)
        #expect(byLength.truncated)
        let exact = TKAttributedTextRuns.collect(text, maxRuns: 6, maxUTF16Length: 6) { _ in [] }
        #expect(!exact.truncated)
    }

    @Test func emptyAndZeroBudgetsAreExplicit() {
        let empty = TKAttributedTextRuns.collect(NSAttributedString(string: "")) { _ in [] }
        #expect(empty.sections.isEmpty)
        #expect(!empty.truncated)
        let zero = TKAttributedTextRuns.collect(NSAttributedString(string: "a"), maxRuns: 0) { _ in [] }
        #expect(zero.sections.isEmpty)
        #expect(zero.truncated)
    }

    @Test func legacyTextPreviewIsBoundedWithoutSplittingSurrogates() {
        let text = String(repeating: "a", count: 4095) + "🔒secret"
        let preview = TKTextAttributePreview.make(text)
        #expect(preview.text.utf16.count == 4095)
        #expect(preview.truncated)
        #expect(!preview.text.contains("�"))
        #expect(TKTextAttributePreview.make("short").text == "short")
        #expect(!TKTextAttributePreview.make("").truncated)
    }

    private func number(_ section: TKAttributesSection, _ identifier: String) -> Double? {
        guard case .number(let value) = section.attributes.first(where: { $0.identifier == identifier })?.value else { return nil }
        return value
    }
}
