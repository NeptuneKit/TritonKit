import Foundation

/// Matching semantics shared by every Triton text-query surface.
///
/// - `substring`: the normalized query must appear inside the normalized candidate
///   (used by `wait --text`, `act find`, `verify text-exists`, and host waiters).
/// - `exact`: the normalized candidate must equal the normalized query (used where
///   the contract explicitly promises exact matching, e.g. deterministic test-run
///   `match=exact` selectors).
public enum TKTextMatchMode: String, Codable, Sendable {
    case substring
    case exact
}

/// Single text-normalization rule shared by `observe tree`/`observe current`
/// (which expose trimmed AX text), `wait --text`, and `act find`.
///
/// Rule: trim ASCII whitespace/newlines, then fold case and diacritics with the
/// current locale. This is the same folding the Android and iOS host waiters
/// already apply, so embedded-runtime queries agree with host-side queries.
public func TKNormalizeQueryText(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
}

/// Normalized text matching. Both sides are normalized with
/// `TKNormalizeQueryText`, so leading/trailing whitespace, case, and diacritics
/// never cause an otherwise-visible node to be missed. An empty normalized query
/// never matches.
public func TKTextMatches(
    _ candidate: String,
    query: String,
    mode: TKTextMatchMode = .substring
) -> Bool {
    let normalizedCandidate = TKNormalizeQueryText(candidate)
    let normalizedQuery = TKNormalizeQueryText(query)
    guard !normalizedQuery.isEmpty else { return false }
    switch mode {
    case .substring:
        return normalizedCandidate.contains(normalizedQuery)
    case .exact:
        return normalizedCandidate == normalizedQuery
    }
}

/// The text fields of an AX node that text queries match against, in the same
/// priority order `wait` uses: label, title, value, identifier.
public func TKAXNodeQueryTexts(_ node: TKAXNode, includeValue: Bool = true) -> [String] {
    var texts: [String] = []
    if let label = node.label { texts.append(label) }
    if let title = node.title { texts.append(title) }
    if includeValue, let value = node.value { texts.append(value) }
    if let identifier = node.identifier { texts.append(identifier) }
    return texts
}

/// Whether an AX node's queryable text fields match `query` under the shared
/// normalization. `includeValue: false` restricts matching to label/title/
/// identifier so value-only matches can be ranked after label/title matches.
public func TKAXNodeMatchesText(
    _ node: TKAXNode,
    query: String,
    mode: TKTextMatchMode = .substring,
    includeValue: Bool = true
) -> Bool {
    TKAXNodeQueryTexts(node, includeValue: includeValue).contains {
        TKTextMatches($0, query: query, mode: mode)
    }
}
