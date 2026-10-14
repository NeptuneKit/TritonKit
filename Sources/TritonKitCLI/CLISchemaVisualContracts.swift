import Foundation
import TritonKitShared

func visualObservationSchemaOptions() -> [TKCommandSchemaOption] {
    [
        .init(name: "ocr", type: "Subcommand", description: "Explicit macOS Vision OCR; candidate-only results"),
        .init(name: "settle", type: "Subcommand", description: "Bounded screenshot stability; never business verification"),
        .init(name: "--image", type: "Path", description: "OCR image file; incompatible with device/runtime selectors"),
        .init(name: "--scope", type: "simulator|emulator", description: "Visual host capture scope; real-device capture is excluded"),
        .init(name: "--scale", type: "Double", description: "OCR pixels per point; unknown scale produces pixel coordinates only"),
        .init(name: "--policy", type: "explicit|structure-unavailable", defaultValue: "explicit", description: "Explicit OCR or caller-evidenced structural fallback"),
        .init(name: "--structure-unavailable-reason", type: "String", description: "Required evidence for structure-unavailable OCR policy"),
        .init(name: "--minimum-confidence", type: "Double", defaultValue: "0.5", description: "OCR confidence filter within 0...1"),
        .init(name: "--max-candidates", type: "Int", defaultValue: "200", description: "OCR candidates within 1...1000"),
        .init(name: "--languages", type: "String", description: "Comma-separated OCR language tags; default automatic detection"),
        .init(name: "--timeout", type: "Double", defaultValue: "5", description: "Visual settle total timeout, or OCR capture timeout; maximum 60 seconds"),
        .init(name: "--change-threshold", type: "Double", defaultValue: "0.01", description: "Maximum changed pixel area fraction"),
        .init(name: "--pixel-threshold", type: "Double", defaultValue: "0.04", description: "RGB pixel difference fraction"),
        .init(name: "--stable-window", type: "Double", defaultValue: "0.5", description: "Consecutive stable window seconds"),
        .init(name: "--interval", type: "Double", defaultValue: "0.1", description: "Visual screenshot sample interval seconds"),
    ]
}

func visualObservationSubcommands() -> [TKCommandSubcommandSchema] {
    let common = ["--device", "--platform", "--scope", "--target", "--host", "--port", "--timeout", "--format", "--json"]
    let structural = ["--device", "--platform", "--target", "--host", "--port", "--hdc", "--runtime-base-url", "--max-nodes", "--output", "--format", "--json"]
    return [
        .init(name: "current", summary: "Current structural surface", optionalOptions: structural, outputSelectors: ["observe.surface"]),
        .init(name: "tree", summary: "Structural tree with optional short-lived aliases", optionalOptions: structural + ["--outline"], outputSelectors: ["observe.surface"]),
        .init(name: "ocr", summary: "Image/target OCR with explicit fallback policy", optionalOptions: common + ["--image", "--scale", "--policy", "--structure-unavailable-reason", "--minimum-confidence", "--max-candidates", "--languages"], outputSelectors: ["observe.ocr"], failureCodes: ["validation_failed", "host_command_failed", "request_failed"]),
        .init(name: "settle", summary: "Visual stability only; unknown or timeout exits nonzero", requiresTarget: true, optionalOptions: common + ["--change-threshold", "--pixel-threshold", "--stable-window", "--interval"], outputSelectors: ["observe.settle"], failureCodes: ["validation_failed", "screenshot_provider_unavailable", "screenshot_unavailable", "visual_motion_timeout", "screenshot_deadline_exceeded", "insufficient_visual_samples"]),
    ]
}

func visualOCROutputContract() -> TKCommandOutputContract {
    .init(selector: "observe.ocr", format: "json", kind: "ocr-candidates", model: "VisualOCROutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Whether OCR completed; no action is dispatched"),
        ("action", "String", true, "observe.ocr"),
        ("source", "String", true, "host-vision-ocr"),
        ("screenshotSource", "String", true, "Screenshot provider or file modification time source"),
        ("capturedAt", "String", true, "Provider response time or file mtime; see captureTimeSource"),
        ("captureTimeSource", "String", true, "File mtime is not capture time"),
        ("freshness", "String", true, "captured-on-request or unknown"),
        ("analyzedAt", "String", true, "OCR analysis completion time"),
        ("policy", "String", true, "explicit or structure-unavailable"),
        ("structureUnavailableReason", "String?", false, "Caller-supplied structural failure evidence"),
        ("candidateOnly", "Bool", true, "Always true; never an OID or action reference"),
        ("coordinates", "VisualOCRCoordinates", true, "Raw-raster top-left pixels; points only with known scale"),
        ("coordinates.scale", "Double?", false, "Pixels per point; never inferred from model name"),
        ("coordinates.orientationPolicy", "String", true, "raw-raster; no inferred rotation or viewport offset"),
        ("candidates", "[VisualOCRCandidate]", true, "Confidence-filtered OCR text candidates"),
        ("candidates[].text", "String", true, "Recognized text"),
        ("candidates[].confidence", "Double", true, "Vision recognition confidence"),
        ("candidates[].framePixels", "TKRect", true, "Bounding box in top-left raster pixels"),
        ("candidates[].framePoints", "TKRect?", false, "Bounding box with explicit/known pixel-per-point scale"),
        ("minimumConfidence", "Double", true, "Applied confidence threshold"),
        ("maxCandidates", "Int", true, "Applied candidate count budget"),
        ("partial", "Bool", true, "Candidate count limit was reached"),
        ("limits", "[String]", true, "Applied collection limits"),
        ("note", "String", true, "OCR provenance and action limitations"),
    ]))
}

func visualSettleOutputContract() -> TKCommandOutputContract {
    .init(selector: "observe.settle", format: "json", kind: "visual-settle", model: "VisualSettleOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "True only when sampled stability is established"),
        ("action", "String", true, "observe.settle"),
        ("state", "String", true, "settled, timeout, or unknown"),
        ("reason", "String", true, "Stable diagnostic reason; no screenshot contents"),
        ("businessVerified", "Bool", true, "Always false; explicit business assertions remain required"),
        ("elapsedMs", "Int", true, "Elapsed observation time"),
        ("sampleCount", "Int", true, "Actual screenshot samples"),
        ("lastChangeFraction", "Double?", false, "Changed RGB pixel area on bounded thumbnails"),
        ("capturedAt", "String?", false, "Most recent screenshot response timestamp"),
        ("source", "String?", false, "Screenshot provider provenance"),
        ("configuration", "VisualSettleConfiguration", true, "Applied finite timeout, interval, window and thresholds"),
        ("comparisonPolicy", "String", true, "Approximate comparison policy; no business, lock or occlusion inference"),
    ]))
}
