import Foundation
import Testing
@testable import TritonKitShared

@Suite("Temporary domain is a potentially creating request")
struct TKTemporaryDomainPolicyTests {
    @Test func requiresExplicitPolicy() throws {
        #expect(throws: TKDevicectlFilesError.temporaryRequiresPolicy) {
            try TKDevicectlFilesRequest(domain: "temporary", domainIdentifier: "fixture")
        }
        let request = try TKDevicectlFilesRequest(domain: "temporary", domainIdentifier: "fixture", allowTemporaryCreation: true)
        #expect(request.domain == "temporary")
        let command = TKDevicectlCommand.deviceInfoFiles(identifier: "fixture", request: request, jsonOutput: "/json", logOutput: "/log")
        #expect(command.riskLevel == .automation)
        #expect(command.requiredConfig.contains(.auditRecord))
        #expect(throws: TKDevicectlFilesError.invalidRequest) {
            try TKDevicectlFilesRequest(domain: "temporary", allowTemporaryCreation: true)
        }
    }
}
