import Foundation
import Testing
@testable import TritonKit
import TritonKitShared
#if canImport(UIKit)
import UIKit

@MainActor
@Suite(.serialized)
struct TKLabelAttributeGroupsTests {
    final class CustomLabel: UILabel {}

    @Test func viewAndLayerOIDsReturnLabelAttributes() async throws {
        let label = CustomLabel()
        label.text = "sensitive-label-copy"
        for object in [label as AnyObject, label.layer as AnyObject] {
            let oid = TKObjectRegistry.shared.register(object)
            let request = TKMessage(id: 1, type: .allAttrGroups, payload: try JSONEncoder().encode(oid))
            let response = try #require(await TritonKitRequestHandler().handleAllAttrGroups(request))
            let payload = try #require(response.payload)
            let groups = try JSONDecoder().decode([TKAttributesGroup].self, from: payload)
            #expect(groups.contains { $0.identifier == "ui_label" })
            #expect(String(decoding: payload, as: UTF8.self).contains("sensitive-label-copy"))
        }
    }

    @Test func mixedRunsHaveEffectiveFontsColorsAndUTF16Ranges() throws {
        let label = CustomLabel()
        label.font = .systemFont(ofSize: 19)
        label.textColor = .green
        let text = NSMutableAttributedString(string: "🔒42kg")
        text.addAttributes([.foregroundColor: UIColor.red, .font: UIFont.boldSystemFont(ofSize: 23)], range: NSRange(location: 2, length: 2))
        text.addAttribute(.init("private"), value: "private-value", range: NSRange(location: 4, length: 2))
        label.attributedText = text
        let group = try labelGroup(label)
        let runs = group.attrSections.filter { $0.identifier.hasPrefix("text_run_") }
        #expect(runs.count == 3)
        #expect(number(runs[1], "range_location") == 2)
        #expect(number(runs[1], "range_length") == 2)
        #expect(number(runs[1], "font_size") == 23)
        #expect(color(runs[1]) == [1, 0, 0, 1])
        #expect(number(runs[0], "font_size") == Double(label.font.pointSize))
        #expect(color(runs[0]) == [0, 1, 0, 1])
        let json = String(decoding: try JSONEncoder().encode(group), as: UTF8.self)
        #expect(!json.contains("private-value"))
        #expect(json.components(separatedBy: "🔒42kg").count == 2)
    }

    @Test func resolvesDynamicColorsUsingLabelTraits() throws {
        // An unattached UIView has no established trait environment; its override
        // alone is not evidence that UIKit has propagated a dark trait collection.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let controller = UIViewController()
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .dark
        window.isHidden = false
        defer { window.isHidden = true }
        let label = CustomLabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        controller.view.addSubview(label)
        window.layoutIfNeeded()
        try #require(label.window === window)
        try #require(label.traitCollection.userInterfaceStyle == .dark)

        // Deliberately use a different ambient trait: serialization must use the
        // inspected label's environment for both defaults and attributed runs.
        var defaultGroups: [TKAttributesGroup] = []
        var attributedGroups: [TKAttributesGroup] = []
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            label.textColor = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
            defaultGroups = TKAttributeGroupsBuilder.build(for: label.layer)
            label.attributedText = NSAttributedString(string: "x", attributes: [.foregroundColor: UIColor { $0.userInterfaceStyle == .dark ? .red : .blue }])
            attributedGroups = TKAttributeGroupsBuilder.build(for: label.layer)
        }
        let group = try #require(defaultGroups.first { $0.identifier == "ui_label" })
        let section = try #require(group.attrSections.first { $0.identifier == "text" })
        #expect(color(section) == [1, 1, 1, 1])
        let attributedGroup = try #require(attributedGroups.first { $0.identifier == "ui_label" })
        let run = try #require(attributedGroup.attrSections.first { $0.identifier == "text_run_0" })
        #expect(color(run) == [1, 0, 0, 1])
    }

    @Test func unsupportedColorsStayExplicitAndSerializable() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let label = UILabel()
        label.textColor = UIColor(patternImage: renderer.image { _ in UIColor.red.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 1, height: 1)) })
        let group = try labelGroup(label)
        let section = try #require(group.attrSections.first { $0.identifier == "text" })
        #expect(color(section) == nil)
        #expect(section.attributes.contains { $0.identifier == "foreground_color_status" })
        _ = try JSONEncoder().encode(group)
    }

    private func labelGroup(_ label: UILabel) throws -> TKAttributesGroup {
        try #require(TKAttributeGroupsBuilder.build(for: label.layer).first { $0.identifier == "ui_label" })
    }
    private func number(_ section: TKAttributesSection, _ identifier: String) -> Double? {
        guard case .number(let value) = section.attributes.first(where: { $0.identifier == identifier })?.value else { return nil }
        return value
    }
    private func color(_ section: TKAttributesSection) -> [Double]? {
        guard case .numberArray(let value) = section.attributes.first(where: { $0.identifier == "foreground_color_rgba" })?.value else { return nil }
        return value
    }
}
#endif
