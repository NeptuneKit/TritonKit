import Foundation

/// Converts an existing, already-compiled testrec package into the much
/// narrower `.tritontest.yaml` v1 surface.  This is intentionally an import
/// seam, not another replay executor: it never recompiles raw events, resolves
/// a device, starts an app, or creates evidence.
func importTritonTestCase(
    input: String,
    output: String,
    bundleID: String,
    devicePlatform: String,
    expectedCompiledDigest: String? = nil
) throws -> TKTestImportResponse {
    do {
        return try importCompiledTritonTestCase(
            input: input,
            output: output,
            bundleID: bundleID,
            devicePlatform: devicePlatform,
            expectedCompiledDigest: expectedCompiledDigest
        )
    } catch let failure as TKTestValidationFailure {
        throw failure
    } catch let failure as TKTestRecorderValidationFailure {
        throw testValidationFailure(
            code: failure.detail.code,
            message: "The source package failed import preflight validation.",
            path: importSafeSourceErrorPath(failure.detail.path)
        )
    } catch {
        throw testValidationFailure(
            code: "test_import_failed",
            message: "Could not import the compiled testrec contract.",
            path: "$"
        )
    }
}

private func importCompiledTritonTestCase(
    input: String,
    output: String,
    bundleID: String,
    devicePlatform: String,
    expectedCompiledDigest: String?
) throws -> TKTestImportResponse {
    let fileManager = FileManager.default
    let requestedCaseURL = URL(fileURLWithPath: input).standardizedFileURL
    let caseURL = requestedCaseURL.resolvingSymlinksInPath().standardizedFileURL
    let outputURL = importResolvedOutputURL(
        URL(fileURLWithPath: output).standardizedFileURL,
        fileManager: fileManager
    )
    let trimmedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedDevicePlatform = devicePlatform.trimmingCharacters(in: .whitespacesAndNewlines)

    guard requestedCaseURL.pathExtension == "tritontestcase" else {
        throw testValidationFailure(
            code: "invalid_case_directory",
            message: "test import requires a directory ending in .tritontestcase.",
            path: "<case.tritontestcase>"
        )
    }
    guard outputURL.lastPathComponent.hasSuffix(".tritontest.yaml") else {
        throw testValidationFailure(
            code: "invalid_output_path",
            message: "--output must end in .tritontest.yaml.",
            path: "--output"
        )
    }
    let source = try importReadSourcePackage(caseURL: caseURL, fileManager: fileManager)
    guard !importPath(outputURL, isInside: caseURL) else {
        throw testValidationFailure(
            code: "invalid_output_path",
            message: "--output must be outside the source .tritontestcase package.",
            path: "--output"
        )
    }
    guard !fileManager.fileExists(atPath: outputURL.path) else {
        throw testValidationFailure(
            code: "output_already_exists",
            message: "Refusing to overwrite an existing output plan.",
            path: "--output"
        )
    }
    guard !trimmedBundleID.isEmpty else {
        throw testValidationFailure(
            code: "missing_required_field",
            message: "--bundle-id is required because .tritontestcase v1 does not carry an app identity.",
            path: "--bundle-id"
        )
    }
    guard trimmedDevicePlatform == "ios-simulator" else {
        throw testValidationFailure(
            code: "unsupported_import_platform",
            message: "P0 import only writes an explicitly selected ios-simulator plan.",
            path: "--device-platform",
            allowed: ["ios-simulator"]
        )
    }

    let manifest = source.manifest
    let capabilities = source.capabilities
    guard manifest.kind == "triton.testcase.v1" else {
        throw testValidationFailure(
            code: "invalid_source_contract",
            message: "manifest.json.kind must be triton.testcase.v1.",
            path: "manifest.json.kind"
        )
    }
    guard !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testValidationFailure(
            code: "invalid_source_contract",
            message: "manifest.json.name must not be empty.",
            path: "manifest.json.name"
        )
    }
    guard importSourcePlatformIsIOS(manifest.sourcePlatform) else {
        throw testValidationFailure(
            code: "unsupported_import_platform",
            message: "P0 import accepts only ios or ios-simulator source contracts.",
            path: "manifest.json.sourcePlatform",
            allowed: ["ios", "ios-simulator"]
        )
    }
    guard manifest.truncationStatus == "not-truncated" else {
        throw testValidationFailure(
            code: "truncated_source_contract",
            message: "Import requires a source package whose raw stream is not truncated.",
            path: "manifest.json.truncationStatus"
        )
    }
    guard ["pending", "redacted", "not-required"].contains(manifest.redactionStatus) else {
        throw testValidationFailure(
            code: "invalid_source_contract",
            message: "manifest.json.redactionStatus is not a recognized metadata value.",
            path: "manifest.json.redactionStatus"
        )
    }
    guard importUnsupportedCapabilities(in: capabilities).isEmpty else {
        throw testValidationFailure(
            code: "unsupported_capability",
            message: "The source package declares capability values unsupported by the deterministic importer.",
            path: "contract-capabilities.json"
        )
    }

    let compiled = try importReadCompiledContract(caseURL: caseURL, fileManager: fileManager)
    let contractRef = compiled.contractRef
    if let expectedCompiledDigest {
        let trimmedExpectedDigest = expectedCompiledDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedExpectedDigest.range(of: #"^[0-9a-f]{16}$"#, options: .regularExpression) != nil else {
            throw testValidationFailure(
                code: "invalid_expected_compiled_digest",
                message: "--expect-compiled-digest must be a lowercase 16-character fnv1a64 digest.",
                path: "--expect-compiled-digest"
            )
        }
        guard trimmedExpectedDigest == contractRef.digest else {
            throw testValidationFailure(
                code: "compiled_digest_mismatch",
                message: "compiled-contract.json does not match --expect-compiled-digest.",
                path: "compiled-contract.json"
            )
        }
    }

    let contract = compiled.contract
    guard contract.caseName == manifest.name else {
        throw testValidationFailure(
            code: "source_identity_mismatch",
            message: "compiled-contract.json.caseName does not match manifest.json.name.",
            path: "compiled-contract.json.caseName"
        )
    }
    guard contract.sourcePlatform == manifest.sourcePlatform else {
        throw testValidationFailure(
            code: "source_identity_mismatch",
            message: "compiled-contract.json.sourcePlatform does not match manifest.json.sourcePlatform.",
            path: "compiled-contract.json.sourcePlatform"
        )
    }
    guard let sourcePlatform = contract.sourcePlatform,
          importSourcePlatformIsIOS(sourcePlatform) else {
        throw testValidationFailure(
            code: "unsupported_import_platform",
            message: "P0 import accepts only ios or ios-simulator compiled contracts.",
            path: "compiled-contract.json.sourcePlatform",
            allowed: ["ios", "ios-simulator"]
        )
    }
    guard contract.capabilities == capabilities else {
        throw testValidationFailure(
            code: "source_identity_mismatch",
            message: "compiled-contract.json.capabilities does not match contract-capabilities.json.",
            path: "compiled-contract.json.capabilities"
        )
    }
    guard contract.compiler.mode == "deterministic-offline", !contract.compiler.llmUsed, !contract.compiler.vlmUsed else {
        throw testValidationFailure(
            code: "unsupported_compiled_contract",
            message: "P0 import requires a deterministic-offline compiled contract with no LLM/VLM transform.",
            path: "compiled-contract.json.compiler"
        )
    }
    if let finding = contract.qualityFindings.first {
        let code = finding.proposalKind == "contract.redaction" || finding.code == "privacy_candidate"
            ? "redaction_review_required"
            : "contract_quality_review_required"
        throw testValidationFailure(
            code: code,
            message: "Import requires all compiled-contract quality findings to be resolved before projection.",
            path: "compiled-contract.json.qualityFindings[\(importQualityFindingIndex(finding, in: contract.qualityFindings))]"
        )
    }
    guard importHasPageEvidence(contract.pages) else {
        throw testValidationFailure(
            code: "missing_page_evidence",
            message: "Import requires at least one route or fingerprint page evidence record.",
            path: "compiled-contract.json.pages"
        )
    }
    guard !contract.actions.isEmpty else {
        throw testValidationFailure(
            code: "missing_actions",
            message: "Import requires at least one compiled action.",
            path: "compiled-contract.json.actions"
        )
    }

    let provenance = TKTestPlanProvenance(
        importerVersion: 1,
        sourceKind: "triton.testrec.compiled-contract",
        sourcePlatform: sourcePlatform,
        contractRef: contractRef
    )
    let steps = try importTestSteps(from: contract.actions)
    let importedPlan = TKTestNormalizedPlan(
        name: manifest.name,
        app: TKTestPlanApp(bundleId: trimmedBundleID),
        device: TKTestPlanDevice(platform: trimmedDevicePlatform),
        settings: TKTestPlanSettings(
            strict: true,
            timeoutMs: 5_000,
            retry: TKTestPlanRetry(count: 0, intervalMs: 250)
        ),
        steps: steps,
        provenance: provenance
    )
    let yaml = renderTritonTestYAML(from: importedPlan)
    let publicOutputName = outputURL.lastPathComponent
    let validated = try validateTritonTestContract(yaml: yaml, inputPath: publicOutputName)
    let validation = TKTestValidationResponse(input: publicOutputName, normalizedPlan: validated)
    try importWritePlanWithoutOverwrite(yaml: yaml, outputURL: outputURL, fileManager: fileManager)

    return TKTestImportResponse(
        input: caseURL.lastPathComponent,
        output: publicOutputName,
        importedPlan: validated,
        validation: validation,
        provenance: provenance,
        suggestedCommands: [
            "triton test validate <written-plan.tritontest.yaml> --json",
            "triton test run <written-plan.tritontest.yaml> --json --evidence-dir <written-plan.tritonevidence>",
        ]
    )
}

private func importSourcePlatformIsIOS(_ value: String?) -> Bool {
    switch value {
    case "ios", "ios-simulator":
        return true
    default:
        return false
    }
}

private func importReadSourcePackage(
    caseURL: URL,
    fileManager: FileManager
) throws -> (manifest: TKTestRecorderManifest, capabilities: TKTestRecorderContractCapabilities) {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: caseURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw testValidationFailure(
            code: "invalid_case_directory",
            message: "test import requires an existing .tritontestcase directory.",
            path: "<case.tritontestcase>"
        )
    }

    let manifestURL = caseURL.appendingPathComponent("manifest.json")
    let resolvedManifestURL = try importRequireContainedRegularFile(
        manifestURL,
        in: caseURL,
        path: "manifest.json",
        fileManager: fileManager
    )
    let manifest: TKTestRecorderManifest
    do {
        manifest = try JSONDecoder().decode(TKTestRecorderManifest.self, from: Data(contentsOf: resolvedManifestURL))
    } catch {
        throw testValidationFailure(
            code: "invalid_json",
            message: "manifest.json must be a valid source package manifest.",
            path: "manifest.json"
        )
    }
    guard manifest.schemaVersion == 1 else {
        throw testValidationFailure(
            code: "unsupported_schema_version",
            message: "manifest.json must use schemaVersion 1.",
            path: "manifest.json.schemaVersion",
            allowed: ["1"]
        )
    }

    let capabilitiesRef = manifest.capabilitiesRef.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !capabilitiesRef.isEmpty,
          !capabilitiesRef.hasPrefix("/"),
          !capabilitiesRef.split(separator: "/").contains("..") else {
        throw testValidationFailure(
            code: "invalid_capabilities_ref",
            message: "manifest.json.capabilitiesRef must be a package-relative path.",
            path: "manifest.json.capabilitiesRef"
        )
    }
    let capabilitiesURL = caseURL.appendingPathComponent(capabilitiesRef)
    let resolvedCapabilitiesURL = try importRequireContainedRegularFile(
        capabilitiesURL,
        in: caseURL,
        path: "contract-capabilities.json",
        fileManager: fileManager
    )
    let capabilities: TKTestRecorderContractCapabilities
    do {
        capabilities = try JSONDecoder().decode(
            TKTestRecorderContractCapabilities.self,
            from: Data(contentsOf: resolvedCapabilitiesURL)
        )
    } catch {
        throw testValidationFailure(
            code: "invalid_json",
            message: "The source package capabilities must be valid JSON.",
            path: "contract-capabilities.json"
        )
    }
    guard capabilities.schemaVersion == 1 else {
        throw testValidationFailure(
            code: "unsupported_schema_version",
            message: "contract-capabilities.json must use schemaVersion 1.",
            path: "contract-capabilities.json.schemaVersion",
            allowed: ["1"]
        )
    }

    let compiledURL = caseURL.appendingPathComponent("compiled-contract.json")
    if fileManager.fileExists(atPath: compiledURL.path) {
        _ = try importRequireContainedRegularFile(
            compiledURL,
            in: caseURL,
            path: "compiled-contract.json",
            fileManager: fileManager
        )
    }
    return (manifest, capabilities)
}

private func importReadCompiledContract(
    caseURL: URL,
    fileManager: FileManager
) throws -> (contract: TKTestRecorderCompiledContract, contractRef: TKTestRecorderReplayContractRef) {
    let contractURL = caseURL.appendingPathComponent("compiled-contract.json")
    guard fileManager.fileExists(atPath: contractURL.path) else {
        throw testValidationFailure(
            code: "missing_compiled_contract",
            message: "test import requires an existing compiled-contract.json; run testrec compile first.",
            path: "compiled-contract.json"
        )
    }
    let resolvedContractURL = try importRequireContainedRegularFile(
        contractURL,
        in: caseURL,
        path: "compiled-contract.json",
        fileManager: fileManager
    )

    let data: Data
    let contract: TKTestRecorderCompiledContract
    do {
        data = try Data(contentsOf: resolvedContractURL)
        contract = try JSONDecoder().decode(TKTestRecorderCompiledContract.self, from: data)
    } catch {
        throw testValidationFailure(
            code: "invalid_json",
            message: "compiled-contract.json must be a valid compiled testrec contract.",
            path: "compiled-contract.json"
        )
    }
    guard contract.schemaVersion == 1 else {
        throw testValidationFailure(
            code: "unsupported_schema_version",
            message: "compiled-contract.json must use schemaVersion 1.",
            path: "compiled-contract.json.schemaVersion",
            allowed: ["1"]
        )
    }
    guard contract.kind == "triton.testrec.compiled-contract" else {
        throw testValidationFailure(
            code: "invalid_json",
            message: "compiled-contract.json must be a compiled testrec contract.",
            path: "compiled-contract.json.kind"
        )
    }
    return (
        contract,
        TKTestRecorderReplayContractRef(
            path: "compiled-contract.json",
            byteCount: data.count,
            digestAlgorithm: "fnv1a64",
            digest: fnv1a64Hex(data)
        )
    )
}

private func importRequireContainedRegularFile(
    _ url: URL,
    in caseURL: URL,
    path: String,
    fileManager: FileManager
) throws -> URL {
    guard fileManager.fileExists(atPath: url.path) else {
        throw testValidationFailure(
            code: "missing_required_file",
            message: "The source package is missing a required import artifact.",
            path: path
        )
    }
    let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
    guard importPath(resolvedURL, isInside: caseURL) else {
        throw testValidationFailure(
            code: "invalid_source_contract",
            message: "Source import artifacts must remain inside the .tritontestcase package.",
            path: path
        )
    }
    let values = try resolvedURL.resourceValues(forKeys: [.isRegularFileKey])
    guard values.isRegularFile == true else {
        throw testValidationFailure(
            code: "invalid_source_contract",
            message: "Source import artifacts must be regular files.",
            path: path
        )
    }
    return resolvedURL
}

private func importUnsupportedCapabilities(
    in capabilities: TKTestRecorderContractCapabilities
) -> [String] {
    let supportedActions: Set<String> = ["tap", "type", "paste", "scroll", "swipe", "wait", "assert", "open-url", "screenshot", "evidence"]
    let supportedPages: Set<String> = ["route", "ax", "dom", "semantic", "fingerprint", "screenshot", "webview-url"]
    let supportedNetwork: Set<String> = ["fixture", "passthrough", "mock", "block", "throttle", "map-local", "map-remote"]
    return capabilities.actions.filter { !supportedActions.contains($0) }
        + capabilities.pages.filter { !supportedPages.contains($0) }
        + capabilities.network.filter { !supportedNetwork.contains($0) }
}

private func importPath(_ candidate: URL, isInside root: URL) -> Bool {
    let rootPath = root.standardizedFileURL.path.hasSuffix("/")
        ? root.standardizedFileURL.path
        : root.standardizedFileURL.path + "/"
    return candidate.standardizedFileURL.path.hasPrefix(rootPath)
}

private func importResolvedOutputURL(_ requestedURL: URL, fileManager: FileManager) -> URL {
    var existingAncestor = requestedURL
    var missingComponents: [String] = []
    while !fileManager.fileExists(atPath: existingAncestor.path) {
        let parent = existingAncestor.deletingLastPathComponent()
        guard parent.path != existingAncestor.path else { break }
        missingComponents.insert(existingAncestor.lastPathComponent, at: 0)
        existingAncestor = parent
    }
    var resolved = existingAncestor.resolvingSymlinksInPath().standardizedFileURL
    for component in missingComponents {
        resolved.appendPathComponent(component)
    }
    return resolved.standardizedFileURL
}

private func importWritePlanWithoutOverwrite(
    yaml: String,
    outputURL: URL,
    fileManager: FileManager
) throws {
    let parent = outputURL.deletingLastPathComponent()
    let temporaryURL = parent.appendingPathComponent(".triton-test-import-\(UUID().uuidString).tmp")
    do {
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        try yaml.write(to: temporaryURL, atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(at: temporaryURL) }
        do {
            try fileManager.linkItem(at: temporaryURL, to: outputURL)
        } catch {
            if fileManager.fileExists(atPath: outputURL.path) {
                throw testValidationFailure(
                    code: "output_already_exists",
                    message: "Refusing to overwrite an existing output plan.",
                    path: "--output"
                )
            }
            throw testValidationFailure(
                code: "output_write_failed",
                message: "Could not write the validated import output.",
                path: "--output"
            )
        }
    } catch let failure as TKTestValidationFailure {
        throw failure
    } catch {
        throw testValidationFailure(
            code: "output_write_failed",
            message: "Could not write the validated import output.",
            path: "--output"
        )
    }
}

private func importSafeSourceErrorPath(_ path: String) -> String {
    if path.hasPrefix("manifest.json") { return "manifest.json" }
    if path.hasPrefix("compiled-contract.json") { return "compiled-contract.json" }
    if path.hasPrefix("contract-capabilities.json") { return "contract-capabilities.json" }
    return "$"
}

private func importHasPageEvidence(_ pages: TKTestRecorderCompiledPages) -> Bool {
    let hasRoute = pages.routes.contains {
        importHasMeaningfulText($0.route) || importHasMeaningfulText($0.url)
    }
    let hasFingerprint = pages.fingerprints.contains {
        importHasMeaningfulText($0.pageId)
            || importHasMeaningfulText($0.route)
            || importHasMeaningfulText($0.hash)
    }
    return hasRoute || hasFingerprint
}

private func importTestSteps(from actions: [TKTestRecorderCompiledAction]) throws -> [TKTestPlanStep] {
    var steps: [TKTestPlanStep] = [
        TKTestPlanStep(
            index: 0,
            id: "import-bootstrap-launch",
            kind: "action",
            type: "launch",
            optional: false,
            timeoutMs: nil,
            point: nil,
            selector: nil
        ),
    ]

    for (offset, action) in actions.enumerated() {
        guard action.index == offset + 1 else {
            throw testValidationFailure(
                code: "source_identity_mismatch",
                message: "compiled action indexes must be contiguous and start at 1.",
                path: "compiled-contract.json.actions[\(offset)].index"
            )
        }
        guard action.sourcePath == "actions.jsonl:\(action.index)" else {
            throw testValidationFailure(
                code: "invalid_source_contract",
                message: "compiled action sourcePath must be a canonical actions.jsonl reference.",
                path: "compiled-contract.json.actions[\(offset)].sourcePath"
            )
        }

        let index = offset + 1
        let id = String(format: "import-%03d", index)
        switch action.action {
        case "tap":
            let selector = try importExactAXSelector(from: action, offset: offset)
            steps.append(TKTestPlanStep(
                index: steps.count,
                id: id,
                kind: "action",
                type: "tap",
                optional: false,
                timeoutMs: nil,
                point: nil,
                selector: selector
            ))
        case "assert":
            let selector = try importExactAXSelector(from: action, offset: offset)
            steps.append(TKTestPlanStep(
                index: steps.count,
                id: id,
                kind: "assertion",
                type: "assertVisible",
                optional: false,
                timeoutMs: nil,
                point: nil,
                selector: selector
            ))
        case "screenshot":
            steps.append(TKTestPlanStep(
                index: steps.count,
                id: id,
                kind: "observation",
                type: "takeScreenshot",
                optional: false,
                timeoutMs: nil,
                point: nil,
                selector: nil
            ))
        default:
            throw testValidationFailure(
                code: "unmapped_contract_feature",
                message: "A compiled action cannot be represented without changing its semantics.",
                path: "compiled-contract.json.actions[\(offset)]"
            )
        }
    }
    return steps
}

private func importExactAXSelector(
    from action: TKTestRecorderCompiledAction,
    offset: Int
) throws -> TKTestPlanSelector {
    guard let rawText = action.targetText else {
        throw testValidationFailure(
            code: "unmapped_contract_feature",
            message: "A compiled action has no semantic target text.",
            path: "compiled-contract.json.actions[\(offset)].targetText"
        )
    }
    let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text != "<target>", text != "<text>", !importTargetLooksSensitive(text) else {
        throw testValidationFailure(
            code: "unmapped_contract_feature",
            message: "A compiled action has an empty, sentinel, or sensitive semantic target.",
            path: "compiled-contract.json.actions[\(offset)].targetText"
        )
    }
    return TKTestPlanSelector(text: text, match: "exact", source: "ax")
}

private func importTargetLooksSensitive(_ value: String) -> Bool {
    guard !testRecorderLooksSensitive(value) else { return true }
    let decimalDigits = value.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
    return decimalDigits.count >= 11
}

private func importHasMeaningfulText(_ value: String?) -> Bool {
    guard let value else { return false }
    return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func importQualityFindingIndex(
    _ finding: TKTestRecorderQualityFinding,
    in findings: [TKTestRecorderQualityFinding]
) -> Int {
    findings.firstIndex(of: finding) ?? 0
}
