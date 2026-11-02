import ArgumentParser
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Host goal workflow plans")
struct HostGoalWorkflowPlanTests {
    private func capabilities(_ reachable: Bool) -> TKCapabilitiesResponse {
        TKCapabilitiesResponse(ok: reachable, serverReachable: reachable, connected: reachable,
            latestHierarchyAvailable: reachable, targetCount: reachable ? 1 : 0, runtime: "unknown", capabilities: [],
            error: reachable ? nil : TKCLIErrorDetail(code: "server_unavailable", message: "unavailable", hint: "connect the iOS app"))
    }

    @Test("Explicit host platform routes before runtime bootstrap", arguments: [false, true])
    func hostRoutingMatrix(reachable: Bool) {
        for platform in ["harmony", "android"] {
            for goal in ["general", "open-url"] {
                let plan = buildWorkflowPlan(capabilities: capabilities(reachable), host: "127.0.0.1", port: 28771,
                    request: .init(goal: goal, device: "audit-device", platform: platform, bundle: platform == "harmony" ? "com.example.audit" : nil,
                        ability: platform == "harmony" ? "EntryAbility" : nil, url: "example://audit?id=1&mode=2", text: "Ready"))
                #expect(plan.mode == "task")
                #expect(plan.goal == goal)
                #expect(plan.nextStep == "device-doctor")
                #expect(plan.serverReachable == reachable)
                #expect(plan.steps.allSatisfy { !$0.requiresServer })
                #expect(!plan.steps.contains { $0.argv.contains("xcode") || $0.argv.contains("serve") })
                #expect(plan.error?.code != "server_unavailable")
            }
        }
    }

    @Test("Harmony smoke preserves lifecycle identity and each argv token", arguments: [false, true])
    func harmonyGoalArguments(reachable: Bool) throws {
        let request = WorkflowPlanRequest(goal: "open-url", device: "harmony:audit-device", platform: "harmony",
            bundle: "com.example.audit", ability: "EntryAbility", hap: "/fixture/candidate file.hap",
            url: "example://audit?id=1&mode=two words", text: "Ready now", evidence: "/fixture/evidence dir.tritonevidence")
        let plan = buildWorkflowPlan(capabilities: capabilities(reachable), host: "127.0.0.1", port: 28771, request: request)
        #expect(plan.ok)
        #expect(plan.error == nil)
        #expect(plan.steps.map(\.id) == ["device-doctor", "device-list", "device-wait-ready", "app-install", "host-open-url-smoke", "evidence-summary"])
        let install = try #require(plan.steps.first { $0.id == "app-install" })
        #expect(install.argv == ["triton", "app", "install", "--platform", "harmony", "--device", "harmony:audit-device", "--hap", "/fixture/candidate file.hap", "--json"])
        let smoke = try #require(plan.steps.first { $0.id == "host-open-url-smoke" })
        let parsed = try SmokeHarmony.parse(Array(smoke.argv.dropFirst(3)))
        #expect(parsed.device == request.device)
        #expect(parsed.bundle == request.bundle)
        #expect(parsed.ability == request.ability)
        #expect(parsed.openURL == request.url)
        #expect(parsed.waitText == request.text)
        #expect(parsed.evidence == request.evidence)
        #expect(smoke.argv.filter { $0 == request.url }.count == 1)
        #expect(!plan.steps.contains { Array($0.argv.prefix(3)) == ["triton", "app", "go"] })
        #expect(!plan.steps.contains { Array($0.argv.prefix(3)) == ["triton", "app", "open-url"] })
        #expect(plan.afterRecoverySteps.isEmpty)
        _ = try HostAppInstall.parse(Array(install.argv.dropFirst(3)))
    }

    @Test("No HAP means no optional install, and missing platform fields remain explicit placeholders")
    func optionalInstall() throws {
        let plan = buildWorkflowPlan(capabilities: capabilities(false), host: "127.0.0.1", port: 28771,
            request: .init(goal: "open-url", device: "audit-device", platform: "harmony", url: "example://audit", text: "Ready"))
        #expect(!plan.steps.contains { $0.id == "app-install" })
        let smoke = try #require(plan.steps.first { $0.id == "host-open-url-smoke" })
        #expect(smoke.argv.contains("<bundle>"))
        #expect(smoke.argv.contains("<ability>"))
        #expect(smoke.when.contains("placeholders"))
    }

    @Test("Android uses supported host actions and labels unsupported evidence", arguments: [false, true])
    func androidGoalArguments(reachable: Bool) throws {
        let plan = buildWorkflowPlan(capabilities: capabilities(reachable), host: "127.0.0.1", port: 28771,
            request: .init(goal: "open-url", device: "android:audit-device", platform: "android", url: "example://audit?id=1&mode=2",
                text: "Ready now", evidence: "/fixture/android.tritonevidence"))
        #expect(!plan.ok)
        #expect(plan.error?.code == "unsupported_capability")
        #expect(plan.error?.message.contains("evidence") == true)
        #expect(plan.error?.message.contains("/fixture/android.tritonevidence") == true)
        let open = try #require(plan.steps.first { $0.id == "app-open-url" })
        let parsed = try HostAppOpenURL.parse(Array(open.argv.dropFirst(3)))
        #expect(parsed.platform == .android)
        #expect(parsed.device == "android:audit-device")
        #expect(parsed.url == "example://audit?id=1&mode=2")
        let wait = try #require(plan.steps.first { $0.id == "wait-text" })
        #expect(wait.argv == ["triton", "wait", "--platform", "android", "--device", "android:audit-device", "--text", "Ready now", "--json"])
        #expect(!plan.steps.contains { $0.argv.contains("verify") || $0.argv.contains("capture") })
    }

    @Test("Android without an evidence request has a supported host sequence")
    func androidSupportedSubset() {
        let plan = buildWorkflowPlan(capabilities: capabilities(false), host: "127.0.0.1", port: 28771,
            request: .init(goal: "open-url", device: "audit-device", platform: "android", url: "example://audit", text: "Ready"))
        #expect(plan.ok)
        #expect(plan.error == nil)
        #expect(plan.steps.contains { $0.id == "app-open-url" })
        #expect(plan.steps.contains { $0.id == "wait-text" })
        #expect(!plan.steps.contains { $0.id == "evidence" || $0.id == "evidence-summary" })
    }

    @Test("Plan schema declares host evidence limitation")
    func schemaDeclaresLimitation() throws {
        let schema = try #require(commandSchemas().first { $0.name == "plan" })
        #expect(schema.failureCodes.contains("unsupported_capability"))
        #expect(schema.outputSemantics?.contains("Android package input") == true)
    }

    @Test("Android does not silently discard Harmony install or lifecycle options")
    func androidRejectsHarmonyOptions() {
        let plan = buildWorkflowPlan(capabilities: capabilities(false), host: "127.0.0.1", port: 28771,
            request: .init(goal: "open-url", device: "audit-device", platform: "android", bundle: "com.example.harmony", ability: "EntryAbility", hap: "/fixture/test.hap"))
        #expect(!plan.ok)
        #expect(plan.error?.code == "unsupported_capability")
        #expect(!plan.steps.contains { $0.id == "app-open-url" || $0.id == "app-install" })
    }

    @Test("Default iOS retains bootstrap and deferred task structure")
    func iosUnchanged() {
        let plan = buildWorkflowPlan(capabilities: capabilities(false), host: "127.0.0.1", port: 28771,
            request: .init(goal: "open-url", device: "sim:audit", url: "example://audit", text: "Ready"))
        #expect(plan.mode == "bootstrap")
        #expect(plan.nextStep == "start-server")
        #expect(plan.afterRecoverySteps.map(\.id) == ["target-resolve", "app-open-url", "wait-text", "assert-text", "evidence"])
    }
}
