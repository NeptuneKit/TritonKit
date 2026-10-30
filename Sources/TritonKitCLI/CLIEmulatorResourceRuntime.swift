import Foundation

struct EmulatorResourceFailure: Codable { let code: String; let message: String }

struct EmulatorResourceOutput: Encodable {
    var ok = true
    let action: String
    let platform: EmulatorResourcePlatform
    var identity: EmulatorResourceIdentity?
    var features: [EmulatorResourceFeature]?
    var profiles: [String]?
    var states: [EmulatorResourceState]?
    var receipt: EmulatorResourceReceipt?
    var memory: EmulatorResourceGuestMemory?
    var hostMemory: EmulatorResourceHostMemory?
    var partial = false
    var error: EmulatorResourceFailure?
    let businessVerified = false
    let hostSavingsVerified = false
    static func failure(action: String, platform: EmulatorResourcePlatform, error: EmulatorResourceError) -> Self {
        var result = Self(action: action, platform: platform)
        result.ok = false; result.error = .init(code: error.code, message: error.message)
        return result
    }
}

struct EmulatorResourceEngine {
    func selected(platform: EmulatorResourcePlatform, profile: String, disable: String?, keep: String?) throws -> [EmulatorResourceItem] {
        guard ["stock", "ui-minimal", "custom"].contains(profile) else { throw EmulatorResourceError("resource_invalid_profile", "Use stock, ui-minimal, or custom") }
        let features = EmulatorResourceCatalog.features(platform), valid = Set(features.map(\.id))
        func ids(_ value: String?) throws -> Set<String> {
            guard let value else { return [] }
            let values = value.components(separatedBy: ",")
            guard !values.isEmpty, values.allSatisfy({ valid.contains($0) }), Set(values).count == values.count else {
                throw EmulatorResourceError("resource_invalid_feature", "Features must be unique catalog IDs separated by commas")
            }
            return Set(values)
        }
        let requested = try ids(disable), retained = try ids(keep)
        var selection = profile == "ui-minimal" ? Set(features.filter(\.defaultProfile).map(\.id)) : []
        selection.formUnion(requested); selection.subtract(retained)
        guard profile != "custom" || !selection.isEmpty else { throw EmulatorResourceError("resource_invalid_feature", "Custom profile requires at least one disabled feature") }
        return features.filter { selection.contains($0.id) }.flatMap(\.items)
    }
    func plan(adapter: EmulatorResourceAdapter, platform: EmulatorResourcePlatform, profile: String, disable: String?, keep: String?) throws -> EmulatorResourceOutput {
        let items = try selected(platform: platform, profile: profile, disable: disable, keep: keep)
        let identity = try adapter.identity()
        guard identity.platform == platform else { throw EmulatorResourceError("resource_identity_mismatch", "Platform identity does not match") }
        var result = EmulatorResourceOutput(action: "plan", platform: platform)
        result.identity = identity
        result.features = EmulatorResourceCatalog.features(platform).filter { feature in items.contains { $0.feature == feature.id } }
        result.states = try items.map { try adapter.read($0) }
        result.partial = result.states!.contains { !$0.available || $0.value == nil }
        return result
    }
    func apply(adapter: EmulatorResourceAdapter, platform: EmulatorResourcePlatform, profile: String, disable: String?, keep: String?, receiptPath: String, confirm: Bool) throws -> EmulatorResourceOutput {
        guard confirm else { throw EmulatorResourceError("resource_confirmation_required", "Review plan and pass --confirm") }
        let plan = try plan(adapter: adapter, platform: platform, profile: profile, disable: disable, keep: keep)
        guard let identity = plan.identity, let states = plan.states, !plan.partial, identity.bootID != "unavailable" else { throw EmulatorResourceError("resource_state_unavailable", "All selected states, boot identity and control permissions must be available before apply") }
        let lock = try EmulatorResourceLock(identity: identity)
        defer { withExtendedLifetime(lock) {} }
        // Re-read after acquiring the cross-invocation lock.
        try sameBoot(adapter, identity)
        for state in states {
            guard try adapter.read(state.item) == state else { throw EmulatorResourceError("resource_state_conflict", "State changed after planning; review a fresh plan") }
        }
        var receipt = EmulatorResourceReceipt(version: 1, id: UUID().uuidString, identity: identity, createdAt: Date(), entries: states.compactMap { state in
            guard let value = state.value, value != state.item.disabledValue else { return nil }
            return .init(item: state.item, previous: value, applied: state.item.disabledValue, phase: "pending")
        })
        try EmulatorResourceStore.write(receipt, path: receiptPath, create: true)
        do {
            for index in receipt.entries.indices {
                // Record the whole dependency group before its first mutation (audio_server stops audio_host).
                let feature = receipt.entries[index].item.feature
                for related in receipt.entries.indices where receipt.entries[related].item.feature == feature && receipt.entries[related].phase == "pending" {
                    receipt.entries[related].phase = "intent"
                }
                try EmulatorResourceStore.write(receipt, path: receiptPath)
                try sameBoot(adapter, identity)
                let entry = receipt.entries[index], current = try adapter.read(entry.item)
                guard current.available, current.value == entry.previous || current.value == entry.applied else { throw EmulatorResourceError("resource_state_conflict", "State changed during apply") }
                if current.value != entry.applied { try adapter.write(entry.item, value: entry.applied) }
                try verifyState(adapter, entry.item, expected: entry.applied, identity: identity)
                receipt.entries[index].phase = "applied"
                try EmulatorResourceStore.write(receipt, path: receiptPath)
            }
            var result = EmulatorResourceOutput(action: "apply", platform: platform)
            result.identity = identity; result.receipt = receipt
            return result
        } catch {
            var result = EmulatorResourceOutput.failure(action: "apply", platform: platform, error: normalized(error))
            result.partial = true; result.identity = identity; result.receipt = receipt
            return result
        }
    }
    func restore(adapter: EmulatorResourceAdapter, platform: EmulatorResourcePlatform, receiptPath: String, confirm: Bool) throws -> EmulatorResourceOutput {
        guard confirm else { throw EmulatorResourceError("resource_confirmation_required", "Review receipt and pass --confirm") }
        var receipt = try EmulatorResourceStore.read(receiptPath)
        guard receipt.identity.platform == platform else { throw EmulatorResourceError("resource_identity_mismatch", "Receipt platform does not match") }
        let identity = try adapter.identity()
        try matchReceipt(receipt, identity)
        guard identity.bootID != "unavailable" else { throw EmulatorResourceError("resource_identity_unavailable", "A verified boot identity is required to restore") }
        let lock = try EmulatorResourceLock(identity: identity)
        defer { withExtendedLifetime(lock) {} }
        var failure: EmulatorResourceError?
        // Dependencies restore in reverse order: host before audio server.
        for index in receipt.entries.indices.reversed() {
            let entry = receipt.entries[index]
            guard ["intent", "applied", "conflict"].contains(entry.phase) else { continue }
            do {
                try sameBoot(adapter, identity)
                let current = try adapter.read(entry.item)
                guard current.available, let value = current.value else { throw EmulatorResourceError("resource_state_unavailable", "Cannot read current state for restore") }
                if value == entry.previous { receipt.entries[index].phase = "restored" }
                else if value == entry.applied {
                    try adapter.write(entry.item, value: entry.previous)
                    try verifyState(adapter, entry.item, expected: entry.previous, identity: identity)
                    receipt.entries[index].phase = "restored"
                } else {
                    receipt.entries[index].phase = "conflict"
                    failure = EmulatorResourceError("resource_state_conflict", "A later state change was preserved; inspect receipt")
                }
                try EmulatorResourceStore.write(receipt, path: receiptPath)
            } catch { failure = normalized(error); break }
        }
        var result = failure.map { EmulatorResourceOutput.failure(action: "restore", platform: platform, error: $0) } ?? EmulatorResourceOutput(action: "restore", platform: platform)
        result.identity = identity; result.receipt = receipt; result.partial = failure != nil
        return result
    }
    func verify(adapter: EmulatorResourceAdapter, platform: EmulatorResourcePlatform, receiptPath: String) throws -> EmulatorResourceOutput {
        let receipt = try EmulatorResourceStore.read(receiptPath)
        guard receipt.identity.platform == platform else { throw EmulatorResourceError("resource_identity_mismatch", "Receipt platform does not match") }
        let identity = try adapter.identity(); try matchReceipt(receipt, identity)
        var result = EmulatorResourceOutput(action: "verify", platform: platform)
        result.identity = identity; result.receipt = receipt
        result.states = try receipt.entries.map { try adapter.read($0.item) }
        let matches = zip(receipt.entries, result.states!).allSatisfy { entry, state in
            state.available && state.value == (["restored", "pending"].contains(entry.phase) ? entry.previous : entry.applied)
        }
        let complete = receipt.entries.allSatisfy { ["applied", "restored"].contains($0.phase) }
        if !matches || !complete { result.ok = false; result.partial = true; result.error = .init(code: "resource_verification_failed", message: "Receipt has unfinished transitions or one or more states did not match") }
        try sameBoot(adapter, identity)
        return result
    }
    private func verifyState(_ adapter: EmulatorResourceAdapter, _ item: EmulatorResourceItem, expected: String, identity: EmulatorResourceIdentity) throws {
        for attempt in 0..<10 {
            try sameBoot(adapter, identity)
            let state = try adapter.read(item)
            if state.available && state.value == expected { return }
            if attempt < 9 { Thread.sleep(forTimeInterval: 0.2) }
        }
        throw EmulatorResourceError("resource_verification_failed", "State did not settle after the command; use receipt to inspect or restore")
    }
    private func sameBoot(_ adapter: EmulatorResourceAdapter, _ expected: EmulatorResourceIdentity) throws {
        guard try adapter.identity() == expected else { throw EmulatorResourceError("resource_identity_mismatch", "Target or boot identity changed; no further mutations were attempted") }
    }
    private func matchReceipt(_ receipt: EmulatorResourceReceipt, _ current: EmulatorResourceIdentity) throws {
        let saved = receipt.identity
        guard saved.platform == current.platform, saved.target == current.target, saved.instance == current.instance, saved.image == current.image,
              saved.platform == .android || saved.bootID == current.bootID else { throw EmulatorResourceError("resource_identity_mismatch", "Receipt belongs to a different instance, image, or Harmony boot") }
    }
    private func normalized(_ error: Error) -> EmulatorResourceError {
        (error as? EmulatorResourceError) ?? EmulatorResourceError("resource_command_failed", "Resource operation failed; inspect the durable receipt before retrying")
    }
}
