import Darwin
import Foundation

enum WebDependencyInstallMode: String {
    case auto
    case always
    case never
}

enum WebCommandError: Error, Equatable, CustomStringConvertible {
    case webRootNotFound(currentDirectory: String, explicitRoot: String?)
    case conflictingInstallOptions
    case processFailed(command: String, exitCode: Int32)

    var description: String {
        switch self {
        case .webRootNotFound(let currentDirectory, let explicitRoot):
            let root = explicitRoot.map { " explicit root: \($0);" } ?? ""
            return "Triton Web root was not found;\(root) current directory: \(currentDirectory). Expected a Web/package.json and Vite config in a TritonKit checkout."
        case .conflictingInstallOptions:
            return "Use only one of --install or --no-install."
        case .processFailed(let command, let exitCode):
            return "Command failed with exit code \(exitCode): \(command)"
        }
    }

    var code: String {
        switch self {
        case .webRootNotFound:
            return "web_root_not_found"
        case .conflictingInstallOptions:
            return "validation_failed"
        case .processFailed:
            return "web_start_failed"
        }
    }

    var hint: String {
        switch self {
        case .webRootNotFound:
            return "Run from the TritonKit checkout, pass --root /path/to/TritonKit, or use --root /path/to/TritonKit/Web."
        case .conflictingInstallOptions:
            return "Choose --install to force npm install, or --no-install to skip it."
        case .processFailed:
            return "Inspect npm output above, then retry `triton web --print-command --json` to verify the launch plan."
        }
    }
}

struct WebLaunchCommand: Codable, Equatable {
    let executable: String
    let arguments: [String]

    var display: String {
        ([executable] + arguments).map(shellQuote).joined(separator: " ")
    }
}

struct WebLaunchPlan: Codable, Equatable {
    let ok: Bool
    let action: String
    let repoRoot: String
    let webRoot: String
    let tritonBin: String
    let host: String
    let port: Int
    let url: String
    let readonly: Bool
    let installCommand: WebLaunchCommand?
    let command: WebLaunchCommand
    let environment: [String: String]
}

func makeWebLaunchPlan(
    explicitRoot: String?,
    currentDirectory: String,
    explicitTritonBin: String?,
    currentExecutable: String,
    host: String,
    port: Int,
    installMode: WebDependencyInstallMode,
    environment: [String: String]
) throws -> WebLaunchPlan {
    guard let roots = discoverWebRoots(explicitRoot: explicitRoot, currentDirectory: currentDirectory) else {
        throw WebCommandError.webRootNotFound(currentDirectory: currentDirectory, explicitRoot: explicitRoot)
    }

    let tritonBin = explicitTritonBin ?? environment["TRITONKIT_TRITON_BIN"] ?? currentExecutable
    let nodeModules = roots.webRoot.appendingPathComponent("node_modules", isDirectory: true)
    let shouldInstall = switch installMode {
    case .always:
        true
    case .auto:
        !FileManager.default.fileExists(atPath: nodeModules.path)
    case .never:
        false
    }
    let installCommand = shouldInstall
        ? WebLaunchCommand(executable: "npm", arguments: ["--prefix", roots.webRoot.path, "install"])
        : nil
    let command = WebLaunchCommand(executable: "npm", arguments: [
        "--prefix", roots.webRoot.path,
        "run", "dev",
        "--",
        "--host", host,
        "--port", String(port),
    ])

    return WebLaunchPlan(
        ok: true,
        action: "web.start",
        repoRoot: roots.repoRoot.path,
        webRoot: roots.webRoot.path,
        tritonBin: tritonBin,
        host: host,
        port: port,
        url: "http://\(host):\(port)/",
        readonly: true,
        installCommand: installCommand,
        command: command,
        environment: ["TRITONKIT_TRITON_BIN": tritonBin]
    )
}

func renderWebLaunchPlanText(_ plan: WebLaunchPlan) -> String {
    var lines = [
        "url: \(plan.url)",
        "repoRoot: \(plan.repoRoot)",
        "webRoot: \(plan.webRoot)",
        "tritonBin: \(plan.tritonBin)",
        "readonly: \(plan.readonly)",
    ]
    if let installCommand = plan.installCommand {
        lines.append("install: \(installCommand.display)")
    } else {
        lines.append("install: skipped")
    }
    lines.append("command: \(plan.command.display)")
    return lines.joined(separator: "\n")
}

func runWebLaunchPlan(_ plan: WebLaunchPlan) throws {
    if let installCommand = plan.installCommand {
        try runWebProcess(installCommand, environment: plan.environment, currentDirectory: plan.repoRoot)
    }
    print("Triton Web Device Hub: \(plan.url)")
    try runWebProcess(plan.command, environment: plan.environment, currentDirectory: plan.repoRoot)
}

func currentExecutablePath() -> String {
    var size = UInt32(0)
    _ = _NSGetExecutablePath(nil, &size)
    var buffer = [CChar](repeating: 0, count: Int(size) + 1)
    if _NSGetExecutablePath(&buffer, &size) == 0 {
        return FileManager.default
            .string(withFileSystemRepresentation: buffer, length: Int(strlen(buffer)))
    }
    return ProcessInfo.processInfo.arguments.first ?? "triton"
}

private func discoverWebRoots(explicitRoot: String?, currentDirectory: String) -> (repoRoot: URL, webRoot: URL)? {
    if let explicitRoot {
        return webRoots(for: URL(fileURLWithPath: explicitRoot).standardizedFileURL)
    }

    var cursor = URL(fileURLWithPath: currentDirectory).standardizedFileURL
    while true {
        if let roots = webRoots(for: cursor) {
            return roots
        }
        let parent = cursor.deletingLastPathComponent()
        if parent.path == cursor.path {
            return nil
        }
        cursor = parent
    }
}

private func webRoots(for root: URL) -> (repoRoot: URL, webRoot: URL)? {
    if isValidWebRoot(root) {
        return (repoRoot: root.deletingLastPathComponent(), webRoot: root)
    }

    let web = root.appendingPathComponent("Web", isDirectory: true)
    if isValidWebRoot(web) {
        return (repoRoot: root, webRoot: web)
    }

    return nil
}

private func isValidWebRoot(_ url: URL) -> Bool {
    let packageJSON = url.appendingPathComponent("package.json")
    guard FileManager.default.fileExists(atPath: packageJSON.path) else {
        return false
    }
    let viteConfigs = [
        "vite.config.ts",
        "vite.config.js",
        "vite.config.mjs",
    ]
    return viteConfigs.contains { name in
        FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path)
    }
}

private func runWebProcess(
    _ command: WebLaunchCommand,
    environment: [String: String],
    currentDirectory: String
) throws {
    let process = Process()
    if command.executable.contains("/") {
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command.executable] + command.arguments
    }
    process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory, isDirectory: true)
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw WebCommandError.processFailed(command: command.display, exitCode: process.terminationStatus)
    }
}

private func shellQuote(_ value: String) -> String {
    guard !value.isEmpty else {
        return "''"
    }
    let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-")
    if value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
        return value
    }
    return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
