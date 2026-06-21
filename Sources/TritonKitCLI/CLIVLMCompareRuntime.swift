import AppKit
import Foundation
import TritonKitShared

func compareVLMProviders(
    image imagePath: String,
    target: String,
    coordinateContract: String,
    providers: [String],
    outputDirectory: String?,
    agreementThresholdPoints: Double = 24,
    baseURL: String? = nil,
    model: String? = nil,
    modelPath: String? = nil,
    apiKeyEnv: String? = nil,
    allowRemoteVLM: Bool = false,
    maxTokens: Int = 64,
    temperature: Double = 0,
    seed: Int = 0,
    promptTemplate: String = "gui-grounding-v1",
    allowModelDownload: Bool = false
) throws -> TKVLMCompareResponse {
    let selectedProviders = providers.isEmpty ? ["mock"] : providers
    let imageURL = URL(fileURLWithPath: imagePath)
    let image = try loadVLMImage(path: imageURL.path)
    let outputURL = outputDirectory.map(URL.init(fileURLWithPath:)) ??
        imageURL.deletingLastPathComponent().appendingPathComponent("vlm-compare", isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    var results: [TKVLMCompareProviderResult] = []
    for provider in selectedProviders {
        let started = Date()
        let providerOutput = outputURL.appendingPathComponent(vlmCompareSlug(provider), isDirectory: true)
        do {
            let grounding = try groundVLMTarget(
                provider: provider,
                image: imagePath,
                target: target,
                coordinateContract: coordinateContract,
                outputDirectory: providerOutput.path,
                baseURL: baseURL,
                model: model,
                modelPath: modelPath,
                apiKeyEnv: apiKeyEnv,
                allowRemoteVLM: allowRemoteVLM,
                maxTokens: maxTokens,
                temperature: temperature,
                seed: seed,
                promptTemplate: promptTemplate,
                allowModelDownload: allowModelDownload
            )
            results.append(TKVLMCompareProviderResult(
                provider: provider,
                status: "passed",
                model: grounding.model,
                runtimePoint: grounding.point.runtimePoint,
                latencyMs: vlmCompareElapsedMilliseconds(since: started),
                artifacts: grounding.artifacts
            ))
        } catch let failure as TKVLMGroundingFailure {
            results.append(TKVLMCompareProviderResult(
                provider: provider,
                status: "failed",
                latencyMs: vlmCompareElapsedMilliseconds(since: started),
                errorCode: failure.code,
                message: failure.message
            ))
        } catch {
            results.append(TKVLMCompareProviderResult(
                provider: provider,
                status: "failed",
                latencyMs: vlmCompareElapsedMilliseconds(since: started),
                errorCode: "vlm_grounding_failed",
                message: "\(error)"
            ))
        }
    }

    let agreement = compareAgreement(results: results, threshold: agreementThresholdPoints)
    let overlayURL = outputURL.appendingPathComponent("compare-overlay.png")
    try writeVLMCompareOverlay(imageURL: imageURL, outputURL: overlayURL, target: target, results: results)
    let resultsURL = outputURL.appendingPathComponent("compare-results.json")
    let artifacts = TKVLMCompareArtifacts(comparisonOverlay: overlayURL.path, results: resultsURL.path)
    let response = TKVLMCompareResponse(
        target: target,
        image: image,
        results: results,
        agreement: agreement,
        artifacts: artifacts
    )
    try writeVLMJSON(response, to: resultsURL)
    return response
}

private func vlmCompareElapsedMilliseconds(since start: Date) -> Int {
    max(0, Int(Date().timeIntervalSince(start) * 1_000))
}

private func vlmCompareSlug(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics
    let characters = value.lowercased().unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let collapsed = String(characters).split(separator: "-").joined(separator: "-")
    return collapsed.isEmpty ? "provider" : collapsed
}

private func compareAgreement(results: [TKVLMCompareProviderResult], threshold: Double) -> TKVLMCompareAgreement {
    let points = results.compactMap(\.runtimePoint)
    let distances = pairwiseDistances(points)
    let maxDistance = distances.max()
    let meanDistance = distances.isEmpty ? nil : distances.reduce(0, +) / Double(distances.count)
    return TKVLMCompareAgreement(
        maxDistancePoints: maxDistance,
        meanDistancePoints: meanDistance,
        withinThreshold: (maxDistance ?? 0) <= threshold,
        thresholdPoints: threshold,
        passedProviderCount: results.filter { $0.status == "passed" }.count,
        failedProviderCount: results.filter { $0.status != "passed" }.count
    )
}

private func pairwiseDistances(_ points: [TKVLMRuntimePoint]) -> [Double] {
    guard points.count > 1 else { return [] }
    var distances: [Double] = []
    for i in 0..<(points.count - 1) {
        for j in (i + 1)..<points.count {
            let dx = points[i].x - points[j].x
            let dy = points[i].y - points[j].y
            distances.append((dx * dx + dy * dy).squareRoot())
        }
    }
    return distances
}

private func writeVLMCompareOverlay(
    imageURL: URL,
    outputURL: URL,
    target: String,
    results: [TKVLMCompareProviderResult]
) throws {
    guard let image = NSImage(contentsOf: imageURL) else {
        throw TKVLMGroundingFailure(code: "vlm_overlay_failed", message: "Could not load image for compare overlay", hint: nil)
    }
    let size = image.size
    let canvas = NSImage(size: size)
    canvas.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: size))
    let colors: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink]
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    for (index, result) in results.enumerated() {
        guard let point = result.runtimePoint else { continue }
        let color = colors[index % colors.count]
        color.setStroke()
        color.setFill()
        let marker = NSRect(x: point.x - 5, y: size.height - point.y - 5, width: 10, height: 10)
        NSBezierPath(ovalIn: marker).fill()
        let label = "\(result.provider)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        label.draw(at: NSPoint(x: min(point.x + 8, size.width - 120), y: max(size.height - point.y - 16, 4)), withAttributes: attrs)
    }
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor.white,
        .backgroundColor: NSColor.black.withAlphaComponent(0.55),
    ]
    "target: \(target)".draw(at: NSPoint(x: 8, y: size.height - 22), withAttributes: titleAttrs)
    canvas.unlockFocus()
    guard let tiff = canvas.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw TKVLMGroundingFailure(code: "vlm_overlay_failed", message: "Could not encode compare overlay PNG", hint: nil)
    }
    try png.write(to: outputURL, options: .atomic)
}
