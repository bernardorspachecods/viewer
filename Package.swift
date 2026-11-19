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
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.6.0"),
        .package(
            url: "https://github.com/nodes-app/swift-markdown-engine",
            revision: "ca0d9798b0e18a590840b366295f5a686c9c3daf"
        )
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
            dependencies: [
                "ViewerCore",
                .product(name: "MarkdownEngine", package: "swift-markdown-engine"),
                .product(name: "MarkdownEngineCodeBlocks", package: "swift-markdown-engine"),
                .product(name: "MarkdownEngineLatex", package: "swift-markdown-engine")
            ]
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
