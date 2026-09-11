// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "RouteKit",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "RouteKit",
            targets: ["RouteKit"]
        ),
        .library(
            name: "RouteKitMacro",
            targets: ["RouteKitMacro"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "603.0.0")
    ],
    targets: [
        .macro(
            name: "RouteKitMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "RouteKitMacros/Sources/RouteKitMacros"
        ),
        .target(
            name: "RouteKitMacro",
            dependencies: ["RouteKitMacros"],
            path: "RouteKitMacros/Sources/RouteKitMacro"
        ),
        .target(
            name: "RouteKit",
            dependencies: ["RouteKitMacro"]
        ),
        .testTarget(
            name: "RouteKitTests",
            dependencies: ["RouteKit"]
        ),
    ]
)
