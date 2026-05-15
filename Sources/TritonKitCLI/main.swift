import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKitShared

// MARK: - Entry Point

@main
struct TritonKitCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tritonkit",
        abstract: "TritonKit macOS CLI - WebSocket control + HTTP data server for iOS view debugging",
        subcommands: [Serve.self]
    )
}

// MARK: - Serve Command

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Start server")

    @Option(name: .shortAndLong, help: "Port to listen on") var port: Int = 8080
    @Option(name: .shortAndLong, help: "Host to bind to") var host: String = "0.0.0.0"

    func run() async throws {
        let store = DataStore()
        let state = ConnectionState()
        let encoder = JSONEncoder()
        let counter = MessageCounter()

        let router = Router(context: BasicWebSocketRequestContext.self)

        // ---- HTTP Data Endpoints ----

        router.post("/data") { request, _ -> Response in
            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }
            guard !bodyData.isEmpty else {
                return Response(status: .badRequest, body: .init(byteBuffer: ByteBuffer(string: "Empty body")))
            }
            let id = store.put(bodyData)
            let resp = try JSONEncoder().encode(["id": id])
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: resp)))
        }

        router.get("/data/:id") { request, _ -> Response in
            guard let idStr = request.uri.path.split(separator: "/").last,
                  let id = UUID(uuidString: String(idStr)),
                  let data = store.get(id) else {
                return Response(status: .notFound)
            }
            return Response(status: .ok, headers: [.contentType: "application/octet-stream"],
                            body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        router.get("/health") { _, _ -> HTTPResponse.Status in .ok }

        // ---- WebSocket Control Channel ----

        router.ws("/") { inbound, outbound, _ in
            log("[tritonkit] iOS device connected (ws)")
            state.set(outbound)

            // Test ping first to verify bidirectional communication
            let pingId = counter.next()
            log("[tritonkit] -> ping [id:\(pingId)]")
            try await outbound.send(TKMessage(id: pingId, type: .ping), encoder: encoder)

            // Then request hierarchy
            let id = counter.next()
            log("[tritonkit] -> hierarchy [id:\(id)]")
            try await outbound.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)

            do {
                for try await frame in inbound {
                    let data: Data
                    switch frame.opcode {
                    case .binary: data = Data(frame.data.readableBytesView)
                    case .text: data = Data(String(buffer: frame.data).utf8)
                    default: continue
                    }
                    handleResponse(data: data, store: store, state: state, counter: counter, encoder: encoder)
                }
            } catch {
                log("[tritonkit] Connection error: \(error)")
            }

            log("[tritonkit] iOS device disconnected")
            state.set(nil)
        }

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(webSocketRouter: router, configuration: .init(extensions: [])),
            configuration: .init(address: .hostname(host, port: port))
        )

        log("[tritonkit] Control: ws://\(host):\(port)/")
        log("[tritonkit] Data:   http://\(host):\(port)/data")
        log("[tritonkit] Commands: h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")

        // Stdin
        Task {
            while let line = readLine() {
                switch line.trimmingCharacters(in: .whitespaces).lowercased() {
                case "q", "quit", "exit": log("[tritonkit] Shut down."); Darwin.exit(0)
                case "h", "hierarchy":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> hierarchy [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "a", "appinfo":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> appInfo [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .appInfo), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "p", "ping":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> ping [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .ping), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "help", "?": log("[tritonkit] h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")
                case "": break
                default: log("[tritonkit] Unknown: \(line)")
                }
            }
        }

        signal(SIGINT, SIG_IGN)
        let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sig.setEventHandler { log("\n[tritonkit] Interrupted."); Darwin.exit(0) }
        sig.resume()

        do { try await app.run() } catch { log("[tritonkit] Error: \(error)"); throw error }
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

/// Thread-safe binary data store keyed by UUID
final class DataStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: Data] = [:]

    func put(_ data: Data) -> UUID {
        let id = UUID()
        lock.withLock { storage[id] = data }
        return id
    }

    func get(_ id: UUID) -> Data? {
        lock.withLock { storage[id] }
    }
}

// Flush-printing to stderr for immediate output in piped environments
func log(_ msg: String) {
    fputs("\(msg)\n", stderr)
    fflush(stderr)
}

// MARK: - Extensions

extension WebSocketOutboundWriter {
    func send(_ msg: TKMessage, encoder: JSONEncoder) async throws {
        guard let data = try? encoder.encode(msg) else { return }
        try await write(.binary(ByteBuffer(data: data)))
    }
}

// MARK: - Response Handling

func handleResponse(data: Data, store: DataStore, state: ConnectionState, counter: MessageCounter, encoder: JSONEncoder) {
    guard let msg = try? JSONDecoder().decode(TKMessage.self, from: data) else {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            log("[tritonkit] <- raw:\n\(str)")
        }
        return
    }

    log("[tritonkit] <- \(msg.type.rawValue) [id:\(msg.id)]")

    guard let payload = msg.payload,
          let json = try? JSONSerialization.jsonObject(with: payload) else { return }

    switch msg.type {
    case .hierarchy:
        if let dict = json as? [String: Any] {
            if let items = dict["displayItems"] as? [[String: Any]] {
                printHierarchy(items, indent: 0)
            }
            if let info = dict["appInfo"] as? [String: Any] {
                log("── App: \(info["appName"] ?? "?") | \(info["deviceDescription"] ?? "?") | OS \(info["osDescription"] ?? "?")")
            }
        }

    case .appInfo:
        if let dict = json as? [String: Any] {
            log("── \(dict["appName"] ?? "?") | \(dict["appBundleIdentifier"] ?? "?") | Device: \(dict["deviceDescription"] ?? "?")")
        }

    case .hierarchyDetails:
        checkAndShowImage(json: json, label: "solo", store: store)
        checkAndShowImage(json: json, label: "group", store: store)

    case .ping: log("  Pong!")
    default:
        if let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) { log(str) }
    }
}

func checkAndShowImage(json: Any, label: String, store: DataStore) {
    guard let dict = json as? [String: Any],
          let ref = dict["\(label)ScreenshotRef"] as? String,
          let id = UUID(uuidString: ref),
          let imgData = store.get(id) else { return }
    let size = ByteCountFormatter.string(fromByteCount: Int64(imgData.count), countStyle: .file)
    log("  [\(label) screenshot: \(size)]")
}

func printHierarchy(_ items: [[String: Any]], indent: Int) {
    for (i, item) in items.enumerated() {
        let isLast = i == items.count - 1
        let prefix: String
        if indent == 0 { prefix = "  " }
        else { prefix = String(repeating: "  ", count: indent - 1) + (isLast ? "  └─ " : "  ├─ ") }

        let viewObj = item["viewObject"] as? [String: Any]
        let className = (viewObj?["classChainList"] as? [String])?.first ?? "?"
        let frame = item["frame"] as? [String: Any]
        let hidden = item["isHidden"] as? Bool ?? false
        let alpha = item["alpha"] as? Float ?? 1.0
        let title = item["customDisplayTitle"] as? String
        let screenshotRef = item["screenshotRef"] as? String

        var line = "\(prefix)\(className)"
        if let t = title { line += " \"\(t)\"" }
        if let f = frame {
            line += String(format: " (%.0f,%.0f %.0fx%.0f)",
                f["x"] as? Double ?? 0, f["y"] as? Double ?? 0,
                f["width"] as? Double ?? 0, f["height"] as? Double ?? 0)
        }
        if hidden { line += " [H]" }
        if alpha < 1 { line += String(format: " α:%.2f", alpha) }
        if screenshotRef != nil { line += " [📷]" }
        log(line)

        if let subitems = item["subitems"] as? [[String: Any]] {
            printHierarchy(subitems, indent: indent + 1)
        }
    }
}
