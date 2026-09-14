import XCTest
@testable import TritonKitShared

final class TKSimulatorResourcePlanTests: XCTestCase {
    func testCanonicalArtifactsByAction() {
        XCTAssertEqual(TKSimulatorResourcePlanStep.canonicalArtifacts(action: "apply"), ["simulator-resource.plan.json", "simulator-resource.status.json", "simulator-resource.receipt.json"])
        XCTAssertEqual(TKSimulatorResourcePlanStep.canonicalArtifacts(action: "measure"), ["simulator-resource.measurement.json"])
    }
    func testPlanResultCarriesExpectedArtifacts() {
        let step = TKSimulatorResourcePlanStep(action: "verify", expectedArtifacts: TKSimulatorResourcePlanStep.canonicalArtifacts(action: "verify"))
        XCTAssertEqual(TKSimulatorResourcePlanResult(target: "UDID", step: step).expectedArtifacts, ["simulator-resource.status.json"])
    }
}
