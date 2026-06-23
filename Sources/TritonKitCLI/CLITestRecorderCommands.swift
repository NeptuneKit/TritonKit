import ArgumentParser
import Foundation

struct TestRecorderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "testrec",
        abstract: "Inspect and compile .tritontestcase semantic replay contracts",
        subcommands: [
            TestRecorderStart.self,
            TestRecorderEvent.self,
            TestRecorderStop.self,
            TestRecorderInspect.self,
            TestRecorderCompile.self,
            TestRecorderProposals.self,
            TestRecorderMatchPage.self,
            TestRecorderReplay.self,
        ]
    )
}

struct TestRecorderStart: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start an explicit-event .tritontestcase recording session"
    )

    @Option(help: "Source platform: ios, android, harmony, or web") var platform: String
    @Option(name: .customLong("case"), help: "Recorded test case name") var caseName: String
    @Option(help: "Output .tritontestcase directory path") var output: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestRecorderStartCommand(
            platform: platform,
            caseName: caseName,
            output: output,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestRecorderEvent: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "event",
        abstract: "Append an explicit JSON event to a testrec recording session"
    )

    @Option(help: "Session id returned by testrec start") var session: String
    @Option(help: "Event kind: action, network, page-route, page-fingerprint, or page-snapshot") var kind: String
    @Option(name: .customLong("payload-json"), help: "Single event JSON object") var payloadJSON: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestRecorderEventCommand(
            session: session,
            kind: kind,
            payloadJSON: payloadJSON,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestRecorderStop: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop an explicit-event testrec recording session"
    )

    @Option(help: "Session id returned by testrec start") var session: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestRecorderStopCommand(session: session, format: effectiveFormat(format, json: json))
    }
}

struct TestRecorderInspect: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect a .tritontestcase directory package"
    )

    @Argument(help: ".tritontestcase directory path") var input: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestRecorderInspectCommand(input: input, format: effectiveFormat(format, json: json))
    }
}

struct TestRecorderCompile: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "compile",
        abstract: "Compile-preflight a .tritontestcase directory package"
    )

    @Argument(help: ".tritontestcase directory path") var input: String
    @Option(help: "Compiled contract output path; defaults to <case>/compiled-contract.json") var output: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestRecorderCompileCommand(input: input, output: output, format: effectiveFormat(format, json: json))
    }
}

struct TestRecorderReplay: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "replay",
        abstract: "Plan or locally simulate a .tritontestcase replay"
    )

    @Argument(help: ".tritontestcase directory path") var input: String
    @Option(help: "Target platform: ios, android, harmony, or web") var platform: String
    @Option(help: "Optional target device selector") var device: String?
    @Flag(name: .customLong("dry-run"), help: "Only build the replay plan without executing") var dryRun = false
    @Option(help: "Replay executor. Current non-device executor: local-simulated") var executor: String?
    @Option(name: .customLong("evidence-dir"), help: "Optional .tritonevidence output directory for local-simulated replay") var evidenceDir: String?
    @Option(name: .customLong("target-fingerprints-json"), help: "Optional target-side page fingerprint object, array, or {pages:[...]} for local-simulated replay") var targetFingerprintsJSON: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestRecorderReplayCommand(
            input: input,
            platform: platform,
            device: device,
            dryRun: dryRun,
            executor: executor,
            evidenceDir: evidenceDir,
            targetFingerprintsJSON: targetFingerprintsJSON,
            format: effectiveFormat(format, json: json)
        )
    }
}

struct TestRecorderProposals: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "proposals",
        abstract: "Read compile proposals for a .tritontestcase package"
    )

    @Argument(help: ".tritontestcase directory path") var input: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestRecorderProposalsCommand(input: input, format: effectiveFormat(format, json: json))
    }
}

struct TestRecorderMatchPage: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "match-page",
        abstract: "Score a target-side page fingerprint against a compiled .tritontestcase page"
    )

    @Argument(help: ".tritontestcase directory path") var input: String
    @Option(help: "Compiled source page selector: pageId, route, or fingerprint index") var page: String
    @Option(name: .customLong("candidate-json"), help: "Target-side page fingerprint JSON object") var candidateJSON: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        try runTestRecorderMatchPageCommand(
            input: input,
            page: page,
            candidateJSON: candidateJSON,
            format: effectiveFormat(format, json: json)
        )
    }
}

private func runTestRecorderStartCommand(platform: String, caseName: String, output: String, format: ClientOutputFormat) throws {
    do {
        let response = try startTritonTestRecorderSession(
            caseName: caseName,
            sourcePlatform: platform,
            outputPath: output
        )
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("sessionId: \(response.sessionId)")
            print("casePath: \(response.casePath)")
        }
    } catch let failure as TKTestRecorderValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(TKTestRecorderValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}

private func runTestRecorderEventCommand(session: String, kind: String, payloadJSON: String, format: ClientOutputFormat) throws {
    do {
        let response = try appendTritonTestRecorderEvent(
            sessionID: session,
            eventKind: kind,
            payloadJSON: payloadJSON
        )
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("sessionId: \(response.sessionId)")
            print("eventKind: \(response.eventKind)")
            print("eventPath: \(response.eventPath)")
            print("eventCount: \(response.eventCount)")
        }
    } catch let failure as TKTestRecorderValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(TKTestRecorderValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}

private func runTestRecorderStopCommand(session: String, format: ClientOutputFormat) throws {
    do {
        let response = try stopTritonTestRecorderSession(sessionID: session)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("sessionId: \(response.sessionId)")
            print("casePath: \(response.casePath)")
            print("eventCount: \(response.eventCount)")
        }
    } catch let failure as TKTestRecorderValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(TKTestRecorderValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}

private func runTestRecorderInspectCommand(input: String, format: ClientOutputFormat) throws {
    do {
        let response = try inspectTritonTestCase(path: input)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("name: \(response.manifest.name)")
            print("stage: \(response.lifecycle.stage)")
            print("health: \(response.lifecycle.health)")
            print("actions: \(response.capabilities.actions.joined(separator: ","))")
            print("pages: \(response.capabilities.pages.joined(separator: ","))")
            print("network: \(response.capabilities.network.joined(separator: ","))")
            if !response.unsupportedCapabilities.isEmpty {
                print("unsupported: \(response.unsupportedCapabilities.map { "\($0.domain):\($0.name)" }.joined(separator: ","))")
            }
        }
    } catch let failure as TKTestRecorderValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(TKTestRecorderValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}

private func runTestRecorderCompileCommand(input: String, output: String?, format: ClientOutputFormat) throws {
    do {
        let response = try compileTritonTestCase(path: input, writeContract: true, outputPath: output)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("status: \(response.status)")
            print("actions: \(response.summary.actionEventCount)")
            print("network: \(response.summary.networkEventCount)")
            print("pageRoutes: \(response.summary.pageRouteEventCount)")
            print("pageFingerprints: \(response.summary.pageFingerprintCount)")
            if let artifact = response.contractArtifact {
                print("compiledContract: \(artifact.path)")
            }
            if let artifact = response.proposalArtifact {
                print("compileProposals: \(artifact.path)")
            }
            if !response.warnings.isEmpty {
                print("warnings: \(response.warnings.map { $0.code }.joined(separator: ","))")
            }
        }
    } catch let failure as TKTestRecorderValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(TKTestRecorderValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}

private func runTestRecorderReplayCommand(input: String, platform: String, device: String?, dryRun: Bool, executor: String?, evidenceDir: String?, targetFingerprintsJSON: String?, format: ClientOutputFormat) throws {
    do {
        if !dryRun {
            _ = try validateTestRecorderReplayExecutor(executor)
            let targetFingerprints = try decodeTestRecorderTargetFingerprintsJSON(targetFingerprintsJSON)
            let response = try replayTritonTestCaseLocalSimulated(path: input, platform: platform, device: device, evidenceDirectory: evidenceDir, targetFingerprints: targetFingerprints)
            switch format {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("ok: \(response.ok)")
                print("dryRun: \(response.dryRun)")
                print("executor: \(response.executor)")
                print("platform: \(response.platform)")
                if let device = response.device {
                    print("device: \(device)")
                }
                print("status: \(response.status)")
                if let evidenceDir = response.evidenceDir {
                    print("evidenceDir: \(evidenceDir)")
                }
                print("steps: \(response.steps.count)")
                if !response.blockers.isEmpty {
                    print("blockers: \(response.blockers.map { $0.code }.joined(separator: ","))")
                }
            }
            return
        }
        let response = try replayTritonTestCase(path: input, platform: platform, device: device, dryRun: dryRun)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("dryRun: \(response.dryRun)")
            print("platform: \(response.platform)")
            if let device = response.device {
                print("device: \(device)")
            }
            print("status: \(response.status)")
            print("plannedSteps: \(response.plannedSteps.count)")
            if !response.blockers.isEmpty {
                print("blockers: \(response.blockers.map { $0.code }.joined(separator: ","))")
            }
        }
    } catch let failure as TKTestRecorderValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(TKTestRecorderValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}

private func runTestRecorderProposalsCommand(input: String, format: ClientOutputFormat) throws {
    do {
        let response = try inspectTritonTestCaseProposals(path: input)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("proposals: \(response.proposalCount)")
            if !response.proposals.isEmpty {
                print("proposalKinds: \(response.proposals.map { $0.proposalKind }.joined(separator: ","))")
            }
        }
    } catch let failure as TKTestRecorderValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(TKTestRecorderValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}

private func runTestRecorderMatchPageCommand(input: String, page: String, candidateJSON: String, format: ClientOutputFormat) throws {
    do {
        let response = try matchTritonTestCasePageFingerprint(path: input, page: page, candidateJSON: candidateJSON)
        switch format {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("ok: true")
            print("page: \(response.page)")
            print("score: \(response.score)")
            print("decision: \(response.decision)")
            print("llmUsed: \(response.llmUsed)")
            print("llmDecisionAuthority: \(response.llmDecisionAuthority)")
        }
    } catch let failure as TKTestRecorderValidationFailure {
        switch format {
        case .json:
            print(try encodeJSON(TKTestRecorderValidationFailureResponse(failure)))
        case .text:
            print("\(failure.detail.code): \(failure.detail.path): \(failure.detail.message)")
        }
        throw ExitCode.failure
    }
}
