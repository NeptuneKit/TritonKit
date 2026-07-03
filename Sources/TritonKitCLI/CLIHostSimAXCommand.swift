import ArgumentParser
import Foundation
import TritonKitShared
import TritonKit

struct SimAX: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ax", abstract: "Dump the host-side Accessibility tree for a simulator")

    @Option(help: "Simulator UDID or alias") var device: String = "booted"
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        
        #if os(macOS)
        let resolvedUDID: String
        if device.lowercased() == "booted" {
            // Find a booted device
            let list = try runHostCommand(TKHostCommand(executable: "xcrun", arguments: ["simctl", "list", "devices", "booted", "-j"]))
            let decoder = JSONDecoder()
            struct SimctlList: Decodable { let devices: [String: [SimctlDevice]] }
            struct SimctlDevice: Decodable { let state: String; let udid: String }
            let parsed = try decoder.decode(SimctlList.self, from: list.stdoutData)
            if let firstBooted = parsed.devices.values.flatMap({ $0 }).first(where: { $0.state == "Booted" }) {
                resolvedUDID = firstBooted.udid
            } else {
                throw CleanExit.message("No booted simulator found")
            }
        } else {
            resolvedUDID = device
        }

        let driver = AXPTranslatorAccessibility(udid: resolvedUDID)
        guard let tree = try driver.describeAll() else {
            throw CleanExit.message("Failed to fetch tree from AXPTranslatorAccessibility for udid \(resolvedUDID). Check if framework is loaded and device is frontmost.")
        }
        
        switch outputFormat {
        case .json:
            print(try encodeJSON(tree))
        case .text:
            printTree(tree, indent: "")
        }
        #else
        print("macOS only")
        #endif
    }
    
    #if os(macOS)
    private func printTree(_ node: TKAXNode, indent: String) {
        let label = node.label ?? node.title ?? ""
        let val = node.value ?? ""
        let id = node.identifier ?? ""
        let frameStr = "[x:\(node.frame.x),y:\(node.frame.y),w:\(node.frame.width),h:\(node.frame.height)]"
        print("\(indent)\(node.role ?? "Unknown") | label: '\(label)' | val: '\(val)' | id: '\(id)' | \(frameStr)")
        for child in node.children {
            printTree(child, indent: indent + "  ")
        }
    }
    #endif
}
