import Foundation
import Darwin

extension IOSRunnerDependencies {
    static var live: IOSRunnerDependencies {
        IOSRunnerDependencies(registryRoot: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".triton/ios-runner", isDirectory: true), resolve: { selector in
            guard selector.hasPrefix("ios-real:") || selector.hasPrefix("ios-sim:") || selector.hasPrefix("sim:") else {
                throw IOSRunnerFailure("ios_runner_explicit_device_required", "Use an explicit ios-real or simulator device selector.")
            }
            let selection = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: selector, platform: .ios), hdc: "hdc", adb: "adb")
            let target = selection.target
            if target.scope == "real" {
                let addresses = ([target.rawTarget] + target.rawTargetAliases).filter {
                    $0.range(of: "^(?:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{40})$", options: .regularExpression) != nil
                }
                guard let udid = Set(addresses).first, Set(addresses).count == 1 else {
                    throw IOSRunnerFailure("ios_runner_identity_unavailable", "Device discovery must supply one USB UDID; a CoreDevice UUID is insufficient.")
                }
                return IOSRunnerTarget(device: target.target, scope: "real", address: udid)
            }
            guard target.scope == "simulator", UUID(uuidString: target.rawTarget) != nil else {
                throw IOSRunnerFailure("ios_runner_unsupported_target", "Runner supports iOS Simulator and paired iOS devices.")
            }
            return IOSRunnerTarget(device: "sim:" + target.rawTarget, scope: "simulator", address: target.rawTarget)
        }, command: iosRunnerRunCommand, launch: { arguments, directory in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: arguments[0])
            process.arguments = Array(arguments.dropFirst())
            for filename in ["native.stdout", "native.stderr"] {
                try IOSRunnerSessionStore.writeExclusive(Data(), to: directory.appendingPathComponent(filename))
            }
            let stdout = try FileHandle(forWritingTo: directory.appendingPathComponent("native.stdout"))
            let stderr = try FileHandle(forWritingTo: directory.appendingPathComponent("native.stderr"))
            process.standardOutput = stdout; process.standardError = stderr
            process.standardInput = FileHandle.nullDevice
            try process.run()
            try stdout.close(); try stderr.close()
            return process.processIdentifier
        }, processExists: { pid in
            guard pid > 1 else { return nil }
            if Darwin.kill(pid, 0) == 0 { return true }
            if errno == ESRCH { return false }
            if errno == EPERM { return true }
            return nil
        }, ownsProcess: iosRunnerOwnsProcess, terminate: { pid, path in
            guard iosRunnerOwnsProcess(pid, path) else { return false }
            guard Darwin.kill(pid, SIGTERM) == 0 else { return false }
            for _ in 0..<50 {
                if Darwin.kill(pid, 0) != 0 && errno == ESRCH { return true }
                Thread.sleep(forTimeInterval: 0.1)
            }
            return false
        }, exchange: { session, route, body, requestID, timeout in
            IOSRunnerTransport.exchange(connection: iosRunnerConnection(session), route: route, body: body, requestID: requestID, timeout: timeout)
        }, project: bundledIOSRunnerProjectURL, now: Date.init, sleep: Thread.sleep(forTimeInterval:))
    }
}

func iosRunnerOwnsProcess(_ pid: Int32, _ xctestrun: String) -> Bool {
    guard pid > 1, kill(pid, 0) == 0,
          let result = try? iosRunnerRunCommand(["/bin/ps", "-p", String(pid), "-o", "command="], 3), result.status == 0 else { return false }
    // Exact test configuration is fresh per launch. Never use process names alone.
    return result.stdout.contains("xcodebuild") && result.stdout.contains("-xctestrun " + xctestrun + " -destination ") && result.stdout.contains("test-without-building")
}
func iosRunnerRunCommand(_ args: [String], _ timeout: TimeInterval) throws -> IOSRunnerCommandResult {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-runner-command-" + UUID().uuidString)
    try IOSRunnerSessionStore.privateDirectory(directory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let stdoutURL = directory.appendingPathComponent("stdout"), stderrURL = directory.appendingPathComponent("stderr")
    try IOSRunnerSessionStore.writeExclusive(Data(), to: stdoutURL)
    try IOSRunnerSessionStore.writeExclusive(Data(), to: stderrURL)
    let output = try FileHandle(forWritingTo: stdoutURL), errors = try FileHandle(forWritingTo: stderrURL)
    defer { try? output.close(); try? errors.close() }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: args[0]); process.arguments = Array(args.dropFirst())
    process.standardOutput = output; process.standardError = errors; process.standardInput = FileHandle.nullDevice
    try process.run()
    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
    if process.isRunning {
        process.terminate()
        for _ in 0..<40 { if !process.isRunning { break }; Thread.sleep(forTimeInterval: 0.05) }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        process.waitUntilExit()
        return IOSRunnerCommandResult(status: 124, stdout: String(data: try Data(contentsOf: stdoutURL), encoding: .utf8) ?? "", stderr: String(data: try Data(contentsOf: stderrURL), encoding: .utf8) ?? "")
    }
    process.waitUntilExit()
    let stdout = String(data: try Data(contentsOf: stdoutURL), encoding: .utf8) ?? ""
    let stderr = String(data: try Data(contentsOf: stderrURL), encoding: .utf8) ?? ""
    return IOSRunnerCommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
}

extension IOSRunnerService {
    func resourceFingerprint(_ project: URL) throws -> String {
        let data = try Data(contentsOf: project.appendingPathComponent("RUNNER_MANIFEST.json"))
        guard data.count <= 65536 else { throw IOSRunnerFailure("ios_runner_resource_invalid", "Runner manifest exceeds its limit.") }
        return iosRunnerKey(String(decoding: data, as: UTF8.self))
    }
    func prepare(_ target: IOSRunnerTarget, payload: [String: Any], store: IOSRunnerSessionStore) throws -> [String: Any] {
        if let session = try store.read("session", as: IOSRunnerSession.self), let pid = session.pid, dependencies.ownsProcess(pid, session.xctestrun) {
            throw IOSRunnerFailure("ios_runner_busy", "Stop the active Runner before preparing another build.")
        }
        if let session = try store.read("session", as: IOSRunnerSession.self), let pid = session.pid, dependencies.processExists(pid) != false { throw IOSRunnerFailure("ios_runner_owner_unknown", "Previous native process exit is unverified; stop or recover it before preparing.") }
        let installedProject = try dependencies.project()
        let digest = try resourceFingerprint(installedProject)
        let project = store.targetDirectory.appendingPathComponent("project-" + digest.prefix(16) + "-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.copyItem(at: installedProject, to: project)
        try IOSRunnerSessionStore.privateDirectory(project)
        let projectFile = project.appendingPathComponent("TritonIOSRunner.xcodeproj")
        guard FileManager.default.fileExists(atPath: projectFile.path) else {
            throw IOSRunnerFailure("ios_runner_resource_missing", "The installed CLI lacks the bundled Runner project.")
        }
        let derived = store.targetDirectory.appendingPathComponent("build-v1-" + digest.prefix(16) + "-" + UUID().uuidString, isDirectory: true)
        try IOSRunnerSessionStore.privateDirectory(derived)
        // Isolated products prevent concurrent CLI users and Xcode from mutating the signed Runner cache.
        var args = ["/usr/bin/xcodebuild", "build-for-testing", "-project", projectFile.path, "-scheme", "TritonIOSRunner", "-derivedDataPath", derived.path,
                    "-destination", "platform=" + (target.scope == "real" ? "iOS" : "iOS Simulator") + ",id=" + target.address,
                    "-sdk", target.scope == "real" ? "iphoneos" : "iphonesimulator", "-parallel-testing-enabled", "NO"]
        if target.scope == "real" {
            let explicitTeam = payload["team"] as? String
            let team = try explicitTeam ?? uniqueDevelopmentTeam()
            guard team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else {
                throw IOSRunnerFailure("ios_runner_invalid_team", "The development team must be a ten-character Apple team identifier.")
            }
            args += ["DEVELOPMENT_TEAM=" + team, "CODE_SIGN_STYLE=Automatic"]
            if payload["allowProvisioning"] as? Bool == true { args.append("-allowProvisioningUpdates") }
        } else { args.append("CODE_SIGNING_ALLOWED=NO") }
        let timeout = try duration(payload, key: "timeout", fallback: 600, range: 1...1800)
        let result = try dependencies.command(args, timeout)
        try IOSRunnerSessionStore.writeExclusive(Data((result.stdout + "\n" + result.stderr).utf8), to: store.targetDirectory.appendingPathComponent("build-" + UUID().uuidString + ".log"))
        guard result.status == 0 else {
            throw IOSRunnerFailure("ios_runner_build_failed", "Bundled Runner build failed; inspect the private build log. Verify signing, pairing, and installed iOS SDK.")
        }
        let products = derived.appendingPathComponent("Build/Products")
        let candidates = (FileManager.default.enumerator(at: products, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "xctestrun" }
        guard candidates.count == 1 else { throw IOSRunnerFailure("ios_runner_build_artifact_ambiguous", "The build must produce exactly one Runner test configuration.") }
        try store.write(IOSRunnerPrepared(version: 1, resourceDigest: digest, target: target, xctestrun: candidates[0].path, preparedAt: dependencies.now()), name: "prepared")
        return ["operation": "prepare", "device": target.device, "state": "prepared", "buildVerified": true, "derivedDataIsolationReason": "protect_owned_signed_runner_cache"]
    }
    func uniqueDevelopmentTeam() throws -> String {
        let identities = try dependencies.command(["/usr/bin/security", "find-identity", "-v", "-p", "codesigning"], 15)
        guard identities.status == 0 else { throw IOSRunnerFailure("ios_runner_team_required", "Supply --team or install a valid Apple Development signing identity.") }
        let valid = identities.stdout.split(separator: "\n").filter { $0.contains("Apple Development:") }.compactMap { line -> String? in
            let text = String(line)
            guard let range = text.range(of: "[A-Fa-f0-9]{40}", options: .regularExpression) else { return nil }
            return String(text[range]).uppercased()
        }
        let certificates = try dependencies.command(["/usr/bin/security", "find-certificate", "-a", "-c", "Apple Development", "-p"], 15)
        let pieces = certificates.stdout.components(separatedBy: "-----END CERTIFICATE-----")
        var teams = Set<String>()
        for piece in pieces where piece.contains("-----BEGIN CERTIFICATE-----") {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("triton-cert-" + UUID().uuidString + ".pem")
            try IOSRunnerSessionStore.writeExclusive(Data((piece + "-----END CERTIFICATE-----\n").utf8), to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            let details = try dependencies.command(["/usr/bin/openssl", "x509", "-in", file.path, "-noout", "-subject", "-fingerprint", "-sha1", "-nameopt", "sep_multiline"], 10)
            let fingerprint = details.stdout.split(separator: "\n").first(where: { $0.contains("Fingerprint=") }).map { String($0.split(separator: "=").last ?? "").replacingOccurrences(of: ":", with: "").uppercased() }
            guard let fingerprint, valid.contains(fingerprint) else { continue }
            let matches = details.stdout.split(separator: "\n").filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("OU=") || $0.trimmingCharacters(in: .whitespaces).hasPrefix("OU =") }
            for match in matches {
                if let team = match.split(separator: "=").last?.trimmingCharacters(in: .whitespaces), team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil { teams.insert(team) }
            }
        }
        guard teams.count == 1, let team = teams.first else { throw IOSRunnerFailure("ios_runner_team_required", "Supply --team: no unique valid Apple Development identity was found.") }
        return team
    }
}
