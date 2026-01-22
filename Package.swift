// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "URNComponents",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "URNComponents",
            targets: ["URNComponents"]
        ),
    ],
    targets: [
        .target(
            name: "URNComponents"
        ),
        .testTarget(
            name: "URNComponentsTests",
            dependencies: ["URNComponents"]
        ),
    ]
)
