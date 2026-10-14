import Darwin
import Foundation
import XCTest
@testable import TritonKitCLI

final class SimulatorResourceReceiptTests: XCTestCase {
    func testReceiptReaderRejectsSymlinksAndOversizedFile() throws {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("receipt.json")
        try Data(repeating: 65, count: 1_048_577).write(to: file)
        XCTAssertThrowsError(try SimulatorResourceReceiptReader.read(file.path))
        let link = directory.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try SimulatorResourceReceiptReader.read(link.path))
        let parentLink = directory.appendingPathComponent("parent")
        try FileManager.default.createSymbolicLink(at: parentLink, withDestinationURL: directory)
        XCTAssertThrowsError(try SimulatorResourceReceiptReader.read(parentLink.appendingPathComponent("receipt.json").path))
    }
}
