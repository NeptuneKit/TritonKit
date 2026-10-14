import TritonKitShared

func deviceMirrorOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.device-mirror", format: "json", kind: "host-action", model: "DeviceMirrorOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Whether the bounded terminal/file mirror completed without a capture failure"),
        ("action", "String", true, "mirror"),
        ("platform", "String", true, "ios|android|harmony; concrete target pinned once at startup"),
        ("mode", "String", true, "kitty|iterm2|png-files; Kitty/Ghostty use real chunked PNG images, no ASCII substitute"),
        ("frames", "Int", true, "Number of successfully decoded screenshots within fps/timeout/byte/pixel budgets"),
        ("images", "[String]", true, "Private PNG file paths for --frames/--output; interactive mode returns an empty array"),
        ("sourceWidth", "Int", true, "Last source screenshot width in pixels; output images may be resized by --max-size"),
        ("sourceHeight", "Int", true, "Last source screenshot height in pixels; click maps image cells to original pixels and source geometry"),
        ("businessReadinessVerified", "Bool", true, "Always false; screenshot/input submission is not app workflow acceptance")
    ]))
}

func deviceMirrorSubcommandSchemas() -> [TKCommandSubcommandSchema] {
    [TKCommandSubcommandSchema(name: "mirror", summary: "Terminal Kitty/Ghostty/iTerm2 PNG mirror with bounded non-interactive frame capture", optionOverrides: [
        TKCommandSchemaOption(name: "--device", type: "String", description: "Explicit target selector, pinned once at startup"),
        TKCommandSchemaOption(name: "--platform", type: "ios|android|harmony", description: "Host platform adapter"),
        TKCommandSchemaOption(name: "--scope", type: "simulator|emulator|real|all", defaultValue: "all", description: "Target scope"),
        TKCommandSchemaOption(name: "--protocol", type: "auto|kitty|iterm2", defaultValue: "auto", description: "Kitty/Ghostty or iTerm2 image protocol"),
        TKCommandSchemaOption(name: "--fps", type: "Double", defaultValue: "1", description: "Refresh budget 0.1...5"),
        TKCommandSchemaOption(name: "--timeout", type: "Double", defaultValue: "300", description: "Session budget 1...3600 seconds"),
        TKCommandSchemaOption(name: "--frames", type: "Int", description: "Bounded non-interactive frame count 1...100"),
        TKCommandSchemaOption(name: "--output", type: "Path", description: "New private directory for PNG frames"),
        TKCommandSchemaOption(name: "--max-size", type: "Int", defaultValue: "1600", description: "Maximum rendered image dimension"),
        TKCommandSchemaOption(name: "--max-bytes", type: "Int", defaultValue: "16777216", description: "Maximum PNG bytes"),
    ], artifacts: ["private frame PNG files for --frames", "terminal state restored on exit/signal"], outputSelectors: ["frames", "images", "sourceWidth", "sourceHeight", "businessReadinessVerified"], failureCodes: ["device_mirror_failed", "device_not_ready", "unsupported_terminal_protocol"])]
}
func deviceMirrorFailureCodes() -> [String] { ["device_mirror_failed", "device_not_ready", "unsupported_terminal_protocol"] }
