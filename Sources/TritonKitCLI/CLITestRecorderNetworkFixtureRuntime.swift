import Foundation

func writeTestRecorderNetworkFixturesIfNeeded(
    for requests: [TKTestRecorderCompiledNetworkRequest],
    caseURL: URL
) throws -> [Int: String] {
    let fixtureDirectory = caseURL.appendingPathComponent("network/fixtures", isDirectory: true)
    var paths: [Int: String] = [:]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    for request in requests {
        guard let body = request.responseBody, !body.isEmpty else { continue }
        guard !isTransientNetworkURL(request.url ?? "") else { continue }

        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        let fileName = "\(networkFixtureID(for: request)).json"
        let relativePath = "network/fixtures/\(fileName)"
        let fixtureURL = caseURL.appendingPathComponent(relativePath)
        var fixture: [String: String] = [
            "id": request.id ?? "network-\(request.index)",
            "method": request.method ?? "",
            "url": request.url ?? "",
            "body": redactTestRecorderNetworkFixtureBody(body),
            "redaction": "deterministic-sensitive-token-redaction-v1",
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

private func redactTestRecorderNetworkFixtureBody(_ body: String) -> String {
    var redacted = body
    redacted = redacted.replacingTestRecorderRegex(
        #"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        template: "<redacted:email>"
    )
    redacted = redacted.replacingTestRecorderRegex(
        #"(?i)(token=)[^\s&]+"#,
        template: "$1<redacted:token>"
    )
    redacted = redacted.replacingTestRecorderRegex(
        #"(?i)(\"token\"\s*:\s*\")[^\"]+"#,
        template: "$1<redacted:token>"
    )
    redacted = redacted.replacingTestRecorderRegex(
        #"(?i)(authorization=Bearer\s+)[^\s&]+"#,
        template: "$1<redacted:token>"
    )
    return redacted
}

private extension String {
    func replacingTestRecorderRegex(_ pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }
        let range = NSRange(startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: template)
    }
}
