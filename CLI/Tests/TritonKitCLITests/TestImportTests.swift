import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct TestImportTests {
    @Test("import maps a compiled iOS tap/assert contract into a deterministic validated Simulator test plan")
    func importsCompiledIOSCaseDeterministically() throws {
        let caseURL = try makeImportCase(
            actions: [
                #"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#,
                #"{"id":"a2","kind":"assert","target":{"label":"Fixture Home"}}"#,
            ]
        )
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }

        let firstOutput = caseURL.deletingLastPathComponent().appendingPathComponent("first.tritontest.yaml")
        let secondOutput = caseURL.deletingLastPathComponent().appendingPathComponent("second.tritontest.yaml")
        let optionalSourceRef = try testRecorderCompiledContractRef(caseURL: caseURL)
        let sourceRef = try #require(optionalSourceRef)
        let sourceSnapshot = try importPackageSnapshot(caseURL)

        let first = try importTritonTestCase(
            input: caseURL.path,
            output: firstOutput.path,
            bundleID: "com.neptunekit.tritonkit.testfixture",
            devicePlatform: "ios-simulator",
            expectedCompiledDigest: sourceRef.digest
        )
        let second = try importTritonTestCase(
            input: caseURL.path,
            output: secondOutput.path,
            bundleID: "com.neptunekit.tritonkit.testfixture",
            devicePlatform: "ios-simulator"
        )

        #expect(first.ok == true)
        #expect(first.kind == "triton.test.import-result")
        #expect(first.input == caseURL.lastPathComponent)
        #expect(first.output == firstOutput.lastPathComponent)
        #expect(first.provenance.sourceKind == "triton.testrec.compiled-contract")
        #expect(first.provenance.contractRef.path == "compiled-contract.json")
        #expect(first.provenance.contractRef.digestAlgorithm == "fnv1a64")
        #expect(first.provenance.contractRef == sourceRef)
        #expect(first.validation.ok == true)
        #expect(first.validation.input == firstOutput.lastPathComponent)
        #expect(first.validation.normalizedPlan.provenance == first.provenance)
        #expect(first.importedPlan.app.bundleId == "com.neptunekit.tritonkit.testfixture")
        #expect(first.importedPlan.device.platform == "ios-simulator")
        #expect(first.importedPlan.steps.map(\.type) == ["launch", "tap", "assertVisible"])
        #expect(first.importedPlan.steps[1].selector?.text == "Go Home")
        #expect(first.importedPlan.steps[2].selector?.text == "Fixture Home")
        #expect(first.unmapped.isEmpty)
        #expect(second.provenance.contractRef.digest == first.provenance.contractRef.digest)

        let firstYAML = try String(contentsOf: firstOutput, encoding: .utf8)
        let secondYAML = try String(contentsOf: secondOutput, encoding: .utf8)
        let firstResponseJSON = try encodeJSON(first)
        #expect(firstYAML == secondYAML)
        #expect(firstYAML.contains("provenance:"))
        #expect(!firstYAML.contains(caseURL.path))
        #expect(!firstResponseJSON.contains(caseURL.path))
        #expect(!firstResponseJSON.contains(caseURL.deletingLastPathComponent().path))

        let validated = try validateTritonTestContract(yaml: firstYAML, inputPath: firstOutput.path)
        #expect(validated.steps.map(\.type) == ["launch", "tap", "assertVisible"])
        #expect(try importPackageSnapshot(caseURL) == sourceSnapshot)
    }

    @Test("import fails closed without an existing compiled contract")
    func importFailsClosedWithoutCompiledContract() throws {
        let caseURL = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#], compile: false)
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let output = caseURL.deletingLastPathComponent().appendingPathComponent("missing.tritontest.yaml")

        let failure = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: output.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }

        #expect(failure?.detail.code == "missing_compiled_contract")
        #expect(failure?.detail.path == "compiled-contract.json")
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test("import validates the expected compiled digest and never overwrites an existing plan")
    func importRejectsDigestMismatchAndExistingOutput() throws {
        let caseURL = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#])
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let output = caseURL.deletingLastPathComponent().appendingPathComponent("digest-mismatch.tritontest.yaml")

        let mismatch = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: output.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator",
                expectedCompiledDigest: "0000000000000000"
            )
        }

        #expect(mismatch?.detail.code == "compiled_digest_mismatch")
        #expect(!FileManager.default.fileExists(atPath: output.path))

        let sentinel = "existing plan must remain unchanged\n"
        try sentinel.write(to: output, atomically: true, encoding: .utf8)
        let overwrite = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: output.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }

        #expect(overwrite?.detail.code == "output_already_exists")
        #expect(try String(contentsOf: output, encoding: .utf8) == sentinel)
    }

    @Test("import allows legacy pending metadata but fails closed on a concrete redaction finding")
    func importFailsClosedWhenCompiledContractHasRedactionFinding() throws {
        let caseURL = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#])
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try addImportQualityFinding(to: caseURL, proposalKind: "contract.redaction")
        let output = caseURL.deletingLastPathComponent().appendingPathComponent("redaction.tritontest.yaml")

        let failure = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: output.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }

        #expect(failure?.detail.code == "redaction_review_required")
        #expect(failure?.detail.path == "compiled-contract.json.qualityFindings[0]")
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test("import rejects a compiled contract whose manifest identity changed")
    func importRejectsSourceIdentityMismatch() throws {
        let caseURL = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#])
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        try writeImportManifest(to: caseURL, name: "mutated-source", sourcePlatform: "ios", redactionStatus: "redacted")
        let output = caseURL.deletingLastPathComponent().appendingPathComponent("identity.tritontest.yaml")

        let failure = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: output.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }

        #expect(failure?.detail.code == "source_identity_mismatch")
        #expect(failure?.detail.path == "compiled-contract.json.caseName")
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test("import rejects unsupported action and missing page evidence instead of fabricating a step")
    func importRejectsUnmappedActionAndMissingPageEvidence() throws {
        let unmappedCase = try makeImportCase(actions: [#"{"id":"a1","kind":"scroll","target":{"label":"Fixture List"}}"#])
        defer { try? FileManager.default.removeItem(at: unmappedCase.deletingLastPathComponent()) }
        let unmappedOutput = unmappedCase.deletingLastPathComponent().appendingPathComponent("unmapped.tritontest.yaml")

        let unmapped = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: unmappedCase.path,
                output: unmappedOutput.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }

        #expect(unmapped?.detail.code == "unmapped_contract_feature")
        #expect(unmapped?.detail.path == "compiled-contract.json.actions[0]")
        #expect(!FileManager.default.fileExists(atPath: unmappedOutput.path))

        let pageMissingCase = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#])
        defer { try? FileManager.default.removeItem(at: pageMissingCase.deletingLastPathComponent()) }
        try removeImportPageEvidence(from: pageMissingCase)
        let pageMissingOutput = pageMissingCase.deletingLastPathComponent().appendingPathComponent("page-missing.tritontest.yaml")

        let pageMissing = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: pageMissingCase.path,
                output: pageMissingOutput.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }

        #expect(pageMissing?.detail.code == "missing_page_evidence")
        #expect(pageMissing?.detail.path == "compiled-contract.json.pages")
        #expect(!FileManager.default.fileExists(atPath: pageMissingOutput.path))
    }

    @Test("import rejects sensitive target text without echoing it or mutating the source package")
    func importRejectsSensitiveTargetWithoutLeakage() throws {
        let sensitiveTarget = "4111 1111 1111 1111"
        let caseURL = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"4111 1111 1111 1111"}}"#])
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let output = caseURL.deletingLastPathComponent().appendingPathComponent("sensitive.tritontest.yaml")
        let sourceSnapshot = try importPackageSnapshot(caseURL)

        let failure = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: output.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }

        #expect(failure?.detail.code == "unmapped_contract_feature")
        #expect(failure?.detail.message.contains(sensitiveTarget) == false)
        #expect(!FileManager.default.fileExists(atPath: output.path))
        #expect(try importPackageSnapshot(caseURL) == sourceSnapshot)
    }

    @Test("import reports output write failure without creating a plan")
    func importReportsOutputWriteFailureAtomically() throws {
        let caseURL = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#])
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let blockedParent = caseURL.deletingLastPathComponent().appendingPathComponent("not-a-directory")
        try "block output parent".write(to: blockedParent, atomically: true, encoding: .utf8)
        let output = blockedParent.appendingPathComponent("plan.tritontest.yaml")

        let failure = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: output.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }

        #expect(failure?.detail.code == "output_write_failed")
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test("import rejects source-contained output and symlinked source artifacts")
    func importRejectsEscapingPackageBoundaries() throws {
        let caseURL = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#])
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let sourceOutput = caseURL.appendingPathComponent("inside-source.tritontest.yaml")

        let sourceOutputFailure = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: sourceOutput.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }
        #expect(sourceOutputFailure?.detail.code == "invalid_output_path")
        #expect(!FileManager.default.fileExists(atPath: sourceOutput.path))

        let alias = caseURL.deletingLastPathComponent().appendingPathComponent("source-alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: caseURL)
        let aliasedOutput = alias.appendingPathComponent("also-inside-source.tritontest.yaml")
        let aliasFailure = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: aliasedOutput.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }
        #expect(aliasFailure?.detail.code == "invalid_output_path")

        let contractURL = caseURL.appendingPathComponent("compiled-contract.json")
        let externalContract = caseURL.deletingLastPathComponent().appendingPathComponent("outside-contract.json")
        try FileManager.default.moveItem(at: contractURL, to: externalContract)
        try FileManager.default.createSymbolicLink(at: contractURL, withDestinationURL: externalContract)
        let externalOutput = caseURL.deletingLastPathComponent().appendingPathComponent("outside-output.tritontest.yaml")
        let artifactFailure = #expect(throws: TKTestValidationFailure.self) {
            _ = try importTritonTestCase(
                input: caseURL.path,
                output: externalOutput.path,
                bundleID: "com.neptunekit.tritonkit.testfixture",
                devicePlatform: "ios-simulator"
            )
        }
        #expect(artifactFailure?.detail.code == "invalid_source_contract")
        #expect(artifactFailure?.detail.path == "compiled-contract.json")
        #expect(!FileManager.default.fileExists(atPath: externalOutput.path))
    }

    @Test("imported provenance survives the existing runner normalized-plan artifact")
    func importedProvenanceSurvivesRunnerEvidencePlan() async throws {
        let caseURL = try makeImportCase(actions: [#"{"id":"a1","kind":"tap","target":{"label":"Go Home"}}"#])
        defer { try? FileManager.default.removeItem(at: caseURL.deletingLastPathComponent()) }
        let output = caseURL.deletingLastPathComponent().appendingPathComponent("runner-provenance.tritontest.yaml")
        let evidence = caseURL.deletingLastPathComponent().appendingPathComponent("runner-provenance.tritonevidence")
        let imported = try importTritonTestCase(
            input: caseURL.path,
            output: output.path,
            bundleID: "com.neptunekit.tritonkit.testfixture",
            devicePlatform: "ios-simulator"
        )

        let run = try await runTritonTest(
            input: output.path,
            evidenceDirectory: evidence.path,
            target: "fixture-target",
            host: "127.0.0.1",
            port: 1,
            executor: ImportPlanExecutor()
        )
        let persisted = try JSONDecoder().decode(
            TKTestNormalizedPlan.self,
            from: Data(contentsOf: evidence.appendingPathComponent("normalized-plan.json"))
        )

        #expect(run.ok)
        #expect(run.normalizedPlan.provenance == imported.provenance)
        #expect(persisted.provenance == imported.provenance)
    }

    @Test("test schema declares offline import with explicit bundle identity and Simulator target")
    func testSchemaDeclaresOfflineImportContract() throws {
        let schema = try #require(commandSchemaMap()["test"])
        let importSchema = try #require(schema.subcommands.first { $0.name == "import" })

        #expect(schema.runtimeScope.contains("import"))
        #expect(importSchema.requiredOptions == ["<case.tritontestcase>", "--output", "--bundle-id", "--device-platform"])
        #expect(importSchema.outputSelectors.contains("test.import"))
        #expect(importSchema.failureCodes.contains("missing_compiled_contract"))
        #expect(importSchema.failureCodes.contains("unmapped_contract_feature"))
        #expect(schema.outputContracts.contains { $0.selector == "test.import" })

        _ = try TritonKitCLI.parseAsRoot([
            "test",
            "import",
            "fixture.tritontestcase",
            "--output", "fixture.tritontest.yaml",
            "--bundle-id", "com.neptunekit.tritonkit.testfixture",
            "--device-platform", "ios-simulator",
            "--json",
        ])
    }
}

private func makeImportCase(
    actions: [String],
    name: String = "fixture-login",
    sourcePlatform: String = "ios",
    redactionStatus: String = "pending",
    includePageEvidence: Bool = true,
    compile: Bool = true
) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-test-import-\(UUID().uuidString)", isDirectory: true)
    let caseURL = root.appendingPathComponent("fixture.tritontestcase", isDirectory: true)
    let sessions = root.appendingPathComponent("sessions", isDirectory: true)
    let started = try startTritonTestRecorderSession(
        caseName: name,
        sourcePlatform: sourcePlatform,
        outputPath: caseURL.path,
        sessionStoreRoot: sessions
    )

    for action in actions {
        _ = try appendTritonTestRecorderEvent(
            sessionID: started.sessionId,
            eventKind: "action",
            payloadJSON: action,
            sessionStoreRoot: sessions
        )
    }
    if includePageEvidence {
        _ = try appendTritonTestRecorderEvent(
            sessionID: started.sessionId,
            eventKind: "page-route",
            payloadJSON: #"{"id":"p1","route":"fixture-login"}"#,
            sessionStoreRoot: sessions
        )
    }
    _ = try stopTritonTestRecorderSession(sessionID: started.sessionId, sessionStoreRoot: sessions)
    try writeImportManifest(to: caseURL, name: name, sourcePlatform: sourcePlatform, redactionStatus: redactionStatus)
    if compile {
        _ = try compileTritonTestCase(path: caseURL.path, writeContract: true)
    }
    return caseURL
}

private func addImportQualityFinding(to caseURL: URL, proposalKind: String) throws {
    let contractURL = caseURL.appendingPathComponent("compiled-contract.json")
    var object = try importJSONObject(at: contractURL)
    object["qualityFindings"] = [[
        "code": "privacy_candidate",
        "path": "actions.jsonl:1",
        "severity": "review",
        "message": "fixture redaction review required",
        "proposalKind": proposalKind,
    ]]
    try writeImportJSONObject(object, to: contractURL)
}

private func removeImportPageEvidence(from caseURL: URL) throws {
    let contractURL = caseURL.appendingPathComponent("compiled-contract.json")
    var object = try importJSONObject(at: contractURL)
    var pages = try #require(object["pages"] as? [String: Any])
    pages["routeEventCount"] = 0
    pages["fingerprintCount"] = 0
    pages["routes"] = []
    pages["fingerprints"] = []
    object["pages"] = pages
    try writeImportJSONObject(object, to: contractURL)
}

private func importJSONObject(at url: URL) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
}

private func writeImportJSONObject(_ object: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url, options: .atomic)
}

private func writeImportManifest(to caseURL: URL, name: String, sourcePlatform: String, redactionStatus: String) throws {
    try """
    {
      "schemaVersion": 1,
      "kind": "triton.testcase.v1",
      "name": "\(name)",
      "sourcePlatform": "\(sourcePlatform)",
      "redactionStatus": "\(redactionStatus)",
      "truncationStatus": "not-truncated"
    }
    """.write(to: caseURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
}

private func importPackageSnapshot(_ caseURL: URL) throws -> [String: Data] {
    guard let enumerator = FileManager.default.enumerator(
        at: caseURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw CocoaError(.fileNoSuchFile)
    }

    var snapshot: [String: Data] = [:]
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { continue }
        let relativePath = url.path.replacingOccurrences(of: caseURL.path + "/", with: "")
        snapshot[relativePath] = try Data(contentsOf: url)
    }
    return snapshot
}

private struct ImportPlanExecutor: TKTestRunPrimitiveExecutor {
    func execute(
        step: TKTestPlanStep,
        plan: TKTestNormalizedPlan,
        context: TKTestRunExecutionContext
    ) async throws -> TKTestRunPrimitiveOutcome {
        .passed(command: ["fixture", step.type])
    }
}
