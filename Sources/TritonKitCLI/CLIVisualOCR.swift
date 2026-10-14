import ArgumentParser
import CoreGraphics
import Foundation
import ImageIO
import TritonKitShared
import Vision

enum VisualOCRPolicy: String, Codable, ExpressibleByArgument {
    case explicit
    case structureUnavailable = "structure-unavailable"
}

func validateVisualOCRPolicy(_ policy: VisualOCRPolicy, reason: String?) throws {
    if policy == .structureUnavailable, reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
        throw VisualFeedbackError.invalid("structure-unavailable OCR policy requires --structure-unavailable-reason from the structural observation")
    }
}

struct VisualOCRCandidate: Codable {
    let text: String
    let confidence: Double
    let framePixels: TKRect
    let framePoints: TKRect?
    let candidateOnly = true
    let source = "host-vision-ocr"
}

struct VisualOCRCoordinates: Codable {
    let units: String
    let origin: String
    let pixelWidth: Int
    let pixelHeight: Int
    let scale: Double?
    let pointsAvailable: Bool
    let orientationPolicy: String
    let appliedRotationDegrees: Int
    let note: String
}

struct VisualOCROutput: Codable {
    let ok: Bool
    let action: String
    let source: String
    let screenshotSource: String
    let capturedAt: String
    let captureTimeSource: String
    let freshness: String
    let analyzedAt: String
    let policy: VisualOCRPolicy
    let structureUnavailableReason: String?
    let minimumConfidence: Double
    let maxCandidates: Int
    let candidateOnly: Bool
    let coordinates: VisualOCRCoordinates
    let candidates: [VisualOCRCandidate]
    let partial: Bool
    let limits: [String]
    let note: String
}

func visualOCRBounds(normalized: CGRect, pixelWidth: Int, pixelHeight: Int, scale: Double?) throws -> (pixels: TKRect, points: TKRect?) {
    guard pixelWidth > 0, pixelHeight > 0,
          [normalized.minX, normalized.minY, normalized.width, normalized.height].allSatisfy({ $0.isFinite }),
          normalized.minX >= 0, normalized.minY >= 0, normalized.width >= 0, normalized.height >= 0,
          normalized.maxX <= 1, normalized.maxY <= 1 else {
        throw VisualFeedbackError.invalid("OCR bounding box must lie in the normalized screenshot")
    }
    if let scale, !scale.isFinite || scale <= 0 || scale > 16 {
        throw VisualFeedbackError.invalid("OCR scale must be finite, positive and at most 16 pixels per point")
    }
    let pixels = TKRect(x: normalized.minX * Double(pixelWidth),
                        y: (1 - normalized.maxY) * Double(pixelHeight),
                        width: normalized.width * Double(pixelWidth), height: normalized.height * Double(pixelHeight))
    let points = scale.map { TKRect(x: pixels.x / $0, y: pixels.y / $0, width: pixels.width / $0, height: pixels.height / $0) }
    return (pixels, points)
}

func recognizeVisualText(
    data: Data,
    capturedAt: String,
    screenshotSource: String,
    scale: Double? = nil,
    policy: VisualOCRPolicy = .explicit,
    structureUnavailableReason: String? = nil,
    minimumConfidence: Double = 0.5,
    maxCandidates: Int = 200,
    languages: [String] = []
) throws -> VisualOCROutput {
    try validateVisualOCRPolicy(policy, reason: structureUnavailableReason)
    guard minimumConfidence.isFinite, (0...1).contains(minimumConfidence), (1...1000).contains(maxCandidates) else {
        throw VisualFeedbackError.invalid("OCR confidence must be finite within 0...1 and max candidates within 1...1000")
    }
    let (source, width, height) = try visualImageSource(data)
    _ = try visualOCRBounds(normalized: .zero, pixelWidth: width, pixelHeight: height, scale: scale)
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw VisualFeedbackError.invalid("Cannot decode OCR screenshot")
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    if languages.isEmpty { request.automaticallyDetectsLanguage = true }
    else { request.recognitionLanguages = languages }
    // CGImage preserves the supplied raster; do not silently rotate using EXIF/device guesses.
    try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
    let observations = request.results ?? []
    let eligible = observations.compactMap { observation -> (VNRecognizedTextObservation, VNRecognizedText)? in
        guard let candidate = observation.topCandidates(1).first, Double(candidate.confidence) >= minimumConfidence else { return nil }
        return (observation, candidate)
    }
    let candidates = try eligible.prefix(maxCandidates).map { observation, candidate in
        let bounds = try visualOCRBounds(normalized: observation.boundingBox, pixelWidth: width, pixelHeight: height, scale: scale)
        return VisualOCRCandidate(text: candidate.string, confidence: Double(candidate.confidence), framePixels: bounds.pixels, framePoints: bounds.points)
    }
    return VisualOCROutput(
        ok: true, action: "observe.ocr", source: "host-vision-ocr", screenshotSource: screenshotSource,
        capturedAt: capturedAt,
        captureTimeSource: screenshotSource == "image-file-modification-time" ? "file-modification-time-not-capture" : "capture-provider-response-time",
        freshness: screenshotSource == "image-file-modification-time" ? "unknown" : "captured-on-request",
        analyzedAt: ISO8601DateFormatter().string(from: Date()), policy: policy,
        structureUnavailableReason: structureUnavailableReason, minimumConfidence: minimumConfidence, maxCandidates: maxCandidates, candidateOnly: true,
        coordinates: VisualOCRCoordinates(units: "pixels", origin: "top-left", pixelWidth: width, pixelHeight: height,
                                          scale: scale, pointsAvailable: scale != nil, orientationPolicy: "raw-raster",
                                          appliedRotationDegrees: 0,
                                          note: "Points are emitted only with a known or explicitly supplied pixel-per-point scale. No device orientation or viewport offset is inferred."),
        candidates: candidates, partial: eligible.count > maxCandidates,
        limits: eligible.count > maxCandidates ? ["max_candidates"] : [],
        note: "OCR yields screenshot text candidates only. It does not establish visibility, enabled state, semantic identity, lock state or business verification; native Vision execution is not forcibly cancellable."
    )
}
