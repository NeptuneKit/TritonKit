import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// HTTP data uploader for sending screenshots / binary payloads to CLI
public final class TritonKitDataUploader: @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL) {
        self.baseURL = baseURL.appendingPathComponent("data")
        self.session = URLSession(configuration: .default)
    }

    /// Upload binary data, returns the data reference ID from the CLI
    public func upload(_ data: Data) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (responseData, _) = try await session.data(for: request)
        struct DataUploadResponse: Decodable { let id: String }
        let resp = try JSONDecoder().decode(DataUploadResponse.self, from: responseData)
        return resp.id
    }

    /// Capture a UIView screenshot (png data) - must be called on main actor
    @MainActor
    public static func captureScreenshot(view: UIView) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        format.opaque = view.isOpaque
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
        let image = renderer.image { ctx in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        return image.pngData()
    }

    /// Capture a view screenshot and upload it
    public func captureAndUpload(view: UIView) async -> String? {
        let imageData = await MainActor.run { TritonKitDataUploader.captureScreenshot(view: view) }
        guard let data = imageData else { return nil }
        return try? await upload(data)
    }
}
