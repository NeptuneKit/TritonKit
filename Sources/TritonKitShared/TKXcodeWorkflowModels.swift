import Foundation

public struct TKXcodeWorkspaceDefaults: Codable, Equatable {
    public let workspace: String?
    public let project: String?
    public let scheme: String
    public let configuration: String
    public let sdk: String
    public let destination: String?
    public let derivedDataPath: String

    public init(
        workspace: String? = nil,
        project: String? = nil,
        scheme: String,
        configuration: String = "Debug",
        sdk: String = "iphonesimulator",
        destination: String? = nil,
        derivedDataPath: String = ".triton/DerivedData"
    ) {
        self.workspace = workspace
        self.project = project
        self.scheme = scheme
        self.configuration = configuration
        self.sdk = sdk
        self.destination = destination
        self.derivedDataPath = derivedDataPath
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
    public static func discover(path: String, maxDepth: Int = 2) throws -> TKXcodeDiscoveryResult {
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
    public static func listSchemes(workspace: String?, project: String?) -> TKHostCommand {
        TKHostCommand(
            executable: "xcodebuild",
            arguments: containerArguments(workspace: workspace, project: project) + ["-list", "-json"],
            defaultTimeoutSeconds: 60
        )
    }

    public static func showBuildSettings(
        workspace: String?,
        project: String?,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?
    ) -> TKHostCommand {
        TKHostCommand(
            executable: "xcodebuild",
            arguments: buildArguments(
                workspace: workspace,
                project: project,
                scheme: scheme,
                configuration: configuration,
                sdk: sdk,
                destination: destination,
                derivedDataPath: derivedDataPath
            ) + ["-showBuildSettings", "-json"],
            defaultTimeoutSeconds: 300
        )
    }

    public static func build(
        workspace: String?,
        project: String?,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?
    ) -> TKHostCommand {
        TKHostCommand(
            executable: "xcodebuild",
            arguments: buildArguments(
                workspace: workspace,
                project: project,
                scheme: scheme,
                configuration: configuration,
                sdk: sdk,
                destination: destination,
                derivedDataPath: derivedDataPath
            ) + ["build"],
            riskLevel: .automation,
            requiredConfig: [.timeout, .auditRecord],
            defaultTimeoutSeconds: 900
        )
    }

    public static func test(
        workspace: String?,
        project: String?,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?,
        resultBundlePath: String?
    ) -> TKHostCommand {
        var arguments = buildArguments(
            workspace: workspace,
            project: project,
            scheme: scheme,
            configuration: configuration,
            sdk: sdk,
            destination: destination,
            derivedDataPath: derivedDataPath
        )
        if let resultBundlePath, !resultBundlePath.isEmpty {
            arguments += ["-resultBundlePath", resultBundlePath]
        }
        arguments.append("test")
        return TKHostCommand(
            executable: "xcodebuild",
            arguments: arguments,
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

    private static func buildArguments(
        workspace: String?,
        project: String?,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?
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
        return arguments
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

public struct TKXcodeActionSummary: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let workspace: String?
    public let project: String?
    public let scheme: String
    public let configuration: String
    public let sdk: String?
    public let destination: String?
    public let derivedDataPath: String?
    public let appPath: String?
    public let bundleID: String?
    public let resultBundlePath: String?
    public let simulatorUDID: String?
    public let durationMs: Int
    public let sourceCommand: String
    public let exitCode: Int32
    public let stdoutTruncated: Bool
    public let stderrTruncated: Bool
    public let stdoutLogPath: String?
    public let stderrLogPath: String?
    public let stdoutBytes: Int?
    public let stderrBytes: Int?
    public let note: String?

    public init(
        ok: Bool,
        action: String,
        workspace: String?,
        project: String?,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?,
        appPath: String? = nil,
        bundleID: String? = nil,
        resultBundlePath: String? = nil,
        simulatorUDID: String? = nil,
        durationMs: Int,
        sourceCommand: String,
        exitCode: Int32,
        stdoutTruncated: Bool,
        stderrTruncated: Bool,
        stdoutLogPath: String? = nil,
        stderrLogPath: String? = nil,
        stdoutBytes: Int? = nil,
        stderrBytes: Int? = nil,
        note: String? = nil
    ) {
        self.ok = ok
        self.action = action
        self.workspace = workspace
        self.project = project
        self.scheme = scheme
        self.configuration = configuration
        self.sdk = sdk
        self.destination = destination
        self.derivedDataPath = derivedDataPath
        self.appPath = appPath
        self.bundleID = bundleID
        self.resultBundlePath = resultBundlePath
        self.simulatorUDID = simulatorUDID
        self.durationMs = durationMs
        self.sourceCommand = sourceCommand
        self.exitCode = exitCode
        self.stdoutTruncated = stdoutTruncated
        self.stderrTruncated = stderrTruncated
        self.stdoutLogPath = stdoutLogPath
        self.stderrLogPath = stderrLogPath
        self.stdoutBytes = stdoutBytes
        self.stderrBytes = stderrBytes
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
