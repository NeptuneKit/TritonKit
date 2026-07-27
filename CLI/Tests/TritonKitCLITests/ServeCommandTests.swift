import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct ServeCommandTests {
    @Test("serve parser defaults to loopback without starting the server")
    func parserDefaultsToLoopbackWithoutStartingTheServer() throws {
        let command = try Serve.parse([])

        #expect(command.host == "127.0.0.1")
        #expect(command.port == 19421)
    }

    @Test("serve parser preserves an explicit non-loopback host")
    func parserPreservesExplicitNonLoopbackHost() throws {
        let command = try Serve.parse([
            "--host", "0.0.0.0",
            "--port", "19421",
        ])

        #expect(command.host == "0.0.0.0")
        #expect(command.port == 19421)
    }

    @Test("Chinese serve help describes the loopback default")
    func chineseServeHelpDescribesLoopbackDefault() throws {
        let help = try #require(chineseCommandHelps()["serve"])
        let hostOption = try #require(help.options.first { $0.0 == "--host <host>" })

        #expect(hostOption.1.contains("默认 127.0.0.1"))
        #expect(!hostOption.1.contains("0.0.0.0"))
    }

    @Test("serve schema describes the loopback default")
    func serveSchemaDescribesLoopbackDefault() throws {
        let response = try buildSchemaResponse(command: "serve")
        let serve = try #require(response.commands.first)
        let hostOption = try #require(serve.options.first { $0.name == "--host" })
        let portOption = try #require(serve.options.first { $0.name == "--port" })

        #expect(hostOption.defaultValue == "127.0.0.1")
        #expect(portOption.defaultValue == "19421")
        #expect(serve.examples.contains("triton serve --host 127.0.0.1 --port 19421"))
    }

    @Test("server recovery action uses the loopback default")
    func serverRecoveryActionUsesLoopbackDefault() throws {
        let action = try #require(runtimeCapabilityNextAction(
            for: "status",
            host: "127.0.0.1",
            port: 19421,
            serverReachable: false,
            connected: false
        ))

        #expect(action.command == "serve")
        #expect(action.args == ["--host", "127.0.0.1", "--port", "19421"])
        #expect(action.requiresLongRunningProcess)
    }

    @Test("server recovery action preserves an explicit non-loopback host")
    func serverRecoveryActionPreservesExplicitNonLoopbackHost() throws {
        let action = try #require(runtimeCapabilityNextAction(
            for: "status",
            host: "192.168.1.20",
            port: 19421,
            serverReachable: false,
            connected: false
        ))

        #expect(action.args == ["--host", "192.168.1.20", "--port", "19421"])
    }
}
