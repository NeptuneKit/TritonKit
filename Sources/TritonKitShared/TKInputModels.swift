import Foundation

public enum TKInputType: String, Codable, CaseIterable {
    case tap
    case swipe
    case button
    case typeText = "type"
    case paste
    case clear
}

public struct TKInputRequest: Codable, Equatable {
    public let type: TKInputType
    public let targetOID: UInt?
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
        duration: Double? = nil
    ) -> TKInputRequest {
        TKInputRequest(
            type: .tap,
            targetOID: targetOID,
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
    public let secure: Bool?
    public let redacted: Bool?
    public let insertedLength: Int?

    public init(
        ok: Bool,
        action: String,
        message: String? = nil,
        targetOID: UInt? = nil,
        targetClassName: String? = nil,
        secure: Bool? = nil,
        redacted: Bool? = nil,
        insertedLength: Int? = nil
    ) {
        self.ok = ok
        self.action = action
        self.message = message
        self.targetOID = targetOID
        self.targetClassName = targetClassName
        self.secure = secure
        self.redacted = redacted
        self.insertedLength = insertedLength
    }

    public static func success(
        action: String,
        message: String? = nil,
        targetOID: UInt? = nil,
        targetClassName: String? = nil,
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
            secure: secure,
            redacted: redacted,
            insertedLength: insertedLength
        )
    }

    public static func failure(
        action: String,
        message: String,
        targetOID: UInt? = nil,
        targetClassName: String? = nil
    ) -> TKInputResult {
        TKInputResult(
            ok: false,
            action: action,
            message: message,
            targetOID: targetOID,
            targetClassName: targetClassName
        )
    }

    public static func unsupported(action: String, message: String) -> TKInputResult {
        failure(action: action, message: message)
    }
}
