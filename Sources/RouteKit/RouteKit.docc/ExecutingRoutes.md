# Executing Routes

Choose between a throwing async API and a nonthrowing execution handle.

## Await completion

The async overload waits for interceptors, middleware, and the selected handler:

```swift
do {
    let handled = try await Router.open("checkout/confirm")
    if !handled {
        // The selected route declined the request.
    }
} catch {
    // Resolution, middleware, or action-route failure.
}
```

It throws ``RouteError`` for invalid URLs, missing schemes, registration failures, missing
routes, and excessive interceptor rewrites. Errors thrown by middleware and
``ActionRoute/handle(with:)`` also propagate to the caller.

## Start from synchronous code

The nonthrowing overload starts routing and returns a ``RouteExecution``:

```swift
guard let execution = Router.open("checkout/confirm") else {
    return
}

Task {
    let handled = await execution.result
}
```

Page routes without middleware can complete immediately. Action routes and middleware
chains continue asynchronously. In both cases, ``RouteExecution/result`` returns the final
handled state.

Resolution or immediate execution errors make the method return `nil`. Later asynchronous
errors produce `false`. RouteKit sends both kinds of errors to
``RouterConfig/unhandledErrorHandler``.

## Cancel work

Keep the execution handle when the caller's lifetime should control an asynchronous route:

```swift
private var routeExecution: RouteExecution?

func startRoute() {
    routeExecution = Router.open("search/refresh")
}

func stopRoute() {
    routeExecution?.cancel()
    routeExecution = nil
}
```

``RouteExecution/cancel()`` cancels the underlying task. Action routes and middleware
should use cancellation-aware async APIs or call `Task.checkCancellation()` during long
operations. Cancellation resolves the nonthrowing execution as `false`.

## Check availability

Use ``Router/canOpen(_:)`` to check whether a URL can resolve:

```swift
if Router.canOpen("profile/42") {
    Router.open("profile/42")
}
```

This is a dry run. URL interceptors are invoked with ``RouteURLRequest/isDryRun`` set to
`true`, so they should avoid side effects during availability checks.
