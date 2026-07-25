// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TKRouter",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13),
    ],
    products: [
        .library(
            name: "TKRouter",
            targets: ["TKRouter"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/TokenTeamiOS/TKMacros.git",
            from: "0.0.4"
        )
    ],
    targets: [
        .target(
            name: "TKRouter",
            dependencies: [
                .product(name: "TKMacros", package: "TKMacros")
            ]
        ),
        .testTarget(
            name: "TKRouterTests",
            dependencies: ["TKRouter"]
        ),
    ]
)
