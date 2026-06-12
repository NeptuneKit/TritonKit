import Darwin
import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct DeviceCrossPlatformTests {
    @Test("device schema exposes a cross-platform list/use/wait-ready/screenshot surface")
    func deviceSchemaExposesCrossPlatformSurface() throws {
        let device = try #require(commandSchemas().first { $0.name == "device" })
        let optionNames = device.options.map(\.name)
        let usageForms = device.usageForms.map(\.form)
        let outputSelectors = Set(device.outputContracts.map(\.selector))
        let proxyFields = try #require(device.outputContracts.first { $0.selector == "host.device-proxy" }?.fields.map(\.name))
        let proxyServeFields = try #require(device.outputContracts.first { $0.selector == "host.device-proxy-serve" }?.fields.map(\.name))

        #expect(usageForms.contains("doctor --platform ios|android|harmony"))
        #expect(usageForms.contains("proxy doctor --platform ios|android|harmony"))
        #expect(usageForms.contains("proxy cert doctor --platform ios|android|harmony"))
        #expect(usageForms.contains("proxy cert plan --platform ios|android|harmony --device <selector> --certificate <path.cer>"))
        #expect(usageForms.contains("proxy cert install --platform ios|android --device <selector> --certificate <path.cer> --confirm --audit-record <id> --execute-runner"))
        #expect(usageForms.contains("proxy probe --platform ios|android|harmony --device <selector>"))
        #expect(usageForms.contains("proxy probe --platform ios|android|harmony --device <selector> --plan-only"))
        #expect(usageForms.contains("proxy serve --listen <host:port> --output <dir> --mode record|mock|block|throttle --jsonl"))
        #expect(usageForms.contains("proxy start --platform ios|android|harmony --device <selector> --mode record|mock|block|throttle --output <dir>"))
        #expect(usageForms.contains("proxy start --platform ios|android|harmony --device <selector> --mode record|mock|block|throttle --output <dir> --plan-only"))
        #expect(usageForms.contains("proxy start --platform ios|android --device <selector> --mode record|mock|block|throttle --output <dir> --confirm --audit-record <id> --execute-runner"))
        #expect(usageForms.contains("proxy status --platform ios|android|harmony --device <selector>"))
        #expect(usageForms.contains("proxy export --platform ios|android|harmony --device <selector> --output <path.har|path.ndjson>"))
        #expect(usageForms.contains("proxy export --platform ios|android|harmony --device <selector> --output <path.har|path.ndjson> --plan-only"))
        #expect(usageForms.contains("proxy stop --platform ios|android|harmony --device <selector> --restore"))
        #expect(usageForms.contains("proxy stop --platform ios|android|harmony --device <selector> --restore --plan-only"))
        #expect(usageForms.contains("proxy stop --platform ios|android --device <selector> --restore-snapshot <path> --plan-only"))
        #expect(usageForms.contains("proxy stop --platform ios|android --device <selector> --restore --confirm --audit-record <id> --execute-runner"))
        #expect(usageForms.contains("list --platform ios|android|harmony"))
        #expect(usageForms.contains("list --platform ios|android|harmony --scope real"))
        #expect(usageForms.contains("alias set <name> --platform ios|android|harmony --target <id>"))
        #expect(usageForms.contains("use <selector>"))
        #expect(usageForms.contains("current"))
        #expect(usageForms.contains("resolve <selector>"))
        #expect(usageForms.contains("wait-ready --device <selector>"))
        #expect(usageForms.contains("screenshot --device <selector> --output <path>"))
        #expect(usageForms.contains("runtime-url --device <selector>"))
        #expect(usageForms.contains("stop --platform harmony --hvd <name> --path <deployed-path> --confirm"))
        #expect(optionNames.contains("--device"))
        #expect(optionNames.contains("--plan-only"))
        #expect(optionNames.contains("--proxy"))
        #expect(optionNames.contains("--listen"))
        #expect(optionNames.contains("--execute-runner"))
        #expect(optionNames.contains("--session"))
        #expect(optionNames.contains("--certificate"))
        #expect(optionNames.contains("--jsonl"))
        #expect(optionNames.contains("--scope"))
        #expect(optionNames.contains("--name"))
        #expect(optionNames.contains("--runtime"))
        #expect(device.examples.contains("triton device list --platform android --scope real --json"))
        #expect(device.examples.contains("triton device wait-ready --platform android --scope real --device <android-real-target> --json"))
        #expect(usageForms.contains("runtime-url --platform harmony --target <target>"))
        #expect(device.examples.contains("triton device runtime-url --device harmony-a --probe-manifest --json"))
        #expect(device.examples.contains("triton device stop --platform harmony --hvd 'Codex Test Phone' --path ~/.Huawei/Emulator/deployed --confirm --json"))
        #expect(device.examples.contains("triton device proxy doctor --platform ios --json"))
        #expect(device.examples.contains("triton device proxy cert doctor --platform ios --json"))
        #expect(device.examples.contains("triton device proxy cert plan --platform android --device emulator-5554 --certificate /tmp/triton-proxy-ca.cer --json"))
        #expect(device.examples.contains("triton device proxy cert install --platform ios --device booted --certificate /tmp/triton-proxy-ca.cer --confirm --audit-record ticket-123 --execute-runner --json"))
        #expect(device.examples.contains("triton device proxy probe --platform harmony --device harmony-a --json"))
        #expect(device.examples.contains("triton device proxy probe --platform harmony --device harmony-a --plan-only --json"))
        #expect(device.examples.contains("triton device proxy serve --listen 127.0.0.1:19431 --output /tmp/triton-network --mode record --jsonl"))
        #expect(device.examples.contains("triton device proxy serve --listen 127.0.0.1:19431 --output /tmp/triton-network-mock --mode mock --jsonl"))
        #expect(device.examples.contains("triton device proxy serve --listen 127.0.0.1:19431 --output /tmp/triton-network-block --mode block --jsonl"))
        #expect(device.examples.contains("triton device proxy serve --listen 127.0.0.1:19431 --output /tmp/triton-network-throttle --mode throttle --jsonl"))
        #expect(device.examples.contains("triton device proxy start --platform android --device android-a --mode record --output /tmp/android-network --json"))
        #expect(device.examples.contains("triton device proxy status --platform harmony --device harmony-a --json"))
        #expect(device.examples.contains("triton device proxy export --platform ios --device iphone15 --output /tmp/network.har --json"))
        #expect(device.examples.contains("triton device proxy export --platform android --device emulator-5554 --session /tmp/android-network --output /tmp/network.ndjson --json"))
        #expect(device.examples.contains("triton device proxy stop --platform ios --device iphone15 --restore --json"))
        #expect(device.examples.contains("triton device proxy start --platform ios --device booted --mode record --output /tmp/ios-network --confirm --audit-record ticket-123 --execute-runner --json"))
        #expect(device.jsonlEvents.contains("proxy.serve.ready"))
        #expect(device.jsonlEvents.contains("proxy.serve.request"))
        #expect(device.jsonlEvents.contains("proxy.serve.connection-failed"))
        #expect(device.jsonlEvents.contains("proxy.serve.summary"))
        #expect(device.finalEventKind == "proxy.serve.summary")
        #expect(device.providedCapabilities.contains("host-device"))
        #expect(device.providedCapabilities.contains("device-alias"))
        #expect(device.providedCapabilities.contains("host-device-selector"))
        #expect(device.providedCapabilities.contains("device-list"))
        #expect(device.providedCapabilities.contains("device-use"))
        #expect(device.providedCapabilities.contains("device-wait-ready"))
        #expect(device.providedCapabilities.contains("device-screenshot"))
        #expect(device.providedCapabilities.contains("android-device"))
        #expect(device.providedCapabilities.contains("android-device-list"))
        #expect(device.providedCapabilities.contains("android-device-wait-ready"))
        #expect(device.providedCapabilities.contains("android-device-screenshot"))
        #expect(device.failureCodes.contains("android_debugging_disabled"))
        #expect(device.failureCodes.contains("android_package_manager_unavailable"))
        #expect(device.providedCapabilities.contains("harmony-device-stop"))
        #expect(device.providedCapabilities.contains("device-proxy-ios"))
        #expect(device.providedCapabilities.contains("device-proxy-android"))
        #expect(device.providedCapabilities.contains("device-proxy-harmony"))
        #expect(device.providedCapabilities.contains("network-capture-export"))
        #expect(device.providedCapabilities.contains("network-certificate-plan"))
        #expect(device.providedCapabilities.contains("network-certificate-install"))
        #expect(device.failureCodes.contains("proxy_visibility_limited"))
        #expect(device.failureCodes.contains("proxy_cert_untrusted"))
        #expect(device.failureCodes.contains("proxy_platform_not_supported"))
        #expect(device.failureCodes.contains("proxy_real_device_not_supported"))
        #expect(device.failureCodes.contains("proxy_runner_not_configured"))
        #expect(device.failureCodes.contains("proxy_unverified_platform_proxy"))
        #expect(device.failureCodes.contains("destructive_action_requires_policy"))
        #expect(device.failureCodes.contains("proxy_endpoint_unreachable"))
        #expect(device.failureCodes.contains("proxy_probe_failed"))
        #expect(device.failureCodes.contains("proxy_cert_install_failed"))
        #expect(device.failureCodes.contains("proxy_start_failed"))
        #expect(device.failureCodes.contains("proxy_restore_failed"))
        #expect(device.failureCodes.contains("proxy_artifact_write_failed"))
        #expect(outputSelectors.contains("host.device-proxy"))
        #expect(outputSelectors.contains("host.device-proxy-serve"))
        #expect(proxyFields.contains("redaction"))
        #expect(proxyFields.contains("requestCount"))
        #expect(proxyFields.contains("truncation"))
        #expect(proxyFields.contains("probeResults"))
        #expect(proxyServeFields.contains("responseStatus"))
        #expect(proxyServeFields.contains("responseStatusText"))
    }

    @Test("device proxy capabilities expose three-platform network takeover metadata")
    func deviceProxyCapabilitiesExposeThreePlatformMetadata() throws {
        let capabilities = connectedCapabilityMap()

        try assertCapability(
            capabilities,
            name: "device-proxy-ios",
            supported: true,
            group: "host",
            requiredByContains: ["target", "evidence", "smoke"],
            evidence: ["host-command-json", "network-capture", "proxy-restore"],
            nextActionCommand: "device",
            nextActionArgs: ["proxy", "doctor", "--platform", "ios", "--json"]
        )
        try assertCapability(
            capabilities,
            name: "device-proxy-android",
            supported: true,
            group: "host",
            requiredByContains: ["target", "evidence", "smoke"],
            evidence: ["host-command-json", "network-capture", "proxy-restore"],
            nextActionCommand: "device",
            nextActionArgs: ["proxy", "doctor", "--platform", "android", "--json"]
        )
        try assertCapability(
            capabilities,
            name: "device-proxy-harmony",
            supported: true,
            group: "host",
            requiredByContains: ["target", "evidence", "smoke"],
            evidence: ["host-command-json", "network-capture", "proxy-restore"],
            nextActionCommand: "device",
            nextActionArgs: ["proxy", "doctor", "--platform", "harmony", "--json"]
        )
        try assertCapability(
            capabilities,
            name: "network-capture-export",
            supported: true,
            group: "evidence",
            requiredByContains: ["evidence", "replay"],
            evidence: ["network-capture", "evidence-bundle"],
            nextActionCommand: "device",
            nextActionArgs: ["proxy", "export", "--platform", "<platform>", "--device", "<selector>", "--output", "<path.har|path.ndjson>", "--json"]
        )
        try assertCapability(
            capabilities,
            name: "network-certificate-plan",
            supported: true,
            group: "host",
            requiredByContains: ["target", "evidence", "smoke"],
            evidence: ["host-command-json", "network-capture"],
            nextActionCommand: "device",
            nextActionArgs: ["proxy", "cert", "plan", "--platform", "<platform>", "--device", "<selector>", "--certificate", "<path.cer>", "--json"]
        )
        try assertCapability(
            capabilities,
            name: "network-certificate-install",
            supported: true,
            group: "host",
            requiredByContains: ["target", "evidence", "smoke"],
            evidence: ["host-command-json", "network-capture"],
            nextActionCommand: "device",
            nextActionArgs: ["proxy", "cert", "install", "--platform", "<platform>", "--device", "<selector>", "--certificate", "<path.cer>", "--confirm", "--audit-record", "<id>", "--execute-runner", "--json"]
        )
    }

    @Test("device proxy doctor returns a stable host-side envelope for all three platforms")
    func deviceProxyDoctorReturnsStableHostSideEnvelopeForThreePlatforms() {
        for platform in [HostDevicePlatform.ios, .android, .harmony] {
            let session = makeNetworkProxyDoctorSession(platform: platform)

            #expect(session.ok)
            #expect(session.surface == "host.device-proxy")
            #expect(session.action == "proxy.doctor")
            #expect(session.platform == platform.rawValue)
            #expect(session.lane == .hostProxy)
            #expect(session.configured == false)
            #expect(session.visibility == .partial)
            #expect(session.target == nil)
            #expect(session.error == nil)
            #expect(session.cert == NetworkProxyCertificate(
                installed: false,
                trusted: false,
                scope: platform == .ios ? "simulator" : "emulator"
            ))
            #expect(session.limitations.contains { $0.contains("proxy_visibility_limited") })
            #expect(session.limitations.contains { $0.contains("proxy_runtime_not_required") })
        }
    }

    @Test("device proxy cert plan exposes conservative three-platform trust setup ledgers")
    func deviceProxyCertPlanExposesConservativeThreePlatformTrustSetupLedgers() throws {
        let cases: [(HostDevicePlatform, String)] = [
            (.ios, "booted"),
            (.android, "emulator-5554"),
            (.harmony, "127.0.0.1:5555"),
        ]

        for (platform, selector) in cases {
            let target = try makeNetworkProxyPlanTarget(platform: platform, device: selector)
            let session = try makeNetworkProxyCertificatePlanSession(
                platform: platform,
                target: target,
                certificatePath: "/tmp/triton-proxy-ca.cer"
            )

            #expect(session.ok)
            #expect(session.surface == "host.device-proxy")
            #expect(session.action == "proxy.cert.plan")
            #expect(session.platform == platform.rawValue)
            #expect(session.target == target)
            #expect(session.configured == false)
            #expect(session.cert == NetworkProxyCertificate(
                installed: false,
                trusted: false,
                scope: platform == .ios ? "simulator" : "emulator"
            ))
            #expect(session.artifacts == [
                NetworkProxyArtifact(kind: "proxy-certificate", path: "/tmp/triton-proxy-ca.cer", bytes: nil)
            ])
            #expect(session.limitations.contains { $0.contains("proxy_cert_untrusted") })

            switch platform {
            case .ios:
                #expect(session.sourceCommands == [
                    "xcrun simctl keychain booted add-root-cert /tmp/triton-proxy-ca.cer"
                ])
            case .android:
                #expect(session.sourceCommands.contains("adb -s emulator-5554 push /tmp/triton-proxy-ca.cer /sdcard/Download/tritonkit-proxy-ca.cer"))
                #expect(session.sourceCommands.contains { $0.contains("android.credentials.INSTALL") })
            case .harmony:
                #expect(session.sourceCommands.isEmpty)
                #expect(session.limitations.contains { $0.contains("proxy_cert_harmony_probe_only") })
            }
        }
    }

    @Test("device proxy cert install executes reviewed iOS and Android ledgers with a fake runner")
    func deviceProxyCertInstallExecutesReviewedIOSAndAndroidLedgersWithFakeRunner() throws {
        let cases: [(HostDevicePlatform, HostDeviceTarget, NetworkProxyCertificate, String)] = [
            (
                .ios,
                makeSimulatorProxyTarget(simulator: "booted"),
                NetworkProxyCertificate(installed: true, trusted: true, scope: "simulator"),
                "proxy_cert_installed:simulator_root_trusted"
            ),
            (
                .android,
                try makeNetworkProxyPlanTarget(platform: .android, device: "emulator-5554"),
                NetworkProxyCertificate(installed: false, trusted: false, scope: "emulator"),
                "proxy_cert_install_prompt_opened:manual_user_trust_required"
            ),
        ]

        for (platform, target, expectedCert, expectedLimitation) in cases {
            var executed: [String] = []
            let session = try makeNetworkProxyCertificateInstallExecutedSession(
                platform: platform,
                target: target,
                certificatePath: "/tmp/triton-proxy-ca.cer",
                auditRecord: "ticket-cert",
                runner: { command in
                    executed.append(hostSourceCommand(command))
                    return successfulHostProcessResult(command)
                }
            )

            #expect(session.ok)
            #expect(session.surface == "host.device-proxy")
            #expect(session.action == "proxy.cert.install")
            #expect(session.platform == platform.rawValue)
            #expect(session.target == target)
            #expect(session.configured == false)
            #expect(session.cert == expectedCert)
            #expect(session.visibility == .partial)
            #expect(session.sourceCommands == networkProxyCertificatePlanCommands(platform: platform, target: target, certificatePath: "/tmp/triton-proxy-ca.cer").map(hostSourceCommand))
            #expect(executed == session.sourceCommands)
            #expect(session.limitations.contains("proxy_execution_policy_accepted:auditRecord=ticket-cert"))
            #expect(session.limitations.contains("proxy_cert_runner_executed:break_glass"))
            #expect(session.limitations.contains(expectedLimitation))
            #expect(session.artifacts == [
                NetworkProxyArtifact(kind: "proxy-certificate", path: "/tmp/triton-proxy-ca.cer", bytes: nil)
            ])
            #expect(session.error == nil)
        }
    }

    @Test("device proxy cert install keeps Harmony probe-only until certificate trust command is verified")
    func deviceProxyCertInstallKeepsHarmonyProbeOnlyUntilCertificateTrustCommandIsVerified() throws {
        let target = try makeNetworkProxyPlanTarget(platform: .harmony, device: "127.0.0.1:5555")
        var executed: [String] = []
        let session = try makeNetworkProxyCertificateInstallExecutedSession(
            platform: .harmony,
            target: target,
            certificatePath: "/tmp/triton-proxy-ca.cer",
            auditRecord: "ticket-cert",
            runner: { command in
                executed.append(hostSourceCommand(command))
                return successfulHostProcessResult(command)
            }
        )

        #expect(session.ok == false)
        #expect(session.action == "proxy.cert.install")
        #expect(session.error?.code == "proxy_unverified_platform_proxy")
        #expect(session.error?.nextAction?.args == ["proxy", "cert", "doctor", "--platform", "harmony", "--json"])
        #expect(session.cert == NetworkProxyCertificate(installed: false, trusted: false, scope: "emulator"))
        #expect(session.limitations.contains("proxy_cert_harmony_probe_only:no_verified_harmony_certificate_install_or_trust_mutation"))
        #expect(session.limitations.contains("proxy_execution_policy_accepted:auditRecord=ticket-cert"))
        #expect(session.sourceCommands == [
            "hdc -t 127.0.0.1:5555 shell param get bootevent.boot.completed",
            "hdc -t 127.0.0.1:5555 shell echo triton-shell-ready",
        ])
        #expect(executed.isEmpty)
    }

    @Test("device proxy cert install returns a stable failure envelope")
    func deviceProxyCertInstallReturnsStableFailureEnvelope() throws {
        let target = try makeNetworkProxyPlanTarget(platform: .android, device: "emulator-5554")
        var invocation = 0
        let session = try makeNetworkProxyCertificateInstallExecutedSession(
            platform: .android,
            target: target,
            certificatePath: "/tmp/triton-proxy-ca.cer",
            auditRecord: "ticket-cert",
            runner: { command in
                invocation += 1
                if invocation == 2 {
                    throw HostCommandRunError.nonZeroExit(command: command, result: failedHostProcessResult(command, stderr: "intent denied"))
                }
                return successfulHostProcessResult(command)
            }
        )

        #expect(session.ok == false)
        #expect(session.action == "proxy.cert.install")
        #expect(session.configured == false)
        #expect(session.error?.code == "proxy_cert_install_failed")
        #expect(session.error?.nextAction?.args == ["proxy", "cert", "doctor", "--platform", "android", "--json"])
        #expect(session.cert == NetworkProxyCertificate(installed: false, trusted: false, scope: "emulator"))
        #expect(session.sourceCommands == networkProxyCertificatePlanCommands(platform: .android, target: target, certificatePath: "/tmp/triton-proxy-ca.cer").map(hostSourceCommand))
        #expect(session.artifacts == [
            NetworkProxyArtifact(kind: "proxy-certificate", path: "/tmp/triton-proxy-ca.cer", bytes: nil)
        ])
        #expect(session.limitations.contains("proxy_execution_policy_accepted:auditRecord=ticket-cert"))
        #expect(session.limitations.contains { $0.hasPrefix("proxy_cert_install_failed:") })
    }

    @Test("device proxy probe exposes readonly Harmony HDC capability evidence")
    func deviceProxyProbeExposesReadonlyHarmonyHDCCapabilityEvidence() throws {
        let target = try makeNetworkProxyPlanTarget(platform: .harmony, device: "127.0.0.1:5555")
        let session = try makeNetworkProxyProbeSession(
            platform: .harmony,
            target: target,
            runner: { command in
                let commandLine = hostSourceCommand(command)
                if commandLine.contains("bootevent.boot.completed") {
                    return successfulHostProcessResult(command, stdout: "true\n")
                }
                if commandLine.contains("echo triton-shell-ready") {
                    return successfulHostProcessResult(command, stdout: "triton-shell-ready\n")
                }
                if commandLine.contains("param ls -r proxy") {
                    return successfulHostProcessResult(command, stdout: "persist.net.proxy.host=\npersist.net.proxy.port=\n")
                }
                if commandLine.contains("param ls -r http") {
                    throw HostCommandRunError.nonZeroExit(command: command, result: failedHostProcessResult(command, stderr: "no matching parameter\n"))
                }
                return successfulHostProcessResult(command)
            }
        )

        #expect(session.ok)
        #expect(session.action == "proxy.probe")
        #expect(session.platform == "harmony")
        #expect(session.configured == false)
        #expect(session.sourceCommands.contains("hdc -t 127.0.0.1:5555 shell param ls -r proxy"))
        #expect(session.sourceCommands.contains("hdc -t 127.0.0.1:5555 shell param ls -r http"))
        #expect(session.limitations.contains("proxy_probe_readonly:not_mutated"))
        #expect(session.limitations.contains("proxy_harmony_probe_only:no_verified_proxy_mutation"))
        #expect(session.limitations.contains("proxy_harmony_candidate_parameters_found:manual_verification_required"))
        let probeResults = try #require(session.probeResults)
        #expect(probeResults.count == 4)
        #expect(probeResults.first { $0.name == "harmony.param.proxy" }?.ok == true)
        #expect(probeResults.first { $0.name == "harmony.param.proxy" }?.stdoutPreview?.contains("persist.net.proxy.host") == true)
        #expect(probeResults.first { $0.name == "harmony.param.http" }?.ok == false)
        #expect((probeResults.first { $0.name == "harmony.param.http" }?.exitCode ?? 0) != 0)
    }

    @Test("device proxy probe CLI plan-only resolves Harmony aliases without running HDC")
    func deviceProxyProbeCLIPlanOnlyResolvesHarmonyAliasesWithoutRunningHDC() async throws {
        let fileManager = FileManager.default
        let originalDirectory = fileManager.currentDirectoryPath
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("triton-proxy-probe-alias-\(UUID().uuidString)")
            .path
        try fileManager.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        defer {
            _ = fileManager.changeCurrentDirectoryPath(originalDirectory)
            try? fileManager.removeItem(atPath: tempDirectory)
        }
        #expect(fileManager.changeCurrentDirectoryPath(tempDirectory))

        _ = try saveHostTargetAliasStore(HostTargetAliasStore(
            current: "harmony-a",
            aliases: [
                "harmony-a": HostTargetAlias(platform: .harmony, target: "harmony:127.0.0.1:5555"),
            ]
        ))

        let command = try DeviceProxyProbe.parse([
            "--platform", "harmony",
            "--device", "current",
            "--plan-only",
            "--json",
        ])
        let session = try makeNetworkProxyProbePlanSession(
            platform: command.platform,
            target: try makeNetworkProxyPlanTarget(platform: command.platform, device: command.device),
            hdc: command.hdc,
            adb: command.adb
        )
        let target = try #require(session.target)
        let sourceCommands = session.sourceCommands
        let limitations = session.limitations

        #expect(command.planOnly)
        #expect(session.ok)
        #expect(session.action == "proxy.probe")
        #expect(target.target == "127.0.0.1:5555")
        #expect(sourceCommands.contains("hdc -t 127.0.0.1:5555 shell param ls -r proxy"))
        #expect(sourceCommands.contains("hdc -t 127.0.0.1:5555 shell param ls -r http"))
        #expect(!sourceCommands.contains { $0.contains("current") || $0.contains("harmony-a") })
        #expect(limitations.contains("proxy_plan_only:not_executed"))
    }

    @Test("device proxy rejects real-device targets because takeover is emulator scoped")
    func deviceProxyRejectsRealDeviceTargetsBecauseTakeoverIsEmulatorScoped() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")

        for fixture in networkProxyRealDeviceTargetFixtures() {
            let start = try makeNetworkProxyStartPlanSession(
                platform: fixture.platform,
                target: fixture.target,
                captureMode: "record",
                endpoint: endpoint
            )
            let stop = try makeNetworkProxyStopPlanSession(
                platform: fixture.platform,
                target: fixture.target,
                restore: true
            )
            let export = try makeNetworkProxyExportPlanSession(
                platform: fixture.platform,
                target: fixture.target,
                outputPath: "/tmp/\(fixture.platform.rawValue)-real-network.ndjson"
            )
            let cert = try makeNetworkProxyCertificatePlanSession(
                platform: fixture.platform,
                target: fixture.target,
                certificatePath: "/tmp/triton-proxy-ca.cer"
            )
            var executedCommands: [TKHostCommand] = []
            let executedStart = try makeNetworkProxyStartExecutedSession(
                platform: fixture.platform,
                target: fixture.target,
                captureMode: "record",
                endpoint: endpoint,
                auditRecord: "real-device-rejected",
                runner: { command in
                    executedCommands.append(command)
                    return successfulHostProcessResult(command)
                },
                endpointPreflight: { _ in true }
            )
            let executedStop = try makeNetworkProxyStopExecutedSession(
                platform: fixture.platform,
                target: fixture.target,
                restore: true,
                auditRecord: "real-device-rejected",
                runner: { command in
                    executedCommands.append(command)
                    return successfulHostProcessResult(command)
                }
            )
            let executedCert = try makeNetworkProxyCertificateInstallExecutedSession(
                platform: fixture.platform,
                target: fixture.target,
                certificatePath: "/tmp/triton-proxy-ca.cer",
                auditRecord: "real-device-rejected",
                runner: { command in
                    executedCommands.append(command)
                    return successfulHostProcessResult(command)
                }
            )
            let status = try makeNetworkProxyStatusSession(
                platform: fixture.platform,
                target: fixture.target,
                sessionDirectory: nil
            )
            let sessionExport = try makeNetworkProxyExportSession(
                platform: fixture.platform,
                target: fixture.target,
                sessionDirectory: nil,
                outputPath: nil
            )

            #expect(executedCommands.isEmpty)
            for session in [start, stop, export, cert, executedStart, executedStop, executedCert, status, sessionExport] {
                #expect(session.ok == false)
                #expect(session.configured == false)
                #expect(session.platform == fixture.platform.rawValue)
                #expect(session.target == fixture.target)
                #expect(session.error?.code == "proxy_real_device_not_supported")
                #expect(session.error?.nextAction?.command == "device")
                #expect(session.error?.nextAction?.args == ["proxy", "doctor", "--platform", fixture.platform.rawValue, "--json"])
                #expect(session.error?.nextAction?.category == "diagnose")
                #expect(session.limitations.contains("proxy_scope_emulator_only:real_device_not_supported"))
                #expect(session.sourceCommands.isEmpty)
                #expect(session.artifacts.isEmpty)
            }
        }
    }

    @Test("device proxy plan target preserves real-device selector prefixes for rejection")
    func deviceProxyPlanTargetPreservesRealDeviceSelectorPrefixesForRejection() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let cases: [(platform: HostDevicePlatform, selector: String)] = [
            (.ios, "ios-real:abc123"),
            (.android, "android-real:redacted"),
            (.harmony, "harmony-real:redacted"),
        ]

        for testCase in cases {
            let target = try makeNetworkProxyPlanTarget(platform: testCase.platform, device: testCase.selector)
            let session = try makeNetworkProxyStartPlanSession(
                platform: testCase.platform,
                target: target,
                captureMode: "record",
                endpoint: endpoint
            )

            #expect(target.scope == "real")
            #expect(target.kind == "real-device")
            #expect(target.target == testCase.selector)
            #expect(target.rawTarget == testCase.selector)
            #expect(session.ok == false)
            #expect(session.error?.code == "proxy_real_device_not_supported")
            #expect(session.sourceCommands.isEmpty)
            #expect(session.artifacts.isEmpty)
        }
    }

    @Test("device proxy plan target resolves workspace aliases and current selectors")
    func deviceProxyPlanTargetResolvesWorkspaceAliasesAndCurrentSelectors() throws {
        let fileManager = FileManager.default
        let originalDirectory = fileManager.currentDirectoryPath
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("triton-proxy-alias-\(UUID().uuidString)")
            .path
        try fileManager.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        defer {
            _ = fileManager.changeCurrentDirectoryPath(originalDirectory)
            try? fileManager.removeItem(atPath: tempDirectory)
        }
        #expect(fileManager.changeCurrentDirectoryPath(tempDirectory))

        _ = try saveHostTargetAliasStore(HostTargetAliasStore(
            current: "android-a",
            aliases: [
                "iphone15": HostTargetAlias(platform: .ios, target: "sim:SIM-1"),
                "android-a": HostTargetAlias(platform: .android, target: "android:emulator-5554"),
                "harmony-a": HostTargetAlias(platform: .harmony, target: "harmony:127.0.0.1:10100"),
                "android-phone": HostTargetAlias(
                    platform: .android,
                    target: "android-real:redacted",
                    scope: .real,
                    kind: "real-device",
                    sensitiveRef: ".triton/devices/android-real-redacted.json"
                ),
            ]
        ))

        let ios = try makeNetworkProxyPlanTarget(platform: .ios, device: "iphone15")
        let android = try makeNetworkProxyPlanTarget(platform: .android, device: "android-a")
        let current = try makeNetworkProxyPlanTarget(platform: .android, device: "current")
        let harmony = try makeNetworkProxyPlanTarget(platform: .harmony, device: "harmony-a")
        let real = try makeNetworkProxyPlanTarget(platform: .android, device: "android-phone")

        #expect(ios.target == "SIM-1")
        #expect(ios.id == "sim:SIM-1")
        #expect(android.target == "emulator-5554")
        #expect(android.id == "android:emulator-5554")
        #expect(current.target == "emulator-5554")
        #expect(harmony.target == "127.0.0.1:10100")
        #expect(harmony.id == "harmony:127.0.0.1:10100")
        #expect(real.scope == "real")
        #expect(real.kind == "real-device")
        #expect(real.target == "android-real:redacted")

        #expect(throws: HostDeviceSelectionError.self) {
            _ = try makeNetworkProxyPlanTarget(platform: .ios, device: "android-a")
        }
    }

    @Test("device proxy start CLI plan-only resolves workspace aliases in emitted ledgers")
    func deviceProxyStartCLIPlanOnlyResolvesWorkspaceAliasesInEmittedLedgers() async throws {
        let fileManager = FileManager.default
        let originalDirectory = fileManager.currentDirectoryPath
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("triton-proxy-cli-alias-\(UUID().uuidString)")
            .path
        try fileManager.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        defer {
            _ = fileManager.changeCurrentDirectoryPath(originalDirectory)
            try? fileManager.removeItem(atPath: tempDirectory)
        }
        #expect(fileManager.changeCurrentDirectoryPath(tempDirectory))

        _ = try saveHostTargetAliasStore(HostTargetAliasStore(
            current: "android-a",
            aliases: [
                "iphone15": HostTargetAlias(platform: .ios, target: "sim:SIM-1"),
                "android-a": HostTargetAlias(platform: .android, target: "android:emulator-5554"),
                "harmony-a": HostTargetAlias(platform: .harmony, target: "harmony:127.0.0.1:10100"),
            ]
        ))

        let cases: [(platform: String, device: String, expectedTarget: String, expectedCommandFragment: String?)] = [
            ("ios", "iphone15", "SIM-1", nil),
            ("android", "current", "emulator-5554", "adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:19431"),
            ("harmony", "harmony-a", "127.0.0.1:10100", "hdc -t 127.0.0.1:10100 shell"),
        ]

        for testCase in cases {
            let command = try DeviceProxyStart.parse([
                "--platform", testCase.platform,
                "--device", testCase.device,
                "--mode", "record",
                "--proxy", "127.0.0.1:19431",
                "--plan-only",
                "--json",
            ])
            let session = try makeNetworkProxyStartPlanSession(
                platform: command.platform,
                target: try makeNetworkProxyPlanTarget(platform: command.platform, device: command.device),
                captureMode: command.mode,
                endpoint: try NetworkProxyEndpoint(command.proxy)
            )
            let target = try #require(session.target)
            let sourceCommands = session.sourceCommands

            #expect(command.planOnly)
            #expect(session.ok)
            #expect(session.configured == false)
            #expect(target.target == testCase.expectedTarget)
            if let expectedCommandFragment = testCase.expectedCommandFragment {
                #expect(sourceCommands.contains { $0.contains(expectedCommandFragment) })
            }
            #expect(!sourceCommands.contains { $0.contains(testCase.device) && testCase.device != testCase.expectedTarget })
        }
    }

    @Test("device proxy status CLI resolves aliases and rejects real-device aliases without a session")
    func deviceProxyStatusCLIResolvesAliasesAndRejectsRealDeviceAliasesWithoutSession() async throws {
        let fileManager = FileManager.default
        let originalDirectory = fileManager.currentDirectoryPath
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("triton-proxy-status-alias-\(UUID().uuidString)")
            .path
        try fileManager.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        defer {
            _ = fileManager.changeCurrentDirectoryPath(originalDirectory)
            try? fileManager.removeItem(atPath: tempDirectory)
        }
        #expect(fileManager.changeCurrentDirectoryPath(tempDirectory))

        _ = try saveHostTargetAliasStore(HostTargetAliasStore(
            current: nil,
            aliases: [
                "android-a": HostTargetAlias(platform: .android, target: "android:emulator-5554"),
                "android-phone": HostTargetAlias(
                    platform: .android,
                    target: "android-real:redacted",
                    scope: .real,
                    kind: "real-device",
                    sensitiveRef: ".triton/devices/android-real-redacted.json"
                ),
            ]
        ))

        let aliasCommand = try DeviceProxyStatus.parse([
            "--platform", "android",
            "--device", "android-a",
            "--json",
        ])
        let aliasStatusTarget = try makeNetworkProxyPlanTarget(platform: aliasCommand.platform, device: aliasCommand.device)
        let aliasSession = makeNetworkProxyStatusSession(
            platform: aliasCommand.platform,
            target: aliasStatusTarget
        )
        let aliasTarget = try #require(aliasSession.target)

        #expect(aliasSession.ok)
        #expect(aliasTarget.target == "emulator-5554")
        #expect(aliasSession.configured == false)

        let realCommand = try DeviceProxyStatus.parse([
            "--platform", "android",
            "--device", "android-phone",
            "--json",
        ])
        let realStatusTarget = try makeNetworkProxyPlanTarget(platform: realCommand.platform, device: realCommand.device)
        let realSession = makeNetworkProxyStatusSession(
            platform: realCommand.platform,
            target: realStatusTarget
        )
        let realTarget = try #require(realSession.target)
        let realError = try #require(realSession.error)
        let sourceCommands = realSession.sourceCommands

        #expect(realSession.ok == false)
        #expect(realTarget.target == "android-real:redacted")
        #expect(realTarget.scope == "real")
        #expect(realError.code == "proxy_real_device_not_supported")
        #expect(sourceCommands.isEmpty)
    }

    @Test("sim proxy alias CLI resolves workspace aliases like device proxy")
    func simProxyAliasCLIResolvesWorkspaceAliasesLikeDeviceProxy() async throws {
        let fileManager = FileManager.default
        let originalDirectory = fileManager.currentDirectoryPath
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("triton-sim-proxy-alias-\(UUID().uuidString)")
            .path
        try fileManager.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        defer {
            _ = fileManager.changeCurrentDirectoryPath(originalDirectory)
            try? fileManager.removeItem(atPath: tempDirectory)
        }
        #expect(fileManager.changeCurrentDirectoryPath(tempDirectory))

        _ = try saveHostTargetAliasStore(HostTargetAliasStore(
            current: "iphone15",
            aliases: [
                "iphone15": HostTargetAlias(platform: .ios, target: "sim:SIM-1"),
                "iphone-real": HostTargetAlias(
                    platform: .ios,
                    target: "ios-real:redacted",
                    scope: .real,
                    kind: "real-device",
                    sensitiveRef: ".triton/devices/ios-real-redacted.json"
                ),
            ]
        ))

        let startCommand = try SimProxyStart.parse([
            "--simulator", "iphone15",
            "--mode", "record",
            "--proxy", "127.0.0.1:19431",
            "--plan-only",
            "--json",
        ])
        let statusCommand = try SimProxyStatus.parse([
            "--simulator", "current",
            "--json",
        ])
        let exportCommand = try SimProxyExport.parse([
            "--simulator", "iphone15",
            "--output", "/tmp/ios-network.har",
            "--plan-only",
            "--json",
        ])
        let stopCommand = try SimProxyStop.parse([
            "--simulator", "current",
            "--restore",
            "--plan-only",
            "--json",
        ])
        let sessions = try [
            makeNetworkProxyStartPlanSession(
                platform: .ios,
                target: makeNetworkProxyPlanTarget(platform: .ios, device: startCommand.simulator),
                captureMode: startCommand.mode,
                endpoint: NetworkProxyEndpoint(startCommand.proxy)
            ),
            makeNetworkProxyStatusSession(
                platform: .ios,
                target: makeNetworkProxyPlanTarget(platform: .ios, device: statusCommand.simulator)
            ),
            makeNetworkProxyExportPlanSession(
                platform: .ios,
                target: makeNetworkProxyPlanTarget(platform: .ios, device: exportCommand.simulator),
                outputPath: makeNetworkProxyExportPlanOutputPath(exportCommand.output)
            ),
            makeNetworkProxyStopPlanSession(
                platform: .ios,
                target: makeNetworkProxyPlanTarget(platform: .ios, device: stopCommand.simulator),
                restore: stopCommand.restore
            ),
        ]

        for session in sessions {
            let target = try #require(session.target)
            let sourceCommands = session.sourceCommands

            #expect(session.platform == "ios")
            #expect(target.target == "SIM-1")
            #expect(!sourceCommands.contains { $0.contains("iphone15") || $0.contains("current") })
        }

        let realCommand = try SimProxyStatus.parse([
            "--simulator", "iphone-real",
            "--json",
        ])
        let realSession = try makeNetworkProxyStatusSession(
            platform: .ios,
            target: makeNetworkProxyPlanTarget(platform: .ios, device: realCommand.simulator)
        )
        let realTarget = try #require(realSession.target)
        let realError = try #require(realSession.error)
        let realSourceCommands = realSession.sourceCommands

        #expect(realSession.ok == false)
        #expect(realTarget.target == "ios-real:redacted")
        #expect(realTarget.scope == "real")
        #expect(realError.code == "proxy_real_device_not_supported")
        #expect(realSourceCommands.isEmpty)
    }

    @Test("device proxy status returns conservative certificate state before a session exists")
    func deviceProxyStatusReturnsConservativeCertificateStateBeforeSessionExists() {
        for platform in [HostDevicePlatform.ios, .android, .harmony] {
            let session = makeNetworkProxyStatusSession(platform: platform, target: nil)

            #expect(session.ok)
            #expect(session.action == "proxy.status")
            #expect(session.platform == platform.rawValue)
            #expect(session.configured == false)
            #expect(session.visibility == .unknown)
            #expect(session.cert == NetworkProxyCertificate(
                installed: false,
                trusted: false,
                scope: platform == .ios ? "simulator" : "emulator"
            ))
            #expect(session.limitations.contains("proxy_session_not_running"))
        }
    }

    @Test("device proxy serve parses proxy requests into redacted capture events")
    func deviceProxyServeParsesProxyRequestsIntoRedactedCaptureEvents() throws {
        let request = Data((
            "GET http://example.test/path?q=1 HTTP/1.1\r\n" +
            "Host: example.test\r\n" +
            "Authorization: secret\r\n" +
            "Cookie: session=secret\r\n" +
            "Proxy-Connection: keep-alive\r\n" +
            "\r\n"
        ).utf8)

        let event = try parseNetworkProxyHTTPHeader(
            request,
            listen: "127.0.0.1:19431",
            capturePath: "/tmp/requests.ndjson",
            connectionIndex: 7
        )

        #expect(event.ok)
        #expect(event.surface == "host.device-proxy-serve")
        #expect(event.event == "proxy.serve.request")
        #expect(event.schemaVersion == "triton.proxy.capture.v1")
        #expect(event.connectionIndex == 7)
        #expect(event.method == "GET")
        #expect(event.url == "http://example.test/path?q=1")
        #expect(event.host == "example.test")
        #expect(event.port == 80)
        #expect(event.path == "/path?q=1")
        #expect(event.tunnel == false)
        #expect(event.headerNames.contains("Authorization"))
        #expect(event.headerNames.contains("Cookie"))
        #expect(event.redaction == "headers-names-only")
    }

    @Test("device proxy serve listens locally and writes NDJSON capture events")
    func deviceProxyServeListensLocallyAndWritesNDJSONCaptureEvents() throws {
        let port = try reserveLocalPortForTest()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-serve-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:\(port)")
        let finished = DispatchSemaphore(value: 0)
        var summary: NetworkProxyServeSummary?
        var serverError: Error?

        DispatchQueue.global().async {
            do {
                summary = try runNetworkProxyCaptureServer(
                    config: NetworkProxyServeConfig(listen: endpoint, outputDirectory: directory.path, maxConnections: 2)
                )
            } catch {
                serverError = error
            }
            finished.signal()
        }

        try waitUntilPortAcceptsConnections(port: port)
        try sendProxyServeTestRequest(port: port)
        #expect(finished.wait(timeout: .now() + 3) == .success)
        if let serverError {
            throw serverError
        }

        let capturePath = networkProxyServeCapturePath(outputDirectory: directory.path)
        let capture = try String(contentsOfFile: capturePath, encoding: .utf8)
        #expect(summary?.ok == true)
        #expect(summary?.surface == "host.device-proxy-serve")
        #expect(summary?.event == "proxy.serve.summary")
        #expect(summary?.schemaVersion == "triton.proxy.capture.v1")
        #expect(summary?.capturePath == capturePath)
        #expect(capture.contains("\"event\":\"proxy.serve.request\""))
        #expect(capture.contains("\"event\":\"proxy.serve.connection-failed\""))
        #expect(capture.contains("\"host\":\"127.0.0.1\""))
        #expect(capture.contains("\"redaction\":\"headers-names-only\""))
        #expect(!capture.contains("session=secret"))
    }

    @Test("device proxy serve command emits ready request and summary JSONL events")
    func deviceProxyServeCommandEmitsReadyRequestAndSummaryJSONLEvents() async throws {
        let port = try reserveLocalPortForTest()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-cli-jsonl-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let endpoint = "127.0.0.1:\(port)"
        let commandTask = Task {
            try await captureStandardOutputAsync {
                let command = try DeviceProxyServe.parse([
                    "--listen", endpoint,
                    "--output", directory.path,
                    "--mode", "mock",
                    "--max-connections", "2",
                    "--jsonl",
                ])
                try await command.run()
            }
        }

        try waitUntilPortAcceptsConnections(port: port)
        let response = try sendProxyServeTestRequestAndReadResponse(port: port)
        let output = try await commandTask.value

        var events: [[String: Any]] = []
        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("{") else { continue }
            let event = try jsonObject(line: trimmed)
            if event["surface"] as? String == "host.device-proxy-serve" {
                events.append(event)
            }
        }
        let ready = try #require(events.first { $0["event"] as? String == "proxy.serve.ready" })
        let connectionFailed = try #require(events.first { $0["event"] as? String == "proxy.serve.connection-failed" })
        let request = try #require(events.first { $0["event"] as? String == "proxy.serve.request" })
        let summary = try #require(events.first { $0["event"] as? String == "proxy.serve.summary" })
        let capture = try String(contentsOfFile: networkProxyServeCapturePath(outputDirectory: directory.path), encoding: .utf8)

        #expect(response.contains("HTTP/1.1 200 TritonKit Proxy Mock"))
        #expect(events.count == 4)
        #expect(ready["surface"] as? String == "host.device-proxy-serve")
        #expect(ready["schemaVersion"] as? String == "triton.proxy.capture.v1")
        #expect(ready["listen"] as? String == endpoint)
        #expect(connectionFailed["ok"] as? Bool == false)
        #expect(connectionFailed["schemaVersion"] as? String == "triton.proxy.capture.v1")
        #expect(request["policyAction"] as? String == "mocked")
        #expect(request["captureMode"] as? String == "mock")
        #expect(request["responseStatus"] as? Int == 200)
        #expect(request["responseStatusText"] as? String == "TritonKit Proxy Mock")
        #expect(summary["surface"] as? String == "host.device-proxy-serve")
        #expect(summary["schemaVersion"] as? String == "triton.proxy.capture.v1")
        #expect(summary["captureMode"] as? String == "mock")
        #expect(summary["requestCount"] as? Int == 1)
        #expect(capture.contains("\"event\":\"proxy.serve.connection-failed\""))
        #expect(capture.contains("\"event\":\"proxy.serve.request\""))
        #expect(!capture.contains("\"event\":\"proxy.serve.summary\""))
    }

    @Test("device proxy serve block mode records metadata and denies upstream traffic")
    func deviceProxyServeBlockModeRecordsMetadataAndDeniesUpstreamTraffic() throws {
        let port = try reserveLocalPortForTest()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-block-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:\(port)")
        let finished = DispatchSemaphore(value: 0)
        var summary: NetworkProxyServeSummary?
        var serverError: Error?

        DispatchQueue.global().async {
            do {
                summary = try runNetworkProxyCaptureServer(
                    config: NetworkProxyServeConfig(listen: endpoint, outputDirectory: directory.path, maxConnections: 2, mode: "block")
                )
            } catch {
                serverError = error
            }
            finished.signal()
        }

        try waitUntilPortAcceptsConnections(port: port)
        let response = try sendProxyServeTestRequestAndReadResponse(port: port)
        #expect(finished.wait(timeout: .now() + 3) == .success)
        if let serverError {
            throw serverError
        }

        let capture = try String(contentsOfFile: networkProxyServeCapturePath(outputDirectory: directory.path), encoding: .utf8)
        #expect(summary?.requestCount == 1)
        #expect(summary?.captureMode == "block")
        #expect(response.contains("HTTP/1.1 502 TritonKit Proxy Blocked"))
        #expect(capture.contains("\"event\":\"proxy.serve.request\""))
        #expect(capture.contains("\"captureMode\":\"block\""))
        #expect(capture.contains("\"policyAction\":\"blocked\""))
        #expect(capture.contains("\"responseStatus\":502"))
        #expect(capture.contains("\"responseStatusText\":\"TritonKit Proxy Blocked\""))
        #expect(!capture.contains("session=secret"))
    }

    @Test("device proxy serve mock mode records metadata and returns a fixed mock response")
    func deviceProxyServeMockModeRecordsMetadataAndReturnsFixedMockResponse() throws {
        let port = try reserveLocalPortForTest()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-mock-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:\(port)")
        let finished = DispatchSemaphore(value: 0)
        var summary: NetworkProxyServeSummary?
        var serverError: Error?

        DispatchQueue.global().async {
            do {
                summary = try runNetworkProxyCaptureServer(
                    config: NetworkProxyServeConfig(listen: endpoint, outputDirectory: directory.path, maxConnections: 2, mode: "mock")
                )
            } catch {
                serverError = error
            }
            finished.signal()
        }

        try waitUntilPortAcceptsConnections(port: port)
        let response = try sendProxyServeTestRequestAndReadResponse(port: port)
        #expect(finished.wait(timeout: .now() + 3) == .success)
        if let serverError {
            throw serverError
        }

        let capture = try String(contentsOfFile: networkProxyServeCapturePath(outputDirectory: directory.path), encoding: .utf8)
        #expect(summary?.requestCount == 1)
        #expect(summary?.captureMode == "mock")
        #expect(response.contains("HTTP/1.1 200 TritonKit Proxy Mock"))
        #expect(response.contains(#""mocked":true"#))
        #expect(capture.contains("\"event\":\"proxy.serve.request\""))
        #expect(capture.contains("\"captureMode\":\"mock\""))
        #expect(capture.contains("\"policyAction\":\"mocked\""))
        #expect(capture.contains("\"responseStatus\":200"))
        #expect(capture.contains("\"responseStatusText\":\"TritonKit Proxy Mock\""))
        #expect(!capture.contains("session=secret"))
    }

    @Test("device proxy serve throttle mode records metadata and returns a stable rate limit response")
    func deviceProxyServeThrottleModeRecordsMetadataAndReturnsStableRateLimitResponse() throws {
        let port = try reserveLocalPortForTest()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-throttle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:\(port)")
        let finished = DispatchSemaphore(value: 0)
        var summary: NetworkProxyServeSummary?
        var serverError: Error?

        DispatchQueue.global().async {
            do {
                summary = try runNetworkProxyCaptureServer(
                    config: NetworkProxyServeConfig(listen: endpoint, outputDirectory: directory.path, maxConnections: 2, mode: "throttle")
                )
            } catch {
                serverError = error
            }
            finished.signal()
        }

        try waitUntilPortAcceptsConnections(port: port)
        let response = try sendProxyServeTestRequestAndReadResponse(port: port)
        #expect(finished.wait(timeout: .now() + 3) == .success)
        if let serverError {
            throw serverError
        }

        let capture = try String(contentsOfFile: networkProxyServeCapturePath(outputDirectory: directory.path), encoding: .utf8)
        #expect(summary?.requestCount == 1)
        #expect(summary?.captureMode == "throttle")
        #expect(response.contains("HTTP/1.1 429 TritonKit Proxy Throttled"))
        #expect(response.contains("Retry-After: 1"))
        #expect(capture.contains("\"event\":\"proxy.serve.request\""))
        #expect(capture.contains("\"captureMode\":\"throttle\""))
        #expect(capture.contains("\"policyAction\":\"throttled\""))
        #expect(capture.contains("\"responseStatus\":429"))
        #expect(capture.contains("\"responseStatusText\":\"TritonKit Proxy Throttled\""))
        #expect(!capture.contains("session=secret"))
    }

    @Test("device proxy export converts capture events into metadata-only HAR")
    func deviceProxyExportConvertsCaptureEventsIntoMetadataOnlyHAR() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-har-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("requests.ndjson")
        let outputURL = directory.appendingPathComponent("network.har")
        let request = Data((
            "GET http://example.test/path?q=1 HTTP/1.1\r\n" +
            "Host: example.test\r\n" +
            "Authorization: secret\r\n" +
            "\r\n"
        ).utf8)
        let connect = Data((
            "CONNECT secure.example.test:443 HTTP/1.1\r\n" +
            "Host: secure.example.test:443\r\n" +
            "\r\n"
        ).utf8)
        let mock = try parseNetworkProxyHTTPHeader(
            request,
            listen: "127.0.0.1:19431",
            capturePath: sourceURL.path,
            connectionIndex: 3,
            captureMode: "mock",
            policyAction: "mocked"
        )
        let block = try parseNetworkProxyHTTPHeader(
            request,
            listen: "127.0.0.1:19431",
            capturePath: sourceURL.path,
            connectionIndex: 4,
            captureMode: "block",
            policyAction: "blocked"
        )
        let throttle = try parseNetworkProxyHTTPHeader(
            request,
            listen: "127.0.0.1:19431",
            capturePath: sourceURL.path,
            connectionIndex: 5,
            captureMode: "throttle",
            policyAction: "throttled"
        )
        let events = [
            try parseNetworkProxyHTTPHeader(request, listen: "127.0.0.1:19431", capturePath: sourceURL.path, connectionIndex: 1),
            try parseNetworkProxyHTTPHeader(connect, listen: "127.0.0.1:19431", capturePath: sourceURL.path, connectionIndex: 2),
            mock,
            block,
            throttle,
        ]
        let ndjson = try events.map { try encodeCompactJSON($0) }.joined(separator: "\n") + "\n"
        try Data(ndjson.utf8).write(to: sourceURL)

        let bytes = try exportNetworkProxyCaptureArtifact(sourceURL: sourceURL, outputURL: outputURL)
        let har = try jsonDictionary(at: outputURL.path)
        let log = try #require(har["log"] as? [String: Any])
        let entries = try #require(log["entries"] as? [[String: Any]])
        let firstRequest = try #require(entries.first?["request"] as? [String: Any])
        let secondRequest = try #require(entries.dropFirst().first?["request"] as? [String: Any])
        let forwardedResponse = try #require(entries.first?["response"] as? [String: Any])
        let mockResponse = try #require(entries.dropFirst(2).first?["response"] as? [String: Any])
        let blockResponse = try #require(entries.dropFirst(3).first?["response"] as? [String: Any])
        let throttleResponse = try #require(entries.dropFirst(4).first?["response"] as? [String: Any])
        let firstHeaders = try #require(firstRequest["headers"] as? [[String: Any]])

        #expect(bytes > 0)
        #expect(log["version"] as? String == "1.2")
        #expect(entries.count == 5)
        #expect(firstRequest["method"] as? String == "GET")
        #expect(firstRequest["url"] as? String == "http://example.test/path?q=1")
        #expect(firstHeaders.contains { $0["name"] as? String == "Authorization" && $0["value"] as? String == "<redacted>" })
        #expect(secondRequest["method"] as? String == "CONNECT")
        #expect(secondRequest["url"] as? String == "https://secure.example.test:443/")
        #expect(forwardedResponse["status"] as? Int == 0)
        #expect(mockResponse["status"] as? Int == 200)
        #expect(mockResponse["statusText"] as? String == "TritonKit Proxy Mock")
        #expect(blockResponse["status"] as? Int == 502)
        #expect(blockResponse["statusText"] as? String == "TritonKit Proxy Blocked")
        #expect(throttleResponse["status"] as? Int == 429)
        #expect(throttleResponse["statusText"] as? String == "TritonKit Proxy Throttled")
    }

    @Test("device proxy mutating actions stay unsupported until a platform runner exists")
    func deviceProxyMutatingActionsStayUnsupportedUntilPlatformRunnerExists() throws {
        let start = makeNetworkProxyUnsupportedSession(action: .start, platform: .ios, captureMode: "record")
        let export = makeNetworkProxyUnsupportedSession(action: .export, platform: .android)

        #expect(start.ok == false)
        #expect(start.surface == "host.device-proxy")
        #expect(start.action == "proxy.start")
        #expect(start.platform == "ios")
        #expect(start.captureMode == "record")
        #expect(start.configured == false)
        #expect(start.error?.code == "proxy_platform_not_supported")
        #expect(start.error?.nextAction?.command == "plan")
        #expect(start.error?.nextAction?.category == "plan")

        #expect(export.ok == false)
        #expect(export.action == "proxy.export")
        #expect(export.platform == "android")
        #expect(export.artifacts.isEmpty)
        #expect(export.error?.code == "proxy_platform_not_supported")
    }

    @Test("fake proxy adapter records status export and restore for all three platforms without touching host settings")
    func fakeProxyAdapterRecordsStatusExportAndRestoreForThreePlatforms() throws {
        for fixture in networkProxyTargetFixtures() {
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("triton-\(fixture.platform.rawValue)-proxy-fake-\(UUID().uuidString)", isDirectory: true)
            let captureDir = temp.appendingPathComponent("capture", isDirectory: true)
            let exportPath = temp.appendingPathComponent("requests.ndjson")
            let adapter = FakeNetworkProxyHostAdapter()

            let start = try adapter.start(NetworkProxyStartRequest(platform: fixture.platform, target: fixture.target, captureMode: "record", outputDirectory: captureDir.path))

            #expect(start.ok)
            #expect(start.platform == fixture.platform.rawValue)
            #expect(start.target == fixture.target)
            #expect(start.captureMode == "record")
            #expect(start.proxyEndpoint == "127.0.0.1:19431")
            #expect(start.configured)
            #expect(start.visibility == .partial)
            #expect(start.restore?.available == true)
            #expect(start.restore?.snapshotPath?.hasSuffix("restore-state.json") == true)
            #expect(start.artifacts.contains { $0.kind == "network-capture" && $0.path.hasSuffix("requests.ndjson") })

            let restorePayload = try jsonDictionary(at: try #require(start.restore?.snapshotPath))
            #expect(restorePayload["platform"] as? String == fixture.platform.rawValue)
            #expect(restorePayload["target"] as? String == fixture.target.target)

            let status = adapter.status(platform: fixture.platform, target: fixture.target)
            #expect(status.ok)
            #expect(status.action == "proxy.status")
            #expect(status.configured)
            #expect(status.platform == fixture.platform.rawValue)
            #expect(status.target == fixture.target)
            #expect(status.proxyEndpoint == start.proxyEndpoint)

            let exported = try adapter.export(NetworkProxyExportRequest(platform: fixture.platform, target: fixture.target, outputPath: exportPath.path))
            #expect(exported.ok)
            #expect(exported.action == "proxy.export")
            #expect(exported.platform == fixture.platform.rawValue)
            #expect(exported.artifacts.count == 1)
            #expect(exported.artifacts[0].kind == "network-capture")
            #expect(exported.artifacts[0].path == exportPath.path)
            #expect((exported.artifacts[0].bytes ?? 0) > 0)
            #expect(FileManager.default.fileExists(atPath: exportPath.path))

            let exportPayload = try jsonDictionary(at: exportPath.path)
            #expect(exportPayload["platform"] as? String == fixture.platform.rawValue)
            #expect(exportPayload["target"] as? String == fixture.target.target)

            let stopped = adapter.stop(NetworkProxyStopRequest(platform: fixture.platform, target: fixture.target, restore: true))
            #expect(stopped.ok)
            #expect(stopped.action == "proxy.stop")
            #expect(stopped.platform == fixture.platform.rawValue)
            #expect(stopped.target == fixture.target)
            #expect(stopped.configured == false)
            #expect(stopped.restore?.restored == true)

            let afterStop = adapter.status(platform: fixture.platform, target: fixture.target)
            #expect(afterStop.ok)
            #expect(afterStop.configured == false)
            #expect(afterStop.limitations.contains("proxy_session_not_running"))
        }
    }

    @Test("fake proxy adapter reports proxy_not_running for export before start")
    func fakeProxyAdapterReportsNotRunningForExportBeforeStart() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-ios-proxy-export-\(UUID().uuidString).ndjson")
        let adapter = FakeNetworkProxyHostAdapter()
        let exported = try adapter.export(NetworkProxyExportRequest(platform: .ios, target: makeSimulatorProxyTarget(simulator: "SIM-1"), outputPath: temp.path))

        #expect(exported.ok == false)
        #expect(exported.action == "proxy.export")
        #expect(exported.error?.code == "proxy_not_running")
        #expect(exported.error?.nextAction?.command == "device")
        #expect(exported.error?.nextAction?.args == ["proxy", "start", "--platform", "ios", "--device", "SIM-1", "--mode", "record", "--json"])
    }

    @Test("Android proxy command plan sets and clears the emulator global HTTP proxy")
    func androidProxyCommandPlanSetsAndClearsGlobalHTTPProxy() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let override = adbProxyOverrideCommands(serial: "emulator-5554", endpoint: endpoint)
        let restore = adbProxyRestoreCommands(serial: "emulator-5554")

        #expect(override.map(hostSourceCommand) == [
            "adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:19431",
        ])
        #expect(restore.map(hostSourceCommand) == [
            "adb -s emulator-5554 shell settings delete global http_proxy",
        ])
        #expect((override + restore).allSatisfy { $0.riskLevel == .breakGlass })
        #expect((override + restore).allSatisfy { $0.requiredConfig == [.target, .timeout, .auditRecord] })
    }

    @Test("Android proxy restore plan preserves the original global HTTP proxy when snapshot captured it")
    func androidProxyRestorePlanPreservesOriginalGlobalHTTPProxy() throws {
        let snapshotCommands = adbProxySnapshotCommands(serial: "emulator-5554")
        let restore = adbProxyRestoreCommands(serial: "emulator-5554", originalHTTPProxy: "corp-proxy.local:8080")
        let cleared = adbProxyRestoreCommands(serial: "emulator-5554", originalHTTPProxy: nil)

        #expect(snapshotCommands.map(hostSourceCommand) == [
            "adb -s emulator-5554 shell settings get global http_proxy",
        ])
        #expect(snapshotCommands.allSatisfy { $0.riskLevel == .readonly })
        #expect(parseADBHTTPProxySetting(stdout: "corp-proxy.local:8080\n") == "corp-proxy.local:8080")
        #expect(parseADBHTTPProxySetting(stdout: "null\n") == nil)
        #expect(parseADBHTTPProxySetting(stdout: "\n") == nil)
        #expect(restore.map(hostSourceCommand) == [
            "adb -s emulator-5554 shell settings put global http_proxy corp-proxy.local:8080",
        ])
        #expect(cleared.map(hostSourceCommand) == [
            "adb -s emulator-5554 shell settings delete global http_proxy",
        ])
    }

    @Test("proxy stop plan-only can review original-value restore snapshot ledgers")
    func proxyStopPlanOnlyCanReviewOriginalValueRestoreSnapshotLedgers() throws {
        let target = try makeNetworkProxyPlanTarget(platform: .android, device: "emulator-5554")
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-stop-plan-snapshot-\(UUID().uuidString)", isDirectory: true)
        let restoreCommands = adbProxyRestoreCommands(serial: "emulator-5554", originalHTTPProxy: "corp-proxy.local:8080")
        let snapshotPath = try #require(try writeNetworkProxyRestoreSnapshot(
            platform: .android,
            target: target,
            endpoint: endpoint,
            auditRecord: "ticket-plan",
            snapshotCommands: adbProxySnapshotCommands(serial: "emulator-5554"),
            startCommands: adbProxyOverrideCommands(serial: "emulator-5554", endpoint: endpoint),
            restoreCommands: restoreCommands,
            androidOriginalHTTPProxy: "corp-proxy.local:8080",
            outputDirectory: directory.path
        ))

        let plan = try makeNetworkProxyStopPlanSession(
            platform: .android,
            target: target,
            restore: false,
            restoreSnapshotPath: snapshotPath
        )

        #expect(plan.ok)
        #expect(plan.action == "proxy.stop")
        #expect(plan.configured == false)
        #expect(plan.restore?.available == true)
        #expect(plan.restore?.snapshotPath == snapshotPath)
        #expect(plan.restore?.restored == false)
        #expect(plan.limitations.contains("proxy_plan_only:not_executed"))
        #expect(plan.limitations.contains("proxy_restore_snapshot_plan:original_value_ledger"))
        #expect(plan.sourceCommands == restoreCommands.map(hostSourceCommand))
    }

    @Test("Android proxy command plan preserves explicit non-loopback proxy hosts")
    func androidProxyCommandPlanPreservesExplicitNonLoopbackHosts() throws {
        let endpoint = try NetworkProxyEndpoint("192.168.1.10:19431")
        let override = adbProxyOverrideCommands(serial: "emulator-5554", endpoint: endpoint)

        #expect(override.map(hostSourceCommand) == [
            "adb -s emulator-5554 shell settings put global http_proxy 192.168.1.10:19431",
        ])
    }

    @Test("Harmony proxy plan is probe-only until a real DevEco proxy command is verified")
    func harmonyProxyPlanIsProbeOnlyUntilVerified() {
        let commands = harmonyProxyProbeCommands(target: "127.0.0.1:10100")

        #expect(commands.map(hostSourceCommand) == [
            "hdc -t 127.0.0.1:10100 shell param get bootevent.boot.completed",
            "hdc -t 127.0.0.1:10100 shell echo triton-shell-ready",
        ])
        #expect(commands.allSatisfy { $0.riskLevel == .readonly })
        #expect(commands.allSatisfy { $0.requiredConfig == [.target, .timeout] })
    }

    @Test("proxy start plan-only exposes three-platform host command ledgers without configuring proxies")
    func proxyStartPlanOnlyExposesThreePlatformHostCommandLedgers() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let plans = try networkProxyTargetFixtures().map { fixture in
            try makeNetworkProxyStartPlanSession(
                platform: fixture.platform,
                target: fixture.target,
                captureMode: "record",
                endpoint: endpoint
            )
        }

        #expect(plans.map(\.platform) == ["ios", "android", "harmony"])
        #expect(plans.allSatisfy { $0.ok })
        #expect(plans.allSatisfy { $0.action == "proxy.start" })
        #expect(plans.allSatisfy { $0.configured == false })
        #expect(plans.allSatisfy { $0.proxyEndpoint == "127.0.0.1:19431" })
        #expect(plans.allSatisfy { $0.limitations.contains("proxy_plan_only:not_executed") })
        #expect(plans[0].sourceCommands == [
            "/usr/sbin/networksetup -setwebproxy Wi-Fi 127.0.0.1 19431",
            "/usr/sbin/networksetup -setwebproxystate Wi-Fi on",
            "/usr/sbin/networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 19431",
            "/usr/sbin/networksetup -setsecurewebproxystate Wi-Fi on",
            "/usr/sbin/networksetup -setsocksfirewallproxystate Wi-Fi off",
        ])
        #expect(plans[1].sourceCommands == [
            "adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:19431",
        ])
        #expect(plans[2].sourceCommands == [
            "hdc -t 127.0.0.1:10100 shell param get bootevent.boot.completed",
            "hdc -t 127.0.0.1:10100 shell echo triton-shell-ready",
        ])
    }

    @Test("proxy stop plan-only exposes three-platform restore command ledgers without executing restore")
    func proxyStopPlanOnlyExposesThreePlatformRestoreCommandLedgers() throws {
        let plans = try networkProxyTargetFixtures().map { fixture in
            try makeNetworkProxyStopPlanSession(platform: fixture.platform, target: fixture.target, restore: true)
        }

        #expect(plans.map(\.platform) == ["ios", "android", "harmony"])
        #expect(plans.allSatisfy { $0.ok })
        #expect(plans.allSatisfy { $0.action == "proxy.stop" })
        #expect(plans.allSatisfy { $0.configured == false })
        #expect(plans.allSatisfy { $0.restore?.restored == false })
        #expect(plans.allSatisfy { $0.limitations.contains("proxy_plan_only:not_executed") })
        #expect(plans[0].sourceCommands == [
            "/usr/sbin/networksetup -setwebproxystate Wi-Fi off",
            "/usr/sbin/networksetup -setsecurewebproxystate Wi-Fi off",
            "/usr/sbin/networksetup -setsocksfirewallproxystate Wi-Fi off",
        ])
        #expect(plans[1].sourceCommands == [
            "adb -s emulator-5554 shell settings delete global http_proxy",
        ])
        #expect(plans[2].sourceCommands == [
            "hdc -t 127.0.0.1:10100 shell param get bootevent.boot.completed",
            "hdc -t 127.0.0.1:10100 shell echo triton-shell-ready",
        ])
        #expect(plans[2].limitations.contains("proxy_restore_probe_only:no_verified_harmony_proxy_mutation"))
    }

    @Test("proxy export plan-only exposes three-platform artifact plans without writing files")
    func proxyExportPlanOnlyExposesThreePlatformArtifactPlans() throws {
        let plans = try networkProxyTargetFixtures().map { fixture in
            try makeNetworkProxyExportPlanSession(
                platform: fixture.platform,
                target: fixture.target,
                outputPath: "/tmp/\(fixture.platform.rawValue)-network.ndjson"
            )
        }

        #expect(plans.map(\.platform) == ["ios", "android", "harmony"])
        #expect(plans.allSatisfy { $0.ok })
        #expect(plans.allSatisfy { $0.action == "proxy.export" })
        #expect(plans.allSatisfy { $0.configured == false })
        #expect(plans.allSatisfy { $0.visibility == .unknown })
        #expect(plans.allSatisfy { $0.restore?.available == false })
        #expect(plans.allSatisfy { $0.sourceCommands.isEmpty })
        #expect(plans.allSatisfy { $0.limitations.contains("proxy_plan_only:not_executed") })
        #expect(plans.allSatisfy { $0.limitations.contains("proxy_export_plan_only:artifact_not_written") })
        #expect(plans.allSatisfy { $0.artifacts.count == 1 })
        #expect(plans.allSatisfy { $0.artifacts[0].kind == "network-capture" })
        #expect(plans.allSatisfy { $0.artifacts[0].bytes == nil })
        #expect(plans[0].artifacts[0].path == "/tmp/ios-network.ndjson")
        #expect(plans[1].artifacts[0].path == "/tmp/android-network.ndjson")
        #expect(plans[2].artifacts[0].path == "/tmp/harmony-network.ndjson")
    }

    @Test("proxy mutating execution requires explicit break-glass policy before runner wiring")
    func proxyMutatingExecutionRequiresExplicitBreakGlassPolicy() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let iosTarget = makeSimulatorProxyTarget(simulator: "booted")

        let missingPolicy = try makeNetworkProxyExecutionPolicyRequiredSession(
            action: .start,
            platform: .ios,
            target: iosTarget,
            captureMode: "record",
            confirm: false,
            auditRecord: nil,
            executeRunner: false
        )
        #expect(missingPolicy.ok == false)
        #expect(missingPolicy.error?.code == "destructive_action_requires_policy")
        #expect(missingPolicy.error?.nextAction?.command == "device")
        #expect(missingPolicy.error?.nextAction?.args.contains("--confirm") == true)
        #expect(missingPolicy.error?.nextAction?.args.contains("--audit-record") == true)

        let armed = try makeNetworkProxyRunnerNotConfiguredSession(
            action: .start,
            platform: .ios,
            target: iosTarget,
            captureMode: "record",
            sourceCommands: networkProxyStartPlanCommands(platform: .ios, target: iosTarget, endpoint: endpoint).map(hostSourceCommand),
            auditRecord: "ticket-123"
        )
        #expect(armed.ok == false)
        #expect(armed.error?.code == "proxy_runner_not_configured")
        #expect(armed.sourceCommands.contains("/usr/sbin/networksetup -setwebproxy Wi-Fi 127.0.0.1 19431"))
        #expect(armed.limitations.contains("proxy_execution_policy_accepted:auditRecord=ticket-123"))
        #expect(armed.limitations.contains("proxy_runner_not_configured:not_executed"))
    }

    @Test("proxy execution policy requires explicit runner opt-in before calling host commands")
    func proxyExecutionPolicyRequiresExplicitRunnerOptIn() throws {
        let iosTarget = makeSimulatorProxyTarget(simulator: "booted")

        let missingRunnerOptIn = try makeNetworkProxyExecutionPolicyRequiredSession(
            action: .start,
            platform: .ios,
            target: iosTarget,
            captureMode: "record",
            confirm: true,
            auditRecord: "ticket-123",
            executeRunner: false
        )

        #expect(missingRunnerOptIn.ok == false)
        #expect(missingRunnerOptIn.error?.code == "destructive_action_requires_policy")
        #expect(missingRunnerOptIn.limitations.contains("proxy_execution_policy_required:executeRunner=false"))
        #expect(missingRunnerOptIn.error?.nextAction?.args.contains("--execute-runner") == true)
    }

    @Test("proxy start endpoint preflight blocks runner before mutating proxy settings")
    func proxyStartEndpointPreflightBlocksRunnerBeforeMutation() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let androidTarget = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )
        var preflightEndpoints: [String] = []
        var runnerWasCalled = false

        let blocked = try makeNetworkProxyStartExecutedSession(
            platform: .android,
            target: androidTarget,
            captureMode: "record",
            endpoint: endpoint,
            auditRecord: "ticket-preflight",
            runner: { command in
                runnerWasCalled = true
                return successfulHostProcessResult(command)
            },
            endpointPreflight: { endpoint in
                preflightEndpoints.append("\(endpoint.host):\(endpoint.port)")
                return false
            }
        )

        #expect(blocked.ok == false)
        #expect(blocked.configured == false)
        #expect(blocked.proxyEndpoint == "127.0.0.1:19431")
        #expect(blocked.error?.code == "proxy_endpoint_unreachable")
        #expect(blocked.error?.nextAction?.category == "diagnose")
        #expect(blocked.limitations.contains("proxy_endpoint_unreachable:not_mutated"))
        #expect(blocked.sourceCommands == [
            "adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:19431",
        ])
        #expect(preflightEndpoints == ["127.0.0.1:19431"])
        #expect(runnerWasCalled == false)
    }

    @Test("proxy start writes restore snapshot and stop can execute that snapshot ledger")
    func proxyStartWritesRestoreSnapshotAndStopExecutesSnapshotLedger() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let target = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-restore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var executed: [String] = []
        let runner: NetworkProxyCommandRunner = { command in
            executed.append(hostSourceCommand(command))
            if command.arguments == ["-s", "emulator-5554", "shell", "settings", "get", "global", "http_proxy"] {
                return successfulHostProcessResult(command, stdout: "corp-proxy.local:8080\n")
            }
            return successfulHostProcessResult(command)
        }

        let started = try makeNetworkProxyStartExecutedSession(
            platform: .android,
            target: target,
            captureMode: "record",
            endpoint: endpoint,
            auditRecord: "ticket-restore",
            runner: runner,
            endpointPreflight: { _ in true },
            outputDirectory: directory.path
        )

        let snapshotPath = try #require(started.restore?.snapshotPath)
        #expect(started.ok)
        #expect(started.restore?.available == true)
        #expect(started.limitations.contains("proxy_restore_snapshot_written"))
        #expect(FileManager.default.fileExists(atPath: snapshotPath))

        let snapshot = try loadNetworkProxyRestoreSnapshot(path: snapshotPath)
        #expect(snapshot.schemaVersion == "triton.proxy.restore.v1")
        #expect(snapshot.platform == "android")
        #expect(snapshot.target == "emulator-5554")
        #expect(snapshot.proxyEndpoint == "127.0.0.1:19431")
        #expect(snapshot.auditRecord == "ticket-restore")
        #expect(snapshot.sourceCommands == [
            "adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:19431",
        ])
        #expect(snapshot.restoreSourceCommands == [
            "adb -s emulator-5554 shell settings put global http_proxy corp-proxy.local:8080",
        ])
        #expect(snapshot.snapshotSourceCommands == [
            "adb -s emulator-5554 shell settings get global http_proxy",
        ])
        #expect(snapshot.androidOriginalHTTPProxy == "corp-proxy.local:8080")
        let sessionState = try loadNetworkProxySessionState(directory: directory.path)
        #expect(sessionState.schemaVersion == "triton.proxy.session.v1")
        #expect(sessionState.platform == "android")
        #expect(sessionState.target == "emulator-5554")
        #expect(sessionState.configured)
        #expect(sessionState.artifacts.contains { $0.kind == "network-capture" && $0.path.hasSuffix("requests.ndjson") })

        let stopStartIndex = executed.count
        let stopped = try makeNetworkProxyStopExecutedSession(
            platform: .android,
            target: target,
            restore: false,
            auditRecord: "ticket-restore",
            runner: runner,
            restoreSnapshotPath: snapshotPath
        )

        #expect(stopped.ok)
        #expect(stopped.configured == false)
        #expect(stopped.restore?.available == true)
        #expect(stopped.restore?.snapshotPath == snapshotPath)
        #expect(stopped.restore?.restored == true)
        #expect(stopped.limitations.contains("proxy_restore_snapshot_used"))
        #expect(stopped.sourceCommands == snapshot.restoreSourceCommands)
        #expect(Array(executed.dropFirst(stopStartIndex)) == snapshot.restoreSourceCommands)
    }

    @Test("proxy session state can report status and export capture artifacts across CLI invocations")
    func proxySessionStateReportsStatusAndExportsCaptureArtifacts() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let target = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-session-\(UUID().uuidString)", isDirectory: true)
        let exportPath = directory.appendingPathComponent("exported.ndjson")
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner: NetworkProxyCommandRunner = { command in
            if command.arguments == ["-s", "emulator-5554", "shell", "settings", "get", "global", "http_proxy"] {
                return successfulHostProcessResult(command, stdout: "null\n")
            }
            return successfulHostProcessResult(command)
        }

        let started = try makeNetworkProxyStartExecutedSession(
            platform: .android,
            target: target,
            captureMode: "record",
            endpoint: endpoint,
            auditRecord: "ticket-session",
            runner: runner,
            endpointPreflight: { _ in true },
            outputDirectory: directory.path
        )
        #expect(started.ok)
        #expect(started.limitations.contains("proxy_session_state_written"))
        #expect(started.artifacts.contains { $0.kind == "network-capture" && $0.path.hasSuffix("requests.ndjson") })
        #expect(FileManager.default.fileExists(atPath: networkProxySessionStateURL(directory: directory.path).path))

        let restoreSnapshotPath = try #require(started.restore?.snapshotPath)
        let restoreFailure = NetworkProxyRestoreFailurePayload(
            schemaVersion: "triton.proxy.restore-failure.v1",
            platform: "android",
            target: "emulator-5554",
            action: "proxy.stop",
            auditRecord: "ticket-session",
            restoreSnapshotPath: restoreSnapshotPath,
            restoreSourceCommands: ["adb -s emulator-5554 shell settings delete global http_proxy"],
            errorCode: "proxy_restore_failed",
            errorSummary: "denied",
            capturedAt: "2026-06-11T00:00:00Z"
        )
        let restoreFailureURL = URL(fileURLWithPath: restoreSnapshotPath)
            .deletingLastPathComponent()
            .appendingPathComponent("restore-failure.json")
        try prettyEncodedData(restoreFailure).write(to: restoreFailureURL, options: .atomic)

        let status = try makeNetworkProxyStatusSession(platform: .android, target: target, sessionDirectory: directory.path)
        #expect(status.ok)
        #expect(status.action == "proxy.status")
        #expect(status.configured)
        #expect(status.proxyEndpoint == "127.0.0.1:19431")
        #expect(status.restore?.snapshotPath?.hasSuffix("restore-state.json") == true)
        let statusRestoreArtifact = try #require(status.artifacts.first { $0.kind == "proxy-restore" })
        #expect(statusRestoreArtifact.path.hasSuffix("restore-failure.json"))
        let restoreFailureByteCount = try Data(contentsOf: restoreFailureURL).count
        #expect(statusRestoreArtifact.bytes == restoreFailureByteCount)

        let exported = try makeNetworkProxyExportSession(platform: .android, target: target, sessionDirectory: directory.path, outputPath: exportPath.path)
        #expect(exported.ok)
        #expect(exported.action == "proxy.export")
        #expect(exported.configured)
        #expect(exported.artifacts == [NetworkProxyArtifact(kind: "network-capture", path: exportPath.path, bytes: try Data(contentsOf: exportPath).count)])
        #expect(exported.requestCount == 0)
        #expect(exported.redaction == "default")
        #expect(exported.truncation == "none")
        let exportedPayload = try jsonDictionary(at: exportPath.path)
        #expect(exportedPayload["schemaVersion"] as? String == "triton.network.v1")
        #expect(exportedPayload["platform"] as? String == "android")
        #expect(exportedPayload["target"] as? String == "emulator-5554")
    }

    @Test("proxy session export writes HAR when requested by output extension")
    func proxySessionExportWritesHARWhenRequestedByOutputExtension() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let target = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-session-har-\(UUID().uuidString)", isDirectory: true)
        let exportPath = directory.appendingPathComponent("exported.har")
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner: NetworkProxyCommandRunner = { command in
            if command.arguments == ["-s", "emulator-5554", "shell", "settings", "get", "global", "http_proxy"] {
                return successfulHostProcessResult(command, stdout: "null\n")
            }
            return successfulHostProcessResult(command)
        }

        let started = try makeNetworkProxyStartExecutedSession(
            platform: .android,
            target: target,
            captureMode: "record",
            endpoint: endpoint,
            auditRecord: "ticket-session-har",
            runner: runner,
            endpointPreflight: { _ in true },
            outputDirectory: directory.path
        )
        let capturePath = try #require(started.artifacts.first(where: { $0.kind == "network-capture" })?.path)
        let request = Data((
            "GET http://example.test/session?q=1 HTTP/1.1\r\n" +
            "Host: example.test\r\n" +
            "X-Trace: secret\r\n" +
            "\r\n"
        ).utf8)
        let event = try parseNetworkProxyHTTPHeader(
            request,
            listen: "127.0.0.1:19431",
            capturePath: capturePath,
            connectionIndex: 1
        )
        try Data((try encodeCompactJSON(event) + "\n").utf8).write(to: URL(fileURLWithPath: capturePath))

        let exported = try makeNetworkProxyExportSession(platform: .android, target: target, sessionDirectory: directory.path, outputPath: exportPath.path)
        let har = try jsonDictionary(at: exportPath.path)
        let log = try #require(har["log"] as? [String: Any])
        let entries = try #require(log["entries"] as? [[String: Any]])
        let requestPayload = try #require(entries.first?["request"] as? [String: Any])

        #expect(exported.ok)
        #expect(exported.action == "proxy.export")
        #expect(exported.artifacts == [NetworkProxyArtifact(kind: "network-capture", path: exportPath.path, bytes: try Data(contentsOf: exportPath).count)])
        #expect(exported.requestCount == 1)
        #expect(exported.redaction == "headers-names-only")
        #expect(exported.truncation == "none")
        #expect(log["version"] as? String == "1.2")
        #expect(entries.count == 1)
        #expect(requestPayload["method"] as? String == "GET")
        #expect(requestPayload["url"] as? String == "http://example.test/session?q=1")
    }

    @Test("proxy session export returns stable artifact write failure when capture is missing")
    func proxySessionExportReturnsStableArtifactWriteFailureWhenCaptureIsMissing() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let target = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-session-missing-capture-\(UUID().uuidString)", isDirectory: true)
        let exportPath = directory.appendingPathComponent("exported.har")
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner: NetworkProxyCommandRunner = { command in
            if command.arguments == ["-s", "emulator-5554", "shell", "settings", "get", "global", "http_proxy"] {
                return successfulHostProcessResult(command, stdout: "null\n")
            }
            return successfulHostProcessResult(command)
        }

        let started = try makeNetworkProxyStartExecutedSession(
            platform: .android,
            target: target,
            captureMode: "record",
            endpoint: endpoint,
            auditRecord: "ticket-missing-capture",
            runner: runner,
            endpointPreflight: { _ in true },
            outputDirectory: directory.path
        )
        let capturePath = try #require(started.artifacts.first(where: { $0.kind == "network-capture" })?.path)
        try FileManager.default.removeItem(atPath: capturePath)

        let exported = try makeNetworkProxyExportSession(platform: .android, target: target, sessionDirectory: directory.path, outputPath: exportPath.path)

        #expect(exported.ok == false)
        #expect(exported.action == "proxy.export")
        #expect(exported.error?.code == "proxy_artifact_write_failed")
        #expect(exported.error?.nextAction?.category == "archive")
        #expect(exported.artifacts == [NetworkProxyArtifact(kind: "network-capture", path: exportPath.path, bytes: nil)])
    }

    @Test("device proxy export CLI writes HAR from a persisted session")
    func deviceProxyExportCLIWritesHARFromPersistedSession() async throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let target = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-cli-har-\(UUID().uuidString)", isDirectory: true)
        let exportPath = directory.appendingPathComponent("cli.har")
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner: NetworkProxyCommandRunner = { command in
            if command.arguments == ["-s", "emulator-5554", "shell", "settings", "get", "global", "http_proxy"] {
                return successfulHostProcessResult(command, stdout: "null\n")
            }
            return successfulHostProcessResult(command)
        }

        let started = try makeNetworkProxyStartExecutedSession(
            platform: .android,
            target: target,
            captureMode: "record",
            endpoint: endpoint,
            auditRecord: "ticket-cli-har",
            runner: runner,
            endpointPreflight: { _ in true },
            outputDirectory: directory.path
        )
        let capturePath = try #require(started.artifacts.first(where: { $0.kind == "network-capture" })?.path)
        let request = Data((
            "GET http://example.test/cli HTTP/1.1\r\n" +
            "Host: example.test\r\n" +
            "X-CLI: secret\r\n" +
            "\r\n"
        ).utf8)
        let event = try parseNetworkProxyHTTPHeader(
            request,
            listen: "127.0.0.1:19431",
            capturePath: capturePath,
            connectionIndex: 1
        )
        try Data((try encodeCompactJSON(event) + "\n").utf8).write(to: URL(fileURLWithPath: capturePath))

        let command = try DeviceProxyExport.parse([
            "--platform", "android",
            "--device", "emulator-5554",
            "--session", directory.path,
            "--output", exportPath.path,
            "--json",
        ])
        let exported = try makeNetworkProxyExportSession(
            platform: command.platform,
            target: makeNetworkProxyPlanTarget(platform: command.platform, device: command.device),
            sessionDirectory: command.session,
            outputPath: command.output
        )
        let artifact = try #require(exported.artifacts.first)
        let har = try jsonDictionary(at: exportPath.path)
        let log = try #require(har["log"] as? [String: Any])
        let entries = try #require(log["entries"] as? [[String: Any]])

        #expect(exported.ok)
        #expect(artifact.path == exportPath.path)
        #expect(exported.requestCount == 1)
        #expect(exported.redaction == "headers-names-only")
        #expect(exported.truncation == "none")
        #expect(entries.count == 1)
    }

    @Test("proxy command runner can execute accepted iOS and Android start and restore plans under fake runner")
    func proxyCommandRunnerExecutesAcceptedIOSAndAndroidPlansUnderFakeRunner() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        for fixture in networkProxyTargetFixtures().filter({ $0.platform != .harmony }) {
            var executed: [String] = []
            let runner: NetworkProxyCommandRunner = { command in
                executed.append(hostSourceCommand(command))
                return successfulHostProcessResult(command)
            }

            let started = try makeNetworkProxyStartExecutedSession(
                platform: fixture.platform,
                target: fixture.target,
                captureMode: "record",
                endpoint: endpoint,
                auditRecord: "ticket-\(fixture.platform.rawValue)",
                runner: runner,
                endpointPreflight: { _ in true }
            )

            #expect(started.ok)
            #expect(started.configured)
            #expect(started.proxyEndpoint == "127.0.0.1:19431")
            #expect(started.sourceCommands == networkProxyStartPlanCommands(platform: fixture.platform, target: fixture.target, endpoint: endpoint).map(hostSourceCommand))
            #expect(started.limitations.contains("proxy_execution_policy_accepted:auditRecord=ticket-\(fixture.platform.rawValue)"))
            #expect(started.limitations.contains("proxy_runner_executed:break_glass"))
            #expect(started.restore?.available == true)
            #expect(started.restore?.restored == nil)
            #expect(executed == started.sourceCommands)

            let stopStartIndex = executed.count
            let stopped = try makeNetworkProxyStopExecutedSession(
                platform: fixture.platform,
                target: fixture.target,
                restore: true,
                auditRecord: "ticket-\(fixture.platform.rawValue)",
                runner: runner
            )

            #expect(stopped.ok)
            #expect(stopped.configured == false)
            #expect(stopped.restore?.available == true)
            #expect(stopped.restore?.restored == true)
            #expect(stopped.sourceCommands == networkProxyStopPlanCommands(platform: fixture.platform, target: fixture.target, restore: true).map(hostSourceCommand))
            #expect(Array(executed.dropFirst(stopStartIndex)) == stopped.sourceCommands)
        }
    }

    @Test("proxy command runner reports stable start and restore failure envelopes")
    func proxyCommandRunnerReportsStableFailureEnvelopes() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let iosTarget = makeSimulatorProxyTarget(simulator: "SIM-FAIL")
        let runner: NetworkProxyCommandRunner = { command in
            throw HostCommandRunError.nonZeroExit(command: command, result: failedHostProcessResult(command, stderr: "denied"))
        }

        let start = try makeNetworkProxyStartExecutedSession(
            platform: .ios,
            target: iosTarget,
            captureMode: "record",
            endpoint: endpoint,
            auditRecord: "ticket-fail",
            runner: runner,
            endpointPreflight: { _ in true }
        )
        #expect(start.ok == false)
        #expect(start.configured == false)
        #expect(start.error?.code == "proxy_start_failed")
        #expect(start.error?.nextAction?.category == "diagnose")
        #expect(start.sourceCommands == networkProxyStartPlanCommands(platform: .ios, target: iosTarget, endpoint: endpoint).map(hostSourceCommand))
        #expect(start.limitations.contains("proxy_execution_policy_accepted:auditRecord=ticket-fail"))

        let stop = try makeNetworkProxyStopExecutedSession(
            platform: .ios,
            target: iosTarget,
            restore: true,
            auditRecord: "ticket-fail",
            runner: runner
        )
        #expect(stop.ok == false)
        #expect(stop.configured == false)
        #expect(stop.restore?.available == true)
        #expect(stop.restore?.restored == false)
        #expect(stop.error?.code == "proxy_restore_failed")
        #expect(stop.sourceCommands == networkProxyStopPlanCommands(platform: .ios, target: iosTarget, restore: true).map(hostSourceCommand))

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-proxy-restore-failure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let restoreCommands = [
            TKHostCommand(
                executable: "networksetup",
                arguments: ["-setwebproxystate", "Wi-Fi", "off"],
                riskLevel: .breakGlass,
                requiredConfig: [.target, .timeout, .auditRecord]
            ),
        ]
        let writtenSnapshotPath = try writeNetworkProxyRestoreSnapshot(
            platform: .ios,
            target: iosTarget,
            endpoint: endpoint,
            auditRecord: "ticket-fail",
            startCommands: networkProxyStartPlanCommands(platform: .ios, target: iosTarget, endpoint: endpoint),
            restoreCommands: restoreCommands,
            outputDirectory: directory.path
        )
        let snapshotPath = try #require(writtenSnapshotPath)

        let failedSnapshotRestore = try makeNetworkProxyStopExecutedSession(
            platform: .ios,
            target: iosTarget,
            restore: false,
            auditRecord: "ticket-fail",
            runner: runner,
            restoreSnapshotPath: snapshotPath
        )
        let restoreArtifact = try #require(failedSnapshotRestore.artifacts.first { $0.kind == "proxy-restore" })
        #expect(failedSnapshotRestore.ok == false)
        #expect(failedSnapshotRestore.restore?.snapshotPath == snapshotPath)
        #expect(failedSnapshotRestore.restore?.restored == false)
        #expect(failedSnapshotRestore.limitations.contains("proxy_restore_failure_artifact_written"))
        #expect(restoreArtifact.path.hasSuffix("restore-failure.json"))
        #expect((restoreArtifact.bytes ?? 0) > 0)
        #expect(FileManager.default.fileExists(atPath: restoreArtifact.path))

        let payloadData = try Data(contentsOf: URL(fileURLWithPath: restoreArtifact.path))
        let payload = try JSONDecoder().decode(NetworkProxyRestoreFailurePayload.self, from: payloadData)
        #expect(payload.schemaVersion == "triton.proxy.restore-failure.v1")
        #expect(payload.platform == "ios")
        #expect(payload.target == "SIM-FAIL")
        #expect(payload.action == "proxy.stop")
        #expect(payload.auditRecord == "ticket-fail")
        #expect(payload.restoreSnapshotPath == snapshotPath)
        #expect(payload.restoreSourceCommands == restoreCommands.map(hostSourceCommand))
        #expect(payload.errorCode == "proxy_restore_failed")
        #expect(payload.errorSummary == "denied")
        #expect(payload.capturedAt.isEmpty == false)
    }

    @Test("Harmony proxy execution remains blocked until platform mutation command is verified")
    func harmonyProxyExecutionRemainsBlockedUntilVerified() throws {
        let harmonyTarget = HostDeviceTarget(
            platform: "harmony",
            id: "harmony:127.0.0.1:10100",
            target: "127.0.0.1:10100",
            state: "Unknown",
            ready: false,
            source: "proxy-plan",
            name: nil,
            runtime: nil,
            transport: nil,
            scope: "emulator",
            kind: "emulator"
        )

        let blocked = try makeNetworkProxyUnverifiedPlatformSession(
            action: .start,
            platform: .harmony,
            target: harmonyTarget,
            captureMode: "record",
            auditRecord: "ticket-456"
        )

        #expect(blocked.ok == false)
        #expect(blocked.error?.code == "proxy_unverified_platform_proxy")
        #expect(blocked.sourceCommands == [
            "hdc -t 127.0.0.1:10100 shell param get bootevent.boot.completed",
            "hdc -t 127.0.0.1:10100 shell echo triton-shell-ready",
        ])
        #expect(blocked.limitations.contains("proxy_execution_policy_accepted:auditRecord=ticket-456"))
        #expect(blocked.limitations.contains("proxy_harmony_probe_only:no_verified_proxy_mutation"))
    }

    @Test("Harmony emulator stop plans launchd bootout before DevEco stop")
    func harmonyEmulatorStopPlansLaunchdBootoutBeforeDevEcoStop() throws {
        let plan = try harmonyEmulatorStopPlan(
            hvd: "Codex Test Phone",
            deployedPath: "/Users/linhey/.Huawei/Emulator/deployed",
            emulator: "/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator",
            launchdLabel: "triton-harmony-emulator",
            launchdDomain: "gui/501",
            includeLaunchd: true,
            confirmed: true
        )

        #expect(plan.action == "device.stop")
        #expect(plan.platform == "harmony")
        #expect(plan.hvd == "Codex Test Phone")
        #expect(plan.launchdLabel == "triton-harmony-emulator")
        #expect(plan.launchdDomain == "gui/501")
        #expect(plan.commands.map(hostSourceCommand) == [
            "launchctl print gui/501/triton-harmony-emulator",
            "launchctl bootout gui/501/triton-harmony-emulator",
            "/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator -stop 'Codex Test Phone' -path /Users/linhey/.Huawei/Emulator/deployed",
        ])
    }

    @Test("Harmony emulator stop requires explicit confirmation")
    func harmonyEmulatorStopRequiresConfirmation() {
        #expect(throws: HostDeviceSelectionError.self) {
            _ = try harmonyEmulatorStopPlan(
                hvd: "Codex Test Phone",
                deployedPath: "/Users/linhey/.Huawei/Emulator/deployed",
                emulator: "/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator",
                launchdLabel: "triton-harmony-emulator",
                launchdDomain: "gui/501",
                includeLaunchd: true,
                confirmed: false
            )
        }
    }

    @Test("sim screenshot metadata documents raw framebuffer orientation semantics")
    func simulatorScreenshotMetadataDocumentsRawFramebufferOrientationSemantics() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-sim-screenshot-metadata-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let path = temp.appendingPathComponent("shot.png")
        try writeMinimalPNG(width: 768, height: 1024, to: path)

        let metadata = try makeSimulatorScreenshotMetadata(outputPath: path.path)

        #expect(metadata.path == path.path)
        #expect(metadata.contentType == "image/png")
        #expect(metadata.pixelWidth == 768)
        #expect(metadata.pixelHeight == 1024)
        #expect(metadata.orientationSemantics == "raw-simctl-framebuffer")
        #expect(metadata.normalizationApplied == false)
        #expect(metadata.normalizationStrategy == "metadata-only")
        #expect(metadata.note.contains("raw framebuffer"))
    }

    @Test("app and smoke schemas expose unified device selector with explicit selector forms")
    func appAndSmokeSchemasExposeUnifiedDeviceSelector() throws {
        let app = try #require(commandSchemas().first { $0.name == "app" })
        let smoke = try #require(commandSchemas().first { $0.name == "smoke" })

        let appOptionNames = app.options.map(\.name)
        let smokeOptionNames = smoke.options.map(\.name)

        #expect(appOptionNames.contains("--device"))
        #expect(appOptionNames.contains("--simulator"))
        #expect(appOptionNames.contains("--target"))
        #expect(appOptionNames.contains("--name"))
        #expect(appOptionNames.contains("--runtime"))
        #expect(appOptionNames.contains("--package-name"))
        #expect(appOptionNames.contains("--activity"))
        #expect(appOptionNames.contains("--apk"))
        #expect(app.examples.contains("triton app list --device iphone15 --user-only --json"))
        #expect(app.examples.contains("triton app install --device android-a --platform android --apk /tmp/Demo.apk --json"))
        #expect(app.examples.contains("triton app launch --device android-a --platform android --package-name com.example.app --json"))
        #expect(app.examples.contains("triton app open-url example://debug --device android-a --platform android --package-name com.example.app --json"))
        #expect(app.examples.contains("triton app install --device harmony-a --hap /tmp/Demo.hap --json"))
        #expect(app.examples.contains("triton app info --device <ios-real-target> --platform ios --scope real --bundle-id com.example.app --json"))
        #expect(app.examples.contains("triton app list --device <android-real-target> --platform android --scope real --user-only --json"))
        #expect(app.examples.contains("triton app terminate --device <harmony-real-target> --platform harmony --scope real --bundle com.example.app --json"))
        #expect(app.examples.contains(#"triton app go "example://debug""#))
        #expect(app.examples.contains(#"triton app go "example://debug" --device iphone15"#))
        #expect(app.examples.contains("triton app prefs get DEBUG-mock --device iphone15 --bundle-id com.example.app --json"))
        #expect(app.providedCapabilities.contains("ios-real-app"))
        #expect(app.providedCapabilities.contains("android-app"))
        #expect(app.providedCapabilities.contains("android-app-install"))
        #expect(app.providedCapabilities.contains("android-app-launch"))
        #expect(app.providedCapabilities.contains("android-app-terminate"))
        #expect(app.providedCapabilities.contains("android-app-open-url"))
        #expect(app.providedCapabilities.contains("harmony-app-info"))

        #expect(smokeOptionNames.contains("--device"))
        #expect(smokeOptionNames.contains("--simulator"))
        #expect(smokeOptionNames.contains("--target"))
        #expect(smokeOptionNames.contains("--ready"))
        #expect(smoke.examples.contains("triton smoke ios --device iphone15 --bundle-id com.example.app --open-url myapp://home --wait-text Ready --json"))
        #expect(smoke.examples.contains("triton smoke harmony --device harmony-a --bundle com.example.app --ability EntryAbility --open-url example://home --wait-text Ready --screenshot /tmp/smoke.jpeg --evidence /tmp/harmony.tritonevidence --json"))
    }

    @Test("unified device selector rejects mixed selector conflicts")
    func unifiedDeviceSelectorRejectsLegacySelectorConflicts() {
        #expect(throws: HostDeviceSelectionError.self) {
            try ensureHostDeviceSelectorCompatibility(device: "iphone15", simulator: "booted", target: nil)
        }
        #expect(throws: HostDeviceSelectionError.self) {
            try ensureHostDeviceSelectorCompatibility(device: "harmony-a", simulator: nil, target: "127.0.0.1:10100")
        }
        #expect((try? ensureHostDeviceSelectorCompatibility(device: "iphone15", simulator: nil, target: nil)) != nil)
        #expect((try? ensureHostDeviceSelectorCompatibility(device: nil, simulator: "booted", target: nil)) != nil)
    }

    @Test("host device target mapping keeps a platform-neutral envelope")
    func hostDeviceTargetMappingKeepsAPlatformNeutralEnvelope() {
        let iosSimulator = TKHostSimulatorTarget(
            udid: "SIM-1",
            name: "iPhone 15",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
            state: "Booted",
            isAvailable: true,
            source: "simctl"
        )
        let harmonyTarget = TKHarmonyTarget(target: "127.0.0.1:10100", state: "Connected", transport: "TCP", source: "hdc")
        let androidTarget = TKAndroidTarget(serial: "emulator-5554", state: "device", product: "sdk_gphone64_arm64", model: "Pixel_8", device: "emu64a", transportID: "1")

        let ios = hostDeviceTarget(from: iosSimulator)
        let harmony = hostDeviceTarget(from: harmonyTarget)
        let android = hostDeviceTarget(from: androidTarget)

        #expect(ios.platform == "ios")
        #expect(ios.id == "sim:SIM-1")
        #expect(ios.target == "SIM-1")
        #expect(ios.ready)
        #expect(ios.runtime == "iOS 26.5")
        #expect(ios.transport == nil)
        #expect(harmony.platform == "harmony")
        #expect(harmony.id == "harmony:127.0.0.1:10100")
        #expect(harmony.target == "127.0.0.1:10100")
        #expect(harmony.ready)
        #expect(harmony.transport == "TCP")
        #expect(android.platform == "android")
        #expect(android.id == "android:emulator-5554")
        #expect(android.target == "emulator-5554")
        #expect(android.ready)
        #expect(android.name == "Pixel_8")
        #expect(android.runtime == "sdk_gphone64_arm64")
        #expect(android.transport == "1")
        #expect(android.scope == "emulator")
        #expect(android.kind == "emulator")
        #expect(android.blockedReasons.isEmpty)
    }

    @Test("host device target mapping redacts Android real device serials")
    func hostDeviceTargetMappingRedactsAndroidRealDeviceSerials() {
        let androidTarget = TKAndroidTarget(
            serial: "R58M1234ABC",
            state: "device",
            product: "oriole",
            model: "Pixel_6",
            device: "oriole",
            transportID: "4"
        )

        let target = hostDeviceTarget(from: androidTarget)

        #expect(target.platform == "android")
        #expect(target.scope == "real")
        #expect(target.kind == "real-device")
        #expect(target.id.hasPrefix("android-real:"))
        #expect(target.target == target.id)
        #expect(target.rawTarget == "R58M1234ABC")
        #expect(target.sensitive)
        #expect(!target.id.contains("R58M1234ABC"))
        #expect(!target.target.contains("R58M1234ABC"))
        #expect(target.blockedReasons.isEmpty)
        #expect(target.transport == "4")
    }

    @Test("host device selector filters Android real devices away from emulators")
    func hostDeviceSelectorFiltersAndroidRealDevicesAwayFromEmulators() throws {
        let emulator = hostDeviceTarget(from: TKAndroidTarget(serial: "emulator-5554", state: "device", model: "Pixel_8"))
        let real = hostDeviceTarget(from: TKAndroidTarget(serial: "R58M1234ABC", state: "device", model: "Pixel_6"))

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(platform: .android, scope: .real),
            candidates: [.android: [emulator, real]],
            aliases: .empty
        )

        #expect(resolved.target == real)
        #expect(resolved.target.scope == "real")
        #expect(resolved.target.kind == "real-device")
        #expect(resolved.source == .platformFilter)
    }

    @Test("host device selector filters Harmony real devices away from DevEco emulators")
    func hostDeviceSelectorFiltersHarmonyRealDevicesAwayFromDevEcoEmulators() throws {
        let emulator = hostDeviceTarget(from: TKHarmonyTarget(target: "127.0.0.1:10100", state: "Connected", transport: "TCP"))
        let real = hostDeviceTarget(from: TKHarmonyTarget(target: "HDCREAL001", state: "Connected", transport: "USB"))

        #expect(real.platform == "harmony")
        #expect(real.scope == "real")
        #expect(real.kind == "real-device")
        #expect(real.id.hasPrefix("harmony-real:"))
        #expect(real.target == real.id)
        #expect(real.rawTarget == "HDCREAL001")
        #expect(real.sensitive)
        #expect(!real.id.contains("HDCREAL001"))
        #expect(!real.target.contains("HDCREAL001"))

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(platform: .harmony, scope: .real),
            candidates: [.harmony: [emulator, real]],
            aliases: .empty
        )

        #expect(resolved.target == real)
        #expect(resolved.target.scope == "real")
        #expect(resolved.target.kind == "real-device")
        #expect(harmonyTarget(from: resolved.target).target == "HDCREAL001")
        #expect(resolved.source == .platformFilter)
    }

    @Test("iOS real device target mapping uses redacted stable identity")
    func iosRealDeviceTargetMappingUsesRedactedStableIdentity() {
        let real = TKDevicectlDeviceTarget(
            identifier: "00008110-001C195E0A10801E",
            name: "Lin iPhone",
            runtime: "iOS 26.5",
            state: "connected",
            ready: true,
            transport: "usb",
            blockedReasons: []
        )

        let target = hostDeviceTarget(from: real)

        #expect(target.platform == "ios")
        #expect(target.scope == "real")
        #expect(target.kind == "real-device")
        #expect(target.source == "devicectl")
        #expect(target.id == real.id)
        #expect(target.target == real.redactedTarget)
        #expect(target.ready)
        #expect(target.blockedReasons == [])
        #expect(target.name == "Lin iPhone")
        #expect(target.runtime == "iOS 26.5")
        #expect(target.transport == "usb")
        #expect(target.id.contains("00008110") == false)
        #expect(target.target.contains("00008110") == false)
    }

    @Test("host device selector resolves iOS real devices by stable id")
    func hostDeviceSelectorResolvesIOSRealDevicesByStableID() throws {
        let ready = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:abc123",
            target: "ios-real:abc123",
            state: "connected",
            ready: true,
            source: "devicectl",
            name: "Lin iPhone",
            runtime: "iOS 26.5",
            transport: "usb",
            scope: "real",
            kind: "real-device",
            blockedReasons: []
        )

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(device: "ios-real:abc123", platform: .ios, ready: true),
            candidates: [.ios: [ready]],
            aliases: .empty
        )

        #expect(resolved.platform == .ios)
        #expect(resolved.target == ready)
        #expect(resolved.target.scope == "real")
        #expect(resolved.target.kind == "real-device")
        #expect(resolved.source == .explicit)
    }

    @Test("host device target can round-trip into Harmony runtime target")
    func hostDeviceTargetCanRoundTripIntoHarmonyRuntimeTarget() {
        let target = HostDeviceTarget(
            platform: "harmony",
            id: "harmony:127.0.0.1:10100",
            target: "127.0.0.1:10100",
            state: "Connected",
            ready: true,
            source: "hdc",
            name: nil,
            runtime: nil,
            transport: "TCP"
        )

        let harmony = harmonyTarget(from: target)

        #expect(harmony.target == "127.0.0.1:10100")
        #expect(harmony.state == "Connected")
        #expect(harmony.transport == "TCP")
        #expect(harmony.source == "hdc")
    }

    @Test("host device selector prefers explicit matches and unique ready candidates")
    func hostDeviceSelectorPrefersExplicitMatchesAndUniqueReadyCandidates() {
        let first = HostDeviceTarget(
            platform: "ios",
            id: "sim:SIM-1",
            target: "SIM-1",
            state: "Booted",
            ready: true,
            source: "simctl",
            name: "iPhone 15",
            runtime: "iOS 26.5",
            transport: nil
        )
        let second = HostDeviceTarget(
            platform: "ios",
            id: "sim:SIM-2",
            target: "SIM-2",
            state: "Shutdown",
            ready: false,
            source: "simctl",
            name: "iPhone 14",
            runtime: "iOS 25.0",
            transport: nil
        )

        #expect(selectHostDeviceTarget(target: "SIM-2", candidates: [first, second]) == second)
        #expect(selectHostDeviceTarget(target: "booted", candidates: [first, second]) == first)
        #expect(selectHostDeviceTarget(target: nil, candidates: [first, second]) == first)
        #expect(selectHostDeviceTarget(target: nil, candidates: [second]) == second)
    }

    @Test("host device current selector falls back to stable target ids")
    func hostDeviceCurrentSelectorFallsBackToStableTargetIDs() {
        let selected = HostDeviceSelectionResult(
            platform: .ios,
            target: iosTarget(udid: "SIM-1"),
            selector: "ios",
            source: .platformFilter,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(platform: .ios))
        )

        #expect(hostDeviceCurrentSelector(explicitSelector: "iphone15", explicitTarget: nil, selected: selected) == "iphone15")
        #expect(hostDeviceCurrentSelector(explicitSelector: nil, explicitTarget: "sim:SIM-1", selected: selected) == "sim:SIM-1")
        #expect(hostDeviceCurrentSelector(explicitSelector: nil, explicitTarget: nil, selected: selected) == "sim:SIM-1")
    }

    @Test("host device selector can resolve a single ready target across platforms")
    func hostDeviceSelectorResolvesUniqueReadyTargetAcrossPlatforms() throws {
        let ios = iosTarget(udid: "SIM-1", state: "Booted", ready: true, name: "iPhone 15")
        let harmony = HostDeviceTarget(
            platform: "harmony",
            id: "harmony:127.0.0.1:10100",
            target: "127.0.0.1:10100",
            state: "Connected",
            ready: false,
            source: "hdc",
            name: nil,
            runtime: nil,
            transport: "TCP"
        )

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(),
            candidates: [.ios: [ios], .harmony: [harmony]],
            aliases: .empty
        )

        #expect(resolved.platform == .ios)
        #expect(resolved.target == ios)
        #expect(resolved.selector == "ready")
        #expect(resolved.source == .globalUnique)
    }

    @Test("host device screenshot rejects not-ready targets before invoking platform tools")
    func hostDeviceScreenshotRejectsNotReadyTargets() {
        let target = iosTarget(udid: "SIM-2", state: "Shutdown", ready: false)

        #expect(throws: HostCommandRunError.self) {
            _ = try captureHostDeviceScreenshot(
                platform: .ios,
                target: target,
                hdc: "hdc",
                output: "/tmp/should-not-be-written.png"
            )
        }
    }

    @Test("host device selector resolves aliases before raw platform ids")
    func hostDeviceSelectorResolvesAliasesBeforeRawPlatformIDs() throws {
        let store = HostTargetAliasStore(
            current: nil,
            aliases: [
                "iphone15": HostTargetAlias(platform: .ios, target: "SIM-1")
            ]
        )
        let first = iosTarget(udid: "SIM-1", name: "iPhone 15")
        let second = iosTarget(udid: "SIM-2", name: "iPhone 16")

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(device: "iphone15"),
            candidates: [.ios: [first, second]],
            aliases: store
        )

        #expect(resolved.platform == .ios)
        #expect(resolved.target == first)
        #expect(resolved.selector == "iphone15")
        #expect(resolved.source == .alias)
    }

    @Test("host device selector auto-selects only unique ready platform target")
    func hostDeviceSelectorAutoSelectsOnlyUniqueReadyPlatformTarget() throws {
        let first = iosTarget(udid: "SIM-1", state: "Booted", ready: true)
        let second = iosTarget(udid: "SIM-2", state: "Shutdown", ready: false)

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(platform: .ios),
            candidates: [.ios: [first, second]],
            aliases: .empty
        )

        #expect(resolved.target == first)
        #expect(resolved.selector == "ios")
        #expect(resolved.source == .platformFilter)
    }

    @Test("host device selector rejects ambiguous platform candidates")
    func hostDeviceSelectorRejectsAmbiguousPlatformCandidates() throws {
        let first = iosTarget(udid: "SIM-1", state: "Booted", ready: true, name: "iPhone 15")
        let second = iosTarget(udid: "SIM-2", state: "Booted", ready: true, name: "iPhone 16")

        #expect(throws: HostDeviceSelectionError.self) {
            try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(platform: .ios),
                candidates: [.ios: [first, second]],
                aliases: .empty
            )
        }
    }

    @Test("host device selector filters by name runtime state and ready")
    func hostDeviceSelectorFiltersByNameRuntimeStateAndReady() throws {
        let first = iosTarget(udid: "SIM-1", state: "Booted", ready: true, name: "iPhone 15", runtime: "iOS 26.5")
        let second = iosTarget(udid: "SIM-2", state: "Booted", ready: true, name: "iPhone 16", runtime: "iOS 26.5")

        let resolved = try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(platform: .ios, name: "15", runtime: "26.5", state: "booted", ready: true),
            candidates: [.ios: [first, second]],
            aliases: .empty
        )

        #expect(resolved.target == first)
        #expect(resolved.source == .platformFilter)
    }

    @Test("host target aliases persist current target and aliases")
    func hostTargetAliasesPersistCurrentTargetAndAliases() throws {
        let store = HostTargetAliasStore(
            current: "iphone15",
            aliases: [
                "iphone15": HostTargetAlias(platform: .ios, target: "SIM-1"),
                "android-a": HostTargetAlias(platform: .android, target: "emulator-5554"),
                "harmony-a": HostTargetAlias(platform: .harmony, target: "127.0.0.1:10100"),
            ]
        )

        let decoded = try JSONDecoder().decode(HostTargetAliasStore.self, from: JSONEncoder().encode(store))

        #expect(decoded.schemaVersion == 2)
        #expect(decoded.current == "iphone15")
        #expect(decoded.aliases["iphone15"]?.platform == .ios)
        #expect(decoded.aliases["android-a"]?.platform == .android)
        #expect(decoded.aliases["harmony-a"]?.target == "127.0.0.1:10100")
    }

    @Test("host target alias store reads v1 and writes v2 real-device bindings")
    func hostTargetAliasStoreReadsV1AndWritesV2RealDeviceBindings() throws {
        let v1 = Data(#"""
        {
          "current": "android-phone",
          "aliases": {
            "android-phone": {
              "platform": "android",
              "target": "android:emulator-5554"
            }
          }
        }
        """#.utf8)
        let oldStore = try JSONDecoder().decode(HostTargetAliasStore.self, from: v1)

        #expect(oldStore.schemaVersion == 1)
        #expect(oldStore.aliases["android-phone"]?.scope == nil)
        #expect(oldStore.aliases["android-phone"]?.kind == nil)

        let realStore = HostTargetAliasStore(
            current: "android-phone",
            aliases: [
                "android-phone": HostTargetAlias(
                    platform: .android,
                    target: "android-real:abc123",
                    scope: .real,
                    kind: "real-device",
                    sensitiveRef: ".triton/devices/android-real-abc123.json"
                )
            ]
        )
        let decoded = try JSONDecoder().decode(HostTargetAliasStore.self, from: JSONEncoder().encode(realStore))

        #expect(decoded.schemaVersion == 2)
        #expect(decoded.aliases["android-phone"]?.scope == .real)
        #expect(decoded.aliases["android-phone"]?.kind == "real-device")
        #expect(decoded.aliases["android-phone"]?.sensitiveRef == ".triton/devices/android-real-abc123.json")
    }
}

private func networkProxyTargetFixtures() -> [(platform: HostDevicePlatform, target: HostDeviceTarget)] {
    [
        (.ios, makeSimulatorProxyTarget(simulator: "SIM-1")),
        (.android, HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "device",
            ready: true,
            source: "adb",
            name: "Pixel_8",
            runtime: "sdk_gphone64_arm64",
            transport: "1",
            scope: "emulator",
            kind: "emulator"
        )),
        (.harmony, HostDeviceTarget(
            platform: "harmony",
            id: "harmony:127.0.0.1:10100",
            target: "127.0.0.1:10100",
            state: "Connected",
            ready: true,
            source: "hdc",
            name: nil,
            runtime: nil,
            transport: "tcp",
            scope: "emulator",
            kind: "emulator"
        )),
    ]
}

private func networkProxyRealDeviceTargetFixtures() -> [(platform: HostDevicePlatform, target: HostDeviceTarget)] {
    [
        (.ios, HostDeviceTarget(
            platform: "ios",
            id: "ios-real:abc123",
            target: "ios-real:abc123",
            state: "Available",
            ready: true,
            source: "devicectl",
            name: "Private iPhone",
            runtime: nil,
            transport: "usb",
            scope: "real",
            kind: "real-device",
            blockedReasons: []
        )),
        (.android, HostDeviceTarget(
            platform: "android",
            id: "android-real:redacted",
            target: "android-real:redacted",
            state: "device",
            ready: true,
            source: "adb",
            name: "Pixel Phone",
            runtime: nil,
            transport: "usb",
            scope: "real",
            kind: "real-device",
            blockedReasons: []
        )),
        (.harmony, HostDeviceTarget(
            platform: "harmony",
            id: "harmony-real:redacted",
            target: "harmony-real:redacted",
            state: "Connected",
            ready: true,
            source: "hdc",
            name: nil,
            runtime: nil,
            transport: "USB",
            scope: "real",
            kind: "real-device",
            blockedReasons: []
        )),
    ]
}

private func jsonDictionary(at path: String) throws -> [String: Any] {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
}

private func jsonObject(line: String) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: Data(line.utf8))
    return try #require(object as? [String: Any])
}

private func successfulHostProcessResult(_ command: TKHostCommand, stdout: String = "") -> HostProcessResult {
    let stdoutData = Data(stdout.utf8)
    return HostProcessResult(
        stdoutData: stdoutData,
        stderrData: Data(),
        exitCode: 0,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: false,
        stderrTruncated: false,
        stdoutLogPath: nil,
        stderrLogPath: nil,
        stdoutBytes: stdoutData.count,
        stderrBytes: 0
    )
}

private func failedHostProcessResult(_ command: TKHostCommand, stderr: String) -> HostProcessResult {
    let stderrData = Data(stderr.utf8)
    return HostProcessResult(
        stdoutData: Data(),
        stderrData: stderrData,
        exitCode: 7,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: false,
        stderrTruncated: false,
        stdoutLogPath: nil,
        stderrLogPath: nil,
        stdoutBytes: 0,
        stderrBytes: stderrData.count
    )
}

private func reserveLocalPortForTest() throws -> Int {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    defer { close(fd) }
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(0).bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bindResult = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &bound) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(fd, $0, &length)
        }
    }
    guard nameResult == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    return Int(UInt16(bigEndian: bound.sin_port))
}

private func waitUntilPortAcceptsConnections(port: Int) throws {
    var lastError: Error?
    for _ in 0..<50 {
        do {
            let fd = try connectToLocalTestPort(port)
            close(fd)
            return
        } catch {
            lastError = error
            Thread.sleep(forTimeInterval: 0.02)
        }
    }
    throw lastError ?? POSIXError(.ETIMEDOUT)
}

private func sendProxyServeTestRequest(port: Int) throws {
    let fd = try connectToLocalTestPort(port)
    defer { close(fd) }
    let request = Data((
        "GET http://127.0.0.1:1/capture HTTP/1.1\r\n" +
        "Host: 127.0.0.1:1\r\n" +
        "Cookie: session=secret\r\n" +
        "\r\n"
    ).utf8)
    var sent = 0
    request.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return }
        while sent < request.count {
            let written = write(fd, base.advanced(by: sent), request.count - sent)
            if written <= 0 { return }
            sent += written
        }
    }
    shutdown(fd, SHUT_WR)
}

private func sendProxyServeTestRequestAndReadResponse(port: Int) throws -> String {
    let fd = try connectToLocalTestPort(port)
    defer { close(fd) }
    let request = Data((
        "GET http://127.0.0.1:1/capture HTTP/1.1\r\n" +
        "Host: 127.0.0.1:1\r\n" +
        "Cookie: session=secret\r\n" +
        "\r\n"
    ).utf8)
    var sent = 0
    request.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return }
        while sent < request.count {
            let written = write(fd, base.advanced(by: sent), request.count - sent)
            if written <= 0 { return }
            sent += written
        }
    }
    shutdown(fd, SHUT_WR)

    var response = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
        let readCount = read(fd, &buffer, buffer.count)
        if readCount <= 0 { break }
        response.append(buffer, count: readCount)
    }
    return String(decoding: response, as: UTF8.self)
}

private func connectToLocalTestPort(_ port: Int) throws -> Int32 {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(port).bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard result == 0 else {
        let code = POSIXErrorCode(rawValue: errno) ?? .EIO
        close(fd)
        throw POSIXError(code)
    }
    return fd
}

private func captureStandardOutputAsync(_ body: () async throws -> Void) async throws -> String {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)

    fflush(stdout)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    do {
        try await body()
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

private func captureStandardOutputAllowingFailureAsync(_ body: () async throws -> Void) async throws -> (output: String, error: Error?) {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    var caughtError: Error?

    fflush(stdout)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    do {
        try await body()
    } catch {
        caughtError = error
    }
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (String(decoding: data, as: UTF8.self), caughtError)
}

private func iosTarget(
    udid: String,
    state: String = "Booted",
    ready: Bool = true,
    name: String = "iPhone",
    runtime: String = "iOS 26.5"
) -> HostDeviceTarget {
    HostDeviceTarget(
        platform: "ios",
        id: "sim:\(udid)",
        target: udid,
        state: state,
        ready: ready,
        source: "simctl",
        name: name,
        runtime: runtime,
        transport: nil
    )
}

private func harmonyHostDeviceTargets(
    scope: HostDeviceScope? = nil,
    hdc: String,
    runner: (TKHostCommand) throws -> HostProcessResult
) throws -> (targets: [HostDeviceTarget], sourceCommand: String) {
    let verboseResult = try runner(TKHarmonyHDCCommand.listTargets(executable: hdc))
    let verboseTargets = TKHdcTargetListParser.parse(verboseResult.stdout)
    let targets: [TKHarmonyTarget]
    let sourceCommand: String
    if verboseTargets.isEmpty {
        let plainResult = try runner(TKHarmonyHDCCommand.listTargetsPlain(executable: hdc))
        targets = TKHdcTargetListParser.parse(plainResult.stdout)
        sourceCommand = [verboseResult.sourceCommand, plainResult.sourceCommand].joined(separator: "\n")
    } else {
        targets = verboseTargets
        sourceCommand = verboseResult.sourceCommand
    }

    let mapped = targets
        .map(testHarmonyHostDeviceTarget)
        .filter { target in
            guard let scope else { return true }
            return target.scope == scope.rawValue
        }
    return (mapped, sourceCommand)
}

private func testHarmonyHostDeviceTarget(from target: TKHarmonyTarget) -> HostDeviceTarget {
    let sensitive = target.scope == .real
    return HostDeviceTarget(
        platform: "harmony",
        id: target.id,
        target: sensitive ? target.id : target.target,
        state: target.state,
        ready: target.isReady,
        source: target.source,
        name: nil,
        runtime: nil,
        transport: target.transport,
        scope: target.scope.rawValue,
        kind: target.kind,
        blockedReasons: target.blockedReasons,
        sensitive: sensitive,
        rawTarget: target.target
    )
}

private func writeMinimalPNG(width: UInt32, height: UInt32, to url: URL) throws {
    var data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x0D])
    data.append(contentsOf: [0x49, 0x48, 0x44, 0x52])
    data.append(UInt8((width >> 24) & 0xff))
    data.append(UInt8((width >> 16) & 0xff))
    data.append(UInt8((width >> 8) & 0xff))
    data.append(UInt8(width & 0xff))
    data.append(UInt8((height >> 24) & 0xff))
    data.append(UInt8((height >> 16) & 0xff))
    data.append(UInt8((height >> 8) & 0xff))
    data.append(UInt8(height & 0xff))
    data.append(contentsOf: [8, 6, 0, 0, 0])
    data.append(contentsOf: [0, 0, 0, 0])
    try data.write(to: url, options: .atomic)
}
