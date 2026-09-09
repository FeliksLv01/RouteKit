/// Describes a route pattern registered by the `@Route` macro.
public struct RoutePattern: Sendable {
  public enum Priority: Sendable {
    case low
    case `default`
    case high
  }

  public let pattern: String
  public let priority: Priority

  public init(_ pattern: String, priority: Priority = .default) {
    self.pattern = pattern
    self.priority = priority
  }
}

/// Registers a route handler for automatic runtime discovery.
///
/// Supplying patterns generates `static func register()`. Use `@Route` without
/// arguments when the route provides its own registration implementation.
@attached(
  member,
  names: named(init), named(register), named(_routekit_route_item), named(_routekit_route_type_check)
)
public macro Route(
  patterns: [RoutePattern]
) = #externalMacro(module: "RouteKitMacros", type: "RouteMacro")

@attached(member, names: named(init), named(_routekit_route_item), named(_routekit_route_type_check))
public macro Route() = #externalMacro(module: "RouteKitMacros", type: "RouteMacro")
