import Testing
import TritonKitShared

@Suite("Simulator rename argv contract")
struct TKSimulatorRenameTests {
    @Test("rename uses common argv and lifecycle mutation metadata, not delete/clone or shell")
    func renameBuilder() {
        let command = TKSimctlCommand.rename(udid: "FIXTURE", name: "设备 Name; $(opaque)")
        #expect(command.executable == "xcrun")
        #expect(command.arguments == ["simctl", "rename", "FIXTURE", "设备 Name; $(opaque)"])
        #expect(command.riskLevel == .automation)
        #expect(command.requiredConfig.contains(.target))
        #expect(command.requiredConfig.contains(.timeout))
        #expect(command.requiredConfig.contains(.auditRecord))
        #expect(!command.capturesArtifacts)
    }
}
