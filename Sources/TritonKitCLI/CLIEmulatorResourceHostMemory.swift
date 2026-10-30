import Foundation
#if os(macOS)
import Darwin
#endif

/// One verified emulator VM process. Child processes are deliberately excluded.
struct EmulatorResourceHostMemory: Codable {
    let metric: String
    let pid: Int32?
    let physicalFootprintBytes: UInt64?
    let partial: Bool
    let reason: String?

    private static let metricName = "host_vm_main_process_physical_footprint_bytes"
    private static let scope = "VM main process only; excludes child processes"
    private static let argumentLimit = 1_048_576
    private enum Failure: Error { case unsupportedPlatform, argumentsUnavailable, malformedArguments }
    private enum Match { case selected, selectedByAVD, sameAVDOtherPort, other, invalid }

    static func measure(
        identity: EmulatorResourceIdentity,
        processList: () throws -> [SimulatorPhysicalFootprint.ProcessEntry] = SimulatorPhysicalFootprint.hostProcessList,
        arguments: (Int32) throws -> [String] = EmulatorResourceHostMemory.hostArguments,
        sample: (Int32) throws -> UInt64 = SimulatorPhysicalFootprint.hostSample
    ) -> Self {
        guard let port = targetPort(identity) else { return unavailable("Invalid local emulator identity") }
        let entries: [SimulatorPhysicalFootprint.ProcessEntry]
        do { entries = try processList() } catch { return unavailable("Host process list is unavailable") }
        guard entries.count <= 65_536, Set(entries.map(\.pid)).count == entries.count,
              entries.allSatisfy({ $0.pid > 0 && $0.parentPID >= 0 }) else {
            return unavailable("Host process list is malformed")
        }
        var roots: [(pid: Int32, argv: [String], avdOnly: Bool)] = []
        var unverifiedCandidate = false
        var sameAVDOtherPort = false
        for entry in entries {
            // ps is only a coarse candidate filter. It is never split into argv or used as identity proof.
            let candidate = identity.platform == .android
                ? entry.arguments.contains("qemu-system-aarch64")
                : entry.arguments.contains("Emulator")
            guard candidate else { continue }
            let argv: [String]
            do { argv = try arguments(entry.pid) } catch { unverifiedCandidate = true; continue }
            switch match(argv, identity: identity, port: port) {
            case .selected: roots.append((entry.pid, argv, false))
            case .selectedByAVD: roots.append((entry.pid, argv, true))
            case .sameAVDOtherPort: sameAVDOtherPort = true
            case .other: break
            case .invalid: unverifiedCandidate = true
            }
        }
        guard !unverifiedCandidate else { return unavailable("Host VM arguments could not be verified") }
        guard roots.count == 1, let root = roots.first else {
            return unavailable(roots.isEmpty ? "Host VM main process was not found" : "Host VM main process is ambiguous")
        }
        guard !root.avdOnly || !sameAVDOtherPort else { return unavailable("AVD-only host VM selection is ambiguous") }
        let bytes: UInt64
        do {
            bytes = try sample(root.pid)
            // A disappearing/replaced PID must not produce a sample for another process.
            guard try arguments(root.pid) == root.argv else { return unavailable("Host VM process changed during sampling") }
        } catch { return unavailable("Host VM physical footprint is unavailable") }
        let basis = root.avdOnly ? "; AVD-only match against verified guest identity because argv omits -port" : ""
        return .init(metric: metricName, pid: root.pid, physicalFootprintBytes: bytes, partial: false, reason: scope + basis)
    }

    /// KERN_PROCARGS2 includes a kernel-supplied executable path before argc NUL-separated arguments.
    /// Return that path as argv[0], retaining argument boundaries and excluding environment variables.
    static func hostArguments(pid: Int32) throws -> [String] {
        guard pid > 0 else { throw Failure.argumentsUnavailable }
        #if os(macOS)
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = argumentLimit
        var buffer = [UInt8](repeating: 0, count: argumentLimit)
        let result = mib.withUnsafeMutableBufferPointer { path in
            buffer.withUnsafeMutableBytes { bytes in
                sysctl(path.baseAddress, u_int(path.count), bytes.baseAddress, &size, nil, 0)
            }
        }
        guard result == 0, size > 0, size <= argumentLimit else { throw Failure.argumentsUnavailable }
        return try parseProcArgs(Data(buffer.prefix(size)))
        #else
        throw Failure.unsupportedPlatform
        #endif
    }

    static func parseProcArgs(_ data: Data) throws -> [String] {
        guard data.count > MemoryLayout<Int32>.size, data.count <= argumentLimit else { throw Failure.malformedArguments }
        let argc = data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard argc > 0, argc <= 4096 else { throw Failure.malformedArguments }
        let bytes = Array(data)
        var cursor = MemoryLayout<Int32>.size
        func readString() throws -> String {
            guard cursor < bytes.count,
                  let end = bytes[cursor...].firstIndex(of: 0),
                  let value = String(bytes: bytes[cursor..<end], encoding: .utf8) else { throw Failure.malformedArguments }
            cursor = end + 1
            return value
        }
        let executable = try readString()
        guard !executable.isEmpty else { throw Failure.malformedArguments }
        // Padding follows the executable path; argv[0] is nonempty for a process we can identify.
        while cursor < bytes.count, bytes[cursor] == 0 { cursor += 1 }
        var argv: [String] = []
        for _ in 0..<Int(argc) { argv.append(try readString()) }
        guard !argv[0].isEmpty else { throw Failure.malformedArguments }
        argv[0] = executable
        return argv
    }

    private static func targetPort(_ identity: EmulatorResourceIdentity) -> String? {
        let prefix = identity.platform == .android ? "emulator-" : "127.0.0.1:"
        guard identity.target.hasPrefix(prefix), !identity.instance.isEmpty,
              !identity.image.isEmpty, !identity.bootID.isEmpty else { return nil }
        let raw = String(identity.target.dropFirst(prefix.count))
        guard let port = UInt16(raw), port > 0, String(port) == raw else { return nil }
        if identity.platform == .android {
            guard port >= 1024, port.isMultiple(of: 2),
                  !identity.instance.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        }
        return raw
    }

    private static func match(_ argv: [String], identity: EmulatorResourceIdentity, port: String) -> Match {
        guard !argv.isEmpty, argv.count <= 4096,
              argv.allSatisfy({ $0.utf8.count <= argumentLimit && !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }) else { return .invalid }
        let executable = URL(fileURLWithPath: argv[0]).lastPathComponent
        switch identity.platform {
        case .android:
            guard ["qemu-system-aarch64", "qemu-system-aarch64-headless"].contains(executable) else { return .other }
            let positionalAVDs = argv.dropFirst().filter { $0.hasPrefix("@") }
            let namedAVDCount = argv.dropFirst().filter { $0 == "-avd" }.count
            guard !argv.dropFirst().contains(where: { $0.hasPrefix("-avd") && $0 != "-avd" }),
                  positionalAVDs.count + namedAVDCount == 1 else { return .invalid }
            let avd: String
            if let positional = positionalAVDs.first {
                guard positional.count > 1 else { return .invalid }
                avd = String(positional.dropFirst())
            } else {
                guard let named = singleOption("-avd", argv: argv) else { return .invalid }
                avd = named
            }
            guard avd == identity.instance else { return .other }
            // QEMU may omit -port when the launcher automatically assigns one. An unrelated AVD is already excluded above.
            guard !argv.dropFirst().contains(where: { $0.hasPrefix("-port") && $0 != "-port" }) else { return .invalid }
            if !argv.contains("-port") { return .selectedByAVD }
            guard let actualPort = singleOption("-port", argv: argv) else { return .invalid }
            return actualPort == port ? .selected : .sameAVDOtherPort
        case .harmony:
            guard executable == "Emulator" else { return .other }
            guard let actualPort = singleOption("-hdcPort", argv: argv) else { return .invalid }
            let selectors = argv.indices.filter { argv[$0] == "-start" || argv[$0] == "-hvd" }
            guard selectors.count == 1, let selector = selectors.first, selector + 1 < argv.count,
                  !argv[selector + 1].isEmpty, !argv[selector + 1].hasPrefix("-") else { return .invalid }
            // HVD names can contain spaces. Guest identity already verifies the model; host selection uses the unique HDC port.
            return actualPort == port ? .selected : .other
        }
    }

    private static func singleOption(_ option: String, argv: [String]) -> String? {
        let indexes = argv.indices.filter { argv[$0] == option }
        guard indexes.count == 1, let index = indexes.first, index + 1 < argv.count,
              !argv[index + 1].isEmpty, !argv[index + 1].hasPrefix("-") else { return nil }
        return argv[index + 1]
    }

    private static func unavailable(_ message: String) -> Self {
        .init(metric: metricName, pid: nil, physicalFootprintBytes: nil, partial: true, reason: "\(message). \(scope)")
    }
}
