import Foundation
import TritonKitShared

func matchTritonTestCasePageFingerprint(path: String, page: String, candidateJSON: String) throws -> TKTestRecorderFingerprintMatchResponse {
    let candidateValue = try decodeTestRecorderCandidateJSON(candidateJSON)
    return try matchTritonTestCasePageFingerprint(path: path, page: page, candidate: candidateValue)
}

func matchTritonTestCasePageFingerprint(path: String, page: String, candidate: TKJSONValue) throws -> TKTestRecorderFingerprintMatchResponse {
    let caseURL = URL(fileURLWithPath: path, isDirectory: true)
    guard let compiled = try readCompiledContractForReplay(caseURL: caseURL) else {
        throw testRecorderValidationFailure(
            code: "missing_compiled_contract",
            message: "Page fingerprint matching requires compiled-contract.json.",
            path: "compiled-contract.json",
            hint: "Run triton testrec compile <case.tritontestcase> --json first."
        )
    }

    guard let source = compiled.contract.pages.fingerprints.first(where: { fingerprint in
        fingerprint.pageId == page || fingerprint.route == page || String(fingerprint.index) == page
    }) else {
        throw testRecorderValidationFailure(
            code: "source_fingerprint_not_found",
            message: "No compiled page fingerprint matched page '\(page)'.",
            path: "compiled-contract.json.pages.fingerprints",
            hint: "Use a pageId, route, or fingerprint index from compiled-contract.json."
        )
    }

    let subject = fingerprintSubject(from: candidate)
    let policy = compiled.contract.pages.matchPolicy
    let components = fingerprintMatchComponents(source: source, candidate: subject)
    let score = roundedScore(components.reduce(0) { $0 + ($1.weight * $1.score) })
    let evidence = fingerprintMatchEvidence(source: source, candidate: subject, components: components)
    return TKTestRecorderFingerprintMatchResponse(
        path: caseURL.path,
        page: page,
        source: source,
        candidate: subject,
        policy: policy,
        score: score,
        decision: fingerprintDecision(score: score, policy: policy),
        components: components,
        evidence: evidence
    )
}

func handleTestRecorderHTTPMatchPage(body: Data) throws -> TKTestRecorderFingerprintMatchResponse {
    let request = try decodeTestRecorderHTTPJSON(
        TKTestRecorderHTTPPageMatchRequest.self,
        from: body,
        endpoint: "/v1/test-recorder/cases/match-page"
    )
    guard !request.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !request.page.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw testRecorderValidationFailure(
            code: "invalid_payload",
            message: "Test recorder page match payload requires path and page.",
            path: "$",
            hint: #"Send JSON like {"path":"/tmp/login.tritontestcase","page":"login","candidate":{"route":"login","hash":"..."}}."#
        )
    }
    return try matchTritonTestCasePageFingerprint(
        path: request.path,
        page: request.page,
        candidate: request.candidate
    )
}

private func decodeTestRecorderCandidateJSON(_ candidateJSON: String) throws -> TKJSONValue {
    do {
        let data = Data(candidateJSON.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard JSONSerialization.isValidJSONObject(object), object is [String: Any] else {
            throw testRecorderValidationFailure(
                code: "invalid_json",
                message: "--candidate-json must be a JSON object.",
                path: "--candidate-json",
                hint: "Pass the observed target-side page fingerprint object."
            )
        }
        return try TKJSONValue.fromJSONObject(object)
    } catch let failure as TKTestRecorderValidationFailure {
        throw failure
    } catch {
        throw testRecorderValidationFailure(
            code: "invalid_json",
            message: "Could not decode --candidate-json: \(error)",
            path: "--candidate-json",
            hint: "Pass a valid JSON object with pageId, route, kind, and hash fields."
        )
    }
}

private func fingerprintSubject(from value: TKJSONValue) -> TKTestRecorderFingerprintMatchSubject {
    let object = jsonObject(value) ?? [:]
    let nested = object["fingerprint"].flatMap(jsonObject) ?? object
    return TKTestRecorderFingerprintMatchSubject(
        pageId: firstString(in: nested, keys: ["pageId", "pageID", "id"]),
        route: firstString(in: nested, keys: ["route", "path", "url"]),
        kind: firstString(in: nested, keys: ["kind", "type", "source"]),
        hash: firstString(in: nested, keys: ["hash", "fingerprintHash", "signature"])
    )
}

private func fingerprintMatchComponents(source: TKTestRecorderCompiledPageFingerprint, candidate: TKTestRecorderFingerprintMatchSubject) -> [TKTestRecorderFingerprintMatchComponent] {
    [
        fingerprintComponent(
            name: "hash",
            weight: 0.40,
            source: source.hash,
            candidate: candidate.hash,
            matchEvidence: "same hash",
            missingEvidence: "source or candidate hash missing",
            mismatchEvidence: "hash differs"
        ),
        fingerprintComponent(
            name: "route",
            weight: 0.25,
            source: source.route,
            candidate: candidate.route,
            matchEvidence: "same route",
            missingEvidence: "source or candidate route missing",
            mismatchEvidence: "route differs"
        ),
        fingerprintComponent(
            name: "pageId",
            weight: 0.20,
            source: source.pageId,
            candidate: candidate.pageId,
            matchEvidence: "same pageId",
            missingEvidence: "source or candidate pageId missing",
            mismatchEvidence: "pageId differs"
        ),
        fingerprintComponent(
            name: "kind",
            weight: 0.15,
            source: source.kind,
            candidate: candidate.kind,
            matchEvidence: "same fingerprint kind",
            missingEvidence: "source or candidate kind missing",
            mismatchEvidence: "fingerprint kind differs"
        ),
    ]
}

private func fingerprintComponent(name: String, weight: Double, source: String?, candidate: String?, matchEvidence: String, missingEvidence: String, mismatchEvidence: String) -> TKTestRecorderFingerprintMatchComponent {
    let normalizedSource = normalizeFingerprintValue(source)
    let normalizedCandidate = normalizeFingerprintValue(candidate)
    let score: Double
    let evidence: String
    if let normalizedSource, let normalizedCandidate {
        score = normalizedSource == normalizedCandidate ? 1.0 : 0.0
        evidence = normalizedSource == normalizedCandidate ? matchEvidence : mismatchEvidence
    } else {
        score = 0.0
        evidence = missingEvidence
    }
    return TKTestRecorderFingerprintMatchComponent(
        name: name,
        weight: weight,
        score: score,
        evidence: evidence
    )
}

private func fingerprintDecision(score: Double, policy: TKTestRecorderFingerprintMatchPolicy) -> String {
    if score >= policy.thresholds.matched {
        return "matched"
    }
    if score >= policy.thresholds.assistedMatched {
        return "assisted-matched"
    }
    if score >= policy.thresholds.needsReview {
        return "needs-review"
    }
    return "not-matched"
}

private func fingerprintMatchEvidence(source: TKTestRecorderCompiledPageFingerprint, candidate: TKTestRecorderFingerprintMatchSubject, components: [TKTestRecorderFingerprintMatchComponent]) -> [String] {
    var evidence = components.map { "\($0.name):\($0.evidence)" }
    if source.hash == nil || candidate.hash == nil {
        evidence.append("required-element-gate:hash evidence unavailable")
    }
    evidence.append("llm:unused")
    evidence.append("llm-decision-authority:false")
    return evidence
}

private func normalizeFingerprintValue(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }
    return value.lowercased()
}

private func roundedScore(_ score: Double) -> Double {
    (score * 10000).rounded() / 10000
}

private func firstString(in object: [String: TKJSONValue], keys: [String]) -> String? {
    for key in keys {
        if let value = object[key], let string = jsonString(value), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return string
        }
    }
    return nil
}

private func jsonObject(_ value: TKJSONValue) -> [String: TKJSONValue]? {
    if case let .object(object) = value {
        return object
    }
    return nil
}

private func jsonString(_ value: TKJSONValue) -> String? {
    switch value {
    case let .string(value):
        return value
    case let .int(value):
        return String(value)
    case let .double(value):
        return String(value)
    default:
        return nil
    }
}
