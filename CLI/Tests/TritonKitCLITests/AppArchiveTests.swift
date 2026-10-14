import Foundation
import Testing
@testable import TritonKitCLI

@Suite("App archive safety") struct AppArchiveTests {
    @Test func rejectsTraversalAndLinksBeforeExtraction() throws {
        for name in ["../Escape.app/Info.plist", "/Escape.app/Info.plist", "A.app/./Info.plist", "A.app/a//b", "A.app/*"] {
            #expect(throws: (any Error).self) { try validateAppArchivePath(name) }
        }
        #expect(try validateAppArchivePath("Payload/Demo.app/Info.plist") == ["Payload", "Demo.app", "Info.plist"])
    }
    @Test func scopeCannotMistakeSimulatorForDevice() throws {
        #expect(throws: (any Error).self) { try validateArchivedAppPlatform(["iPhoneSimulator"], scope: "real") }
        #expect(throws: (any Error).self) { try validateArchivedAppPlatform(["iPhoneOS"], scope: "simulator") }
        #expect(throws: (any Error).self) { try validateArchivedAppPlatform([], scope: "real") }
        try validateArchivedAppPlatform(["iPhoneOS"], scope: "real")
        try validateArchivedAppPlatform(["iPhoneSimulator"], scope: "simulator")
    }
    @Test func nonArchivesAreUntouched() throws {
        let value = try prepareHostIOSAppArchive(path: "/a/Demo.app", scope: "simulator")
        #expect(value.appPath == "/a/Demo.app")
        #expect(value.workspace == nil)
    }
    @Test func rejectsMalformedZIP() {
        #expect(throws: (any Error).self) { try parseAppArchiveZIP(Data("not zip".utf8), budget: .init()) }
    }
}
