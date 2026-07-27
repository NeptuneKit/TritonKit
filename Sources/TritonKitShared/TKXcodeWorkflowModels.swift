import Foundation

public struct TKXcodeWorkspaceDefaults: Codable, Equatable {
    public let workspace: String?
    public let project: String?
    public let package: String?
    public let scheme: String
    public let configuration: String
    public let sdk: String
    public let destination: String?
    public let derivedDataPath: String

    public init(
        workspace: String? = nil,
        project: String? = nil,
        package: String? = nil,
        scheme: String,
        configuration: String = "Debug",
        sdk: String = "iphonesimulator",
        destination: String? = nil,
        derivedDataPath: String = ".triton/DerivedData"
    ) {
        self.workspace = workspace
        self.project = project
        self.package = package
        self.scheme = scheme
        self.configuration = configuration
        self.sdk = sdk
        self.destination = destination
        self.derivedDataPath = derivedDataPath
    }
}

public struct TKXcodeDerivedDataCacheInfo: Codable, Equatable {
    public let path: String
    public let exists: Bool
    public let cacheState: String
    public let incrementalExpected: Bool
    public let cleanupPolicy: String
    public let guidance: String

    public init(
        path: String,
        exists: Bool,
        cacheState: String,
        incrementalExpected: Bool,
        cleanupPolicy: String,
        guidance: String
    ) {
        self.path = path
        self.exists = exists
        self.cacheState = cacheState
        self.incrementalExpected = incrementalExpected
        self.cleanupPolicy = cleanupPolicy
        self.guidance = guidance
    }
}

public enum TKXcodeContainerKind: String, Codable, Equatable {
    case workspace
    case project
    case package
}

public struct TKXcodeContainerReference: Codable, Equatable {
    public let kind: TKXcodeContainerKind
    public let name: String
    public let path: String

    public init(kind: TKXcodeContainerKind, name: String, path: String) {
        self.kind = kind
        self.name = name
        self.path = path
    }
}

public struct TKXcodeDiscoveryResult: Codable, Equatable {
    public let ok: Bool
    public let path: String
    public let workspaces: [TKXcodeContainerReference]
    public let projects: [TKXcodeContainerReference]
    public let packages: [TKXcodeContainerReference]
    public let recommendedContainer: TKXcodeContainerReference?
    public let ambiguous: Bool

    public init(
        ok: Bool = true,
        path: String,
        workspaces: [TKXcodeContainerReference],
        projects: [TKXcodeContainerReference],
        packages: [TKXcodeContainerReference],
        recommendedContainer: TKXcodeContainerReference?
    ) {
        self.ok = ok
        self.path = path
        self.workspaces = workspaces
        self.projects = projects
        self.packages = packages
        self.recommendedContainer = recommendedContainer
        self.ambiguous = recommendedContainer == nil && workspaces.count + projects.count + packages.count > 1
    }
}

public enum TKXcodeProjectDiscovery {
    public static func discover(path: String, maxDepth: Int = 8) throws -> TKXcodeDiscoveryResult {
        let root = URL(fileURLWithPath: path)
        let rootDepth = root.standardizedFileURL.pathComponents.count
        var workspaces: [TKXcodeContainerReference] = []
        var projects: [TKXcodeContainerReference] = []
        var packages: [TKXcodeContainerReference] = []

        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw TKXcodeDiscoveryError.pathNotFound(path)
        }

        for case let url as URL in enumerator {
            let depth = url.standardizedFileURL.pathComponents.count - rootDepth
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            let name = url.lastPathComponent
            if shouldSkipDirectory(name) {
                enumerator.skipDescendants()
                continue
            }
            if name.hasSuffix(".xcworkspace") {
                workspaces.append(TKXcodeContainerReference(kind: .workspace, name: name, path: url.path))
                enumerator.skipDescendants()
            } else if name.hasSuffix(".xcodeproj") {
                projects.append(TKXcodeContainerReference(kind: .project, name: name, path: url.path))
                enumerator.skipDescendants()
            } else if name == "Package.swift" {
                packages.append(TKXcodeContainerReference(kind: .package, name: name, path: url.path))
            }
        }

        let sortedWorkspaces = workspaces.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        let sortedProjects = projects.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        let sortedPackages = packages.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        let recommended = single(sortedWorkspaces) ?? single(sortedProjects) ?? single(sortedPackages)
        return TKXcodeDiscoveryResult(
            path: root.path,
            workspaces: sortedWorkspaces,
            projects: sortedProjects,
            packages: sortedPackages,
            recommendedContainer: recommended
        )
    }

    private static func single(_ containers: [TKXcodeContainerReference]) -> TKXcodeContainerReference? {
        containers.count == 1 ? containers[0] : nil
    }

    private static func shouldSkipDirectory(_ name: String) -> Bool {
        switch name {
        case ".build", "build", "DerivedData", "Pods", "Carthage", "node_modules":
            return true
        default:
            return false
        }
    }
}

public enum TKXcodeDiscoveryError: Error, Equatable {
    case pathNotFound(String)
}

public enum TKXcodebuildCommand {
    public static func listSchemes(
        workspace: String?,
        project: String?,
        package: String? = nil,
        disableAutomaticPackageResolution: Bool = false,
        timeoutSeconds: Double = 300
    ) -> TKHostCommand {
        var arguments = containerArguments(workspace: workspace, project: project) + ["-list", "-json"]
        if disableAutomaticPackageResolution {
            arguments.append("-disableAutomaticPackageResolution")
        }
        return TKHostCommand(
            executable: "xcodebuild",
            arguments: arguments,
            workingDirectory: packageWorkingDirectory(package),
            defaultTimeoutSeconds: timeoutSeconds
        )
    }

    public static func showBuildSettings(
        workspace: String?,
        project: String?,
        package: String? = nil,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?,
        buildSettings: [String] = [],
        redactDestination: Bool = false
    ) -> TKHostCommand {
        let arguments = buildArguments(
            workspace: workspace,
            project: project,
            scheme: scheme,
            configuration: configuration,
            sdk: sdk,
            destination: destination,
            derivedDataPath: derivedDataPath,
            buildSettings: buildSettings
        ) + ["-showBuildSettings", "-json"]
        return TKHostCommand(
            executable: "xcodebuild",
            arguments: arguments,
            workingDirectory: packageWorkingDirectory(package),
            redactedArgumentIndexes: redactedDestinationArgumentIndexes(arguments, redactDestination: redactDestination),
            defaultTimeoutSeconds: 300
        )
    }

    public static func build(
        workspace: String?,
        project: String?,
        package: String? = nil,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?,
        buildSettings: [String] = [],
        allowProvisioningUpdates: Bool = false,
        redactDestination: Bool = false
    ) -> TKHostCommand {
        var arguments = buildArguments(
            workspace: workspace,
            project: project,
            scheme: scheme,
            configuration: configuration,
            sdk: sdk,
            destination: destination,
            derivedDataPath: derivedDataPath,
            buildSettings: buildSettings
        )
        if allowProvisioningUpdates {
            arguments.append("-allowProvisioningUpdates")
        }
        arguments.append("build")
        return TKHostCommand(
            executable: "xcodebuild",
            arguments: arguments,
            workingDirectory: packageWorkingDirectory(package),
            redactedArgumentIndexes: redactedDestinationArgumentIndexes(arguments, redactDestination: redactDestination),
            riskLevel: .automation,
            requiredConfig: [.timeout, .auditRecord],
            defaultTimeoutSeconds: 900
        )
    }

    public static func test(
        workspace: String?,
        project: String?,
        package: String? = nil,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?,
        resultBundlePath: String?,
        buildSettings: [String] = [],
        onlyTesting: [String] = [],
        redactDestination: Bool = false
    ) -> TKHostCommand {
        var arguments = buildArguments(
            workspace: workspace,
            project: project,
            scheme: scheme,
            configuration: configuration,
            sdk: sdk,
            destination: destination,
            derivedDataPath: derivedDataPath,
            buildSettings: buildSettings
        )
        if let resultBundlePath, !resultBundlePath.isEmpty {
            arguments += ["-resultBundlePath", resultBundlePath]
        }
        arguments.append("test")
        arguments += onlyTesting.map { "-only-testing:\($0)" }
        return TKHostCommand(
            executable: "xcodebuild",
            arguments: arguments,
            workingDirectory: packageWorkingDirectory(package),
            redactedArgumentIndexes: redactedDestinationArgumentIndexes(arguments, redactDestination: redactDestination),
            riskLevel: .automation,
            requiredConfig: [.timeout, .auditRecord],
            defaultTimeoutSeconds: 1_200,
            capturesArtifacts: resultBundlePath != nil
        )
    }

    private static func containerArguments(workspace: String?, project: String?) -> [String] {
        if let workspace, !workspace.isEmpty {
            return ["-workspace", workspace]
        }
        if let project, !project.isEmpty {
            return ["-project", project]
        }
        return []
    }

    private static func packageWorkingDirectory(_ package: String?) -> String? {
        guard let package, !package.isEmpty else { return nil }
        let url = URL(fileURLWithPath: package).standardizedFileURL
        return url.lastPathComponent == "Package.swift" ? url.deletingLastPathComponent().path : url.path
    }

    private static func buildArguments(
        workspace: String?,
        project: String?,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?,
        buildSettings: [String]
    ) -> [String] {
        var arguments = containerArguments(workspace: workspace, project: project)
        arguments += ["-scheme", scheme, "-configuration", configuration]
        if let sdk, !sdk.isEmpty {
            arguments += ["-sdk", sdk]
        }
        if let destination, !destination.isEmpty {
            arguments += ["-destination", destination]
        }
        if let derivedDataPath, !derivedDataPath.isEmpty {
            arguments += ["-derivedDataPath", derivedDataPath]
        }
        arguments += buildSettings
        return arguments
    }

    private static func redactedDestinationArgumentIndexes(
        _ arguments: [String],
        redactDestination: Bool
    ) -> Set<Int> {
        guard redactDestination,
              let optionIndex = arguments.firstIndex(of: "-destination") else {
            return []
        }
        let destinationIndex = arguments.index(after: optionIndex)
        guard destinationIndex < arguments.endIndex else {
            return []
        }
        return [destinationIndex]
    }
}

public enum TKXctraceCommand {
    public static func record(
        template: String,
        output: String,
        device: String? = nil,
        timeLimit: String? = nil,
        allProcesses: Bool = false,
        attach: String? = nil,
        launchCommand: [String] = [],
        noPrompt: Bool = true,
        appendRun: Bool = false,
        runName: String? = nil
    ) -> TKHostCommand {
        var arguments = ["xctrace", "record", "--template", template, "--output", output]
        if let device, !device.isEmpty {
            arguments += ["--device", device]
        }
        if let timeLimit, !timeLimit.isEmpty {
            arguments += ["--time-limit", timeLimit]
        }
        if appendRun {
            arguments.append("--append-run")
        }
        if let runName, !runName.isEmpty {
            arguments += ["--run-name", runName]
        }
        if allProcesses {
            arguments.append("--all-processes")
        }
        if let attach, !attach.isEmpty {
            arguments += ["--attach", attach]
        }
        if !launchCommand.isEmpty {
            arguments += ["--launch", "--"]
            arguments += launchCommand
        }
        if noPrompt {
            arguments.append("--no-prompt")
        }
        return TKHostCommand(
            executable: "xcrun",
            arguments: arguments,
            riskLevel: .evidence,
            requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: 600,
            capturesArtifacts: true,
            sensitiveOutput: true
        )
    }
}

public enum TKXccovReportMode: Equatable {
    case summary
    case onlyTargets
    case filesForTarget(String)
    case functionsForFile(String)
}

public enum TKXccovCommand {
    public static func viewReport(
        xcresult: String,
        mode: TKXccovReportMode = .summary,
        json: Bool = true
    ) -> TKHostCommand {
        var arguments = ["xccov", "view", "--report"]
        switch mode {
        case .summary:
            break
        case .onlyTargets:
            arguments.append("--only-targets")
        case .filesForTarget(let target):
            arguments += ["--files-for-target", target]
        case .functionsForFile(let file):
            arguments += ["--functions-for-file", file]
        }
        if json {
            arguments.append("--json")
        }
        arguments.append(xcresult)
        return TKHostCommand(
            executable: "xcrun",
            arguments: arguments,
            riskLevel: .evidence,
            requiredConfig: [.artifactDir, .redactionPolicy, .timeout, .auditRecord],
            defaultTimeoutSeconds: 120,
            capturesArtifacts: true,
            sensitiveOutput: true
        )
    }
}

public enum TKXcresultCommand {
    public static func summary(path: String) -> TKHostCommand {
        TKHostCommand(
            executable: "xcrun",
            arguments: ["xcresulttool", "get", "test-results", "summary", "--path", path, "--compact"],
            riskLevel: .evidence,
            requiredConfig: [.timeout],
            defaultTimeoutSeconds: 120,
            sensitiveOutput: true
        )
    }

    public static func tests(path: String) -> TKHostCommand {
        TKHostCommand(
            executable: "xcrun",
            arguments: ["xcresulttool", "get", "test-results", "tests", "--path", path, "--compact"],
            riskLevel: .evidence,
            requiredConfig: [.timeout],
            defaultTimeoutSeconds: 120,
            sensitiveOutput: true
        )
    }
}

public struct TKXcresultInsightSummary: Codable, Equatable {
    public let impact: String
    public let category: String
    public let text: String

    public init(impact: String, category: String, text: String) {
        self.impact = impact
        self.category = category
        self.text = text
    }
}

public struct TKXcresultStatistic: Codable, Equatable {
    public let title: String
    public let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }
}

public struct TKXcresultDeviceSummary: Codable, Equatable {
    public let deviceId: String
    public let deviceName: String
    public let architecture: String?
    public let modelName: String?
    public let platform: String?
    public let osVersion: String
    public let osBuildNumber: String?

    public init(
        deviceId: String,
        deviceName: String,
        architecture: String? = nil,
        modelName: String? = nil,
        platform: String? = nil,
        osVersion: String,
        osBuildNumber: String? = nil
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.architecture = architecture
        self.modelName = modelName
        self.platform = platform
        self.osVersion = osVersion
        self.osBuildNumber = osBuildNumber
    }
}

public struct TKXcresultConfigurationSummary: Codable, Equatable {
    public let configurationId: String
    public let configurationName: String

    public init(configurationId: String, configurationName: String) {
        self.configurationId = configurationId
        self.configurationName = configurationName
    }
}

public struct TKXcresultDeviceAndConfigurationSummary: Codable, Equatable {
    public let device: TKXcresultDeviceSummary
    public let testPlanConfiguration: TKXcresultConfigurationSummary
    public let passedTests: Int
    public let failedTests: Int
    public let skippedTests: Int
    public let expectedFailures: Int

    public init(
        device: TKXcresultDeviceSummary,
        testPlanConfiguration: TKXcresultConfigurationSummary,
        passedTests: Int,
        failedTests: Int,
        skippedTests: Int,
        expectedFailures: Int
    ) {
        self.device = device
        self.testPlanConfiguration = testPlanConfiguration
        self.passedTests = passedTests
        self.failedTests = failedTests
        self.skippedTests = skippedTests
        self.expectedFailures = expectedFailures
    }
}

public struct TKXcresultTestFailure: Codable, Equatable {
    public let testName: String
    public let targetName: String
    public let failureText: String
    public let testIdentifier: Int64?
    public let testIdentifierString: String
    public let testIdentifierURL: String?

    public init(
        testName: String,
        targetName: String,
        failureText: String,
        testIdentifier: Int64? = nil,
        testIdentifierString: String,
        testIdentifierURL: String? = nil
    ) {
        self.testName = testName
        self.targetName = targetName
        self.failureText = failureText
        self.testIdentifier = testIdentifier
        self.testIdentifierString = testIdentifierString
        self.testIdentifierURL = testIdentifierURL
    }
}

public struct TKXcresultSummaryMetrics: Codable, Equatable {
    public let title: String
    public let startTime: Double?
    public let finishTime: Double?
    public let environmentDescription: String
    public let topInsights: [TKXcresultInsightSummary]
    public let result: String
    public let status: String
    public let durationMs: Int?
    public let totalTestCount: Int
    public let passedTests: Int
    public let failedTests: Int
    public let skippedTests: Int
    public let expectedFailures: Int
    public let statistics: [TKXcresultStatistic]
    public let devicesAndConfigurations: TKXcresultDeviceAndConfigurationSummary?
    public let testFailure: TKXcresultTestFailure?

    public init(
        title: String,
        startTime: Double?,
        finishTime: Double?,
        environmentDescription: String,
        topInsights: [TKXcresultInsightSummary],
        result: String,
        durationMs: Int? = nil,
        totalTestCount: Int,
        passedTests: Int,
        failedTests: Int,
        skippedTests: Int,
        expectedFailures: Int,
        statistics: [TKXcresultStatistic],
        devicesAndConfigurations: TKXcresultDeviceAndConfigurationSummary?,
        testFailure: TKXcresultTestFailure?
    ) {
        self.title = title
        self.startTime = startTime
        self.finishTime = finishTime
        self.environmentDescription = environmentDescription
        self.topInsights = topInsights
        self.result = result
        self.status = TKXcresultSummaryMetrics.statusString(for: result)
        self.durationMs = durationMs
        self.totalTestCount = totalTestCount
        self.passedTests = passedTests
        self.failedTests = failedTests
        self.skippedTests = skippedTests
        self.expectedFailures = expectedFailures
        self.statistics = statistics
        self.devicesAndConfigurations = devicesAndConfigurations
        self.testFailure = testFailure
    }

    private static func statusString(for result: String) -> String {
        result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }
}

public struct TKXcresultSummaryResponse: Codable, Equatable {
    public let title: String
    public let startTime: Double?
    public let finishTime: Double?
    public let environmentDescription: String
    public let topInsights: [TKXcresultInsightSummary]
    public let result: String
    public let totalTestCount: Int
    public let passedTests: Int
    public let failedTests: Int
    public let skippedTests: Int
    public let expectedFailures: Int
    public let statistics: [TKXcresultStatistic]
    public let devicesAndConfigurations: TKXcresultDeviceAndConfigurationSummary?
    public let testFailures: TKXcresultTestFailure?

    public init(
        title: String,
        startTime: Double? = nil,
        finishTime: Double? = nil,
        environmentDescription: String,
        topInsights: [TKXcresultInsightSummary] = [],
        result: String,
        totalTestCount: Int,
        passedTests: Int,
        failedTests: Int,
        skippedTests: Int,
        expectedFailures: Int,
        statistics: [TKXcresultStatistic] = [],
        devicesAndConfigurations: TKXcresultDeviceAndConfigurationSummary? = nil,
        testFailures: TKXcresultTestFailure? = nil
    ) {
        self.title = title
        self.startTime = startTime
        self.finishTime = finishTime
        self.environmentDescription = environmentDescription
        self.topInsights = topInsights
        self.result = result
        self.totalTestCount = totalTestCount
        self.passedTests = passedTests
        self.failedTests = failedTests
        self.skippedTests = skippedTests
        self.expectedFailures = expectedFailures
        self.statistics = statistics
        self.devicesAndConfigurations = devicesAndConfigurations
        self.testFailures = testFailures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.startTime = try container.decodeIfPresent(Double.self, forKey: .startTime)
        self.finishTime = try container.decodeIfPresent(Double.self, forKey: .finishTime)
        self.environmentDescription = try container.decode(String.self, forKey: .environmentDescription)
        self.topInsights = try container.decode([TKXcresultInsightSummary].self, forKey: .topInsights)
        self.result = try container.decode(String.self, forKey: .result)
        self.totalTestCount = try container.decode(Int.self, forKey: .totalTestCount)
        self.passedTests = try container.decode(Int.self, forKey: .passedTests)
        self.failedTests = try container.decode(Int.self, forKey: .failedTests)
        self.skippedTests = try container.decode(Int.self, forKey: .skippedTests)
        self.expectedFailures = try container.decode(Int.self, forKey: .expectedFailures)
        self.statistics = try container.decode([TKXcresultStatistic].self, forKey: .statistics)
        self.devicesAndConfigurations = try container
            .decodeIfPresent(TKXcresultSingleOrArrayInput<TKXcresultDeviceAndConfigurationSummary>.self, forKey: .devicesAndConfigurations)?
            .primary
        self.testFailures = try container
            .decodeIfPresent(TKXcresultSingleOrArrayInput<TKXcresultTestFailure>.self, forKey: .testFailures)?
            .primary
    }
}

// Xcode 26.6 changed plural summary fields from one object to an array. Keep
// Triton's released single-value DTO stable while accepting either wire shape.
private struct TKXcresultSingleOrArrayInput<Value: Decodable>: Decodable {
    let primary: Value?

    init(from decoder: Decoder) throws {
        if var array = try? decoder.unkeyedContainer() {
            var first: Value?
            while !array.isAtEnd {
                let value = try array.decode(Value.self)
                if first == nil {
                    first = value
                }
            }
            self.primary = first
        } else {
            self.primary = try Value(from: decoder)
        }
    }
}

public enum TKXcresultSummaryParser {
    public static func parse(_ data: Data) throws -> TKXcresultSummaryMetrics {
        let response = try JSONDecoder().decode(TKXcresultSummaryResponse.self, from: data)
        let durationMs: Int?
        if let startTime = response.startTime, let finishTime = response.finishTime {
            let computed = max(0, Int(((finishTime - startTime) * 1_000).rounded()))
            durationMs = computed
        } else {
            durationMs = nil
        }
        return TKXcresultSummaryMetrics(
            title: response.title,
            startTime: response.startTime,
            finishTime: response.finishTime,
            environmentDescription: response.environmentDescription,
            topInsights: response.topInsights,
            result: response.result,
            durationMs: durationMs,
            totalTestCount: response.totalTestCount,
            passedTests: response.passedTests,
            failedTests: response.failedTests,
            skippedTests: response.skippedTests,
            expectedFailures: response.expectedFailures,
            statistics: response.statistics,
            devicesAndConfigurations: response.devicesAndConfigurations,
            testFailure: response.testFailures
        )
    }
}

public enum TKXcresultTestNodeType: String, Codable, Equatable {
    case testPlan = "Test Plan"
    case unitTestBundle = "Unit test bundle"
    case uiTestBundle = "UI test bundle"
    case testSuite = "Test Suite"
    case testCase = "Test Case"
    case device = "Device"
    case testPlanConfiguration = "Test Plan Configuration"
    case arguments = "Arguments"
    case repetition = "Repetition"
    case testCaseRun = "Test Case Run"
    case failureMessage = "Failure Message"
    case sourceCodeReference = "Source Code Reference"
    case attachment = "Attachment"
    case expression = "Expression"
    case testValue = "Test Value"
    case runtimeWarning = "Runtime Warning"
    case other

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = TKXcresultTestNodeType(rawValue: raw) ?? .other
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue == "other" ? "other" : rawValue)
    }
}

public struct TKXcresultTestNode: Codable, Equatable {
    public let nodeIdentifier: String?
    public let nodeIdentifierURL: String?
    public let nodeType: TKXcresultTestNodeType
    public let name: String
    public let details: String?
    public let duration: String?
    public let durationInSeconds: Double?
    public let result: String?
    public let tags: [String]
    public let children: [TKXcresultTestNode]

    public init(
        nodeIdentifier: String? = nil,
        nodeIdentifierURL: String? = nil,
        nodeType: TKXcresultTestNodeType,
        name: String,
        details: String? = nil,
        duration: String? = nil,
        durationInSeconds: Double? = nil,
        result: String? = nil,
        tags: [String] = [],
        children: [TKXcresultTestNode] = []
    ) {
        self.nodeIdentifier = nodeIdentifier
        self.nodeIdentifierURL = nodeIdentifierURL
        self.nodeType = nodeType
        self.name = name
        self.details = details
        self.duration = duration
        self.durationInSeconds = durationInSeconds
        self.result = result
        self.tags = tags
        self.children = children
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeIdentifier = try container.decodeIfPresent(String.self, forKey: .nodeIdentifier)
        self.nodeIdentifierURL = try container.decodeIfPresent(String.self, forKey: .nodeIdentifierURL)
        self.nodeType = try container.decode(TKXcresultTestNodeType.self, forKey: .nodeType)
        self.name = try container.decode(String.self, forKey: .name)
        self.details = try container.decodeIfPresent(String.self, forKey: .details)
        self.duration = try container.decodeIfPresent(String.self, forKey: .duration)
        self.durationInSeconds = try container.decodeIfPresent(Double.self, forKey: .durationInSeconds)
        self.result = try container.decodeIfPresent(String.self, forKey: .result)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.children = try container.decodeIfPresent([TKXcresultTestNode].self, forKey: .children) ?? []
    }
}

public struct TKXcresultTestsResponse: Codable, Equatable {
    public let testPlanConfigurations: [TKXcresultConfigurationSummary]
    public let devices: [TKXcresultDeviceSummary]
    public let testNodes: [TKXcresultTestNode]

    public init(
        testPlanConfigurations: [TKXcresultConfigurationSummary],
        devices: [TKXcresultDeviceSummary],
        testNodes: [TKXcresultTestNode]
    ) {
        self.testPlanConfigurations = testPlanConfigurations
        self.devices = devices
        self.testNodes = testNodes
    }
}

public struct TKXcresultFailureRecord: Codable, Equatable {
    public let suiteName: String?
    public let testName: String
    public let targetName: String
    public let message: String
    public let location: String?
    public let testIdentifierString: String?
    public let testIdentifierURL: String?
    public let attachmentNames: [String]

    public init(
        suiteName: String?,
        testName: String,
        targetName: String,
        message: String,
        location: String? = nil,
        testIdentifierString: String? = nil,
        testIdentifierURL: String? = nil,
        attachmentNames: [String] = []
    ) {
        self.suiteName = suiteName
        self.testName = testName
        self.targetName = targetName
        self.message = message
        self.location = location
        self.testIdentifierString = testIdentifierString
        self.testIdentifierURL = testIdentifierURL
        self.attachmentNames = attachmentNames
    }
}

public enum TKXcresultRedaction {
    public static func redact(_ value: String) -> String {
        var redacted = value
        redacted = replacing(
            #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            in: redacted,
            with: "<email>",
            options: [.caseInsensitive]
        )
        redacted = replacing(
            #"file:///(?:Users|private|var|tmp|Volumes)/[^\s"'<>,)]+"#,
            in: redacted,
            with: "<private-path>"
        )
        redacted = replacing(
            #"/(?:Users|private|var|tmp|Volumes)/[^\s"'<>,)]+"#,
            in: redacted,
            with: "<private-path>"
        )
        redacted = replacing(
            #"(?i)\bBearer\s+[A-Za-z0-9._\-+/=]{8,}"#,
            in: redacted,
            with: "Bearer <redacted>"
        )
        redacted = replacing(
            #"(?i)\b(token|secret|password|passwd|api[_-]?key|authorization)\s*[:=]\s*[^\s,;"']{6,}"#,
            in: redacted,
            with: "$1=<redacted>"
        )
        redacted = replacing(
            #"\b[A-Za-z0-9_\-]{32,}\b"#,
            in: redacted,
            with: "<redacted-token>"
        )
        return redacted
    }

    /// Applies the standard xcresult redaction plus exact values which are known to be
    /// execution-only for the caller (for example a CoreDevice raw target identifier).
    public static func redact(_ value: String, exactValues: [String]) -> String {
        let values = exactValues
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
        return values.reduce(redact(value)) { partialResult, sensitiveValue in
            partialResult.replacingOccurrences(of: sensitiveValue, with: "<redacted>")
        }
    }

    public static func redact(_ summary: TKXcresultSummaryMetrics) -> TKXcresultSummaryMetrics {
        redact(summary, transforming: { redact($0) })
    }

    /// Redacts a parsed xcresult summary with caller-supplied execution-only values.
    public static func redact(
        _ summary: TKXcresultSummaryMetrics,
        exactValues: [String]
    ) -> TKXcresultSummaryMetrics {
        redact(summary, transforming: { redact($0, exactValues: exactValues) })
    }

    public static func redact(_ failures: [TKXcresultFailureRecord]) -> [TKXcresultFailureRecord] {
        failures.map { redact($0, transforming: { redact($0) }) }
    }

    /// Redacts parsed xcresult failures with caller-supplied execution-only values.
    public static func redact(
        _ failures: [TKXcresultFailureRecord],
        exactValues: [String]
    ) -> [TKXcresultFailureRecord] {
        failures.map { redact($0, transforming: { redact($0, exactValues: exactValues) }) }
    }

    private static func redact(
        _ summary: TKXcresultSummaryMetrics,
        transforming transform: (String) -> String
    ) -> TKXcresultSummaryMetrics {
        TKXcresultSummaryMetrics(
            title: transform(summary.title),
            startTime: summary.startTime,
            finishTime: summary.finishTime,
            environmentDescription: transform(summary.environmentDescription),
            topInsights: summary.topInsights.map { redact($0, transforming: transform) },
            result: summary.result,
            durationMs: summary.durationMs,
            totalTestCount: summary.totalTestCount,
            passedTests: summary.passedTests,
            failedTests: summary.failedTests,
            skippedTests: summary.skippedTests,
            expectedFailures: summary.expectedFailures,
            statistics: summary.statistics.map { redact($0, transforming: transform) },
            devicesAndConfigurations: summary.devicesAndConfigurations.map { redact($0, transforming: transform) },
            testFailure: summary.testFailure.map { redact($0, transforming: transform) }
        )
    }

    private static func redact(
        _ insight: TKXcresultInsightSummary,
        transforming transform: (String) -> String
    ) -> TKXcresultInsightSummary {
        TKXcresultInsightSummary(
            impact: transform(insight.impact),
            category: transform(insight.category),
            text: transform(insight.text)
        )
    }

    private static func redact(
        _ statistic: TKXcresultStatistic,
        transforming transform: (String) -> String
    ) -> TKXcresultStatistic {
        TKXcresultStatistic(title: transform(statistic.title), subtitle: transform(statistic.subtitle))
    }

    private static func redact(
        _ summary: TKXcresultDeviceAndConfigurationSummary,
        transforming transform: (String) -> String
    ) -> TKXcresultDeviceAndConfigurationSummary {
        TKXcresultDeviceAndConfigurationSummary(
            device: redact(summary.device, transforming: transform),
            testPlanConfiguration: redact(summary.testPlanConfiguration, transforming: transform),
            passedTests: summary.passedTests,
            failedTests: summary.failedTests,
            skippedTests: summary.skippedTests,
            expectedFailures: summary.expectedFailures
        )
    }

    private static func redact(
        _ device: TKXcresultDeviceSummary,
        transforming transform: (String) -> String
    ) -> TKXcresultDeviceSummary {
        TKXcresultDeviceSummary(
            deviceId: transform(device.deviceId),
            deviceName: transform(device.deviceName),
            architecture: device.architecture.map(transform),
            modelName: device.modelName.map(transform),
            platform: device.platform.map(transform),
            osVersion: transform(device.osVersion),
            osBuildNumber: device.osBuildNumber.map(transform)
        )
    }

    private static func redact(
        _ configuration: TKXcresultConfigurationSummary,
        transforming transform: (String) -> String
    ) -> TKXcresultConfigurationSummary {
        TKXcresultConfigurationSummary(
            configurationId: transform(configuration.configurationId),
            configurationName: transform(configuration.configurationName)
        )
    }

    private static func redact(
        _ failure: TKXcresultTestFailure,
        transforming transform: (String) -> String
    ) -> TKXcresultTestFailure {
        TKXcresultTestFailure(
            testName: transform(failure.testName),
            targetName: transform(failure.targetName),
            failureText: transform(failure.failureText),
            testIdentifier: failure.testIdentifier,
            testIdentifierString: transform(failure.testIdentifierString),
            testIdentifierURL: failure.testIdentifierURL.map(transform)
        )
    }

    private static func redact(
        _ failure: TKXcresultFailureRecord,
        transforming transform: (String) -> String
    ) -> TKXcresultFailureRecord {
        TKXcresultFailureRecord(
            suiteName: failure.suiteName.map(transform),
            testName: transform(failure.testName),
            targetName: transform(failure.targetName),
            message: transform(failure.message),
            location: failure.location.map(transform),
            testIdentifierString: failure.testIdentifierString.map(transform),
            testIdentifierURL: failure.testIdentifierURL.map(transform),
            attachmentNames: failure.attachmentNames.map(transform)
        )
    }

    private static func replacing(
        _ pattern: String,
        in value: String,
        with replacement: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}

public enum TKXcresultTestsParser {
    public static func parseFailures(_ data: Data) throws -> [TKXcresultFailureRecord] {
        let response = try JSONDecoder().decode(TKXcresultTestsResponse.self, from: data)
        return collectFailures(from: response.testNodes)
    }

    private static func collectFailures(from nodes: [TKXcresultTestNode], ancestors: [TKXcresultTestNode] = []) -> [TKXcresultFailureRecord] {
        var failures: [TKXcresultFailureRecord] = []
        for node in nodes {
            let chain = ancestors + [node]
            let isFailedRun = node.nodeType == .testCaseRun
                && node.result?.localizedCaseInsensitiveCompare("Failed") == .orderedSame
            let isFlattenedFailedCase = node.nodeType == .testCase
                && node.result?.localizedCaseInsensitiveCompare("Failed") == .orderedSame
                && !node.children.contains(where: { $0.nodeType == .testCaseRun })
            if isFailedRun || isFlattenedFailedCase {
                if let record = failureRecord(for: node, ancestors: ancestors) {
                    failures.append(record)
                }
            }
            if !node.children.isEmpty {
                failures.append(contentsOf: collectFailures(from: node.children, ancestors: chain))
            }
        }
        return failures
    }

    private static func failureRecord(for node: TKXcresultTestNode, ancestors: [TKXcresultTestNode]) -> TKXcresultFailureRecord? {
        let suiteName = ancestors.reversed().first(where: { $0.nodeType == .testSuite })?.name
        let targetName = ancestors.reversed().first(where: { $0.nodeType == .unitTestBundle || $0.nodeType == .uiTestBundle })?.name
            ?? ancestors.reversed().first(where: { $0.nodeType == .testPlanConfiguration })?.name
            ?? ancestors.reversed().first(where: { $0.nodeType == .testPlan })?.name
            ?? "unknown"
        let testName = ancestors.reversed().first(where: { $0.nodeType == .testCase })?.name ?? node.name
        let messages = failureMessages(from: node)
        let attachments = attachmentNames(from: node)
        let location = sourceReference(from: node)
        return TKXcresultFailureRecord(
            suiteName: suiteName,
            testName: testName,
            targetName: targetName,
            message: messages.isEmpty ? node.details ?? node.name : messages.joined(separator: "\n"),
            location: location,
            testIdentifierString: node.nodeIdentifier,
            testIdentifierURL: node.nodeIdentifierURL,
            attachmentNames: attachments
        )
    }

    private static func failureMessages(from node: TKXcresultTestNode) -> [String] {
        node.children.flatMap { child -> [String] in
            switch child.nodeType {
            case .failureMessage:
                return [child.details ?? child.name]
            default:
                return failureMessages(from: child)
            }
        }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func attachmentNames(from node: TKXcresultTestNode) -> [String] {
        node.children.flatMap { child -> [String] in
            switch child.nodeType {
            case .attachment:
                return [child.details ?? child.name]
            default:
                return attachmentNames(from: child)
            }
        }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func sourceReference(from node: TKXcresultTestNode) -> String? {
        let direct = node.children.first(where: { $0.nodeType == .sourceCodeReference })?.details
            ?? node.children.first(where: { $0.nodeType == .sourceCodeReference })?.name
        if let direct, !direct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return direct
        }
        for child in node.children {
            if let location = sourceReference(from: child) {
                return location
            }
        }
        return nil
    }
}

public struct TKXcodeSchemeList: Codable, Equatable {
    public let containerName: String?
    public let schemes: [String]

    public init(containerName: String?, schemes: [String]) {
        self.containerName = containerName
        self.schemes = schemes
    }
}

public enum TKXcodebuildListParser {
    private struct Response: Decodable {
        let workspace: Container?
        let project: Container?
    }

    private struct Container: Decodable {
        let name: String?
        let schemes: [String]?
    }

    public static func parseSchemes(_ data: Data) throws -> TKXcodeSchemeList {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let container = response.workspace ?? response.project
        return TKXcodeSchemeList(
            containerName: container?.name,
            schemes: (container?.schemes ?? []).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        )
    }
}

public struct TKXcodeBuiltAppProduct: Codable, Equatable {
    public let target: String?
    public let appPath: String
    public let bundleID: String?

    public init(target: String?, appPath: String, bundleID: String?) {
        self.target = target
        self.appPath = appPath
        self.bundleID = bundleID
    }
}

public enum TKXcodeBuildSettingsParser {
    private struct Entry: Decodable {
        let target: String?
        let buildSettings: [String: String]
    }

    public static func resolveBuiltApp(_ data: Data) throws -> TKXcodeBuiltAppProduct {
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        guard let entry = entries.first(where: { ($0.buildSettings["FULL_PRODUCT_NAME"] ?? "").hasSuffix(".app") }) ?? entries.first,
              let productsDir = entry.buildSettings["BUILT_PRODUCTS_DIR"],
              let productName = entry.buildSettings["FULL_PRODUCT_NAME"],
              productName.hasSuffix(".app")
        else {
            throw TKXcodeBuildSettingsError.appPathUnresolved
        }
        return TKXcodeBuiltAppProduct(
            target: entry.target,
            appPath: URL(fileURLWithPath: productsDir).appendingPathComponent(productName).path,
            bundleID: entry.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]
        )
    }
}

public enum TKXcodeBuildSettingsError: Error, Equatable {
    case appPathUnresolved
}

public struct TKXcodeOutputDiagnosticSample: Codable, Equatable {
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

public struct TKXcodeOutputDiagnostic: Codable, Equatable {
    public let kind: String
    public let message: String
    public let matchCount: Int
    public let samples: [TKXcodeOutputDiagnosticSample]
    public let recovery: String
    public let nextAction: TKCLINextAction

    public init(
        kind: String,
        message: String,
        matchCount: Int,
        samples: [TKXcodeOutputDiagnosticSample],
        recovery: String,
        nextAction: TKCLINextAction
    ) {
        self.kind = kind
        self.message = message
        self.matchCount = matchCount
        self.samples = samples
        self.recovery = recovery
        self.nextAction = nextAction
    }
}

public struct TKXcodeActiveProcessSummary: Codable, Equatable {
    public let pid: Int
    public let name: String
    public let commandLine: String
    public let elapsed: String?
    public let elapsedSeconds: Int?
    public let workspace: String?
    public let project: String?
    public let scheme: String?
    public let destination: String?
    public let derivedDataPath: String?
    public let confidence: String

    public init(
        pid: Int,
        name: String,
        commandLine: String,
        elapsed: String? = nil,
        elapsedSeconds: Int? = nil,
        workspace: String? = nil,
        project: String? = nil,
        scheme: String? = nil,
        destination: String? = nil,
        derivedDataPath: String? = nil,
        confidence: String
    ) {
        self.pid = pid
        self.name = name
        self.commandLine = commandLine
        self.elapsed = elapsed
        self.elapsedSeconds = elapsedSeconds
        self.workspace = workspace
        self.project = project
        self.scheme = scheme
        self.destination = destination
        self.derivedDataPath = derivedDataPath
        self.confidence = confidence
    }
}

public struct TKXcodePostActionProcessStatus: Codable, Equatable {
    public let active: Bool
    public let workspaceFilter: String?
    public let processes: [TKXcodeActiveProcessSummary]
    public let sourceCommand: String

    public init(
        active: Bool,
        workspaceFilter: String? = nil,
        processes: [TKXcodeActiveProcessSummary],
        sourceCommand: String
    ) {
        self.active = active
        self.workspaceFilter = workspaceFilter
        self.processes = processes
        self.sourceCommand = sourceCommand
    }
}

public struct TKXcodeActionSummary: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let failureCode: String?
    public let workspace: String?
    public let project: String?
    public let package: String?
    public let scheme: String
    public let configuration: String
    public let sdk: String?
    public let destination: String?
    public let derivedDataPath: String?
    public let derivedDataCache: TKXcodeDerivedDataCacheInfo?
    public let appPath: String?
    public let bundleID: String?
    public let resultBundlePath: String?
    public let onlyTesting: [String]?
    public let simulatorUDID: String?
    public let device: String?
    public let durationMs: Int
    public let sourceCommand: String
    public let exitCode: Int32
    public let stdoutTruncated: Bool
    public let stderrTruncated: Bool
    public let stdoutLogPath: String?
    public let stderrLogPath: String?
    public let stdoutBytes: Int?
    public let stderrBytes: Int?
    public let testResultSummary: TKXcresultSummaryMetrics?
    public let topFailures: [TKXcresultFailureRecord]?
    public let xcresultNote: String?
    public let xcodeDiagnostics: [TKXcodeOutputDiagnostic]?
    public let postActionProcessStatus: TKXcodePostActionProcessStatus?
    public let nextActions: [TKCLINextAction]?
    public let note: String?

    public init(
        ok: Bool,
        action: String,
        failureCode: String? = nil,
        workspace: String?,
        project: String?,
        package: String? = nil,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?,
        derivedDataCache: TKXcodeDerivedDataCacheInfo? = nil,
        appPath: String? = nil,
        bundleID: String? = nil,
        resultBundlePath: String? = nil,
        onlyTesting: [String]? = nil,
        simulatorUDID: String? = nil,
        device: String? = nil,
        durationMs: Int,
        sourceCommand: String,
        exitCode: Int32,
        stdoutTruncated: Bool,
        stderrTruncated: Bool,
        stdoutLogPath: String? = nil,
        stderrLogPath: String? = nil,
        stdoutBytes: Int? = nil,
        stderrBytes: Int? = nil,
        testResultSummary: TKXcresultSummaryMetrics? = nil,
        topFailures: [TKXcresultFailureRecord]? = nil,
        xcresultNote: String? = nil,
        xcodeDiagnostics: [TKXcodeOutputDiagnostic]? = nil,
        postActionProcessStatus: TKXcodePostActionProcessStatus? = nil,
        nextActions: [TKCLINextAction]? = nil,
        note: String? = nil
    ) {
        self.ok = ok
        self.action = action
        self.failureCode = failureCode
        self.workspace = workspace
        self.project = project
        self.package = package
        self.scheme = scheme
        self.configuration = configuration
        self.sdk = sdk
        self.destination = destination
        self.derivedDataPath = derivedDataPath
        self.derivedDataCache = derivedDataCache
        self.appPath = appPath
        self.bundleID = bundleID
        self.resultBundlePath = resultBundlePath
        self.onlyTesting = onlyTesting
        self.simulatorUDID = simulatorUDID
        self.device = device
        self.durationMs = durationMs
        self.sourceCommand = sourceCommand
        self.exitCode = exitCode
        self.stdoutTruncated = stdoutTruncated
        self.stderrTruncated = stderrTruncated
        self.stdoutLogPath = stdoutLogPath
        self.stderrLogPath = stderrLogPath
        self.stdoutBytes = stdoutBytes
        self.stderrBytes = stderrBytes
        self.testResultSummary = testResultSummary
        self.topFailures = topFailures
        self.xcresultNote = xcresultNote
        self.xcodeDiagnostics = xcodeDiagnostics
        self.postActionProcessStatus = postActionProcessStatus
        self.nextActions = nextActions
        self.note = note
    }
}

public struct TKXcodeProgressEvent: Codable, Equatable {
    public let ok: Bool
    public let event: String
    public let message: String
    public let sourceCommand: String?
    public let elapsedMs: Int?
    public let stdoutLogPath: String?
    public let stderrLogPath: String?
    public let stdoutBytes: Int?
    public let stderrBytes: Int?

    public init(
        ok: Bool = true,
        event: String,
        message: String,
        sourceCommand: String? = nil,
        elapsedMs: Int? = nil,
        stdoutLogPath: String? = nil,
        stderrLogPath: String? = nil,
        stdoutBytes: Int? = nil,
        stderrBytes: Int? = nil
    ) {
        self.ok = ok
        self.event = event
        self.message = message
        self.sourceCommand = sourceCommand
        self.elapsedMs = elapsedMs
        self.stdoutLogPath = stdoutLogPath
        self.stderrLogPath = stderrLogPath
        self.stdoutBytes = stdoutBytes
        self.stderrBytes = stderrBytes
    }
}
