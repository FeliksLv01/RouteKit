# Defining Routes

Use patterns, parameters, and priorities to control route matching.

## Pattern syntax

Patterns may be relative when ``RouterConfig/scheme`` is configured, or may include a
scheme explicitly.

| Pattern | Matching URL | Behavior |
| --- | --- | --- |
| `profile/:id` | `myapp://profile/42` | Captures one segment as `id`. |
| `docs/*` | `myapp://docs/readme` | Matches one unnamed segment. |
| `flutter/**` | `myapp://flutter/home/detail` | Matches the remaining segments. |
| `file/:{name}.json` | `myapp://file/report.json` | Captures part of a segment as `name`. |

Captured values are available in ``RouteContext/urlParams``. Query items are merged after
path captures, and explicit parameters supplied by the caller are merged last. Therefore,
explicit parameters override query and path values with the same key.

```swift
let execution = Router.open(
    "profile/42?source=notification",
    params: ["source": "internal"]
)
```

In this example, `id` is `"42"` and `source` is `"internal"`.

## Route priority

Use priority when broad and specific patterns can both match:

```swift
@Route(patterns: [
    .init("profile/*", priority: .low),
    .init("profile/settings", priority: .high),
])
struct ProfileRoute: PageRoute {
    // ...
}
```

RouteKit searches ``RoutePriority/high``, ``RoutePriority/default``, and
``RoutePriority/low`` tables in that order. Priority chooses a handler; if the selected
handler returns `false`, RouteKit does not retry a lower-priority match.

## Custom registration

Use the argument-free `@Route` form when a handler needs to calculate its pattern:

```swift
@Route
struct DynamicRoute: ActionRoute {
    static func register() {
        register(RouteConfiguration.dynamicPattern, priority: .high)
    }

    func handle(with context: RouteContext) async throws -> Bool {
        true
    }
}
```

Custom registration still participates in automatic discovery. Registration runs lazily
once, immediately before RouteKit builds its immutable route tables.

## Normalize routes

Set ``RouterConfig/normalizer`` when registrations and incoming URLs require the same
canonicalization:

```swift
struct LowercaseRouteNormalizer: RouteNormalizer {
    func normalize(_ value: String) -> String {
        value.lowercased()
    }
}

RouterConfig.normalizer = LowercaseRouteNormalizer()
```

The normalizer is applied to both registered patterns and opened URLs.
