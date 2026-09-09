# ``RouteKit``

Build declarative URL routing for UIKit applications with automatic macro registration.

## Overview

RouteKit maps URLs to page destinations or asynchronous actions. Declare a handler with
`@Route`, configure the router once during application startup, and open routes through
``Router``.

```swift
import RouteKit
import UIKit

RouterConfig.scheme = "myapp"

@Route(patterns: [.init("profile/:id")])
struct ProfileRoute: PageRoute {
    func destination(with context: RouteContext) -> UIViewController? {
        guard let id = context.urlParams["id"] as? String else {
            return nil
        }
        return ProfileViewController(id: id)
    }
}

Router.open("profile/42")
```

The package includes the macro declaration and compiler plugin. Applications only import
`RouteKit`; there is no separate macro dependency.

> Important: RouteKit supports iOS 13 and Mac Catalyst 13 or later. Its page-routing API
> uses UIKit and does not support native macOS applications.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:DefiningRoutes>
- <doc:ExecutingRoutes>

### Request Pipeline

- <doc:InterceptorsAndMiddleware>

### Distribution

- <doc:Installation>

### Core API

- ``Route(patterns:)``
- ``Route()``
- ``RoutePattern``
- ``Router``
- ``RouterConfig``
- ``RouteContext``
- ``RouteExecution``
- ``PageRoute``
- ``ActionRoute``
