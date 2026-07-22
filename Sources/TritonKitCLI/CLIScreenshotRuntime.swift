import Foundation

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
