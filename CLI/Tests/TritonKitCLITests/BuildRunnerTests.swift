import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct BuildRunnerTests {
    @Test("fake archive runner returns artifact paths and stable final summary")
    func fakeArchiveRunnerReturnsArtifactPathsAndStableFinalSummary() throws {
        let project = try makeTemporaryProject()
        let archive = project.appendingPathComponent("App.xcarchive")
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        let invocation = ResolvedXcodeInvocation(
            workspace: nil,
            project: project.appendingPathComponent("App.xcodeproj").path,
            package: nil,
            scheme: "App",
            configuration: "Release",
            sdk: "iphoneos",
            destination: "generic/platform=iOS",
            derivedDataPath: ".triton/DerivedData",
            buildSettings: ["CODE_SIGN_STYLE=Manual"],
            derivedDataCache: TKXcodeDerivedDataCacheInfo(path: ".triton/DerivedData", exists: false, cacheState: "empty", incrementalExpected: false, cleanupPolicy: "preserve-by-default", guidance: "preserve") ,
            simulatorUDID: nil,
            device: nil
        )
        var captured: TKHostCommand?
        let summary = try runXcodeArchive(
            invocation: invocation,
            archivePath: archive.path,
            jsonl: true,
            hostCommandRunner: { command, event, jsonl, progress in
                captured = command
                #expect(event == "xcode.archive")
                #expect(jsonl)
                #expect(progress == .compact)
                return (HostProcessResult(
                    stdoutData: Data("** ARCHIVE SUCCEEDED **\n".utf8),
                    stderrData: Data(),
                    exitCode: 0,
                    sourceCommand: hostSourceCommand(command),
                    stdoutTruncated: false,
                    stderrTruncated: false,
                    stdoutLogPath: "archive.stdout.log",
                    stderrLogPath: "archive.stderr.log",
                    stdoutBytes: 24,
                    stderrBytes: 0
                ), 42)
            }
        )

        #expect(captured?.argv.contains("archive") == true)
        #expect(summary.ok)
        #expect(summary.action == "xcode.archive")
        #expect(summary.artifactPaths.contains(archive.path))
        #expect(summary.archivePath == archive.path)
        #expect(summary.failureCode == nil)
    }

    @Test("fake export runner maps signing failure and keeps archive/export artifacts")
    func fakeExportRunnerMapsSigningFailureAndKeepsArchiveExportArtifacts() throws {
        let project = try makeTemporaryProject()
        let archive = project.appendingPathComponent("App.xcarchive")
        let export = project.appendingPathComponent("ipa output", isDirectory: true)
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: export, withIntermediateDirectories: true)
        let ipa = export.appendingPathComponent("App.ipa")
        try Data("ipa".utf8).write(to: ipa)
        var captured: TKHostCommand?
        let summary = try runXcodeExport(
            archivePath: archive.path,
            exportOptionsPlist: project.appendingPathComponent("ExportOptions.plist").path,
            exportPath: export.path,
            jsonl: true,
            hostCommandRunner: { command, event, jsonl, progress in
                captured = command
                #expect(event == "xcode.export")
                return (HostProcessResult(
                    stdoutData: Data(),
                    stderrData: Data("Code signing failed: certificate not found\n".utf8),
                    exitCode: 65,
                    sourceCommand: hostSourceCommand(command),
                    stdoutTruncated: false,
                    stderrTruncated: false,
                    stdoutLogPath: "export.stdout.log",
                    stderrLogPath: "export.stderr.log",
                    stdoutBytes: 0,
                    stderrBytes: 39
                ), 17)
            }
        )

        #expect(captured?.argv.starts(with: ["-exportArchive", "-archivePath", archive.path]) == true)
        #expect(summary.ok == false)
        #expect(summary.failureCode == "xcode_signing_failed")
        #expect(summary.artifactPaths.contains(ipa.path))
        #expect(summary.exportPath == export.path)
        #expect(summary.nextActions?.first?.args.contains("--export-options-plist") == true)
    }

    @Test("Android build planner uses project Gradle wrapper and variant task")
    func androidPlannerUsesGradleWrapperAndVariantTask() throws {
        let project = try makeTemporaryProject()
        let gradlew = project.appendingPathComponent("gradlew")
        try writeExecutable(gradlew, body: "exit 0\n")

        let plan = try planCLIBuild(.android(project: project.path, gradle: nil, variant: "debug", device: "android-phone", timeout: nil, discoveryRoot: nil))

        #expect(plan.platform == "android")
        #expect(plan.executable == gradlew.path)
        #expect(plan.arguments == ["assembleDebug"])
        #expect(plan.workingDirectory == project.path)
        #expect(plan.sourceCommand.contains("assembleDebug"))
        #expect(plan.device == "android-phone")
    }

    @Test("Harmony build planner uses hvigor module mode command")
    func harmonyPlannerUsesHvigorModuleModeCommand() throws {
        let project = try makeTemporaryProject()
        let hvigorw = project.appendingPathComponent("hvigorw")
        try writeExecutable(hvigorw, body: "exit 0\n")

        let plan = try planCLIBuild(.harmony(project: project.path, hvigor: nil, module: "entry", mode: "debug", device: "harmony-phone", timeout: nil, discoveryRoot: nil))

        #expect(plan.platform == "harmony")
        #expect(plan.executable == hvigorw.path)
        #expect(plan.arguments == ["--mode", "entry@debug", "assembleHap"])
        #expect(plan.sourceCommand.contains("assembleHap"))
        #expect(plan.device == "harmony-phone")
    }

    @Test("Harmony build planner supports DevEco assembleApp through node and explicit SDK environment")
    func harmonyPlannerSupportsDevEcoAssembleAppThroughNodeAndExplicitSDKEnvironment() throws {
        let project = try makeTemporaryProject()
        let node = project.appendingPathComponent("deveco-node")
        let hvigor = project.appendingPathComponent("hvigor.js")
        try writeExecutable(node, body: "exit 0\n")
        try writeExecutable(hvigor, body: "exit 0\n")

        let plan = try planCLIBuild(.harmony(
            project: project.path,
            hvigor: hvigor.path,
            module: "entry",
            mode: "debug",
            device: nil,
            timeout: nil,
            discoveryRoot: nil,
            node: node.path,
            javaHome: "/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home",
            devecoSdkHome: "/Applications/DevEco-Studio.app/Contents/sdk",
            product: "default",
            task: "assembleApp",
            noDaemon: true
        ))

        #expect(plan.platform == "harmony")
        #expect(plan.executable == node.path)
        #expect(plan.arguments == [hvigor.path, "assembleApp", "--no-daemon", "-p", "product=default", "-p", "buildMode=debug"])
        #expect(plan.environment["JAVA_HOME"] == "/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home")
        #expect(plan.environment["DEVECO_SDK_HOME"] == "/Applications/DevEco-Studio.app/Contents/sdk")
        #expect(plan.environment["PATH"]?.hasPrefix("/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin:") == true)
        #expect(plan.sourceCommand.contains("JAVA_HOME="))
        #expect(plan.sourceCommand.contains("DEVECO_SDK_HOME="))
        #expect(plan.sourceCommand.contains("assembleApp"))
    }

    @Test("missing project and tool failures map to stable codes")
    func missingProjectAndToolFailuresMapToStableCodes() throws {
        let missingProject = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            _ = try planCLIBuild(.android(project: missingProject.path, gradle: nil, variant: "debug", device: nil, timeout: nil, discoveryRoot: nil))
            Issue.record("Expected missing project to fail")
        } catch let error as CLIBuildError {
            #expect(buildErrorDetail(error).code == "validation_failed")
        }

        let project = try makeTemporaryProject()
        do {
            _ = try planCLIBuild(.harmony(project: project.path, hvigor: "/tmp/not-hvigorw", module: "entry", mode: "debug", device: nil, timeout: nil, discoveryRoot: nil))
            Issue.record("Expected missing hvigor to fail")
        } catch let error as CLIBuildError {
            #expect(buildErrorDetail(error).code == "hvigor_not_found")
        }
    }

    @Test("artifact discovery finds APK and HAP outputs")
    func artifactDiscoveryFindsAPKAndHAPOutputs() throws {
        let project = try makeTemporaryProject()
        let apk = project.appendingPathComponent("app/build/outputs/apk/debug/app-debug.apk")
        let hap = project.appendingPathComponent("entry/build/default/outputs/default/entry-default-unsigned.hap")
        try FileManager.default.createDirectory(at: apk.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: hap.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("apk".utf8).write(to: apk)
        try Data("hap".utf8).write(to: hap)

        let androidPlan = CLIBuildPlan(platform: "android", action: "build.android", project: project.path, executable: "gradle", arguments: [], workingDirectory: project.path, variant: "debug", module: nil, mode: nil, device: nil, timeout: 1, discoveryRoot: nil)
        let harmonyPlan = CLIBuildPlan(platform: "harmony", action: "build.harmony", project: project.path, executable: "hvigor", arguments: [], workingDirectory: project.path, variant: nil, module: "entry", mode: "debug", device: nil, timeout: 1, discoveryRoot: nil)
        let android = discoverBuildArtifact(plan: androidPlan)
        let harmony = discoverBuildArtifact(plan: harmonyPlan)

        #expect(android.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path } == apk.standardizedFileURL.path)
        #expect(android?.bytes == 3)
        #expect(harmony.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path } == hap.standardizedFileURL.path)
        #expect(harmony?.bytes == 3)
    }

    @Test("Harmony assembleApp prefers signed HAP sibling and routes the same artifact into nextAction")
    func harmonyAssembleAppPrefersSignedHAPSiblingAndRoutesSameArtifactIntoNextAction() throws {
        let project = try makeTemporaryProject()
        let fakeHvigor = project.appendingPathComponent("fake-hvigor.sh")
        try writeExecutable(fakeHvigor, body: """
        mkdir -p app
        printf 'unsigned' > app/entry-default.hap
        printf 'signed' > app/entry-default-signed.hap
        """)

        let summary = try runCLIBuild(.harmony(
            project: project.path,
            hvigor: fakeHvigor.path,
            module: "entry",
            mode: "debug",
            device: "harmony-real",
            timeout: 30,
            discoveryRoot: nil,
            task: "assembleApp"
        ))

        #expect(summary.ok)
        #expect(summary.artifactPath?.hasSuffix("/app/entry-default-signed.hap") == true)
        #expect(summary.artifact == summary.artifactPath)
        #expect(summary.nextAction?.args.contains("--hap") == true)
        #expect(summary.nextAction?.args.contains { $0.hasSuffix("/app/entry-default-signed.hap") } == true)
        #expect(summary.nextAction?.args.contains(project.appendingPathComponent("app/entry-default.hap").path) == false)
    }

    @Test("Harmony assembleApp fails closed when only unsigned HAPs are discovered")
    func harmonyAssembleAppFailsClosedWhenOnlyUnsignedHAPsAreDiscovered() throws {
        let project = try makeTemporaryProject()
        let fakeHvigor = project.appendingPathComponent("fake-hvigor.sh")
        try writeExecutable(fakeHvigor, body: """
        mkdir -p app
        printf 'unsigned' > app/entry-default-unsigned.hap
        """)
        let request = CLIBuildRequest.harmony(
            project: project.path,
            hvigor: fakeHvigor.path,
            module: "entry",
            mode: "debug",
            device: "harmony-real",
            timeout: 30,
            discoveryRoot: nil,
            task: "assembleApp"
        )

        do {
            _ = try runCLIBuild(request)
            Issue.record("Expected assembleApp with only an unsigned HAP to fail closed")
        } catch {
            let summary = buildFailureSummary(error: error, request: request, jsonl: false)
            #expect(summary.ok == false)
            #expect(summary.artifact == nil)
            #expect(summary.artifactPath == nil)
            #expect(summary.nextAction?.command == "build")
            #expect(summary.nextAction?.args.contains("--hap") == false)
            #expect(summary.error?.code == "hap_artifact_not_found")
        }
    }

    @Test("non-zero Gradle exit keeps logs as artifacts")
    func nonZeroGradleExitKeepsLogsAsArtifacts() throws {
        let project = try makeTemporaryProject()
        let logs = CLIBuildLogPaths(directory: project.path, stdoutLogPath: project.appendingPathComponent("stdout.log").path, stderrLogPath: project.appendingPathComponent("stderr.log").path)
        try Data("warning: deprecated api\n".utf8).write(to: URL(fileURLWithPath: logs.stdoutLogPath))
        try Data("build failed\n".utf8).write(to: URL(fileURLWithPath: logs.stderrLogPath))
        let plan = CLIBuildPlan(platform: "android", action: "build.android", project: project.path, executable: "gradle", arguments: ["assembleDebug"], workingDirectory: project.path, variant: "debug", module: nil, mode: nil, device: nil, timeout: 1, discoveryRoot: nil)
        let error = CLIBuildError.buildFailed(platform: "android", plan: plan, logs: logs, result: CLIBuildProcessResult(exitCode: 1, stdoutBytes: 24, stderrBytes: 13))
        let output = buildFailureSummary(error: error, request: .android(project: project.path, gradle: nil, variant: "debug", device: nil, timeout: nil, discoveryRoot: nil), jsonl: false)

        #expect(output.ok == false)
        #expect(output.error?.code == "gradle_build_failed")
        #expect(output.stdoutLogPath?.hasSuffix("stdout.log") == true)
        #expect(output.stderrLogPath?.hasSuffix("stderr.log") == true)
        #expect(output.nextAction?.command == "build")
    }

    private func makeTemporaryProject() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("triton-build-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeExecutable(_ url: URL, body: String) throws {
        let script = "#!/usr/bin/env bash\nset -euo pipefail\n\(body)"
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
