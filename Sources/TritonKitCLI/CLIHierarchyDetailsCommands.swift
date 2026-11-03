import ArgumentParser
import Foundation
import TritonKit
import TritonKitShared

struct HierarchyDetails: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "details",
        abstract: "Read bounded live node details and distinct solo/group screenshots"
    )

    @Option(name: [.long, .customLong("device")], help: "Runtime target id from triton list")
    var target = TKLocalTargetID
    @Option(name: [.customLong("oid"), .customLong("id")], parsing: .singleValue,
            help: "View or layer object ID; repeat for up to 8 unique IDs from debug nodes")
    var oids: [UInt] = []
    @Option(help: "Images to capture: none, solo, group, or both") var screenshots: String = "both"
    @Flag(inversion: .prefixedNo, help: "Include live attribute groups") var includeAttributes = true
    @Option(help: "Maximum pixels per image (1...1048576)") var maxPixelCount: Int = 262_144
    @Option(help: "Server host") var host = "127.0.0.1"
    @Option(help: "Server port") var port = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func validate() throws {
        _ = try makeRequest()
        guard (1...65535).contains(port), !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("--host must be nonempty and --port must be between 1 and 65535")
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/request"
        guard components.url != nil else { throw ValidationError("--host is not a valid HTTP host") }
    }

    func makeRequest() throws -> TKHierarchyDetailsRequest {
        guard let mode = TKNodeScreenshotMode(rawValue: screenshots) else {
            throw ValidationError("--screenshots must be none, solo, group, or both")
        }
        let request = TKHierarchyDetailsRequest(oids: oids, screenshots: mode,
            includeAttributes: includeAttributes, maxPixelCount: maxPixelCount)
        if let reason = request.validationError { throw ValidationError(reason) }
        return request
    }

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let request = try makeRequest()
            let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port,
                jsonError: outputFormat == .json)
            let data = try await requestHierarchyDetails(request, client: client)
            try emitHierarchyDetails(data, requestedOIDs: request.oids, outputFormat: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}
