#if os(macOS)
import TritonKitShared

func hostDeviceInfoOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.device-info",
        format: "json",
        kind: "host-action",
        model: "HostDeviceInfoOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether all explicitly requested readonly queries succeeded"),
            ("action", "String", true, "device.info"),
            ("runtimeScope", "String", true, "host-device; no embedded runtime required"),
            ("riskLevel", "String", true, "readonly; never boot, pair or unlock automatically"),
            ("target", "HostDeviceTarget", true, "Fresh metadata with canonical/redacted identity; raw aliases stay private"),
            ("hardware", "TKDevicectlHardwareInfo", true, "Existing whitelisted hardware plus optional explicit platformObservation; old archived hardware missing observation still decodes"),
            ("hardware.platformObservation", "TKAppleHardwarePlatformObservation?", false, "Fresh details includes explicit normalized hardware observations, old archived hardware may omit. No inference from names/product/marketing/runtime/legacy ios namespace or capabilities; unknown raw observation values never echoed. Present modern properties never resurrect deprecated hardware"),
            ("hardware.platformObservation.systemFamily", "String", false, "If observation present: ios|ipados|watchos|tvos|visionos|macos|unknown from exact reported platform only; reported iOS plus iPad deviceType stays ios, not iPadOS. xrOS groups under visionos, not brand proof"),
            ("hardware.platformObservation.deviceFamily", "String", false, "If present: iphone|ipad|watch|tv|spatial|mac|unknown from exact deviceType only, not product/marketing/name or geometry"),
            ("hardware.platformObservation.reality", "String", false, "If present: physical|simulated|unknown only explicit exact hardware reality; absence not physical"),
            ("hardware.platformObservation.sourceLayout", "String", false, "If present: modern-properties-hardware or legacy-hardware-properties; modern presence even null/wrong type blocks deprecated fallback"),
            ("hardware.platformObservation.authority", "String", false, "If present: explicit-sdk-hardware-only; identity-bound readonly details fileJSON, not specialized platform control or business acceptance"),
            ("hardware.platformObservation.legacyNamespaceIsOperatingSystemProof", "Bool", false, "If present always false; existing compatibility ios namespace is not OS evidence. No old dispatcher/ID/argv change"),
            ("hardware.platformObservation.actionCapabilitiesVerified", "Bool", false, "If present always false; metadata never enables controls/capability claims"),
            ("hardware.platformObservation.businessReadinessVerified", "Bool", false, "If present always false; observations not business/action acceptance"),
            ("lockState", "HostDeviceLockStateOutput", true, "Explicit lock observation/probe state, not screenLocked or business readiness"),
            ("lockState.requested", "Bool", true, "Whether --lock-state was explicitly requested"),
            ("lockState.verification", "String", true, "executed-file-json for a successful probe, otherwise not-probed"),
            ("lockState.passcodeRequired", "Bool?", false, "Observed Apple field; absence remains unknown"),
            ("lockState.unlockedSinceBoot", "Bool?", false, "Observed Apple field; does not prove current screen lock state"),
            ("sourceCommands", "[String]", true, "Redacted commands with private target aliases removed"),
            ("artifacts", "[String]", true, "Private file JSON and log artifact paths; never publish raw contents"),
            ("verification", "String", true, "executed-file-json; not help/fixture or UI validation"),
            ("businessReadinessVerified", "Bool", true, "Always false; readonly metadata does not verify the app workflow"),
        ])
    )
}
#endif
