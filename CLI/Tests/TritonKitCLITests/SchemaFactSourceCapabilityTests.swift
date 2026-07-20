import Testing
import TritonKitShared
@testable import TritonKitCLI

extension SchemaFactSourceTests {
    @Test("capability reason and next-action keep stable recovery transitions")
    func capabilityReasonAndNextActionKeepStableRecoveryTransitions() throws {
        let requiresRuntime = "Requires connected embedded TritonKit runtime"
        let requiresWebViewProvider = "Requires WebView provider metadata from embedded runtime or --runtime-base-url"

        let connected = connectedCapabilityMap()
        let disconnected = disconnectedCapabilityMap()
        let unavailableServer = unavailableServerCapabilityMap()
        let schemaCapabilities = Set(commandSchemas().flatMap(\.providedCapabilities))

        var runtimeReasonDisconnectedUnexpectedRecovery: [String] = []
        var runtimeReasonUnavailableUnexpectedRecovery: [String] = []
        var runtimeReasonConnectedReasonLeak: [String] = []

        var webviewReasonDisconnectedUnexpectedRecovery: [String] = []
        var webviewReasonUnavailableUnexpectedRecovery: [String] = []
        var webviewReasonConnectedReasonLeak: [String] = []

        for capabilityName in schemaCapabilities.sorted() {
            guard let connectedCapability = connected[capabilityName],
                  let disconnectedCapability = disconnected[capabilityName],
                  let unavailableServerCapability = unavailableServer[capabilityName] else {
                continue
            }

            if disconnectedCapability.reason == requiresRuntime {
                if connectedCapability.reason != nil {
                    runtimeReasonConnectedReasonLeak.append("\(capabilityName):connected=\(connectedCapability.reason ?? "nil")")
                }

                let disconnectedAction = disconnectedCapability.nextAction
                let unavailableAction = unavailableServerCapability.nextAction
                let connectedAction = connectedCapability.nextAction

                if disconnectedAction?.command == "status" {
                    if unavailableAction?.command != "serve" ||
                        unavailableAction?.args != ["--host", "127.0.0.1", "--port", "19421"] ||
                        unavailableAction?.requiresLongRunningProcess != true {
                        runtimeReasonUnavailableUnexpectedRecovery.append(
                            "\(capabilityName):expected=serve:actual=\(unavailableAction?.command ?? "nil"):\(unavailableAction?.args ?? [])"
                        )
                    }
                } else {
                    if disconnectedAction?.command != connectedAction?.command ||
                        disconnectedAction?.args != connectedAction?.args ||
                        disconnectedAction?.requiresLongRunningProcess == true {
                        runtimeReasonDisconnectedUnexpectedRecovery.append(
                            "\(capabilityName):expected-connected-action:actual=\(disconnectedAction?.command ?? "nil"):\(disconnectedAction?.args ?? [])"
                        )
                    }
                    if unavailableAction?.command != disconnectedAction?.command ||
                        unavailableAction?.args != disconnectedAction?.args ||
                        unavailableAction?.requiresLongRunningProcess == true {
                        runtimeReasonUnavailableUnexpectedRecovery.append(
                            "\(capabilityName):expected-disconnected-action:actual=\(unavailableAction?.command ?? "nil"):\(unavailableAction?.args ?? [])"
                        )
                    }
                }
            }

            if disconnectedCapability.reason == requiresWebViewProvider {
                if connectedCapability.reason != nil {
                    webviewReasonConnectedReasonLeak.append("\(capabilityName):connected=\(connectedCapability.reason ?? "nil")")
                }

                let disconnectedAction = disconnectedCapability.nextAction
                let unavailableAction = unavailableServerCapability.nextAction
                let connectedAction = connectedCapability.nextAction

                if disconnectedAction?.command == "serve" || disconnectedAction?.command == "status" {
                    webviewReasonDisconnectedUnexpectedRecovery.append(
                        "\(capabilityName):unexpected-disconnected-command=\(disconnectedAction?.command ?? "nil")"
                    )
                }
                if unavailableAction?.command == "serve" || unavailableAction?.command == "status" {
                    webviewReasonUnavailableUnexpectedRecovery.append(
                        "\(capabilityName):unexpected-unavailable-command=\(unavailableAction?.command ?? "nil")"
                    )
                }
                if disconnectedAction?.command != connectedAction?.command ||
                    disconnectedAction?.args != connectedAction?.args ||
                    disconnectedAction?.requiresLongRunningProcess == true {
                    webviewReasonDisconnectedUnexpectedRecovery.append(
                        "\(capabilityName):expected-connected-action:actual=\(disconnectedAction?.command ?? "nil"):\(disconnectedAction?.args ?? [])"
                    )
                }
                if unavailableAction?.command != disconnectedAction?.command ||
                    unavailableAction?.args != disconnectedAction?.args ||
                    unavailableAction?.requiresLongRunningProcess == true {
                    webviewReasonUnavailableUnexpectedRecovery.append(
                        "\(capabilityName):expected-disconnected-action:actual=\(unavailableAction?.command ?? "nil"):\(unavailableAction?.args ?? [])"
                    )
                }
            }
        }

        #expect(runtimeReasonConnectedReasonLeak == [])
        #expect(runtimeReasonDisconnectedUnexpectedRecovery == [])
        #expect(runtimeReasonUnavailableUnexpectedRecovery == [])
        #expect(webviewReasonConnectedReasonLeak == [])
        #expect(webviewReasonDisconnectedUnexpectedRecovery == [])
        #expect(webviewReasonUnavailableUnexpectedRecovery == [])
    }

    @Test("capability reason text stays bidirectionally aligned with capability families")
    func capabilityReasonTextStaysBidirectionallyAlignedWithCapabilityFamilies() throws {
        let requiresRuntime = "Requires connected embedded TritonKit runtime"
        let requiresWebViewProvider = "Requires WebView provider metadata from embedded runtime or --runtime-base-url"
        let harmonyClearBoundary = "Host-side Harmony clear is not available in the current adapter"
        let pressBoundary = "Host-side HID is not available in the embedded runtime"

        let runtimeReasonCapabilities = Set([
            "runtime-manifest", "state-app", "state-scene", "state-route", "state-responder",
            "snapshot", "focus", "set-text", "select-segment", "set-switch", "semantic-action", "ledger",
            "observe-ios",
            "inspect", "hierarchy", "nodes", "node", "attrs", "object",
            "export-json", "export-archive", "geometry", "ax", "hit", "screenshot",
            "wait", "capture", "assert", "verify", "verify-text-exists", "verify-text-not-exists", "replay",
            "act", "tap", "swipe", "type", "paste", "clear", "input",
        ])
        let webviewProviderReasonCapabilities = Set([
            "webview-current-url", "webview-snapshot", "webview-bridge-call",
            "webview-events", "webview-wait", "webview-aware-tap", "route-current-url-assert",
        ])

        let connected = connectedCapabilityMap()
        let disconnected = disconnectedCapabilityMap()
        let unavailableServer = unavailableServerCapabilityMap()

        var runtimeReasonToWrongFamily: [String] = []
        var webviewReasonToWrongFamily: [String] = []
        var harmonyClearReasonToWrongFamily: [String] = []
        var pressReasonToWrongFamily: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                switch capability.reason {
                case requiresRuntime:
                    if !runtimeReasonCapabilities.contains(capability.name) {
                        runtimeReasonToWrongFamily.append("\(fixture.name):\(capability.name)")
                    }
                case requiresWebViewProvider:
                    if !webviewProviderReasonCapabilities.contains(capability.name) {
                        webviewReasonToWrongFamily.append("\(fixture.name):\(capability.name)")
                    }
                case harmonyClearBoundary:
                    if capability.name != "harmony-clear-text" {
                        harmonyClearReasonToWrongFamily.append("\(fixture.name):\(capability.name)")
                    }
                case pressBoundary:
                    if capability.name != "press" {
                        pressReasonToWrongFamily.append("\(fixture.name):\(capability.name)")
                    }
                default:
                    break
                }
            }
        }

        #expect(runtimeReasonToWrongFamily == [])
        #expect(webviewReasonToWrongFamily == [])
        #expect(harmonyClearReasonToWrongFamily == [])
        #expect(pressReasonToWrongFamily == [])

        var runtimeFamilyMissingReason: [String] = []
        var webviewFamilyMissingReason: [String] = []
        var boundaryReasonDrift: [String] = []

        for capabilityName in runtimeReasonCapabilities.sorted() {
            let connectedCapability = try #require(connected[capabilityName])
            let disconnectedCapability = try #require(disconnected[capabilityName])
            let unavailableCapability = try #require(unavailableServer[capabilityName])

            if connectedCapability.reason != nil {
                runtimeFamilyMissingReason.append("runtime-connected:\(capabilityName):reason=\(connectedCapability.reason ?? "nil")")
            }
            if disconnectedCapability.reason != requiresRuntime {
                runtimeFamilyMissingReason.append("runtime-disconnected:\(capabilityName):reason=\(disconnectedCapability.reason ?? "nil")")
            }
            if unavailableCapability.reason != requiresRuntime {
                runtimeFamilyMissingReason.append("server-unreachable:\(capabilityName):reason=\(unavailableCapability.reason ?? "nil")")
            }
        }

        for capabilityName in webviewProviderReasonCapabilities.sorted() {
            let connectedCapability = try #require(connected[capabilityName])
            let disconnectedCapability = try #require(disconnected[capabilityName])
            let unavailableCapability = try #require(unavailableServer[capabilityName])

            if connectedCapability.reason != nil {
                webviewFamilyMissingReason.append("runtime-connected:\(capabilityName):reason=\(connectedCapability.reason ?? "nil")")
            }
            if disconnectedCapability.reason != requiresWebViewProvider {
                webviewFamilyMissingReason.append("runtime-disconnected:\(capabilityName):reason=\(disconnectedCapability.reason ?? "nil")")
            }
            if unavailableCapability.reason != requiresWebViewProvider {
                webviewFamilyMissingReason.append("server-unreachable:\(capabilityName):reason=\(unavailableCapability.reason ?? "nil")")
            }
        }

        for fixture in capabilityStateFixtures() {
            let map = Dictionary(uniqueKeysWithValues: fixture.capabilities.map { ($0.name, $0) })
            let press = try #require(map["press"])
            let harmonyClear = try #require(map["harmony-clear-text"])
            if press.reason != pressBoundary {
                boundaryReasonDrift.append("\(fixture.name):press:\(press.reason ?? "nil")")
            }
            if harmonyClear.reason != harmonyClearBoundary {
                boundaryReasonDrift.append("\(fixture.name):harmony-clear-text:\(harmonyClear.reason ?? "nil")")
            }
        }

        #expect(runtimeFamilyMissingReason == [])
        #expect(webviewFamilyMissingReason == [])
        #expect(boundaryReasonDrift == [])
    }

    @Test("capability reason families stay aligned with group workflow and evidence taxonomies")
    func capabilityReasonFamiliesStayAlignedWithGroupWorkflowAndEvidenceTaxonomies() throws {
        let requiresRuntime = "Requires connected embedded TritonKit runtime"
        let requiresWebViewProvider = "Requires WebView provider metadata from embedded runtime or --runtime-base-url"
        let harmonyClearBoundary = "Host-side Harmony clear is not available in the current adapter"
        let pressBoundary = "Host-side HID is not available in the embedded runtime"

        let runtimeReasonGroups = Set(["runtime", "observe", "assert", "evidence", "replay", "action"])
        let webviewReasonGroups = Set(["webview", "route", "action"])
        let webviewEvidenceKeys = Set([
            "webview-provider", "provider-url", "webview-snapshot",
            "bridge-call-result", "page-events", "wait-samples", "act.webview-aware-tap", "route-assertion",
        ])

        let fixtures: [(name: String, map: [String: TKRuntimeCapability])] = [
            ("runtime-disconnected", disconnectedCapabilityMap()),
            ("server-unreachable", unavailableServerCapabilityMap()),
        ]

        var runtimeReasonGroupMismatches: [String] = []
        var runtimeReasonWorkflowMismatches: [String] = []
        var runtimeReasonEvidenceMismatches: [String] = []

        var webviewReasonGroupMismatches: [String] = []
        var webviewReasonWorkflowMismatches: [String] = []
        var webviewReasonEvidenceMismatches: [String] = []

        var boundaryReasonTaxonomyMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.map.values {
                switch capability.reason {
                case requiresRuntime:
                    if let group = capability.group {
                        if !runtimeReasonGroups.contains(group) {
                            runtimeReasonGroupMismatches.append("\(fixture.name):\(capability.name):group=\(group)")
                        }
                    } else {
                        runtimeReasonGroupMismatches.append("\(fixture.name):\(capability.name):group=nil")
                    }
                    if capability.requiredBy.contains("webview-check") {
                        runtimeReasonWorkflowMismatches.append("\(fixture.name):\(capability.name):requiredBy=\(capability.requiredBy)")
                    }
                    let evidence = Set(capability.evidence)
                    if evidence.isEmpty || !evidence.isDisjoint(with: webviewEvidenceKeys) {
                        runtimeReasonEvidenceMismatches.append("\(fixture.name):\(capability.name):evidence=\(capability.evidence)")
                    }

                case requiresWebViewProvider:
                    if let group = capability.group {
                        if !webviewReasonGroups.contains(group) {
                            webviewReasonGroupMismatches.append("\(fixture.name):\(capability.name):group=\(group)")
                        }
                    } else {
                        webviewReasonGroupMismatches.append("\(fixture.name):\(capability.name):group=nil")
                    }
                    let requiredBy = Set(capability.requiredBy)
                    let hasExpectedWorkflow = capability.group == "action"
                        ? requiredBy.isSuperset(of: ["action", "assert", "evidence"])
                        : requiredBy.isSuperset(of: ["webview-check", "assert", "evidence"])
                    if !hasExpectedWorkflow {
                        webviewReasonWorkflowMismatches.append("\(fixture.name):\(capability.name):requiredBy=\(capability.requiredBy)")
                    }
                    let evidence = Set(capability.evidence)
                    if !evidence.contains("webview-provider") {
                        webviewReasonEvidenceMismatches.append("\(fixture.name):\(capability.name):evidence=\(capability.evidence)")
                    }

                case harmonyClearBoundary:
                    if capability.group != "action" ||
                        !capability.requiredBy.contains("action") ||
                        !capability.requiredBy.contains("assert") ||
                        !capability.requiredBy.contains("evidence") ||
                        Set(capability.evidence) != Set(["unsupported-envelope", "command-schema"]) {
                        boundaryReasonTaxonomyMismatches.append("\(fixture.name):\(capability.name):group=\(capability.group ?? "nil"):requiredBy=\(capability.requiredBy):evidence=\(capability.evidence)")
                    }

                case pressBoundary:
                    if capability.group != "action" ||
                        !capability.requiredBy.contains("action") ||
                        !capability.requiredBy.contains("assert") ||
                        !capability.requiredBy.contains("evidence") ||
                        Set(capability.evidence) != Set(["unsupported-envelope", "command-schema"]) {
                        boundaryReasonTaxonomyMismatches.append("\(fixture.name):\(capability.name):group=\(capability.group ?? "nil"):requiredBy=\(capability.requiredBy):evidence=\(capability.evidence)")
                    }

                default:
                    break
                }
            }
        }

        #expect(runtimeReasonGroupMismatches == [])
        #expect(runtimeReasonWorkflowMismatches == [])
        #expect(runtimeReasonEvidenceMismatches == [])
        #expect(webviewReasonGroupMismatches == [])
        #expect(webviewReasonWorkflowMismatches == [])
        #expect(webviewReasonEvidenceMismatches == [])
        #expect(boundaryReasonTaxonomyMismatches == [])
    }

    @Test("capability requiredBy lanes stay aligned with next-action categories")
    func capabilityRequiredByLanesStayAlignedWithNextActionCategories() throws {
        let fixtures: [(name: String, capabilities: [TKRuntimeCapability])] = capabilityStateFixtures()

        var webviewCheckLaneMismatches: [String] = []
        var xcodeProjectLaneMismatches: [String] = []
        var smokeLaneMismatches: [String] = []
        var routeLaneMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let category = nextAction.category
                let requiredBy = capability.requiredBy
                let descriptor = "\(fixture.name):\(capability.name):category=\(category):requiredBy=\(requiredBy)"

                if requiredBy.contains("webview-check") &&
                    !Set(["observe", "verify"]).contains(category) {
                    webviewCheckLaneMismatches.append(descriptor)
                }

                if (requiredBy.contains("xcode") || requiredBy.contains("project")) &&
                    !Set(["project", "archive"]).contains(category) {
                    xcodeProjectLaneMismatches.append(descriptor)
                }

                if capability.name.hasPrefix("smoke-") && requiredBy.contains("smoke") &&
                    category != "smoke" {
                    smokeLaneMismatches.append(descriptor)
                }

                if (requiredBy.contains("route") || capability.group == "route") &&
                    !Set(["observe", "verify"]).contains(category) {
                    routeLaneMismatches.append(descriptor)
                }
            }
        }

        #expect(webviewCheckLaneMismatches == [])
        #expect(xcodeProjectLaneMismatches == [])
        #expect(smokeLaneMismatches == [])
        #expect(routeLaneMismatches == [])
    }

    @Test("capability group stays aligned with next-action root commands")
    func capabilityGroupStaysAlignedWithNextActionRootCommands() {
        let allowedRootsByGroup: [String: Set<String>] = [
            "bootstrap": ["status", "doctor", "capabilities", "schema", "plan", "record", "replay", "serve", "web", "update"],
            "target": ["target"],
            "runtime": ["debug", "act", "schema", "status", "serve"],
            "host": ["debug", "device", "sim", "app", "schema"],
            "observe": ["debug", "act", "observe", "node", "list", "inspect", "export", "screenshot", "wait", "status", "serve"],
            "webview": ["webview"],
            "route": ["route"],
            "evidence": ["evidence", "map", "vlm", "device", "status", "serve"],
            "assert": ["assert", "verify", "status", "serve"],
            "replay": ["plan", "status", "serve"],
            "smoke": ["smoke"],
            "action": ["act", "action", "tap", "swipe", "type", "paste", "clear", "press", "input", "wait", "schema", "status", "serve"],
            "test": ["test", "testrec", "schema"],
            "xcode": ["xcode", "xcresult", "xctrace", "coverage"],
        ]

        var unknownGroups: [String] = []
        var mismatchedRoots: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                guard let group = capability.group else {
                    continue
                }
                guard let nextAction = capability.nextAction else {
                    continue
                }
                guard let allowedRoots = allowedRootsByGroup[group] else {
                    unknownGroups.append("\(fixture.name):\(capability.name):group=\(group)")
                    continue
                }
                let root = nextAction.command
                if !allowedRoots.contains(root) {
                    mismatchedRoots.append("\(fixture.name):\(capability.name):group=\(group):root=\(root)")
                }
            }
        }

        #expect(unknownGroups == [])
        #expect(mismatchedRoots == [])
    }

    @Test("capability next-action args keep lane-specific placeholder semantics")
    func capabilityNextActionArgsKeepLaneSpecificPlaceholderSemantics() {
        let fixtures = capabilityStateFixtures()

        var webviewCheckTemplateMismatches: [String] = []
        var routeTemplateMismatches: [String] = []
        var smokeTemplateMismatches: [String] = []
        let webviewCheckNeedsURLOrTextPlaceholders: Set<String> = [
            "route-current-url-assert",
            "webview-wait",
        ]
        let webviewCheckNeedsMethodPlaceholder: Set<String> = [
            "webview-bridge-call",
        ]

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let argSet = Set(args)
                let context = "\(fixture.name):\(capability.name)"

                if capability.requiredBy.contains("webview-check") {
                    if webviewCheckNeedsURLOrTextPlaceholders.contains(capability.name) {
                        let hasURLOrTextPlaceholder =
                            argSet.contains("<expected-url>") ||
                            argSet.contains("<url>") ||
                            argSet.contains("<text>")
                        if !hasURLOrTextPlaceholder {
                            webviewCheckTemplateMismatches.append("\(context):args=\(args)")
                        }
                    }

                    if webviewCheckNeedsMethodPlaceholder.contains(capability.name) && !argSet.contains("<method>") {
                        webviewCheckTemplateMismatches.append("\(context):args=\(args)")
                    }
                }

                if capability.group == "route" || capability.requiredBy.contains("route") {
                    if nextAction.command == "route" && !argSet.contains("<expected-url>") {
                        routeTemplateMismatches.append("\(context):args=\(args)")
                    }
                }

                if capability.name == "smoke-ios" {
                    let required = Set(["ios", "<device>", "<bundle-id>", "<url>", "<text>"])
                    if !required.isSubset(of: argSet) {
                        smokeTemplateMismatches.append("\(context):args=\(args)")
                    }
                }
                if capability.name == "smoke-harmony" {
                    let required = Set(["harmony", "<device>", "<bundle>", "<ability>", "<text>"])
                    if !required.isSubset(of: argSet) {
                        smokeTemplateMismatches.append("\(context):args=\(args)")
                    }
                }
            }
        }

        #expect(webviewCheckTemplateMismatches == [])
        #expect(routeTemplateMismatches == [])
        #expect(smokeTemplateMismatches == [])
    }

    @Test("capability groups keep machine-readable next-action output flags")
    func capabilityGroupsKeepMachineReadableNextActionOutputFlags() {
        let fixtures = capabilityStateFixtures()
        let schemas = commandSchemaMap()

        var missingMachineReadableFlags: [String] = []
        var screenshotObserveMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let argSet = Set(args)
                let context = "\(fixture.name):\(capability.name):group=\(capability.group ?? "nil"):command=\(nextAction.command):args=\(args)"

                if nextAction.command == "serve" {
                    continue
                }

                let hasJSONFlag = argSet.contains("--json") || argSet.contains("--jsonl")
                let hasPlanFormatJSON = args.contains("--format") && args.contains("json")
                let hasScreenshotMetadata = argSet.contains("--metadata")
                let defaultsToJSON = schemas[nextAction.command]?.options.contains {
                    $0.name == "--format" && $0.defaultValue == "json"
                } == true
                if !(hasJSONFlag || hasPlanFormatJSON || hasScreenshotMetadata || defaultsToJSON) {
                    missingMachineReadableFlags.append(context)
                }

                if capability.group == "observe" && nextAction.command == "screenshot" {
                    if !argSet.contains("--metadata") || !argSet.contains("<path.png>") {
                        screenshotObserveMismatches.append(context)
                    }
                }
            }
        }

        #expect(missingMachineReadableFlags == [])
        #expect(screenshotObserveMismatches == [])
    }

    @Test("capability next-action output placeholders stay artifact-typed and explicit")
    func capabilityNextActionOutputPlaceholdersStayArtifactTypedAndExplicit() {
        let fixtures = capabilityStateFixtures()

        let expectedOutputPlaceholdersByCapability: [String: [String]] = [
            "record": ["<file.tritonplan>"],
            "device-screenshot": ["<path>"],
            "host-device-screenshot": ["<path>"],
            "ios-screenshot": ["<path>"],
            "ios-device-screenshot": ["<path>"],
            "android-device-screenshot": ["<path>"],
            "harmony-screenshot": ["<path>"],
            "harmony-device-screenshot": ["<path>"],
            "sim-video": ["<path.mov>"],
            "sim-logs": ["<path.ndjson>"],
            "sim-app-process-console": ["<path.log>"],
            "sim-diagnostics": ["<path>"],
            "capture": ["<dir.tritonevidence>"],
            "evidence": ["<dir.tritonevidence>"],
            "evidence-ingest": ["<dir.tritonevidence>"],
            "evidence-redact": ["<safe.tritonevidence>"],
            "network-capture-export": ["<path.har|path.ndjson>"],
            "screenshot": ["<path.png>"],
            "app-map-viewer": ["<file.html>"],
            "test-create-from-session": ["<path.tritontest.yaml>"],
            "testrec-session-start": ["<case.tritontestcase>"],
        ]

        var unknownOutputCapabilities: [String] = []
        var outputPlaceholderMismatches: [String] = []
        var nonPlaceholderOutputs: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let outputValues = args.enumerated().compactMap { index, arg -> String? in
                    guard arg == "--output", args.indices.contains(index + 1) else {
                        return nil
                    }
                    return args[index + 1]
                }

                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"
                if outputValues.contains(where: { !$0.hasPrefix("<") || !$0.hasSuffix(">") }) {
                    nonPlaceholderOutputs.append(context)
                }

                guard !outputValues.isEmpty else {
                    continue
                }

                guard let expected = expectedOutputPlaceholdersByCapability[capability.name] else {
                    unknownOutputCapabilities.append(context)
                    continue
                }
                if outputValues != expected {
                    outputPlaceholderMismatches.append("\(context):expected=\(expected)")
                }
            }
        }

        #expect(unknownOutputCapabilities == [])
        #expect(outputPlaceholderMismatches == [])
        #expect(nonPlaceholderOutputs == [])
    }

    @Test("capability next-action target selector placeholders stay canonical")
    func capabilityNextActionTargetSelectorPlaceholdersStayCanonical() {
        let fixtures = capabilityStateFixtures()

        var deviceSelectorMismatches: [String] = []
        var simulatorSelectorMismatches: [String] = []
        var bundleIDPlaceholderMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"

                for (index, arg) in args.enumerated() where arg == "--device" {
                    guard args.indices.contains(index + 1) else {
                        deviceSelectorMismatches.append("\(context):missing-device-value")
                        continue
                    }
                    let actual = args[index + 1]
                    let expected = nextAction.command == "smoke" ? "<device>" : "<selector>"
                    if actual != expected {
                        deviceSelectorMismatches.append("\(context):expected=\(expected):actual=\(actual)")
                    }
                }

                for (index, arg) in args.enumerated() where arg == "--simulator" {
                    guard args.indices.contains(index + 1) else {
                        simulatorSelectorMismatches.append("\(context):missing-simulator-value")
                        continue
                    }
                    let actual = args[index + 1]
                    if actual != "<udid|booted>" {
                        simulatorSelectorMismatches.append("\(context):expected=<udid|booted>:actual=\(actual)")
                    }
                }

                for (index, arg) in args.enumerated() where arg == "--bundle-id" {
                    guard args.indices.contains(index + 1) else {
                        bundleIDPlaceholderMismatches.append("\(context):missing-bundle-id-value")
                        continue
                    }
                    let actual = args[index + 1]
                    if actual != "<bundle-id>" {
                        bundleIDPlaceholderMismatches.append("\(context):expected=<bundle-id>:actual=\(actual)")
                    }
                }
            }
        }

        #expect(deviceSelectorMismatches == [])
        #expect(simulatorSelectorMismatches == [])
        #expect(bundleIDPlaceholderMismatches == [])
    }

    @Test("capability next-action platform flags stay canonical and family-aligned")
    func capabilityNextActionPlatformFlagsStayCanonicalAndFamilyAligned() {
        let fixtures = capabilityStateFixtures()

        var unsupportedPlatformValues: [String] = []
        var harmonyFamilyPlatformMismatches: [String] = []
        var iosFamilyPlatformMismatches: [String] = []
        var androidFamilyPlatformMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"

                let platformValues = args.enumerated().compactMap { index, arg -> String? in
                    guard arg == "--platform", args.indices.contains(index + 1) else {
                        return nil
                    }
                    return args[index + 1]
                }

                for value in platformValues where !Set(["ios", "android", "harmony"]).contains(value) {
                    if ["network-capture-export", "network-certificate-plan", "network-certificate-install"].contains(capability.name), value == "<platform>" {
                        continue
                    }
                    unsupportedPlatformValues.append("\(context):platform=\(value)")
                }

                if capability.name.hasPrefix("harmony-") {
                    if !platformValues.isEmpty && !platformValues.allSatisfy({ $0 == "harmony" }) {
                        harmonyFamilyPlatformMismatches.append("\(context):platforms=\(platformValues)")
                    }
                }

                if capability.name.hasPrefix("ios-") || capability.name == "observe-ios" {
                    if !platformValues.isEmpty && !platformValues.allSatisfy({ $0 == "ios" }) {
                        iosFamilyPlatformMismatches.append("\(context):platforms=\(platformValues)")
                    }
                }

                if capability.name.hasPrefix("android-") {
                    if !platformValues.isEmpty && !platformValues.allSatisfy({ $0 == "android" }) {
                        androidFamilyPlatformMismatches.append("\(context):platforms=\(platformValues)")
                    }
                }
            }
        }

        #expect(unsupportedPlatformValues == [])
        #expect(harmonyFamilyPlatformMismatches == [])
        #expect(iosFamilyPlatformMismatches == [])
        #expect(androidFamilyPlatformMismatches == [])
    }

    @Test("capability next-action text placeholders stay canonical")
    func capabilityNextActionTextPlaceholdersStayCanonical() {
        let fixtures = capabilityStateFixtures()

        var textFlagPlaceholderMismatches: [String] = []
        var waitTextFlagPlaceholderMismatches: [String] = []
        var assertTextExistsPlaceholderMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"

                for (index, arg) in args.enumerated() where arg == "--text" {
                    guard args.indices.contains(index + 1) else {
                        textFlagPlaceholderMismatches.append("\(context):missing-text-value")
                        continue
                    }
                    if args[index + 1] != "<text>" {
                        textFlagPlaceholderMismatches.append("\(context):expected=<text>:actual=\(args[index + 1])")
                    }
                }

                for (index, arg) in args.enumerated() where arg == "--wait-text" {
                    guard args.indices.contains(index + 1) else {
                        waitTextFlagPlaceholderMismatches.append("\(context):missing-wait-text-value")
                        continue
                    }
                    if args[index + 1] != "<text>" {
                        waitTextFlagPlaceholderMismatches.append("\(context):expected=<text>:actual=\(args[index + 1])")
                    }
                }

                if nextAction.command == "assert",
                   let textExistsIndex = args.firstIndex(of: "text-exists") {
                    guard args.indices.contains(textExistsIndex + 1) else {
                        assertTextExistsPlaceholderMismatches.append("\(context):missing-assert-text")
                        continue
                    }
                    if args[textExistsIndex + 1] != "<text>" {
                        assertTextExistsPlaceholderMismatches.append("\(context):expected=<text>:actual=\(args[textExistsIndex + 1])")
                    }
                }
            }
        }

        #expect(textFlagPlaceholderMismatches == [])
        #expect(waitTextFlagPlaceholderMismatches == [])
        #expect(assertTextExistsPlaceholderMismatches == [])
    }

    @Test("capability next-action url placeholders stay canonical")
    func capabilityNextActionURLPlaceholdersStayCanonical() {
        let fixtures = capabilityStateFixtures()

        var urlFlagPlaceholderMismatches: [String] = []
        var openURLFlagPlaceholderMismatches: [String] = []
        var appOpenURLArgumentMismatches: [String] = []
        var routeAssertCurrentURLArgumentMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"

                for (index, arg) in args.enumerated() where arg == "--url" {
                    guard args.indices.contains(index + 1) else {
                        urlFlagPlaceholderMismatches.append("\(context):missing-url-value")
                        continue
                    }
                    if args[index + 1] != "<url>" {
                        urlFlagPlaceholderMismatches.append("\(context):expected=<url>:actual=\(args[index + 1])")
                    }
                }

                for (index, arg) in args.enumerated() where arg == "--open-url" {
                    guard args.indices.contains(index + 1) else {
                        openURLFlagPlaceholderMismatches.append("\(context):missing-open-url-value")
                        continue
                    }
                    if args[index + 1] != "<url>" {
                        openURLFlagPlaceholderMismatches.append("\(context):expected=<url>:actual=\(args[index + 1])")
                    }
                }

                if nextAction.command == "app",
                   args.first == "open-url" || args.first == "go" {
                    guard args.indices.contains(1) else {
                        appOpenURLArgumentMismatches.append("\(context):missing-open-url-argument")
                        continue
                    }
                    if args[1] != "<url>" {
                        appOpenURLArgumentMismatches.append("\(context):expected=<url>:actual=\(args[1])")
                    }
                }

                if nextAction.command == "route",
                   args.first == "assert-current-url" {
                    guard args.indices.contains(1) else {
                        routeAssertCurrentURLArgumentMismatches.append("\(context):missing-expected-url-argument")
                        continue
                    }
                    if args[1] != "<expected-url>" {
                        routeAssertCurrentURLArgumentMismatches.append(
                            "\(context):expected=<expected-url>:actual=\(args[1])"
                        )
                    }
                }
            }
        }

        #expect(urlFlagPlaceholderMismatches == [])
        #expect(openURLFlagPlaceholderMismatches == [])
        #expect(appOpenURLArgumentMismatches == [])
        #expect(routeAssertCurrentURLArgumentMismatches == [])
    }

    @Test("capability names remain unique for agent indexing")
    func capabilityNamesRemainUniqueForAgentIndexing() {
        var duplicateSchemaCapabilities: [String] = []

        for schema in commandSchemas() {
            if Set(schema.providedCapabilities).count != schema.providedCapabilities.count {
                duplicateSchemaCapabilities.append(schema.name)
            }
        }

        let matrixCapabilities = connectedCapabilities().map(\.name)
        let duplicateMatrixCapabilities = Set(matrixCapabilities)
            .filter { capability in matrixCapabilities.filter { $0 == capability }.count > 1 }
            .sorted()

        #expect(duplicateSchemaCapabilities == [])
        #expect(duplicateMatrixCapabilities == [])
    }

    @Test("capability planning arrays expose nonempty unique values")
    func capabilityPlanningArraysExposeNonemptyUniqueValues() {
        var emptyRequiredBy: [String] = []
        var duplicateRequiredBy: [String] = []
        var emptyEvidence: [String] = []
        var duplicateEvidence: [String] = []

        let capabilities = connectedCapabilities()

        for capability in capabilities {
            if capability.requiredBy.contains(where: \.isEmpty) {
                emptyRequiredBy.append(capability.name)
            }
            if Set(capability.requiredBy).count != capability.requiredBy.count {
                duplicateRequiredBy.append(capability.name)
            }
            if capability.evidence.contains(where: \.isEmpty) {
                emptyEvidence.append(capability.name)
            }
            if Set(capability.evidence).count != capability.evidence.count {
                duplicateEvidence.append(capability.name)
            }
        }

        #expect(emptyRequiredBy == [])
        #expect(duplicateRequiredBy == [])
        #expect(emptyEvidence == [])
        #expect(duplicateEvidence == [])
    }

    @Test("capability groups stay within the agent taxonomy")
    func capabilityGroupsStayWithinTheAgentTaxonomy() {
        let capabilities = connectedCapabilities()
        let unknownGroups = capabilities
            .filter { !capabilityGroupTaxonomy().contains($0.group ?? "") }
            .map { "\($0.name):\($0.group ?? "nil")" }
            .sorted()

        #expect(unknownGroups == [])
    }

    @Test("capability requiredBy values stay within the workflow taxonomy")
    func capabilityRequiredByValuesStayWithinTheWorkflowTaxonomy() {
        let capabilities = connectedCapabilities()
        let unknownRequiredBy = capabilities
            .flatMap { capability in
                capability.requiredBy
                    .filter { !capabilityWorkflowTaxonomy().contains($0) }
                    .map { "\(capability.name):\($0)" }
            }
            .sorted()

        #expect(unknownRequiredBy == [])
    }

    @Test("capability evidence values stay within the artifact taxonomy")
    func capabilityEvidenceValuesStayWithinTheArtifactTaxonomy() {
        let capabilities = connectedCapabilities()
        let unknownEvidence = capabilities
            .flatMap { capability in
                capability.evidence
                    .filter { !capabilityEvidenceTaxonomy().contains($0) }
                    .map { "\(capability.name):\($0)" }
            }
            .sorted()

        #expect(unknownEvidence == [])
    }

    @Test("capabilities expose at least one evidence source")
    func capabilitiesExposeAtLeastOneEvidenceSource() {
        let capabilities = connectedCapabilities()
        let missingEvidence = capabilities
            .filter(\.evidence.isEmpty)
            .map(\.name)
            .sorted()

        #expect(missingEvidence == [])
    }

    @Test("capability long-running next actions stay explicit")
    func capabilityLongRunningNextActionsStayExplicit() {
        var unexpectedLongRunningActions: [String] = []
        var missingLongRunningLifecycle: [String] = []
        var unexpectedOneShotLifecycle: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                guard let action = capability.nextAction else { continue }
                let context = "\(fixture.name):\(capability.name):\(action.command)"
                if action.requiresLongRunningProcess {
                    if action.command != "serve" || action.args != ["--host", "127.0.0.1", "--port", "19421"] {
                        unexpectedLongRunningActions.append(context)
                    }
                    if action.terminationSignals != ["sigint", "sigterm"] {
                        missingLongRunningLifecycle.append(context)
                    }
                } else if !action.readyEvents.isEmpty || !action.finalEvents.isEmpty || !action.terminationSignals.isEmpty {
                    unexpectedOneShotLifecycle.append(context)
                }
            }
        }

        #expect(unexpectedLongRunningActions == [])
        #expect(missingLongRunningLifecycle == [])
        #expect(unexpectedOneShotLifecycle == [])
    }

    @Test("capability next action placeholders are complete argv tokens")
    func capabilityNextActionPlaceholdersAreCompleteArgvTokens() {
        var malformedPlaceholders: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                for arg in capability.nextAction?.args ?? [] where arg.contains("<") || arg.contains(">") {
                    if !isCompletePlaceholderToken(arg) {
                        malformedPlaceholders.append("\(fixture.name):\(capability.name):\(arg)")
                    }
                }
            }
        }

        #expect(malformedPlaceholders == [])
    }

    @Test("capability next actions expose stable recovery categories")
    func capabilityNextActionsExposeStableRecoveryCategories() {
        var missingCategories: [String] = []
        var invalidCategories: [String] = []
        var mismatchedCategories: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                if nextAction.category.isEmpty {
                    missingCategories.append("\(fixture.name):\(capability.name)")
                }
                if !TKCommandRecoveryCommand.categoryTaxonomy.contains(nextAction.category) {
                    invalidCategories.append("\(fixture.name):\(capability.name):\(nextAction.category)")
                }
                guard let expectedCategory = TKCommandRecoveryCommand.category(forRootCommand: nextAction.command) else {
                    mismatchedCategories.append("\(fixture.name):\(capability.name):\(nextAction.command)")
                    continue
                }
                if nextAction.category != expectedCategory {
                    mismatchedCategories.append("\(fixture.name):\(capability.name):expected=\(expectedCategory):actual=\(nextAction.category)")
                }
            }
        }

        #expect(missingCategories == [])
        #expect(invalidCategories == [])
        #expect(mismatchedCategories == [])
    }

}
