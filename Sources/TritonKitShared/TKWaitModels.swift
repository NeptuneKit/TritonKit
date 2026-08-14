import Foundation

public enum TKWaitCondition: String, Codable, CaseIterable {
    case text
    case gone
    case idle
    case predicate
    case exists
    case hierarchyChange = "hierarchy-change"
}

public struct TKWaitMatch: Codable, Equatable {
    public let text: String
    public let role: String?
    public let label: String?
    public let value: String?
    public let identifier: String?
    public let title: String?
    public let frame: TKRect?
    public let targetOID: UInt?
    public let viewOID: UInt?
    public let className: String?
    public let source: String

    public init(
        text: String,
        role: String?,
        label: String?,
        value: String?,
        identifier: String?,
        title: String?,
        frame: TKRect?,
        targetOID: UInt?,
        viewOID: UInt?,
        className: String?,
        source: String
    ) {
        self.text = text
        self.role = role
        self.label = label
        self.value = value
        self.identifier = identifier
        self.title = title
        self.frame = frame
        self.targetOID = targetOID
        self.viewOID = viewOID
        self.className = className
        self.source = source
    }
}

public struct TKWaitResult: Codable, Equatable {
    public let ok: Bool
    public let matched: Bool
    public let condition: String
    public let query: String?
    public let predicate: String?
    public let role: String?
    public let timedOut: Bool
    public let elapsedMs: Int
    public let pollCount: Int
    public let timeoutSeconds: Double
    public let intervalSeconds: Double
    public let targetConnectionState: String?
    public let hierarchyCacheState: String?
    public let lastObservedNodeCount: Int?
    public let lastObservedTextSample: [String]
    public let lastObservedHierarchyHash: String?
    public let match: TKWaitMatch?

    public init(
        ok: Bool,
        matched: Bool,
        condition: String,
        query: String? = nil,
        predicate: String? = nil,
        role: String? = nil,
        timedOut: Bool,
        elapsedMs: Int,
        pollCount: Int,
        timeoutSeconds: Double,
        intervalSeconds: Double,
        targetConnectionState: String? = nil,
        hierarchyCacheState: String? = nil,
        lastObservedNodeCount: Int? = nil,
        lastObservedTextSample: [String] = [],
        lastObservedHierarchyHash: String? = nil,
        match: TKWaitMatch? = nil
    ) {
        self.ok = ok
        self.matched = matched
        self.condition = condition
        self.query = query
        self.predicate = predicate
        self.role = role
        self.timedOut = timedOut
        self.elapsedMs = elapsedMs
        self.pollCount = pollCount
        self.timeoutSeconds = timeoutSeconds
        self.intervalSeconds = intervalSeconds
        self.targetConnectionState = targetConnectionState
        self.hierarchyCacheState = hierarchyCacheState
        self.lastObservedNodeCount = lastObservedNodeCount
        self.lastObservedTextSample = lastObservedTextSample
        self.lastObservedHierarchyHash = lastObservedHierarchyHash
        self.match = match
    }
}

public struct TKWaitObservation: Equatable {
    public let nodes: [TKAXNode]
    public let targetConnectionState: String?
    public let hierarchyCacheState: String?
    public let hierarchyHash: String?

    public init(
        nodes: [TKAXNode] = [],
        targetConnectionState: String? = nil,
        hierarchyCacheState: String? = nil,
        hierarchyHash: String? = nil
    ) {
        self.nodes = nodes
        self.targetConnectionState = targetConnectionState
        self.hierarchyCacheState = hierarchyCacheState
        self.hierarchyHash = hierarchyHash
    }
}

public func TKWaitVisibleTexts(from nodes: [TKAXNode]) -> [TKWaitMatch] {
    nodes.flatMap { waitVisibleTexts(from: $0, ancestorHidden: false) }
}

public func TKWaitFindTextMatch(
    in nodes: [TKAXNode],
    query: String,
    role: String? = nil
) -> TKWaitMatch? {
    let normalizedRole = role?.lowercased()
    return TKWaitVisibleTexts(from: nodes).first { match in
        let roleMatches = normalizedRole.map { match.role?.lowercased() == $0 } ?? true
        return roleMatches && TKTextMatches(match.text, query: query)
    }
}

public func TKWaitTextSample(from nodes: [TKAXNode], limit: Int = 20) -> [String] {
    var seen = Set<String>()
    var sample: [String] = []
    for match in TKWaitVisibleTexts(from: nodes) {
        guard !seen.contains(match.text) else { continue }
        seen.insert(match.text)
        sample.append(match.text)
        if sample.count >= limit { break }
    }
    return sample
}

public func TKWaitEvaluatePredicate(_ expression: String, nodes: [TKAXNode]) throws -> Bool {
    let parser = TKWaitPredicateParser(expression: expression, nodes: nodes)
    return try parser.parse()
}

private final class TKWaitPredicateParser {
    private enum Token: Equatable {
        case identifier(String)
        case string(String)
        case and
        case or
        case not
        case leftParen
        case rightParen
        case invalid(String)
        case eof
    }

    private let tokens: [Token]
    private let nodes: [TKAXNode]
    private var index = 0

    init(expression: String, nodes: [TKAXNode]) {
        self.tokens = TKWaitPredicateParser.tokenize(expression)
        self.nodes = nodes
    }

    func parse() throws -> Bool {
        let value = try parseOr()
        guard peek() == .eof else {
            throw TKWaitPredicateError("Unexpected token after predicate expression")
        }
        return value
    }

    private func parseOr() throws -> Bool {
        var value = try parseAnd()
        while match(.or) {
            value = try parseAnd() || value
        }
        return value
    }

    private func parseAnd() throws -> Bool {
        var value = try parseUnary()
        while match(.and) {
            value = try parseUnary() && value
        }
        return value
    }

    private func parseUnary() throws -> Bool {
        if match(.not) {
            return try !parseUnary()
        }
        return try parsePrimary()
    }

    private func parsePrimary() throws -> Bool {
        if match(.leftParen) {
            let value = try parseOr()
            guard match(.rightParen) else {
                throw TKWaitPredicateError("Expected ')' in predicate expression")
            }
            return value
        }

        guard case .identifier(let name) = advance() else {
            throw TKWaitPredicateError("Expected predicate function")
        }
        guard match(.leftParen) else {
            throw TKWaitPredicateError("Expected '(' after predicate function")
        }
        guard case .string(let query) = advance() else {
            throw TKWaitPredicateError("Expected quoted text argument")
        }
        guard match(.rightParen) else {
            throw TKWaitPredicateError("Expected ')' after predicate argument")
        }
        return try evaluate(function: name, query: query)
    }

    private func evaluate(function: String, query: String) throws -> Bool {
        switch function {
        case "text.exists", "exists":
            return TKWaitFindTextMatch(in: nodes, query: query) != nil
        case "text.gone", "gone":
            return TKWaitFindTextMatch(in: nodes, query: query) == nil
        default:
            throw TKWaitPredicateError("Unsupported predicate function: \(function)")
        }
    }

    private func peek() -> Token {
        tokens[index]
    }

    private func advance() -> Token {
        let token = tokens[index]
        index += 1
        return token
    }

    private func match(_ token: Token) -> Bool {
        guard peek() == token else { return false }
        index += 1
        return true
    }

    private static func tokenize(_ expression: String) -> [Token] {
        var tokens: [Token] = []
        var i = expression.startIndex
        while i < expression.endIndex {
            let char = expression[i]
            if char.isWhitespace {
                i = expression.index(after: i)
                continue
            }
            if char == "&", expression.index(after: i) < expression.endIndex, expression[expression.index(after: i)] == "&" {
                tokens.append(.and)
                i = expression.index(i, offsetBy: 2)
                continue
            }
            if char == "|", expression.index(after: i) < expression.endIndex, expression[expression.index(after: i)] == "|" {
                tokens.append(.or)
                i = expression.index(i, offsetBy: 2)
                continue
            }
            if char == "!" {
                tokens.append(.not)
                i = expression.index(after: i)
                continue
            }
            if char == "(" {
                tokens.append(.leftParen)
                i = expression.index(after: i)
                continue
            }
            if char == ")" {
                tokens.append(.rightParen)
                i = expression.index(after: i)
                continue
            }
            if char == "\"" {
                let parsed = parseString(expression, start: expression.index(after: i))
                tokens.append(.string(parsed.value))
                i = parsed.next
                continue
            }

            let start = i
            while i < expression.endIndex {
                let current = expression[i]
                if current.isLetter || current.isNumber || current == "." || current == "_" {
                    i = expression.index(after: i)
                } else {
                    break
                }
            }
            if start != i {
                tokens.append(.identifier(String(expression[start..<i])))
            } else {
                tokens.append(.invalid(String(char)))
                i = expression.index(after: i)
            }
        }
        tokens.append(.eof)
        return tokens
    }

    private static func parseString(_ expression: String, start: String.Index) -> (value: String, next: String.Index) {
        var i = start
        var value = ""
        while i < expression.endIndex {
            let char = expression[i]
            if char == "\"" {
                return (value, expression.index(after: i))
            }
            if char == "\\", expression.index(after: i) < expression.endIndex {
                let next = expression[expression.index(after: i)]
                switch next {
                case "\"", "\\":
                    value.append(next)
                case "n":
                    value.append("\n")
                case "t":
                    value.append("\t")
                default:
                    value.append(next)
                }
                i = expression.index(i, offsetBy: 2)
            } else {
                value.append(char)
                i = expression.index(after: i)
            }
        }
        return (value, i)
    }
}

public struct TKWaitPredicateError: Error, Equatable, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

private func waitVisibleTexts(from node: TKAXNode, ancestorHidden: Bool) -> [TKWaitMatch] {
    let hidden = ancestorHidden || node.hidden
    guard !hidden else {
        return []
    }

    var matches: [TKWaitMatch] = []
    for (source, value) in [
        ("label", node.label),
        ("title", node.title),
        ("value", node.value),
        ("identifier", node.identifier),
    ] {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            continue
        }
        matches.append(TKWaitMatch(
            text: text,
            role: node.role,
            label: node.label,
            value: node.value,
            identifier: node.identifier,
            title: node.title,
            frame: node.frame,
            targetOID: node.targetOID,
            viewOID: node.viewOID,
            className: node.className,
            source: source
        ))
    }
    matches.append(contentsOf: node.children.flatMap { waitVisibleTexts(from: $0, ancestorHidden: hidden) })
    return matches
}
