import Foundation

/// Supplies compatibility search paths only to the selected Baguette child process.
func baguetteFrameworkEnvironment(
    executable: String,
    environment: [String: String],
    developerDirectory: String?,
    fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
) -> [String: String] {
    guard isBaguetteHostExecutable(executable, environment: environment),
          let directory = developerDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
          directory.hasPrefix("/")
    else { return environment }

    let developer = URL(fileURLWithPath: directory, isDirectory: true)
    let contents = developer.pathExtension == "app"
        ? developer.appendingPathComponent("Contents", isDirectory: true)
        : developer.deletingLastPathComponent()
    let shared = contents.appendingPathComponent("SharedFrameworks", isDirectory: true).path
    guard fileExists(shared + "/SimulatorKit.framework/SimulatorKit")
        || fileExists(shared + "/SimulatorKit.framework/Versions/A/SimulatorKit")
    else { return environment }

    var result = environment
    var paths = (environment["DYLD_FRAMEWORK_PATH"] ?? "").split(separator: ":").map(String.init)
    if !paths.contains(shared) { paths.append(shared) }
    result["DYLD_FRAMEWORK_PATH"] = paths.joined(separator: ":")
    return result
}

func isBaguetteHostExecutable(_ executable: String, environment: [String: String]) -> Bool {
    URL(fileURLWithPath: executable).lastPathComponent == "baguette"
        || environment["TRITONKIT_BAGUETTE_BIN"] == executable
}

func baguetteDeveloperDirectory(
    environment: [String: String],
    querySelectedDeveloperDirectory: () -> String? = querySelectedXcodeDeveloperDirectory
) -> String? {
    environment["DEVELOPER_DIR"] ?? querySelectedDeveloperDirectory()
}

private func querySelectedXcodeDeveloperDirectory() -> String? {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    process.arguments = ["-p"]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              path.hasPrefix("/")
        else { return nil }
        return path
    } catch {
        return nil
    }
}
