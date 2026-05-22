// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TritonKitCLI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "triton", targets: ["TritonKitCLI"]),
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "TritonKitCLI",
            dependencies: [
                .product(name: "TritonKitShared", package: "tritonkit"),
                .product(name: "TritonKit", package: "tritonkit"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "TritonKitCLITests",
            dependencies: ["TritonKitCLI"]
        ),
    ]
)
