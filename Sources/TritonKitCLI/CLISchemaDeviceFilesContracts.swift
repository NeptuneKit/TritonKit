#if os(macOS)
import TritonKitShared

func hostDeviceFilesOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.device-files", format: "json", kind: "host-action", model: "HostDeviceFilesOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "All requested metadata parsed and matched; no partial success"),
        ("action", "String", true, "device.files"),
        ("runtimeScope", "String", true, "host-device; no Run/server required"),
        ("riskLevel", "String", true, "readonly; excludes temporary namespace creation/copy/write"),
        ("target", "HostDeviceTarget", true, "Canonical/redacted device; raw aliases private"),
        ("domain", "String", true, "Selected domain bound to file JSON"),
        ("recursive", "Bool", true, "Always false; explicit --no-recurse"),
        ("sensitiveMetadataIncluded", "Bool", true, "Explicit name/relative-path opt-in, never file contents/raw IDs"),
        ("entries", "[HostDeviceFileEntryOutput]", true, "White-listed shallow metadata, token/kind/sizeBytes/modifiedAt/isHidden/isReadable; non-directory is not guaranteed regular file"),
        ("entries[].token", "String", true, "Stable correlation hash, not an authorization or content/path disclosure"),
        ("entries[].name", "String?", false, "Only with include-sensitive; private filename"),
        ("entries[].relativePath", "String?", false, "Only with include-sensitive; validated domain-relative path"),
        ("count", "Int", true, "Accepted entry count; no silent truncation"),
        ("maximumJSONBytes", "Int", true, "Local JSON acceptance byte bound"),
        ("maximumEntries", "Int", true, "Local metadata acceptance count bound"),
        ("limitSemantics", "String", true, "Not a remote traversal, transport or disk hard limit"),
        ("sourceCommands", "[String]", true, "Producer commands with device/domain identifier/directory/username redacted"),
        ("artifacts", "[String]", true, "Private 0700/0600 file JSON/log paths; no automatic evidence publication"),
        ("verification", "String", true, "executed-file-json, not help or content verification"),
        ("businessReadinessVerified", "Bool", true, "Always false; isWritable not output and not write authorization"),
    ]))
}
#endif
