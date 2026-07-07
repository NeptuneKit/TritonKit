import Foundation

func workspaceProviderPreflight(_ request: TKWorkspaceRunRequest) throws -> TKWorkspaceProviderPreflight {
    let llm = try workspaceLLMProviderPreflight(request)
    let vlm = try workspaceVLMProviderPreflight(request)
    let providersReady = llm.ready && vlm.ready
    let providerStatus = providersReady ? "ready" : (llm.ready || vlm.ready ? "partial" : "missing")

    let nextActions: [TKWorkspaceNextAction]
    if providersReady {
        nextActions = []
    } else if llm.provider == nil, vlm.provider == nil {
        nextActions = [
            TKWorkspaceNextAction(
                code: "configure_ai_provider",
                message: "LLM/VLM are enabled by default; configure a local or approved provider before autonomous actions."
            ),
        ]
    } else {
        nextActions = [llm.nextAction, vlm.nextAction].compactMap { $0 }
    }

    return TKWorkspaceProviderPreflight(
        providersReady: providersReady,
        providerStatus: providerStatus,
        llmProvider: llm.provider,
        llmProviderStatus: llm.status,
        vlmProvider: vlm.provider,
        vlmProviderStatus: vlm.status,
        providerEventPhase: workspaceProviderEventPhase(llm: llm, vlm: vlm),
        bootstrapPhase: workspaceBootstrapPhase(llm: llm, vlm: vlm),
        nextActions: nextActions
    )
}

private func workspaceLLMProviderPreflight(_ request: TKWorkspaceRunRequest) throws -> TKWorkspaceProviderComponentPreflight {
    guard let rawProvider = workspaceNonEmpty(request.llmProvider)
    else {
        return TKWorkspaceProviderComponentPreflight(
            provider: nil,
            status: "missing",
            phase: "llm_missing",
            nextAction: TKWorkspaceNextAction(
                code: "configure_llm_provider",
                message: "Configure the LLM provider before autonomous actions."
            )
        )
    }

    let provider = rawProvider.lowercased()
    switch provider {
    case "mock":
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "ready",
            phase: "llm_ready",
            nextAction: nil
        )
    case "openai-compatible":
        return workspaceOpenAICompatiblePreflight(
            provider: provider,
            kind: "LLM",
            baseURL: request.llmBaseURL,
            model: request.llmModel,
            apiKeyEnv: request.llmAPIKeyEnv,
            allowRemote: request.allowRemoteLLM,
            configureCode: "configure_llm_provider",
            approveRemoteCode: "approve_remote_llm_provider",
            remoteMessageSuffix: "workspace evidence may be sent to that endpoint"
        )
    default:
        throw RuntimeError("Unsupported workspace LLM provider \(rawProvider)")
    }
}

private func workspaceVLMProviderPreflight(_ request: TKWorkspaceRunRequest) throws -> TKWorkspaceProviderComponentPreflight {
    guard let rawProvider = workspaceNonEmpty(request.vlmProvider)
    else {
        return TKWorkspaceProviderComponentPreflight(
            provider: nil,
            status: "missing",
            phase: "vlm_missing",
            nextAction: TKWorkspaceNextAction(
                code: "configure_vlm_provider",
                message: "Configure the VLM provider before autonomous actions."
            )
        )
    }

    let provider = rawProvider.lowercased()
    switch provider {
    case "mock":
        _ = try makeVLMProvider(provider)
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "ready",
            phase: "vlm_ready",
            nextAction: nil
        )
    case "mlx-swift-lm":
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "missing_model",
            phase: "vlm_missing_model",
            nextAction: TKWorkspaceNextAction(
                code: "configure_vlm_provider",
                message: "mlx-swift-lm requires an explicit model or model path before workspace run can use it."
            )
        )
    case "openai-compatible":
        return workspaceOpenAICompatiblePreflight(
            provider: provider,
            kind: "VLM",
            baseURL: request.vlmBaseURL,
            model: request.vlmModel,
            apiKeyEnv: request.vlmAPIKeyEnv,
            allowRemote: request.allowRemoteVLM,
            configureCode: "configure_vlm_provider",
            approveRemoteCode: "approve_remote_vlm_provider",
            remoteMessageSuffix: "screenshots or visual evidence may be sent to that endpoint"
        )
    default:
        throw RuntimeError("Unsupported workspace VLM provider \(rawProvider)")
    }
}

private func workspaceOpenAICompatiblePreflight(
    provider: String,
    kind: String,
    baseURL: String?,
    model: String?,
    apiKeyEnv: String?,
    allowRemote: Bool,
    configureCode: String,
    approveRemoteCode: String,
    remoteMessageSuffix: String
) -> TKWorkspaceProviderComponentPreflight {
    let prefix = kind.lowercased()
    guard let baseURL = workspaceNonEmpty(baseURL) else {
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "missing_base_url",
            phase: "\(prefix)_missing_base_url",
            nextAction: TKWorkspaceNextAction(
                code: configureCode,
                message: "openai-compatible \(kind) requires --\(prefix)-base-url with a local endpoint unless remote approval is explicit."
            )
        )
    }
    guard workspaceNonEmpty(model) != nil else {
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "missing_model",
            phase: "\(prefix)_missing_model",
            nextAction: TKWorkspaceNextAction(
                code: configureCode,
                message: "openai-compatible \(kind) requires --\(prefix)-model before workspace run can call it."
            )
        )
    }
    guard let url = URL(string: baseURL), let host = url.host else {
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "invalid_base_url",
            phase: "\(prefix)_invalid_base_url",
            nextAction: TKWorkspaceNextAction(
                code: configureCode,
                message: "openai-compatible \(kind) base URL is invalid; pass an absolute http(s) URL ending at /v1."
            )
        )
    }
    if !isLocalWorkspaceProviderHost(host), !allowRemote {
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "remote_approval_required",
            phase: "\(prefix)_remote_approval_required",
            nextAction: TKWorkspaceNextAction(
                code: approveRemoteCode,
                message: "Remote \(kind) provider \(host) requires --allow-remote-\(prefix) because \(remoteMessageSuffix)."
            )
        )
    }
    if let apiKeyEnv = workspaceNonEmpty(apiKeyEnv),
       ProcessInfo.processInfo.environment[apiKeyEnv]?.isEmpty != false {
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "missing_api_key",
            phase: "\(prefix)_missing_api_key",
            nextAction: TKWorkspaceNextAction(
                code: configureCode,
                message: "\(kind) API key environment variable \(apiKeyEnv) is not set."
            )
        )
    }
    return TKWorkspaceProviderComponentPreflight(
        provider: provider,
        status: "ready",
        phase: "\(prefix)_ready",
        nextAction: nil
    )
}

private func workspaceProviderEventPhase(
    llm: TKWorkspaceProviderComponentPreflight,
    vlm: TKWorkspaceProviderComponentPreflight
) -> String {
    if llm.ready, vlm.ready {
        return "ready"
    }
    if llm.ready {
        return "llm_ready_\(vlm.phase)"
    }
    if vlm.ready {
        return "vlm_ready_\(llm.phase)"
    }
    if llm.provider == nil, vlm.provider == nil {
        return "missing"
    }
    return "\(llm.phase)_\(vlm.phase)"
}

private func workspaceBootstrapPhase(
    llm: TKWorkspaceProviderComponentPreflight,
    vlm: TKWorkspaceProviderComponentPreflight
) -> String {
    if llm.ready, vlm.ready {
        return "provider_ready"
    }
    if !llm.ready, vlm.ready {
        return "llm_missing"
    }
    if llm.ready, !vlm.ready {
        return "vlm_missing"
    }
    return "provider_missing"
}
