import ArgumentParser
import Foundation
import Testing
@testable import TritonKitCLI

@Suite struct WorkspaceInferenceOptInTests {
    @Test func cliFlagsAreExplicitAndDefaultOff() throws {
        let configured = try Workspace.Run.parse(["--app", "demo", "--goal", "observe", "--llm-provider", "mock", "--vlm-provider", "mock", "--execute-actions"])
        #expect(!configured.enableLLM)
        #expect(!configured.enableVLM)
        let enabled = try Workspace.Run.parse(["--app", "demo", "--goal", "observe", "--enable-llm", "--enable-vlm"])
        #expect(enabled.enableLLM)
        #expect(enabled.enableVLM)
    }

    @Test func httpRejectsNonBooleanEnableValues() {
        let body = Data(#"{"app":"demo","goal":"observe","enableLLM":"true","enableVLM":1}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(TKWorkspaceHTTPRunRequest.self, from: body) }
    }

    @Test func resolvedRequestsPreserveExplicitFlags() throws {
        let request = TKWorkspaceRunRequest(runsDirectory: ".unused", runID: nil, target: "current", app: "demo", goal: "observe", actionPolicy: "explore", enableLLM: true, enableVLM: true)
        let resolved = try request.resolvingRunID().resolvingTarget(target: "fixture", platform: "ios", scope: "simulator")
        #expect(resolved.enableLLM)
        #expect(resolved.enableVLM)
    }

    @Test func defaultInferenceIsDisabled() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let run = try runWorkspaceRun(TKWorkspaceRunRequest(runsDirectory: root.path, runID: "disabled", target: "current", app: "demo", goal: "observe", actionPolicy: "explore"))
        #expect(!run.ai.llmEnabled)
        #expect(!run.ai.vlmEnabled)
        #expect(run.ai.providerStatus == "disabled")
        #expect(!run.nextActions.contains { $0.code == "configure_ai_provider" })
    }

    @Test(arguments: [false, true]) func configuredProvidersDoNotRunWithoutOptIn(dryFixture: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await runWorkspaceRunAsync(TKWorkspaceRunRequest(runsDirectory: root.path, runID: "configured", target: "current", app: "demo", goal: "observe", actionPolicy: "explore", dryModelFixture: dryFixture, llmProvider: "openai-compatible", llmBaseURL: "http://127.0.0.1:1/v1", llmModel: "fixture", vlmProvider: "mock"), modelDecisionProvider: { request in
            Issue.record("Configured provider must not be invoked without explicit enable, including dry fixtures")
            return workspaceDefaultModelDecision(request)
        })
    }

    @Test(arguments: [nil, false, true] as [Bool?]) func httpExplicitOptIn(enabled: Bool?) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let count = InvocationCount()
        let body = try JSONEncoder().encode(TKWorkspaceHTTPRunRequest(runsDir: root.path, runID: "http", target: "current", app: "demo", goal: "observe", actionPolicy: nil, enableLLM: enabled, llmProvider: "mock"))
        let run = try await handleWorkspaceHTTPRunAsync(body: body, modelDecisionProvider: { request in
            await count.increment()
            return workspaceDefaultModelDecision(request)
        })
        #expect(await count.value == (enabled == true ? 1 : 0))
        #expect(run.ai.llmEnabled == (enabled == true))
        #expect(!run.ai.vlmEnabled)
    }

    @Test func disabledConfigurationIsNotValidatedOrStarted() throws {
        let request = TKWorkspaceRunRequest(runsDirectory: ".unused", runID: "disabled", target: "current", app: "demo", goal: "observe", actionPolicy: "explore", llmProvider: "not-a-provider", llmBaseURL: "bad-url", llmAPIKeyEnv: "TRITON_MISSING_FIXTURE_KEY", vlmProvider: "mlx-swift-lm", vlmHelper: "/nonexistent/fixture", vlmAllowModelDownload: true)
        let result = try workspaceProviderPreflight(request)
        #expect(result.providerStatus == "disabled")
        #expect(result.llmProviderStatus == "disabled")
        #expect(result.vlmProviderStatus == "disabled")
    }

    @Test func vlmOnlyCannotActivateConfiguredLLM() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let run = try await runWorkspaceRunAsync(TKWorkspaceRunRequest(runsDirectory: root.path, runID: "vlm-only", target: "current", app: "demo", goal: "observe", actionPolicy: "explore", llmProvider: "openai-compatible", llmBaseURL: "http://127.0.0.1:1/v1", llmModel: "fixture", enableVLM: true, vlmProvider: "mock"), modelDecisionProvider: { request in
            Issue.record("VLM enable must not activate disabled LLM")
            return workspaceDefaultModelDecision(request)
        })
        #expect(!run.ai.llmEnabled)
        #expect(run.ai.vlmEnabled)
        #expect(run.ai.llmProviderStatus == "disabled")
    }

    @Test func dryFixtureIgnoresEnabledExternalProviders() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let run = try await runWorkspaceRunAsync(TKWorkspaceRunRequest(runsDirectory: root.path, runID: "dry", target: "current", app: "demo", goal: "observe", actionPolicy: "explore", dryModelFixture: true, enableLLM: true, llmProvider: "openai-compatible", llmBaseURL: "bad-url", enableVLM: true, vlmProvider: "mlx-swift-lm", vlmHelper: "/nonexistent/fixture", vlmAllowModelDownload: true), modelDecisionProvider: { request in
            Issue.record("Dry fixture must bypass enabled online provider")
            return workspaceDefaultModelDecision(request)
        }, vlmGroundingProvider: { _ in
            throw RuntimeError("Dry fixture must bypass enabled helper")
        })
        #expect(run.ai.providerStatus == "fixture")
        #expect(!run.ai.providersReady)
    }

    @Test func explicitProviderFailureIsNotRetriedOrFallenBack() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let count = InvocationCount()
        do {
            _ = try await runWorkspaceRunAsync(TKWorkspaceRunRequest(runsDirectory: root.path, runID: "failure", target: "current", app: "demo", goal: "observe", actionPolicy: "explore", enableLLM: true, llmProvider: "mock"), modelDecisionProvider: { _ in
                await count.increment()
                throw TKWorkspaceModelDecisionFailure(code: "fixture_provider_failed", message: "failed", hint: "fixture")
            })
            Issue.record("Provider failure must propagate")
        } catch let error as TKWorkspaceModelDecisionFailure {
            #expect(error.code == "fixture_provider_failed")
        }
        #expect(await count.value == 1)
    }

}

private actor InvocationCount {
    var value = 0
    func increment() { value += 1 }
}
