import Foundation
import TritonKitShared

/// Audited potential effects for the four operation families covered by #247.
/// A newly added operation stays unknown until audited; it is never inferred
/// readonly from a name, missing declaration, failed result, or dry-run wording.
func schemaWithAuditedOperationEffect(_ command: TKCommandSubcommandSchema, root: String) -> TKCommandSubcommandSchema {
    let path = "\(root).\(command.name)"
    guard let effect = auditedOperationEffects[path] else { return command }
    return TKCommandSubcommandSchema(
        name: command.name, summary: command.summary,
        requiresServer: command.requiresServer, requiresTarget: command.requiresTarget,
        requiresConfirmation: ["app.uninstall", "sim.erase"].contains(path) || command.requiresConfirmation,
        sideEffect: effect, sideEffectCases: command.sideEffectCases + auditedEffectCases(path),
        optionOverrides: command.optionOverrides, requiredOptions: command.requiredOptions,
        oneOfRequiredOptions: command.oneOfRequiredOptions, oneOfRequiredOptionSets: command.oneOfRequiredOptionSets,
        optionalOptions: command.optionalOptions, defaultProviders: command.defaultProviders,
        inheritsDefaultsFrom: command.inheritsDefaultsFrom, jsonlEvents: command.jsonlEvents,
        finalEventKind: command.finalEventKind, artifacts: command.artifacts,
        retryable: command.retryable, nextCommands: command.nextCommands,
        recoveryCommands: command.recoveryCommands, outputSelectors: command.outputSelectors,
        failureCodes: command.failureCodes, subcommands: command.subcommands
    )
}

private let auditedOperationEffects: [String: String] = [
    "act.find": "readonly", "act.tap": "input-submission", "act.type": "text-input",
    "act.paste": "text-input", "act.clear": "text-input", "act.swipe": "input-submission",
    "act.press": "input-submission", "act.focus": "ui-mutation", "act.set-text": "text-input",
    "act.select-segment": "ui-mutation", "act.set-switch": "ui-mutation", "act.input": "input-submission",
    "app.list": "readonly", "app.info": "readonly", "app.inspect": "readonly", "app.container": "readonly",
    "app.install": "app-install", "app.uninstall": "app-uninstall", "app.launch": "app-launch",
    "app.terminate": "app-terminate", "app.go": "app-open-url", "app.open-url": "app-open-url",
    "app.pull": "artifact-write", "app.prefs": "preferences-write",
    "sim.pairs": "readonly", "sim.list": "readonly", "sim.ax": "readonly",
    "sim.use": "workspace-settings-write", "sim.create": "simulator-create",
    "sim.boot": "simulator-boot", "sim.shutdown": "simulator-shutdown",
    "sim.screenshot": "artifact-write", "sim.record": "artifact-write", "sim.logs": "artifact-write",
    "sim.app-console": "app-launch-and-artifact-write", "sim.diagnose": "artifact-write",
    "sim.tap": "input-submission", "sim.swipe": "input-submission",
    // Reserved unsupported ASCII entry, not a real text submission (historical #216).
    "sim.type": "none", "sim.logverbose": "simulator-settings-write",
    "sim.proxy": "host-network-and-artifact-write", "sim.pair": "simulator-pairing-write",
    "sim.unpair": "simulator-pairing-write", "sim.clone": "simulator-create",
    "sim.erase": "simulator-data-delete", "sim.upgrade": "simulator-runtime-upgrade",
    "sim.runtime": "runtime-maintenance", "sim.personalization": "runtime-personalization-write",
    "sim.status-bar": "simulator-settings-write", "sim.privacy": "simulator-permission-write",
    "sim.location": "simulated-location-write", "sim.ui": "simulator-settings-write",
    "sim.pasteboard": "pasteboard-write", "sim.push": "notification-submission",
    "sim.media": "simulator-media-write",
    "build.ios": "build-execution-filesystem-write",
    "build.android": "build-execution-filesystem-write",
    "build.harmony": "build-execution-filesystem-write",
]

private func auditedEffectCases(_ path: String) -> [TKCommandSideEffectCase] {
    func mode(_ arguments: [String], _ effect: String, count: Int? = nil,
              options: [String: String] = [:], confirmation: Bool? = nil) -> TKCommandSideEffectCase {
        TKCommandSideEffectCase(sourceCommand: path, argumentPrefix: arguments, argumentCount: count,
                                optionValues: options, sideEffect: effect, requiresConfirmation: confirmation)
    }
    switch path {
    case "app.prefs":
        return [mode(["dump"], "readonly"), mode(["get"], "readonly")]
            + ["set", "import"].map { mode([$0], "preferences-write-and-app-relaunch", options: ["--relaunch": "true"]) }
    case "sim.runtime":
        return [
            mode(["list"], "readonly"), mode(["verify"], "readonly"),
            mode(["match", "list"], "readonly"),
            mode(["delete"], "readonly", options: ["--dry-run": "true"], confirmation: false),
            mode(["delete"], "runtime-delete", options: ["--dry-run": "false"], confirmation: true),
            mode(["dyld-cache", "remove"], "runtime-cache-delete", confirmation: true),
        ]
    case "sim.proxy":
        return [mode(["doctor"], "readonly"), mode(["status"], "readonly")]
            + ["start", "export", "stop"].map { mode([$0], "readonly", options: ["--plan-only": "true"], confirmation: false) }
            + ["start", "stop"].map { mode([$0], "host-network-and-artifact-write", options: ["--plan-only": "false"], confirmation: true) }
    case "sim.personalization":
        return ["remove-manifest", "remove-all-manifests", "remove-personalization", "revoke-manifests"].map {
            mode([$0], "runtime-personalization-write", confirmation: true)
        }
    case "sim.status-bar", "sim.location":
        return [mode(["list"], "readonly")]
    case "sim.ui":
        return ["appearance", "increase-contrast", "content-size"].map { mode([$0], "readonly", count: 1) }
    case "sim.pasteboard":
        return [mode(["get"], "readonly")]
    default:
        return []
    }
}
