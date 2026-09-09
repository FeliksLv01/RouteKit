import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
public struct RouteKitPlugin: CompilerPlugin {
  public init() {}

  public let providingMacros: [Macro.Type] = [
    RouteMacro.self
  ]
}
