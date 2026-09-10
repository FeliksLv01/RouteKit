# RouteKit

[简体中文](README.zh-CN.md)

RouteKit is a standalone Swift URL router with built-in macro registration, path parameters, route priorities, URL interceptors, middleware, and synchronous and asynchronous execution APIs.

## Documentation

- [Online documentation](https://felikslv01.github.io/RouteKit/documentation/routekit/)
- [Getting Started](Sources/RouteKit/RouteKit.docc/GettingStarted.md)
- [Defining Routes](Sources/RouteKit/RouteKit.docc/DefiningRoutes.md)
- [Executing Routes](Sources/RouteKit/RouteKit.docc/ExecutingRoutes.md)
- [Interceptors and Middleware](Sources/RouteKit/RouteKit.docc/InterceptorsAndMiddleware.md)
- [Installation](Sources/RouteKit/RouteKit.docc/Installation.md)
- [DocC landing page](Sources/RouteKit/RouteKit.docc/RouteKit.md)

The README is a practical overview. The DocC catalog contains the complete guides and generated API reference. Read it online through GitHub Pages, or open the package in Xcode and choose **Product > Build Documentation**.

## Requirements

- iOS 13.0+
- Mac Catalyst 13.0+
- Swift 6.0+

RouteKit's page-routing API depends on UIKit and does not support macOS. The macOS deployment target declared by the internal `Macros` package applies only to the Swift compiler plugin.

## Swift Package Manager

Add RouteKit in Xcode under Package Dependencies, or declare it in `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/FeliksLv01/RouteKit.git",
        from: "0.0.1"
    )
]
```

Then add the `RouteKit` library product to your iOS target. SwiftPM builds the bundled macro target automatically.

## CocoaPods

```ruby
pod 'RouteKit'
```

If your private Specs repository contains `RouteKit`, place that source before the public Specs source in your Podfile.

Both package managers expose the complete API through one import:

```swift
import RouteKit
```

The `@Route` declaration, implementation, and prebuilt CocoaPods compiler plugin are bundled with RouteKit. TKMacros is not required.

## Configuration

Configure the default URL scheme and page-opening behavior before the first call to `Router.open` or `Router.canOpen`:

```swift
RouterConfig.scheme = "myapp"
RouterConfig.defaultOpenHandler = { viewController, context in
    navigationController.pushViewController(viewController, animated: true)
}
```

The configuration is frozen after routing begins.

## Page routes

```swift
import RouteKit
import UIKit

@Route(patterns: [
    .init("profile/:id"),
    .init("profile/settings", priority: .high),
])
struct ProfileRoute: PageRoute {
    func destination(with context: RouteContext) -> UIViewController? {
        guard let id = context.urlParams["id"] as? String else {
            return nil
        }
        return ProfileViewController(id: id)
    }
}
```

`@Route` generates `static func register()` and places the route type in `__DATA_CONST,__routekit`. RouteKit scans that section and registers routes lazily on first use.

## Action routes

```swift
@Route(patterns: [
    .init("session/logout")
])
struct LogoutRoute: ActionRoute {
    func handle(with context: RouteContext) async throws -> Bool {
        await session.logout()
        return true
    }
}
```

The synchronous entry point returns a `RouteExecution` immediately:

```swift
let execution = Router.open("session/logout")
let handled = await execution?.result
execution?.cancel()
```

The asynchronous entry point waits for completion:

```swift
let handled = try await Router.open("session/logout")
```

## Patterns

With `RouterConfig.scheme = "myapp"`:

| Pattern | Example | Description |
| --- | --- | --- |
| `profile/:id` | `myapp://profile/42` | Named parameter |
| `docs/*` | `myapp://docs/readme` | Single-segment wildcard |
| `flutter/**` | `myapp://flutter/home/detail` | Multi-segment catch-all |
| `file/:{name}.json` | `myapp://file/report.json` | Partial parameter |

Parameters passed explicitly to `Router.open(_:params:)` override URL query and path parameters with the same key.

## Priority

```swift
@Route(patterns: [
    .init("profile/*", priority: .low),
    .init("profile/settings", priority: .high),
])
```

Routes are matched in `high`, `default`, then `low` priority order. Priority affects selection only; RouteKit does not fall back to a lower-priority handler when the selected handler returns `false`.

## Custom registration

Use the argument-free macro when a route needs a dynamic pattern:

```swift
@Route
struct DynamicRoute: ActionRoute {
    static func register() {
        register(RouteConfiguration.dynamicPattern)
    }

    func handle(with context: RouteContext) async throws -> Bool {
        true
    }
}
```

## Interceptors and middleware

`RouteURLInterceptor` runs before route matching and may rewrite, handle, or reject a URL. `RouteMiddleware` runs after matching and can wrap the global or route-specific responder chain.

```swift
RouterConfig.urlInterceptors = [LegacyURLInterceptor()]
RouterConfig.middlewares = [AnalyticsMiddleware()]
```

Individual routes may declare middleware through `static var middlewares`.

## License

RouteKit is available under the MIT license.
