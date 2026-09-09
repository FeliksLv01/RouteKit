# Interceptors and Middleware

Transform requests before matching and wrap behavior around matched routes.

## Intercept URLs

A ``RouteURLInterceptor`` runs before route matching. It can continue, rewrite, handle, or
reject a request:

```swift
struct LegacyURLInterceptor: RouteURLInterceptor {
    func intercept(_ request: RouteURLRequest) -> RouteURLInterceptResult {
        guard request.url.host == "old-profile" else {
            return .proceed
        }

        let id = request.url.lastPathComponent
        return .rewrite(URL(string: "myapp://profile/\(id)")!)
    }
}

RouterConfig.urlInterceptors = [LegacyURLInterceptor()]
```

Interceptors execute in array order. A rewrite restarts the interceptor chain with the new
URL. RouteKit limits repeated rewrites and reports
``RouteError/tooManyURLInterceptorRewrites(_:)`` when the chain does not converge.

When ``RouteURLRequest/isDryRun`` is `true`, the request originated from
``Router/canOpen(_:)``. An interceptor should calculate the same result without navigation,
analytics, authentication prompts, or other side effects.

## Wrap route execution

A ``RouteMiddleware`` runs after matching and can perform work before and after the next
responder:

```swift
struct AnalyticsMiddleware: RouteMiddleware {
    func respond(
        to request: RouteRequest,
        chainingTo next: any RouteResponder
    ) async throws -> RouteResponse {
        analytics.begin(request.context.url)
        let response = try await next.respond(to: request)
        analytics.end(request.context.url, handled: response.handled)
        return response
    }
}

RouterConfig.middlewares = [AnalyticsMiddleware()]
```

Global middleware runs before route-specific middleware. Within each array, the first item
is the outermost responder: it receives the request first and the response last.

Declare route-specific middleware on a handler type:

```swift
@Route(patterns: [.init("account/security")])
struct SecurityRoute: PageRoute {
    static var middlewares: [any RouteMiddleware] {
        [AuthenticationMiddleware()]
    }

    // ...
}
```

A middleware can stop the chain by returning ``RouteResponse`` without calling `next`.
Throwing an error follows the error behavior described in <doc:ExecutingRoutes>.
