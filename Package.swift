// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Flux",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .visionOS(.v1),
        .watchOS(.v10),
        .tvOS(.v16),
    ],
    products: [
        .library(
            name: "Flux",
            targets: ["Flux"]
        ),
    ],
    targets: [
        .target(
            name: "Flux"
        ),
        .testTarget(
            name: "FluxTests",
            dependencies: ["Flux"]
        ),
    ]
)
