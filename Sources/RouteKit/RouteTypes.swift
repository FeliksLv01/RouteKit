import Foundation
import UIKit

/// The matching priority of a registered route pattern.
public enum RoutePriority: Int, Sendable {
    /// Matches after default- and high-priority routes.
    case low
    /// The standard route priority.
    case `default`
    /// Matches before default- and low-priority routes.
    case high
}

/// Errors produced while registering, resolving, or executing routes.
public enum RouteError: Error {
    /// The supplied string cannot be converted into a URL.
    case invalidURL(String)
    /// A relative route was opened before configuring ``RouterConfig/scheme``.
    case missingDefaultScheme(String)
    /// No registered route matches the resolved URL.
    case notFound(URL)
    /// A registered route pattern is malformed.
    case invalidPattern(String)
    /// Route registration recursively entered itself.
    case registrationReentered
    /// Automatic route registration could not be completed.
    case registrationFailed
    /// A registered type does not implement a supported route protocol.
    case unsupportedRouteType(Any.Type)
    /// URL interceptors rewrote a request too many times.
    case tooManyURLInterceptorRewrites(URL)
}

@MainActor
/// The URL and merged parameters supplied to a route handler.
public final class RouteContext {
    /// The normalized URL selected for route execution.
    public let url: URL
    /// Path, query, interceptor, and explicit parameters merged for this request.
    public let urlParams: [String: Any]

    /// Creates a route context.
    /// - Parameters:
    ///   - url: The normalized route URL.
    ///   - urlParams: The parameters available to the route handler.
    public init(url: URL, urlParams: [String: Any]) {
        self.url = url
        self.urlParams = urlParams
    }
}

/// Normalizes route strings before registration and matching.
public protocol RouteNormalizer {
    /// Returns the canonical representation of a route string.
    func normalize(_ value: String) -> String
}

/// The request passed to a URL interceptor before route matching.
public struct RouteURLRequest {
    /// The URL supplied by the caller before any rewrite.
    public let originalURL: URL
    /// The URL currently being evaluated.
    public let url: URL
    /// Parameters currently associated with the request.
    public let params: [String: Any]
    /// Whether the request comes from ``Router/canOpen(_:)``.
    public let isDryRun: Bool

    /// Creates an interceptor request.
    public init(originalURL: URL, url: URL, params: [String: Any], isDryRun: Bool) {
        self.originalURL = originalURL
        self.url = url
        self.params = params
        self.isDryRun = isDryRun
    }
}

/// The decision returned by a ``RouteURLInterceptor``.
public enum RouteURLInterceptResult {
    /// Continues matching the current URL.
    case proceed
    /// Restarts interception and matching with another URL and optional parameters.
    case rewrite(URL, params: [String: Any]? = nil)
    /// Finishes routing immediately with the supplied handled state.
    case handled(Bool)
    /// Rejects the request without matching a route.
    case reject
}

@MainActor
/// Inspects, rewrites, handles, or rejects URLs before route matching.
public protocol RouteURLInterceptor {
    /// Intercepts one URL request.
    func intercept(_ request: RouteURLRequest) -> RouteURLInterceptResult
}

@MainActor
/// The request passed through the middleware and route responder chain.
public struct RouteRequest {
    /// The context that will be supplied to the route handler.
    public let context: RouteContext
    /// The concrete route handler type selected during matching.
    public let handlerType: any RouteHandler.Type

    /// Creates a middleware request.
    public init(context: RouteContext, handlerType: any RouteHandler.Type) {
        self.context = context
        self.handlerType = handlerType
    }
}

/// The result returned by a route responder.
public struct RouteResponse {
    /// Whether the request was handled.
    public let handled: Bool

    /// Creates a route response.
    public init(handled: Bool) {
        self.handled = handled
    }
}

@MainActor
/// A link in the asynchronous route response chain.
public protocol RouteResponder {
    /// Produces a response for a matched route request.
    func respond(to request: RouteRequest) async throws -> RouteResponse
}

@MainActor
/// Wraps route execution with cross-cutting behavior.
public protocol RouteMiddleware {
    /// Handles a request and optionally forwards it to the next responder.
    func respond(to request: RouteRequest, chainingTo next: any RouteResponder) async throws -> RouteResponse
}

@MainActor
/// Global configuration applied to route registration and execution.
///
/// Set configuration values before the first routing or availability request.
/// RouteKit freezes the configuration after routing begins.
public enum RouterConfig {
    private static var configuredScheme: String?
    private static var configuredNormalizer: (any RouteNormalizer)?
    private static var configuredURLInterceptors: [any RouteURLInterceptor] = []
    private static var configuredMiddlewares: [any RouteMiddleware] = []
    private static var configuredDefaultOpenHandler: @MainActor (UIViewController, RouteContext) -> Void = DefaultPageOpener.open
    private static var configuredUnhandledErrorHandler: @MainActor (any Error, URL?) -> Void = { _, _ in }

    static var isFrozen = false

    /// The scheme used to turn relative route strings into URLs.
    public static var scheme: String? {
        get { configuredScheme }
        set { update { configuredScheme = newValue } }
    }

    /// An optional normalizer applied consistently to registrations and requests.
    public static var normalizer: (any RouteNormalizer)? {
        get { configuredNormalizer }
        set { update { configuredNormalizer = newValue } }
    }

    /// URL interceptors evaluated before route matching, in array order.
    public static var urlInterceptors: [any RouteURLInterceptor] {
        get { configuredURLInterceptors }
        set { update { configuredURLInterceptors = newValue } }
    }

    /// Global middleware wrapped around every matched route.
    public static var middlewares: [any RouteMiddleware] {
        get { configuredMiddlewares }
        set { update { configuredMiddlewares = newValue } }
    }

    /// Opens a destination produced by a ``PageRoute``.
    ///
    /// The default implementation pushes from the current key window's top navigation controller when available.
    public static var defaultOpenHandler: @MainActor (UIViewController, RouteContext) -> Void {
        get { configuredDefaultOpenHandler }
        set { update { configuredDefaultOpenHandler = newValue } }
    }

    /// Receives errors from the nonthrowing route API.
    public static var unhandledErrorHandler: @MainActor (any Error, URL?) -> Void {
        get { configuredUnhandledErrorHandler }
        set { update { configuredUnhandledErrorHandler = newValue } }
    }

    static func freeze() {
        isFrozen = true
    }

    static func resetForTesting() {
        isFrozen = false
        configuredScheme = nil
        configuredNormalizer = nil
        configuredURLInterceptors = []
        configuredMiddlewares = []
        configuredDefaultOpenHandler = DefaultPageOpener.open
        configuredUnhandledErrorHandler = { _, _ in }
    }

    private static func update(_ body: () -> Void) {
        precondition(!isFrozen, "RouterConfig cannot be changed after the first open or canOpen")
        body()
    }
}

@MainActor
private enum DefaultPageOpener {
    static func open(_ page: UIViewController, context: RouteContext) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController else { return }
        let top = topViewController(from: root)
        guard let navigationController = (top as? UINavigationController) ?? top.navigationController else { return }
        navigationController.pushViewController(page, animated: true)
    }

    private static func topViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigationController = viewController as? UINavigationController,
           let visible = navigationController.visibleViewController {
            return topViewController(from: visible)
        }
        if let tabBarController = viewController as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return topViewController(from: selected)
        }
        return viewController
    }
}

@MainActor
/// A type that participates in route registration.
public protocol RouteRegistrable {
    /// Registers the patterns handled by this type.
    static func register()
}

@MainActor
/// The common requirements for page and action route handlers.
public protocol RouteHandler: RouteRegistrable {
    /// Creates a handler for one route execution.
    init()
    /// Middleware applied only when this route type is selected.
    static var middlewares: [any RouteMiddleware] { get }
}

public extension RouteHandler {
    /// Performs no custom registration by default.
    static func register() {}

    /// Returns no route-specific middleware by default.
    static var middlewares: [any RouteMiddleware] { [] }

    /// Registers one route pattern for this handler type.
    /// - Parameters:
    ///   - pattern: The path pattern to register.
    ///   - priority: The pattern's matching priority.
    static func register(_ pattern: String, priority: RoutePriority = .default) {
        RouterRuntime.shared.register(pattern: pattern, priority: priority, handlerType: Self.self)
    }
}

@MainActor
/// A route that creates and opens a UIKit view controller.
public protocol PageRoute: RouteHandler {
    /// Creates the destination for a matched route context.
    func destination(with context: RouteContext) -> UIViewController?
    /// Presents or otherwise handles a destination.
    func open(_ page: UIViewController?, context: RouteContext) -> Bool
}

public extension PageRoute {
    /// Returns no destination by default.
    func destination(with context: RouteContext) -> UIViewController? { nil }

    /// Opens a non-`nil` destination through ``RouterConfig/defaultOpenHandler``.
    func open(_ page: UIViewController?, context: RouteContext) -> Bool {
        guard let page else { return false }
        RouterConfig.defaultOpenHandler(page, context)
        return true
    }
}

@MainActor
/// A route that performs asynchronous work without requiring a page destination.
public protocol ActionRoute: RouteHandler {
    /// Handles a matched route context.
    func handle(with context: RouteContext) async throws -> Bool
}

public extension ActionRoute {
    /// Reports an unsupported route type when the route does not provide an implementation.
    func handle(with context: RouteContext) async throws -> Bool {
        throw RouteError.unsupportedRouteType(type(of: self))
    }
}
