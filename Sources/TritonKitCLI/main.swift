import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOCore
import TritonKitShared

// MARK: - Entry Point

@main
struct TritonKitCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tritonkit",
        abstract: "TritonKit macOS CLI - WebSocket server for iOS view debugging",
        subcommands: [Serve.self]
    )
}

// MARK: - Serve Command

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start WebSocket server and wait for iOS device connections"
    )

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = 8080

    @Option(name: .shortAndLong, help: "Host to bind to")
    var host: String = "0.0.0.0"

    func run() async throws {
        let state = ConnectionState()
        let encoder = JSONEncoder()
        let counter = MessageCounter()

        let router = Router(context: BasicWebSocketRequestContext.self)

        router.get("/health") { _, _ -> HTTPResponse.Status in .ok }

        router.ws("/") { inbound, outbound, _ in
            print("[tritonkit] iOS device connected")
            state.set(outbound)

            // Auto-request hierarchy on connect
            let id = counter.next()
            print("[tritonkit] -> hierarchy [id:\(id)]")
            try await outbound.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)

            do {
                for try await frame in inbound {
                    let data: Data
                    switch frame.opcode {
                    case .binary: data = Data(frame.data.readableBytesView)
                    case .text: data = Data(String(buffer: frame.data).utf8)
                    default: continue
                    }
                    handleResponse(data: data)
                }
            } catch {
                print("[tritonkit] Connection error: \(error)")
            }

            print("[tritonkit] iOS device disconnected")
            state.set(nil)
        }

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(
                webSocketRouter: router,
                configuration: .init(extensions: [])
            ),
            configuration: .init(address: .hostname(host, port: port))
        )

        print("[tritonkit] WebSocket server on ws://\(host):\(port)")
        print("[tritonkit] Waiting for iOS device connection...")
        print("[tritonkit] Commands: h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")

        // Stdin command loop
        Task {
            while let line = readLine() {
                let cmd = line.trimmingCharacters(in: .whitespaces).lowercased()
                switch cmd {
                case "q", "quit", "exit":
                    print("[tritonkit] Shutting down...")
                    Darwin.exit(0)
                case "h", "hierarchy":
                    if let ws = state.outbound {
                        let id = counter.next()
                        print("[tritonkit] -> hierarchy [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)
                    } else { print("[tritonkit] No iOS device connected") }
                case "a", "appinfo":
                    if let ws = state.outbound {
                        let id = counter.next()
                        print("[tritonkit] -> appInfo [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .appInfo), encoder: encoder)
                    } else { print("[tritonkit] No iOS device connected") }
                case "p", "ping":
                    if let ws = state.outbound {
                        let id = counter.next()
                        print("[tritonkit] -> ping [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .ping), encoder: encoder)
                    } else { print("[tritonkit] No iOS device connected") }
                case "help", "?":
                    print("[tritonkit] h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")
                case "": break
                default:
                    print("[tritonkit] Unknown: \(line). Try: h a p q")
                }
            }
        }

        // Signal handling
        signal(SIGINT, SIG_IGN)
        let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigSource.setEventHandler { print("\n[tritonkit] Interrupted."); Darwin.exit(0) }
        sigSource.resume()

        do { try await app.run() }
        catch { print("[tritonkit] Server error: \(error)"); throw error }
    }
}

// MARK: - State

final class ConnectionState: @unchecked Sendable {
    private let lock = NSLock()
    private var _outbound: WebSocketOutboundWriter?
    func set(_ w: WebSocketOutboundWriter?) { lock.withLock { _outbound = w } }
    var outbound: WebSocketOutboundWriter? { lock.withLock { _outbound } }
}

final class MessageCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
}

// MARK: - Extensions

extension WebSocketOutboundWriter {
    func send(_ msg: TKMessage, encoder: JSONEncoder) async throws {
        guard let data = try? encoder.encode(msg) else { return }
        try await write(.binary(ByteBuffer(data: data)))
    }
}

// MARK: - Response Handling

func handleResponse(data: Data) {
    guard let msg = try? JSONDecoder().decode(TKMessage.self, from: data) else {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let str = String(data: pretty, encoding: .utf8) {
            print("[tritonkit] <- raw:\n\(str)")
        }
        return
    }

    print("[tritonkit] <- \(msg.type.rawValue) [id:\(msg.id)]")

    guard let payload = msg.payload,
          let json = try? JSONSerialization.jsonObject(with: payload) else { return }

    switch msg.type {
    case .hierarchy:
        if let dict = json as? [String: Any], let items = dict["displayItems"] as? [[String: Any]] {
            printHierarchy(items, indent: 0)
            if let info = dict["appInfo"] as? [String: Any] {
                print("── App: \(info["appName"] ?? "?") | \(info["deviceDescription"] ?? "?") | OS \(info["osDescription"] ?? "?")")
            }
        }
    case .appInfo:
        if let dict = json as? [String: Any] {
            print("── \(dict["appName"] ?? "?") | \(dict["appBundleIdentifier"] ?? "?") | \(dict["deviceDescription"] ?? "?") | OS \(dict["osDescription"] ?? "?") | Screen \(dict["screenWidth"] ?? 0)x\(dict["screenHeight"] ?? 0) @\(dict["screenScale"] ?? 0)x")
        }
    case .ping: print("  Pong!")
    default:
        if let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let str = String(data: pretty, encoding: .utf8) { print(str) }
    }
}

func printHierarchy(_ items: [[String: Any]], indent: Int) {
    for (i, item) in items.enumerated() {
        let isLast = i == items.count - 1
        let prefix: String
        if indent == 0 { prefix = "" }
        else { prefix = String(repeating: "  ", count: indent - 1) + (isLast ? "  └─ " : "  ├─ ") }

        let viewObj = item["viewObject"] as? [String: Any]
        let className = (viewObj?["classChainList"] as? [String])?.first ?? "?"
        let frame = item["frame"] as? [String: Any]
        let hidden = item["isHidden"] as? Bool ?? false
        let alpha = item["alpha"] as? Float ?? 1.0
        let title = item["customDisplayTitle"] as? String

        var line = "\(prefix)\(className)"
        if let t = title { line += " \"\(t)\"" }
        if let f = frame {
            line += String(format: " (%.0f,%.0f %.0fx%.0f)",
                f["x"] as? Double ?? 0, f["y"] as? Double ?? 0,
                f["width"] as? Double ?? 0, f["height"] as? Double ?? 0)
        }
        if hidden { line += " [H]" }
        if alpha < 1 { line += String(format: " α:%.2f", alpha) }
        print(line)

        if let subitems = item["subitems"] as? [[String: Any]] {
            printHierarchy(subitems, indent: indent + 1)
        }
    }
}
