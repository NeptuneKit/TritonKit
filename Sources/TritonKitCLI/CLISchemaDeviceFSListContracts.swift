import TritonKitShared

func hostDeviceFSListOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.device-fs-list", format: "json", kind: "host-action", model: "HostDeviceFSListOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Accepted identity-bound directory metadata only; no contents or business postcondition"),
        ("action", "String", true, "device.fs.list"),
        ("runtimeScope", "String", true, "host-device; standalone/no required server"),
        ("riskLevel", "String", true, "readonly; CoreDevice service/host descriptor and private artifact side effects remain"),
        ("backend", "String", true, "devicefs; explicit independent backend, never files-error fallback"),
        ("view", "String", true, "mount-root (default)|app-data-containers|app-group-containers; fixed namespace or explicit bounded container-relative selected directory shallow metadata, not verified bundle/group identity/outside-container/crash/Temporary-domain navigation"),
        ("directoryToken", "String", false, "Only with explicit container; hashes exact view/container/optional subdirectory bytes. Omitted subdirectory keeps old scope tokens. No authorization/secrecy/identity proof; requested scope fields private, opt-in leaf names may coincide."),
        ("target", "HostDeviceTarget", true, "Redacted stable device selector; aliases/raw physical ID private"),
        ("mountpointToken", "String", true, "devicefs hash correlation; not path, authorization or secrecy guarantee"),
        ("entries", "[HostDeviceFileEntryOutput]", true, "file token/kind/regular size only; name opt-in, no owners/xattrs/link target/content"),
        ("count", "Int", true, "Accepted shallow entries; never silently truncate"),
        ("sensitiveMetadataIncluded", "Bool", true, "Explicit include-sensitive admits entry names only"),
        ("maximumJSONBytes", "Int", true, "Local mountpoint JSON acceptance bytes"),
        ("maximumEntries", "Int", true, "Local entry acceptance 1...10000"),
        ("recursive", "Bool", true, "false"),
        ("hostFilesystemInspected", "Bool", true, "true; same-FD owner-bound nofollow shallow metadata"),
        ("contentsRead", "Bool", true, "false; no content or symlink target opened"),
        ("mountStateVerified", "Bool", true, "false; no CoreDevice mount provenance proof"),
        ("readWriteAuthorizationVerified", "Bool", true, "false; metadata is not write authorization"),
        ("businessReadinessVerified", "Bool", true, "false; no auto boot/pair/unlock"),
        ("entryIdentityVerification", "String", true, "Same-directory nofollow double-stat inode/device/kind; native fstatfs devicefs type only admits non-comparable synthetic dirent IDs, other filesystem dirent IDs remain checked. Not atomic snapshot/mount provenance."),
        ("verification", "String", true, "executed-file-json-and-descriptor-metadata"),
        ("limitSemantics", "String", true, "Local acceptance only; query timeout is not FUSE deadline, remote hard limit or atomic snapshot"),
        ("sourceCommands", "[String]", true, "Producer mountpoint command; device redacted; not backend stdout"),
        ("artifacts", "[String]", true, "Private0700/0600 file-JSON/log refs; nativepath stays private"),
    ]))
}
