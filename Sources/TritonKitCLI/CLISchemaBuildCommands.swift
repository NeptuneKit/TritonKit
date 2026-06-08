import Foundation
import TritonKitShared

func buildCommandSchemas() -> [TKCommandSchema] {
    let jsonAlias = schemaJSONAliasOption

    return [
        TKCommandSchema(
            name: "build",
            summary: "Plan and run cross-platform debug builds for real-device artifacts",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "host-build",
            exitCodeOnFailure: 1,
            outputFormats: ["json", "jsonl"],
            options: [
                TKCommandSchemaOption(name: "ios", type: "Subcommand", description: "Run an Xcode iphoneos build for a selected real device"),
                TKCommandSchemaOption(name: "android", type: "Subcommand", description: "Run or plan a Gradle debug build and discover APK artifacts"),
                TKCommandSchemaOption(name: "harmony", type: "Subcommand", description: "Run or plan an hvigor debug build and discover HAP artifacts"),
                TKCommandSchemaOption(name: "--workspace", type: "Path", description: "iOS .xcworkspace path for xcodebuild"),
                TKCommandSchemaOption(name: "--project", type: "Path", description: "Project root for Android/Harmony or iOS .xcodeproj path when used with `ios`"),
                TKCommandSchemaOption(name: "--scheme", type: "String", description: "iOS Xcode scheme"),
                TKCommandSchemaOption(name: "--device", type: "String", description: "Real-device selector or UDID used for build/install next actions"),
                TKCommandSchemaOption(name: "--destination", type: "String", description: "Explicit iOS xcodebuild destination"),
                TKCommandSchemaOption(name: "--configuration", type: "String", defaultValue: "Debug", description: "iOS Xcode build configuration"),
                TKCommandSchemaOption(name: "--sdk", type: "String", defaultValue: "iphoneos", description: "iOS SDK for xcodebuild"),
                TKCommandSchemaOption(name: "--derived-data-path", type: "Path", description: "iOS DerivedData output path"),
                TKCommandSchemaOption(name: "--variant", type: "String", defaultValue: "debug", description: "Android Gradle build variant"),
                TKCommandSchemaOption(name: "--module", type: "String", defaultValue: "entry", description: "Harmony module name"),
                TKCommandSchemaOption(name: "--mode", type: "String", defaultValue: "debug", description: "Harmony build mode"),
                TKCommandSchemaOption(name: "--gradle", type: "Path", description: "Explicit Gradle or gradlew executable"),
                TKCommandSchemaOption(name: "--hvigor", type: "Path", description: "Explicit hvigor or hvigorw executable"),
                TKCommandSchemaOption(name: "--output", type: "Path", description: "Optional artifact output or discovery root"),
                TKCommandSchemaOption(name: "--timeout", type: "Double", description: "Command timeout in seconds for large projects"),
                TKCommandSchemaOption(name: "--jsonl", type: "Bool", defaultValue: "false", description: "Emit JSON Lines progress for long build commands"),
                TKCommandSchemaOption(name: "--format", type: "json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            usageForms: [
                TKCommandUsageForm(form: "ios --workspace <path> --scheme <name> --device <ios-real-target>", kind: "Subcommand", description: "Build an iOS app for iphoneos through xcodebuild"),
                TKCommandUsageForm(form: "android --project <path> --variant debug", kind: "Subcommand", description: "Build an Android debug APK through Gradle wrapper discovery"),
                TKCommandUsageForm(form: "harmony --project <path> --module entry --mode debug", kind: "Subcommand", description: "Build a Harmony debug HAP through hvigor wrapper discovery"),
            ],
            examples: [
                "triton build ios --workspace App.xcworkspace --scheme App --device <ios-real-target> --jsonl",
                "triton build android --project /tmp/App --variant debug --jsonl",
                "triton build android --project /tmp/App --gradle /tmp/App/gradlew --variant debug --json",
                "triton build harmony --project /tmp/HarmonyApp --module entry --mode debug --jsonl",
                "triton build harmony --project /tmp/HarmonyApp --hvigor /tmp/HarmonyApp/hvigorw --module entry --mode debug --json",
            ],
            successShape: "JSONL progress plus final TKBuildActionSummary with { ok, action, platform, project, variant?, module?, mode?, device?, artifact?, artifactPath?, artifactKind?, sourceCommand, exitCode, nextAction?, note }",
            failureShape: "{ ok:false, error:{ code: validation_failed|invalid_workspace_path|ambiguous_workspace|scheme_not_found|device_not_ready|device_not_trusted|developer_mode_required|ddi_missing|xcode_signing_failed|provisioning_profile_missing|xcodebuild_failed|gradle_not_found|gradle_build_failed|apk_artifact_not_found|android_keystore_missing|android_signing_failed|hvigor_not_found|hvigor_build_failed|hap_artifact_not_found|harmony_certificate_missing|harmony_profile_missing, message, hint, nextAction?{ command,args,category,requiresLongRunningProcess? } } }",
            outputSemantics: "Use build to produce installable debug artifacts before app install/run. A successful build only proves artifact production; device install, launch, and business readiness must be verified with app, smoke, wait/assert, or evidence.",
            jsonlEvents: [
                "build.<platform>.invocation",
                "build.<platform>.stdout",
                "build.<platform>.stderr",
                "build.<platform>.artifact",
                "build.<platform>.summary",
            ],
            finalEventKind: "build.<platform>.summary",
            artifacts: ["stdout-log", "stderr-log", "build.summary"],
            retryable: true,
            nextCommands: [
                "triton xcode build --device <ios-real-target> --sdk iphoneos --jsonl",
                "triton app install --device <selector> --scope real --platform android --apk <path> --json",
                "triton app install --device <selector> --scope real --platform harmony --hap <path> --json",
                "triton smoke android --device <selector> --scope real --package <package> --wait-text <text> --json",
                "triton smoke harmony --device <selector> --scope real --bundle <bundle> --ability <ability> --wait-text <text> --json",
                "triton evidence --include build.summary --output <dir.tritonevidence> --json",
                "triton schema --command build --json",
            ],
            outputContracts: [
                buildProgressOutputContract(),
                buildFinalOutputContract(),
            ],
            failureCodes: buildFailureCodes(),
            subcommands: [
                TKCommandSubcommandSchema(
                    name: "ios",
                    summary: "Run an Xcode iphoneos build for a selected real device",
                    requiredOptions: ["--scheme"],
                    oneOfRequiredOptions: [["--workspace", "--project"]],
                    optionalOptions: ["--device", "--destination", "--configuration", "--sdk", "--derived-data-path", "--timeout", "--jsonl", "--json"],
                    jsonlEvents: [
                        "build.ios.invocation",
                        "build.ios.stdout",
                        "build.ios.stderr",
                        "build.ios.summary",
                    ],
                    finalEventKind: "build.ios.summary",
                    artifacts: ["stdout-log", "stderr-log", "build.summary"],
                    retryable: true,
                    nextCommands: [
                        "triton xcode build --device <ios-real-target> --sdk iphoneos --jsonl",
                        "triton app install --device <ios-real-target> --scope real --platform ios --app <path.app> --json",
                        "triton evidence --include build.summary --output <dir.tritonevidence> --json",
                    ],
                    outputSelectors: ["build.progress", "build.final"],
                    failureCodes: [
                        "validation_failed",
                        "invalid_workspace_path",
                        "ambiguous_workspace",
                        "scheme_not_found",
                        "device_not_ready",
                        "device_not_trusted",
                        "developer_mode_required",
                        "ddi_missing",
                        "xcode_signing_failed",
                        "provisioning_profile_missing",
                        "xcodebuild_failed",
                    ]
                ),
                TKCommandSubcommandSchema(
                    name: "android",
                    summary: "Run or plan a Gradle debug build and discover APK artifacts",
                    requiredOptions: ["--project"],
                    optionalOptions: ["--variant", "--gradle", "--output", "--timeout", "--jsonl", "--json"],
                    jsonlEvents: [
                        "build.android.invocation",
                        "build.android.stdout",
                        "build.android.stderr",
                        "build.android.artifact",
                        "build.android.summary",
                    ],
                    finalEventKind: "build.android.summary",
                    artifacts: ["stdout-log", "stderr-log", "build.summary"],
                    retryable: true,
                    nextCommands: [
                        "triton app install --device <selector> --scope real --platform android --apk <path> --json",
                        "triton smoke android --device <selector> --scope real --package <package> --wait-text <text> --json",
                        "triton evidence --include build.summary --output <dir.tritonevidence> --json",
                    ],
                    outputSelectors: ["build.progress", "build.final"],
                    failureCodes: [
                        "gradle_not_found",
                        "gradle_build_failed",
                        "apk_artifact_not_found",
                        "android_keystore_missing",
                        "android_signing_failed",
                        "validation_failed",
                    ]
                ),
                TKCommandSubcommandSchema(
                    name: "harmony",
                    summary: "Run or plan an hvigor debug build and discover HAP artifacts",
                    requiredOptions: ["--project"],
                    optionalOptions: ["--module", "--mode", "--hvigor", "--output", "--timeout", "--jsonl", "--json"],
                    jsonlEvents: [
                        "build.harmony.invocation",
                        "build.harmony.stdout",
                        "build.harmony.stderr",
                        "build.harmony.artifact",
                        "build.harmony.summary",
                    ],
                    finalEventKind: "build.harmony.summary",
                    artifacts: ["stdout-log", "stderr-log", "build.summary"],
                    retryable: true,
                    nextCommands: [
                        "triton app install --device <selector> --scope real --platform harmony --hap <path> --json",
                        "triton smoke harmony --device <selector> --scope real --bundle <bundle> --ability <ability> --wait-text <text> --json",
                        "triton evidence --include build.summary --output <dir.tritonevidence> --json",
                    ],
                    outputSelectors: ["build.progress", "build.final"],
                    failureCodes: [
                        "hvigor_not_found",
                        "hvigor_build_failed",
                        "hap_artifact_not_found",
                        "harmony_certificate_missing",
                        "harmony_profile_missing",
                        "validation_failed",
                    ]
                ),
            ]
        ),
    ]
}

private func buildFailureCodes() -> [String] {
    [
        "validation_failed",
        "invalid_workspace_path",
        "ambiguous_workspace",
        "scheme_not_found",
        "device_not_ready",
        "device_not_trusted",
        "developer_mode_required",
        "ddi_missing",
        "xcode_signing_failed",
        "provisioning_profile_missing",
        "xcodebuild_failed",
        "gradle_not_found",
        "gradle_build_failed",
        "apk_artifact_not_found",
        "android_keystore_missing",
        "android_signing_failed",
        "hvigor_not_found",
        "hvigor_build_failed",
        "hap_artifact_not_found",
        "harmony_certificate_missing",
        "harmony_profile_missing",
    ]
}

private func buildProgressOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "build.progress",
        format: "jsonl",
        kind: "progress-event",
        model: "TKBuildProgressEvent",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the progress event is valid"),
            ("event", "String", true, "Progress event kind"),
            ("platform", "String", true, "ios, android, or harmony"),
            ("message", "String", true, "Human-readable progress message"),
            ("sourceCommand", "String?", false, "Underlying host command"),
            ("elapsedMs", "Int?", false, "Elapsed milliseconds"),
            ("stdoutLogPath", "String?", false, "Stdout artifact path"),
            ("stderrLogPath", "String?", false, "Stderr artifact path"),
        ])
    )
}

private func buildFinalOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "build.final",
        format: "jsonl",
        kind: "final-event",
        model: "TKBuildActionSummary",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the build action completed"),
            ("action", "String", true, "build.android or build.harmony"),
            ("platform", "String", true, "ios, android, or harmony"),
            ("project", "String", true, "Project root"),
            ("variant", "String?", false, "Android Gradle variant"),
            ("module", "String?", false, "Harmony module name"),
            ("mode", "String?", false, "Harmony build mode or iOS Xcode configuration"),
            ("device", "String?", false, "Real-device selector or UDID"),
            ("artifact", "String?", false, "Discovered APK or HAP artifact path"),
            ("artifactPath", "String?", false, "Discovered installable artifact path"),
            ("artifactKind", "String?", false, "app, apk, or hap"),
            ("artifactBytes", "Int?", false, "Artifact byte size when available"),
            ("sourceCommand", "String?", false, "Underlying host command"),
            ("exitCode", "Int32", true, "Host process exit code"),
            ("stdoutLogPath", "String?", false, "Stdout artifact path"),
            ("stderrLogPath", "String?", false, "Stderr artifact path"),
            ("stdoutBytes", "Int?", false, "Captured stdout byte count"),
            ("stderrBytes", "Int?", false, "Captured stderr byte count"),
            ("durationMs", "Int", true, "Duration in milliseconds"),
            ("diagnostics", "CLIBuildDiagnosticsSummary?", false, "Warning/error counts and representative samples"),
            ("error", "TKCLIErrorDetail?", false, "Structured build diagnostic"),
            ("nextAction", "TKCLINextAction?", false, "Suggested app install action when an artifact exists"),
            ("note", "String?", false, "Boundary or next-step note"),
        ])
    )
}
