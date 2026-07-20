import Foundation
import TritonKitShared

func iosHostWaitSelectionRequest(target: String) -> HostDeviceSelectionRequest {
    HostDeviceSelectionRequest(
        device: target == TKLocalTargetID ? nil : target,
        platform: .ios,
        scope: .simulator,
        ready: true
    )
}

func waitForIOSHostText(
    selected: HostDeviceTarget,
    text: String,
    role: String?,
    timeout: Double,
    interval: Double,
    gone: Bool = false,
    observe: (_ target: String) throws -> ObserveOutput = { target in
        try observeIOSHostAX(action: "observe.tree", target: target, maxNodes: nil)
    }
) async throws -> HostIOSWaitOutput {
    let startedAt = Date()
    let deadline = startedAt.addingTimeInterval(timeout)
    var pollCount = 0
    var lastMatch: ObserveNodeOutput?
    var sourceCommands: [String] = []

    func response(matched: Bool, timedOut: Bool) -> HostIOSWaitOutput {
        HostIOSWaitOutput(
            ok: matched,
            action: "wait",
            platform: "ios",
            target: selected,
            condition: gone ? "gone" : "text",
            query: text,
            role: role,
            matched: matched,
            timedOut: timedOut,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            pollCount: pollCount,
            match: lastMatch,
            sourceCommands: sourceCommands
        )
    }

    while true {
        pollCount += 1
        let output = try observe(selected.target)
        sourceCommands.append(contentsOf: output.sourceCommands)
        lastMatch = output.nodes.first { node in
            iosHostWaitNodeMatches(node, text: text, role: role)
        }
        let matched = gone ? lastMatch == nil : lastMatch != nil
        if matched {
            return response(matched: true, timedOut: false)
        }
        if Date() >= deadline {
            return response(matched: false, timedOut: true)
        }
        let sleepSeconds = max(0.001, min(interval, deadline.timeIntervalSinceNow))
        try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
    }
}

private func iosHostWaitNodeMatches(_ node: ObserveNodeOutput, text: String, role: String?) -> Bool {
    guard node.hidden != true else { return false }
    if let role, !rolesMatch(node.role, role) {
        return false
    }
    let query = foldedHostWaitValue(text)
    return [node.text, node.identifier].compactMap { $0 }.contains {
        foldedHostWaitValue($0).contains(query)
    }
}

private func rolesMatch(_ candidate: String?, _ requested: String) -> Bool {
    guard let candidate else { return false }
    func normalized(_ value: String) -> String {
        let folded = foldedHostWaitValue(value)
        return folded.hasPrefix("ax") ? String(folded.dropFirst(2)) : folded
    }
    return normalized(candidate) == normalized(requested)
}

private func foldedHostWaitValue(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
}
