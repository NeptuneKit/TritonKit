import Testing
@testable import TritonKit
import TritonKitShared

@Suite
struct TKCollectionCellRecoveryTests {
    @Test("collection-cell rejection exposes executable opt-in retry and verification")
    func collectionCellRejectionExposesRecoveryContract() {
        let request = TKInputRequest.tap(
            targetOID: 42,
            matchedOID: 42,
            matchedClassName: "UILabel",
            activationStrategy: .ancestor
        )

        #expect(collectionCellHostHIDRetryCommand(for: request, matchedOID: 42) ==
            "triton act tap --ax-oid 42 --strategy ancestor --allow-host-hid-fallback --target <ios-simulator-runtime-target> --json")

        let verification = collectionCellHostHIDVerificationBoundary()
        #expect(verification.required)
        #expect(verification.status == "not-verified")
        #expect(verification.suggestedCommands == [
            "triton verify text-exists <expected-postcondition> --target <ios-simulator-runtime-target> --json",
            "triton wait --text <expected-postcondition> --target <ios-simulator-runtime-target> --json",
            "triton observe current --target <ios-simulator-runtime-target> --json",
        ])
    }
}
