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
