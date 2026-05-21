import Foundation
import TritonKitShared
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
        #if DEBUG
        true
        #else
        false
        #endif
    }

    public static let shared = TritonKit()

    public weak var delegate: TritonKitDelegate?
    public private(set) var state: ConnectionState = .disconnected {
        didSet {
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
    private var stateObservers: [UUID: (ConnectionState) -> Void] = [:]
    private var errorObservers: [UUID: (Error) -> Void] = [:]

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
    public func onStateChange(_ handler: @escaping (ConnectionState) -> Void) -> ObservationToken {
        let id = UUID()
        stateObservers[id] = handler
        handler(state)
        return ObservationToken { [weak self] in
            self?.stateObservers.removeValue(forKey: id)
        }
    }

    @discardableResult
    public func onError(_ handler: @escaping (Error) -> Void) -> ObservationToken {
        let id = UUID()
        errorObservers[id] = handler
        return ObservationToken { [weak self] in
            self?.errorObservers.removeValue(forKey: id)
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
        for observer in Array(stateObservers.values) {
            observer(state)
        }
    }

    private func notifyError(_ error: Error) {
        delegate?.tritonKit(self, didReceiveError: error)
        for observer in Array(errorObservers.values) {
            observer(error)
        }
    }
}
