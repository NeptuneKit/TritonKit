import Foundation
import XCTest
import UniformTypeIdentifiers

struct PlatformRequest: Decodable {
    let version: Int
    let platform: String
    let action: String
    let device: String
    let nonce: String
    let crownDelta: Double?

    static func load(platform: String) throws -> PlatformRequest {
        let environment = ProcessInfo.processInfo.environment
        guard let raw = environment["TRITON_PLATFORM_REQUEST"], let data = raw.data(using: .utf8) else {
            throw rejection("Missing runner request")
        }
        let request = try JSONDecoder().decode(Self.self, from: data)
        // SIMULATOR_UDID is injected by CoreSimulator in the actual XCTest runner process.
        // It is never populated by the acceptance app or copied from the request.
        guard let runtimeDevice = environment["SIMULATOR_UDID"],
              UUID(uuidString: runtimeDevice) != nil,
              runtimeDevice.caseInsensitiveCompare(request.device) == .orderedSame,
              request.version == 1, request.platform == platform,
              !request.nonce.isEmpty else {
            throw rejection("Runner request does not match actual simulator identity/platform")
        }
        return request
    }

    static func rejection(_ message: String) -> NSError {
        NSError(domain: "TritonPlatformAcceptance", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

extension XCTestCase {
    func attachPlatformResult(_ request: PlatformRequest, succeeded: Bool) {
        // A failed postcondition cannot tell whether the input was delivered.
        // Keep the XCTest failure and omit a success attachment so the host reports unknown.
        guard succeeded else { return }
        var result: [String: Any] = [
            "version": 1, "platform": request.platform, "action": request.action,
            "device": ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "",
            "nonce": request.nonce, "ok": succeeded,
            "eventDelivered": succeeded, "postconditionVerified": succeeded
        ]
        if let delta = request.crownDelta { result["crownDelta"] = delta }
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]) else { return }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: UTType.json.identifier)
        attachment.name = "triton-platform-result"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
