import Foundation

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
        buildForTesting: Bool = false,
        testProductsPath: String? = nil,
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
        if let testProductsPath { arguments += ["-testProductsPath", testProductsPath] }
        arguments.append(buildForTesting ? "build-for-testing" : "build")
        return TKHostCommand(
            executable: "xcodebuild",
            arguments: arguments,
            workingDirectory: packageWorkingDirectory(package),
            redactedArgumentIndexes: redactedDestinationArgumentIndexes(arguments, redactDestination: redactDestination),
            riskLevel: .automation,
            requiredConfig: [.timeout, .auditRecord],
            defaultTimeoutSeconds: 900,
            capturesArtifacts: buildForTesting
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

    public static func archive(
        workspace: String?,
        project: String?,
        package: String? = nil,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String,
        derivedDataPath: String?,
        archivePath: String,
        buildSettings: [String] = [],
        allowProvisioningUpdates: Bool = false,
        allowProvisioningDeviceRegistration: Bool = false,
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
        if allowProvisioningDeviceRegistration {
            arguments.append("-allowProvisioningDeviceRegistration")
        }
        arguments += ["archive", "-archivePath", archivePath]
        return TKHostCommand(
            executable: "xcodebuild",
            arguments: arguments,
            workingDirectory: packageWorkingDirectory(package),
            redactedArgumentIndexes: redactedDestinationArgumentIndexes(arguments, redactDestination: redactDestination),
            riskLevel: .automation,
            requiredConfig: [.timeout, .auditRecord],
            defaultTimeoutSeconds: 1_800,
            capturesArtifacts: true
        )
    }

    public static func exportArchive(
        archivePath: String,
        exportOptionsPlist: String,
        exportPath: String,
        buildSettings: [String] = [],
        allowProvisioningUpdates: Bool = false,
        allowProvisioningDeviceRegistration: Bool = false
    ) -> TKHostCommand {
        var arguments = [
            "-exportArchive",
            "-archivePath", archivePath,
            "-exportOptionsPlist", exportOptionsPlist,
            "-exportPath", exportPath,
        ]
        arguments += buildSettings
        if allowProvisioningUpdates {
            arguments.append("-allowProvisioningUpdates")
        }
        if allowProvisioningDeviceRegistration {
            arguments.append("-allowProvisioningDeviceRegistration")
        }
        return TKHostCommand(
            executable: "xcodebuild",
            arguments: arguments,
            riskLevel: .automation,
            requiredConfig: [.timeout, .auditRecord],
            defaultTimeoutSeconds: 1_200,
            capturesArtifacts: true
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
