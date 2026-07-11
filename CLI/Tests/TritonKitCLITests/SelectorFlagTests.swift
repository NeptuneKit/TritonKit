import ArgumentParser
import Testing
@testable import TritonKitCLI

@Suite
struct SelectorFlagTests {
    @Test("find accepts device as target selector alias")
    func findAcceptsDeviceAlias() throws {
        let command = try Find.parse(["Needle", "--device", "booted"])

        #expect(command.query == "Needle")
        #expect(command.target == "booted")
    }

    @Test("tap accepts device as target selector alias")
    func tapAcceptsDeviceAlias() throws {
        let command = try Tap.parse(["Needle", "--device", "booted"])

        #expect(command.query == "Needle")
        #expect(command.target == "booted")
    }

    @Test("tap accepts iOS host platform")
    func tapAcceptsIOSHostPlatform() throws {
        let command = try Tap.parse(["设置", "--platform", "ios", "--device", "booted"])

        #expect(command.query == "设置")
        #expect(command.platform == .ios)
        #expect(command.target == "booted")
    }

    @Test("tap parses WebView-aware agent options")
    func tapParsesWebViewAwareAgentOptions() throws {
        let command = try Tap.parse([
            "--webview-aware",
            "--selector",
            "#submit",
            "--webview-id",
            "webview-1",
            "--page-session-id",
            "page-1",
            "--expect-text",
            "成功",
            "--timeout",
            "5",
            "--json",
        ])

        #expect(command.webViewAware)
        #expect(command.selector == "#submit")
        #expect(command.webViewID == "webview-1")
        #expect(command.pageSessionID == "page-1")
        #expect(command.expectText == "成功")
        #expect(command.timeout == 5)
        #expect(command.json)
    }

    @Test("WebView-aware tap source command preserves agent contract")
    func webViewAwareTapSourceCommandPreservesAgentContract() {
        let command = webViewAwareTapSourceCommand(
            selector: "#submit",
            webViewID: "webview-1",
            pageSessionID: "page-1",
            expectText: "成功",
            timeout: 5,
            outputFormat: .json
        )

        #expect(command == "triton act tap --webview-aware --selector '#submit' --webview-id 'webview-1' --page-session-id 'page-1' --expect-text '成功' --timeout 5 --json")
    }

    @Test("wait and assert accept device as target selector alias")
    func waitAndAssertAcceptDeviceAlias() throws {
        let wait = try Wait.parse(["--text", "Ready", "--device", "booted"])
        let assertion = try UIAssert.parse(["text-exists", "Ready", "--device", "booted"])

        #expect(wait.target == "booted")
        #expect(assertion.target == "booted")
    }

    @Test("node resolve accepts positional alias query")
    func nodeResolveAcceptsPositionalAliasQuery() throws {
        let command = try NodeResolve.parse(["@1", "--platform", "ios", "--device", "booted"])

        #expect(command.query == "@1")
        #expect(command.text == nil)
        #expect(command.platform == .ios)
        #expect(command.device == "booted")
    }

    @Test("observe tree accepts outline flag")
    func observeTreeAcceptsOutlineFlag() throws {
        let command = try ObserveTree.parse(["--platform", "ios", "--device", "booted", "--outline"])

        #expect(command.platform == .ios)
        #expect(command.device == "booted")
        #expect(command.outline)
    }

    @Test("observation device alias infers platform when platform is omitted")
    func observationDeviceAliasInfersPlatform() {
        let request = observationHostDeviceSelectionRequest(
            device: "harmony-a",
            platform: nil,
            target: "triton:local",
            runtimeBaseURL: nil
        )

        #expect(request.device == "harmony-a")
        #expect(request.platform == nil)
        #expect(request.ready)
    }

    @Test("observation explicit platform remains a selection filter")
    func observationExplicitPlatformRemainsFilter() {
        let request = observationHostDeviceSelectionRequest(
            device: "harmony-a",
            platform: .harmony,
            target: "triton:local",
            runtimeBaseURL: nil
        )

        #expect(request.platform == .harmony)
    }

    @Test("find and tap schemas expose target device selector vocabulary")
    func actionSchemasExposeDeviceAlias() throws {
        let schemas = Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })
        let act = try #require(schemas["act"])

        #expect(act.options.contains(where: { $0.name == "--target/--device" }))
        #expect(act.subcommands.map(\.name).contains("find"))
        #expect(act.subcommands.map(\.name).contains("tap"))
    }
}
