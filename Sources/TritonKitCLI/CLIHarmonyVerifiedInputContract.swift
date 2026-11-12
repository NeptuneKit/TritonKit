import TritonKitShared

let harmonyVerifiedInputFailureCodes = [
    "harmony_input_invalid_options", "harmony_input_invalid_selector", "harmony_input_target_unavailable",
    "harmony_input_layout_budget", "harmony_input_layout_invalid", "harmony_input_not_found",
    "harmony_input_ambiguous", "harmony_input_not_editable",
    "harmony_input_value_unavailable", "harmony_input_focus_unavailable", "harmony_input_bounds_unavailable",
    "harmony_input_timeout", "harmony_input_identity_changed", "harmony_input_focus_timeout",
    "harmony_input_value_mismatch", "harmony_input_submission_unknown", "harmony_input_focus_unknown",
    "harmony_input_capture_unavailable",
]

func harmonyVerifiedInputOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(selector: "host.harmony-verified-text-input", format: "json", kind: "host-action", model: "HarmonyVerifiedInputResult", fields: schemaContractFields([
        ("ok", "Bool", true, "True only after exact full native field value observed within deadline"),
        ("action", "String", true, "type"),
        ("platform", "String", true, "harmony"),
        ("submission", "String", true, "not-sent, submitted, or unknown; unknown is never replayed"),
        ("focus", "String", true, "unknown, not-focused, or confirmed from layout"),
        ("verification", "String", true, "match, mismatch, timeout, or unavailable"),
        ("code", "String", true, "Typed outcome; failure uses one result envelope"),
        ("durations", "[String:Double]", true, "Observed resolve/focus/send/verify and total seconds; unentered phases omitted"),
        ("timedOut", "Bool", true, "A phase or total deadline expired; preserves an already-observed mismatch"),
        ("polls", "Int", true, "Completed layout reads"),
        ("note", "String", true, "Match is an observed postcondition, not causal proof"),
        ("redacted", "Bool", true, "False by default; --secure explicitly omits observedValue"),
        ("observedValue", "String?", false, "Exact provider text when available; no inferred sensitivity filter"),
    ]))
}
