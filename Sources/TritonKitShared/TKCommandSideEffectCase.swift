import Foundation

/// A declarative refinement of potential effects, never execution permission or
/// evidence of success. Every predicate must be known and match. Otherwise the
/// command's conservative base effect applies. Options use parsed values,
/// including known parser defaults; missing values do not imply false.
public struct TKCommandSideEffectCase: Codable, Equatable {
    public let sourceCommand: String
    /// Positional tokens after sourceCommand, excluding flags and their values.
    public let argumentPrefix: [String]
    public let argumentCount: Int?
    public let optionValues: [String: String]
    public let sideEffect: String
    /// Nil inherits the command requirement; it never silently clears it.
    public let requiresConfirmation: Bool?

    public init(sourceCommand: String, argumentPrefix: [String] = [], argumentCount: Int? = nil,
                optionValues: [String: String] = [:], sideEffect: String,
                requiresConfirmation: Bool? = nil) {
        self.sourceCommand = sourceCommand
        self.argumentPrefix = argumentPrefix
        self.argumentCount = argumentCount
        self.optionValues = optionValues
        self.sideEffect = sideEffect
        self.requiresConfirmation = requiresConfirmation
    }
}
