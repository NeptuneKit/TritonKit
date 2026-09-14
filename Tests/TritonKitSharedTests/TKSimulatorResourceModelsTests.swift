import XCTest
@testable import TritonKitShared
final class TKSimulatorResourceModelsTests: XCTestCase {
 func testProfileRoundTripAndValidation() throws { let p=TKSimulatorResourceProfile(id:"ci", disabledCategories:[.store,.push]); let d=try JSONEncoder().encode(p); XCTAssertEqual(try JSONDecoder().decode(TKSimulatorResourceProfile.self,from:d),p); XCTAssertNoThrow(try p.validate()); XCTAssertThrowsError(try TKSimulatorResourceProfile(id:"").validate()) }
 func testStatusAndMeasurementCodable() throws { let s=TKSimulatorResourceStatus(udid:"u",runtime:"iOS-18",enabled:true,disabledCategories:[.web]); XCTAssertEqual(try JSONDecoder().decode(TKSimulatorResourceStatus.self,from: JSONEncoder().encode(s)),s); let m=TKSimulatorResourceMeasurement(udid:"u",memoryBytes:42,processCount:3); XCTAssertEqual(try JSONDecoder().decode(TKSimulatorResourceMeasurement.self,from: JSONEncoder().encode(m)),m) }
}
