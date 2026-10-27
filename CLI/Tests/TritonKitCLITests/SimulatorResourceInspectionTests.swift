import XCTest
@testable import TritonKitCLI

final class SimulatorResourceInspectionTests: XCTestCase {
    func testStatusDoesNotCountUnmanagedServicesOrEnabledOverrides() throws {
        let inspector = SimulatorResourceInspection(read: { _ in
            .init(overrides: ["com.apple.apsd": true, "com.apple.storekitd": false, "custom.service": true])
        })
        let status = try inspector.status(udid: "fixture")
        XCTAssertEqual(status["managedDisabled"] as? Int, 1)
        XCTAssertEqual(status["disabledLabels"] as? [String], ["com.apple.apsd"])
    }

    func testDoctorReportsDisabledPushWithoutClaimingBusinessVerification() throws {
        let inspector = SimulatorResourceInspection(read: { _ in .init(overrides: ["com.apple.apsd": true]) })
        let report = try inspector.doctor(udid: "fixture", requires: ["push"])
        XCTAssertEqual(report["ok"] as? Bool, false)
        XCTAssertEqual(report["verificationBoundary"] as? String, "service-overrides-only")
    }

    func testWidgetsDoctorChecksNavigationDependency() throws {
        let inspector = SimulatorResourceInspection(read: { _ in .init(overrides: ["com.apple.navd": true]) })
        let report = try inspector.doctor(udid: "fixture", requires: ["widgets"])
        XCTAssertEqual(report["ok"] as? Bool, false)
        let features = report["features"] as? [[String: Any]]
        XCTAssertEqual(features?.first?["disabledLabels"] as? [String], ["com.apple.navd"])
    }

    func testFilesRecentsReportsOnlyDisabledSearchd() throws {
        let inspector = SimulatorResourceInspection(read: { _ in
            .init(overrides: ["com.apple.searchd": true, "com.apple.searchtoold": true])
        })
        let report = try inspector.doctor(udid: "fixture", requires: ["files-recents"])
        XCTAssertEqual(report["ok"] as? Bool, false)
        XCTAssertEqual(report["verificationBoundary"] as? String, "service-overrides-only")
        let features = try XCTUnwrap(report["features"] as? [[String: Any]])
        XCTAssertEqual(features.count, 1)
        XCTAssertEqual(features.first?["id"] as? String, "files-recents")
        XCTAssertEqual(features.first?["disabledLabels"] as? [String], ["com.apple.searchd"])
    }

    func testFilesRecentsDoesNotRequireSearchtoold() throws {
        let inspector = SimulatorResourceInspection(read: { _ in
            .init(overrides: ["com.apple.searchd": false, "com.apple.searchtoold": true])
        })
        let report = try inspector.doctor(udid: "fixture", requires: ["files-recents", "spotlight"])
        XCTAssertEqual(report["ok"] as? Bool, false)
        XCTAssertEqual(report["verificationBoundary"] as? String, "service-overrides-only")
        let features = try XCTUnwrap(report["features"] as? [[String: Any]])
        XCTAssertEqual(features.count, 2)
        XCTAssertEqual(features[0]["ok"] as? Bool, true)
        XCTAssertEqual(features[0]["disabledLabels"] as? [String], [])
        XCTAssertEqual(features[1]["ok"] as? Bool, false)
        XCTAssertEqual(features[1]["disabledLabels"] as? [String], ["com.apple.searchtoold"])
    }

    func testFilesRecentsKeepsMissingOverrideMeaning() throws {
        let inspector = SimulatorResourceInspection(read: { _ in .init(overrides: [:]) })
        let report = try inspector.doctor(udid: "fixture", requires: ["files-recents"])
        XCTAssertEqual(report["ok"] as? Bool, true)
        XCTAssertEqual(report["verificationBoundary"] as? String, "service-overrides-only")
        let features = try XCTUnwrap(report["features"] as? [[String: Any]])
        XCTAssertEqual(features.first?["disabledLabels"] as? [String], [])
    }

    func testInvalidRequirementsFailBeforeDeviceRead() {
        let inspector = SimulatorResourceInspection(read: { _ in XCTFail("unexpected device read"); return .init(overrides: [:]) })
        XCTAssertThrowsError(try inspector.doctor(udid: "fixture", requires: ["unknown"]))
        XCTAssertThrowsError(try inspector.doctor(udid: "fixture", requires: []))
    }

    func testReadFailureIsNotReportedAsStock() {
        let inspector = SimulatorResourceInspection(read: { _ in throw SimulatorResourceOverrideState.ParseError.malformedOutput })
        XCTAssertThrowsError(try inspector.status(udid: "fixture"))
        XCTAssertThrowsError(try inspector.doctor(udid: "fixture", requires: ["push"]))
    }
}
