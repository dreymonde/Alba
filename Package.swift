// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Alba",
    platforms: [
        .macOS(.v10_12), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)
    ],
    products: [
        .library(name: "Alba", type: .static, targets: ["Alba"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Alba",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "AlbaTests",
            dependencies: ["Alba"]
        )
    ]
)
