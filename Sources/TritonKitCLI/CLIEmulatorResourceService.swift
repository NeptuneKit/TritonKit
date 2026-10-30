import Foundation

enum EmulatorResourceCLI {
    static func execute(action: String, platform: EmulatorResourcePlatform, device: String?, adb: String, hdc: String, profile: String, disable: String?, keep: String?, receipt: String?, confirm: Bool) throws -> EmulatorResourceOutput {
        var output = EmulatorResourceOutput(action: action, platform: platform)
        if action == "features" || action == "profiles" {
            output.features = EmulatorResourceCatalog.features(platform)
            output.profiles = ["stock", "ui-minimal", "custom"]
            return output
        }
        guard let device, !device.isEmpty else { throw EmulatorResourceError("resource_invalid_target", "An explicit emulator target is required") }
        let adapter: EmulatorResourceAdapter = platform == .android ? AndroidResourceAdapter(device: device, executable: adb) : HarmonyResourceAdapter(device: device, executable: hdc)
        let engine = EmulatorResourceEngine()
        switch action {
        case "plan": return try engine.plan(adapter: adapter, platform: platform, profile: profile, disable: disable, keep: keep)
        case "apply":
            guard let receipt else { throw EmulatorResourceError("resource_invalid_receipt", "A new receipt path is required") }
            return try engine.apply(adapter: adapter, platform: platform, profile: profile, disable: disable, keep: keep, receiptPath: receipt, confirm: confirm)
        case "verify", "restore":
            guard let receipt else { throw EmulatorResourceError("resource_invalid_receipt", "A receipt path is required") }
            return action == "verify" ? try engine.verify(adapter: adapter, platform: platform, receiptPath: receipt) : try engine.restore(adapter: adapter, platform: platform, receiptPath: receipt, confirm: confirm)
        case "status", "doctor":
            output.identity = try adapter.identity()
            output.features = EmulatorResourceCatalog.features(platform)
            output.states = EmulatorResourceCatalog.items(platform).map { item in
                do { return try adapter.read(item) }
                catch { return .init(item: item, value: nil, available: false, reason: (error as? EmulatorResourceError)?.code ?? "resource_command_failed") }
            }
            output.partial = output.states!.contains { !$0.available || $0.value == nil }
        case "measure":
            let identity = try adapter.identity()
            output.identity = identity; output.memory = try adapter.measure()
            output.hostMemory = EmulatorResourceHostMemory.measure(identity: identity)
            output.partial = output.memory!.partial || output.hostMemory!.partial
            guard try adapter.identity() == identity else { throw EmulatorResourceError("resource_identity_mismatch", "Identity changed during measurement") }
        default: throw EmulatorResourceError("resource_invalid_action", "Unknown resource action")
        }
        return output
    }
    static func printOutput(_ output: EmulatorResourceOutput, format: ClientOutputFormat) throws {
        // Both formats retain the complete audit/verification boundary; JSON is the default.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(output), as: UTF8.self))
    }
}
