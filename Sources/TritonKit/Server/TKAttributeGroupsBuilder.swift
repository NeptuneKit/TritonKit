#if canImport(UIKit)
import UIKit

@MainActor
public enum TKAttributeGroupsBuilder {

    public static func build(for layer: CALayer) -> [TKAttributesGroup] {
        let view = layer.tk_hostView

        var groups: [TKAttributesGroup] = []

        // Class group
        groups.append(buildClassGroup(for: view.map { $0 as NSObject } ?? layer))

        // Layout group
        groups.append(buildLayoutGroup(for: layer))

        // ViewLayer group
        groups.append(buildViewLayerGroup(for: layer, view: view))

        // UIKit-specific groups
        if let imageView = view as? UIImageView {
            groups.append(buildImageViewGroup(for: imageView))
        }
        if let label = view as? UILabel {
            groups.append(TKLabelTextAttributes.group(for: label))
        }
        if let scrollView = view as? UIScrollView {
            groups.append(buildScrollViewGroup(for: scrollView))
        }

        return groups.filter { !$0.attrSections.isEmpty }
    }

    // MARK: - Group Builders

    private static func buildClassGroup(for object: NSObject) -> TKAttributesGroup {
        let section = TKAttributesSection(
            identifier: "class",
            attributes: [
                TKAttribute(
                    identifier: "class_name",
                    displayTitle: "Class",
                    attrType: 0,
                    value: .string(NSStringFromClass(type(of: object)))
                ),
                TKAttribute(
                    identifier: "address",
                    displayTitle: "Address",
                    attrType: 0,
                    value: .string("\(Unmanaged.passUnretained(object).toOpaque())")
                )
            ]
        )
        return TKAttributesGroup(identifier: "class", userCustomTitle: "Class", attrSections: [section])
    }

    private static func buildLayoutGroup(for layer: CALayer) -> TKAttributesGroup {
        var sections: [TKAttributesSection] = []

        // Frame section
        let frame = layer.frame
        sections.append(TKAttributesSection(
            identifier: "frame",
            attributes: [
                TKAttribute(identifier: "frame_x", displayTitle: "X", attrType: 1, value: .number(Double(frame.origin.x))),
                TKAttribute(identifier: "frame_y", displayTitle: "Y", attrType: 1, value: .number(Double(frame.origin.y))),
                TKAttribute(identifier: "frame_w", displayTitle: "Width", attrType: 1, value: .number(Double(frame.size.width))),
                TKAttribute(identifier: "frame_h", displayTitle: "Height", attrType: 1, value: .number(Double(frame.size.height)))
            ]
        ))

        // Bounds section
        let bounds = layer.bounds
        sections.append(TKAttributesSection(
            identifier: "bounds",
            attributes: [
                TKAttribute(identifier: "bounds_x", displayTitle: "X", attrType: 1, value: .number(Double(bounds.origin.x))),
                TKAttribute(identifier: "bounds_y", displayTitle: "Y", attrType: 1, value: .number(Double(bounds.origin.y))),
                TKAttribute(identifier: "bounds_w", displayTitle: "Width", attrType: 1, value: .number(Double(bounds.size.width))),
                TKAttribute(identifier: "bounds_h", displayTitle: "Height", attrType: 1, value: .number(Double(bounds.size.height)))
            ]
        ))

        return TKAttributesGroup(identifier: "layout", userCustomTitle: "Layout", attrSections: sections)
    }

    private static func buildViewLayerGroup(for layer: CALayer, view: UIView?) -> TKAttributesGroup {
        var sections: [TKAttributesSection] = []

        // Visibility
        var visibility = [
            TKAttribute(identifier: "hidden", displayTitle: "Hidden", attrType: 3, value: .bool(layer.isHidden)),
            TKAttribute(identifier: "alpha", displayTitle: "Alpha", attrType: 1, value: .number(Double(layer.opacity)))
        ]
        if let view {
            visibility.append(TKAttribute(identifier: "clips_to_bounds", displayTitle: "Clips To Bounds", attrType: 3, value: .bool(view.clipsToBounds)))
            visibility.append(TKAttribute(identifier: "user_interaction", displayTitle: "User Interaction", attrType: 3, value: .bool(view.isUserInteractionEnabled)))
        }
        sections.append(TKAttributesSection(identifier: "visibility", attributes: visibility))
        sections.append(TKAttributesSection(identifier: "position", attributes: [
            TKAttribute(identifier: "z_position", displayTitle: "Z Position", attrType: 1, value: .number(Double(layer.zPosition)))
        ]))

        // Background Color
        if let bg = TKColor(uiColor: layer.backgroundColor.flatMap { UIColor(cgColor: $0) }) {
            sections.append(TKAttributesSection(
                identifier: "bg_color",
                attributes: [
                    TKAttribute(identifier: "bg_r", displayTitle: "Red", attrType: 1, value: .number(Double(bg.red))),
                    TKAttribute(identifier: "bg_g", displayTitle: "Green", attrType: 1, value: .number(Double(bg.green))),
                    TKAttribute(identifier: "bg_b", displayTitle: "Blue", attrType: 1, value: .number(Double(bg.blue))),
                    TKAttribute(identifier: "bg_a", displayTitle: "Alpha", attrType: 1, value: .number(Double(bg.alpha)))
                ]
            ))
        }

        // Corner
        sections.append(TKAttributesSection(
            identifier: "corner",
            attributes: [
                TKAttribute(identifier: "corner_radius", displayTitle: "Corner Radius", attrType: 1, value: .number(Double(layer.cornerRadius))),
                TKAttribute(identifier: "masks_to_bounds", displayTitle: "Masks To Bounds", attrType: 3, value: .bool(layer.masksToBounds))
            ]
        ))

        // Border
        sections.append(TKAttributesSection(
            identifier: "border",
            attributes: [
                TKAttribute(identifier: "border_width", displayTitle: "Border Width", attrType: 1, value: .number(Double(layer.borderWidth)))
            ]
        ))

        // Shadow
        sections.append(TKAttributesSection(
            identifier: "shadow",
            attributes: [
                TKAttribute(identifier: "shadow_opacity", displayTitle: "Shadow Opacity", attrType: 1, value: .number(Double(layer.shadowOpacity))),
                TKAttribute(identifier: "shadow_radius", displayTitle: "Shadow Radius", attrType: 1, value: .number(Double(layer.shadowRadius)))
            ]
        ))

        // A standalone CALayer does not have UIView tags or interaction state.
        if let view {
            sections.append(TKAttributesSection(
                identifier: "tag",
                attributes: [
                    TKAttribute(identifier: "tag", displayTitle: "Tag", attrType: 2, value: .number(Double(view.tag)))
                ]
            ))
        }
        return TKAttributesGroup(identifier: "view_layer", userCustomTitle: view == nil ? "Layer" : "View & Layer", attrSections: sections)
    }

    private static func buildImageViewGroup(for imageView: UIImageView) -> TKAttributesGroup {
        TKAttributesGroup(
            identifier: "ui_imageview",
            userCustomTitle: "UIImageView",
            attrSections: [
                TKAttributesSection(identifier: "image", attributes: [
                    TKAttribute(identifier: "has_image", displayTitle: "Has Image", attrType: 3, value: .bool(imageView.image != nil)),
                    TKAttribute(identifier: "content_mode", displayTitle: "Content Mode", attrType: 2, value: .number(Double(imageView.contentMode.rawValue)))
                ])
            ]
        )
    }

    private static func buildScrollViewGroup(for scrollView: UIScrollView) -> TKAttributesGroup {
        TKAttributesGroup(
            identifier: "ui_scrollview",
            userCustomTitle: "UIScrollView",
            attrSections: [
                TKAttributesSection(identifier: "scroll", attributes: [
                    TKAttribute(identifier: "content_offset_x", displayTitle: "Content Offset X", attrType: 1, value: .number(Double(scrollView.contentOffset.x))),
                    TKAttribute(identifier: "content_offset_y", displayTitle: "Content Offset Y", attrType: 1, value: .number(Double(scrollView.contentOffset.y))),
                    TKAttribute(identifier: "content_size_w", displayTitle: "Content Width", attrType: 1, value: .number(Double(scrollView.contentSize.width))),
                    TKAttribute(identifier: "content_size_h", displayTitle: "Content Height", attrType: 1, value: .number(Double(scrollView.contentSize.height)))
                ])
            ]
        )
    }
}
#endif
