import Foundation
import TritonKitShared

struct XcodeUseOutput: Encodable {
    let ok: Bool
    let action: String
    let defaultsPath: String
    let defaults: TKHostWorkspaceDefaults
}

struct XcodeSchemesOutput: Encodable {
    let ok: Bool
    let workspace: String?
    let project: String?
    let schemes: [String]
    let sourceCommand: String
}

struct ResolvedXcodeInvocation: Encodable {
    let workspace: String?
    let project: String?
    let scheme: String
    let configuration: String
    let sdk: String?
    let destination: String?
    let derivedDataPath: String?
    let simulatorUDID: String?
}

struct XcodeSettingsOutput: Encodable {
    let ok: Bool
    let invocation: ResolvedXcodeInvocation
    let product: TKXcodeBuiltAppProduct
    let sourceCommand: String
    let stdoutLogPath: String?
    let stderrLogPath: String?
    let stdoutBytes: Int?
    let stderrBytes: Int?
}
