import Foundation
import TritonKitShared
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#if canImport(UIKit)
import UIKit
#endif

public protocol TritonKitDelegate: AnyObject {
    func tritonKit(_ kit: TritonKit, didChangeState state: TritonKit.ConnectionState)
    func tritonKit(_ kit: TritonKit, didReceiveError error: Error)
    func tritonKit(_ kit: TritonKit, didReceiveMessage message: TKMessage) async -> TKMessage?
}

public extension TritonKitDelegate {
    func tritonKit(_ kit: TritonKit, didReceiveMessage message: TKMessage) async -> TKMessage? { nil }
}

public enum TritonKitRuntimeError: Error {
    case disabledOutsideDebug
}

public struct TritonKitStartPayload: Equatable {
    public var host: String
    public var port: UInt16
    public var dataURL: URL?

    public init(host: String = "127.0.0.1", port: UInt16 = 19421, dataURL: URL? = nil) {
        self.host = host
        self.port = port
        self.dataURL = dataURL ?? Self.defaultDataURL(host: host, port: port)
    }

    public static func environment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        defaultHost: String = "127.0.0.1",
        defaultPort: UInt16 = 19421
    ) -> Self {
        let host = environment["TRITON_HOST"] ?? defaultHost
        let port = environment["TRITON_PORT"].flatMap(UInt16.init) ?? defaultPort
        return Self(host: host, port: port)
    }

    public static func local(port: UInt16 = 19421) -> Self {
        Self(host: "127.0.0.1", port: port)
    }

    public static func device(_ host: String, port: UInt16 = 19421) -> Self {
        Self(host: host, port: port)
    }

    private static func defaultDataURL(host: String, port: UInt16) -> URL? {
        URL(string: "http://\(host):\(port)")
    }
}

public class TritonKit {
    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }

    public typealias Endpoint = TritonKitStartPayload

    public enum Feature: String, CaseIterable, Hashable {
        case appInfo
        case hierarchy
        case accessibility
        case geometry
        case screenshot
        case input
        case semantic
    }

    public struct RedactionPolicy: Equatable {
        public enum SecureText: String, Equatable {
            case lengthOnly
            case hidden
        }

        public var secureText: SecureText
        public var collectClipboard: Bool
        public var collectNetwork: Bool
        public var collectLogs: Bool

        public init(
            secureText: SecureText = .lengthOnly,
            collectClipboard: Bool = false,
            collectNetwork: Bool = false,
            collectLogs: Bool = false
        ) {
            self.secureText = secureText
            self.collectClipboard = collectClipboard
            self.collectNetwork = collectNetwork
            self.collectLogs = collectLogs
        }
    }

    public struct AppIdentity: Equatable {
        public var name: String
        public var tags: [String]

        public init(name: String, tags: [String] = []) {
            self.name = name
            self.tags = tags
        }
    }

    public struct Configuration: Equatable {
        public static let defaultFeatures: Set<Feature> = [
            .appInfo,
            .hierarchy,
            .accessibility,
            .geometry,
            .screenshot,
            .input,
            .semantic,
        ]

        public var endpoint: Endpoint
        public var autoReconnect: Bool
        public var features: Set<Feature>
        public var redaction: RedactionPolicy
        public var appIdentity: AppIdentity?

        public init(
            endpoint: Endpoint = .environment(),
            autoReconnect: Bool = true,
            features: Set<Feature> = Configuration.defaultFeatures,
            redaction: RedactionPolicy = RedactionPolicy(),
            appIdentity: AppIdentity? = nil
        ) {
            self.endpoint = endpoint
            self.autoReconnect = autoReconnect
            self.features = features
            self.redaction = redaction
            self.appIdentity = appIdentity
        }

        public init(_ configure: (inout Configuration) -> Void) {
            self.init()
            configure(&self)
        }
    }

    public final class ObservationToken {
        private let lock = NSLock()
        private var cancellation: (() -> Void)?

        fileprivate init(_ cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        public func cancel() {
            lock.lock()
            let cancellation = self.cancellation
            self.cancellation = nil
            lock.unlock()
            cancellation?()
        }

        deinit {
            cancel()
        }
    }

    public static var isRuntimeEnabled: Bool {
        #if TRITONKIT_RUNTIME_ENABLED
        true
        #else
        false
        #endif
    }

    public static let shared = TritonKit()

    public weak var delegate: TritonKitDelegate?
    public private(set) var state: ConnectionState = .disconnected {
        didSet {
            guard oldValue != state else { return }
            delegate?.tritonKit(self, didChangeState: state)
            notifyStateObservers(state)
        }
    }
    public private(set) var configuration = Configuration()

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var host: String = ""
    private var port: UInt16 = 0
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?
    private var defaultRequestHandler: TritonKitRequestHandler?
    private var isStarted = false
    private let observerLock = NSLock()
    private var stateObservers: [UUID: (ConnectionState) -> Void] = [:]
    private var errorObservers: [UUID: (Error) -> Void] = [:]
    private let semanticProviderLock = NSLock()
    private var semanticProviders: [String: SemanticProviderRegistration] = [:]
    internal var endpointReadinessTimeout: TimeInterval = 0.25
    internal var endpointReadinessProbe: (String, UInt16, TimeInterval) -> Bool = TritonKit.probeEndpointReadiness

    /// HTTP data uploader (for screenshots / heavy payloads)
    public private(set) var uploader: TritonKitDataUploader?
    private var _dataURL: URL?

    /// Set the CLI's HTTP data endpoint URL (e.g., http://192.168.1.5:8080)
    public var dataURL: URL? {
        get { _dataURL }
        set {
            _dataURL = newValue
            if let url = newValue { uploader = TritonKitDataUploader(baseURL: url) }
            else { uploader = nil }
        }
    }

    private struct SemanticProviderRegistration {
        let id: UUID
        let domain: String
        let displayName: String?
        let source: String
        let confidence: String
        let schema: [TKRuntimeSemanticStateField]
        let actions: [TKRuntimeSemanticActionDescriptor]
        let redaction: TKRuntimeSemanticRedaction
        let evidenceCommands: [String]
        let state: () -> [String: TKJSONValue]
    }

    private init() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        #endif
    }

    deinit { disconnect(); NotificationCenter.default.removeObserver(self) }

    // MARK: - Public

    @discardableResult
    public func start(_ payload: TritonKitStartPayload = .environment()) -> Bool {
        start(Configuration(endpoint: payload))
    }

    @discardableResult
    public func start(_ configuration: Configuration) -> Bool {
        startRuntime(configuration, delegate: nil)
    }

    @discardableResult
    public func start(_ configure: (inout Configuration) -> Void) -> Bool {
        start(Configuration(configure))
    }

    @discardableResult
    public func start(_ payload: TritonKitStartPayload, delegate: TritonKitDelegate) -> Bool {
        startRuntime(Configuration(endpoint: payload), delegate: delegate)
    }

    @discardableResult
    public func start(_ configuration: Configuration, delegate: TritonKitDelegate) -> Bool {
        startRuntime(configuration, delegate: delegate)
    }

    public func stop() {
        isStarted = false
        closeConnection()
    }

    @discardableResult
    public func registerSemanticStateProvider(
        domain: String,
        displayName: String? = nil,
        source: String = "runtime-provider",
        confidence: String = "provider-backed",
        schema: [TKRuntimeSemanticStateField] = [],
        actions: [TKRuntimeSemanticActionDescriptor] = [],
        redaction: TKRuntimeSemanticRedaction = TKRuntimeSemanticRedaction(),
        evidenceCommands: [String] = TKRuntimeSemanticDefaultEvidenceCommands,
        state: @escaping () -> [String: TKJSONValue]
    ) -> ObservationToken {
        let normalizedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let registration = SemanticProviderRegistration(
            id: UUID(),
            domain: normalizedDomain.isEmpty ? "app" : normalizedDomain,
            displayName: displayName,
            source: source,
            confidence: confidence,
            schema: schema,
            actions: actions,
            redaction: redaction,
            evidenceCommands: evidenceCommands,
            state: state
        )
        semanticProviderLock.lock()
        semanticProviders[registration.domain] = registration
        semanticProviderLock.unlock()

        return ObservationToken { [weak self] in
            guard let self else { return }
            self.semanticProviderLock.lock()
            if self.semanticProviders[registration.domain]?.id == registration.id {
                self.semanticProviders.removeValue(forKey: registration.domain)
            }
            self.semanticProviderLock.unlock()
        }
    }

    public func clearSemanticStateProvider(domain: String) {
        let normalizedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        semanticProviderLock.lock()
        semanticProviders.removeValue(forKey: normalizedDomain.isEmpty ? "app" : normalizedDomain)
        semanticProviderLock.unlock()
    }

    internal var hasSemanticStateProviders: Bool {
        semanticProviderLock.lock()
        let hasProviders = !semanticProviders.isEmpty
        semanticProviderLock.unlock()
        return hasProviders
    }

    internal var semanticDomainManifests: [TKRuntimeSemanticDomainManifest] {
        semanticProviderLock.lock()
        let registrations = semanticProviders.values.sorted { $0.domain < $1.domain }
        semanticProviderLock.unlock()

        return registrations.map { registration in
            TKRuntimeSemanticDomainManifest(
                domain: registration.domain,
                displayName: registration.displayName,
                source: registration.source,
                confidence: registration.confidence,
                schema: registration.schema,
                actions: registration.actions,
                redaction: registration.redaction,
                evidenceCommands: registration.evidenceCommands
            )
        }
    }

    internal func currentSemanticState(capturedAt: String) -> TKRuntimeSemanticStateResponse {
        semanticProviderLock.lock()
        let registrations = semanticProviders.values.sorted { $0.domain < $1.domain }
        semanticProviderLock.unlock()

        let domains = registrations.map { registration in
            TKRuntimeSemanticDomainState(
                domain: registration.domain,
                displayName: registration.displayName,
                source: registration.source,
                confidence: registration.confidence,
                state: registration.state(),
                schema: registration.schema,
                actions: registration.actions,
                redaction: registration.redaction,
                evidenceCommands: registration.evidenceCommands
            )
        }
        return TKRuntimeSemanticStateResponse(capturedAt: capturedAt, domains: domains)
    }

    @discardableResult
    public func onStateChange(_ handler: @escaping (ConnectionState) -> Void) -> ObservationToken {
        let id = UUID()
        observerLock.lock()
        stateObservers[id] = handler
        let currentState = state
        observerLock.unlock()
        handler(currentState)
        return ObservationToken { [weak self] in
            guard let self else { return }
            self.observerLock.lock()
            self.stateObservers.removeValue(forKey: id)
            self.observerLock.unlock()
        }
    }

    @discardableResult
    public func onError(_ handler: @escaping (Error) -> Void) -> ObservationToken {
        let id = UUID()
        observerLock.lock()
        errorObservers[id] = handler
        observerLock.unlock()
        return ObservationToken { [weak self] in
            guard let self else { return }
            self.observerLock.lock()
            self.errorObservers.removeValue(forKey: id)
            self.observerLock.unlock()
        }
    }

    private func startRuntime(_ configuration: Configuration, delegate explicitDelegate: TritonKitDelegate?) -> Bool {
        self.configuration = configuration
        guard Self.isRuntimeEnabled else {
            stop()
            return false
        }

        if let explicitDelegate {
            defaultRequestHandler = nil
            delegate = explicitDelegate
        } else {
            let requestHandler = defaultRequestHandler ?? TritonKitRequestHandler()
            defaultRequestHandler = requestHandler
            delegate = requestHandler
        }

        dataURL = configuration.endpoint.dataURL
        connect(host: configuration.endpoint.host, port: configuration.endpoint.port, autoReconnect: configuration.autoReconnect)
        return true
    }

    public func connect(host: String, port: UInt16) {
        connect(host: host, port: port, autoReconnect: true)
    }

    private func connect(host: String, port: UInt16, autoReconnect: Bool) {
        guard Self.isRuntimeEnabled else {
            stop()
            return
        }
        self.host = host
        self.port = port
        self.isStarted = true
        if configuration.endpoint.host != host || configuration.endpoint.port != port {
            configuration = Configuration(endpoint: Endpoint(host: host, port: port, dataURL: dataURL))
        }
        if configuration.autoReconnect != autoReconnect {
            configuration.autoReconnect = autoReconnect
        }
        closeConnection()
        state = .connecting

        guard endpointReadinessProbe(host, port, endpointReadinessTimeout) else {
            state = .disconnected
            scheduleReconnect()
            return
        }

        let url = URL(string: "ws://\(host):\(port)/")!
        let req = URLRequest(url: url, timeoutInterval: 10)

        session = URLSession(configuration: .default)
        task = session?.webSocketTask(with: req)
        task?.resume()
        startPing()
        receive()
    }

    public func disconnect() {
        stop()
    }

    private func closeConnection() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        stopTimers()
        state = .disconnected
    }

    public func send(_ message: TKMessage) {
        guard Self.isRuntimeEnabled else { return }
        guard let data = try? JSONEncoder().encode(message) else { return }
        task?.send(.data(data)) { [weak self] error in
            guard let self, let error else { return }
            self.notifyError(error)
        }
    }

    /// Send raw JSON string
    public func send(json: String) {
        guard Self.isRuntimeEnabled else { return }
        task?.send(.string(json)) { [weak self] error in
            guard let self, let error else { return }
            self.notifyError(error)
        }
    }

    // MARK: - Receive Loop

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if self.state != .connected {
                    self.state = .connected
                }
                self.handle(message)
            case .failure(let error):
                self.state = .disconnected
                self.notifyError(error)
                self.scheduleReconnect()
                return
            }
            self.receive()
        }
    }

    private func handle(_ wsMessage: URLSessionWebSocketTask.Message) {
        let data: Data
        switch wsMessage {
        case .data(let d): data = d
        case .string(let text): guard let d = text.data(using: .utf8) else { return }; data = d
        @unknown default: return
        }

        Task {
            do {
                let msg = try JSONDecoder().decode(TKMessage.self, from: data)
                if let response = await delegate?.tritonKit(self, didReceiveMessage: msg) {
                    send(response)
                }
            } catch {
                send(TKMessage(id: 0, type: .ping, payload: try? JSONEncoder().encode(
                    TKErrorPayload(message: "Parse error: \(error.localizedDescription)")
                )))
            }
        }
    }

    // MARK: - Lifecycle

    #if canImport(UIKit)
    @objc private func appDidBecomeActive() {
        if state == .disconnected, isStarted, configuration.autoReconnect, !host.isEmpty {
            connect(host: host, port: port, autoReconnect: configuration.autoReconnect)
        }
    }
    #endif

    private func scheduleReconnect() {
        guard Self.isRuntimeEnabled, isStarted, configuration.autoReconnect else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self,
                  self.isStarted,
                  self.configuration.autoReconnect,
                  self.state == .disconnected,
                  !self.host.isEmpty
            else { return }
            self.connect(host: self.host, port: self.port, autoReconnect: self.configuration.autoReconnect)
        }
    }

    private func startPing() {
        guard Self.isRuntimeEnabled else { return }
        stopTimers()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.task?.sendPing { _ in }
        }
    }

    private func stopTimers() {
        pingTimer?.invalidate(); pingTimer = nil
        reconnectTimer?.invalidate(); reconnectTimer = nil
    }

    private func notifyStateObservers(_ state: ConnectionState) {
        observerLock.lock()
        let observers = Array(stateObservers.values)
        observerLock.unlock()
        for observer in observers {
            observer(state)
        }
    }

    private func notifyError(_ error: Error) {
        delegate?.tritonKit(self, didReceiveError: error)
        observerLock.lock()
        let observers = Array(errorObservers.values)
        observerLock.unlock()
        for observer in observers {
            observer(error)
        }
    }

    private static func probeEndpointReadiness(host: String, port: UInt16, timeout: TimeInterval) -> Bool {
        #if canImport(Darwin) || canImport(Glibc)
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        #if canImport(Glibc)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif
        hints.ai_protocol = IPPROTO_TCP

        var results: UnsafeMutablePointer<addrinfo>?
        let lookupResult = getaddrinfo(host, String(port), &hints, &results)
        guard lookupResult == 0, let results else { return false }
        defer { freeaddrinfo(results) }

        let timeoutMilliseconds = max(1, Int32((timeout * 1000).rounded(.up)))
        var current: UnsafeMutablePointer<addrinfo>? = results
        while let candidate = current {
            if probeSocketAddress(candidate, timeoutMilliseconds: timeoutMilliseconds) {
                return true
            }
            current = candidate.pointee.ai_next
        }
        return false
        #else
        return true
        #endif
    }

    #if canImport(Darwin) || canImport(Glibc)
    private static func probeSocketAddress(
        _ candidate: UnsafeMutablePointer<addrinfo>,
        timeoutMilliseconds: Int32
    ) -> Bool {
        let descriptor = socket(candidate.pointee.ai_family, candidate.pointee.ai_socktype, candidate.pointee.ai_protocol)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        let currentFlags = fcntl(descriptor, F_GETFL, 0)
        guard currentFlags >= 0 else { return false }
        guard fcntl(descriptor, F_SETFL, currentFlags | O_NONBLOCK) >= 0 else { return false }

        #if canImport(Darwin)
        let connectionResult = Darwin.connect(descriptor, candidate.pointee.ai_addr, candidate.pointee.ai_addrlen)
        #else
        let connectionResult = Glibc.connect(descriptor, candidate.pointee.ai_addr, candidate.pointee.ai_addrlen)
        #endif
        if connectionResult == 0 {
            return true
        }

        guard errno == EINPROGRESS else {
            return false
        }

        var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
        let pollResult = poll(&pollDescriptor, nfds_t(1), timeoutMilliseconds)
        guard pollResult > 0, (pollDescriptor.revents & Int16(POLLOUT)) != 0 else {
            return false
        }

        var socketError: Int32 = 0
        var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
        let optionResult = getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &socketError, &socketErrorLength)
        return optionResult == 0 && socketError == 0
    }
    #endif
}
