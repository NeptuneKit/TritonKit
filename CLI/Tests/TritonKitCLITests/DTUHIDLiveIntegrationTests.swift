import Foundation
import Testing
@testable import TritonKitCLI

private let sp255OwnedDTUHIDSimulator = ProcessInfo.processInfo.environment[
    "TRITON_SP255_OWNED_SIMULATOR"
].flatMap(UUID.init(uuidString:))

@Suite("SP-255 owned Simulator DTUHID no-event barriers", .serialized)
struct DTUHIDLiveIntegrationTests {
    @Test(.enabled(if: sp255OwnedDTUHIDSimulator != nil,
                   "Requires an explicitly task-owned Simulator; disabled is not live acceptance."))
    func initAndFinishWithoutContactsUseModernBackend() throws {
        let owned = try #require(sp255OwnedDTUHIDSimulator)
        let developer = try #require(selectedXcodeDeveloperDirectory(environment: ProcessInfo.processInfo.environment))
        // Exactly the production admission before and after a production driver.
        // No contact/key is submitted; external fixture observation must prove
        // that the business state did not change across these two barriers.
        let environment = ["DEVELOPER_DIR": developer]
        let before = try nativeHIDGuardSnapshot(target: owned.uuidString, environment: environment, allowActiveDTUHID: true)
        let driver = try NativeSimulatorDigitizer(target: owned.uuidString, developerDirectory: developer)
        #expect(driver.backend == "dtuhid", "Legacy does not satisfy this acceptance case")
        #expect(driver.pointSize == before.pointSize)
        try driver.finish()
        let after = try nativeHIDGuardSnapshot(target: owned.uuidString, environment: environment, allowActiveDTUHID: true)
        #expect(after == before)
    }
}
