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
        do {
            let resolvedUDID: String
            if device.lowercased() == "booted" {
                let list = try runHostCommand(TKHostCommand(executable: "xcrun", arguments: ["simctl", "list", "devices", "booted", "-j"]))
                let decoder = JSONDecoder()
                struct SimctlList: Decodable { let devices: [String: [SimctlDevice]] }
                struct SimctlDevice: Decodable { let state: String; let udid: String }
                let parsed = try decoder.decode(SimctlList.self, from: list.stdoutData)
                if let firstBooted = parsed.devices.values.flatMap({ $0 }).first(where: { $0.state == "Booted" }) {
                    resolvedUDID = firstBooted.udid
                } else {
                    throw HostSimulatorAXError.targetNotFound("booted")
                }
            } else {
                resolvedUDID = device
            }

            let driver = AXPTranslatorAccessibility(udid: resolvedUDID)
            guard let tree = try driver.describeAll() else {
                throw HostSimulatorAXError.treeUnavailable(resolvedUDID)
            }

            switch outputFormat {
            case .json:
                print(try encodeJSON(tree))
            case .text:
                printTree(tree, indent: "")
            }
        } catch let error as HostSimulatorAXError {
            try fail(error: error, outputFormat: outputFormat)
        }
        #else
        try fail(error: .unsupportedPlatform, outputFormat: outputFormat)
        #endif
    }

    private func fail(error: HostSimulatorAXError, outputFormat: ClientOutputFormat) throws -> Never {
        switch outputFormat {
        case .json:
            print(try encodeJSON(TKCLIErrorResponse(error: error.detail, surface: "sim.ax")))
        case .text:
            fputs("\(error.detail.code): \(error.detail.message)\n", stderr)
            if let hint = error.detail.hint {
                fputs("hint: \(hint)\n", stderr)
            }
        }
        throw ExitCode.failure
    }
    
    #if os(macOS)
    private func printTree(_ node: TKAXNode, indent: String) {
        let label = node.label ?? node.title ?? ""
        let val = node.value ?? ""
        let id = node.identifier ?? ""
        let frameStr = "[x:\(node.frame.x),y:\(node.frame.y),w:\(node.frame.width),h:\(node.frame.height)]"
        print("\(indent)\(node.role) | label: '\(label)' | val: '\(val)' | id: '\(id)' | \(frameStr)")
        for child in node.children {
            printTree(child, indent: indent + "  ")
        }
    }
    #endif
}
