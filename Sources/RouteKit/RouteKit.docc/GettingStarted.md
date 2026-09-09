# Getting Started

Configure RouteKit and create your first page and action routes.

## Configure the router

Set global configuration during application startup, before calling ``Router`` for the
first time:

```swift
import RouteKit

RouterConfig.scheme = "myapp"
RouterConfig.defaultOpenHandler = { viewController, context in
    navigationController.pushViewController(viewController, animated: true)
}
RouterConfig.unhandledErrorHandler = { error, url in
    logger.error("Route failed: \(String(describing: url)), \(error)")
}
```

``RouterConfig/scheme`` lets callers use a relative string such as `profile/42`. A fully
qualified URL such as `myapp://profile/42` can be opened without a default scheme.

RouteKit freezes ``RouterConfig`` when the first route is resolved or checked. Configure
the scheme, normalizer, interceptors, middleware, and handlers before that point.

## Declare a page route

Conform a type to ``PageRoute`` and annotate it with `@Route`:

```swift
@Route(patterns: [.init("profile/:id")])
struct ProfileRoute: PageRoute {
    func destination(with context: RouteContext) -> UIViewController? {
        guard let id = context.urlParams["id"] as? String else {
            return nil
        }
        return ProfileViewController(id: id)
    }
}
```

The macro synthesizes the route initializer and registration code. RouteKit discovers
annotated handlers automatically the first time routing begins.

The default implementation of ``PageRoute/open(_:context:)`` forwards a non-`nil`
destination to ``RouterConfig/defaultOpenHandler``. Override it when a route needs to
present, replace a navigation stack, or perform another transition.

## Declare an action route

Use ``ActionRoute`` for work that does not require a view controller:

```swift
@Route(patterns: [.init("session/logout")])
struct LogoutRoute: ActionRoute {
    func handle(with context: RouteContext) async throws -> Bool {
        try await session.logout()
        return true
    }
}
```

## Open a route

Await the throwing API when the caller owns error handling:

```swift
let handled = try await Router.open("profile/42")
```

Use the nonthrowing API from synchronous UIKit code:

```swift
let execution = Router.open("session/logout")
let handled = await execution?.result
```

Errors from the nonthrowing API are sent to
``RouterConfig/unhandledErrorHandler``. See <doc:ExecutingRoutes> for execution and
cancellation details.
