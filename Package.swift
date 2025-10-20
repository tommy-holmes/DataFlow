// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DataFlow",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .visionOS(.v1),
        .watchOS(.v10),
        .tvOS(.v16),
    ],
    products: [
        .library(
            name: "DataFlow",
            targets: ["DataFlow"]
        ),
    ],
    targets: [
        .target(
            name: "DataFlow"
        ),
        .testTarget(
            name: "DataFlowTests",
            dependencies: ["DataFlow"]
        ),
    ]
)
