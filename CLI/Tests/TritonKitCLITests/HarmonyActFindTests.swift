import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

/// SP-164 / GitHub #201: `act find` must be able to select a Harmony host adapter
/// (`--platform harmony --device <harmony-target>`) and resolve matches from the
/// Harmony uitest host layout, exactly like `act tap`, instead of falling through
/// to the embedded iOS runtime server.
@Suite("SP-164 Harmony act find")
struct HarmonyActFindTests {
    private let harmonyTarget = TKHarmonyTarget(target: "127.0.0.1:10100", state: "Connected", transport: "TCP")

    private func layoutCapture(json: String, sourceCommands: [String] = ["hdc shell uitest dumpLayout", "hdc file recv layout.json"]) -> (TKHarmonyTarget, String) throws -> HarmonyLayoutCapture {
        { _, _ in
            HarmonyLayoutCapture(
                localPath: "/tmp/issue-201-layout.json",
                remotePath: "/data/local/tmp/issue-201-layout.json",
                sourceCommands: sourceCommands,
                data: Data(json.utf8)
            )
        }
    }

    private let twoNodeLayout = #"""
    {"attributes":{},
     "children":[
       {"attributes":{"type":"Text","text":"设置","bounds":"[0,0][200,100]"}},
       {"attributes":{"type":"Button","text":"设置","bounds":"[0,120][200,220]"}},
       {"attributes":{"type":"Text","text":"登录","bounds":"[300,400][400,500]"}}
     ]}
    """#

    // MARK: - Parser surface (red before #201)

    @Test("find accepts --platform harmony with a Harmony host --device and --hdc")
    func findParsesHarmonyHostPlatformAndDevice() throws {
        let command = try Find.parse([
            "设置",
            "--platform", "harmony",
            "--device", "127.0.0.1:10100",
            "--hdc", "/opt/deveco/hdc",
            "--json",
        ])

        #expect(command.query == "设置")
        #expect(command.platform == .harmony)
        #expect(command.target == "127.0.0.1:10100")
        #expect(command.hdc == "/opt/deveco/hdc")
    }

    @Test("find routes a Harmony platform to the host adapter, never to the embedded server")
    func harmonyPlatformNeverRoutesToEmbeddedServer() {
        #expect(actFindHostRoute(platform: .harmony) == .hostHarmony)
        #expect(actFindHostRoute(platform: .ios) == .hostUnsupported(.ios))
        #expect(actFindHostRoute(platform: .android) == .hostUnsupported(.android))
        #expect(actFindHostRoute(platform: nil) == .embedded)
        #expect(actFindHostRoute(platform: .harmony) != .embedded)
    }

    @Test("find without --platform keeps the embedded runtime path")
    func findWithoutPlatformStaysEmbedded() throws {
        let command = try Find.parse(["Needle", "--device", "triton:ios-simulator:00000000-0000-0000-0000-000000000000"])
        #expect(command.platform == nil)
        #expect(actFindHostRoute(platform: command.platform) == .embedded)
    }

    // MARK: - Host layout resolution (pure function, no hdc execution)

    @Test("harmony find resolves the first exact layout text match into a coordinate resolution")
    func harmonyFindResolvesExactTextMatch() throws {
        let resolution = try resolveHostHarmonyFind(
            "设置",
            selected: harmonyTarget,
            hdc: "hdc",
            captureLayout: layoutCapture(json: twoNodeLayout)
        )

        #expect(resolution.query == "设置")
        #expect(resolution.source == "host-harmony-layout")
        #expect(resolution.strategy == "coordinate")
        #expect(resolution.label == "设置")
        #expect(resolution.matchIndex == 1)
        #expect(resolution.matchCount == 2)
        #expect(resolution.frame == TKRect(x: 0, y: 0, width: 200, height: 100))
        #expect(resolution.request.x == 100)
        #expect(resolution.request.y == 50)
    }

    @Test("harmony find --all exposes stable 1-based candidates")
    func harmonyFindAllExposesCandidates() throws {
        let resolution = try resolveHostHarmonyFind(
            "设置",
            selected: harmonyTarget,
            hdc: "hdc",
            includeCandidates: true,
            captureLayout: layoutCapture(json: twoNodeLayout)
        )

        let candidates = try #require(resolution.candidates)
        #expect(candidates.count == 2)
        #expect(candidates.map(\.index) == [1, 2])
        #expect(candidates[1].frame == TKRect(x: 0, y: 120, width: 200, height: 100))
        #expect(candidates[1].role == "Button")
        #expect(candidates[1].identifier == nil)
    }

    @Test("harmony find --index selects a later candidate")
    func harmonyFindIndexSelectsLaterCandidate() throws {
        let resolution = try resolveHostHarmonyFind(
            "设置",
            selected: harmonyTarget,
            hdc: "hdc",
            index: 2,
            captureLayout: layoutCapture(json: twoNodeLayout)
        )

        #expect(resolution.matchIndex == 2)
        #expect(resolution.matchCount == 2)
        #expect(resolution.frame == TKRect(x: 0, y: 120, width: 200, height: 100))
    }

    @Test("harmony find --within and --at filter the layout candidates")
    func harmonyFindWithinAndAtFilterCandidates() throws {
        let within = try resolveHostHarmonyFind(
            "设置",
            selected: harmonyTarget,
            hdc: "hdc",
            within: TKRect(x: 0, y: 100, width: 300, height: 200),
            captureLayout: layoutCapture(json: twoNodeLayout)
        )
        #expect(within.matchCount == 1)
        #expect(within.frame == TKRect(x: 0, y: 120, width: 200, height: 100))

        let at = try resolveHostHarmonyFind(
            "设置",
            selected: harmonyTarget,
            hdc: "hdc",
            at: (x: 100, y: 170),
            captureLayout: layoutCapture(json: twoNodeLayout)
        )
        #expect(at.matchCount == 1)
        #expect(at.frame == TKRect(x: 0, y: 120, width: 200, height: 100))
    }

    @Test("harmony find missing text fails with the typed text_not_found detail, not server_unavailable")
    func harmonyFindMissingTextIsTypedTextNotFound() throws {
        let error = try #require(throws: Error.self) {
            _ = try resolveHostHarmonyFind(
                "缺失",
                selected: harmonyTarget,
                hdc: "hdc",
                captureLayout: layoutCapture(json: twoNodeLayout)
            )
        }
        let detail = cliErrorDetail(for: error, endpoint: "/request", host: "127.0.0.1", port: 19421)
        #expect(detail.code == "text_not_found")
        #expect(detail.suggestedCommands?.contains { $0.contains("--platform harmony") } == true)
    }

    @Test("harmony find out-of-range --index fails with typed text_not_found")
    func harmonyFindIndexOutOfRangeIsTypedTextNotFound() throws {
        let error = try #require(throws: Error.self) {
            _ = try resolveHostHarmonyFind(
                "设置",
                selected: harmonyTarget,
                hdc: "hdc",
                index: 3,
                captureLayout: layoutCapture(json: twoNodeLayout)
            )
        }
        let detail = cliErrorDetail(for: error, endpoint: "/request", host: "127.0.0.1", port: 19421)
        #expect(detail.code == "text_not_found")
        #expect(detail.message.contains("--index 3"))
    }

    // MARK: - Schema contract

    @Test("act.find schema exposes --platform/--hdc and typed unsupported instead of server fallthrough")
    func actFindSchemaExposesHarmonyHostSelection() throws {
        let schema = try #require(actionCommandSchemas().first { $0.name == "act" })
        let find = try #require(schema.subcommands.first { $0.name == "find" })

        #expect(find.optionalOptions.contains("--platform"))
        #expect(find.optionalOptions.contains("--adb"))
        #expect(find.optionalOptions.contains("--hdc"))
        #expect(find.failureCodes.contains("unsupported_capability"))
        #expect(find.failureCodes.contains("text_not_found"))
        #expect(schema.examples.contains { $0.contains("find 登录 --platform harmony") })
    }

    @Test("act.find --platform harmony --device argv validates against the schema")
    func actFindHarmonyArgvValidatesAgainstSchema() throws {
        let schemas = commandSchemaMap()
        var issues = SchemaBackedCommandIssues()
        validateSchemaBackedArgv(
            ["triton", "act", "find", "登录", "--platform", "harmony", "--device", "127.0.0.1:10100", "--hdc", "hdc", "--json"],
            context: "act.find/harmony-host",
            schemas: schemas,
            issues: &issues
        )
        expectNoSchemaBackedCommandIssues(issues)
    }
}
