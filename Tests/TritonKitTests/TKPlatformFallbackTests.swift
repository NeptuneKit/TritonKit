import Foundation
import Testing
@testable import TritonKit
#if canImport(Darwin)
import Darwin
#endif

@Suite
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

    @Test("configuration defaults are safe for debug app bootstrap")
    func configurationDefaults() {
        let configuration = TritonKit.Configuration()

        #expect(configuration.endpoint.host == "127.0.0.1")
        #expect(configuration.endpoint.port == 19421)
        #expect(configuration.autoReconnect)
        #expect(configuration.features.contains(.hierarchy))
        #expect(configuration.features.contains(.accessibility))
        #expect(configuration.features.contains(.input))
        #expect(configuration.redaction.secureText == .lengthOnly)
        #expect(configuration.redaction.collectClipboard == false)
        #expect(configuration.redaction.collectNetwork == false)
        #expect(configuration.redaction.collectLogs == false)
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
