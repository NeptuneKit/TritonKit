import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct WebCommandTests {
    @Test("web command plan uses repo Web directory and current triton binary")
    func webCommandPlanUsesRepoWebDirectoryAndCurrentTritonBinary() throws {
        let repo = try temporaryRepoWithWeb(nodeModules: true)
        let plan = try makeWebLaunchPlan(
            explicitRoot: repo.path,
            currentDirectory: repo.path,
            explicitTritonBin: "/tmp/triton",
            currentExecutable: "/usr/local/bin/triton",
            host: "127.0.0.1",
            port: 34127,
            installMode: .auto,
            environment: [:]
        )

        #expect(plan.url == "http://127.0.0.1:34127/")
        #expect(plan.mode == "dev")
        #expect(plan.webRoot == repo.appendingPathComponent("Web").path)
        #expect(plan.bundledWebRoot == nil)
        #expect(plan.tritonBin == "/tmp/triton")
        #expect(plan.installCommand == nil)
        #expect(plan.command.executable == "npm")
        #expect(plan.command.arguments == [
            "--prefix", repo.appendingPathComponent("Web").path,
            "run", "dev",
            "--",
            "--host", "127.0.0.1",
            "--port", "34127",
        ])
        #expect(plan.environment["TRITONKIT_TRITON_BIN"] == "/tmp/triton")
    }

    @Test("web command falls back to bundled static dist beside current executable")
    func webCommandFallsBackToBundledStaticDistBesideExecutable() throws {
        let install = try temporaryDirectory()
        let bin = install.appendingPathComponent("triton")
        let web = install.appendingPathComponent("web", isDirectory: true)
        try FileManager.default.createDirectory(at: web, withIntermediateDirectories: true)
        try Data().write(to: bin)
        try "<html></html>".write(to: web.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        let plan = try makeWebLaunchPlan(
            explicitRoot: nil,
            currentDirectory: try temporaryDirectory().path,
            explicitTritonBin: nil,
            currentExecutable: bin.path,
            host: "127.0.0.1",
            port: 34127,
            installMode: .auto,
            environment: [:]
        )

        #expect(plan.mode == "packaged")
        #expect(plan.webRoot == nil)
        #expect(plan.bundledWebRoot == web.path)
        #expect(plan.installCommand == nil)
        #expect(plan.command.executable == bin.path)
        #expect(plan.command.arguments == [
            "web",
            "--host", "127.0.0.1",
            "--port", "34127",
            "--bundled-web-root", web.path,
            "--triton-bin", bin.path,
        ])
    }

    @Test("web command explicit checkout root wins over bundled static dist")
    func webCommandExplicitCheckoutRootWinsOverBundledStaticDist() throws {
        let repo = try temporaryRepoWithWeb(nodeModules: true)
        let install = try temporaryDirectory()
        let bin = install.appendingPathComponent("triton")
        let web = install.appendingPathComponent("web", isDirectory: true)
        try FileManager.default.createDirectory(at: web, withIntermediateDirectories: true)
        try Data().write(to: bin)
        try "<html></html>".write(to: web.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        let plan = try makeWebLaunchPlan(
            explicitRoot: repo.path,
            currentDirectory: install.path,
            explicitTritonBin: nil,
            currentExecutable: bin.path,
            host: "127.0.0.1",
            port: 34127,
            installMode: .auto,
            environment: [:]
        )

        #expect(plan.mode == "dev")
        #expect(plan.webRoot == repo.appendingPathComponent("Web").path)
        #expect(plan.bundledWebRoot == nil)
    }

    @Test("web command finds bundled static dist in Homebrew share layout")
    func webCommandFindsBundledStaticDistInHomebrewShareLayout() throws {
        let install = try temporaryDirectory()
        let binDir = install.appendingPathComponent("bin", isDirectory: true)
        let shareWeb = install
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("triton", isDirectory: true)
            .appendingPathComponent("web", isDirectory: true)
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shareWeb, withIntermediateDirectories: true)
        let bin = binDir.appendingPathComponent("triton")
        try Data().write(to: bin)
        try "<html></html>".write(to: shareWeb.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        let plan = try makeWebLaunchPlan(
            explicitRoot: nil,
            currentDirectory: try temporaryDirectory().path,
            explicitTritonBin: nil,
            currentExecutable: bin.path,
            host: "127.0.0.1",
            port: 34127,
            installMode: .auto,
            environment: [:]
        )

        #expect(plan.mode == "packaged")
        #expect(plan.bundledWebRoot == shareWeb.path)
    }

    @Test("web command resolves bundled static dist through extra PATH symlink")
    func webCommandResolvesBundledStaticDistThroughExtraPATHSymlink() throws {
        let install = try temporaryDirectory()
        let cellar = install
            .appendingPathComponent("Cellar", isDirectory: true)
            .appendingPathComponent("triton", isDirectory: true)
            .appendingPathComponent("0.1.20", isDirectory: true)
        let cellarBinDir = cellar.appendingPathComponent("bin", isDirectory: true)
        let cellarShareWeb = cellar
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("triton", isDirectory: true)
            .appendingPathComponent("web", isDirectory: true)
        let homebrewBinDir = install.appendingPathComponent("bin", isDirectory: true)
        let userBinDir = try temporaryDirectory()
        try FileManager.default.createDirectory(at: cellarBinDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cellarShareWeb, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: homebrewBinDir, withIntermediateDirectories: true)
        let cellarBin = cellarBinDir.appendingPathComponent("triton")
        let homebrewBin = homebrewBinDir.appendingPathComponent("triton")
        let userBin = userBinDir.appendingPathComponent("triton")
        try Data().write(to: cellarBin)
        try "<html></html>".write(to: cellarShareWeb.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(atPath: homebrewBin.path, withDestinationPath: "../Cellar/triton/0.1.20/bin/triton")
        try FileManager.default.createSymbolicLink(atPath: userBin.path, withDestinationPath: homebrewBin.path)

        let plan = try makeWebLaunchPlan(
            explicitRoot: nil,
            currentDirectory: try temporaryDirectory().path,
            explicitTritonBin: nil,
            currentExecutable: userBin.path,
            host: "127.0.0.1",
            port: 34127,
            installMode: .auto,
            environment: [:]
        )

        #expect(plan.mode == "packaged")
        #expect(plan.bundledWebRoot == cellarShareWeb.path)
        #expect(plan.command.executable == userBin.path)
        #expect(plan.tritonBin == userBin.path)
    }

    @Test("web command auto install runs only when node modules are missing")
    func webCommandAutoInstallRunsOnlyWhenNodeModulesAreMissing() throws {
        let repo = try temporaryRepoWithWeb(nodeModules: false)
        let auto = try makeWebLaunchPlan(
            explicitRoot: repo.path,
            currentDirectory: repo.path,
            explicitTritonBin: nil,
            currentExecutable: "/usr/local/bin/triton",
            host: "127.0.0.1",
            port: 34127,
            installMode: .auto,
            environment: [:]
        )
        let never = try makeWebLaunchPlan(
            explicitRoot: repo.path,
            currentDirectory: repo.path,
            explicitTritonBin: nil,
            currentExecutable: "/usr/local/bin/triton",
            host: "127.0.0.1",
            port: 34127,
            installMode: .never,
            environment: [:]
        )

        #expect(auto.installCommand?.arguments == ["--prefix", repo.appendingPathComponent("Web").path, "install"])
        #expect(never.installCommand == nil)
    }

    @Test("web command discovers repo root from nested current directory")
    func webCommandDiscoversRepoRootFromNestedCurrentDirectory() throws {
        let repo = try temporaryRepoWithWeb(nodeModules: true)
        let nested = repo.appendingPathComponent("docs-linhay/spaces/example", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let plan = try makeWebLaunchPlan(
            explicitRoot: nil,
            currentDirectory: nested.path,
            explicitTritonBin: nil,
            currentExecutable: "/usr/local/bin/triton",
            host: "localhost",
            port: 34199,
            installMode: .auto,
            environment: [:]
        )

        #expect(plan.webRoot == repo.appendingPathComponent("Web").path)
        #expect(plan.url == "http://localhost:34199/")
    }

    @Test("web command reports missing web root clearly")
    func webCommandReportsMissingWebRootClearly() throws {
        let empty = try temporaryDirectory()

        #expect(throws: WebCommandError.self) {
            _ = try makeWebLaunchPlan(
                explicitRoot: nil,
                currentDirectory: empty.path,
                explicitTritonBin: nil,
                currentExecutable: "/usr/local/bin/triton",
                host: "127.0.0.1",
                port: 34127,
                installMode: .auto,
                environment: [:]
            )
        }
    }

    @Test("packaged web static response serves index fallback and assets")
    func packagedWebStaticResponseServesIndexFallbackAndAssets() throws {
        let web = try temporaryDirectory()
        try "<html>Device Hub</html>".write(to: web.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try "body{}".write(to: web.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)

        let index = try makePackagedWebStaticResponse(webRoot: web.path, requestPath: "/device/host")
        let css = try makePackagedWebStaticResponse(webRoot: web.path, requestPath: "/style.css")

        #expect(index.contentType == "text/html; charset=utf-8")
        #expect(String(data: index.data, encoding: .utf8)?.contains("Device Hub") == true)
        #expect(css.contentType == "text/css; charset=utf-8")
        #expect(String(data: css.data, encoding: .utf8) == "body{}")
    }

    @Test("web host logs rejects non iOS platforms with readonly envelope")
    func webHostLogsRejectsNonIOSPlatformsWithReadonlyEnvelope() {
        let error = webHostLogsUnsupportedResponse(platform: "android")

        #expect(error.error.code == "web_host_logs_platform_not_supported")
        #expect(error.error.message.contains("only exposed for iOS Simulator") == true)
    }

    @Test("schema exposes web command contract")
    func schemaExposesWebCommandContract() {
        let schema = commandSchemas().first { $0.name == "web" }

        #expect(schema?.runtimeScope == "cli-long-running")
        #expect(schema?.examples.contains("triton web --print-command --json") == true)
        #expect(schema?.failureCodes.contains("web_root_not_found") == true)
    }

    @Test("root command registers web subcommand")
    func rootCommandRegistersWebSubcommand() {
        let commandNames = TritonKitCLI.configuration.subcommands.map { $0.configuration.commandName }

        #expect(commandNames.contains("web"))
    }
}

private func temporaryRepoWithWeb(nodeModules: Bool) throws -> URL {
    let root = try temporaryDirectory()
    let web = root.appendingPathComponent("Web", isDirectory: true)
    try FileManager.default.createDirectory(at: web, withIntermediateDirectories: true)
    try "{}".write(to: web.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
    try "export default {}".write(to: web.appendingPathComponent("vite.config.ts"), atomically: true, encoding: .utf8)
    if nodeModules {
        try FileManager.default.createDirectory(at: web.appendingPathComponent("node_modules", isDirectory: true), withIntermediateDirectories: true)
    }
    return root
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-web-command-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
