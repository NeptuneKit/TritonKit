#if DEBUG
import Foundation
import TritonKit

final class TritonKitFixtureDebugBootstrap: TritonKitDelegate {
    var onStatusChange: ((String) -> Void)?

    private let requestHandler = TritonKitRequestHandler()

    func connect(host: String, port: UInt16) {
        onStatusChange?("Connecting")
        var configuration = TritonKit.Configuration(endpoint: .init(host: host, port: port))
        // This Debug fixture grants inspector capability even when its entry
        // starts hidden; TRITON_PICKER_ENABLED still controls initial visibility.
        configuration.features.insert(.inspector)
        TritonKit.shared.start(configuration, delegate: self)
    }

    @MainActor var isPickerEnabled: Bool { TritonKit.shared.isPickerEnabled }

    @MainActor @discardableResult
    func setPickerEnabled(_ enabled: Bool) -> Bool {
        TritonKit.shared.setPickerEnabled(enabled)
    }

    func tritonKit(_ kit: TritonKit, didChangeState state: TritonKit.ConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.onStatusChange?("Connected")
            case .connecting:
                self.onStatusChange?("Connecting")
            case .disconnected:
                self.onStatusChange?("Disconnected")
            }
        }
    }

    func tritonKit(_ kit: TritonKit, didReceiveError error: Error) {
        DispatchQueue.main.async {
            self.onStatusChange?("Error")
        }
    }

    func tritonKit(_ kit: TritonKit, didReceiveMessage message: TKMessage) async -> TKMessage? {
        await requestHandler.tritonKit(kit, didReceiveMessage: message)
    }
}
#endif
