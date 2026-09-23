import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct SimulatorResourceOfflineStoreTests {
    @Test("offline store merges managed labels and preserves explicit entries")
    func mergePreservesEntries() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = SimulatorResourceOfflineStore.root
        SimulatorResourceOfflineStore.root = root.path
        defer { SimulatorResourceOfflineStore.root = old }
        try SimulatorResourceOfflineStore.merge("device", disable: ["managed"], enable: [])
        try SimulatorResourceOfflineStore.merge("device", disable: [], enable: ["managed"])
        let entries = try SimulatorResourceOfflineStore.read("device")
        #expect(entries["managed"] == false)
    }
}
