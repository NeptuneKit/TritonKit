#if DEBUG
import Foundation
import TritonKit

final class TritonKitDebugBootstrap: TritonKitDelegate {
    var onStatusChange: ((String) -> Void)?
    var onLog: ((String) -> Void)?

    private let requestHandler = TritonKitRequestHandler()

    func connect(host: String, port: UInt16) {
        TritonKit.shared.delegate = self
        onStatusChange?("Connecting...")
        onLog?("WS: ws://\(host):\(port)/")
        TritonKit.shared.dataURL = URL(string: "http://\(host):\(port)")
        TritonKit.shared.connect(host: host, port: port)
    }

    func disconnect() {
        TritonKit.shared.disconnect()
    }

    func tritonKit(_ kit: TritonKit, didChangeState state: TritonKit.ConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.onStatusChange?("Connected")
                self.onLog?("Connected to server!")
            case .connecting:
                self.onStatusChange?("Connecting...")
            case .disconnected:
                self.onStatusChange?("Disconnected")
                self.onLog?("Disconnected")
            }
        }
    }

    func tritonKit(_ kit: TritonKit, didReceiveError error: Error) {
        DispatchQueue.main.async {
            self.onLog?("Error: \(error.localizedDescription)")
        }
    }

    func tritonKit(_ kit: TritonKit, didReceiveMessage message: TKMessage) async -> TKMessage? {
        onLog?("Received: \(message.type.rawValue) [id:\(message.id)]")
        return await requestHandler.tritonKit(kit, didReceiveMessage: message)
    }
}
#endif
