import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct BuildRuntimeTests {
    @Test("android build planner resolves wrapper and task")
    func androidBuildPlannerResolvesWrapperAndTask() throws {
        let root = try makeTemporaryDirectory()
        let gradle = root.appendingPathComponent("gradlew")
        try writeExecutable(gradle, body: "exit 0\n")

        let plan = try planCLIBuild(.android(project: root.path, gradle: nil, variant: "debug", device: "android-a", timeout: 12, discoveryRoot: nil))

        #expect(plan.platform == "android")
        #expect(plan.executable == gradle.path)
        #expect(plan.arguments == ["assembleDebug"])
        #expect(plan.workingDirectory == root.path)
        #expect(plan.device == "android-a")
        #expect(plan.timeout == 12)
    }

    @Test("android build runner discovers APK and next install action")
    func androidBuildRunnerDiscoversAPKAndNextInstallAction() throws {
        let root = try makeTemporaryDirectory()
        let fakeGradle = root.appendingPathComponent("fake-gradle.sh")
        try writeExecutable(fakeGradle, body: """
        mkdir -p app/build/outputs/apk/debug
        printf 'apk' > app/build/outputs/apk/debug/app-debug.apk
        echo built
        """)

        let summary = try runCLIBuild(.android(project: root.path, gradle: fakeGradle.path, variant: "debug", device: "android-a", timeout: 30, discoveryRoot: nil))

        #expect(summary.ok)
        #expect(summary.action == "build.android")
        #expect(summary.artifactKind == "apk")
        #expect(summary.artifactPath?.hasSuffix("app-debug.apk") == true)
        #expect(summary.nextAction?.command == "app")
        #expect(summary.nextAction?.args.contains("--apk") == true)
        #expect(summary.nextAction?.args.contains("android-a") == true)
        #expect(summary.stdoutLogPath != nil)
    }

    @Test("harmony build runner maps missing artifact to hap_artifact_not_found")
    func harmonyBuildRunnerMapsMissingArtifact() throws {
        let root = try makeTemporaryDirectory()
        let fakeHvigor = root.appendingPathComponent("fake-hvigor.sh")
        try writeExecutable(fakeHvigor, body: "echo no hap yet\n")

        do {
            _ = try runCLIBuild(.harmony(project: root.path, hvigor: fakeHvigor.path, module: "entry", mode: "debug", device: nil, timeout: 30, discoveryRoot: nil))
            Issue.record("Expected missing HAP artifact to fail")
        } catch {
            let detail = buildErrorDetail(error)
            #expect(detail.code == "hap_artifact_not_found")
            #expect(detail.nextAction?.command == "build")
        }
    }

    @Test("missing build tools map to stable failure codes")
    func missingBuildToolsMapToStableFailureCodes() throws {
        let root = try makeTemporaryDirectory()

        do {
            _ = try planCLIBuild(.android(project: root.path, gradle: "/tmp/not-a-gradle-wrapper", variant: "debug", device: nil, timeout: nil, discoveryRoot: nil))
            Issue.record("Expected missing Gradle to fail")
        } catch {
            #expect(buildErrorDetail(error).code == "gradle_not_found")
        }

        do {
            _ = try planCLIBuild(.harmony(project: root.path, hvigor: "/tmp/not-a-hvigor-wrapper", module: "entry", mode: "debug", device: nil, timeout: nil, discoveryRoot: nil))
            Issue.record("Expected missing hvigor to fail")
        } catch {
            #expect(buildErrorDetail(error).code == "hvigor_not_found")
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("triton-build-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeExecutable(_ url: URL, body: String) throws {
        let script = "#!/usr/bin/env bash\nset -euo pipefail\n\(body)\n"
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
