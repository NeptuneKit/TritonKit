#if canImport(UIKit)
import UIKit

@MainActor
enum TKLabelTextAttributes {
    static func group(for label: UILabel) -> TKAttributesGroup {
        let font = label.font ?? UIFont.systemFont(ofSize: UIFont.labelFontSize)
        let foreground = (label.isHighlighted ? label.highlightedTextColor : nil) ?? label.textColor ?? UIColor.label
        let runs = label.attributedText.map { text in
            TKAttributedTextRuns.collect(text) { values in
                style(font: values[.font] as? UIFont ?? font,
                      color: values[.foregroundColor] as? UIColor ?? foreground,
                      traits: label.traitCollection)
            }
        }
        let textLength = runs?.utf16Length ?? (label.text as NSString?)?.length ?? 0
        let preview = TKTextAttributePreview.make(label.text ?? "")
        let metadata: [TKAttribute] = [
            TKAttribute(identifier: "text", displayTitle: "Text", attrType: 0, value: .string(preview.text)),
            TKAttribute(identifier: "text_truncated", attrType: 3, value: .bool(preview.truncated)),
            TKAttribute(identifier: "text_utf16_limit", attrType: 2, value: .number(Double(TKTextAttributePreview.maximumUTF16Length))),
            TKAttribute(identifier: "lines", displayTitle: "Lines", attrType: 2, value: .number(Double(label.numberOfLines))),
            TKAttribute(identifier: "text_content_included", attrType: 3, value: .bool(true)),
            TKAttribute(identifier: "has_attributed_text", attrType: 3, value: .bool(label.attributedText != nil)),
            TKAttribute(identifier: "range_unit", attrType: 0, value: .string("utf16")),
            TKAttribute(identifier: "text_utf16_length", attrType: 2, value: .number(Double(textLength))),
            TKAttribute(identifier: "runs_covered_utf16_length", attrType: 2, value: .number(Double(runs?.coveredUTF16Length ?? 0))),
            TKAttribute(identifier: "runs_truncated", attrType: 3, value: .bool(runs?.truncated ?? false)),
            TKAttribute(identifier: "runs_limit", attrType: 2, value: .number(Double(TKAttributedTextRuns.maximumRuns))),
            TKAttribute(identifier: "runs_utf16_limit", attrType: 2, value: .number(Double(TKAttributedTextRuns.maximumUTF16Length))),
            TKAttribute(identifier: "style_scope", attrType: 0, value: .string("public_label_and_attributed_text_properties"))
        ]
        return TKAttributesGroup(identifier: "ui_label", userCustomTitle: "UILabel", attrSections: [
            TKAttributesSection(identifier: "text", attributes: style(font: font, color: foreground, traits: label.traitCollection) + metadata)
        ] + (runs?.sections ?? []))
    }

    private static func style(font: UIFont, color: UIColor, traits: UITraitCollection) -> [TKAttribute] {
        var attributes = [
            TKAttribute(identifier: "font_name", displayTitle: "Font", attrType: 0, value: .string(String(font.fontName.prefix(256))))
        ]
        if font.pointSize.isFinite && font.pointSize > 0 {
            attributes.append(TKAttribute(identifier: "font_size", displayTitle: "Font Size", attrType: 1, value: .number(Double(font.pointSize))))
            attributes.append(TKAttribute(identifier: "font_status", attrType: 0, value: .string("resolved")))
        } else {
            attributes.append(TKAttribute(identifier: "font_status", attrType: 0, value: .string("invalid_point_size")))
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let resolved = color.resolvedColor(with: traits)
        let supported = resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let components = [red, green, blue, alpha].map(Double.init)
        if supported && components.allSatisfy(\.isFinite) {
            attributes.append(TKAttribute(identifier: "foreground_color_rgba", displayTitle: "Foreground RGBA", attrType: 0, value: .numberArray(components)))
            attributes.append(TKAttribute(identifier: "foreground_color_status", attrType: 0, value: .string("resolved")))
        } else {
            attributes.append(TKAttribute(identifier: "foreground_color_status", attrType: 0, value: .string("unsupported_color_space")))
        }
        return attributes
    }
}
#endif
