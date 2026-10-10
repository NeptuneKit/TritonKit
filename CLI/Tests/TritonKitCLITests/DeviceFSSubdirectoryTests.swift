import Foundation
import Testing
@testable import TritonKitCLI

@Suite("DeviceFS explicit container relative directory bounds")
struct DeviceFSSubdirectoryTests {
    @Test("combined standard-root shape accepts exact64 depth/exact16384 UTF8 budget, rejects plus1; no filesystem IO")
    func combinedExactBounds() throws {
        let relative = "AppDataContainers/id/Library"
        let home64 = "/" + Array(repeating: "h", count: 56).joined(separator: "/")
        try validateDeviceFSSelectionBudget(homeDirectory: home64, relativeDirectory: relative)
        #expect(throws: (any Error).self) { try validateDeviceFSSelectionBudget(homeDirectory: home64 + "/h", relativeDirectory: relative) }
        let tail = "/Library/Developer/CoreDevice/DeviceFS/device-00000000-0000-0000-0000-000000000000.localized"
        let count = 16384 - 1 - tail.utf8.count - 1 - relative.utf8.count
        let home16384 = "/" + String(repeating: "h", count: count)
        #expect(home16384.utf8.count + tail.utf8.count + 1 + relative.utf8.count == 16384)
        try validateDeviceFSSelectionBudget(homeDirectory: home16384, relativeDirectory: relative)
        #expect(throws: (any Error).self) { try validateDeviceFSSelectionBudget(homeDirectory: home16384 + "h", relativeDirectory: relative) }
    }
    @Test("relative directory keeps original components and exact 32/4096/255 acceptance boundaries")
    func valid() throws {
        let budget4096 = String(repeating: String(repeating: "a", count: 255) + "/", count: 15) + String(repeating: "b", count: 254) + "/c"
        #expect(budget4096.utf8.count == 4096)
        for path in ["Library/Private", "café", "cafe\u{301}", String(repeating: "x", count: 255), Array(repeating: "a", count: 32).joined(separator: "/"), budget4096, "%2e%2e"] {
            let relative = try #require(try deviceFSRelativeDirectory(view: .appDataContainers, containerIdentifier: "private-id", subdirectory: path))
            #expect(Array(relative.utf8) == Array(("AppDataContainers/private-id/" + path).utf8))
        }
    }
    @Test("bad relative scope rejected without normalization or input echo")
    func invalid() throws {
        let budget4097 = String(repeating: String(repeating: "a", count: 255) + "/", count: 16) + "c"
        #expect(budget4097.utf8.count == 4097)
        for path in ["", ".", "..", "/Library", "../escape", "a/../b", "a/./b", "a//b", "a/", "line\nfeed", "tab\t", "nul\0", String(repeating: "é", count: 128), Array(repeating: "a", count: 33).joined(separator: "/"), budget4097] {
            #expect(throws: (any Error).self) { _ = try deviceFSRelativeDirectory(view: .appGroupContainers, containerIdentifier: "private-id", subdirectory: path) }
        }
        for view in DeviceFSView.allCases {
            #expect(throws: (any Error).self) { _ = try deviceFSRelativeDirectory(view: view, containerIdentifier: nil, subdirectory: "Library") }
        }
        #expect(throws: (any Error).self) { _ = try deviceFSRelativeDirectory(view: .mountRoot, containerIdentifier: "private-id", subdirectory: "Library") }
    }
}
