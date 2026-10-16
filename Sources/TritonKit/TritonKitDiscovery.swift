import Foundation

/// Discovery supplies an unauthenticated endpoint candidate, never service identity.
public enum TritonKitDiscoveryPolicy: Equatable {
    case disabled
    /// Wait for the complete window and require exactly one resolved service.
    /// The timeout must be finite, greater than zero and at most five seconds.
    case bonjour(timeout: TimeInterval)
}

public struct TritonKitDiscoveryCandidate: Equatable {
    public let serviceName: String
    public let host: String?
    public let port: UInt16?
    /// Untrusted, public TXT metadata. It is not used for selection or authentication.
    public let publicID: String?
    public let isAvailable: Bool
    public var isAuthenticated: Bool { false }

    internal init(serviceName: String, host: String? = nil, port: UInt16? = nil, publicID: String? = nil, isAvailable: Bool = true) {
        self.serviceName = serviceName
        self.host = host
        self.port = port
        self.publicID = publicID
        self.isAvailable = isAvailable
    }
}

public struct TritonKitDiscoveryResult: Equatable {
    public enum Status: String, Equatable {
        case candidate
        case noCandidates
        case ambiguous
        case unresolved
        case failed
        case invalidConfiguration
        case runtimeDisabled
        case unsupported
    }

    public let status: Status
    public let candidates: [TritonKitDiscoveryCandidate]
    public var isAuthenticated: Bool { false }

    internal init(status: Status, candidates: [TritonKitDiscoveryCandidate] = []) {
        self.status = status
        self.candidates = candidates
    }

    /// Only an explicit discovery request can produce this unauthenticated candidate.
    public var endpoint: TritonKitStartPayload? {
        guard status == .candidate, candidates.count == 1,
              let candidate = candidates.first, candidate.isAvailable,
              let host = candidate.host, let port = candidate.port else { return nil }
        var payload = TritonKitStartPayload(host: host, port: port)
        payload.discovery = self
        return payload
    }
}

internal enum TritonKitDiscoveryEvent {
    case found(id: String, name: String)
    case resolved(id: String, host: String, port: Int, publicID: String?)
    case resolutionFailed(id: String)
    case removed(id: String)
    case searchFailed
}

internal protocol TritonKitDiscoveryDriver: AnyObject {
    var event: ((TritonKitDiscoveryEvent) -> Void)? { get set }
    func start(timeout: TimeInterval)
    func poll(until deadline: TimeInterval)
    func stop()
}

internal enum TritonKitBonjourDiscovery {
    static func isValid(timeout: TimeInterval) -> Bool {
        timeout.isFinite && timeout > 0 && timeout <= 5
    }

    static func resolve(
        timeout: TimeInterval,
        driverFactory: () -> TritonKitDiscoveryDriver,
        now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) -> TritonKitDiscoveryResult {
        guard isValid(timeout: timeout) else { return .init(status: .invalidConfiguration) }
        #if TRITONKIT_RUNTIME_ENABLED
        let driver = driverFactory()
        let collector = TritonKitDiscoveryCollector()
        driver.event = { collector.receive($0) }
        defer {
            driver.event = nil
            driver.stop()
        }
        let deadline = now() + timeout
        driver.start(timeout: timeout)
        // A resolved service and moreComing=false do not close the discovery window.
        while now() < deadline && !collector.failed {
            driver.poll(until: min(deadline, now() + 0.02))
        }
        return collector.result
        #else
        return .init(status: .runtimeDisabled)
        #endif
    }
}

private final class TritonKitDiscoveryCollector {
    private var candidates: [String: TritonKitDiscoveryCandidate] = [:]
    private var order: [String] = []
    private(set) var failed = false

    func receive(_ event: TritonKitDiscoveryEvent) {
        switch event {
        case let .found(id, name):
            guard candidates[id] == nil else { return }
            // Bound untrusted discovery metadata retained during the window.
            guard order.count < 64 else { failed = true; return }
            order.append(id)
            candidates[id] = .init(serviceName: name)
        case let .resolved(id, host, rawPort, publicID):
            guard let previous = candidates[id], previous.isAvailable else { return }
            let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard !normalized.isEmpty, normalized.utf8.count <= 253,
                  !normalized.contains(where: { $0.isWhitespace || "/\\?#@:%".contains($0) || $0.isNewline }),
                  rawPort > 0, let port = UInt16(exactly: rawPort) else {
                receive(.resolutionFailed(id: id))
                return
            }
            candidates[id] = .init(serviceName: previous.serviceName, host: normalized, port: port, publicID: publicID)
        case let .resolutionFailed(id):
            guard let previous = candidates[id], previous.isAvailable else { return }
            candidates[id] = .init(serviceName: previous.serviceName)
        case let .removed(id):
            guard let previous = candidates[id] else { return }
            // Keep observed identities: a disappearing competing advertisement cannot
            // turn an ambiguous window into permission to choose the first service.
            candidates[id] = .init(serviceName: previous.serviceName, isAvailable: false)
        case .searchFailed:
            failed = true
        }
    }

    var result: TritonKitDiscoveryResult {
        let values = order.compactMap { candidates[$0] }
        let status: TritonKitDiscoveryResult.Status
        if failed { status = .failed }
        else if values.count > 1 { status = .ambiguous }
        else if values.isEmpty { status = .noCandidates }
        else if let only = values.first, only.isAvailable, only.host != nil, only.port != nil { status = .candidate }
        else { status = .unresolved }
        return .init(status: status, candidates: values)
    }
}

#if TRITONKIT_RUNTIME_ENABLED && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS))
internal final class TritonKitBonjourDriver: NSObject, TritonKitDiscoveryDriver, NetServiceBrowserDelegate, NetServiceDelegate {
    var event: ((TritonKitDiscoveryEvent) -> Void)?
    private let browser = NetServiceBrowser()
    private let serviceType: String
    private var services: [String: NetService] = [:]
    private var deadline = 0.0
    private var active = false

    init(serviceType: String = "_tritonkit-server._tcp.") {
        self.serviceType = serviceType
        super.init()
    }

    func start(timeout: TimeInterval) {
        active = true
        deadline = ProcessInfo.processInfo.systemUptime + timeout
        browser.delegate = self
        browser.searchForServices(ofType: serviceType, inDomain: "local.")
    }

    func poll(until deadline: TimeInterval) {
        let remaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(remaining))
    }

    func stop() {
        active = false
        browser.delegate = nil
        browser.stop()
        for service in services.values {
            service.delegate = nil
            service.stop()
        }
        services.removeAll()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard active else { return }
        let id = key(service)
        guard services[id] == nil else { return }
        event?(.found(id: id, name: service.name))
        guard services.count < 64 else { event?(.searchFailed); return }
        services[id] = service
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else { return }
        service.delegate = self
        service.resolve(withTimeout: remaining)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard active, let host = sender.hostName else { return }
        let txt = sender.txtRecordData().map(NetService.dictionary(fromTXTRecord:)) ?? [:]
        let publicID = txt["id"].flatMap { String(data: $0, encoding: .utf8) }
        event?(.resolved(id: key(sender), host: host, port: sender.port, publicID: publicID))
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        guard active else { return }
        event?(.resolutionFailed(id: key(sender)))
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        guard active else { return }
        let id = key(service)
        services[id]?.delegate = nil
        services[id]?.stop()
        event?(.removed(id: id))
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        guard active else { return }
        event?(.searchFailed)
    }

    private func key(_ service: NetService) -> String {
        service.domain + "\0" + service.type + "\0" + service.name
    }
}
#endif
