import Foundation
import Testing
@testable import TritonKit
import TritonKitShared
#if canImport(Darwin)
import Darwin
#endif

@Suite(.serialized)
struct TKPlatformFallbackTests {
    @Test("runtime is enabled only when the package debug flag is defined")
    func runtimeEnabledFlagMatchesBuildConfiguration() {
        #if TRITONKIT_RUNTIME_ENABLED
        #expect(TritonKit.isRuntimeEnabled)
        #else
        #expect(!TritonKit.isRuntimeEnabled)
        #endif
    }

    @Test("start payload defaults to local Triton CLI endpoint")
    func startPayloadDefaultsToLocalEndpoint() {
        let payload = TritonKitStartPayload()

        #expect(payload.host == "127.0.0.1")
        #expect(payload.port == 19421)
        #expect(payload.dataURL == URL(string: "http://127.0.0.1:19421"))
    }

    @Test("start payload reads environment with stable fallbacks")
    func startPayloadReadsEnvironment() {
        let payload = TritonKitStartPayload.environment([
            "TRITON_HOST": "192.168.1.20",
            "TRITON_PORT": "19422"
        ])
        let fallbackPayload = TritonKitStartPayload.environment([
            "TRITON_PORT": "not-a-port"
        ])

        #expect(payload.host == "192.168.1.20")
        #expect(payload.port == 19422)
        #expect(payload.dataURL == URL(string: "http://192.168.1.20:19422"))
        #expect(fallbackPayload.host == "127.0.0.1")
        #expect(fallbackPayload.port == 19421)
    }

    @Test("endpoint conveniences describe local environment and device targets")
    func endpointConveniences() {
        let local = TritonKit.Endpoint.local()
        let device = TritonKit.Endpoint.device("192.168.1.20", port: 19422)
        let environment = TritonKit.Endpoint.environment([
            "TRITON_HOST": "10.0.0.8",
            "TRITON_PORT": "19423"
        ])

        #expect(local.host == "127.0.0.1")
        #expect(local.port == 19421)
        #expect(local.dataURL == URL(string: "http://127.0.0.1:19421"))
        #expect(device.host == "192.168.1.20")
        #expect(device.port == 19422)
        #expect(device.dataURL == URL(string: "http://192.168.1.20:19422"))
        #expect(environment.host == "10.0.0.8")
        #expect(environment.port == 19423)
    }

    @Test("configuration builder keeps startup options in one facade")
    func configurationBuilder() {
        let configuration = TritonKit.Configuration { config in
            config.endpoint = .device("192.168.1.20", port: 19422)
            config.autoReconnect = false
            config.features = [.hierarchy, .input]
            config.redaction.secureText = .hidden
            config.appIdentity = .init(name: "Demo", tags: ["smoke"])
        }

        #expect(configuration.endpoint.host == "192.168.1.20")
        #expect(configuration.endpoint.port == 19422)
        #expect(configuration.autoReconnect == false)
        #expect(configuration.features == [.hierarchy, .input])
        #expect(configuration.redaction.secureText == .hidden)
        #expect(configuration.appIdentity?.name == "Demo")
        #expect(configuration.appIdentity?.tags == ["smoke"])
    }

    @Test("configuration features map to runtime capability gates")
    func configurationFeatureCapabilityMapping() {
        let inputOnly = TritonKit.Configuration { config in
            config.features = [.input]
        }
        let observeOnly = TritonKit.Configuration { config in
            config.features = [.appInfo, .hierarchy, .accessibility, .geometry, .screenshot]
        }

        #expect(inputOnly.isRuntimeCapabilityEnabled(.inputTap))
        #expect(inputOnly.isRuntimeCapabilityEnabled(.semanticSetText))
        #expect(inputOnly.isRuntimeCapabilityEnabled(.webViewList) == false)
        #expect(observeOnly.isRuntimeCapabilityEnabled(.snapshot))
        #expect(observeOnly.isRuntimeCapabilityEnabled(.inputTap) == false)
    }

    @Test("capability gate maps request messages without executing handlers")
    func capabilityGateMapsRequestMessages() throws {
        let tapPayload = try JSONEncoder().encode(TKInputRequest.tap(x: 10, y: 20))
        let semanticPayload = try JSONEncoder().encode(TKSemanticActionRequest(action: .selectSegment, segmentIndex: 1))

        #expect(TKRuntimeCapabilityGate.capability(for: TKMessage(id: 1, type: .input, payload: tapPayload)) == .inputTap)
        #expect(TKRuntimeCapabilityGate.capability(for: TKMessage(id: 1, type: .semanticAction, payload: semanticPayload)) == .semanticSelectSegment)
        #expect(TKRuntimeCapabilityGate.capability(for: TKMessage(id: 1, type: .webViewSnapshot)) == .webViewSnapshot)
        #expect(TKRuntimeCapabilityGate.actionName(for: TKMessage(id: 1, type: .webViewSnapshot)) == "webview.snapshot")
    }

    @Test("capability gate builds model-specific disabled responses")
    func capabilityGateBuildsDisabledResponses() throws {
        let configuration = TritonKit.Configuration { config in
            config.features = [.appInfo, .hierarchy, .accessibility, .geometry, .screenshot]
        }
        let inputMessage = TKMessage(
            id: 1,
            type: .input,
            payload: try JSONEncoder().encode(TKInputRequest.typeText("hello"))
        )
        let webViewMessage = TKMessage(id: 2, type: .webViewSnapshot)

        let inputResponse = try #require(TKRuntimeCapabilityGate.disabledResponse(for: inputMessage, configuration: configuration))
        let input = try #require(inputResponse.payload).decoded(as: TKInputResult.self)
        let webViewResponse = try #require(TKRuntimeCapabilityGate.disabledResponse(for: webViewMessage, configuration: configuration))
        let webView = try #require(webViewResponse.payload).decoded(as: TKWebViewErrorResponse.self)

        #expect(input.error?.code == "capability_disabled")
        #expect(input.action == "type")
        #expect(webView.error.code == "capability_disabled")
        #expect(webView.action == "webview.snapshot")
    }

    @Test("request types map to stable handler domains")
    func requestTypesMapToHandlerDomains() {
        #expect(TKRuntimeRequestDomain.domain(for: .appInfo) == .observation)
        #expect(TKRuntimeRequestDomain.domain(for: .runtimeSnapshot) == .observation)
        #expect(TKRuntimeRequestDomain.domain(for: .input) == .input)
        #expect(TKRuntimeRequestDomain.domain(for: .webViewSnapshot) == .webView)
        #expect(TKRuntimeRequestDomain.domain(for: .semanticAction) == .semantic)
        #expect(TKRuntimeRequestDomain.domain(for: .fetchObject) == .legacyInspection)
        #expect(TKRuntimeRequestDomain.domain(for: .runtimeLedger) == .ledger)
        #expect(TKRuntimeRequestDomain.domain(for: .ping) == .control)
    }

    @Test("runtime manifest marks supported capabilities disabled by app config")
    func manifestReflectsDisabledRuntimeCapabilities() {
        let kit = TritonKit.shared
        let originalProbe = kit.endpointReadinessProbe
        kit.endpointReadinessProbe = { _, _, _ in false }
        _ = kit.start(TritonKit.Configuration { config in
            config.endpoint = .local(port: 9)
            config.autoReconnect = false
            config.features = [.appInfo, .hierarchy, .accessibility, .geometry, .screenshot]
        })
        defer {
            _ = kit.start(TritonKit.Configuration { config in
                config.endpoint = .local(port: 9)
                config.autoReconnect = false
            })
            kit.stop()
            kit.endpointReadinessProbe = originalProbe
        }

        let manifest = currentRuntimeManifestWithWebViewProvider(sdkVersion: "0.1.1")
        let tap = manifest.capabilities.first { $0.name == TKRuntimeCapabilityName.inputTap.rawValue }
        let webView = manifest.capabilities.first { $0.name == TKRuntimeCapabilityName.webViewList.rawValue }

        #expect(tap?.supported == true)
        #expect(tap?.enabled == false)
        #expect(tap?.reason == "Capability disabled by app runtime configuration")
        #expect(webView?.supported == true)
        #expect(webView?.enabled == false)
    }

    @Test("disabled input capability returns input result with stable error code")
    func disabledInputCapabilityReturnsError() async throws {
        try await withRuntimeFeatures([.appInfo, .hierarchy, .accessibility, .geometry, .screenshot]) {
            let handler = TritonKitRequestHandler()
            let request = TKInputRequest.tap(x: 10, y: 20)
            let message = TKMessage(id: 1, type: .input, payload: try JSONEncoder().encode(request))

            let response = await handler.tritonKit(TritonKit.shared, didReceiveMessage: message)
            let result = try #require(response?.payload).decoded(as: TKInputResult.self)

            #expect(result.ok == false)
            #expect(result.action == "tap")
            #expect(result.error?.code == "capability_disabled")
        }
    }

    @Test("disabled semantic action returns semantic error")
    func disabledSemanticActionCapabilityReturnsError() async throws {
        try await withRuntimeFeatures([.appInfo, .hierarchy, .accessibility, .geometry, .screenshot]) {
            let handler = TritonKitRequestHandler()
            let request = TKSemanticActionRequest(action: .setText, text: "hello")
            let message = TKMessage(id: 1, type: .semanticAction, payload: try JSONEncoder().encode(request))

            let response = await handler.tritonKit(TritonKit.shared, didReceiveMessage: message)
            let result = try #require(response?.payload).decoded(as: TKSemanticActionResponse.self)

            #expect(result.ok == false)
            #expect(result.action == .setText)
            #expect(result.error?.code == "capability_disabled")
        }
    }

    @Test("disabled WebView capability returns WebView error")
    func disabledWebViewCapabilityReturnsError() async throws {
        try await withRuntimeFeatures([.appInfo, .hierarchy, .accessibility, .geometry, .screenshot, .input, .semantic]) {
            let handler = TritonKitRequestHandler()
            let message = TKMessage(id: 1, type: .webViewList)

            let response = await handler.tritonKit(TritonKit.shared, didReceiveMessage: message)
            let result = try #require(response?.payload).decoded(as: TKWebViewErrorResponse.self)

            #expect(result.ok == false)
            #expect(result.action == "webview.list")
            #expect(result.error.code == "capability_disabled")
        }
    }

    @Test("configuration defaults are safe for debug app bootstrap")
    func configurationDefaults() {
        let configuration = TritonKit.Configuration()

        #expect(configuration.endpoint.host == "127.0.0.1")
        #expect(configuration.endpoint.port == 19421)
        #expect(configuration.autoReconnect)
        #expect(configuration.features.contains(.hierarchy))
        #expect(configuration.features.contains(.accessibility))
        #expect(configuration.features.contains(.input))
        #expect(configuration.features.contains(.semantic))
        #expect(configuration.redaction.secureText == .lengthOnly)
        #expect(configuration.redaction.collectClipboard == false)
        #expect(configuration.redaction.collectNetwork == false)
        #expect(configuration.redaction.collectLogs == false)
    }

    @Test("semantic provider registry exposes provider-backed domain state")
    func semanticProviderRegistry() {
        let kit = TritonKit.shared
        kit.clearSemanticStateProvider(domain: "media-playback")
        let token = kit.registerSemanticStateProvider(
            domain: "media-playback",
            displayName: "Media Playback",
            schema: [TKRuntimeSemanticStateField(path: "isReady", type: "Bool")],
            actions: [TKRuntimeSemanticActionDescriptor(name: "pause")]
        ) {
            ["isReady": .bool(true)]
        }
        defer {
            token.cancel()
            kit.clearSemanticStateProvider(domain: "media-playback")
        }

        let response = kit.currentSemanticState(capturedAt: "2026-06-08T12:00:00Z")

        #expect(response.domainCount == 1)
        #expect(response.domains.first?.domain == "media-playback")
        #expect(response.domains.first?.state["isReady"] == .bool(true))
        #expect(response.domains.first?.actions.map(\.name) == ["pause"])

        let manifest = currentRuntimeManifestWithWebViewProvider(sdkVersion: "0.1.1")
        let semanticStateCapability = manifest.capabilities.first { $0.name == TKRuntimeCapabilityName.semanticState.rawValue }
        let semanticActionCapability = manifest.capabilities.first { $0.name == TKRuntimeCapabilityName.semanticActionProvider.rawValue }
        #expect(semanticStateCapability?.supported == true)
        #expect(semanticActionCapability?.supported == true)
        #expect(manifest.semanticDomains.first?.domain == "media-playback")
        #expect(manifest.semanticDomains.first?.source == "runtime-provider")
        #expect(manifest.semanticDomains.first?.schema.map(\.path) == ["isReady"])
        #expect(manifest.semanticDomains.first?.actions.map(\.name) == ["pause"])

        token.cancel()
        let empty = kit.currentSemanticState(capturedAt: "2026-06-08T12:00:01Z")
        let emptyManifest = currentRuntimeManifestWithWebViewProvider(sdkVersion: "0.1.1")
        #expect(empty.domainCount == 0)
        #expect(empty.warnings.contains { $0.contains("No semantic providers") })
        #expect(emptyManifest.semanticDomains.isEmpty)
    }

    @Test("state observer token receives current state and can be cancelled")
    func stateObserverToken() {
        var observed: [TritonKit.ConnectionState] = []
        let token = TritonKit.shared.onStateChange { state in
            observed.append(state)
        }

        #expect(observed == [TritonKit.shared.state])
        TritonKit.shared.stop()
        #expect(observed == [TritonKit.shared.state])
        token.cancel()
    }

    @Test("missing local server does not surface connection refused noise")
    func missingLocalServerDoesNotSurfaceConnectionNoise() async throws {
        let kit = TritonKit.shared
        kit.stop()
        var observedErrors: [Error] = []
        let token = kit.onError { error in
            observedErrors.append(error)
        }
        defer {
            token.cancel()
            kit.stop()
        }

        let port = try Self.unusedLocalPort()
        let started = kit.start(TritonKit.Configuration { config in
            config.endpoint = .local(port: port)
            config.autoReconnect = false
        })

        #if TRITONKIT_RUNTIME_ENABLED
        #expect(started)
        try await Task.sleep(nanoseconds: 500_000_000)
        #else
        #expect(!started)
        #endif
        #expect(kit.state == .disconnected)
        #expect(observedErrors.isEmpty)
    }

    @Test("hierarchy builder returns an empty fallback on non-UIKit platforms")
    func hierarchyBuilderFallback() async {
        #if !canImport(UIKit)
        let items = await TKHierarchyBuilder.buildHierarchy()

        #expect(items.isEmpty)
        #endif
    }

    @Test("hierarchy builder defaults cover deeply nested app containers")
    func hierarchyBuilderDefaultTraversalLimits() {
        #expect(TKHierarchyBuilder.defaultMaxDepth >= 32)
        #expect(TKHierarchyBuilder.defaultMaxChildrenPerNode >= 100)
    }

    private static func unusedLocalPort() throws -> UInt16 {
        #if canImport(Darwin)
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(fd, socketAddress, &length)
            }
        }
        guard nameResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        return UInt16(bigEndian: boundAddress.sin_port)
        #else
        throw POSIXError(.ENOTSUP)
        #endif
    }
}

private extension TKPlatformFallbackTests {
    func withRuntimeFeatures(
        _ features: Set<TritonKit.Feature>,
        _ body: () async throws -> Void
    ) async throws {
        let kit = TritonKit.shared
        let originalProbe = kit.endpointReadinessProbe
        kit.endpointReadinessProbe = { _, _, _ in false }
        _ = kit.start(TritonKit.Configuration { config in
            config.endpoint = .local(port: 9)
            config.autoReconnect = false
            config.features = features
        })
        defer {
            _ = kit.start(TritonKit.Configuration { config in
                config.endpoint = .local(port: 9)
                config.autoReconnect = false
            })
            kit.stop()
            kit.endpointReadinessProbe = originalProbe
        }

        try await body()
    }
}

private extension Data {
    func decoded<T: Decodable>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: self)
    }
}
