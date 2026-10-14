import Foundation
import XCTest
import TritonKitShared
@testable import TritonKitCLI

final class SimulatorResourceCommandTests: XCTestCase {
    func testPlanAndApplyParseSameProfileAndSimulator() throws {
        let udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let plan = try SimResourcePlan.parseAsRoot([udid, "--profile", "ci"]) as! SimResourcePlan
        let apply = try SimResourceApply.parseAsRoot([udid, "--profile", "ci", "--no-reboot", "--json"]) as! SimResourceApply
        XCTAssertEqual(plan.profile, apply.profile)
        XCTAssertEqual(plan.simulator, apply.simulator)
        XCTAssertTrue(apply.noReboot)
        let profile = try CLISimulatorResourceRuntime.resolveProfile(plan.profile)
        let labels = Set(SimulatorResourceMutationPlanner.labels(for: profile))
        XCTAssertEqual(labels, try SimulatorResourceCatalog.desired())
        XCTAssertTrue(labels.isDisjoint(with: SimulatorResourceCatalog.alwaysEnabledLabels))
    }

    func testInvalidProfileCategoryIsRejectedRatherThanIgnored() throws {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("profile.json")
        let profile = TKSimulatorResourceProfile(id: "invalid", disabledCategories: [.networking])
        try JSONEncoder().encode(profile).write(to: file)
        XCTAssertThrowsError(try CLISimulatorResourceRuntime.resolveProfile(file.path))
    }
}
