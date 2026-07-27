import CoreGraphics
import Foundation
import ImageIO

struct RuntimeScreenshotArtifactError: Error, CustomStringConvertible {
    let declaredFormat: String
    let detectedFormat: String
    let outputExtension: String

    var description: String {
        let declared = declaredFormat.isEmpty ? "UNKNOWN" : declaredFormat.uppercased()
        let detected = detectedFormat.isEmpty ? "UNKNOWN" : detectedFormat.uppercased()
        if outputExtension.isEmpty {
            return "Screenshot payload format mismatch: the embedded runtime declared \(declared) and returned \(detected) bytes."
        }
        return "Screenshot artifact format mismatch: output .\(outputExtension.lowercased()) requires PNG, but the embedded runtime declared \(declared) and returned \(detected) bytes."
    }
}

struct RuntimeScreenshotNormalizationError: Error, CustomStringConvertible {
    let sourceFormat: String
    let reason: String

    var description: String {
        "Unable to normalize embedded runtime \(sourceFormat.uppercased()) screenshot to PNG: \(reason)"
    }
}

/// Produces the actual PNG bytes required by every embedded-runtime screenshot artifact.
///
/// Current runtimes emit PNG. Older runtimes may still declare and return JPEG; decode those
/// payloads rather than writing JPEG bytes behind a `.png` filename. The existing artifact
/// validator remains strict so callers that miss this boundary cannot publish a disguised file.
func normalizeRuntimeScreenshotToPNG(
    _ data: Data,
    declaredFormat: String,
    outputPath: String
) throws -> Data {
    let detectedFormat = try validateRuntimeScreenshotPayload(data, declaredFormat: declaredFormat)
    let outputExtension = URL(fileURLWithPath: outputPath).pathExtension.lowercased()
    guard outputExtension == "png" else {
        throw RuntimeScreenshotArtifactError(
            declaredFormat: declaredFormat.lowercased(),
            detectedFormat: detectedFormat,
            outputExtension: outputExtension
        )
    }

    if detectedFormat == "png" {
        _ = try validateRuntimeScreenshotArtifact(
            data,
            declaredFormat: declaredFormat,
            outputPath: outputPath
        )
        return data
    }

    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw RuntimeScreenshotNormalizationError(
            sourceFormat: detectedFormat,
            reason: "the payload could not be decoded"
        )
    }

    let normalized = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        normalized as CFMutableData,
        "public.png" as CFString,
        1,
        nil
    ) else {
        throw RuntimeScreenshotNormalizationError(
            sourceFormat: detectedFormat,
            reason: "the PNG encoder could not be created"
        )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw RuntimeScreenshotNormalizationError(
            sourceFormat: detectedFormat,
            reason: "the PNG encoder could not finalize the image"
        )
    }

    let pngData = normalized as Data
    _ = try validateRuntimeScreenshotArtifact(
        pngData,
        declaredFormat: "png",
        outputPath: outputPath
    )
    return pngData
}

func validateRuntimeScreenshotArtifact(
    _ data: Data,
    declaredFormat: String,
    outputPath: String
) throws -> String {
    let detectedFormat = try validateRuntimeScreenshotPayload(data, declaredFormat: declaredFormat)
    let outputExtension = URL(fileURLWithPath: outputPath).pathExtension.lowercased()
    guard outputExtension == "png", detectedFormat == "png" else {
        throw RuntimeScreenshotArtifactError(
            declaredFormat: declaredFormat.lowercased(),
            detectedFormat: detectedFormat,
            outputExtension: outputExtension
        )
    }
    return "png"
}

func validateRuntimeScreenshotPayload(_ data: Data, declaredFormat: String) throws -> String {
    let normalizedDeclaredFormat: String
    switch declaredFormat.lowercased() {
    case "jpg", "jpeg":
        normalizedDeclaredFormat = "jpeg"
    default:
        normalizedDeclaredFormat = declaredFormat.lowercased()
    }

    let detectedFormat: String
    if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
        detectedFormat = "png"
    } else if data.starts(with: [0xFF, 0xD8, 0xFF]) {
        detectedFormat = "jpeg"
    } else {
        detectedFormat = "unknown"
    }

    guard normalizedDeclaredFormat == detectedFormat,
          detectedFormat == "png" || detectedFormat == "jpeg" else {
        throw RuntimeScreenshotArtifactError(
            declaredFormat: normalizedDeclaredFormat,
            detectedFormat: detectedFormat,
            outputExtension: ""
        )
    }
    return detectedFormat
}
