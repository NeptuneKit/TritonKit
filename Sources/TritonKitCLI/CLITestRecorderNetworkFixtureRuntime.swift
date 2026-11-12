import Foundation

func writeTestRecorderNetworkFixturesIfNeeded(
    for requests: [TKTestRecorderCompiledNetworkRequest],
    caseURL: URL
) throws -> [Int: String] {
    let fixtureDirectory = caseURL.appendingPathComponent("network/fixtures", isDirectory: true)
    var paths: [Int: String] = [:]
    var allocated: Set<String> = []
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    for request in requests {
        guard let body = request.responseBody else { continue }

        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        let base = networkFixtureID(for: request)
        var fileName = "\(base).json"
        var collision = 0
        while allocated.contains(fileName) {
            collision += 1
            fileName = "\(base)-\(request.index)-\(collision).json"
        }
        allocated.insert(fileName)
        let relativePath = "network/fixtures/\(fileName)"
        let fixtureURL = caseURL.appendingPathComponent(relativePath)
        var fixture: [String: String] = [
            "id": request.id ?? "network-\(request.index)",
            "method": request.method ?? "",
            "url": request.url ?? "",
            "body": body,
            "redaction": "none",
            "sourcePath": request.sourcePath,
        ]
        if let statusCode = request.statusCode {
            fixture["statusCode"] = String(statusCode)
        }
        let data = try encoder.encode(fixture)
        try data.write(to: fixtureURL, options: .atomic)
        paths[request.index] = relativePath
    }

    return paths
}

private func networkFixtureID(for request: TKTestRecorderCompiledNetworkRequest) -> String {
    let raw = request.id ?? "network-\(request.index)"
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let sanitized = raw.unicodeScalars.map { scalar in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let value = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    return value.isEmpty ? "network-\(request.index)" : value
}
