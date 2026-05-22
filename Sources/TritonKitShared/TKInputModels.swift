import Foundation

public enum TKInputType: String, Codable, CaseIterable {
    case tap
    case swipe
    case button
    case typeText = "type"
    case paste
    case clear
}

public enum TKTapActivationStrategy: String, Codable, CaseIterable {
    case smart
    case exact
    case ancestor
}

public struct TKInputRequest: Codable, Equatable {
    public let type: TKInputType
    public let targetOID: UInt?
    public let matchedOID: UInt?
    public let matchedClassName: String?
    public let activationStrategy: TKTapActivationStrategy?
    public let x: Double?
    public let y: Double?
    public let startX: Double?
    public let startY: Double?
    public let endX: Double?
    public let endY: Double?
    public let width: Double?
    public let height: Double?
    public let duration: Double?
    public let text: String?
    public let button: String?
    public let secure: Bool?

    public init(
        type: TKInputType,
        targetOID: UInt? = nil,
        matchedOID: UInt? = nil,
        matchedClassName: String? = nil,
        activationStrategy: TKTapActivationStrategy? = nil,
        x: Double? = nil,
        y: Double? = nil,
        startX: Double? = nil,
        startY: Double? = nil,
        endX: Double? = nil,
        endY: Double? = nil,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil,
        text: String? = nil,
        button: String? = nil,
        secure: Bool? = nil
    ) {
        self.type = type
        self.targetOID = targetOID
        self.matchedOID = matchedOID
        self.matchedClassName = matchedClassName
        self.activationStrategy = activationStrategy
        self.x = x
        self.y = y
        self.startX = startX
        self.startY = startY
        self.endX = endX
        self.endY = endY
        self.width = width
        self.height = height
        self.duration = duration
        self.text = text
        self.button = button
        self.secure = secure
    }

    public static func tap(
        x: Double? = nil,
        y: Double? = nil,
        targetOID: UInt? = nil,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil,
        matchedOID: UInt? = nil,
        matchedClassName: String? = nil,
        activationStrategy: TKTapActivationStrategy? = nil
    ) -> TKInputRequest {
        TKInputRequest(
            type: .tap,
            targetOID: targetOID,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationStrategy: activationStrategy,
            x: x,
            y: y,
            width: width,
            height: height,
            duration: duration
        )
    }

    public static func swipe(
        startX: Double,
        startY: Double,
        endX: Double,
        endY: Double,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil
    ) -> TKInputRequest {
        TKInputRequest(
            type: .swipe,
            startX: startX,
            startY: startY,
            endX: endX,
            endY: endY,
            width: width,
            height: height,
            duration: duration
        )
    }

    public static func press(button: String, duration: Double? = nil) -> TKInputRequest {
        TKInputRequest(type: .button, duration: duration, button: button)
    }

    public static func typeText(_ text: String, targetOID: UInt? = nil) -> TKInputRequest {
        TKInputRequest(type: .typeText, targetOID: targetOID, text: text)
    }

    public static func paste(
        _ text: String,
        targetOID: UInt? = nil,
        x: Double? = nil,
        y: Double? = nil,
        secure: Bool = false
    ) -> TKInputRequest {
        TKInputRequest(type: .paste, targetOID: targetOID, x: x, y: y, text: text, secure: secure)
    }

    public static func clear(targetOID: UInt? = nil, x: Double? = nil, y: Double? = nil) -> TKInputRequest {
        TKInputRequest(type: .clear, targetOID: targetOID, x: x, y: y)
    }
}

public struct TKInputResult: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let message: String?
    public let targetOID: UInt?
    public let targetClassName: String?
    public let matchedOID: UInt?
    public let matchedClassName: String?
    public let activationOID: UInt?
    public let activationClassName: String?
    public let strategy: String?
    public let secure: Bool?
    public let redacted: Bool?
    public let insertedLength: Int?

    public init(
        ok: Bool,
        action: String,
        message: String? = nil,
        targetOID: UInt? = nil,
        targetClassName: String? = nil,
        matchedOID: UInt? = nil,
        matchedClassName: String? = nil,
        activationOID: UInt? = nil,
        activationClassName: String? = nil,
        strategy: String? = nil,
        secure: Bool? = nil,
        redacted: Bool? = nil,
        insertedLength: Int? = nil
    ) {
        self.ok = ok
        self.action = action
        self.message = message
        self.targetOID = targetOID
        self.targetClassName = targetClassName
        self.matchedOID = matchedOID
        self.matchedClassName = matchedClassName
        self.activationOID = activationOID
        self.activationClassName = activationClassName
        self.strategy = strategy
        self.secure = secure
        self.redacted = redacted
        self.insertedLength = insertedLength
    }

    public static func success(
        action: String,
        message: String? = nil,
        targetOID: UInt? = nil,
        targetClassName: String? = nil,
        matchedOID: UInt? = nil,
        matchedClassName: String? = nil,
        activationOID: UInt? = nil,
        activationClassName: String? = nil,
        strategy: String? = nil,
        secure: Bool? = nil,
        redacted: Bool? = nil,
        insertedLength: Int? = nil
    ) -> TKInputResult {
        TKInputResult(
            ok: true,
            action: action,
            message: message,
            targetOID: targetOID,
            targetClassName: targetClassName,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy,
            secure: secure,
            redacted: redacted,
            insertedLength: insertedLength
        )
    }

    public static func failure(
        action: String,
        message: String,
        targetOID: UInt? = nil,
        targetClassName: String? = nil,
        matchedOID: UInt? = nil,
        matchedClassName: String? = nil,
        activationOID: UInt? = nil,
        activationClassName: String? = nil,
        strategy: String? = nil
    ) -> TKInputResult {
        TKInputResult(
            ok: false,
            action: action,
            message: message,
            targetOID: targetOID,
            targetClassName: targetClassName,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }

    public static func unsupported(
        action: String,
        message: String,
        strategy: String? = nil,
        matchedOID: UInt? = nil,
        matchedClassName: String? = nil,
        activationOID: UInt? = nil,
        activationClassName: String? = nil
    ) -> TKInputResult {
        failure(
            action: action,
            message: message,
            targetOID: activationOID,
            targetClassName: activationClassName,
            matchedOID: matchedOID,
            matchedClassName: matchedClassName,
            activationOID: activationOID,
            activationClassName: activationClassName,
            strategy: strategy
        )
    }
}
