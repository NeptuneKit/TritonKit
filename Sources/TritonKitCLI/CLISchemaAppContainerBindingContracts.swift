import TritonKitShared

func hostAppContainerBindingOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.app-container-binding", format: "json", kind: "host-action", model: "HostAppContainerBindingOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Accepted metadata query; unavailable binding is explicit, never directory-name guessing"),
        ("action", "String", true, "device.containers"),
        ("runtimeScope", "String", true, "host-device"),
        ("riskLevel", "String", true, "readonly; native query/private artifacts and shallow descriptor metadata side effects remain"),
        ("target", "HostDeviceTarget", true, "Selected target bound to exact request argv and result identity"),
        ("backend", "String", true, "sdk-metadata or coresimulator-native when --list"),
        ("bindingSource", "String", true, "SDK apps explicit bundleIdentifier/containerAccessible/dataContainerPath or appGroupIdentifiers plus groupContainerPaths"),
        ("bindingStatus", "String", true, "sdk-bound|unavailable; legacy absent fields do not trigger fallback"),
        ("containerKind", "String", true, "app-data|app-group"),
        ("applicationToken", "String", true, "Hash correlation; no raw bundle ID, not an authorization or secrecy guarantee"),
        ("groupToken", "String", false, "Hash correlation for explicitly selected group, bound by both membership and path map"),
        ("containerToken", "String", false, "Only for explicit accessible SDK path; path stays private; no DeviceFS mapping claim"),
        ("containerAccessible", "Bool", false, "SDK field, nil in older layouts; not proof of filesystem or write access"),
        ("hostFilesystemInspected", "Bool", true, "Only with --list; exact selected Simulator UDID /data/Containers/Data/Application/<UUID> or Shared/AppGroup/<UUID>"),
        ("entries", "[HostDeviceFileEntryOutput]", true, "Shallow nofollow token/kind/regular size; no names, contents, owners or symlink targets"),
        ("count", "Int", true, "0 for metadata-only; entries never silently truncated"),
        ("maximumJSONBytes", "Int", true, "Local file-JSON acceptance 1...16777216"),
        ("maximumEntries", "Int", true, "Local shallow entries acceptance 1...10000"),
        ("contentsRead", "Bool", true, "false"),
        ("recursive", "Bool", true, "false"),
        ("deviceFSBindingVerified", "Bool", true, "false; explicit native-container binding is independent of existing DeviceFS directory selection"),
        ("readWriteAuthorizationVerified", "Bool", true, "false"),
        ("verification", "String", true, "executed-file-json or executed-file-json-and-descriptor-metadata; fixture vs real acceptance tracked separately"),
        ("limitSemantics", "String", true, "Local acceptance; no filesystem syscall deadline or atomic snapshot"),
        ("sourceCommands", "[String]", true, "Constructed commands with private device and bundle arguments redacted"),
        ("artifacts", "[String]", true, "Fresh private 0700 directory, 0600 file JSON/log refs; may contain private native identity/path metadata"),
    ]))
}
