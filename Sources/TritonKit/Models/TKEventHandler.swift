import Foundation

public struct TKEventHandler: Codable {
    public let handlerType: TKEventHandlerType
    public let eventName: String
    public let targetActions: [TKStringTwoTuple]
    public let inheritedRecognizerName: String?
    public let gestureRecognizerIsEnabled: Bool
    public let gestureRecognizerDelegator: String?
    public let recognizerIvarTraces: [String]
    public let recognizerOid: UInt64

    public init(handlerType: TKEventHandlerType, eventName: String, targetActions: [TKStringTwoTuple] = [], inheritedRecognizerName: String? = nil, gestureRecognizerIsEnabled: Bool = true, gestureRecognizerDelegator: String? = nil, recognizerIvarTraces: [String] = [], recognizerOid: UInt64 = 0) {
        self.handlerType = handlerType
        self.eventName = eventName
        self.targetActions = targetActions
        self.inheritedRecognizerName = inheritedRecognizerName
        self.gestureRecognizerIsEnabled = gestureRecognizerIsEnabled
        self.gestureRecognizerDelegator = gestureRecognizerDelegator
        self.recognizerIvarTraces = recognizerIvarTraces
        self.recognizerOid = recognizerOid
    }
}

public struct TKStringTwoTuple: Codable {
    public let first: String
    public let second: String

    public init(first: String, second: String) {
        self.first = first
        self.second = second
    }
}
