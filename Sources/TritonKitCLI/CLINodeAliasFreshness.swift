import CryptoKit
import Foundation
import TritonKitShared

/// Alias identity excludes geometry and focus so a layout adjustment can return
/// fresh coordinates. Node IDs and ordered page semantics remain part of it.
/// Index-based host IDs cannot prove lifecycle identity when the entire page is
/// identical after a restart; a real provider generation is needed for that.
private struct NodeAliasIdentity: Encodable, Equatable {
    let nodeID: String
    let source: String
    let role: String?
    let text: String?
    let identifier: String?
    let enabled: Bool?
    let hidden: Bool?
    let candidateOnly: Bool
    let capabilities: [String]
    let missingCapabilities: [String]

    init(_ node: ObserveNodeOutput) {
        nodeID = node.nodeID
        source = node.source
        role = node.role
        text = node.text
        identifier = node.identifier
        enabled = node.enabled
        hidden = node.hidden
        candidateOnly = node.candidateOnly
        capabilities = node.capabilities.sorted()
        missingCapabilities = node.missingCapabilities.sorted()
    }
}

func nodeAliasObservationFingerprint(_ output: ObserveOutput) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    // This value contains only JSON primitives and cannot fail encoding.
    let data = (try? encoder.encode(output.nodes.map(NodeAliasIdentity.init))) ?? Data()
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// Requires a current collection. There is intentionally no cache-only overload.
func resolveNodeAlias(
    _ alias: String,
    platform: String,
    target: String,
    workspace: String,
    now: () -> Date = Date.init,
    observe: () async throws -> ObserveOutput
) async throws -> NodeResolveOutput {
    guard isNodeAliasQuery(alias) else {
        throw NodeAliasResolutionError.invalidAlias(alias)
    }
    let cache: NodeAliasCache
    do {
        cache = try loadNodeAliasCache(workspace: workspace, platform: platform, target: target)
    } catch let error as NodeAliasResolutionError {
        throw error
    } catch {
        throw NodeAliasResolutionError.freshnessRejected(alias: alias, platform: platform, target: target, reason: "cache is unreadable or malformed")
    }
    func reject(_ reason: String) -> NodeAliasResolutionError {
        .freshnessRejected(alias: alias, platform: platform, target: target, reason: reason)
    }
    guard cache.schemaVersion == 2, let fingerprint = cache.observationFingerprint, !fingerprint.isEmpty else {
        throw reject("unsupported cache schema or missing observation fingerprint")
    }
    let unresolvedRuntimeSelector = platform == "ios" && (target == TKLocalTargetID || target == "local")
    guard cache.platform == platform,
          unresolvedRuntimeSelector || nodeAliasTargetMatches(requested: target, cached: cache.target) else {
        throw NodeAliasResolutionError.staleAlias(alias: alias, expectedPlatform: platform, expectedTarget: target, cachedPlatform: cache.platform, cachedTarget: cache.target)
    }
    try validateAliasTimestamp(cache.capturedAt, now: now(), rejection: reject)
    guard let entry = cache.aliases.first(where: { $0.alias == alias }) else {
        throw NodeAliasResolutionError.aliasNotFound(alias: alias, path: NodeAliasCache.filePath(workspace: workspace), platform: platform, target: target, availableAliases: cache.aliases.map(\.alias))
    }

    let current = try await observe()
    // A slow collector does not renew the alias lifetime.
    let currentTime = now()
    try validateAliasTimestamp(cache.capturedAt, now: currentTime, rejection: reject)
    try validateAliasTimestamp(current.capturedAt, now: currentTime, rejection: reject)
    guard current.ok,
          current.platform == cache.platform,
          nodeAliasTargetMatches(requested: current.target, cached: cache.target),
          current.primarySource?.available == true,
          current.primarySource?.name == cache.primarySourceName else {
        throw reject("current observation target or provider changed or is unavailable")
    }
    guard current.collection?.partial != true else {
        throw reject("current collection reached a traversal limit")
    }
    guard nodeAliasObservationFingerprint(current) == fingerprint else {
        throw reject("current page or node identity changed")
    }
    let identity = NodeAliasIdentity(entry.node)
    let candidates = current.nodes.filter { NodeAliasIdentity($0) == identity }
    guard candidates.count == 1, let node = candidates.first, !node.candidateOnly, node.hidden != true else {
        throw reject(candidates.isEmpty ? "node is absent" : "node identity is ambiguous or unavailable")
    }
    return NodeResolveOutput(ok: true, action: "node.resolve", platform: platform, query: alias, matchIndex: Int(alias.dropFirst()) ?? 1, matchCount: cache.aliases.count, node: node, candidates: nil, sourceCommands: current.sourceCommands)
}

private func validateAliasTimestamp(
    _ timestamp: String,
    now: Date,
    rejection: (String) -> NodeAliasResolutionError
) throws {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let fractionalDate = formatter.date(from: timestamp)
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = fractionalDate ?? formatter.date(from: timestamp) else {
        throw rejection("invalid observation timestamp")
    }
    let age = now.timeIntervalSince(date)
    guard age >= 0, age <= 30 else {
        throw rejection(age < 0 ? "observation timestamp is in the future" : "observation is older than the 30 second alias lifetime")
    }
}

func nodeAliasTargetMatches(requested: String, cached: String) -> Bool {
    func split(_ value: String) -> (prefix: String?, id: String) {
        for prefix in ["sim:", "android:", "harmony:"] where value.hasPrefix(prefix) {
            return (prefix, String(value.dropFirst(prefix.count)))
        }
        return (nil, value)
    }
    let requestedID = split(requested)
    let cachedID = split(cached)
    if let requestedPrefix = requestedID.prefix, let cachedPrefix = cachedID.prefix, requestedPrefix != cachedPrefix { return false }
    return requestedID.id == cachedID.id
}
