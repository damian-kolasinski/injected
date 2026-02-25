// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Injected",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "Injected",
            targets: ["Injected"]
        ),
    ],
    targets: [
        .target(name: "Injected"),
        .testTarget(
            name: "InjectedTests",
            dependencies: ["Injected"]
        ),
    ]
)
