#if os(macOS)
import TritonKitShared

func hostDeviceMountpointOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.device-mountpoint", format: "json", kind: "host-action", model: "HostDeviceMountpointOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Bound file JSON only; no filesystem postcondition"),
        ("action", "String", true, "device.mountpoint"),
        ("runtimeScope", "String", true, "host-device; standalone, no mandatory Run/server"),
        ("riskLevel", "String", true, "readonly information query; CoreDevice service/private artifact side effects remain"),
        ("mountCreated", "String", true, "Always unknown because devicectl mountpoint may implicitly mount the device filesystem"),
        ("target", "HostDeviceTarget", true, "Canonical redacted selector; raw identities/aliases private"),
        ("mountpointToken", "String", true, "devicefs: SHA256 target/path correlation token, not path disclosure or authorization"),
        ("identityBinding", "String", true, "Exact unique echoed --device matching actual raw request; no path guessing"),
        ("verification", "String", true, "executed-file-json; not mount/filesystem/content verification"),
        ("hostFilesystemInspected", "Bool", true, "Always false; dataPath not stat/realpath/open/list"),
        ("mountStateVerified", "Bool", true, "Always false; no explicit mount/unmount or presence/read/write claim"),
        ("contentsListed", "Bool", true, "Always false; not automatic fallback from files failure"),
        ("businessReadinessVerified", "Bool", true, "Always false; no auto boot/pair/unlock"),
        ("maximumJSONBytes", "Int", true, "Local JSON acceptance bytes, not remote hard limit"),
        ("limitSemantics", "String", true, "local-acceptance-only"),
        ("sourceCommands", "[String]", true, "Producer command with private device operand redacted, not untrusted stdout"),
        ("artifacts", "[String]", true, "Private 0700/0600 JSON/log references; returned native mount path stays inside private JSON"),
    ]))
}
#endif
