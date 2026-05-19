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

public class TritonKit {
    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }

    public static let shared = TritonKit()

    public weak var delegate: TritonKitDelegate?
    public private(set) var state: ConnectionState = .disconnected {
        didSet { delegate?.tritonKit(self, didChangeState: state) }
    }

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var host: String = ""
    private var port: UInt16 = 0
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?

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

    public func connect(host: String, port: UInt16) {
        self.host = host
        self.port = port
        disconnect()
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
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        stopTimers()
        state = .disconnected
    }

    public func send(_ message: TKMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        task?.send(.data(data)) { [weak self] error in
            guard let self, let error else { return }
            self.delegate?.tritonKit(self, didReceiveError: error)
        }
    }

    /// Send raw JSON string
    public func send(json: String) {
        task?.send(.string(json)) { [weak self] error in
            guard let self, let error else { return }
            self.delegate?.tritonKit(self, didReceiveError: error)
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
                self.delegate?.tritonKit(self, didReceiveError: error)
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
        if state == .disconnected, !host.isEmpty { connect(host: host, port: port) }
    }
    #endif

    private func scheduleReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.state == .disconnected, !self.host.isEmpty else { return }
            self.connect(host: self.host, port: self.port)
        }
    }

    private func startPing() {
        stopTimers()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.task?.sendPing { _ in }
        }
    }

    private func stopTimers() {
        pingTimer?.invalidate(); pingTimer = nil
        reconnectTimer?.invalidate(); reconnectTimer = nil
    }
}
