import Foundation
import Testing
@testable import TritonKit

@Suite
struct TKRuntimeInputActionTargetSafetyTests {
    @Test("control action target introspection is limited to NSObject-backed targets")
    func controlActionTargetIntrospectionIsLimitedToNSObjectBackedTargets() {
        #expect(isSafeControlActionTarget(nil))
        #expect(isSafeControlActionTarget(NSObject()))
        #expect(!isSafeControlActionTarget(SwiftOnlyControlSubscription()))
    }
}

private final class SwiftOnlyControlSubscription {}
