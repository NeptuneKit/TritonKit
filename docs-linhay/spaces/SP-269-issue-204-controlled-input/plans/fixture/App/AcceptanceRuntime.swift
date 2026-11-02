#if DEBUG
import Foundation
import TritonKit

enum AcceptanceRuntime {
    static func startIfRequested() {
        // In-process XCTest requires no server. CLI follow-up is explicit opt-in.
        guard ProcessInfo.processInfo.environment["TRITON_ACCEPTANCE_RUNTIME"] == "1" else { return }
        _ = TritonKit.shared.start()
    }
}
#endif
