// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TritonIOSRunnerProtocol",
    platforms: [.macOS(.v13)],
    products: [.library(name: "RunnerProtocol", targets: ["RunnerProtocol"])],
    targets: [
        .target(name: "RunnerProtocol", path: "RunnerTests", exclude: ["TritonIOSRunnerTests.swift"], sources: ["HTTPProtocol.swift", "RunnerServer.swift", "SecureChannel.swift"]),
        .testTarget(name: "RunnerProtocolTests", dependencies: ["RunnerProtocol"], path: "ProtocolTests"),
    ]
)
