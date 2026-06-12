import ArgumentParser
import Foundation
import TritonKitShared

// MARK: - Host-Side App Commands

enum HostAppPlatform: String, ExpressibleByArgument {
    case ios
    case android
    case harmony
}

private func hostDevicePlatform(from platform: HostAppPlatform) -> HostDevicePlatform {
    switch platform {
    case .ios:
        return .ios
    case .android:
        return .android
    case .harmony:
        return .harmony
    }
}

private func hostAppPlatform(from platform: HostDevicePlatform) -> HostAppPlatform {
    switch platform {
    case .ios:
        return .ios
    case .android:
        return .android
    case .harmony:
        return .harmony
    }
}

private func hostDeviceSelectionRequest(
    device: String?,
    platform: HostAppPlatform?,
    defaultPlatform: HostDevicePlatform?,
    scope: HostDeviceScope?,
    name: String?,
    runtime: String?,
    state: String?,
    ready: Bool
) -> HostDeviceSelectionRequest {
    HostDeviceSelectionRequest(
        device: device,
        platform: platform.map(hostDevicePlatform(from:)) ?? defaultPlatform,
        scope: scope,
        name: name,
        runtime: runtime,
        state: state,
        ready: ready
    )
}

private func resolveDefaultIOSHostDeviceSelection(
    device: String?,
    simulator: String?,
    scope: HostDeviceScope?,
    name: String?,
    runtime: String?,
    state: String?,
    ready: Bool
) throws -> HostDeviceSelectionResult {
    let explicitDevice = device ?? simulator
    if explicitDevice != nil {
        return try resolveHostDeviceSelection(
            request: hostDeviceSelectionRequest(
                device: explicitDevice,
                platform: .ios,
                defaultPlatform: .ios,
                scope: scope,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready
            ),
            hdc: "hdc"
        )
    }

    do {
        return try resolveHostDeviceSelection(
            request: hostDeviceSelectionRequest(
                device: "current",
                platform: .ios,
                defaultPlatform: .ios,
                scope: scope,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready
            ),
            hdc: "hdc"
        )
    } catch HostDeviceSelectionError.targetNotFound(let target) where target == "current" {
        return try resolveHostDeviceSelection(
            request: hostDeviceSelectionRequest(
                device: nil,
                platform: .ios,
                defaultPlatform: .ios,
                scope: scope,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready
            ),
            hdc: "hdc"
        )
    }
}

func ensureHostDeviceSelectorCompatibility(device: String?, simulator: String?, target: String?) throws {
    if device != nil && (simulator != nil || target != nil) {
        throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --simulator or Harmony --target.")
    }
}

private func resolveHostAppDeviceSelection(
    device: String?,
    platform: HostAppPlatform?,
    defaultPlatform: HostDevicePlatform?,
    scope: HostDeviceScope?,
    simulator: String?,
    target: String?,
    name: String?,
    runtime: String?,
    state: String?,
    ready: Bool,
    hdc: String
) throws -> HostDeviceSelectionResult {
    try ensureHostDeviceSelectorCompatibility(device: device, simulator: simulator, target: target)
    return try resolveHostDeviceSelection(
        request: hostDeviceSelectionRequest(
            device: device ?? simulator ?? target,
            platform: platform,
            defaultPlatform: defaultPlatform,
            scope: scope,
            name: name,
            runtime: runtime,
            state: state,
            ready: ready
        ),
        hdc: hdc
    )
}

struct HostAppCommandPlan {
    let action: String
    let runtimeScope: String
    let target: String
    let command: TKHostCommand
    let artifacts: [String]
    let note: String
}

private func hostAppRuntimeScope(selection: HostDeviceSelectionResult) -> String {
    if selection.target.scope == "real", selection.platform == .ios {
        return "host-ios-real-device"
    }
    switch selection.platform {
    case .ios:
        return "host-simulator"
    case .android:
        return "host-android"
    case .harmony:
        return "host-harmony"
    }
}

private func hostAppPublicTarget(selection: HostDeviceSelectionResult, appID: String? = nil) -> String {
    let base: String
    if selection.target.scope == "real" {
        base = selection.target.target
    } else {
        switch selection.platform {
        case .ios:
            base = "sim:\(selection.target.target)"
        case .android:
            base = "android:\(selection.target.target)"
        case .harmony:
            base = "harmony:\(selection.target.target)"
        }
    }
    guard let appID, !appID.isEmpty else {
        return base
    }
    return "\(base)/app:\(appID)"
}

private func hostAppSubmissionNote(_ action: String, followUp: String) -> String {
    "Host action was submitted for \(action); hostAction.ok=true is not business readiness. Verify with \(followUp)."
}

func planHostAppInstall(
    selection: HostDeviceSelectionResult,
    app: String?,
    apk: String?,
    hap: String?,
    adb: String,
    hdc: String,
    devicectlArtifacts: (json: String, log: String)?
) throws -> HostAppCommandPlan {
    switch selection.platform {
    case .ios:
        guard let app else {
            throw ValidationError("iOS app install requires --app.")
        }
        let command: TKHostCommand
        let artifacts: [String]
        if selection.target.scope == "real" {
            let devicectlArtifacts = try devicectlArtifacts ?? freshDevicectlArtifactPaths(action: "app-install")
            command = TKDevicectlCommand.installApp(identifier: selection.target.rawTarget, appPath: app, jsonOutput: devicectlArtifacts.json, logOutput: devicectlArtifacts.log)
            artifacts = [app, devicectlArtifacts.json, devicectlArtifacts.log]
        } else {
            command = TKSimctlCommand.installApp(udid: selection.target.target, appPath: app)
            artifacts = [app]
        }
        return HostAppCommandPlan(action: "app.install", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection), command: command, artifacts: artifacts, note: hostAppSubmissionNote("app.install", followUp: "`triton app info`, `triton smoke`, wait/assert, or evidence"))
    case .android:
        guard let apk else {
            throw ValidationError("Android app install requires --apk.")
        }
        return HostAppCommandPlan(action: "app.install", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection), command: TKAndroidADBCommand.installAPK(serial: selection.target.rawTarget, apkPath: apk, executable: adb), artifacts: [apk], note: hostAppSubmissionNote("app.install", followUp: "`triton app list --platform android`, launch + wait/assert, or evidence"))
    case .harmony:
        guard let hap else {
            throw ValidationError("Harmony app install requires --hap.")
        }
        return HostAppCommandPlan(action: "app.install", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection), command: TKHarmonyHDCCommand.installHap(target: selection.target.rawTarget, hapPath: hap, executable: hdc), artifacts: [hap], note: hostAppSubmissionNote("app.install", followUp: "`triton app info --platform harmony`, launch + wait/assert, or evidence"))
    }
}

func planHostAppLaunch(
    selection: HostDeviceSelectionResult,
    bundleID: String?,
    packageName: String?,
    activity: String?,
    bundle: String?,
    ability: String?,
    payloadURL: String?,
    adb: String,
    hdc: String,
    devicectlArtifacts: (json: String, log: String)?
) throws -> HostAppCommandPlan {
    switch selection.platform {
    case .ios:
        guard let bundleID else {
            throw ValidationError("iOS app launch requires --bundle-id.")
        }
        let command: TKHostCommand
        let artifacts: [String]
        if selection.target.scope == "real" {
            let devicectlArtifacts = try devicectlArtifacts ?? freshDevicectlArtifactPaths(action: payloadURL == nil ? "app-launch" : "app-open-url")
            command = TKDevicectlCommand.launchApp(identifier: selection.target.rawTarget, bundleID: bundleID, payloadURL: payloadURL, jsonOutput: devicectlArtifacts.json, logOutput: devicectlArtifacts.log)
            artifacts = [devicectlArtifacts.json, devicectlArtifacts.log]
        } else if let payloadURL {
            command = TKSimctlCommand.openURL(udid: selection.target.target, url: payloadURL)
            artifacts = []
        } else {
            command = TKSimctlCommand.launchApp(udid: selection.target.target, bundleID: bundleID)
            artifacts = []
        }
        return HostAppCommandPlan(action: payloadURL == nil ? "app.launch" : "app.open-url", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundleID), command: command, artifacts: artifacts, note: hostAppSubmissionNote(payloadURL == nil ? "app.launch" : "app.open-url", followUp: "`triton status`, wait/assert, smoke, or evidence"))
    case .android:
        let packageID = packageName ?? bundleID
        guard let packageID else {
            throw ValidationError("Android app launch requires --package-name.")
        }
        guard let activity, !activity.isEmpty else {
            throw ValidationError("Android launch command planning requires a resolved --activity.")
        }
        return HostAppCommandPlan(action: "app.launch", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: packageID), command: TKAndroidADBCommand.launch(serial: selection.target.rawTarget, packageName: packageID, activity: activity, executable: adb), artifacts: [], note: hostAppSubmissionNote("app.launch", followUp: "`triton wait --platform android`, observe, screenshot, smoke, or evidence"))
    case .harmony:
        guard let bundle, let ability else {
            throw ValidationError("Harmony app launch requires --bundle and --ability.")
        }
        return HostAppCommandPlan(action: "app.launch", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundle), command: TKHarmonyHDCCommand.appLaunch(target: selection.target.rawTarget, bundleName: bundle, abilityName: ability, executable: hdc), artifacts: [], note: hostAppSubmissionNote("app.launch", followUp: "`triton wait --platform harmony`, observe, screenshot, smoke, or evidence"))
    }
}

func planHostAppOpenURL(
    selection: HostDeviceSelectionResult,
    url: String,
    bundleID: String?,
    packageName: String?,
    bundle: String?,
    ability: String?,
    adb: String,
    hdc: String,
    devicectlArtifacts: (json: String, log: String)?
) throws -> HostAppCommandPlan {
    switch selection.platform {
    case .ios:
        if selection.target.scope == "real" {
            return try planHostAppLaunch(selection: selection, bundleID: bundleID, packageName: nil, activity: nil, bundle: nil, ability: nil, payloadURL: url, adb: adb, hdc: hdc, devicectlArtifacts: devicectlArtifacts)
        }
        return HostAppCommandPlan(action: "app.open-url", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection), command: TKSimctlCommand.openURL(udid: selection.target.target, url: url), artifacts: [], note: hostAppSubmissionNote("app.open-url", followUp: "`triton wait`, `triton assert`, smoke, or evidence"))
    case .android:
        return HostAppCommandPlan(action: "app.open-url", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection), command: TKAndroidADBCommand.openURL(serial: selection.target.rawTarget, url: url, packageName: packageName, executable: adb), artifacts: [], note: hostAppSubmissionNote("app.open-url", followUp: "`triton wait --platform android`, observe, screenshot, smoke, or evidence"))
    case .harmony:
        guard let bundle, let ability else {
            throw ValidationError("Harmony app open-url requires --bundle and --ability.")
        }
        return HostAppCommandPlan(action: "app.open-url", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundle), command: TKHarmonyHDCCommand.appOpenURL(target: selection.target.rawTarget, bundleName: bundle, abilityName: ability, url: url, executable: hdc), artifacts: [], note: hostAppSubmissionNote("app.open-url", followUp: "`triton wait --platform harmony`, observe, screenshot, smoke, or evidence"))
    }
}

func planHostAppTerminate(
    selection: HostDeviceSelectionResult,
    bundleID: String?,
    packageName: String?,
    bundle: String?,
    adb: String,
    hdc: String,
    devicectlArtifacts: (json: String, log: String)?
) throws -> HostAppCommandPlan {
    switch selection.platform {
    case .ios:
        guard let bundleID else {
            throw ValidationError("iOS app terminate requires --bundle-id.")
        }
        let command: TKHostCommand
        let artifacts: [String]
        if selection.target.scope == "real" {
            let devicectlArtifacts = try devicectlArtifacts ?? freshDevicectlArtifactPaths(action: "app-terminate")
            command = TKDevicectlCommand.terminateApp(identifier: selection.target.rawTarget, bundleID: bundleID, jsonOutput: devicectlArtifacts.json, logOutput: devicectlArtifacts.log)
            artifacts = [devicectlArtifacts.json, devicectlArtifacts.log]
        } else {
            command = TKSimctlCommand.terminateApp(udid: selection.target.target, bundleID: bundleID)
            artifacts = []
        }
        return HostAppCommandPlan(action: "app.terminate", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundleID), command: command, artifacts: artifacts, note: hostAppSubmissionNote("app.terminate", followUp: "`triton app launch`, smoke, or evidence"))
    case .android:
        let packageID = packageName ?? bundleID
        guard let packageID else {
            throw ValidationError("Android app terminate requires --package-name.")
        }
        return HostAppCommandPlan(action: "app.terminate", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: packageID), command: TKAndroidADBCommand.forceStop(serial: selection.target.rawTarget, packageName: packageID, executable: adb), artifacts: [], note: hostAppSubmissionNote("app.terminate", followUp: "`triton app launch`, smoke, or evidence"))
    case .harmony:
        guard let bundle else {
            throw ValidationError("Harmony app terminate requires --bundle.")
        }
        return HostAppCommandPlan(action: "app.terminate", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundle), command: TKHarmonyHDCCommand.forceStop(target: selection.target.rawTarget, bundleName: bundle, executable: hdc), artifacts: [], note: hostAppSubmissionNote("app.terminate", followUp: "`triton app launch`, smoke, or evidence"))
    }
}

func planHostAppUninstall(
    selection: HostDeviceSelectionResult,
    bundleID: String,
    adb: String,
    devicectlArtifacts: (json: String, log: String)?
) throws -> HostAppCommandPlan {
    switch selection.platform {
    case .ios:
        let command: TKHostCommand
        let artifacts: [String]
        if selection.target.scope == "real" {
            let devicectlArtifacts = try devicectlArtifacts ?? freshDevicectlArtifactPaths(action: "app-uninstall")
            command = TKDevicectlCommand.uninstallApp(identifier: selection.target.rawTarget, bundleID: bundleID, jsonOutput: devicectlArtifacts.json, logOutput: devicectlArtifacts.log)
            artifacts = [devicectlArtifacts.json, devicectlArtifacts.log]
        } else {
            command = TKSimctlCommand.uninstallApp(udid: selection.target.target, bundleID: bundleID)
            artifacts = []
        }
        return HostAppCommandPlan(action: "app.uninstall", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundleID), command: command, artifacts: artifacts, note: "Host action was submitted for app.uninstall after --confirm; verify removal with app info/list or evidence.")
    case .android:
        return HostAppCommandPlan(action: "app.uninstall", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundleID), command: TKAndroidADBCommand.uninstall(serial: selection.target.rawTarget, packageName: bundleID, executable: adb), artifacts: [], note: "Host action was submitted for app.uninstall after --confirm; verify removal with app list or evidence.")
    case .harmony:
        throw ValidationError("Harmony uninstall is not exposed in P1; destructive uninstall remains unsupported until a stable hdc/bm contract is selected.")
    }
}

func planHostAppInfo(
    selection: HostDeviceSelectionResult,
    bundleID: String,
    adb: String,
    hdc: String,
    devicectlArtifacts: (json: String, log: String)?
) throws -> HostAppCommandPlan {
    switch selection.platform {
    case .ios:
        let command: TKHostCommand
        let artifacts: [String]
        if selection.target.scope == "real" {
            let devicectlArtifacts = try devicectlArtifacts ?? freshDevicectlArtifactPaths(action: "app-info")
            command = TKDevicectlCommand.deviceInfoApps(identifier: selection.target.rawTarget, jsonOutput: devicectlArtifacts.json, logOutput: devicectlArtifacts.log)
            artifacts = [devicectlArtifacts.json, devicectlArtifacts.log]
        } else {
            command = TKSimctlCommand.appInfo(udid: selection.target.target, bundleID: bundleID)
            artifacts = []
        }
        return HostAppCommandPlan(action: "app.info", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundleID), command: command, artifacts: artifacts, note: "App metadata was requested. Inspect the bounded output or artifact; this does not prove business readiness.")
    case .android:
        return HostAppCommandPlan(action: "app.info", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundleID), command: TKAndroidADBCommand.dumpsysPackage(serial: selection.target.rawTarget, packageName: bundleID, executable: adb), artifacts: [], note: "Android package metadata was requested.")
    case .harmony:
        return HostAppCommandPlan(action: "app.info", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection, appID: bundleID), command: TKHarmonyHDCCommand.appInspect(target: selection.target.rawTarget, bundleName: bundleID, executable: hdc), artifacts: [], note: "Harmony app metadata was requested with bm dump.")
    }
}

func planHostAppList(
    selection: HostDeviceSelectionResult,
    userOnly: Bool,
    adb: String,
    devicectlArtifacts: (json: String, log: String)?
) throws -> HostAppCommandPlan {
    switch selection.platform {
    case .ios:
        let command: TKHostCommand
        let artifacts: [String]
        if selection.target.scope == "real" {
            let devicectlArtifacts = try devicectlArtifacts ?? freshDevicectlArtifactPaths(action: "app-list")
            command = TKDevicectlCommand.deviceInfoApps(identifier: selection.target.rawTarget, jsonOutput: devicectlArtifacts.json, logOutput: devicectlArtifacts.log)
            artifacts = [devicectlArtifacts.json, devicectlArtifacts.log]
        } else {
            command = TKSimctlCommand.listApps(udid: selection.target.target)
            artifacts = []
        }
        return HostAppCommandPlan(action: "app.list", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection), command: command, artifacts: artifacts, note: "App list was requested. Use app info or smoke for follow-up verification.")
    case .android:
        return HostAppCommandPlan(action: "app.list", runtimeScope: hostAppRuntimeScope(selection: selection), target: hostAppPublicTarget(selection: selection), command: TKAndroidADBCommand.listPackages(serial: selection.target.rawTarget, userOnly: userOnly, executable: adb), artifacts: [], note: "Android package list was requested.")
    case .harmony:
        throw ValidationError("Harmony app list requires a known --bundle; use `triton app info --platform harmony --bundle <bundle> --json`.")
    }
}

struct HostApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Control simulator apps through host-side Apple tools",
        subcommands: [
            HostAppList.self,
            HostAppInfo.self,
            HostAppInspect.self,
            HostAppInstall.self,
            HostAppUninstall.self,
            HostAppLaunch.self,
            HostAppTerminate.self,
            HostAppGo.self,
            HostAppOpenURL.self,
            HostAppContainer.self,
            HostAppPrefs.self,
        ]
    )
}

struct HostAppList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List installed simulator or emulator apps")

    @Option(help: "Platform adapter: ios or android") var platform: HostAppPlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Flag(help: "Only include User apps") var userOnly = false
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let effectivePlatform = platform ?? .ios
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: effectivePlatform,
                defaultPlatform: nil,
                scope: scope,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            let plan = try planHostAppList(selection: selection, userOnly: userOnly, adb: adb, devicectlArtifacts: nil)
            if selection.platform == .ios, selection.target.scope == "real" {
                try runSimpleHostCommand(
                    action: plan.action,
                    runtimeScope: plan.runtimeScope,
                    target: plan.target,
                    selection: selection,
                    command: plan.command,
                    outputFormat: outputFormat,
                    artifacts: plan.artifacts,
                    note: plan.note
                )
                return
            }
            let apps: [TKHostInstalledApp]
            switch hostAppPlatform(from: selection.platform) {
            case .ios:
                let result = try runHostCommand(plan.command)
                var parsedApps = try TKSimctlAppInfoParser.parseList(result.stdoutData)
                if userOnly {
                    parsedApps = parsedApps.filter { $0.applicationType == "User" }
                }
                apps = parsedApps
            case .android:
                let result = try runHostCommand(plan.command)
                apps = TKAndroidPackageListParser.parse(result.stdout)
            case .harmony:
                try failHostValidation(
                    code: "unsupported_capability",
                    message: "Harmony app list is not implemented through `triton app list` yet.",
                    hint: "Use `triton app inspect --platform harmony --bundle <bundle> --json` for a known bundle.",
                    outputFormat: outputFormat
                )
            }
            let output = HostAppListOutput(
                ok: true,
                action: "app.list",
                simulatorUDID: selection.target.target,
                userOnly: userOnly,
                count: apps.count,
                apps: apps
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for app in apps {
                    print("\(app.bundleID)\t\(app.applicationType ?? "-")\t\(app.displayName ?? app.name ?? "-")\t\(app.path ?? "-")")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInfo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "info", abstract: "Show installed simulator or emulator app information")

    @Option(help: "Platform adapter: ios or android") var platform: HostAppPlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier or Android package name") var bundleID: String
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let effectivePlatform = platform ?? .ios
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: effectivePlatform,
                defaultPlatform: nil,
                scope: scope,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            let plan = try planHostAppInfo(selection: selection, bundleID: bundleID, adb: adb, hdc: "hdc", devicectlArtifacts: nil)
            if (selection.platform == .ios && selection.target.scope == "real") || selection.platform == .harmony {
                try runSimpleHostCommand(
                    action: plan.action,
                    runtimeScope: plan.runtimeScope,
                    target: plan.target,
                    selection: selection,
                    command: plan.command,
                    outputFormat: outputFormat,
                    artifacts: plan.artifacts,
                    note: plan.note
                )
                return
            }
            let app: TKHostInstalledApp
            switch hostAppPlatform(from: selection.platform) {
            case .ios:
                let result = try runHostCommand(plan.command)
                app = try TKSimctlAppInfoParser.parseAppInfo(result.stdoutData, bundleID: bundleID)
            case .android:
                let result = try runHostCommand(plan.command)
                app = TKAndroidPackageInfoParser.parse(result.stdout, packageName: bundleID)
            case .harmony:
                try failHostValidation(
                    code: "unsupported_capability",
                    message: "Use `triton app inspect --platform harmony` for Harmony app metadata.",
                    hint: "Pass `triton app inspect --platform harmony --bundle <bundle> --json`.",
                    outputFormat: outputFormat
                )
            }
            let output = HostAppInfoOutput(
                ok: true,
                action: "app.info",
                simulatorUDID: selection.target.target,
                bundleID: bundleID,
                app: app
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print("\(app.bundleID)\t\(app.applicationType ?? "-")\t\(app.displayName ?? app.name ?? "-")\t\(app.path ?? "-")")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect a platform app with host tools")

    @Option(help: "Platform adapter: android or harmony") var platform: HostPlatform = .harmony
    @Option(help: "Android package name or Harmony bundle name") var bundle: String
    @Option(help: "Unified host device selector: alias, android:<serial>, harmony:<target>, raw id, or current") var device: String?
    @Option(help: "Device name filter, for example Pixel 8") var name: String?
    @Option(help: "Runtime filter, for example sdk_gphone64_arm64") var runtime: String?
    @Option(help: "Target state filter, for example device or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Compatibility target id, for example an adb serial or 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            switch platform {
            case .android:
                let selection = try resolveHostDeviceSelection(
                    request: HostDeviceSelectionRequest(
                        device: device ?? target,
                        platform: .android,
                        name: name,
                        runtime: runtime,
                        state: state,
                        ready: ready
                    ),
                    hdc: hdc,
                    adb: adb
                )
                let response = try inspectAndroidApp(selected: selection.target, bundle: bundle, adb: adb)
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("\(response.app.bundleID)\t\(response.app.applicationType ?? "-")\t\(response.app.displayName ?? response.app.name ?? "-")\t\(response.app.path ?? "-")")
                }
            case .harmony:
                let selected = try resolveHarmonyTarget(target: target ?? device, hdc: hdc)
                try runSimpleHostCommand(
                    action: "app.inspect",
                    runtimeScope: "host-harmony",
                    target: "harmony:\(selected.target)/app:\(bundle)",
                    command: TKHarmonyHDCCommand.appInspect(target: selected.target, bundleName: bundle, executable: hdc),
                    outputFormat: outputFormat,
                    note: "Harmony app metadata was inspected with bm dump."
                )
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Install an app bundle into a simulator or emulator")

    @Option(help: "Platform adapter: ios, android, or harmony") var platform: HostAppPlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to .app bundle") var app: String?
    @Option(help: "Path to Android .apk package") var apk: String?
    @Option(help: "Path to Harmony .hap package") var hap: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let effectivePlatform = platform ?? (apk != nil ? .android : (hap != nil ? .harmony : .ios))
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: effectivePlatform,
                defaultPlatform: nil,
                scope: scope,
                simulator: simulator,
                target: target,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: hdc
            )
            let plan = try planHostAppInstall(selection: selection, app: app, apk: apk, hap: hap, adb: adb, hdc: hdc, devicectlArtifacts: nil)
            try runSimpleHostCommand(
                action: plan.action,
                runtimeScope: plan.runtimeScope,
                target: plan.target,
                selection: selection,
                command: plan.command,
                outputFormat: outputFormat,
                artifacts: plan.artifacts,
                note: plan.note
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppUninstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall", abstract: "Uninstall an app from a simulator or emulator")

    @Option(help: "Platform adapter: ios or android") var platform: HostAppPlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier or Android package name") var bundleID: String
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Confirm uninstalling the app from the target") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard confirm else {
            try failHostValidation(
                code: "destructive_action_requires_policy",
                message: "App uninstall requires --confirm.",
                hint: "Rerun with `--confirm` after verifying the simulator and bundle id.",
                outputFormat: outputFormat
            )
        }
        do {
            let effectivePlatform = platform ?? .ios
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: effectivePlatform,
                defaultPlatform: nil,
                scope: scope,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            let plan = try planHostAppUninstall(selection: selection, bundleID: bundleID, adb: adb, devicectlArtifacts: nil)
            try runSimpleHostCommand(
                action: plan.action,
                runtimeScope: plan.runtimeScope,
                target: plan.target,
                selection: selection,
                command: plan.command,
                outputFormat: outputFormat,
                artifacts: plan.artifacts,
                note: plan.note
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppLaunch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "launch", abstract: "Launch an installed simulator app")

    @Option(help: "Platform adapter: ios, android, or harmony") var platform: HostAppPlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "iOS app bundle identifier") var bundleID: String?
    @Option(help: "Android package name") var packageName: String?
    @Option(help: "Android activity name, for explicit component launch") var activity: String?
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Harmony ability name") var ability: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            try ensureHostDeviceSelectorCompatibility(device: device, simulator: simulator, target: target)
            let defaultPlatform: HostDevicePlatform? = platform == nil && device == nil ? (packageName != nil ? .android : (bundle != nil ? .harmony : .ios)) : nil
            let selection = try resolveHostDeviceSelection(
                request: hostDeviceSelectionRequest(
                    device: device ?? simulator ?? target,
                    platform: platform,
                    defaultPlatform: defaultPlatform,
                    scope: scope,
                    name: name,
                    runtime: runtime,
                    state: state,
                    ready: ready
                ),
                hdc: hdc
            )
            switch hostAppPlatform(from: selection.platform) {
        case .ios:
            let plan = try planHostAppLaunch(selection: selection, bundleID: bundleID, packageName: nil, activity: nil, bundle: nil, ability: nil, payloadURL: nil, adb: adb, hdc: hdc, devicectlArtifacts: nil)
            try runSimpleHostCommand(
                action: plan.action,
                runtimeScope: plan.runtimeScope,
                target: plan.target,
                selection: selection,
                command: plan.command,
                outputFormat: outputFormat,
                artifacts: plan.artifacts,
                note: plan.note
            )
        case .android:
            let packageID = packageName ?? bundleID
            guard let packageID else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "Android app launch requires --package-name.",
                    hint: "Pass `--platform android --package-name <package>`; add `--activity <Activity>` for an explicit component.",
                    outputFormat: outputFormat
                )
            }
            try runAndroidAppLaunchCommand(
                selection: selection,
                packageName: packageID,
                activity: activity,
                adb: adb,
                outputFormat: outputFormat
            )
        case .harmony:
            let plan = try planHostAppLaunch(selection: selection, bundleID: nil, packageName: nil, activity: nil, bundle: bundle, ability: ability, payloadURL: nil, adb: adb, hdc: hdc, devicectlArtifacts: nil)
            try runSimpleHostCommand(
                action: plan.action,
                runtimeScope: plan.runtimeScope,
                target: plan.target,
                selection: selection,
                command: plan.command,
                outputFormat: outputFormat,
                artifacts: plan.artifacts,
                note: plan.note
            )
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

private func runAndroidAppLaunchCommand(
    selection: HostDeviceSelectionResult,
    packageName: String,
    activity: String?,
    adb: String,
    outputFormat: ClientOutputFormat
) throws {
    let component: String
    let hostTarget = selection.target.rawTarget
    if let activity, !activity.isEmpty {
        component = "\(packageName)/\(activity)"
    } else {
        let resolveResult = try runHostCommand(
            TKAndroidADBCommand.resolveActivity(
                serial: hostTarget,
                packageName: packageName,
                executable: adb
            )
        )
        let resolved = TKAndroidResolveActivityParser.parse(
            resolveResult.stdout,
            stderr: resolveResult.stderr,
            exitCode: resolveResult.exitCode
        )
        guard resolved.ok, let resolvedComponent = resolved.component else {
            throw HostCommandRunError.nonZeroExit(
                command: TKAndroidADBCommand.resolveActivity(
                    serial: hostTarget,
                    packageName: packageName,
                    executable: adb
                ),
                result: resolveResult
            )
        }
        component = resolvedComponent
    }

    try runSimpleHostCommand(
        action: "app.launch",
        runtimeScope: "host-android",
        target: hostAppPublicTarget(selection: selection, appID: packageName),
        selection: selection,
        command: TKAndroidADBCommand.launch(
            serial: hostTarget,
            component: component,
            executable: adb
        ),
        outputFormat: outputFormat,
        note: hostAppSubmissionNote("app.launch", followUp: "`triton wait --platform android`, observe, screenshot, smoke, or evidence")
    )
}

struct HostAppTerminate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "terminate", abstract: "Terminate a running simulator or Harmony app")

    @Option(help: "Platform adapter: ios, android, or harmony") var platform: HostAppPlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "iOS app bundle identifier") var bundleID: String?
    @Option(help: "Android package name") var packageName: String?
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let effectivePlatform = platform ?? (packageName != nil ? .android : (bundle != nil ? .harmony : .ios))
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: effectivePlatform,
                defaultPlatform: nil,
                scope: scope,
                simulator: simulator,
                target: target,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: hdc
            )
            let plan = try planHostAppTerminate(selection: selection, bundleID: bundleID, packageName: packageName, bundle: bundle, adb: adb, hdc: hdc, devicectlArtifacts: nil)
            try runSimpleHostCommand(
                action: plan.action,
                runtimeScope: plan.runtimeScope,
                target: plan.target,
                selection: selection,
                command: plan.command,
                outputFormat: outputFormat,
                artifacts: plan.artifacts,
                note: plan.note
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppGo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "go", abstract: "Open a URL and return runtime readiness plus snapshot")

    @Argument(help: "URL to open") var url: String
    @Option(help: "Device scope: simulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(name: .customLong("runtime-target"), help: "iOS embedded runtime target id from `triton list`") var runtimeTarget: String = TKLocalTargetID
    @Option(name: .customLong("snapshot-include"), help: "Comma-separated snapshot sections") var snapshotInclude: String = "app,scene,route,ax,geometry"
    @Option(name: .customLong("max-ax-nodes"), help: "Maximum AX nodes in the runtime snapshot") var maxAXNodes: Int?
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Runtime wait timeout in seconds") var timeout: Double = 20
    @Option(help: "Runtime wait polling interval in seconds") var interval: Double = 0.5
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            try ensureHostDeviceSelectorCompatibility(device: device, simulator: simulator, target: nil)
            let selection = try resolveDefaultIOSHostDeviceSelection(
                device: device,
                simulator: simulator,
                scope: scope,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready
            )
            let include = snapshotInclude.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let summary = try await runIOSAppOpenURLFlow(options: IOSAppOpenURLFlowOptions(
                simulator: selection.target.target,
                runtimeTarget: runtimeTarget,
                url: url,
                waitReady: true,
                snapshot: true,
                snapshotInclude: include,
                maxAXNodes: maxAXNodes,
                host: host,
                port: port,
                timeout: timeout,
                interval: interval
            ))
            switch outputFormat {
            case .json:
                print(try encodeJSON(summary))
            case .text:
                print("status: \(summary.status.rawValue)")
                print("source: \(summary.hostAction.sourceCommand)")
                if let ready = summary.ready {
                    print("runtime: connected=\(ready.connected) hierarchy=\(ready.hierarchyCacheState ?? "-")")
                }
                if let snapshot = summary.snapshot {
                    print("snapshot: app=\(snapshot.appName ?? "-") axNodes=\(snapshot.axNodeCount ?? 0)")
                }
            }
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct HostAppOpenURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open-url", abstract: "Open a URL in a simulator or Harmony app")

    @Argument(help: "URL to open") var url: String
    @Option(help: "Platform adapter: ios, android, or harmony") var platform: HostAppPlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Unified host device selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "iOS app bundle identifier for real-device devicectl payload launch") var bundleID: String?
    @Option(help: "Android package name to constrain VIEW intent") var packageName: String?
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Harmony ability name") var ability: String?
    @Option(help: "Explicit Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(name: .customLong("runtime-target"), help: "iOS embedded runtime target id from `triton list`") var runtimeTarget: String = TKLocalTargetID
    @Flag(name: .customLong("wait-ready"), help: "After opening the URL, wait until the embedded runtime is connected and has an active hierarchy") var waitReady = false
    @Flag(help: "After opening the URL, return an embedded runtime snapshot summary") var snapshot = false
    @Option(name: .customLong("snapshot-include"), help: "Comma-separated snapshot sections") var snapshotInclude: String = "app,scene,route,ax,geometry"
    @Option(name: .customLong("max-ax-nodes"), help: "Maximum AX nodes in the runtime snapshot") var maxAXNodes: Int?
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Runtime wait timeout in seconds") var timeout: Double = 20
    @Option(help: "Runtime wait polling interval in seconds") var interval: Double = 0.5
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            try ensureHostDeviceSelectorCompatibility(device: device, simulator: simulator, target: target)
            let defaultPlatform: HostDevicePlatform? = platform == nil && device == nil ? (packageName != nil ? .android : (bundle != nil ? .harmony : .ios)) : nil
            let selection = try resolveHostDeviceSelection(
                request: hostDeviceSelectionRequest(
                    device: device ?? simulator ?? target,
                    platform: platform,
                    defaultPlatform: defaultPlatform,
                    scope: scope,
                    name: name,
                    runtime: runtime,
                    state: state,
                    ready: ready
                ),
                hdc: hdc
            )
            switch hostAppPlatform(from: selection.platform) {
        case .ios:
            if selection.target.scope == "real" {
                let plan = try planHostAppOpenURL(selection: selection, url: url, bundleID: bundleID, packageName: nil, bundle: nil, ability: nil, adb: adb, hdc: hdc, devicectlArtifacts: nil)
                try runSimpleHostCommand(
                    action: plan.action,
                    runtimeScope: plan.runtimeScope,
                    target: plan.target,
                    selection: selection,
                    command: plan.command,
                    outputFormat: outputFormat,
                    artifacts: plan.artifacts,
                    note: plan.note
                )
            } else if waitReady || snapshot {
                do {
                    let include = snapshotInclude.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    let summary = try await runIOSAppOpenURLFlow(options: IOSAppOpenURLFlowOptions(
                        simulator: selection.target.target,
                        runtimeTarget: runtimeTarget,
                        url: url,
                        waitReady: waitReady,
                        snapshot: snapshot,
                        snapshotInclude: include,
                        maxAXNodes: maxAXNodes,
                        host: host,
                        port: port,
                        timeout: timeout,
                        interval: interval
                    ))
                    switch outputFormat {
                    case .json:
                        print(try encodeJSON(summary))
                    case .text:
                        print("status: \(summary.status.rawValue)")
                        print("source: \(summary.hostAction.sourceCommand)")
                        if let ready = summary.ready {
                            print("runtime: connected=\(ready.connected) hierarchy=\(ready.hierarchyCacheState ?? "-")")
                        }
                        if let snapshot = summary.snapshot {
                            print("snapshot: app=\(snapshot.appName ?? "-") axNodes=\(snapshot.axNodeCount ?? 0)")
                        }
                    }
                } catch {
                    try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
                }
            } else {
                let plan = try planHostAppOpenURL(selection: selection, url: url, bundleID: bundleID, packageName: nil, bundle: nil, ability: nil, adb: adb, hdc: hdc, devicectlArtifacts: nil)
                try runSimpleHostCommand(
                    action: plan.action,
                    runtimeScope: plan.runtimeScope,
                    target: plan.target,
                    selection: selection,
                    command: plan.command,
                    outputFormat: outputFormat,
                    artifacts: plan.artifacts,
                    note: plan.note
                )
            }
        case .android:
            let plan = try planHostAppOpenURL(selection: selection, url: url, bundleID: nil, packageName: packageName, bundle: nil, ability: nil, adb: adb, hdc: hdc, devicectlArtifacts: nil)
            try runSimpleHostCommand(
                action: plan.action,
                runtimeScope: plan.runtimeScope,
                target: plan.target,
                selection: selection,
                command: plan.command,
                outputFormat: outputFormat,
                artifacts: plan.artifacts,
                note: plan.note
            )
        case .harmony:
            let plan = try planHostAppOpenURL(selection: selection, url: url, bundleID: nil, packageName: nil, bundle: bundle, ability: ability, adb: adb, hdc: hdc, devicectlArtifacts: nil)
            try runSimpleHostCommand(
                action: plan.action,
                runtimeScope: plan.runtimeScope,
                target: plan.target,
                selection: selection,
                command: plan.command,
                outputFormat: outputFormat,
                artifacts: plan.artifacts,
                note: plan.note
            )
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppContainer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "container", abstract: "Print a simulator app container path")

    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Option(help: "Container kind: app, data, or groups") var kind: TKHostAppContainerKind = .data
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                scope: nil,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            let result = try runHostCommand(TKSimctlCommand.appContainer(udid: selection.target.target, bundleID: bundleID, kind: kind))
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = HostAppContainerOutput(
                ok: true,
                action: "app.container",
                simulatorUDID: selection.target.target,
                bundleID: bundleID,
                kind: kind.rawValue,
                path: path
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print(path)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppPrefs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prefs",
        abstract: "Read and update simulator app preferences as JSON",
        subcommands: [HostAppPrefsDump.self, HostAppPrefsGet.self, HostAppPrefsSet.self]
    )
}

struct HostAppPrefsDump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "dump", abstract: "Dump app preferences")

    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                scope: nil,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try printPreferences(simulator: selection.target.target, bundleID: bundleID, key: nil, outputFormat: outputFormat)
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppPrefsGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read one app preference value")

    @Argument(help: "Preference key") var key: String
    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                scope: nil,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try printPreferences(simulator: selection.target.target, bundleID: bundleID, key: key, outputFormat: outputFormat)
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

typealias AndroidAppInspectHostRunner = (TKHostCommand) throws -> HostProcessResult

func inspectAndroidApp(
    selected: HostDeviceTarget,
    bundle: String,
    adb: String = "adb",
    runner: AndroidAppInspectHostRunner = { command in try runHostCommand(command) }
) throws -> HostAppInfoOutput {
    let command = TKAndroidADBCommand.dumpsysPackage(
        serial: selected.rawTarget,
        packageName: bundle,
        executable: adb
    )
    let result = try runner(command)
    guard result.exitCode == 0 else {
        throw HostCommandRunError.nonZeroExit(command: command, result: result)
    }
    let app = TKAndroidPackageInfoParser.parse(result.stdout, packageName: bundle)
    return HostAppInfoOutput(
        ok: true,
        action: "app.inspect",
        simulatorUDID: selected.target,
        bundleID: bundle,
        app: app
    )
}

enum HostPreferenceSetType: String, ExpressibleByArgument {
    case json
    case data
}

struct HostAppPrefsSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set one simulator app preference value")

    @Argument(help: "Preference key") var key: String
    @Argument(help: "JSON value to write when --type json is used") var value: String?
    @Option(help: "Preference value type: json or data") var type: HostPreferenceSetType = .json
    @Option(help: "Base64 payload when --type data is used") var base64: String?
    @Option(help: "Hex payload when --type data is used") var hex: String?
    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                scope: nil,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try setPreference(
                simulator: selection.target.target,
                bundleID: bundleID,
                key: key,
                value: value,
                type: type,
                base64: base64,
                hex: hex,
                outputFormat: outputFormat
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

extension TKHostAppContainerKind: @retroactive ExpressibleByArgument {}
