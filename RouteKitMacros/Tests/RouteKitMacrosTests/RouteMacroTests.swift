import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import RouteKitMacros
import XCTest

final class RouteMacroTests: XCTestCase {
    private let testMacros: [String: Macro.Type] = [
      "Route": RouteMacro.self
    ]

    func testRouteGeneratesRegisterMethodForPatterns() throws {
      assertMacroExpansion(
        """
        @Route(patterns: [
            .init("profile"),
            .init("profile/settings", priority: .high),
        ])
        struct ProfileRoute: PageRoute {
        }
        """,
        expandedSource: """
          struct ProfileRoute: PageRoute {

              static func register() {
                  register("profile")
                  register("profile/settings", priority: .high)
              }

              @section("__DATA_CONST,__routekit")
              @used
              private static let _routekit_route_item: @convention(c) () -> UnsafeRawPointer = {
                  unsafeBitCast(ProfileRoute.self, to: UnsafeRawPointer.self)
              }

              private static let _routekit_route_type_check: any RouteHandler.Type = ProfileRoute.self
          }
          """,
        macros: testMacros
      )
    }

    func testRouteWithoutPatternsKeepsCustomRegistration() throws {
      assertMacroExpansion(
        """
        @Route
        final class ProfileRoute: PageRoute {
            static func register() {
                register("profile")
            }
        }
        """,
        expandedSource: """
          final class ProfileRoute: PageRoute {
              static func register() {
                  register("profile")
              }

              required init() {
              }

              @section("__DATA_CONST,__routekit")
              @used
              private static let _routekit_route_item: @convention(c) () -> UnsafeRawPointer = {
                  unsafeBitCast(ProfileRoute.self, to: UnsafeRawPointer.self)
              }

              private static let _routekit_route_type_check: any RouteHandler.Type = ProfileRoute.self
          }
          """,
        macros: testMacros
      )
    }

    func testRouteRejectsInvalidPriority() throws {
      assertMacroExpansion(
        """
        @Route(patterns: [.init("profile", priority: .critical)])
        struct ProfileRoute: PageRoute {
        }
        """,
        expandedSource: """
          struct ProfileRoute: PageRoute {
          }
          """,
        diagnostics: [
          DiagnosticSpec(
            message: "@Route priority must be .low, .default, or .high.",
            line: 1,
            column: 1
          )
        ],
        macros: testMacros
      )
    }
}
