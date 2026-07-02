import Foundation

public struct TKHostStrongControlCapability: Codable, Equatable {
    public let name: String
    public let platform: String
    public let runtimeScope: String
    public let available: Bool
    public let reason: String?
    public let dependency: String
    public let limitations: [String]
    public let fallbackCapability: String
    public let sourceCommand: String?
    public let nextAction: TKCLINextAction?

    public init(
        name: String,
        platform: String,
        runtimeScope: String,
        available: Bool,
        reason: String? = nil,
        dependency: String,
        limitations: [String],
        fallbackCapability: String,
        sourceCommand: String? = nil,
        nextAction: TKCLINextAction? = nil
    ) {
        self.name = name
        self.platform = platform
        self.runtimeScope = runtimeScope
        self.available = available
        self.reason = reason
        self.dependency = dependency
        self.limitations = limitations
        self.fallbackCapability = fallbackCapability
        self.sourceCommand = sourceCommand
        self.nextAction = nextAction
    }
}
