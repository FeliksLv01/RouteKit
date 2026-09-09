import XCTest
@testable import RouteKit

@MainActor
final class RouterTests: XCTestCase {
    private func prepare() {
        Router.resetForTesting(routeTypes: [
            ProfileRoute.self,
            CatchallRoute.self,
            PartialRoute.self,
            AsyncAction.self,
            FalseAction.self,
            NilHandledPageRoute.self,
            NilUnhandledPageRoute.self,
            SingleSegmentRoute.self,
            DefaultPriorityRoute.self,
            HighPriorityRoute.self,
            DefaultFallbackPriorityRoute.self,
            HighFalsePriorityRoute.self,
            ProtectedRoute.self,
            StructAction.self
        ])
        RouterConfig.scheme = "citylink"
        ProfileRoute.lastContext = nil
        AsyncAction.onInit = nil
        AsyncAction.onFinish = nil
        AsyncAction.delayNanoseconds = 20_000_000
        DefaultFallbackPriorityRoute.didOpen = false
        HighFalsePriorityRoute.didOpen = false
        ProtectedRoute.didBuildDestination = false
        ProtectedRoute.isLoggedIn = false
    }

    func testDefaultSchemeAndPageRoute() {
        prepare()
        var openedPage: UIViewController?
        RouterConfig.defaultOpenHandler = { page, context in
            openedPage = page
            ProfileRoute.lastContext = context
        }

        let execution = Router.open("profile/42?scene=query&encoded=a%2520b", params: ["scene": "explicit"])

        XCTAssertNotNil(execution)
        XCTAssertTrue(openedPage is ProfileViewController)
        XCTAssertEqual(ProfileRoute.lastContext?.url.absoluteString, "citylink://profile/42?scene=query&encoded=a%2520b")
        XCTAssertEqual(ProfileRoute.lastContext?.urlParams["id"] as? String, "42")
        XCTAssertEqual(ProfileRoute.lastContext?.urlParams["scene"] as? String, "explicit")
        XCTAssertEqual(ProfileRoute.lastContext?.urlParams["encoded"] as? String, "a%20b")
    }

    func testOptionalParamsAreAccepted() {
        prepare()
        RouterConfig.defaultOpenHandler = { _, context in ProfileRoute.lastContext = context }
        let params: [String: Any]? = ["scene": "optional"]

        let execution: RouteExecution? = Router.open("profile/42", params: params)

        XCTAssertNotNil(execution)
        XCTAssertEqual(ProfileRoute.lastContext?.urlParams["scene"] as? String, "optional")
    }

    func testAnythingMatchesOneComponentAndCatchallMatchesRemainingComponents() {
        prepare()
        XCTAssertTrue(Router.canOpen("profile/42"))
        XCTAssertFalse(Router.canOpen("profile/42/detail"))
        XCTAssertTrue(Router.canOpen("flutter/home/detail"))
        XCTAssertTrue(Router.canOpen("docs/shortcut-id"))
        XCTAssertFalse(Router.canOpen("docs/folder/shortcut-id"))
    }

    func testPriorityAndCustomURLConvertible() {
        prepare()
        var openedType: UIViewController.Type?
        RouterConfig.defaultOpenHandler = { page, _ in openedType = type(of: page) }

        _ = Router.open(TestURL(value: URL(string: "citylink://priority")!))

        XCTAssertTrue(openedType == HighPriorityViewController.self)
    }

    func testPriorityDoesNotFallbackToLowerPriorityWhenExecutionFails() {
        prepare()

        let execution: RouteExecution? = Router.open("priority/fallback")

        XCTAssertNil(execution)
        XCTAssertTrue(HighFalsePriorityRoute.didOpen)
        XCTAssertFalse(DefaultFallbackPriorityRoute.didOpen)
    }

    func testPartialParameterUsesRouteKitSemantics() {
        prepare()
        var context: RouteContext?
        RouterConfig.defaultOpenHandler = { _, value in context = value }

        _ = Router.open("file/report.json")

        XCTAssertEqual(context?.urlParams["name"] as? String, "report")
    }

    func testTriePrefersConstantAndBacktracksToWildcard() {
        var builder = RouteTrieBuilder<Int>()
        builder.register(1, at: ["users", ":id", "settings"])
        builder.register(2, at: ["users", "me", "profile"])
        builder.register(3, at: ["users", "*", "activity"])
        let router = builder.build()

        var parameters = RouteMatchParameters()
        XCTAssertEqual(router.route(path: ["users", "me", "profile"], parameters: &parameters), 2)

        parameters = RouteMatchParameters()
        XCTAssertEqual(router.route(path: ["users", "alice", "settings"], parameters: &parameters), 1)
        XCTAssertEqual(parameters.get("id"), "alice")

        parameters = RouteMatchParameters()
        XCTAssertEqual(router.route(path: ["users", "me", "activity"], parameters: &parameters), 3)
    }

    func testAsyncActionIsRetainedUntilCompletionWhenExecutionIsDiscarded() async {
        prepare()
        let finished = expectation(description: "action finished")
        weak var weakAction: AsyncAction?
        AsyncAction.onInit = { weakAction = $0 }
        AsyncAction.onFinish = { finished.fulfill() }

        let _: RouteExecution? = Router.open("action/async")
        XCTAssertNotNil(weakAction)

        await fulfillment(of: [finished], timeout: 1)
        await Task.yield()
        XCTAssertNil(weakAction)
    }

    func testExplicitCancellationReleasesAction() async {
        prepare()
        let finished = expectation(description: "action cancelled")
        weak var weakAction: AsyncAction?
        AsyncAction.delayNanoseconds = 10_000_000_000
        AsyncAction.onInit = { weakAction = $0 }
        AsyncAction.onFinish = { finished.fulfill() }

        let execution: RouteExecution? = Router.open("action/async")
        XCTAssertNotNil(weakAction)
        execution?.cancel()

        await fulfillment(of: [finished], timeout: 1)
        await Task.yield()
        XCTAssertNil(weakAction)
        AsyncAction.delayNanoseconds = 20_000_000
    }

    func testAsyncOpenAwaitsActionCompletion() async throws {
        prepare()
        var finished = false
        AsyncAction.onFinish = { finished = true }

        let handled = try await Router.open("action/async")

        XCTAssertTrue(handled)
        XCTAssertTrue(finished)
    }

    func testActionResultIsPropagated() async throws {
        prepare()

        let asyncResult = try await Router.open("action/false")
        let execution: RouteExecution? = Router.open("action/false")
        let executionResult = await execution?.result

        XCTAssertFalse(asyncResult)
        XCTAssertNotNil(execution)
        XCTAssertEqual(executionResult, false)
    }

    func testStructActionRouteCanBeRegisteredAndExecuted() async throws {
        prepare()

        let handled = try await Router.open("action/struct")

        XCTAssertTrue(handled)
    }

    func testPageOpenDecidesWhetherNilDestinationWasHandled() async throws {
        prepare()

        let handledExecution: RouteExecution? = Router.open("page/nil-handled")
        let unhandledExecution: RouteExecution? = Router.open("page/nil-unhandled")

        XCTAssertNotNil(handledExecution)
        XCTAssertNil(unhandledExecution)
        let asyncHandled = try await Router.open("page/nil-handled")
        let asyncUnhandled = try await Router.open("page/nil-unhandled")

        XCTAssertTrue(asyncHandled)
        XCTAssertFalse(asyncUnhandled)
    }

    func testURLInterceptorRewritesBeforeMatching() {
        prepare()
        RouterConfig.defaultOpenHandler = { _, context in ProfileRoute.lastContext = context }
        RouterConfig.urlInterceptors = [
            TestURLInterceptor { request in
                guard request.url.host == "legacyProfile",
                      let id = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?
                          .queryItems?
                          .first(where: { $0.name == "id" })?
                          .value else {
                    return .proceed
                }
                guard let url = URL(string: "profile/\(id)") else {
                    return .reject
                }
                return .rewrite(url, params: ["scene": "rewrite"])
            }
        ]

        XCTAssertTrue(Router.canOpen("legacyProfile?id=42"))
        let execution: RouteExecution? = Router.open("legacyProfile?id=42")

        XCTAssertNotNil(execution)
        XCTAssertEqual(ProfileRoute.lastContext?.url.absoluteString, "citylink://profile/42")
        XCTAssertEqual(ProfileRoute.lastContext?.urlParams["id"] as? String, "42")
        XCTAssertEqual(ProfileRoute.lastContext?.urlParams["scene"] as? String, "rewrite")
    }

    func testURLInterceptorCanHandleOrRejectBeforeMatching() async {
        prepare()
        RouterConfig.urlInterceptors = [
            TestURLInterceptor { request in
                request.url.host == "blocked" ? .reject : .proceed
            },
            TestURLInterceptor { request in
                request.url.host == "handled" ? .handled(true) : .proceed
            }
        ]

        let blockedExecution: RouteExecution? = Router.open("blocked")
        let handledExecution: RouteExecution? = Router.open("handled")

        XCTAssertFalse(Router.canOpen("blocked"))
        XCTAssertTrue(Router.canOpen("handled"))
        let blockedResult = await blockedExecution?.result
        let handledResult = await handledExecution?.result
        XCTAssertEqual(blockedResult, false)
        XCTAssertEqual(handledResult, true)
    }

    func testRouteMiddlewareCanBlockProtectedRoute() async throws {
        prepare()
        ProtectedRoute.isLoggedIn = false

        let handled = try await Router.open("protected")

        XCTAssertFalse(handled)
        XCTAssertFalse(ProtectedRoute.didBuildDestination)
    }

    func testRouteMiddlewareAllowsProtectedRouteWhenLoggedIn() async throws {
        prepare()
        ProtectedRoute.isLoggedIn = true
        RouterConfig.defaultOpenHandler = { _, context in ProfileRoute.lastContext = context }

        let handled = try await Router.open("protected")

        XCTAssertTrue(handled)
        XCTAssertTrue(ProtectedRoute.didBuildDestination)
        XCTAssertEqual(ProfileRoute.lastContext?.url.absoluteString, "citylink://protected")
    }

    func testGlobalMiddlewareWrapsRouteResponse() async throws {
        prepare()
        var events: [String] = []
        RouterConfig.middlewares = [
            TestRouteMiddleware { request, next in
                events.append("before:\(request.context.url.host ?? "")")
                let response = try await next.respond(to: request)
                events.append("after:\(response.handled)")
                return response
            }
        ]

        let handled = try await Router.open("action/false")

        XCTAssertFalse(handled)
        XCTAssertEqual(events, ["before:action", "after:false"])
    }
}

@MainActor
private final class ProfileRoute: PageRoute {
    static var lastContext: RouteContext?

    static func register() {
        register("profile/:id")
    }

    func destination(with context: RouteContext) -> UIViewController? {
        ProfileViewController()
    }
}

private final class ProfileViewController: UIViewController {}

@MainActor
private final class CatchallRoute: PageRoute {
    static func register() {
        register("flutter/**")
    }

    func destination(with context: RouteContext) -> UIViewController? {
        UIViewController()
    }
}

@MainActor
private final class PartialRoute: PageRoute {
    static func register() {
        register("file/:{name}.json")
    }

    func destination(with context: RouteContext) -> UIViewController? {
        UIViewController()
    }
}

@MainActor
private final class SingleSegmentRoute: PageRoute {
    static func register() {
        register("docs/*")
    }

    func destination(with context: RouteContext) -> UIViewController? { UIViewController() }
}

@MainActor
private final class DefaultPriorityRoute: PageRoute {
    static func register() {
        register("priority")
    }

    func destination(with context: RouteContext) -> UIViewController? { UIViewController() }
}

@MainActor
private final class HighPriorityRoute: PageRoute {
    static func register() {
        register("priority", priority: .high)
    }

    func destination(with context: RouteContext) -> UIViewController? { HighPriorityViewController() }
}

private final class HighPriorityViewController: UIViewController {}

@MainActor
private final class DefaultFallbackPriorityRoute: PageRoute {
    static var didOpen = false

    static func register() {
        register("priority/fallback")
    }

    func destination(with context: RouteContext) -> UIViewController? {
        UIViewController()
    }

    func open(_ page: UIViewController?, context: RouteContext) -> Bool {
        Self.didOpen = true
        return true
    }
}

@MainActor
private final class HighFalsePriorityRoute: PageRoute {
    static var didOpen = false

    static func register() {
        register("priority/fallback", priority: .high)
    }

    func destination(with context: RouteContext) -> UIViewController? {
        UIViewController()
    }

    func open(_ page: UIViewController?, context: RouteContext) -> Bool {
        Self.didOpen = true
        return false
    }
}

@MainActor
private final class NilHandledPageRoute: PageRoute {
    static func register() {
        register("page/nil-handled")
    }

    func open(_ page: UIViewController?, context: RouteContext) -> Bool {
        page == nil
    }
}

@MainActor
private final class NilUnhandledPageRoute: PageRoute {
    static func register() {
        register("page/nil-unhandled")
    }

    func open(_ page: UIViewController?, context: RouteContext) -> Bool {
        false
    }
}

private struct TestURL: URLConvertible {
    let value: URL
    var urlValue: URL? { value }
}

@MainActor
private final class ProtectedRoute: PageRoute {
    static var isLoggedIn = false
    static var didBuildDestination = false

    static var middlewares: [any RouteMiddleware] {
        [LoginRequiredMiddleware(isLoggedIn: isLoggedIn)]
    }

    static func register() {
        register("protected")
    }

    func destination(with context: RouteContext) -> UIViewController? {
        Self.didBuildDestination = true
        return ProfileViewController()
    }
}

private struct LoginRequiredMiddleware: RouteMiddleware {
    let isLoggedIn: Bool

    func respond(to request: RouteRequest, chainingTo next: any RouteResponder) async throws -> RouteResponse {
        guard isLoggedIn else {
            return RouteResponse(handled: false)
        }
        return try await next.respond(to: request)
    }
}

private struct TestRouteMiddleware: RouteMiddleware {
    let body: @MainActor (RouteRequest, any RouteResponder) async throws -> RouteResponse

    func respond(to request: RouteRequest, chainingTo next: any RouteResponder) async throws -> RouteResponse {
        try await body(request, next)
    }
}

private struct TestURLInterceptor: RouteURLInterceptor {
    let body: (RouteURLRequest) -> RouteURLInterceptResult

    func intercept(_ request: RouteURLRequest) -> RouteURLInterceptResult {
        body(request)
    }
}

@MainActor
private final class AsyncAction: ActionRoute {
    static var delayNanoseconds: UInt64 = 20_000_000
    static var onInit: ((AsyncAction) -> Void)?
    static var onFinish: (() -> Void)?

    init() {
        Self.onInit?(self)
    }

    static func register() {
        register("action/async")
    }

    func handle(with context: RouteContext) async throws -> Bool {
        defer { Self.onFinish?() }
        try await Task.sleep(nanoseconds: Self.delayNanoseconds)
        return true
    }
}

@MainActor
private final class FalseAction: ActionRoute {
    static func register() {
        register("action/false")
    }

    func handle(with context: RouteContext) async throws -> Bool {
        false
    }
}

@MainActor
private struct StructAction: ActionRoute {
    static func register() {
        register("action/struct")
    }

    func handle(with context: RouteContext) async throws -> Bool {
        true
    }
}
