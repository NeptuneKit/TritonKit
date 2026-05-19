import Foundation

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
        guard TritonKit.isRuntimeEnabled else {
            throw TritonKitRuntimeError.disabledOutsideDebug
        }

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
}
