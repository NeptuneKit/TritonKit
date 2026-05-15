import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct TKObject: Codable {
    public let oid: UInt
    public let memoryAddress: String
    public let classChainList: [String]
    public let specialTrace: String
    public let ivarTraces: [TKIvarTrace]

    public init(oid: UInt, memoryAddress: String, classChainList: [String], specialTrace: String = "", ivarTraces: [TKIvarTrace] = []) {
        self.oid = oid
        self.memoryAddress = memoryAddress
        self.classChainList = classChainList
        self.specialTrace = specialTrace
        self.ivarTraces = ivarTraces
    }

    public var rawClassName: String {
        classChainList.first ?? "NSObject"
    }
}

public struct TKIvarTrace: Codable {
    public let ivarName: String
    public let traceClass: String

    public init(ivarName: String, traceClass: String) {
        self.ivarName = ivarName
        self.traceClass = traceClass
    }
}
