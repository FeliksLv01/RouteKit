// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "RouteKitMacrosPackage",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "RouteKitMacro",
      targets: ["RouteKitMacro"]
    )
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
      ]
    ),
    .target(
      name: "RouteKitMacro",
      dependencies: ["RouteKitMacros"]
    ),
    .testTarget(
      name: "RouteKitMacrosTests",
      dependencies: [
        "RouteKitMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ]
)
