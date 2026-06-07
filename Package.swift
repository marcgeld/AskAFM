// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "askafm",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.8.0"
        ),
        .package(
            url: "https://github.com/LebJe/TOMLKit.git",
            from: "0.6.0"
        )
    ],
    targets: [
        .target(
            name: "core"
        ),
        .executableTarget(
            name: "askafm",
            dependencies: [
                "core",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
                .product(
                    name: "TOMLKit",
                    package: "TOMLKit"
                ),
            ]
        ),
        .testTarget(
            name: "askafmTests",
            dependencies: ["askafm"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
