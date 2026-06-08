import Darwin
import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct FailureDiagnosticsTests {
    @Test("assert failure includes nearest text and suggested commands")
    func assertFailureIncludesDiagnostics() {
        let result = TKUIAssertEvaluate(
            TKUIAssertRequest(condition: .textExists, query: "Go to lottery"),
            nodes: [
                TKAXNode(
                    role: "button",
                    label: "Lottery",
                    value: nil,
                    identifier: nil,
                    title: nil,
                    frame: TKRect(x: 0, y: 0, width: 100, height: 44),
                    enabled: true,
                    focused: false,
                    hidden: false,
                    targetOID: nil,
                    className: "UIButton",
                    children: []
                ),
            ]
        )

        #expect(result.ok == false)
        #expect(result.nearestText == ["Lottery"])
        #expect(result.suggestedCommands?.contains("triton find 'Go to lottery' --all --json") == true)
    }

    @Test("tap target failure maps to machine-readable CLI diagnostics")
    func tapTargetFailureMapsToCLIDiagnostics() {
        let failure = TKTapTargetResolutionFailure(
            query: "Go to lottery",
            message: "No tappable UI target matched query: Go to lottery",
            candidateCount: 0,
            nearestCandidates: ["Lottery"],
            suggestedCommands: ["triton find 'Go to lottery' --all --json", "triton screenshot --json"]
        )

        let detail = cliErrorDetail(for: failure, endpoint: "/request", host: "127.0.0.1", port: 19421)

        #expect(detail.code == "text_not_found")
        #expect(detail.nearestCandidates == ["Lottery"])
        #expect(detail.suggestedCommands == ["triton find 'Go to lottery' --all --json", "triton screenshot --json"])
        #expect(detail.candidateCount == 0)
    }

    @Test("runtime HTTP error envelopes are preserved without CLI rewrapping")
    func runtimeHTTPErrorEnvelopeIsPreserved() throws {
        let runtimeResponse = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "runtime_ui_interrupted",
            message: "UI request timed out while the app was interrupted",
            endpoint: "/request",
            hint: "Dismiss system alerts and retry"
        ))
        let data = try JSONEncoder().encode(runtimeResponse)
        let httpError = CLIHTTPError(statusCode: 504, data: data)

        let response = cliErrorResponse(
            for: httpError,
            endpoint: "/request",
            host: "127.0.0.1",
            port: 19421
        )

        #expect(response.ok == false)
        #expect(response.error.code == "runtime_ui_interrupted")
        #expect(response.error.message == "UI request timed out while the app was interrupted")
        #expect(response.error.endpoint == "/request")
        #expect(response.error.hint == "Dismiss system alerts and retry")
    }

    @Test("runtime-facing schemas include preserved runtime envelope failure codes")
    func runtimeFacingSchemasIncludePreservedRuntimeEnvelopeFailureCodes() throws {
        let schemas = Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })
        let state = try #require(schemas["state"])
        let snapshot = try #require(schemas["snapshot"])
        let geometry = try #require(schemas["geometry"])
        let hit = try #require(schemas["hit"])
        let ledger = try #require(schemas["ledger"])
        let focus = try #require(schemas["focus"])
        let setText = try #require(schemas["set-text"])

        for schema in [state, snapshot, geometry, hit, ledger] {
            #expect(schema.failureCodes.contains("runtime_ui_interrupted"))
            #expect(schema.failureCodes.contains("request_timeout"))
            #expect(schema.failureCodes.contains("invalid_payload"))
        }

        for schema in [focus, setText] {
            #expect(schema.failureCodes.contains("runtime_ui_interrupted"))
            #expect(schema.failureCodes.contains("request_timeout"))
            #expect(schema.failureCodes.contains("invalid_payload"))
            #expect(schema.failureCodes.contains("action_not_supported"))
            #expect(schema.failureCodes.contains("unsupported_runtime_scope"))
        }
    }

    @Test("android text-not-found host failure maps to shared text_not_found code")
    func androidTextNotFoundMapsToSharedTextNotFoundCode() throws {
        let output = try captureStandardOutput {
            #expect(throws: ExitCode.self) {
                try failAndroidTextNotFound("Network & internet", outputFormat: .json)
            }
        }
        let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(output.utf8))

        #expect(response.error.code == "text_not_found")
        #expect(response.error.message == "Android layout text was not found: Network & internet")
        #expect(response.error.hint?.contains("triton observe tree --platform android") == true)
    }

    @Test("host validation errors stay validation_failed")
    func hostValidationErrorsStayValidationFailed() throws {
        let detail = hostValidationErrorDetail(ValidationError("Harmony app install requires --hap."))

        #expect(detail.code == "validation_failed")
        #expect(detail.message == "Harmony app install requires --hap.")
    }

    @Test("host-facing schemas cover failHostCommand error codes")
    func hostFacingSchemasCoverFailHostCommandErrorCodes() throws {
        let schemas = Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })
        let hostCommandSchemas = [
            "device", "sim", "app", "xcode", "xcresult", "xctrace", "coverage",
            "observe", "webview", "route", "screenshot", "smoke",
        ].compactMap { schemas[$0] }
        let schemaCodes = Set(hostCommandSchemas.flatMap(\.failureCodes))
        let expectedHostCodes: Set<String> = [
            "invalid_workspace_path",
            "ambiguous_workspace",
            "scheme_not_found",
            "app_path_unresolved",
            "bundle_id_unresolved",
            "simulator_not_found",
            "ambiguous_target",
            "target_offline",
            "target_not_found",
            "target_platform_mismatch",
            "parameter_conflict",
            "device_not_ready",
            "harmony_layout_path_not_found",
            "harmony_layout_text_not_found",
            "host_command_timeout",
            "plist_not_found",
            "preference_key_not_found",
            "xcode_not_idle",
            "xcresult_parse_failed",
            "xcresult_output_too_large",
            "artifact_output_rejected",
            "app_info_not_available",
            "xcodebuild_failed",
            "xctrace_record_failed",
            "result_bundle_not_found",
            "xcresulttool_failed",
            "coverage_report_failed",
            "host_action_failed",
            "unsupported_host_action",
            "debug_runtime_disabled",
            "runtime_not_connected",
            "devicectl_not_found",
            "devicectl_json_missing",
            "devicectl_json_parse_failed",
            "device_not_trusted",
            "developer_mode_required",
            "ddi_missing",
            "xcode_signing_failed",
            "provisioning_profile_missing",
            "android_adb_not_found",
            "android_target_unauthorized",
            "android_target_offline",
            "android_debugging_disabled",
            "android_package_manager_unavailable",
            "android_app_install_failed",
            "android_activity_resolve_failed",
            "harmony_hdc_not_found",
            "harmony_target_unauthorized",
            "harmony_target_offline",
            "harmony_debugging_disabled",
            "harmony_shell_unavailable",
            "harmony_app_install_failed",
            "harmony_ability_launch_failed",
            "status_bar_operation_failed",
            "sim_diagnose_failed",
            "sim_logverbose_failed",
            "sim_record_failed",
            "sim_logs_failed",
            "privacy_operation_failed",
            "location_operation_failed",
            "ui_operation_failed",
            "pasteboard_operation_failed",
            "push_payload_invalid",
            "sim_pair_failed",
            "sim_unpair_failed",
            "sim_clone_failed",
            "sim_erase_failed",
            "sim_upgrade_failed",
            "sim_personalization_failed",
            "runtime_add_failed",
            "runtime_delete_failed",
            "runtime_unmount_failed",
            "runtime_scan_and_mount_failed",
            "runtime_match_failed",
            "runtime_dyld_cache_failed",
            "runtime_verify_failed",
            "runtime_list_failed",
            "app_install_failed",
            "host_open_url_failed",
            "app_launch_failed",
            "app_terminate_failed",
            "harmony_layout_failed",
            "harmony_artifact_recv_failed",
            "harmony_screenshot_failed",
            "app_container_not_found",
        ]

        let missing = expectedHostCodes.subtracting(schemaCodes)
        let missingList = missing.sorted().joined(separator: ", ")
        #expect(missing.isEmpty, "Missing host failure codes in schema: \(missingList)")
    }

    @Test("command-local validation and workflow schemas cover specialized failure codes")
    func commandLocalValidationAndWorkflowSchemasCoverSpecializedFailureCodes() throws {
        let schemas = Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })

        try expectFailureCodes(
            schemas,
            command: "webview",
            include: [
                "webview_not_found",
                "ambiguous_webview",
                "webview_id_not_found",
                "webview_provider_unavailable",
                "webview_navigation_changed",
                "webview_bridge_unavailable",
                "webview_method_not_allowed",
                "webview_wait_timeout",
                "webview_wait_unsupported",
                "javascript_error",
            ]
        )
        try expectFailureCodes(
            schemas,
            command: "route",
            include: [
                "route_mismatch",
                "webview_not_found",
                "ambiguous_webview",
                "webview_id_not_found",
                "webview_provider_unavailable",
                "server_unavailable",
                "target_unavailable",
                "target_not_found",
                "ambiguous_target",
                "host_command_failed",
                "request_failed",
                "validation_failed",
            ]
        )
        try expectFailureCodes(
            schemas,
            command: "smoke",
            include: [
                "runtime_not_connected",
                "smoke_step_failed",
                "text_not_found",
                "artifact_write_failed",
                "device_not_ready",
                "app_info_not_available",
                "app_launch_failed",
                "host_open_url_failed",
                "validation_failed",
            ]
        )
        try expectFailureCodes(
            schemas,
            command: "sim",
            include: [
                "confirmation_required",
                "invalid_duration",
                "invalid_location_value",
                "runtime_delete_selector_required",
                "runtime_dyld_cache_selector_required",
                "runtime_match_selector_required",
                "validation_failed",
            ]
        )
        try expectFailureCodes(
            schemas,
            command: "app",
            include: [
                "destructive_action_requires_policy",
                "validation_failed",
            ]
        )

        for command in ["tap", "swipe", "type", "paste", "clear", "press"] {
            try expectFailureCodes(
                schemas,
                command: command,
                include: [
                    "unsupported_capability",
                    "validation_failed",
                    "server_unavailable",
                    "target_not_found",
                    "ambiguous_target",
                    "request_failed",
                ]
            )
        }

        for command in ["evidence", "capture", "assert", "record", "replay"] {
            try expectFailureCodes(schemas, command: command, include: ["validation_failed"])
        }
    }
}

private func captureStandardOutput(_ body: () throws -> Void) throws -> String {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)

    fflush(stdout)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    do {
        try body()
    } catch {
        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()
        throw error
    }
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}

private func expectFailureCodes(
    _ schemas: [String: TKCommandSchema],
    command: String,
    include expectedCodes: Set<String>
) throws {
    let schema = try #require(schemas[command])
    let missing = expectedCodes.subtracting(schema.failureCodes)
    #expect(missing.isEmpty, "Missing \(command) failure codes: \(missing.sorted().joined(separator: ", "))")
}
