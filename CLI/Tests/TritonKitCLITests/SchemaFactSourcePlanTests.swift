import Testing
import TritonKitShared
@testable import TritonKitCLI

extension SchemaFactSourceTests {
    @Test("schema and plan placeholders are complete argv tokens")
    func schemaAndPlanPlaceholdersAreCompleteArgvTokens() {
        var malformedPlaceholders: [String] = []

        let schemaFixtures = schemaNextCommandFixtures(includeSubcommands: true)
            + schemaExampleCommandFixtures()
        for fixture in schemaFixtures {
            malformedPlaceholders.append(contentsOf: malformedPlaceholderTokens(
                in: fixture.argv,
                context: fixture.context
            ))
        }
        for fixture in workflowPlanCommandFixtures(includeTaskInputs: false) {
            malformedPlaceholders.append(contentsOf: malformedPlaceholderTokens(
                in: fixture.command,
                context: fixture.context
            ))
        }

        #expect(malformedPlaceholders == [])
    }

    @Test("reliability-sample templates retain canonical target as one argv placeholder")
    func reliabilitySampleTemplatesRetainCanonicalTargetAsOneArgvPlaceholder() throws {
        let test = try #require(commandSchemaMap()["test"])
        let usage = try #require(test.usageForms.first { $0.form.hasPrefix("reliability-sample ") })
        let example = try #require(test.examples.first { $0.hasPrefix("triton test reliability-sample ") })
        let templates = [usage.form, example]

        for template in templates {
            #expect(template.contains("--target <canonical>"))
            #expect(template.contains("triton:ios-simulator:<udid>/app:<bundle>") == false)
            #expect(malformedPlaceholderTokens(in: template, context: "test") == [])
        }
    }

    @Test("workflow plan commands stay single Triton invocations")
    func workflowPlanCommandsStaySingleTritonInvocations() {
        var invalidCommands: [String] = []

        for fixture in workflowPlanCommandFixtures(includeTaskInputs: false) {
            if !isSingleTritonInvocation(fixture.command) {
                invalidCommands.append("\(fixture.context):\(fixture.command)")
            }
        }

        #expect(invalidCommands == [])
    }

    @Test("workflow plan steps expose executable argv")
    func workflowPlanStepsExposeExecutableArgv() {
        var missingArgv: [String] = []
        var invalidArgv: [String] = []
        let schemas = commandSchemaMap()
        var issues = SchemaBackedCommandIssues()

        for fixture in workflowPlanFixtures(includeTaskInputs: true) {
            for step in fixture.steps {
                let context = "\(fixture.goal ?? "general"):\(step.id)"
                if step.argv.isEmpty {
                    missingArgv.append(context)
                    continue
                }
                if step.argv.first != "triton" || step.argv.contains(where: { $0.isEmpty }) {
                    invalidArgv.append("\(context):\(step.argv.joined(separator: " "))")
                    continue
                }
                validateSchemaBackedArgv(step.argv, context: context, schemas: schemas, issues: &issues)
            }
        }

        #expect(missingArgv == [])
        #expect(invalidArgv == [])
        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("workflow plan steps expose stable recovery categories")
    func workflowPlanStepsExposeStableRecoveryCategories() {
        var missingCategories: [String] = []
        var invalidCategories: [String] = []
        var mismatchedCategories: [String] = []

        for plan in workflowPlanFixtures(includeTaskInputs: true) {
            let context = plan.goal ?? "general"
            for step in plan.steps {
                if step.category.isEmpty {
                    missingCategories.append("\(context):\(step.id)")
                }
                if !TKCommandRecoveryCommand.categoryTaxonomy.contains(step.category) {
                    invalidCategories.append("\(context):\(step.id):\(step.category)")
                }
                guard let root = tritonRootCommand(in: step.argv),
                      let expectedCategory = TKCommandRecoveryCommand.category(forRootCommand: root) else {
                    mismatchedCategories.append("\(context):\(step.id):\(step.argv.joined(separator: " "))")
                    continue
                }
                if step.category != expectedCategory {
                    mismatchedCategories.append("\(context):\(step.id):expected=\(expectedCategory):actual=\(step.category)")
                }
            }
        }

        #expect(missingCategories == [])
        #expect(invalidCategories == [])
        #expect(mismatchedCategories == [])
    }

    @Test("workflow plan steps expose structured execution metadata")
    func workflowPlanStepsExposeStructuredExecutionMetadata() {
        var missingRequires: [String] = []
        var missingArtifacts: [String] = []
        var missingStopConditions: [String] = []
        var invalidRequires: [String] = []
        var invalidArtifacts: [String] = []
        var invalidStopConditions: [String] = []
        var invalidReadyEvents: [String] = []
        var invalidFinalEvents: [String] = []
        var invalidTerminationSignals: [String] = []

        for fixture in workflowPlanFixtures(includeTaskInputs: true) {
            for step in fixture.steps {
                let context = "\(fixture.goal ?? "general"):\(step.id)"
                if step.requires.isEmpty {
                    missingRequires.append(context)
                }
                if step.expectedArtifacts.isEmpty {
                    missingArtifacts.append(context)
                }
                if step.stopConditions.isEmpty {
                    missingStopConditions.append(context)
                }
                for requirement in step.requires where !isPlanMetadataKey(requirement) {
                    invalidRequires.append("\(context):\(requirement)")
                }
                for artifact in step.expectedArtifacts where !isPlanMetadataKey(artifact) {
                    invalidArtifacts.append("\(context):\(artifact)")
                }
                for condition in step.stopConditions where !isPlanMetadataKey(condition) {
                    invalidStopConditions.append("\(context):\(condition)")
                }
                for event in step.readyEvents where !isAgentEventKey(event, allowingPlaceholders: false) {
                    invalidReadyEvents.append("\(context):\(event)")
                }
                for event in step.finalEvents where !isAgentEventKey(event, allowingPlaceholders: false) {
                    invalidFinalEvents.append("\(context):\(event)")
                }
                for signal in step.terminationSignals where !isPlanMetadataKey(signal) {
                    invalidTerminationSignals.append("\(context):\(signal)")
                }
            }
        }

        #expect(missingRequires == [])
        #expect(missingArtifacts == [])
        #expect(missingStopConditions == [])
        #expect(invalidRequires == [])
        #expect(invalidArtifacts == [])
        #expect(invalidStopConditions == [])
        #expect(invalidReadyEvents == [])
        #expect(invalidFinalEvents == [])
        #expect(invalidTerminationSignals == [])
    }

    @Test("workflow plan long running steps are explicit")
    func workflowPlanLongRunningStepsAreExplicit() {
        var missingLongRunningSteps: [String] = []
        var missingLongRunningTermination: [String] = []
        var missingProxyServeReadyEvents: [String] = []
        var missingProxyServeFinalEvents: [String] = []
        var unexpectedLongRunningSteps: [String] = []
        var unexpectedOneShotLifecycle: [String] = []

        for fixture in workflowPlanFixtures(includeTaskInputs: true) {
            for step in fixture.steps {
                let context = "\(fixture.goal ?? "general"):\(step.id)"
                let isServerServe = Array(step.argv.prefix(2)) == ["triton", "serve"]
                let isProxyServe = Array(step.argv.prefix(4)) == ["triton", "device", "proxy", "serve"]
                let shouldBeLongRunning = isServerServe || isProxyServe
                if shouldBeLongRunning, step.requiresLongRunningProcess == false {
                    missingLongRunningSteps.append(context)
                }
                if shouldBeLongRunning, step.terminationSignals.isEmpty {
                    missingLongRunningTermination.append(context)
                }
                if isProxyServe, step.readyEvents != ["proxy.serve.ready"] {
                    missingProxyServeReadyEvents.append("\(context):\(step.readyEvents)")
                }
                if isProxyServe, step.finalEvents != ["proxy.serve.summary"] {
                    missingProxyServeFinalEvents.append("\(context):\(step.finalEvents)")
                }
                if !shouldBeLongRunning, step.requiresLongRunningProcess {
                    unexpectedLongRunningSteps.append("\(context):\(step.argv.joined(separator: " "))")
                }
                if !shouldBeLongRunning, !step.readyEvents.isEmpty || !step.finalEvents.isEmpty || !step.terminationSignals.isEmpty {
                    unexpectedOneShotLifecycle.append("\(context):ready=\(step.readyEvents):final=\(step.finalEvents):signals=\(step.terminationSignals)")
                }
            }
        }

        #expect(missingLongRunningSteps == [])
        #expect(missingLongRunningTermination == [])
        #expect(missingProxyServeReadyEvents == [])
        #expect(missingProxyServeFinalEvents == [])
        #expect(unexpectedLongRunningSteps == [])
        #expect(unexpectedOneShotLifecycle == [])
    }

    @Test("workflow plan steps expose workflow taxonomy")
    func workflowPlanStepsExposeWorkflowTaxonomy() {
        var missingWorkflows: [String] = []
        var invalidWorkflows: [String] = []

        for plan in workflowPlanFixtures(includeTaskInputs: true) {
            for step in plan.steps {
                let context = "\(plan.goal ?? "general"):\(step.id)"
                if step.workflowCategories.isEmpty {
                    missingWorkflows.append(context)
                }
                for workflow in step.workflowCategories where !capabilityWorkflowTaxonomy().contains(workflow) {
                    invalidWorkflows.append("\(context):\(workflow)")
                }
            }
        }

        #expect(missingWorkflows == [])
        #expect(invalidWorkflows == [])
    }

    @Test("workflow plan nextWorkflows stay within the workflow taxonomy")
    func workflowPlanNextWorkflowsStayWithinTheWorkflowTaxonomy() {
        let unknownValues = workflowPlanFixtures(includeTaskInputs: true)
            .flatMap { plan in
                plan.nextWorkflows
                    .filter { !capabilityWorkflowTaxonomy().contains($0) }
                    .map { "\(plan.goal ?? "general"):\($0)" }
            }
            .sorted()

        #expect(unknownValues == [])
    }

    @Test("plan inspect steps expose schema-backed argv templates")
    func planInspectStepsExposeSchemaBackedArgvTemplates() {
        let schemas = commandSchemaMap()
        let plan = TKReplayPlan(
            name: "inspect-flow",
            variables: ["username", "password"],
            steps: [
                TKReplayPlanStep(action: .tap, text: "登录"),
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
                TKReplayPlanStep(action: .proxyProbe, platform: "android", device: "emulator-5554"),
                TKReplayPlanStep(
                    action: .proxyCertPlan,
                    platform: "android",
                    device: "emulator-5554",
                    certificate: "/tmp/triton-proxy-ca.cer"
                ),
                TKReplayPlanStep(
                    action: .proxyCertInstall,
                    platform: "android",
                    device: "emulator-5554",
                    certificate: "/tmp/triton-proxy-ca.cer",
                    auditRecord: "ticket-123"
                ),
            ]
        )
        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/inspect-flow.tritonplan", plan: plan)

        var issues = SchemaBackedCommandIssues()
        for step in summary.steps {
            validateSchemaBackedArgv(
                step.argv,
                context: "plan.inspect:\(step.index):\(step.action)",
                schemas: schemas,
                issues: &issues
            )
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("plan inspect steps expose workflow taxonomy")
    func planInspectStepsExposeWorkflowTaxonomy() {
        let plan = TKReplayPlan(
            name: "inspect-flow",
            variables: ["username", "password"],
            steps: [
                TKReplayPlanStep(action: .tap, text: "登录"),
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
                TKReplayPlanStep(action: .proxyProbe, platform: "android", device: "emulator-5554"),
                TKReplayPlanStep(
                    action: .proxyCertPlan,
                    platform: "android",
                    device: "emulator-5554",
                    certificate: "/tmp/triton-proxy-ca.cer"
                ),
                TKReplayPlanStep(
                    action: .proxyCertInstall,
                    platform: "android",
                    device: "emulator-5554",
                    certificate: "/tmp/triton-proxy-ca.cer",
                    auditRecord: "ticket-123"
                ),
            ]
        )
        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/inspect-flow.tritonplan", plan: plan)

        #expect(summary.steps[0].workflowCategories == ["action", "assert", "evidence"])
        #expect(summary.steps[1].workflowCategories == ["action", "assert", "evidence"])
        #expect(summary.steps[2].workflowCategories == ["assert", "evidence", "observe"])
        #expect(summary.steps[3].workflowCategories == ["evidence", "replay"])
        #expect(summary.steps[4].workflowCategories == ["evidence", "target"])
        #expect(summary.steps[4].expectedArtifacts.contains("host-device-proxy"))
        #expect(summary.steps[5].workflowCategories == ["evidence", "target"])
        #expect(summary.steps[5].expectedArtifacts.contains("proxy-certificate"))
        #expect(summary.steps[6].workflowCategories == ["evidence", "target"])
        #expect(summary.steps[6].expectedArtifacts.contains("proxy-certificate"))
    }

    @Test("replay step results expose schema-backed argv")
    func replayStepResultsExposeSchemaBackedArgv() throws {
        let schemas = commandSchemaMap()
        let plan = TKReplayPlan(
            name: "replay-flow",
            variables: ["username"],
            steps: [
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )

        var issues = SchemaBackedCommandIssues()

        for (offset, step) in plan.steps.enumerated() {
            let argv = try TKReplayStepExecution.argv(
                for: step,
                planName: plan.name,
                index: offset + 1,
                variables: ["username": "alice"]
            )
            let result = TKReplayStepResult(
                index: offset + 1,
                action: step.action.rawValue,
                ok: true,
                dryRun: true,
                elapsedMs: 0,
                command: argv
            )
            validateSchemaBackedArgv(
                result.argv,
                context: "replay.result:\(result.index):\(result.action)",
                schemas: schemas,
                issues: &issues
            )
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("replay step results expose workflow taxonomy")
    func replayStepResultsExposeWorkflowTaxonomy() throws {
        let plan = TKReplayPlan(
            name: "replay-flow",
            variables: ["username"],
            steps: [
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )

        var results: [TKReplayStepResult] = []
        for (offset, step) in plan.steps.enumerated() {
            let argv = try TKReplayStepExecution.argv(
                for: step,
                planName: plan.name,
                index: offset + 1,
                variables: ["username": "alice"]
            )
            results.append(TKReplayStepResult(
                index: offset + 1,
                action: step.action.rawValue,
                ok: true,
                dryRun: true,
                elapsedMs: 0,
                command: argv
            ))
        }

        #expect(results[0].workflowCategories == ["action", "assert", "evidence"])
        #expect(results[1].workflowCategories == ["assert", "evidence", "observe"])
        #expect(results[2].workflowCategories == ["evidence", "replay"])
    }

}
