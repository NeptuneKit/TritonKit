import SwiftUI
import TritonKit

@main
struct TritonKitDemoApp: App {
    @StateObject private var model = DemoModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear { model.autoConnect() }
        }
    }
}

final class DemoModel: ObservableObject, TritonKitDelegate {
    @Published var status = "Disconnected"
    @Published var host = "127.0.0.1"
    @Published var port = "9090"
    @Published var log: [String] = []

    private let requestHandler = TritonKitRequestHandler()

    func autoConnect() {
        TritonKit.shared.delegate = self
        connect()
    }

    func connect() {
        guard let portNum = UInt16(port) else {
            addLog("Invalid port: \(port)")
            return
        }
        status = "Connecting..."
        addLog("WS: ws://\(host):\(portNum)/ws")
        TritonKit.shared.dataURL = URL(string: "http://\(host):\(portNum)")
        TritonKit.shared.connect(host: host, port: portNum)
    }

    func disconnect() {
        TritonKit.shared.disconnect()
    }

    // MARK: - TritonKitDelegate

    func tritonKit(_ kit: TritonKit, didChangeState state: TritonKit.ConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.status = "Connected"
                self.addLog("Connected to server!")
            case .connecting:
                self.status = "Connecting..."
            case .disconnected:
                self.status = "Disconnected"
                self.addLog("Disconnected")
            }
        }
    }

    func tritonKit(_ kit: TritonKit, didReceiveError error: Error) {
        DispatchQueue.main.async {
            self.addLog("Error: \(error.localizedDescription)")
        }
    }

    func tritonKit(_ kit: TritonKit, didReceiveMessage message: TKMessage) async -> TKMessage? {
        addLog("Received: \(message.type.rawValue) [id:\(message.id)]")
        return await requestHandler.tritonKit(kit, didReceiveMessage: message)
    }

    private func addLog(_ msg: String) {
        let entry = "[\(Date().formatted(.dateTime.hour().minute().second()))] \(msg)"
        DispatchQueue.main.async { self.log.append(entry) }
    }
}

struct ContentView: View {
    @ObservedObject var model: DemoModel

    var body: some View {
        VStack(spacing: 16) {
            Text("TritonKit Demo").font(.largeTitle).bold()

            Text("Status: \(model.status)")
                .foregroundColor(model.status == "Connected" ? .green : .orange)
                .font(.headline)

            HStack {
                TextField("Host", text: $model.host)
                    .textFieldStyle(.roundedBorder).frame(width: 140)
                TextField("Port", text: $model.port)
                    .textFieldStyle(.roundedBorder).frame(width: 80)
            }

            HStack {
                Button("Connect", action: model.connect)
                Button("Disconnect", action: model.disconnect)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.log.reversed(), id: \.self) { entry in
                        Text(entry).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(.systemGroupedBackground)).cornerRadius(8)
        }
        .padding()
    }
}
