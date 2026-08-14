import Foundation

public enum TKUIAssertCondition: String, Codable, CaseIterable {
    case textExists = "text-exists"
    case textNotExists = "text-not-exists"
}

public struct TKUIAssertRequest: Codable, Equatable {
    public let condition: TKUIAssertCondition
    public let query: String
    public let role: String?
    public let count: Int?
    public let minCount: Int?
    public let maxCount: Int?
    public let within: TKRect?

    public init(
        condition: TKUIAssertCondition,
        query: String,
        role: String? = nil,
        count: Int? = nil,
        minCount: Int? = nil,
        maxCount: Int? = nil,
        within: TKRect? = nil
    ) {
        self.condition = condition
        self.query = query
        self.role = role
        self.count = count
        self.minCount = minCount
        self.maxCount = maxCount
        self.within = within
    }
}

public struct TKUIAssertResult: Codable, Equatable {
    public let ok: Bool
    public let condition: String
    public let query: String
    public let role: String?
    public let count: Int
    public let expectedCount: Int?
    public let minCount: Int?
    public let maxCount: Int?
    public let within: TKRect?
    public let matches: [TKWaitMatch]
    public let sample: [String]
    public let targetConnectionState: String?
    public let hierarchyCacheState: String?
    public let message: String?
    public let nearestText: [String]?
    public let suggestedCommands: [String]?

    public init(
        ok: Bool,
        condition: String,
        query: String,
        role: String? = nil,
        count: Int,
        expectedCount: Int? = nil,
        minCount: Int? = nil,
        maxCount: Int? = nil,
        within: TKRect? = nil,
        matches: [TKWaitMatch],
        sample: [String],
        targetConnectionState: String? = nil,
        hierarchyCacheState: String? = nil,
        message: String? = nil,
        nearestText: [String]? = nil,
        suggestedCommands: [String]? = nil
    ) {
        self.ok = ok
        self.condition = condition
        self.query = query
        self.role = role
        self.count = count
        self.expectedCount = expectedCount
        self.minCount = minCount
        self.maxCount = maxCount
        self.within = within
        self.matches = matches
        self.sample = sample
        self.targetConnectionState = targetConnectionState
        self.hierarchyCacheState = hierarchyCacheState
        self.message = message
        self.nearestText = nearestText
        self.suggestedCommands = suggestedCommands
    }
}

public func TKUIAssertEvaluate(
    _ request: TKUIAssertRequest,
    nodes: [TKAXNode],
    targetConnectionState: String? = nil,
    hierarchyCacheState: String? = nil
) -> TKUIAssertResult {
    let normalizedRole = request.role?.lowercased()
    let matches = TKWaitVisibleTexts(from: nodes).filter { match in
        let roleMatches = normalizedRole.map { match.role?.lowercased() == $0 } ?? true
        let textMatches = TKTextMatches(match.text, query: request.query)
        let boundsMatch = request.within.map { within in
            guard let frame = match.frame else { return false }
            return TKRectIntersects(frame, within)
        } ?? true
        return roleMatches && textMatches && boundsMatch
    }
    let count = matches.count
    let ok: Bool
    if let expected = request.count {
        ok = count == expected
    } else if let minCount = request.minCount, count < minCount {
        ok = false
    } else if let maxCount = request.maxCount, count > maxCount {
        ok = false
    } else {
        switch request.condition {
        case .textExists:
            ok = count > 0
        case .textNotExists:
            ok = count == 0
        }
    }

    return TKUIAssertResult(
        ok: ok,
        condition: request.condition.rawValue,
        query: request.query,
        role: request.role,
        count: count,
        expectedCount: request.count,
        minCount: request.minCount,
        maxCount: request.maxCount,
        within: request.within,
        matches: matches,
        sample: TKWaitTextSample(from: nodes),
        targetConnectionState: targetConnectionState,
        hierarchyCacheState: hierarchyCacheState,
        message: ok ? nil : TKUIAssertFailureMessage(request: request, count: count),
        nearestText: ok ? nil : TKWaitTextSample(from: nodes, limit: 5),
        suggestedCommands: ok ? nil : TKUIAssertSuggestedCommands(request: request)
    )
}

public func TKRectIntersects(_ lhs: TKRect, _ rhs: TKRect) -> Bool {
    lhs.x < rhs.x + rhs.width
        && lhs.x + lhs.width > rhs.x
        && lhs.y < rhs.y + rhs.height
        && lhs.y + lhs.height > rhs.y
}

public func TKUIAssertFailureMessage(request: TKUIAssertRequest, count: Int) -> String {
    if let expected = request.count {
        return "Expected \(expected) match(es) for \(request.query), found \(count)"
    }
    if let minCount = request.minCount, count < minCount {
        return "Expected at least \(minCount) match(es) for \(request.query), found \(count)"
    }
    if let maxCount = request.maxCount, count > maxCount {
        return "Expected at most \(maxCount) match(es) for \(request.query), found \(count)"
    }
    switch request.condition {
    case .textExists:
        return "Expected text to exist: \(request.query)"
    case .textNotExists:
        return "Expected text not to exist: \(request.query), found \(count) match(es)"
    }
}

public func TKUIAssertSuggestedCommands(request: TKUIAssertRequest) -> [String] {
    var commands = ["triton act find \(shellQuoted(request.query)) --all --json", "triton screenshot --json"]
    if let role = request.role {
        commands[0] += " --role \(shellQuoted(role))"
    }
    if let within = request.within {
        commands[0] += " --within \(shellRect(within))"
    }
    return commands
}

private func shellQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

private func shellRect(_ rect: TKRect) -> String {
    "\(rect.x),\(rect.y),\(rect.width),\(rect.height)"
}
