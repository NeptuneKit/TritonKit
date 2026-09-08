import Foundation

/// A bounded, content-free projection of NSAttributedString's UTF-16 ranges.
/// The caller supplies an allowlisted attribute projection; arbitrary values are never encoded here.
enum TKAttributedTextRuns {
    static let maximumRuns = 256
    static let maximumUTF16Length = 16_384

    struct Result {
        let utf16Length: Int
        let coveredUTF16Length: Int
        let sections: [TKAttributesSection]
        var truncated: Bool { coveredUTF16Length < utf16Length }
    }

    static func collect(
        _ text: NSAttributedString,
        maxRuns: Int = maximumRuns,
        maxUTF16Length: Int = maximumUTF16Length,
        attributes: ([NSAttributedString.Key: Any]) -> [TKAttribute]
    ) -> Result {
        let length = text.length
        let limit = min(length, max(0, min(maxUTF16Length, maximumUTF16Length)))
        let runLimit = max(0, min(maxRuns, maximumRuns))
        var sections: [TKAttributesSection] = []
        var covered = 0
        if limit > 0 && runLimit > 0 {
            text.enumerateAttributes(in: NSRange(location: 0, length: limit), options: [.longestEffectiveRangeNotRequired]) { values, range, stop in
                let safeRange = NSIntersectionRange(range, NSRange(location: 0, length: limit))
                let rangeAttributes = [
                    TKAttribute(identifier: "range_location", attrType: 2, value: .number(Double(safeRange.location))),
                    TKAttribute(identifier: "range_length", attrType: 2, value: .number(Double(safeRange.length)))
                ]
                sections.append(TKAttributesSection(identifier: "text_run_\(sections.count)", attributes: rangeAttributes + attributes(values)))
                covered = NSMaxRange(safeRange)
                if sections.count >= runLimit { stop.pointee = true }
            }
        }
        return Result(utf16Length: length, coveredUTF16Length: covered, sections: sections)
    }
}

/// Keep the legacy text field, with a hard UTF-16 limit and no dangling surrogate.
enum TKTextAttributePreview {
    static let maximumUTF16Length = 4_096

    static func make(_ text: String) -> (text: String, truncated: Bool) {
        var units = Array(text.utf16.prefix(maximumUTF16Length))
        if let last = units.last, (0xD800...0xDBFF).contains(last) {
            units.removeLast()
        }
        return (String(decoding: units, as: UTF16.self), units.count < text.utf16.count)
    }
}
