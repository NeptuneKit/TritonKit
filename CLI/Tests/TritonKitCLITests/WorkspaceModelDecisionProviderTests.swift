import Foundation
import Testing
@testable import TritonKitCLI

@Suite("WorkspaceModelDecisionProviderTests")
struct WorkspaceModelDecisionProviderTests {
    @Test("workspace openai-compatible LLM provider parses a local action candidate")
    func workspaceOpenAICompatibleLLMProviderParsesLocalActionCandidate() async throws {
        var capturedURL: URL?
        var capturedHeaders: [String: String] = [:]
        var capturedBody: [String: Any] = [:]
        let request = workspaceOpenAICompatibleDecisionRequest(
            baseURL: "http://127.0.0.1:8000/v1",
            model: "local-workspace-model",
            allowRemote: false
        )

        let decision = try await workspaceOpenAICompatibleModelDecisionProvider(
            request,
            httpTransport: { url, body, headers in
                capturedURL = url
                capturedHeaders = headers
                capturedBody = (try JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
                return Data(
                    #"""
                    {
                      "choices": [
                        {
                          "message": {
                            "content": "{\"action\":\"tap\",\"query\":\"Begin\",\"confidence\":0.91,\"summary\":\"Begin is the visible onboarding entry.\",\"expected\":\"Begin opens onboarding.\"}"
                          }
                        }
                      ]
                    }
                    """#.utf8
                )
            }
        )

        #expect(capturedURL?.absoluteString == "http://127.0.0.1:8000/v1/chat/completions")
        #expect(capturedHeaders["Content-Type"] == "application/json")
        #expect(capturedBody["model"] as? String == "local-workspace-model")
        let messages = capturedBody["messages"] as? [[String: Any]]
        let userMessage = messages?.last?["content"] as? String ?? ""
        #expect(userMessage.contains("Start onboarding"))
        #expect(userMessage.contains("Begin"))
        #expect(userMessage.contains("allowedActions"))

        #expect(decision.candidate.action == "tap")
        #expect(decision.candidate.query == "Begin")
        #expect(decision.candidate.source == "openai-compatible.llm")
        #expect(decision.confidence == 0.91)
        #expect(decision.summary == "Begin is the visible onboarding entry.")
        #expect(decision.expected == "Begin opens onboarding.")
        #expect(decision.usedVLM == false)
        #expect(decision.requestContext["llmProvider"] as? String == "openai-compatible")
        #expect(decision.requestContext["llmModel"] as? String == "local-workspace-model")
        #expect(decision.requestContext["llmBaseURL"] as? String == "http://127.0.0.1:8000/v1")
        #expect(decision.decisionResponseText.contains(#""query":"Begin""#))
    }

    @Test("workspace openai-compatible LLM provider rejects remote base URL without approval")
    func workspaceOpenAICompatibleLLMProviderRejectsRemoteWithoutApproval() async throws {
        let request = workspaceOpenAICompatibleDecisionRequest(
            baseURL: "https://example.com/v1",
            model: "remote-workspace-model",
            allowRemote: false
        )

        do {
            _ = try await workspaceOpenAICompatibleModelDecisionProvider(
                request,
                httpTransport: { _, _, _ in Data() }
            )
            Issue.record("Expected remote provider approval failure")
        } catch let failure as TKWorkspaceModelDecisionFailure {
            #expect(failure.code == "workspace_llm_remote_provider_requires_approval")
        }
    }

    private func workspaceOpenAICompatibleDecisionRequest(
        baseURL: String,
        model: String,
        allowRemote: Bool
    ) -> TKWorkspaceModelDecisionRequest {
        TKWorkspaceModelDecisionRequest(
            mode: "openai-compatible-provider",
            goal: "Start onboarding",
            app: "com.example.demo",
            actionPolicy: "explore",
            allowedActions: ["tap", "wait", "verify", "stop"],
            stopConditions: ["model_unparseable", "policy_rejected"],
            visibleTexts: ["Welcome", "Begin"],
            observationRef: "events.jsonl#observation.captured",
            providerStatus: "ready",
            llmProvider: "openai-compatible",
            llmBaseURL: baseURL,
            llmModel: model,
            llmAPIKeyEnv: nil,
            allowRemoteLLM: allowRemote,
            vlmProvider: "mock"
        )
    }
}
