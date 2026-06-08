import Foundation
import TritonKitShared

struct TritonKitHTTPClient {
    let host: String
    let port: Int
    var target: String? = nil

    func getData(_ path: String) async throws -> Data {
        try await data(for: URLRequest(url: url(path)))
    }

    func getJSON<T: Decodable>(_ path: String) async throws -> T {
        let data = try await getData(path)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func latestHierarchyData() async throws -> Data {
        try await data(for: URLRequest(url: url(path: "/hierarchy/latest", queryItems: targetQueryItems())))
    }

    func postJSON<Request: Encodable, Response: Decodable>(_ path: String, body: Request) async throws -> Response {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await data(for: request)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func sendCommand(_ type: String) async throws {
        let _: TKCLICommandResponse = try await postJSON("/command", body: TKCLICommandRequest(type: type, target: target))
    }

    func request(type: String, payload: Data? = nil, target explicitTarget: String? = nil) async throws -> Data {
        try await postRawJSON("/request", body: TKCLICommandRequest(
            type: type,
            payload: payload,
            target: explicitTarget ?? target
        ))
    }

    private func url(_ path: String) -> URL {
        url(path: path, queryItems: [])
    }

    private func url(path: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url!
    }

    private func targetQueryItems() -> [URLQueryItem] {
        target.map { [URLQueryItem(name: "target", value: $0)] } ?? []
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RuntimeError("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CLIHTTPError(statusCode: http.statusCode, data: data)
        }
        return data
    }

    private func postRawJSON<Request: Encodable>(_ path: String, body: Request) async throws -> Data {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await data(for: request)
    }
}

struct EmbeddedRuntimeHTTPClient {
    let baseURL: URL

    init(baseURL: String) throws {
        guard let url = URL(string: baseURL), url.scheme != nil, url.host != nil else {
            throw RuntimeError("Invalid embedded runtime base URL: \(baseURL)")
        }
        self.baseURL = url
    }

    func request(_ requestType: TKRequestType, queryItems: [URLQueryItem] = [], body: Data? = nil) async throws -> Data {
        guard let route = TKEmbeddedRuntimeHTTPRoute.route(for: requestType) else {
            throw RuntimeError("Unsupported embedded runtime HTTP request: \(requestType.rawValue)")
        }

        var request = URLRequest(url: try url(path: route.path, queryItems: queryItems))
        request.httpMethod = route.method.rawValue
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return try await data(for: request)
    }

    private func url(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard let routeURL = URL(string: path, relativeTo: baseURL)?.absoluteURL,
              var components = URLComponents(url: routeURL, resolvingAgainstBaseURL: false) else {
            throw RuntimeError("Invalid embedded runtime route: \(path)")
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw RuntimeError("Invalid embedded runtime URL: \(path)")
        }
        return url
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RuntimeError("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CLIHTTPError(statusCode: http.statusCode, data: data)
        }
        return data
    }
}
