import TritonKitShared

func hostDeviceAdministrationPlanOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.device-administration-plan", format: "json", kind: "host-action", model: "HostDeviceAdministrationPlanOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Policy review plan produced, not native command support or operation/archive success; unsupported SDK still returns explicit support=false/blockers/no preview"),
        ("action", "String", true, "device.pair|device.unpair|device.diagnose; plan-only, different from existing sim operations"),
        ("runtimeScope", "String", true, "host-device; standalone, no server or Run required"),
        ("riskLevel", "String", true, "readonly plan; discovery/help service communication and private cache artifacts possible"),
        ("planOnly", "Bool", true, "Always true, required explicit --plan-only; missing flag rejected before IO"),
        ("executable", "Bool", true, "Always false; no execution runner exposed or accepted"),
        ("executed", "Bool", true, "Always false; planned administration never called"),
        ("verification", "String", true, "planned-not-executed; not pairing/archive/business proof"),
        ("target", "String", true, "Fresh discovered real native primary rehashed ios-real token; raw aliases/names/selection/output path not echoed"),
        ("plannedRiskLevel", "String", true, "break-glass pair/unpair, diagnostic diagnose; this is prospective action risk, not readonly plan risk"),
        ("plannedSourceCommand", "String", false, "Only when SDK help advertises all required flags; private target/destination redacted, JSON/log placeholders never allocated or used. Preview not actual source command execution"),
        ("commandSupport", "HostAppleCommandSupport", true, "help-advertised-only, exact required safety flags, no backend/action acceptance; raw probe error sanitized"),
        ("blockedRequirements", "[String]", true, "Always nonempty: real authorization/audit, accepted execution backend, authoritative result/postconditions; diagnose also archive content/path/permission/nooverwrite/nofollow/size policy; missing SDK flags explicit"),
        ("diagnosticScopeHint", "String", false, "Host CoreDevice logs may still be included despite --no-include-host-sysdiagnose; explicit device only, no device-only or crash-report equivalence; no Finder/profile install/DDI mount in this plan"),
        ("archiveDestinationSupplied", "Bool", true, "Private ZIP input presence only; path not echoed/inspected/created or overwrite-safe"),
        ("operationArtifactsCreated", "Bool", true, "False for planned operation; discovery may create private cache artifacts"),
        ("pairingStateVerified", "Bool", true, "False, no trust state changed or postcondition verified"),
        ("diagnosticArchiveVerified", "Bool", true, "False, no diagnostics collected or archive verified"),
        ("sideEffects", "String", true, "Read-only metadata discovery/help possible, never planned pair/unpair/diagnose, Finder, profile install, DDI mount or credentials storage")
    ]))
}
