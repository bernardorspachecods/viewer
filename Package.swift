// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "viewer",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Viewer", targets: ["ViewerApp"]),
        .library(name: "ViewerCore", targets: ["ViewerCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.6.0")
    ],
    targets: [
        .target(
            name: "ViewerCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            exclude: ["MAP.md"]
        ),
        .executableTarget(
            name: "ViewerApp",
            dependencies: ["ViewerCore"]
        ),
        .testTarget(
            name: "ViewerAppTests",
            dependencies: [
                "ViewerApp",
                "ViewerCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
        .executableTarget(
            name: "ViewerContractRunner",
            dependencies: ["ViewerCore"]
        ),
        .executableTarget(
            name: "ViewerFoundationRunner",
            dependencies: ["ViewerCore"]
        ),
        .executableTarget(
            name: "ViewerTabPrototype",
            dependencies: []
        ),
        .executableTarget(
            name: "ViewerWindowTabPrototype",
            dependencies: []
        )
    ]
)
