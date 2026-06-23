import Foundation

func writePageMapIfReady(_ contract: TKTestRecorderCompiledContract?, caseURL: URL) throws -> TKTestRecorderContractArtifact? {
    guard let contract, !contract.pages.routes.isEmpty || !contract.pages.fingerprints.isEmpty else {
        return nil
    }
    let pageMap = buildPageMap(from: contract)
    let outputURL = caseURL
        .appendingPathComponent("pages", isDirectory: true)
        .appendingPathComponent("page-map.json")
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(pageMap)
    try data.write(to: outputURL, options: .atomic)
    return TKTestRecorderContractArtifact(
        path: "pages/page-map.json",
        absolutePath: outputURL.path,
        contentType: "application/json",
        written: true,
        byteCount: data.count
    )
}

func buildPageMap(from contract: TKTestRecorderCompiledContract) -> TKTestRecorderPageMap {
    var pagesByID: [String: TKTestRecorderPageMapEntry] = [:]
    var orderedIDs: [String] = []

    for route in contract.pages.routes {
        let id = pageMapID(pageId: nil, route: route.route, url: route.url, fallback: route.id ?? "route-\(route.index)")
        if pagesByID[id] == nil {
            orderedIDs.append(id)
        }
        pagesByID[id] = TKTestRecorderPageMapEntry(
            index: orderedIDs.firstIndex(of: id).map { $0 + 1 } ?? orderedIDs.count,
            id: id,
            route: route.route,
            url: route.url,
            routeSourcePath: route.sourcePath,
            fingerprintSourcePath: pagesByID[id]?.fingerprintSourcePath,
            fingerprintHash: pagesByID[id]?.fingerprintHash,
            evidence: pageMapEvidence(routeSourcePath: route.sourcePath, fingerprintSourcePath: pagesByID[id]?.fingerprintSourcePath, fingerprintHash: pagesByID[id]?.fingerprintHash)
        )
    }

    for fingerprint in contract.pages.fingerprints {
        let id = pageMapID(pageId: fingerprint.pageId, route: fingerprint.route, url: nil, fallback: "fingerprint-\(fingerprint.index)")
        if pagesByID[id] == nil {
            orderedIDs.append(id)
        }
        let existing = pagesByID[id]
        pagesByID[id] = TKTestRecorderPageMapEntry(
            index: orderedIDs.firstIndex(of: id).map { $0 + 1 } ?? orderedIDs.count,
            id: id,
            route: existing?.route ?? fingerprint.route,
            url: existing?.url,
            routeSourcePath: existing?.routeSourcePath,
            fingerprintSourcePath: fingerprint.sourcePath,
            fingerprintHash: fingerprint.hash,
            evidence: pageMapEvidence(routeSourcePath: existing?.routeSourcePath, fingerprintSourcePath: fingerprint.sourcePath, fingerprintHash: fingerprint.hash)
        )
    }

    let pages = orderedIDs.compactMap { pagesByID[$0] }
    return TKTestRecorderPageMap(
        schemaVersion: 1,
        kind: "triton.testrec.page-map",
        matchPolicy: contract.pages.matchPolicy,
        pages: pages
    )
}

private func pageMapID(pageId: String?, route: String?, url: String?, fallback: String) -> String {
    for value in [pageId, route, url] {
        if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            return value
        }
    }
    return fallback
}

private func pageMapEvidence(routeSourcePath: String?, fingerprintSourcePath: String?, fingerprintHash: String?) -> [String] {
    var evidence: [String] = []
    if routeSourcePath != nil {
        evidence.append("route")
    }
    if fingerprintSourcePath != nil {
        evidence.append("fingerprint")
    }
    if fingerprintHash != nil {
        evidence.append("fingerprint-hash")
    }
    return evidence
}
