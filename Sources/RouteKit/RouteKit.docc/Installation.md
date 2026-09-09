# Installation

Integrate the same RouteKit API with Swift Package Manager or CocoaPods.

## Requirements

- iOS 13 or later
- Mac Catalyst 13 or later
- Swift 6 or later

RouteKit's runtime imports UIKit. Native macOS is not a supported application platform.
The nested macro package has a macOS deployment target only because Swift compiler plugins
run on the build host.

## Swift Package Manager

Add RouteKit as a package dependency in Xcode, or declare it in `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/FeliksLv01/RouteKit.git",
        from: "0.0.1"
    )
]
```

Add the `RouteKit` product to the application target:

```swift
.target(
    name: "MyApp",
    dependencies: ["RouteKit"]
)
```

Swift Package Manager builds the bundled compiler plugin automatically.

## CocoaPods

Add RouteKit to the Podfile:

```ruby
pod 'RouteKit'
```

When RouteKit is published through a private Specs repository, list that source before the
public CocoaPods source:

```ruby
source 'https://github.com/your-organization/Specs.git'
source 'https://cdn.cocoapods.org/'

target 'MyApp' do
  pod 'RouteKit'
end
```

The pod bundles a prebuilt host compiler plugin tracked through Git LFS. Consumers need
Git LFS available when obtaining the repository source. RouteKit is not published to the
public CocoaPods trunk.

## Import the library

Both package managers expose the complete API through one import:

```swift
import RouteKit
```

The `@Route` declaration and implementation are built in. Do not add TKMacros or another
macro package.
