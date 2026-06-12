import Testing
import TritonKitShared
@testable import TritonKitCLI

func schemaNextCommandFixtures(includeSubcommands: Bool) -> [CommandStringFixture] {
    commandSchemas().flatMap { schema -> [CommandStringFixture] in
        var fixtures: [CommandStringFixture] = []
        for command in schema.nextCommands {
            guard let argv = extractSingleTritonInvocationArgv(from: command) else {
                continue
            }
            fixtures.append(CommandStringFixture(context: schema.name, command: command, argv: argv))
        }
        if includeSubcommands {
            fixtures.append(contentsOf: schema.subcommands.flatMap { subcommand -> [CommandStringFixture] in
                var subcommandFixtures: [CommandStringFixture] = []
                for command in subcommand.nextCommands {
                    guard let argv = extractSingleTritonInvocationArgv(from: command) else {
                        continue
                    }
                    subcommandFixtures.append(CommandStringFixture(
                        context: "\(schema.name) \(subcommand.name)",
                        command: command,
                        argv: argv,
                        isSubcommand: true
                    ))
                }
                return subcommandFixtures
            })
        }
        return fixtures
    }
}

func schemaExampleCommandFixtures() -> [CommandStringFixture] {
    commandSchemas().flatMap { schema in
        schema.examples.compactMap { command -> CommandStringFixture? in
            guard let argv = extractSingleTritonInvocationArgv(from: command) else {
                return nil
            }
            return CommandStringFixture(context: "\(schema.name)/example", command: command, argv: argv)
        }
    }
}

func workflowPlanCommandFixtures(includeTaskInputs: Bool) -> [CommandStringFixture] {
    workflowPlanFixtures(includeTaskInputs: includeTaskInputs).flatMap { plan in
        plan.steps.map {
            CommandStringFixture(
                context: "\(plan.goal ?? "general"):\($0.id)",
                command: $0.command,
                argv: $0.argv
            )
        }
    }
}

func workflowPlanFixtures(includeTaskInputs: Bool) -> [TKWorkflowPlanResponse] {
    let disconnected = TKCapabilitiesResponse(
        ok: false,
        serverReachable: false,
        connected: false,
        latestHierarchyAvailable: false,
        targetCount: 0,
        runtime: "unknown",
        capabilities: []
    )
    let targetMissing = TKCapabilitiesResponse(
        ok: true,
        serverReachable: true,
        connected: false,
        latestHierarchyAvailable: false,
        targetCount: 0,
        runtime: "none",
        capabilities: []
    )
    let connected = TKCapabilitiesResponse(
        ok: true,
        serverReachable: true,
        connected: true,
        latestHierarchyAvailable: true,
        targetCount: 1,
        runtime: "embedded",
        capabilities: []
    )

    return [
        buildWorkflowPlan(capabilities: disconnected, host: "127.0.0.1", port: 19421),
        buildWorkflowPlan(capabilities: targetMissing, host: "127.0.0.1", port: 19421),
        buildWorkflowPlan(capabilities: connected, host: "127.0.0.1", port: 19421),
        buildWorkflowPlan(
            capabilities: connected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "ios-smoke",
                device: includeTaskInputs ? "iphone15" : nil,
                bundleID: includeTaskInputs ? "com.example.app" : nil,
                url: includeTaskInputs ? "myapp://smoke" : nil,
                text: includeTaskInputs ? "Home" : nil,
                expectedURL: nil,
                evidence: includeTaskInputs ? "/tmp/smoke.tritonevidence" : nil
            )
        ),
        buildWorkflowPlan(
            capabilities: connected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "open-url",
                device: includeTaskInputs ? "iphone15" : nil,
                bundleID: nil,
                url: includeTaskInputs ? "myapp://detail" : nil,
                text: includeTaskInputs ? "Ready" : nil,
                expectedURL: nil,
                evidence: includeTaskInputs ? "/tmp/open-url.tritonevidence" : nil
            )
        ),
        buildWorkflowPlan(
            capabilities: connected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "webview-check",
                device: nil,
                bundleID: nil,
                url: nil,
                text: includeTaskInputs ? "Loaded" : nil,
                expectedURL: includeTaskInputs ? "https://example.com" : nil,
                evidence: includeTaskInputs ? "/tmp/webview.tritonevidence" : nil
            )
        ),
        buildWorkflowPlan(
            capabilities: connected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "network-proxy",
                device: includeTaskInputs ? "booted" : nil,
                platform: includeTaskInputs ? "ios" : nil,
                bundleID: nil,
                url: nil,
                text: nil,
                expectedURL: nil,
                evidence: includeTaskInputs ? "/tmp/proxy.tritonevidence" : nil,
                proxy: includeTaskInputs ? "127.0.0.1:19431" : nil,
                mode: includeTaskInputs ? "mock" : nil,
                output: includeTaskInputs ? "/tmp/proxy-session" : nil,
                certificate: includeTaskInputs ? "/tmp/triton-proxy-ca.cer" : nil,
                auditRecord: includeTaskInputs ? "ticket-123" : nil,
                mockRules: includeTaskInputs ? "/tmp/triton-mock-rules.json" : nil
            )
        ),
    ]
}

func capabilityStateFixtures() -> [(name: String, capabilities: [TKRuntimeCapability])] {
    [
        (
            name: "server-unreachable",
            capabilities: runtimeCapabilities(
                host: "127.0.0.1",
                port: 19421,
                serverReachable: false,
                connected: false
            )
        ),
        (
            name: "runtime-disconnected",
            capabilities: runtimeCapabilities(
                host: "127.0.0.1",
                port: 19421,
                serverReachable: true,
                connected: false
            )
        ),
        (
            name: "runtime-connected",
            capabilities: runtimeCapabilities(
                host: "127.0.0.1",
                port: 19421,
                serverReachable: true,
                connected: true
            )
        ),
    ]
}

func capabilityMap(state name: String) -> [String: TKRuntimeCapability] {
    Dictionary(uniqueKeysWithValues: capabilityStateFixtures()
        .first { $0.name == name }?
        .capabilities
        .map { ($0.name, $0) } ?? []
    )
}

func disconnectedCapabilityMap() -> [String: TKRuntimeCapability] {
    capabilityMap(state: "runtime-disconnected")
}

func unavailableServerCapabilityMap() -> [String: TKRuntimeCapability] {
    capabilityMap(state: "server-unreachable")
}

func connectedCapabilities() -> [TKRuntimeCapability] {
    capabilityStateFixtures()
        .first { $0.name == "runtime-connected" }?
        .capabilities ?? []
}

func connectedCapabilityMap() -> [String: TKRuntimeCapability] {
    Dictionary(uniqueKeysWithValues: connectedCapabilities().map { ($0.name, $0) })
}

func assertCapability(
    _ capabilities: [String: TKRuntimeCapability],
    name: String,
    supported: Bool,
    group: String? = nil,
    requiredByContains: [String] = [],
    requiredByExact: [String]? = nil,
    evidence: [String]? = nil,
    nextActionCommand: String,
    nextActionArgs: [String],
    longRunning: Bool? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let capability = try #require(capabilities[name], sourceLocation: sourceLocation)
    #expect(capability.supported == supported, sourceLocation: sourceLocation)
    if let group {
        #expect(capability.group == group, sourceLocation: sourceLocation)
    }
    if let requiredByExact {
        #expect(capability.requiredBy == requiredByExact, sourceLocation: sourceLocation)
    } else {
        for workflow in requiredByContains {
            #expect(capability.requiredBy.contains(workflow), sourceLocation: sourceLocation)
        }
    }
    if let evidence {
        #expect(capability.evidence == evidence, sourceLocation: sourceLocation)
    }
    #expect(capability.nextAction?.command == nextActionCommand, sourceLocation: sourceLocation)
    #expect(capability.nextAction?.args == nextActionArgs, sourceLocation: sourceLocation)
    if let longRunning {
        #expect(capability.nextAction?.requiresLongRunningProcess == longRunning, sourceLocation: sourceLocation)
    }
}
