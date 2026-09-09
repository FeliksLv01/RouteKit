import XCTest
@testable import RouteKit

@MainActor
final class RouteMacroIntegrationTests: XCTestCase {
    private func prepare() {
        Router.resetForTesting(routeTypes: [MacroRegisteredRoute.self])
        RouterConfig.scheme = "tk"
        MacroRegisteredRoute.lastID = nil
    }

    func testRouteMacroGeneratesRegistration() async throws {
        prepare()
        XCTAssertTrue(Router.canOpen("macro/42"))

        let handled = try await Router.open("macro/42")

        XCTAssertTrue(handled)
        XCTAssertEqual(MacroRegisteredRoute.lastID, "42")
    }

    func testRouteMacroEmitsDiscoverableSectionItem() {
        prepare()
        let routeTypes = RouteSectionReader.routeTypes()

        XCTAssertTrue(routeTypes.contains { ObjectIdentifier($0) == ObjectIdentifier(MacroRegisteredRoute.self) })
    }
}

@Route(patterns: [
    .init("macro/:id", priority: .high)
])
@MainActor
private struct MacroRegisteredRoute: ActionRoute {
    static var lastID: String?

    func handle(with context: RouteContext) async throws -> Bool {
        Self.lastID = context.urlParams["id"] as? String
        return Self.lastID != nil
    }
}
