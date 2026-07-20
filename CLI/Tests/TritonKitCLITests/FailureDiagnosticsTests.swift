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
        #expect(result.suggestedCommands?.contains("triton act find 'Go to lottery' --all --json") == true)
    }

    @Test("tap target failure maps to machine-readable CLI diagnostics")
    func tapTargetFailureMapsToCLIDiagnostics() {
        let failure = TKTapTargetResolutionFailure(
            query: "Go to lottery",
            message: "No tappable UI target matched query: Go to lottery",
            candidateCount: 0,
            nearestCandidates: ["Lottery"],
            suggestedCommands: ["triton act find 'Go to lottery' --all --json", "triton screenshot --json"]
        )

        let detail = cliErrorDetail(for: failure, endpoint: "/request", host: "127.0.0.1", port: 19421)

        #expect(detail.code == "text_not_found")
        #expect(detail.nearestCandidates == ["Lottery"])
        #expect(detail.suggestedCommands == ["triton act find 'Go to lottery' --all --json", "triton screenshot --json"])
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

    @Test("host simulator AX errors map to machine-readable CLI diagnostics")
    func hostSimulatorAXErrorsMapToCLIDiagnostics() {
        let detail = cliErrorDetail(
            for: HostSimulatorAXError.frontmostApplicationUnavailable("ABC-123"),
            endpoint: "/request",
            host: "127.0.0.1",
            port: 19421
        )

        #expect(detail.code == "ios_host_ax_frontmost_unavailable")
        #expect(detail.message.contains("ABC-123"))
        #expect(detail.nextAction?.command == "sim")
        #expect(detail.suggestedCommands?.contains("triton sim list --json") == true)

        let actionDetail = cliErrorDetail(
            for: HostSimulatorAXError.actionUnavailable("ABC-123"),
            endpoint: "/request",
            host: "127.0.0.1",
            port: 19421
        )

        #expect(actionDetail.code == "ios_host_ax_action_unavailable")
        #expect(actionDetail.nextAction?.command == "observe")
        #expect(actionDetail.suggestedCommands?.contains("triton observe tree --platform ios --device <selector> --json") == true)
    }

    @Test("target state extracts identity from appInfo envelope")
    func targetStateExtractsIdentityFromAppInfoEnvelope() throws {
        let payload = Data("""
        {
          "displayItems": [],
          "appInfo": {
            "appName": "Overloaded",
            "appBundleIdentifier": "overloaded.cn.debug",
            "platform": "ios",
            "deviceDescription": "iPhone",
            "osDescription": "26.5"
          }
        }
        """.utf8)
        let state = TargetState()

        state.setLatestAppInfo(payload)
        let summary = try #require(state.summary(connected: true, connectionID: 7))

        #expect(summary.appName == "Overloaded")
        #expect(summary.bundleIdentifier == "overloaded.cn.debug")
        #expect(summary.deviceDescription == "iPhone")
        #expect(summary.osDescription == "26.5")
        #expect(summary.identityState == "current")
    }

    @Test("runtime-facing schemas include preserved runtime envelope failure codes")
    func runtimeFacingSchemasIncludePreservedRuntimeEnvelopeFailureCodes() throws {
        let schemas = Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })
        let debug = try #require(schemas["debug"])
        let act = try #require(schemas["act"])

        #expect(debug.failureCodes.contains("runtime_ui_interrupted"))
        #expect(debug.failureCodes.contains("request_timeout"))
        #expect(debug.failureCodes.contains("invalid_payload"))
        #expect(act.failureCodes.contains("runtime_ui_interrupted"))
        #expect(act.failureCodes.contains("request_timeout"))
        #expect(act.failureCodes.contains("invalid_payload"))
        #expect(act.failureCodes.contains("action_not_supported"))
        #expect(act.failureCodes.contains("unsupported_runtime_scope"))
    }

    @Test("android text-not-found host failure maps to shared text_not_found code")
    func androidTextNotFoundMapsToSharedTextNotFoundCode() throws {
        let detail = androidTextNotFoundErrorDetail("Network & internet")
        let response = TKCLIErrorResponse(error: detail)

        #expect(response.error.code == "text_not_found")
        #expect(response.error.message == "Android layout text was not found: Network & internet")
        #expect(response.error.hint?.contains("triton observe tree --platform android") == true)
    }

    @Test("host validation errors stay validation_failed")
    func hostValidationErrorsStayValidationFailed() throws {
        let detail = hostValidationErrorDetail(ValidationError("Harmony app install requires --hap or --app."))

        #expect(detail.code == "validation_failed")
        #expect(detail.message == "Harmony app install requires --hap or --app.")
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
            "harmony_discovery_timeout",
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
                "sim_record_truncated",
                "sim_record_invalid_artifact",
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

        try expectFailureCodes(
            schemas,
            command: "act",
            include: [
                "unsupported_capability",
                "validation_failed",
                "server_unavailable",
                "target_not_found",
                "ambiguous_target",
                "request_failed",
            ]
        )

        for command in ["evidence", "verify", "record", "replay"] {
            try expectFailureCodes(schemas, command: command, include: ["validation_failed"])
        }
    }
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
