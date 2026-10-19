import XCTest
import TritonKitShared
@testable import TritonKitCLI

#if os(macOS)
final class SimulatorAXGeometryTests: XCTestCase {
    func testMissingDeviceGeometryFailsClosedWithoutUnknownKVC() {
        XCTAssertThrowsError(try AXPTranslatorAccessibility.devicePointSize(for: NSObject()))
    }

    func testInvalidRootGeometryFailsClosed() {
        for root in [CGRect.zero, CGRect(x: CGFloat.infinity, y: 0, width: 20, height: 30), CGRect(x: 0, y: 0, width: -1, height: 30)] {
            XCTAssertThrowsError(try AXFrameTransform(rootFrame: root, pointSize: CGSize(width: 390, height: 844)))
        }
    }

    func testInvalidPointGeometryFailsClosed() {
        for size in [CGSize.zero, CGSize(width: CGFloat.nan, height: 20), CGSize(width: 20, height: CGFloat.infinity), CGSize(width: -1, height: 20)] {
            XCTAssertThrowsError(try AXFrameTransform(rootFrame: CGRect(x: 0, y: 0, width: 200, height: 400), pointSize: size))
        }
    }
}
#endif

#if os(macOS)
private final class GeometryDeviceFixture: NSObject {
    @objc var deviceType: NSObject?
    init(_ type: NSObject?) { deviceType = type }
}
private final class GeometryTypeFixture: NSObject {
    @objc var mainScreenSize: NSValue
    @objc var mainScreenScale: NSNumber?
    init(_ size: CGSize, _ scale: Double?) {
        mainScreenSize = NSValue(size: size)
        mainScreenScale = scale.map(NSNumber.init(value:))
    }
}
extension SimulatorAXGeometryTests {
    func testDeviceMetadataRequiresFinitePositiveSizeAndScale() {
        for scale in [nil, 0, -1, Double.nan, Double.infinity] as [Double?] {
            XCTAssertThrowsError(try AXPTranslatorAccessibility.devicePointSize(for: GeometryDeviceFixture(GeometryTypeFixture(CGSize(width: 1179, height: 2556), scale))))
        }
        for size in [CGSize.zero, CGSize(width: -1, height: 20), CGSize(width: CGFloat.infinity, height: 20), CGSize(width: 20, height: CGFloat.nan)] {
            XCTAssertThrowsError(try AXPTranslatorAccessibility.devicePointSize(for: GeometryDeviceFixture(GeometryTypeFixture(size, 3))))
        }
        XCTAssertThrowsError(try AXPTranslatorAccessibility.devicePointSize(for: GeometryDeviceFixture(NSObject())))
    }

    func testValidDifferentDeviceRatiosAndRoundTrip() throws {
        for pair in [(CGSize(width: 1179, height: 2556), 3.0), (CGSize(width: 2048, height: 2732), 2.0)] {
            let size = try AXPTranslatorAccessibility.devicePointSize(for: GeometryDeviceFixture(GeometryTypeFixture(pair.0, pair.1)))
            XCTAssertEqual(size.width, pair.0.width / pair.1)
            let transform = try AXFrameTransform(rootFrame: CGRect(x: 100, y: 80, width: 300, height: 600), pointSize: size)
            let frame = CGRect(x: 140, y: 120, width: 30, height: 40)
            let point = try transform.unmap(transform.map(frame).origin)
            XCTAssertEqual(point.x, frame.minX, accuracy: 0.00001)
            XCTAssertEqual(point.y, frame.minY, accuracy: 0.00001)
        }
    }

    func testExpiredBudgetReturnsPartialWithoutReadingUnknownProperties() throws {
        let collector = CLIObservationTreeCollector(budget: .init(timeoutSeconds: 0))
        XCTAssertNil(try AXPTranslatorAccessibility.geometryTransform(device: NSObject(), root: NSObject(), collector: collector))
        XCTAssertEqual(collector.summary.limitReasons, ["deadline"])
    }

    func testDeadlineExpiresDuringGeometryReadPreservesPartial() throws {
        var clock = 0.0
        let collector = CLIObservationTreeCollector(budget: .init(timeoutSeconds: 1), now: { clock })
        let device = ExpiringGeometryDeviceFixture { clock = 2 }
        XCTAssertNil(try AXPTranslatorAccessibility.geometryTransform(device: device, root: NSObject(), collector: collector))
        XCTAssertEqual(collector.summary.limitReasons, ["deadline"])
    }

    func testInvalidChildAndOverflowFailClosed() throws {
        let transform = try AXFrameTransform(rootFrame: CGRect(x: 0, y: 0, width: 10, height: 20), pointSize: CGSize(width: 100, height: 200))
        for frame in [CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), CGRect(x: 0, y: 0, width: -1, height: 1), CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0, width: 1, height: 1)] {
            XCTAssertThrowsError(try transform.map(frame))
        }
        XCTAssertThrowsError(try transform.unmap(CGPoint(x: CGFloat.infinity, y: 0)))
    }

    func testProductionPressBoundaryNeverSubmitsInvalidGeometry() throws {
        var submissions = 0
        for invalidContext in [true, false] {
            XCTAssertThrowsError(try AXPTranslatorAccessibility.submitValidatedPress(target: "fixture", select: { () throws -> CGRect? in
                let transform = try AXFrameTransform(rootFrame: invalidContext ? .zero : CGRect(x: 0, y: 0, width: 100, height: 200), pointSize: CGSize(width: 390, height: 844))
                return try transform.map(CGRect(x: CGFloat.nan, y: 0, width: 10, height: 20))
            }, submit: { _ in submissions += 1; return true }))
        }
        XCTAssertEqual(submissions, 0)
        _ = try AXPTranslatorAccessibility.submitValidatedPress(target: "fixture", select: { () throws -> CGRect? in
            let transform = try AXFrameTransform(rootFrame: CGRect(x: 0, y: 0, width: 100, height: 200), pointSize: CGSize(width: 390, height: 844))
            return try transform.map(CGRect(x: 0, y: 0, width: 10, height: 20))
        }, submit: { _ in submissions += 1; return true })
        XCTAssertEqual(submissions, 1)
    }

    func testGeometryFailureHasStableMachineReadableDetail() throws {
        let detail = cliErrorDetail(for: HostSimulatorAXError.geometryUnavailable, endpoint: "sim.ax", host: "127.0.0.1", port: 19421)
        let envelope = try encodeJSON(TKCLIErrorResponse(error: detail, surface: "sim.ax"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(envelope.utf8)) as? [String: Any])
        XCTAssertEqual(object["ok"] as? Bool, false)
        let error = try XCTUnwrap(object["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? String, "ios_host_ax_geometry_unavailable")
        XCTAssertNotNil(error["hint"])
        XCTAssertNotNil(error["nextAction"])
        let encoded = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(TKCLIErrorDetail.self, from: encoded)
        XCTAssertEqual(decoded, detail)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(detail.code, "ios_host_ax_geometry_unavailable")
        XCTAssertNotNil(detail.nextAction)
        XCTAssertNotNil(detail.hint)
        XCTAssertFalse(detail.suggestedCommands?.isEmpty ?? true)
    }
}
#endif

#if os(macOS)
private final class ExpiringGeometryDeviceFixture: NSObject {
    let expire: () -> Void
    init(_ expire: @escaping () -> Void) { self.expire = expire }
    @objc var deviceType: NSObject? { expire(); return NSObject() }
}
#endif
