// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Scape",
    platforms: [
        .macOS(.v26),
        .visionOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .executable(name: "ScapeHost", targets: ["ScapeHost"]),
        .executable(name: "ScapeClient", targets: ["ScapeClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/undivisible/miragekit.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "ScapeHost",
            dependencies: [
                .product(name: "MirageKit", package: "MirageKit")
            ],
            path: "ScapeHost",
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "ScapeClient",
            dependencies: [
                .product(name: "MirageKit", package: "MirageKit")
            ],
            path: "ScapeClient",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "ScapeTests",
            dependencies: [
                "ScapeClient",
                "ScapeHost"
            ],
            path: "Tests/ScapeTests"
        )
    ]
)
