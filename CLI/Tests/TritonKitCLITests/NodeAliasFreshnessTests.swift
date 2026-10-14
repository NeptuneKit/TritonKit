import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Node alias freshness")
struct NodeAliasFreshnessTests {
    private let instant = Date(timeIntervalSince1970: 1_800_000_000)

    // Given a cached alias, current collection must run and return current geometry.
    @Test func freshAliasReobservesAndUsesNewFrame() async throws {
        let cached = observation(nodes: [node(frameX: 1)])
        let live = observation(nodes: [node(frameX: 80)])
        try await withCache(cached) { workspace in
            var calls = 0
            let resolved = try await resolveNodeAlias("@1", platform: "ios", target: "sim:ABC", workspace: workspace, now: { instant }) {
                calls += 1
                return live
            }
            #expect(calls == 1)
            #expect(resolved.node.frame?.x == 80)
            #expect(resolved.sourceCommands == live.sourceCommands)
        }
    }

    // Given a page change, replacement object, disappearing node, or duplicate,
    // Then refuse resolution even when the old label is still visible.
    @Test func changedPageNewObjectMissingAndAmbiguousNodesFailClosed() async throws {
        let original = observation(nodes: [node(), node(id: "page", text: "Settings")])
        let changes = [
            observation(nodes: [node(), node(id: "page", text: "Checkout")]),
            observation(nodes: [node(id: "new-oid"), node(id: "page", text: "Settings")]),
            observation(nodes: [node(id: "page", text: "Settings")]),
            observation(nodes: [node(), node(), node(id: "page", text: "Settings")]),
        ]
        try await withCache(original) { workspace in
            for live in changes {
                await #expect(throws: NodeAliasResolutionError.self) {
                    _ = try await resolveNodeAlias("@1", platform: "ios", target: "ABC", workspace: workspace, now: { instant }) { live }
                }
            }
        }
    }

    // Given expired/future/invalid timestamps or another requested platform/target,
    // Then refuse before invoking the current UI provider.
    @Test func invalidCacheNeverCallsProvider() async throws {
        let timestamps = [instant.addingTimeInterval(-31), instant.addingTimeInterval(1)]
        for date in timestamps {
            try await withCache(observation(nodes: [node()], date: date)) { workspace in
                var calls = 0
                await #expect(throws: NodeAliasResolutionError.self) {
                    _ = try await resolveNodeAlias("@1", platform: "ios", target: "ABC", workspace: workspace, now: { instant }) {
                        calls += 1
                        return observation(nodes: [node()])
                    }
                }
                #expect(calls == 0)
            }
        }
        try await withCache(observation(nodes: [node()])) { workspace in
            for (platform, target) in [("android", "ABC"), ("ios", "DEF")] {
                var calls = 0
                await #expect(throws: NodeAliasResolutionError.self) {
                    _ = try await resolveNodeAlias("@1", platform: platform, target: target, workspace: workspace, now: { instant }) {
                        calls += 1
                        return observation(nodes: [node()])
                    }
                }
                #expect(calls == 0)
            }
        }
    }

    // Given legacy schema 1, Then clearly require a fresh outline and never reuse
    // its coordinates. Old cache JSON remains decodable for a useful error.
    @Test func legacyCacheReturnsRefreshHint() async throws {
        let cache = NodeAliasCache(schemaVersion: 1, platform: "ios", target: "sim:ABC", capturedAt: ISO8601DateFormatter().string(from: instant), primarySourceName: "runtime-tree", sourceCommands: [], aliases: [ObserveNodeAliasOutput(alias: "@1", node: node())])
        let workspace = temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        _ = try saveNodeAliasCache(cache, workspace: workspace.path)
        do {
            _ = try await resolveNodeAlias("@1", platform: "ios", target: "ABC", workspace: workspace.path, now: { instant }) {
                Issue.record("Legacy cache must fail before UI collection")
                return observation(nodes: [node()])
            }
            Issue.record("Expected stale alias failure")
        } catch let error as NodeAliasResolutionError {
            #expect(error.code == "stale_node_alias")
            #expect(error.message.contains("schema"))
            #expect(error.detail().nextAction?.command == "observe")
        }
    }

    @Test func localSelectorChecksActualLiveTargetAndSource() async throws {
        try await withCache(observation(nodes: [node()])) { workspace in
            let resolved = try await resolveNodeAlias("@1", platform: "ios", target: TKLocalTargetID, workspace: workspace, now: { instant }) { observation(nodes: [node()]) }
            #expect(resolved.node.nodeID == "oid:1")
            for live in [observation(nodes: [node()], target: "sim:DEF"), observation(nodes: [node()], source: "host-layout")] {
                await #expect(throws: NodeAliasResolutionError.self) {
                    _ = try await resolveNodeAlias("@1", platform: "ios", target: TKLocalTargetID, workspace: workspace, now: { instant }) { live }
                }
            }
        }
    }

    @Test func unchangedButDuplicateIdentityIsStillRejected() async throws {
        let duplicate = observation(nodes: [node(), node()])
        try await withCache(duplicate) { workspace in
            await #expect(throws: NodeAliasResolutionError.self) {
                _ = try await resolveNodeAlias("@1", platform: "ios", target: "ABC", workspace: workspace, now: { instant }) { duplicate }
            }
        }
    }

    @Test func malformedCacheAndInvalidTimestampGiveStructuredRefreshErrors() async throws {
        let workspace = temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        var cache = makeNodeAliasCache(from: observation(nodes: [node()]), outline: makeObserveNodeOutline(from: [node()]))
        cache = NodeAliasCache(platform: cache.platform, target: cache.target, capturedAt: "not-a-date", primarySourceName: cache.primarySourceName, sourceCommands: cache.sourceCommands, aliases: cache.aliases, observationFingerprint: cache.observationFingerprint)
        let path = try saveNodeAliasCache(cache, workspace: workspace.path)
        await #expect(throws: NodeAliasResolutionError.self) {
            _ = try await resolveNodeAlias("@1", platform: "ios", target: "ABC", workspace: workspace.path, now: { instant }) {
                Issue.record("Invalid timestamp must fail before provider collection")
                return observation(nodes: [node()])
            }
        }
        try Data("malformed".utf8).write(to: URL(fileURLWithPath: path))
        await #expect(throws: NodeAliasResolutionError.self) {
            _ = try await resolveNodeAlias("@1", platform: "ios", target: "ABC", workspace: workspace.path, now: { instant }) { observation(nodes: [node()]) }
        }
    }

    @Test func slowObservationCannotExtendCacheLifetime() async throws {
        try await withCache(observation(nodes: [node()])) { workspace in
            var clock = instant
            await #expect(throws: NodeAliasResolutionError.self) {
                _ = try await resolveNodeAlias("@1", platform: "ios", target: "ABC", workspace: workspace, now: { clock }) {
                    clock = instant.addingTimeInterval(31)
                    return observation(nodes: [node()], date: clock)
                }
            }
        }
    }

    @Test func traversalLimitPreventsAliasValidation() async throws {
        let original = observation(nodes: [node()])
        let limited = ObserveOutput(ok: true, action: original.action, platform: original.platform, capturedAt: original.capturedAt, partial: true, target: original.target, sources: original.sources, nodes: original.nodes, collection: TKCollectionBudgetSummary(visitedNodes: 1, limitReasons: ["max_nodes"]), artifacts: [], sourceCommands: original.sourceCommands, note: "limited fixture")
        try await withCache(original) { workspace in
            await #expect(throws: NodeAliasResolutionError.self) {
                _ = try await resolveNodeAlias("@1", platform: "ios", target: "ABC", workspace: workspace, now: { instant }) { limited }
            }
        }
    }

    @Test func cacheFingerprintSurvivesJSONRoundTripAndIgnoresOnlyGeometry() throws {
        let original = observation(nodes: [node()])
        let cache = makeNodeAliasCache(from: original, outline: makeObserveNodeOutline(from: original.nodes))
        #expect(cache.schemaVersion == 2)
        #expect(cache.observationFingerprint != nil)
        #expect(try JSONDecoder().decode(NodeAliasCache.self, from: JSONEncoder().encode(cache)) == cache)
        #expect(nodeAliasObservationFingerprint(original) == nodeAliasObservationFingerprint(observation(nodes: [node(frameX: 100)])))
        #expect(nodeAliasObservationFingerprint(original) != nodeAliasObservationFingerprint(observation(nodes: [node(text: "Cancel")])))
    }

    private func temporaryWorkspace() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("triton-alias-freshness-\(UUID().uuidString)", isDirectory: true)
    }

    private func withCache(_ output: ObserveOutput, body: (String) async throws -> Void) async throws {
        let workspace = temporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        _ = try saveNodeAliasCache(makeNodeAliasCache(from: output, outline: makeObserveNodeOutline(from: output.nodes)), workspace: workspace.path)
        try await body(workspace.path)
    }

    private func observation(nodes: [ObserveNodeOutput], date: Date? = nil, target: String = "sim:ABC", source: String = "runtime-tree") -> ObserveOutput {
        ObserveOutput(ok: true, action: "observe.tree", platform: "ios", capturedAt: ISO8601DateFormatter().string(from: date ?? instant), partial: true, target: target, sources: [ObserveSourceOutput(name: source, available: true, reason: nil, artifact: nil, sourceCommands: ["live observation"])], nodes: nodes, artifacts: [], sourceCommands: ["live observation"], note: "fixture")
    }

    private func node(id: String = "oid:1", text: String = "Continue", frameX: Double = 1) -> ObserveNodeOutput {
        ObserveNodeOutput(nodeID: id, source: "runtime-tree", role: "AXButton", text: text, identifier: "continue", frame: TKRect(x: frameX, y: 2, width: 30, height: 20), enabled: true, focused: false, hidden: false, candidateOnly: false, confidence: 0.9, capabilities: ["tap", "runtime-oid"], missingCapabilities: [])
    }
}
