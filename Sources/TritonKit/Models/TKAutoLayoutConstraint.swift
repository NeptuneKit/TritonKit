import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

public struct TKAutoLayoutConstraint: Codable {
    public let effective: Bool
    public let active: Bool
    public let shouldBeArchived: Bool
    public let firstItem: TKObject?
    public let firstItemType: TKConstraintItemType
    public let firstAttribute: Int
    public let relation: Int
    public let secondItem: TKObject?
    public let secondItemType: TKConstraintItemType
    public let secondAttribute: Int
    public let multiplier: CGFloat
    public let constant: CGFloat
    public let priority: CGFloat
    public let identifier: String?

    public init(effective: Bool, active: Bool, firstItem: TKObject?, firstItemType: TKConstraintItemType, firstAttribute: Int, relation: Int, secondItem: TKObject?, secondItemType: TKConstraintItemType, secondAttribute: Int, multiplier: CGFloat, constant: CGFloat, priority: CGFloat, identifier: String?) {
        self.effective = effective
        self.active = active
        self.shouldBeArchived = effective
        self.firstItem = firstItem
        self.firstItemType = firstItemType
        self.firstAttribute = firstAttribute
        self.relation = relation
        self.secondItem = secondItem
        self.secondItemType = secondItemType
        self.secondAttribute = secondAttribute
        self.multiplier = multiplier
        self.constant = constant
        self.priority = priority
        self.identifier = identifier
    }
}
