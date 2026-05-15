// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TritonKit",
    platforms: [.iOS(.v13), .macOS(.v14)],
    products: [
        .library(name: "TritonKit", targets: ["TritonKit"]),
        .executable(name: "tritonkit", targets: ["TritonKitCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "TritonKitShared",
            path: "Sources/TritonKitShared"
        ),
        .target(
            name: "TritonKit",
            dependencies: ["TritonKitShared"],
            path: "Sources/TritonKit"
        ),
        .executableTarget(
            name: "TritonKitCLI",
            dependencies: [
                "TritonKitShared",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/TritonKitCLI"
        ),
    ]
)
