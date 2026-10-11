import TritonKitShared

func hostDeviceAdministrationPlanOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.device-administration-plan", format: "json", kind: "host-action", model: "HostDeviceAdministrationPlanOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Policy review plan produced, not native command support or operation/archive success; unsupported SDK still returns explicit support=false/blockers/no preview"),
        ("action", "String", true, "device.pair|device.unpair|device.diagnose; plan-only, different from existing sim operations"),
        ("runtimeScope", "String", true, "host-device; standalone, no server or Run required"),
        ("riskLevel", "String", true, "readonly plan; discovery/help service communication and private cache artifacts possible"),
        ("planOnly", "Bool", true, "Always true, required explicit --plan-only; missing flag rejected before IO"),
        ("executable", "Bool", true, "Always false on plan output; explicit execution is a separate contract"),
        ("executed", "Bool", true, "Always false; planned administration never called"),
        ("verification", "String", true, "planned-not-executed; not pairing/archive/business proof"),
        ("target", "String", true, "Fresh discovered real native primary rehashed ios-real token; raw aliases/names/selection/output path not echoed"),
        ("plannedRiskLevel", "String", true, "break-glass pair/unpair, diagnostic diagnose; this is prospective action risk, not readonly plan risk"),
        ("plannedSourceCommand", "String", false, "Only when SDK help advertises all required flags; private target/destination redacted, JSON/log placeholders never allocated or used. Preview not actual source command execution"),
        ("commandSupport", "HostAppleCommandSupport", true, "help-advertised-only, exact required safety flags, no backend/action acceptance; raw probe error sanitized"),
        ("blockedRequirements", "[String]", true, "Always nonempty for plan: explicit execution authorization/audit and result/postconditions required; physical acceptance not performed; diagnose also private archive publication policy and content completeness limits"),
        ("diagnosticScopeHint", "String", false, "Host CoreDevice logs may still be included despite --no-include-host-sysdiagnose; explicit device only, no device-only or crash-report equivalence; no Finder/profile install/DDI mount in this plan"),
        ("archiveDestinationSupplied", "Bool", true, "Private ZIP input presence only; path not echoed/inspected/created or overwrite-safe"),
        ("operationArtifactsCreated", "Bool", true, "False for planned operation; discovery may create private cache artifacts"),
        ("pairingStateVerified", "Bool", true, "False, no trust state changed or postcondition verified"),
        ("diagnosticArchiveVerified", "Bool", true, "False, no diagnostics collected or archive verified"),
        ("sideEffects", "String", true, "Read-only metadata discovery/help possible, never planned pair/unpair/diagnose, Finder, profile install, DDI mount or credentials storage")
    ]))
}

func hostDeviceAdministrationExecutionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.device-administration-execution", format: "json", kind: "host-action", model: "HostDeviceAdministrationExecutionOutput", fields: schemaContractFields([
        ("ok", "Bool", true, "Only native file-JSON success plus independent pairing postcondition or safely published ZIP and durable completion audit"),
        ("action", "String", true, "device.pair|device.unpair|device.diagnose; distinct from old sim commands"),
        ("runtimeScope", "String", true, "host-device; no server or Run required"),
        ("planOnly", "Bool", true, "False; requires explicit --execute-runner --confirm --audit-record, real target; no automatic retry"),
        ("executable", "Bool", true, "Execution backend selected after explicit policy and SDK support checks; not physical acceptance"),
        ("executed", "Bool", true, "Native runner invoked; timeout/nonzero may leave side effects; launch failure is false"),
        ("status", "String", true, "succeeded|failed|timed-out|partial; exit zero alone never success, unknown native shape/postcondition/archive failure is partial"),
        ("target", "String", true, "Fresh primary identity hash, not native identity/name/alias"),
        ("riskLevel", "String", true, "break-glass for trust changes; diagnostic for device and host logs"),
        ("verification", "String", true, "Strict common CoreDevice file-JSON argv/outcome plus operation postcondition; backend fixture tested, no physical execution acceptance performed"),
        ("auditToken", "String", true, "Opaque durable local workspace token under ~/.triton/device-administration; no native identity or output path"),
        ("auditIntentPersisted", "Bool", true, "Intent fsynced as private exclusive file before native action; failure blocks execution"),
        ("auditCompletionPersisted", "Bool", true, "Final status fsynced; failure forces partial even after effects"),
        ("nativeResultVerified", "Bool", true, "info.arguments must exactly match invoked argv; info.outcome success and no contradictory recognized identity"),
        ("pairingStateVerified", "Bool", true, "Fresh identity-bound details file-JSON; missing/disappeared device is unknown, not unpaired"),
        ("pairingState", "String", false, "paired|unpaired, only recognized independent postcondition; trust state is not pairing"),
        ("diagnosticArchiveVerified", "Bool", true, "Owner/private regular ZIP, nofollow/exclusive publication and bounded ZIP structure; not contents/CRC/device-only/completeness acceptance"),
        ("archiveBytes", "Int", false, "Accepted ZIP bytes; limit not native transport/collection or peak disk hard budget"),
        ("error", "TKCLIErrorDetail", false, "Static bounded failure detail, no native logs/paths/identity"),
        ("limitations", "[String]", true, "Fixture-only action acceptance, host logs, unknown effects/no retry, archive content and native budget limits")
    ]))
}
