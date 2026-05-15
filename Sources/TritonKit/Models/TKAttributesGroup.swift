import Foundation

public struct TKAttributesSection: Codable {
    public let identifier: TKAttrSectionIdentifier
    public let attributes: [TKAttribute]

    public init(identifier: TKAttrSectionIdentifier, attributes: [TKAttribute] = []) {
        self.identifier = identifier
        self.attributes = attributes
    }
}

public struct TKAttributesGroup: Codable {
    public let identifier: TKAttrGroupIdentifier
    public let userCustomTitle: String?
    public let attrSections: [TKAttributesSection]

    public init(identifier: TKAttrGroupIdentifier, userCustomTitle: String? = nil, attrSections: [TKAttributesSection] = []) {
        self.identifier = identifier
        self.userCustomTitle = userCustomTitle
        self.attrSections = attrSections
    }

    public var title: String { userCustomTitle ?? identifier }
}
