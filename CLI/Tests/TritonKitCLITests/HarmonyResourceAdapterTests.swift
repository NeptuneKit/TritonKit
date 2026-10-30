import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct HarmonyResourceAdapterTests {
    private let target = "127.0.0.1:10101"
    private var camera: EmulatorResourceItem { EmulatorResourceCatalog.items(.harmony).first { $0.id == "camera_service" }! }

    @Test("Exit-zero HDC failure is unavailable and does not leak diagnostics")
    func exitZeroHDCFailure() throws {
        let adapter = HarmonyResourceAdapter(device: target) { _ in
            harmonyResourceResult("[Fail][E001005] Device not found or connected PRIVATE-TARGET\n")
        }
        let state = try adapter.read(camera)
        #expect(!state.available)
        #expect(state.value == nil)
        #expect(state.reason == "resource_command_failed")
        #expect(!String(describing: state).contains("PRIVATE-TARGET"))
    }

    @Test("Parameter permission code 1002 at exit zero fails closed")
    func parameterPermissionDenied() throws {
        let adapter = HarmonyResourceAdapter(device: target) { _ in harmonyResourceResult("Get parameter \"startup.service.ctl.camera_service\" fail! errNum is:1002!\n") }
        let state = try adapter.read(camera)
        #expect(!state.available)
        #expect(state.reason == "resource_permission_denied")
    }

    @Test("Permission text on stderr is not ignored")
    func stderrPermissionDenied() throws {
        let adapter = HarmonyResourceAdapter(device: target) { _ in harmonyResourceResult("running\n", stderr: "Permission denied PRIVATE-PATH") }
        let state = try adapter.read(camera)
        #expect(!state.available)
        #expect(state.reason == "resource_permission_denied")
    }

    @Test("Only exact running and stopped values are accepted")
    func invalidStateOutput() throws {
        for output in ["", "started", "running\nstopped", "running PRIVATE-LOG", "[running]", "Running"] {
            let adapter = HarmonyResourceAdapter(device: target) { _ in harmonyResourceResult(output) }
            let state = try adapter.read(camera)
            #expect(!state.available)
            #expect(state.reason == "resource_invalid_output")
        }
    }

    @Test("Truncation and nonzero exit cannot yield available state")
    func invalidHostResult() throws {
        let truncated = HarmonyResourceAdapter(device: target) { _ in harmonyResourceResult("running", truncated: true) }
        #expect(try truncated.read(camera).reason == "resource_output_truncated")
        let nonzero = HarmonyResourceAdapter(device: target) { _ in harmonyResourceResult("running", exit: 1) }
        #expect(try nonzero.read(camera).reason == "resource_command_failed")
    }

    @Test("Unknown services cannot reach HDC")
    func unsupportedService() {
        var commands = 0
        let adapter = HarmonyResourceAdapter(device: target) { _ in commands += 1; return harmonyResourceResult("") }
        let item = EmulatorResourceItem(id: "foundation", feature: "camera", kind: .service, disabledValue: "stopped")
        #expect(throws: EmulatorResourceError.self) { try adapter.read(item) }
        #expect(throws: EmulatorResourceError.self) { try adapter.write(item, value: "stopped") }
        #expect(commands == 0)
    }

    @Test("Nonlocal, malformed and shell-injected selectors fail before any command")
    func invalidTarget() {
        for value in ["192.168.1.2:10101", "localhost:10101", "127.0.0.1:0", "127.0.0.1:65536", "127.0.0.1:010101", "127.0.0.1:10101;id", "USB-SERIAL", "harmony:harmony:127.0.0.1:10101"] {
            var commands = 0
            let adapter = HarmonyResourceAdapter(device: value) { _ in commands += 1; return harmonyResourceResult("") }
            #expect(throws: EmulatorResourceError.self) { try adapter.identity() }
            #expect(commands == 0)
        }
    }

    @Test("Observed Harmony emulator parameters and a UUID bind the session identity")
    func observedIdentity() throws {
        let adapter = HarmonyResourceAdapter(device: "harmony:" + target) { command in
            harmonyResourceIdentityResponse(Array(command.arguments.dropFirst(3))) ?? harmonyResourceResult("UNEXPECTED")
        }
        let identity = try adapter.identity()
        #expect(identity.platform == .harmony)
        #expect(identity.target == target)
        #expect(identity.instance == target + "|emulator")
        #expect(identity.image == "emulator 6.0.0.130(SP7DEVC00E130R4P11)")
        #expect(identity.bootID == harmonyResourceBootID)
    }

    @Test("Loopback alone cannot identify an emulator and malformed boot identity is rejected")
    func invalidGuestIdentity() {
        for (field, output) in [
            ("const.product.model", "phone"),
            ("const.product.name", "commercial-device"),
            ("const.product.software.version", "6.0.0.130"),
            ("/proc/sys/kernel/random/boot_id", "PRIVATE invalid UUID")
        ] {
            let adapter = HarmonyResourceAdapter(device: target) { command in
                if command.arguments.last == field { return harmonyResourceResult(output) }
                return harmonyResourceIdentityResponse(Array(command.arguments.dropFirst(3))) ?? harmonyResourceResult("UNEXPECTED")
            }
            #expect(throws: EmulatorResourceError.self) { try adapter.identity() }
        }
    }

    @Test("A boot-ID permission refusal permits only explicitly degraded read-only identity")
    func unavailableBootIdentity() throws {
        let adapter = HarmonyResourceAdapter(device: target) { command in
            if command.arguments.last == "/proc/sys/kernel/random/boot_id" { return harmonyResourceResult("", stderr: "cat: Permission denied") }
            return harmonyResourceIdentityResponse(Array(command.arguments.dropFirst(3))) ?? harmonyResourceResult("UNEXPECTED")
        }
        #expect(try adapter.identity().bootID == "unavailable")
    }

    @Test("Degraded boot identity cannot make readable, privileged services writable")
    func missingBootIdentityDisablesControl() throws {
        var mutations = 0
        let adapter = HarmonyResourceAdapter(device: target) { command in
            let args = Array(command.arguments.dropFirst(3))
            if args == ["cat", "/proc/sys/kernel/random/boot_id"] { return harmonyResourceResult("Permission denied") }
            if let identity = harmonyResourceIdentityResponse(args) { return identity }
            switch args {
            case ["id", "-u"]: return harmonyResourceResult("0")
            case ["begetctl", "--help"]: return harmonyResourceResult(harmonyResourceControlHelp)
            case ["begetctl", "service_control", "stop", "camera_service"]:
                mutations += 1
                return harmonyResourceResult("")
            default: return harmonyResourceResult("running")
            }
        }
        let state = try adapter.read(camera)
        #expect(state.value == "running")
        #expect(state.reason == "resource_identity_unavailable")
        #expect(!state.available)
        #expect(throws: EmulatorResourceError.self) { try adapter.write(camera, value: "stopped") }
        #expect(mutations == 0)
    }

    @Test("Thrown host errors retain only a stable failure reason")
    func thrownErrorPrivacy() throws {
        let adapter = HarmonyResourceAdapter(device: target) { _ in throw HostCommandRunError.launchFailed("PRIVATE-CREDENTIAL") }
        let state = try adapter.read(camera)
        #expect(state.reason == "resource_command_failed")
        #expect(!String(describing: state).contains("PRIVATE-CREDENTIAL"))
    }

    @Test("Readable service state does not prove an unprivileged shell can control it")
    func unprivilegedShell() throws {
        var commands: [[String]] = []
        let adapter = HarmonyResourceAdapter(device: target) { command in
            commands.append(command.arguments)
            if command.arguments.suffix(2) == ["id", "-u"] { return harmonyResourceResult("2000") }
            return harmonyResourceResult("running")
        }
        let state = try adapter.read(camera)
        #expect(state.value == "running")
        #expect(!state.available)
        #expect(state.reason == "resource_control_permission_unverified")
        #expect(throws: EmulatorResourceError.self) { try adapter.write(camera, value: "stopped") }
        #expect(!commands.contains { $0.contains("service_control") })
        #expect(!commands.contains { $0.contains("root") || $0.contains("setenforce") })
    }

    @Test("Both control operations must be advertised before availability is reported")
    func missingControlCapability() throws {
        let adapter = HarmonyResourceAdapter(device: target) { command in
            switch Array(command.arguments.dropFirst(3)) {
            case ["id", "-u"]: return harmonyResourceResult("0")
            case ["begetctl", "--help"]: return harmonyResourceResult("service_control stop servicename --stop service")
            default: return harmonyResourceResult("running")
            }
        }
        #expect(try adapter.read(camera).reason == "resource_unsupported_control")
    }

    @Test("A successful write requires strict readback and redacts every command target")
    func writesAndReadsBack() throws {
        var current = "running"
        var commands: [[String]] = []
        let adapter = HarmonyResourceAdapter(device: "harmony:" + target) { command in
            #expect(command.sensitiveOutput)
            #expect(command.redactedArgumentIndexes == [1])
            #expect(Array(command.arguments.prefix(3)) == ["-t", target, "shell"])
            commands.append(command.arguments)
            if let identity = harmonyResourceIdentityResponse(Array(command.arguments.dropFirst(3))) { return identity }
            switch Array(command.arguments.dropFirst(3)) {
            case ["id", "-u"]: return harmonyResourceResult("0")
            case ["begetctl", "--help"]: return harmonyResourceResult(harmonyResourceControlHelp)
            case ["begetctl", "service_control", "stop", "camera_service"]:
                #expect(command.riskLevel == .automation)
                current = "stopped"
                return harmonyResourceResult("")
            default: return harmonyResourceResult(current)
            }
        }
        try adapter.write(camera, value: "stopped")
        #expect(commands.last?.suffix(3) == ["param", "get", "startup.service.ctl.camera_service"])
        #expect(current == "stopped")
    }

    @Test("Unknown control response is not accepted even with exit zero")
    func unknownWriteResponse() {
        let adapter = HarmonyResourceAdapter(device: target) { command in
            if let identity = harmonyResourceIdentityResponse(Array(command.arguments.dropFirst(3))) { return identity }
            switch Array(command.arguments.dropFirst(3)) {
            case ["id", "-u"]: return harmonyResourceResult("0")
            case ["begetctl", "--help"]: return harmonyResourceResult(harmonyResourceControlHelp)
            case ["begetctl", "service_control", "stop", "camera_service"]: return harmonyResourceResult("PRIVATE unexpected output")
            default: return harmonyResourceResult("running")
            }
        }
        do {
            try adapter.write(camera, value: "stopped")
            Issue.record("Expected fail-closed control response")
        } catch let error as EmulatorResourceError {
            #expect(error.code == "resource_invalid_output")
            #expect(!error.description.contains("PRIVATE"))
        } catch { Issue.record("Unexpected error type") }
    }

    @Test("Exit-zero empty control response still requires the requested service state")
    func failedReadback() {
        let adapter = HarmonyResourceAdapter(device: target) { command in
            if let identity = harmonyResourceIdentityResponse(Array(command.arguments.dropFirst(3))) { return identity }
            switch Array(command.arguments.dropFirst(3)) {
            case ["id", "-u"]: return harmonyResourceResult("0")
            case ["begetctl", "--help"]: return harmonyResourceResult(harmonyResourceControlHelp)
            case ["begetctl", "service_control", "stop", "camera_service"]: return harmonyResourceResult("")
            default: return harmonyResourceResult("running")
            }
        }
        do {
            try adapter.write(camera, value: "stopped")
            Issue.record("Expected readback failure")
        } catch let error as EmulatorResourceError {
            #expect(error.code == "resource_state_mismatch")
        } catch { Issue.record("Unexpected error type") }
    }

    @Test("Observed memory table preserves Total PSS and does not add SwapPss again")
    func observedMemoryFormat() throws {
        let memory = try HarmonyResourceAdapter.parseMemory(harmonyResourceMemoryFixture)
        #expect(memory.metric == "guest_total_pss_bytes")
        #expect(!memory.partial)
        #expect(memory.processes.map(\.name) == ["audio_server", "audio_host", "hianalytics", "camera_service"])
        #expect(memory.processes.first { $0.name == "hianalytics" }?.pssBytes == 13_192 * 1024)
        #expect(!String(describing: memory).contains("camera_host"))
    }

    @Test("Memory parser never exports unrelated process identities")
    func memoryPrivacy() throws {
        let table = harmonyResourceMemoryFixture + "\n999 123(0 in SwapPss) kB 0 kB 0 PRIVATE-CUSTOMER-APP"
        let memory = try HarmonyResourceAdapter.parseMemory(table)
        #expect(!String(describing: memory).contains("PRIVATE"))
        #expect(memory.processes.count == 4)
    }

    @Test("Duplicate PID and arithmetic overflow cannot inflate memory savings")
    func invalidMemoryRows() {
        let duplicate = harmonyResourceMemoryFixture + "\n734 13192(11580 in SwapPss) kB 0 kB -1000 hianalytics"
        let overflow = harmonyResourceMemoryFixture.replacingOccurrences(of: "18052(0 in SwapPss)", with: "18446744073709551615(0 in SwapPss)")
        let totalOverflow = harmonyResourceMemoryFixture.replacingOccurrences(of: "18052(0 in SwapPss)", with: "18014398509481983(0 in SwapPss)")
        let overflowPID = harmonyResourceMemoryFixture.replacingOccurrences(of: "189 ", with: "2147483648 ")
        for table in [duplicate, overflow, totalOverflow, overflowPID, "Total PSS: 123", harmonyResourceMemoryFixture + "\nPRIVATE INVALID DATA"] {
            #expect(throws: EmulatorResourceError.self) { try HarmonyResourceAdapter.parseMemory(table) }
        }
    }

    @Test("Measurement uses the bounded prune view and target privacy contract")
    func memoryCommand() throws {
        let adapter = HarmonyResourceAdapter(device: target) { command in
            #expect(command.arguments == ["-t", target, "shell", "hidumper", "--mem", "--prune"])
            #expect(command.sensitiveOutput)
            return harmonyResourceResult(harmonyResourceMemoryFixture)
        }
        #expect(try adapter.measure().processes.count == 4)
    }
}

// Relevant real help lines captured from DevEco 6.0.0.130, not a guessed CLI form.
private let harmonyResourceControlHelp = """
Command list:
    service_control start servicename               --start service
    service_control stop servicename                --stop service
"""

private let harmonyResourceBootID = "8ef89828-c879-4ab5-b40b-65685db5a79c"

private func harmonyResourceIdentityResponse(_ arguments: [String]) -> HostProcessResult? {
    switch arguments {
    case ["param", "get", "const.product.model"], ["param", "get", "const.product.name"]:
        return harmonyResourceResult("emulator\n")
    case ["param", "get", "const.product.software.version"]:
        return harmonyResourceResult("emulator 6.0.0.130(SP7DEVC00E130R4P11) \n")
    case ["cat", "/proc/sys/kernel/random/boot_id"]:
        // The UUID is synthetic: the real commercial image denies this read.
        return harmonyResourceResult(harmonyResourceBootID + "\n")
    default: return nil
    }
}

// Observed output from HarmonyOS 6.0.2/API 22; ordering is retained from PID sorting.
private let harmonyResourceMemoryFixture = """
-------------------------------[memory]-------------------------------
Total Memory Usage by PID:
PID        Total Pss(xxx in SwapPss)           GL     AdjLabel     Name
189           18052(0 in SwapPss) kB         0 kB        -1000     audio_server
520            3648(0 in SwapPss) kB         0 kB        -1000     camera_host
521            2838(0 in SwapPss) kB         0 kB        -1000     audio_host
734       13192(11580 in SwapPss) kB         0 kB        -1000     hianalytics
862           13757(0 in SwapPss) kB         0 kB        -1000     camera_service
"""

private func harmonyResourceResult(_ stdout: String, stderr: String = "", exit: Int32 = 0, truncated: Bool = false) -> HostProcessResult {
    HostProcessResult(stdoutData: Data(stdout.utf8), stderrData: Data(stderr.utf8), exitCode: exit,
                      sourceCommand: "PRIVATE-COMMAND", stdoutTruncated: truncated, stderrTruncated: false,
                      stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: stdout.utf8.count, stderrBytes: stderr.utf8.count)
}
