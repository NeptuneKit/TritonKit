// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "TritonKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "TritonKit", targets: ["TritonKit"]),
    ],
    targets: [
        .target(
            name: "TritonKit",
            path: "Sources/TritonKit"
        ),
    ]
)
