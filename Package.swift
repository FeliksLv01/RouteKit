// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RouteKit",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13),
    ],
    products: [
        .library(
            name: "RouteKit",
            targets: ["RouteKit"]
        )
    ],
    dependencies: [
        .package(path: "RouteKitMacros")
    ],
    targets: [
        .target(
            name: "RouteKit",
            dependencies: [
                .product(name: "RouteKitMacro", package: "routekitmacros")
            ]
        ),
        .testTarget(
            name: "RouteKitTests",
            dependencies: ["RouteKit"]
        ),
    ]
)
