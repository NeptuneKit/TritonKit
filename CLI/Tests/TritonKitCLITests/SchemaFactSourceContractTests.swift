import Testing
import TritonKitShared
@testable import TritonKitCLI

extension SchemaFactSourceTests {
    @Test("schema next commands stay single Triton invocations")
    func schemaNextCommandsStaySingleTritonInvocations() {
        var invalidCommands: [String] = []

        for fixture in schemaNextCommandFixtures(includeSubcommands: true) {
            if !isSingleTritonInvocation(fixture.command) {
                invalidCommands.append("\(fixture.context):\(fixture.command)")
            }
        }

        #expect(invalidCommands == [])
    }

    @Test("commands that provide capabilities expose output contracts")
    func commandsThatProvideCapabilitiesExposeOutputContracts() {
        let missing = commandSchemas()
            .filter { !$0.providedCapabilities.isEmpty }
            .filter { $0.outputContracts.isEmpty }
            .map(\.name)
            .sorted()

        #expect(missing == [])
    }

    @Test("schema examples do not recommend retired root commands")
    func schemaExamplesDoNotRecommendRetiredRootCommands() {
        let retiredRoots: Set<String> = ["state", "runtime", "snapshot", "hierarchy", "nodes", "node", "attrs", "object", "geometry", "ax", "hit", "ledger"]
        let invalidExamples = commandSchemas()
            .flatMap { schema in schema.examples.map { (schema.name, $0) } }
            .compactMap { schemaName, example -> String? in
                let parts = example.split(whereSeparator: \.isWhitespace)
                guard parts.count > 1, parts[0] == "triton" else {
                    return nil
                }
                return retiredRoots.contains(String(parts[1])) ? "\(schemaName): \(example)" : nil
            }
            .sorted()

        #expect(invalidExamples == [])
    }

    @Test("P23 command schemas expose product surface metadata")
    func p23CommandSchemasExposeProductSurfaceMetadata() throws {
        let schemas = commandSchemaMap()
        let validLayers: Set<String> = ["workflow", "diagnostic", "host-adapter", "agent-support", "raw-engine"]
        let unknownLayers = commandSchemas()
            .filter { !validLayers.contains($0.surfaceLayer) }
            .map { "\($0.name):\($0.surfaceLayer)" }
            .sorted()

        #expect(unknownLayers == [])

        for name in ["observe", "act", "verify"] {
            let schema = try #require(schemas[name])
            #expect(schema.surfaceLayer == "workflow")
            #expect(schema.deprecatedForMainPath == false)
            #expect(schema.replacementCommand == nil)
        }

        let debug = try #require(schemas["debug"])
        #expect(debug.surfaceLayer == "raw-engine")
        #expect(debug.deprecatedForMainPath == false)
        #expect(debug.replacementCommand == nil)
        #expect(debug.subcommands.map(\.name).contains("hierarchy"))
        #expect(debug.subcommands.map(\.name).contains("ledger"))

        let retiredRoots: Set<String> = [
            "find", "tap", "type", "paste", "clear", "swipe", "press", "focus", "set-text", "select-segment", "set-switch", "input",
            "assert", "capture",
            "runtime", "state", "snapshot", "hierarchy", "nodes", "node", "attrs", "object", "geometry", "ax", "hit", "ledger",
        ]
        let stillExposedRetiredRoots = retiredRoots.intersection(Set(schemas.keys)).sorted()
        #expect(stillExposedRetiredRoots == [])

        let act = try #require(schemas["act"])
        #expect(act.subcommands.map(\.name).contains("tap"))
        #expect(act.subcommands.map(\.name).contains("type"))

        let verify = try #require(schemas["verify"])
        #expect(verify.subcommands.map(\.name).contains("text-exists"))

        let evidence = try #require(schemas["evidence"])
        #expect(evidence.subcommands.map(\.name).contains("capture"))

        #expect(debug.subcommands.map(\.name).contains("geometry"))
        #expect(debug.subcommands.map(\.name).contains("hit"))
    }

    @Test("P23 raw debug commands stay schema backed")
    func p23RawDebugCommandsStaySchemaBacked() throws {
        let schemas = commandSchemaMap()
        let debug = try #require(schemas["debug"])
        let debugSubcommands = Set(debug.subcommands.map(\.name))
        var invalidCommands: [String] = []
        var missingSubcommands: [String] = []

        for commandName in ["runtime", "state", "snapshot", "hierarchy", "nodes", "node", "attrs", "object", "geometry", "ax", "hit", "ledger"] {
            let rawDebugCommand = "triton debug \(commandName)"

            if !isSingleTritonInvocation(rawDebugCommand) {
                invalidCommands.append("\(commandName):\(rawDebugCommand)")
                continue
            }

            if !debugSubcommands.contains(commandName) {
                missingSubcommands.append("\(commandName):\(rawDebugCommand)")
            }
        }

        #expect(invalidCommands == [])
        #expect(missingSubcommands == [])
    }

    @Test("schema output contracts expose nonempty fields")
    func schemaOutputContractsExposeNonemptyFields() {
        var missingSelectors: [String] = []
        var missingModels: [String] = []
        var emptyFields: [String] = []
        var duplicateFields: [String] = []
        var invalidFields: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                if contract.selector.isEmpty {
                    missingSelectors.append(schema.name)
                }
                if contract.model?.isEmpty ?? true {
                    missingModels.append("\(schema.name):\(contract.selector)")
                }
                if contract.fields.isEmpty {
                    emptyFields.append("\(schema.name):\(contract.selector)")
                }
                let names = contract.fields.map(\.name)
                if Set(names).count != names.count {
                    duplicateFields.append("\(schema.name):\(contract.selector)")
                }
                for field in contract.fields where field.name.isEmpty || field.type.isEmpty || field.description.isEmpty {
                    invalidFields.append("\(schema.name):\(contract.selector):\(field.name)")
                }
            }
        }

        #expect(missingSelectors == [])
        #expect(missingModels == [])
        #expect(emptyFields == [])
        #expect(duplicateFields == [])
        #expect(invalidFields == [])
    }

    @Test("schema output contract field types stay machine readable")
    func schemaOutputContractFieldTypesStayMachineReadable() {
        var invalidTypes: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                for field in contract.fields where !isMachineReadableSchemaType(field.type) {
                    invalidTypes.append("\(schema.name):\(contract.selector):\(field.name):\(field.type)")
                }
            }
        }

        #expect(invalidTypes == [])
    }

    @Test("schema output contract models stay machine readable")
    func schemaOutputContractModelsStayMachineReadable() {
        var invalidModels: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                guard let model = contract.model else {
                    invalidModels.append("\(schema.name):\(contract.selector):nil")
                    continue
                }
                if !isMachineReadableSchemaType(model) {
                    invalidModels.append("\(schema.name):\(contract.selector):\(model)")
                }
            }
        }

        #expect(invalidModels == [])
    }

    @Test("schema output contract formats stay within the agent taxonomy")
    func schemaOutputContractFormatsStayWithinAgentTaxonomy() {
        var invalidFormats: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts where !outputContractFormatTaxonomy().contains(contract.format) {
                invalidFormats.append("\(schema.name):\(contract.selector):\(contract.format)")
            }
        }

        #expect(invalidFormats == [])
    }

    @Test("schema output contract kinds stay within the agent taxonomy")
    func schemaOutputContractKindsStayWithinAgentTaxonomy() {
        var invalidKinds: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts where !outputContractKindTaxonomy().contains(contract.kind) {
                invalidKinds.append("\(schema.name):\(contract.selector):\(contract.kind)")
            }
        }

        #expect(invalidKinds == [])
    }

    @Test("schema output contract selectors remain unique for agent lookup")
    func schemaOutputContractSelectorsRemainUniqueForAgentLookup() {
        var duplicateSelectors: [String] = []

        for schema in commandSchemas() {
            let selectors = schema.outputContracts.map(\.selector)
            let duplicates = Set(selectors)
                .filter { selector in selectors.filter { $0 == selector }.count > 1 }
                .sorted()
            duplicateSelectors.append(contentsOf: duplicates.map { "\(schema.name):\($0)" })
        }

        #expect(duplicateSelectors == [])
    }

    @Test("schema output contract selectors and kinds use stable agent keys")
    func schemaOutputContractSelectorsAndKindsUseStableAgentKeys() {
        var invalidSelectors: [String] = []
        var invalidKinds: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                if !isAgentSelectorKey(contract.selector) {
                    invalidSelectors.append("\(schema.name):\(contract.selector)")
                }
                if !isKebabCaseKey(contract.kind) {
                    invalidKinds.append("\(schema.name):\(contract.selector):\(contract.kind)")
                }
            }
        }

        #expect(invalidSelectors == [])
        #expect(invalidKinds == [])
    }

    @Test("subcommand output selectors stay covered by parent output contracts")
    func subcommandOutputSelectorsStayCoveredByParentOutputContracts() {
        var uncoveredSelectors: [String] = []

        for schema in commandSchemas() {
            let contractSelectors = Set(schema.outputContracts.map(\.selector))
            for subcommand in schema.subcommands {
                let missing = Set(subcommand.outputSelectors).subtracting(contractSelectors).sorted()
                if !missing.isEmpty {
                    uncoveredSelectors.append("\(schema.name) \(subcommand.name): \(missing.joined(separator: ","))")
                }
            }
        }

        #expect(uncoveredSelectors == [])
    }

    @Test("schema failure surfaces expose stable failure codes")
    func schemaFailureSurfacesExposeStableFailureCodes() {
        let missingCodes = commandSchemas()
            .filter { $0.exitCodeOnFailure != 0 || ($0.failureShape?.isEmpty == false) }
            .filter { $0.failureCodes.isEmpty }
            .map(\.name)
            .sorted()

        #expect(missingCodes == [])
    }

    @Test("schema failure shapes describe next action lifecycle")
    func schemaFailureShapesDescribeNextActionLifecycle() {
        let missingLifecycle = commandSchemas()
            .compactMap { schema -> String? in
                guard let failureShape = schema.failureShape,
                      failureShape.contains("nextAction?")
                else {
                    return nil
                }
                let requiredTokens = [
                    "command",
                    "args",
                    "category",
                    "requiresLongRunningProcess",
                    "readyEvents",
                    "finalEvents",
                    "terminationSignals",
                ]
                return requiredTokens.allSatisfy { failureShape.contains($0) } ? nil : schema.name
            }
            .sorted()

        #expect(missingLifecycle == [])
    }

    @Test("error output contracts expose stable error subfields")
    func errorOutputContractsExposeStableErrorSubfields() {
        let requiredErrorFields: Set<String> = [
            "error.endpoint",
            "error.hint",
            "error.nearestCandidates",
            "error.suggestedCommands",
            "error.candidateCount",
            "error.nextAction",
            "error.nextAction.command",
            "error.nextAction.args",
            "error.nextAction.category",
            "error.nextAction.requiresLongRunningProcess",
            "error.nextAction.readyEvents",
            "error.nextAction.finalEvents",
            "error.nextAction.terminationSignals",
        ]
        var missingFields: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                let fields = contract.fields
                let fieldNames = Set(fields.map(\.name))
                let hasCLIError = fields.contains { field in
                    field.name == "error" && field.type == "TKCLIErrorDetail?"
                }
                guard hasCLIError else { continue }

                let missing = requiredErrorFields.subtracting(fieldNames).sorted()
                if !missing.isEmpty {
                    missingFields.append("\(schema.name):\(contract.selector):\(missing.joined(separator: ","))")
                }
            }
        }

        #expect(missingFields == [])
    }

    @Test("nextAction output contracts expose stable next action subfields")
    func nextActionOutputContractsExposeStableNextActionSubfields() {
        let requiredNextActionFields: Set<String> = [
            ".command",
            ".args",
            ".category",
            ".requiresLongRunningProcess",
            ".readyEvents",
            ".finalEvents",
            ".terminationSignals",
        ]
        var missingFields: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                let fields = contract.fields
                let fieldNames = Set(fields.map(\.name))
                let nextActionFields = fields.filter { $0.type == "TKCLINextAction?" }.map(\.name)

                for nextActionField in nextActionFields {
                    let missing = requiredNextActionFields
                        .map { "\(nextActionField)\($0)" }
                        .filter { !fieldNames.contains($0) }
                        .sorted()
                    if !missing.isEmpty {
                        missingFields.append("\(schema.name):\(contract.selector):\(nextActionField):\(missing.joined(separator: ","))")
                    }
                }
            }
        }

        #expect(missingFields == [])
    }

    @Test("schema failure codes use stable snake case")
    func schemaFailureCodesUseStableSnakeCase() {
        var invalidCodes: [String] = []
        var duplicateSurfaces: [String] = []

        for schema in commandSchemas() {
            if Set(schema.failureCodes).count != schema.failureCodes.count {
                duplicateSurfaces.append(schema.name)
            }
            for code in schema.failureCodes where !isSnakeCaseKey(code) {
                invalidCodes.append("\(schema.name):\(code)")
            }

            for subcommand in schema.subcommands {
                let context = "\(schema.name) \(subcommand.name)"
                if Set(subcommand.failureCodes).count != subcommand.failureCodes.count {
                    duplicateSurfaces.append(context)
                }
                for code in subcommand.failureCodes where !isSnakeCaseKey(code) {
                    invalidCodes.append("\(context):\(code)")
                }
            }
        }

        #expect(invalidCodes == [])
        #expect(duplicateSurfaces == [])
    }

    @Test("subcommand failure codes stay covered by parent schemas")
    func subcommandFailureCodesStayCoveredByParentSchemas() {
        var uncovered: [String] = []

        for schema in commandSchemas() {
            let parentCodes = Set(schema.failureCodes)
            for subcommand in schema.subcommands {
                let missing = Set(subcommand.failureCodes).subtracting(parentCodes).sorted()
                if !missing.isEmpty {
                    uncovered.append("\(schema.name) \(subcommand.name): \(missing.joined(separator: ","))")
                }
            }
        }

        #expect(uncovered == [])
    }

    @Test("schema options and subcommands expose nonempty metadata")
    func schemaOptionsAndSubcommandsExposeNonemptyMetadata() {
        var invalidOptions: [String] = []
        var duplicateOptions: [String] = []
        var invalidSubcommands: [String] = []
        var duplicateSubcommands: [String] = []

        for schema in commandSchemas() {
            let optionNames = schema.options.map(\.name)
            if Set(optionNames).count != optionNames.count {
                duplicateOptions.append(schema.name)
            }
            for option in schema.options where option.name.isEmpty || option.type.isEmpty || option.description.isEmpty {
                invalidOptions.append("\(schema.name):\(option.name)")
            }

            let subcommandNames = schema.subcommands.map(\.name)
            if Set(subcommandNames).count != subcommandNames.count {
                duplicateSubcommands.append(schema.name)
            }
            for subcommand in schema.subcommands where subcommand.name.isEmpty || subcommand.summary.isEmpty {
                invalidSubcommands.append("\(schema.name):\(subcommand.name)")
            }
        }

        #expect(invalidOptions == [])
        #expect(duplicateOptions == [])
        #expect(invalidSubcommands == [])
        #expect(duplicateSubcommands == [])
    }

    @Test("schema command subcommand and flag names use stable CLI keys")
    func schemaCommandSubcommandAndFlagNamesUseStableCLIKeys() {
        var invalidCommands: [String] = []
        var invalidFlags: [String] = []
        var invalidSubcommands: [String] = []

        for schema in commandSchemas() {
            if !isKebabCaseKey(schema.name) {
                invalidCommands.append(schema.name)
            }
            for option in schema.options where !isLongOptionKeyExpression(option.name) {
                invalidFlags.append("\(schema.name):\(option.name)")
            }
            for subcommand in schema.subcommands where !isKebabCaseKey(subcommand.name) {
                invalidSubcommands.append("\(schema.name):\(subcommand.name)")
            }
        }

        #expect(invalidCommands == [])
        #expect(invalidFlags == [])
        #expect(invalidSubcommands == [])
    }

    @Test("schema usage forms stay separate from options")
    func schemaUsageFormsStaySeparateFromOptions() {
        var usageOptions: [String] = []
        var invalidUsageForms: [String] = []
        var missingUsageForms: [String] = []

        for schema in commandSchemas() {
            for option in schema.options where option.type == "Subcommand" || option.type == "Task" {
                usageOptions.append("\(schema.name):\(option.name)")
            }

            if !schema.subcommands.isEmpty && schema.usageForms.isEmpty {
                missingUsageForms.append(schema.name)
            }

            for usageForm in schema.usageForms {
                if usageForm.form.isEmpty ||
                    usageForm.description.isEmpty ||
                    !["Subcommand", "Task"].contains(usageForm.kind) {
                    invalidUsageForms.append("\(schema.name):\(usageForm.form)")
                }
            }
        }

        #expect(usageOptions == [])
        #expect(missingUsageForms == [])
        #expect(invalidUsageForms == [])
    }

    @Test("schema argument forms stay separate from options")
    func schemaArgumentFormsStaySeparateFromOptions() {
        var argumentOptions: [String] = []
        var invalidArgumentForms: [String] = []

        for schema in commandSchemas() {
            for option in schema.options where option.name.hasPrefix("<") {
                argumentOptions.append("\(schema.name):\(option.name)")
            }

            for argument in schema.argumentForms {
                if !argument.name.hasPrefix("<") ||
                    !argument.name.hasSuffix(">") ||
                    argument.type.isEmpty ||
                    argument.description.isEmpty {
                    invalidArgumentForms.append("\(schema.name):\(argument.name)")
                }
            }
        }

        #expect(argumentOptions == [])
        #expect(invalidArgumentForms == [])
    }

    @Test("subcommand parameter references stay covered by parent schema")
    func subcommandParameterReferencesStayCoveredByParentSchema() {
        var missingReferences: [String] = []

        for schema in commandSchemas() {
            let knownParameters = schemaKnownParameterKeys(schema)
            for subcommand in schema.subcommands {
                let references = subcommand.requiredOptions +
                    subcommand.optionalOptions +
                    subcommand.oneOfRequiredOptions.flatMap { $0 }

                for reference in references where !knownParameters.contains(reference) {
                    missingReferences.append("\(schema.name) \(subcommand.name):\(reference)")
                }
            }
        }

        #expect(missingReferences == [])
    }

    @Test("command level required options stay direct or subcommand scoped")
    func commandLevelRequiredOptionsStayDirectOrSubcommandScoped() {
        var subcommandScopedRequirements: [String] = []
        var missingReferences: [String] = []

        for schema in commandSchemas() {
            if !schema.subcommands.isEmpty && !schema.requiredOptions.isEmpty {
                subcommandScopedRequirements.append("\(schema.name):\(schema.requiredOptions.joined(separator: ","))")
            }

            guard schema.subcommands.isEmpty else {
                continue
            }

            let knownParameters = schemaKnownParameterKeys(schema)
            for reference in schema.requiredOptions where !knownParameters.contains(reference) {
                missingReferences.append("\(schema.name):\(reference)")
            }
        }

        #expect(subcommandScopedRequirements == [])
        #expect(missingReferences == [])
    }

    @Test("schema default provider references stay schema backed")
    func schemaDefaultProviderReferencesStaySchemaBacked() {
        let schemas = commandSchemaMap()
        var issues = SchemaBackedCommandIssues()

        for schema in commandSchemas() {
            for command in schema.inheritsDefaultsFrom {
                validateSchemaBackedCommandExpression(
                    command,
                    context: "\(schema.name).inheritsDefaultsFrom",
                    schemas: schemas,
                    issues: &issues
                )
            }

            for subcommand in schema.subcommands {
                for command in subcommand.defaultProviders {
                    validateSchemaBackedCommandExpression(
                        command,
                        context: "\(schema.name) \(subcommand.name).defaultProviders",
                        schemas: schemas,
                        issues: &issues
                    )
                }
                for command in subcommand.inheritsDefaultsFrom {
                    validateSchemaBackedCommandExpression(
                        command,
                        context: "\(schema.name) \(subcommand.name).inheritsDefaultsFrom",
                        schemas: schemas,
                        issues: &issues
                    )
                }
            }
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("schema examples and output formats remain agent usable")
    func schemaExamplesAndOutputFormatsRemainAgentUsable() {
        let schemas = commandSchemaMap()
        var missingOutputFormats: [String] = []
        var missingExamples: [String] = []
        var issues = SchemaBackedCommandIssues()

        for schema in commandSchemas() {
            if schema.outputFormats.isEmpty {
                missingOutputFormats.append(schema.name)
            }
            if schema.examples.isEmpty {
                missingExamples.append(schema.name)
            }
        }

        for fixture in schemaExampleCommandFixtures() {
            validateSchemaBackedArgv(
                fixture.argv,
                context: fixture.context,
                schemas: schemas,
                issues: &issues
            )
        }

        #expect(missingOutputFormats == [])
        #expect(missingExamples == [])
        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("schema output formats stay within the command taxonomy")
    func schemaOutputFormatsStayWithinCommandTaxonomy() {
        var invalidFormats: [String] = []
        var duplicateFormats: [String] = []

        for schema in commandSchemas() {
            for format in schema.outputFormats where !commandOutputFormatTaxonomy().contains(format) {
                invalidFormats.append("\(schema.name):\(format)")
            }
            if Set(schema.outputFormats).count != schema.outputFormats.count {
                duplicateFormats.append(schema.name)
            }
        }

        #expect(invalidFormats == [])
        #expect(duplicateFormats == [])
    }

    @Test("schema artifacts stay within the artifact taxonomy")
    func schemaArtifactsStayWithinTheArtifactTaxonomy() {
        var invalidArtifacts: [String] = []
        var duplicateArtifacts: [String] = []

        for schema in commandSchemas() {
            for artifact in schema.artifacts where !schemaArtifactTaxonomy().contains(artifact) {
                invalidArtifacts.append("\(schema.name):\(artifact)")
            }
            if Set(schema.artifacts).count != schema.artifacts.count {
                duplicateArtifacts.append(schema.name)
            }

            for subcommand in schema.subcommands {
                for artifact in subcommand.artifacts where !schemaArtifactTaxonomy().contains(artifact) {
                    invalidArtifacts.append("\(schema.name) \(subcommand.name):\(artifact)")
                }
                if Set(subcommand.artifacts).count != subcommand.artifacts.count {
                    duplicateArtifacts.append("\(schema.name) \(subcommand.name)")
                }
            }
        }

        #expect(invalidArtifacts == [])
        #expect(duplicateArtifacts == [])
    }

    @Test("schema jsonl events expose stable event keys")
    func schemaJSONLEventsExposeStableEventKeys() {
        var invalidEvents: [String] = []
        var duplicateEvents: [String] = []
        var missingFinalEvents: [String] = []
        var missingJSONLOutputFormat: [String] = []

        for schema in commandSchemas() {
            for event in schema.jsonlEvents where !isAgentEventKey(event, allowingPlaceholders: true) {
                invalidEvents.append("\(schema.name):\(event)")
            }
            if Set(schema.jsonlEvents).count != schema.jsonlEvents.count {
                duplicateEvents.append(schema.name)
            }
            if let finalEventKind = schema.finalEventKind {
                if !isAgentEventKey(finalEventKind, allowingPlaceholders: true) {
                    invalidEvents.append("\(schema.name):\(finalEventKind)")
                }
                if !schema.jsonlEvents.contains(finalEventKind) {
                    missingFinalEvents.append("\(schema.name):\(finalEventKind)")
                }
            }
            if (!schema.jsonlEvents.isEmpty || schema.finalEventKind != nil) && !schema.outputFormats.contains("jsonl") {
                missingJSONLOutputFormat.append(schema.name)
            }

            for subcommand in schema.subcommands {
                for event in subcommand.jsonlEvents where !isAgentEventKey(event, allowingPlaceholders: false) {
                    invalidEvents.append("\(schema.name) \(subcommand.name):\(event)")
                }
                if Set(subcommand.jsonlEvents).count != subcommand.jsonlEvents.count {
                    duplicateEvents.append("\(schema.name) \(subcommand.name)")
                }
                if let finalEventKind = subcommand.finalEventKind {
                    if !isAgentEventKey(finalEventKind, allowingPlaceholders: false) {
                        invalidEvents.append("\(schema.name) \(subcommand.name):\(finalEventKind)")
                    }
                    if !subcommand.jsonlEvents.contains(finalEventKind) {
                        missingFinalEvents.append("\(schema.name) \(subcommand.name):\(finalEventKind)")
                    }
                }
            }
        }

        #expect(invalidEvents == [])
        #expect(duplicateEvents == [])
        #expect(missingFinalEvents == [])
        #expect(missingJSONLOutputFormat == [])
    }

    @Test("retryable schemas expose recovery commands")
    func retryableSchemasExposeRecoveryCommands() {
        var retryableWithoutNextCommands: [String] = []

        for schema in commandSchemas() {
            if schema.retryable && schema.nextCommands.isEmpty {
                retryableWithoutNextCommands.append(schema.name)
            }

            for subcommand in schema.subcommands where subcommand.retryable && subcommand.nextCommands.isEmpty {
                retryableWithoutNextCommands.append("\(schema.name) \(subcommand.name)")
            }
        }

        #expect(retryableWithoutNextCommands == [])
    }

    @Test("failure codes expose a recovery command path")
    func failureCodesExposeARecoveryCommandPath() {
        var failureCodesWithoutRecoveryPath: [String] = []

        for schema in commandSchemas() {
            if !schema.failureCodes.isEmpty && schema.nextCommands.isEmpty {
                failureCodesWithoutRecoveryPath.append(schema.name)
            }

            for subcommand in schema.subcommands
                where !subcommand.failureCodes.isEmpty &&
                subcommand.nextCommands.isEmpty &&
                schema.nextCommands.isEmpty {
                failureCodesWithoutRecoveryPath.append("\(schema.name) \(subcommand.name)")
            }
        }

        #expect(failureCodesWithoutRecoveryPath == [])
    }

    @Test("schema recovery command lists stay clean")
    func schemaRecoveryCommandListsStayClean() {
        var blankRecoveryCommands: [String] = []
        var duplicateRecoveryCommands: [String] = []

        for schema in commandSchemas() {
            collectRecoveryCommandListIssues(
                schema.nextCommands,
                context: schema.name,
                blank: &blankRecoveryCommands,
                duplicate: &duplicateRecoveryCommands
            )

            for subcommand in schema.subcommands {
                collectRecoveryCommandListIssues(
                    subcommand.nextCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    blank: &blankRecoveryCommands,
                    duplicate: &duplicateRecoveryCommands
                )
            }
        }

        #expect(blankRecoveryCommands == [])
        #expect(duplicateRecoveryCommands == [])
    }

    @Test("schema recovery command roots stay within the recovery taxonomy")
    func schemaRecoveryCommandRootsStayWithinRecoveryTaxonomy() {
        var unknownRecoveryRoots: [String] = []

        for fixture in schemaNextCommandFixtures(includeSubcommands: true) {
            guard let root = tritonRootCommand(in: fixture.argv) else {
                unknownRecoveryRoots.append("\(fixture.context):\(fixture.argv.joined(separator: " "))")
                continue
            }
            if !recoveryCommandRootTaxonomy().contains(root) {
                unknownRecoveryRoots.append("\(fixture.context):\(root)")
            }
        }

        #expect(unknownRecoveryRoots == [])
    }

    @Test("schema recovery command roots expose stable categories")
    func schemaRecoveryCommandRootsExposeStableCategories() {
        let rootTaxonomy = recoveryCommandRootTaxonomy()
        let categoryMap = recoveryCommandRootCategoryMap()
        let categoryTaxonomy = recoveryCommandCategoryTaxonomy()

        let missingCategoryRoots = rootTaxonomy.subtracting(categoryMap.keys).sorted()
        let extraCategoryRoots = Set(categoryMap.keys).subtracting(rootTaxonomy).sorted()
        let invalidCategories = categoryMap
            .filter { !categoryTaxonomy.contains($0.value) }
            .map { "\($0.key):\($0.value)" }
            .sorted()

        var uncategorizedRecoveryRoots: [String] = []
        for fixture in schemaNextCommandFixtures(includeSubcommands: true) {
            guard let root = tritonRootCommand(in: fixture.argv) else {
                uncategorizedRecoveryRoots.append("\(fixture.context):\(fixture.argv.joined(separator: " "))")
                continue
            }
            if categoryMap[root] == nil {
                uncategorizedRecoveryRoots.append("\(fixture.context):\(root)")
            }
        }

        #expect(missingCategoryRoots == [])
        #expect(extraCategoryRoots == [])
        #expect(invalidCategories == [])
        #expect(uncategorizedRecoveryRoots == [])
    }

    @Test("schema recovery commands mirror next commands and expose categories")
    func schemaRecoveryCommandsMirrorNextCommandsAndExposeCategories() {
        var mismatchedCommandLists: [String] = []
        var invalidCategories: [String] = []

        #expect(TKCommandRecoveryCommand.rootCommandTaxonomy == recoveryCommandRootTaxonomy())
        #expect(TKCommandRecoveryCommand.categoryTaxonomy == recoveryCommandCategoryTaxonomy())

        for schema in commandSchemas() {
            validateRecoveryCommands(
                schema.recoveryCommands,
                nextCommands: schema.nextCommands,
                context: schema.name,
                mismatchedCommandLists: &mismatchedCommandLists,
                invalidCategories: &invalidCategories
            )

            for subcommand in schema.subcommands {
                validateRecoveryCommands(
                    subcommand.recoveryCommands,
                    nextCommands: subcommand.nextCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    mismatchedCommandLists: &mismatchedCommandLists,
                    invalidCategories: &invalidCategories
                )
            }
        }

        #expect(mismatchedCommandLists == [])
        #expect(invalidCategories == [])
    }

    @Test("schema failure codes map to recovery category families")
    func schemaFailureCodesMapToRecoveryCategoryFamilies() {
        var unmappedFailureCodes: [String] = []
        var invalidRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateFailureCodes(
                schema.failureCodes,
                context: schema.name,
                unmappedFailureCodes: &unmappedFailureCodes,
                invalidRecoveryCategories: &invalidRecoveryCategories
            )

            for subcommand in schema.subcommands {
                validateFailureCodes(
                    subcommand.failureCodes,
                    context: "\(schema.name) \(subcommand.name)",
                    unmappedFailureCodes: &unmappedFailureCodes,
                    invalidRecoveryCategories: &invalidRecoveryCategories
                )
            }
        }

        #expect(unmappedFailureCodes == [])
        #expect(invalidRecoveryCategories == [])
    }

    @Test("artifact failure codes expose archive recovery categories")
    func artifactFailureCodesExposeArchiveRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateArtifactFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateArtifactFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("assertion failure codes expose verify recovery categories")
    func assertionFailureCodesExposeVerifyRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateAssertionFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateAssertionFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("runtime transport failure codes expose diagnose recovery categories")
    func runtimeTransportFailureCodesExposeDiagnoseRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateRuntimeTransportFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateRuntimeTransportFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("target failure codes expose prepare target recovery categories")
    func targetFailureCodesExposePrepareTargetRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateTargetFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateTargetFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("project failure codes expose project recovery categories")
    func projectFailureCodesExposeProjectRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateProjectFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateProjectFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("action failure codes expose act recovery categories")
    func actionFailureCodesExposeActRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateActionFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateActionFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("destructive policy failure codes expose plan recovery categories")
    func destructivePolicyFailureCodesExposePlanRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateDestructivePolicyFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateDestructivePolicyFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("unsupported failure codes expose plan recovery categories")
    func unsupportedFailureCodesExposePlanRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateUnsupportedFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateUnsupportedFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("schema examples contain one Triton invocation for agent reuse")
    func schemaExamplesContainOneTritonInvocationForAgentReuse() {
        let invalidExamples = schemaExampleCommandFixtures()
            .filter { tritonInvocationCount(in: $0.command) != 1 }
            .map { "\($0.context):\($0.command)" }
            .sorted()

        #expect(invalidExamples == [])
    }

    @Test("schema provided capabilities expose planning metadata")
    func schemaProvidedCapabilitiesExposePlanningMetadata() throws {
        let schemaCapabilities = Set(commandSchemas().flatMap(\.providedCapabilities))
        let connected = connectedCapabilityMap()

        var missingGroup: [String] = []
        var miscGroup: [String] = []
        var missingNextAction: [String] = []
        var missingEvidence: [String] = []

        for capabilityName in schemaCapabilities.sorted() {
            let capability = try #require(connected[capabilityName])
            if capability.group == nil {
                missingGroup.append(capabilityName)
            }
            if capability.group == "misc" {
                miscGroup.append(capabilityName)
            }
            if capability.nextAction == nil {
                missingNextAction.append(capabilityName)
            }
            if capability.evidence.isEmpty {
                missingEvidence.append(capabilityName)
            }
        }

        #expect(missingGroup == [])
        #expect(miscGroup == [])
        #expect(missingNextAction == [])
        #expect(missingEvidence == [])
    }

    @Test("capability next actions stay aligned with command schemas")
    func capabilityNextActionsStayAlignedWithCommandSchemas() throws {
        let schemas = commandSchemaMap()
        let capabilities = connectedCapabilities()

        var issues = SchemaBackedCommandIssues()

        for capability in capabilities.sorted(by: { $0.name < $1.name }) {
            guard let nextAction = capability.nextAction else { continue }
            validateSchemaBackedNextAction(
                nextAction.command,
                args: nextAction.args,
                context: capability.name,
                schemas: schemas,
                issues: &issues
            )
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

}
