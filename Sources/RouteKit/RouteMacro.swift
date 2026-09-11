/// Describes a route pattern registered by the `@Route` macro.
public struct RoutePattern: Sendable {
  /// The priority encoded in a macro route declaration.
  public enum Priority: Sendable {
    /// Matches after default- and high-priority patterns.
    case low
    /// The standard pattern priority.
    case `default`
    /// Matches before default- and low-priority patterns.
    case high
  }

  /// The route path pattern.
  public let pattern: String
  /// The matching priority of the pattern.
  public let priority: Priority

  /// Creates a macro route pattern.
  /// - Parameters:
  ///   - pattern: The path pattern to register.
  ///   - priority: The matching priority of the pattern.
  public init(_ pattern: String, priority: Priority = .default) {
    self.pattern = pattern
    self.priority = priority
  }
}

/// Registers a route handler for automatic runtime discovery.
///
/// Supplying patterns generates `static func register()`. Use `@Route` without
/// arguments when the route provides its own registration implementation.
///
/// - Parameter patterns: The path patterns registered for the annotated handler.
@attached(
  member,
  names: named(init), named(register), named(_routekit_route_item), named(_routekit_route_type_check)
)
public macro Route(
  patterns: [RoutePattern]
) = #externalMacro(module: "RouteKitMacros", type: "RouteMacro")

/// Marks a route handler that provides a custom `static func register()` implementation.
@attached(member, names: named(init), named(_routekit_route_item), named(_routekit_route_type_check))
public macro Route() = #externalMacro(module: "RouteKitMacros", type: "RouteMacro")
