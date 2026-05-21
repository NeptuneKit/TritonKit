// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TritonKit",
    platforms: [.iOS(.v13), .macOS(.v14)],
    products: [
        .library(name: "TritonKitShared", targets: ["TritonKitShared"]),
        .library(name: "TritonKit", targets: ["TritonKit"]),
    ],
    dependencies: [],
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
        .testTarget(
            name: "TritonKitSharedTests",
            dependencies: ["TritonKitShared"],
            path: "Tests/TritonKitSharedTests"
        ),
        .testTarget(
            name: "TritonKitTests",
            dependencies: ["TritonKit"],
            path: "Tests/TritonKitTests"
        ),
    ]
)
