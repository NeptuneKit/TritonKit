import Foundation
import TritonKitShared

func deviceRecordingOutputContract() -> TKCommandOutputContract {
    deviceRecordingCommandSchemas().first!.outputContracts.first!
}

func deviceRecordingCommandSchemas() -> [TKCommandSchema] {
    let failures = ["recording_invalid_duration", "recording_invalid_session", "recording_invalid_output", "recording_unsafe_path", "recording_unsafe_store", "recording_lock_failed", "recording_busy", "recording_owner_mismatch", "recording_target_mismatch", "recording_session_corrupt", "recording_already_active", "recording_target_not_ready", "recording_unsupported", "recording_worker_unavailable", "recording_worker_conflict", "recording_worker_identity_unavailable", "recording_worker_identity_lost", "recording_start_timeout", "recording_stop_timeout", "recording_stop_failed", "recording_output_exists", "recording_output_changed", "recording_recorder_timeout", "recording_remote_identity_lost", "recording_pull_failed", "recording_frame_failed", "recording_encoder_failed", "recording_empty_media", "recording_failed"]
    let contract = TKCommandOutputContract(selector: "device.recording", format: "json", kind: "envelope", model: "DeviceRecordingOutput", fields: [
        TKCommandSchemaField(name: "ok", type: "Bool", required: true, description: "False for failed sessions"),
        TKCommandSchemaField(name: "session", type: "DeviceRecordingSession", required: true, description: "Owner, target, process creation identities, session lifecycle, bounds and actual media duration"),
        TKCommandSchemaField(name: "wallClockDurationSeconds", type: "Double", required: true, description: "Wall clock observation; never substituted for encoded video samples"),
        TKCommandSchemaField(name: "captureMethod", type: "String", required: true, description: "native-screen-recording or runner-snapshot-sequence"),
        TKCommandSchemaField(name: "artifacts", type: "[String]", required: true, description: "Final MP4 only after positive video sample validation"),
        TKCommandSchemaField(name: "includesAudio", type: "Bool", required: true, description: "Always false"),
        TKCommandSchemaField(name: "observedFramesPerSecond", type: "Double?", required: false, description: "Observed Runner screenshot count divided by encoded duration; no fixed realtime FPS guarantee"),
    ])
    return [TKCommandSchema(name: "device recording", summary: "Owned cross-invocation recording sessions", requiresServer: false, requiresTarget: true,
                            runtimeScope: "local iOS Simulator, Android devices/emulators and active iOS real-device Runner", exitCodeOnFailure: 1,
                            outputFormats: schemaTextJSONFormats,
                            options: [TKCommandSchemaOption(name: "--device", type: "String", description: "Explicit device for start; optional exact session target guard otherwise"),
                                      TKCommandSchemaOption(name: "--output", type: "String", description: "Fresh absolute .mp4 destination, no overwrite or symlink"),
                                      TKCommandSchemaOption(name: "--session", type: "String", description: "Exact lowercase UUID returned by start"),
                                      TKCommandSchemaOption(name: "--maximum-duration", type: "Double", defaultValue: "180", description: "Finite bound 1...180 seconds"),
                                      TKCommandSchemaOption(name: "--adb", type: "String", defaultValue: "adb", description: "Android command executable"),
                                      TKCommandSchemaOption(name: "--hdc", type: "String", defaultValue: "hdc", description: "Discovery executable"),
                                      TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"), schemaJSONAliasOption],
                            usageForms: [TKCommandUsageForm(form: "triton device recording start --device <device> --output /absolute/fresh.mp4 --maximum-duration 60 --json", kind: "Subcommand", description: "Start an owned background worker"),
                                         TKCommandUsageForm(form: "triton device recording status --session <uuid> --json", kind: "Subcommand", description: "Read and verify session"),
                                         TKCommandUsageForm(form: "triton device recording stop --session <uuid> --json", kind: "Subcommand", description: "Request bounded finalization")],
                            examples: ["triton device recording start --device sim:<udid> --output /tmp/capture.mp4 --maximum-duration 60 --json", "triton device recording status --session <uuid> --json", "triton device recording stop --session <uuid> --json"],
                            successShape: "{ok,action,session,wallClockDurationSeconds,captureMethod,includesAudio:false,artifacts,observedFramesPerSecond?}",
                            failureShape: "Single error envelope or ok:false session with failureCode/failureMessage",
                            outputSemantics: "start returns only after worker acknowledgement; recording continues across CLI exit and allows other actions. Owner-only flock protects target exclusivity. stop addresses session identity and sends a stop request, never signals an arbitrary stored PID. Native Android cleanup verifies remote creation time and UUID-qualified command identity. Worker owns recorder Process and bounded deadline. Completed artifacts require actual positive video samples; wall time is separate. iOS real uses an existing owned, unexpired Runner screenshot stream encoded with original observation times, no audio and no fixed realtime frame rate. TRITON_RECORDING_STATE_DIR overrides the owner-only state directory. Lost worker identity is an explicit failure with retained evidence, never stale-PID signalling.",
                            outputContracts: [contract], failureCodes: failures,
                            subcommands: [TKCommandSubcommandSchema(name: "start", summary: "Start background recording", requiresServer: false, requiresTarget: true, sideEffect: "device_recording_and_local_artifact", requiredOptions: ["--device", "--output"], optionalOptions: ["--maximum-duration", "--adb", "--hdc", "--format", "--json"], outputSelectors: ["device.recording"], failureCodes: failures),
                                          TKCommandSubcommandSchema(name: "status", summary: "Inspect session", requiresServer: false, requiresTarget: false, requiredOptions: ["--session"], optionalOptions: ["--device", "--format", "--json"], outputSelectors: ["device.recording"], failureCodes: failures),
                                          TKCommandSubcommandSchema(name: "stop", summary: "Finalize owned session", requiresServer: false, requiresTarget: false, sideEffect: "owned_recording_finalization", requiredOptions: ["--session"], optionalOptions: ["--device", "--format", "--json"], outputSelectors: ["device.recording"], failureCodes: failures)],
                            providedCapabilities: ["device.recording"])]
}
