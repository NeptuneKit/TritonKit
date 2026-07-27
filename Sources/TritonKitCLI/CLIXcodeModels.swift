import Foundation
import TritonKitShared

struct XcodeUseOutput: Encodable {
    let ok: Bool
    let action: String
    let defaultsPath: String
    let defaults: TKHostWorkspaceDefaults
    let derivedDataCache: TKXcodeDerivedDataCacheInfo
}

struct XcodeSchemesOutput: Encodable {
    let ok: Bool
    let workspace: String?
    let project: String?
    let package: String?
    let schemes: [String]
    let sourceCommand: String
}

struct ResolvedXcodeInvocation: Encodable {
    let workspace: String?
    let project: String?
    let package: String?
    let scheme: String
    let configuration: String
    let sdk: String?
    let destination: String?
    let derivedDataPath: String?
    let buildSettings: [String]
    let derivedDataCache: TKXcodeDerivedDataCacheInfo
    let simulatorUDID: String?
    let device: String?
    private let deviceSelector: String?
    private let executionDestination: String?

    init(
        workspace: String?,
        project: String?,
        package: String?,
        scheme: String,
        configuration: String,
        sdk: String?,
        destination: String?,
        derivedDataPath: String?,
        buildSettings: [String],
        derivedDataCache: TKXcodeDerivedDataCacheInfo,
        simulatorUDID: String?,
        device: String?,
        deviceSelector: String? = nil,
        executionDestination: String? = nil
    ) {
        self.workspace = workspace
        self.project = project
        self.package = package
        self.scheme = scheme
        self.configuration = configuration
        self.sdk = sdk
        self.destination = destination
        self.derivedDataPath = derivedDataPath
        self.buildSettings = buildSettings
        self.derivedDataCache = derivedDataCache
        self.simulatorUDID = simulatorUDID
        self.device = device
        self.deviceSelector = deviceSelector ?? device
        self.executionDestination = executionDestination
    }

    enum CodingKeys: String, CodingKey {
        case workspace
        case project
        case package
        case scheme
        case configuration
        case sdk
        case destination
        case derivedDataPath
        case buildSettings
        case derivedDataCache
        case simulatorUDID
        case device
    }

    var hasRealDeviceSelection: Bool {
        guard let deviceSelector else { return false }
        return !deviceSelector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var realDeviceSelector: String? {
        deviceSelector
    }

    var xcodebuildDestination: String? {
        executionDestination ?? destination
    }

    var redactsXcodebuildDestination: Bool {
        executionDestination != nil
    }

    func withRealDeviceExecutionDestination(rawTarget: String) -> ResolvedXcodeInvocation {
        let rawTarget = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        return ResolvedXcodeInvocation(
            workspace: workspace,
            project: project,
            package: package,
            scheme: scheme,
            configuration: configuration,
            sdk: sdk,
            destination: "platform=iOS,id=<redacted>",
            derivedDataPath: derivedDataPath,
            buildSettings: buildSettings,
            derivedDataCache: derivedDataCache,
            simulatorUDID: simulatorUDID,
            device: "<redacted>",
            deviceSelector: deviceSelector,
            executionDestination: "platform=iOS,id=\(rawTarget)"
        )
    }
}

struct PreparedXcodeRealDeviceInvocation {
    let invocation: ResolvedXcodeInvocation
    let selection: HostDeviceSelectionResult
}

struct XcodeSettingsOutput: Encodable {
    let ok: Bool
    let invocation: ResolvedXcodeInvocation
    let product: TKXcodeBuiltAppProduct
    let sourceCommand: String
    let stdoutLogPath: String?
    let stderrLogPath: String?
    let stdoutBytes: Int?
    let stderrBytes: Int?
}
