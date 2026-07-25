import Foundation
import UIKit

public enum RoutePriority: Int, Sendable {
    case low
    case `default`
    case high
}

public enum RouteError: Error {
    case invalidURL(String)
    case missingDefaultScheme(String)
    case notFound(URL)
    case invalidPattern(String)
    case registrationReentered
    case registrationFailed
    case unsupportedRouteType(Any.Type)
    case tooManyURLInterceptorRewrites(URL)
}

@MainActor
public final class RouteContext {
    public let url: URL
    public let urlParams: [String: Any]

    public init(url: URL, urlParams: [String: Any]) {
        self.url = url
        self.urlParams = urlParams
    }
}

public protocol RouteNormalizer {
    func normalize(_ value: String) -> String
}

public struct RouteURLRequest {
    public let originalURL: URL
    public let url: URL
    public let params: [String: Any]
    public let isDryRun: Bool

    public init(originalURL: URL, url: URL, params: [String: Any], isDryRun: Bool) {
        self.originalURL = originalURL
        self.url = url
        self.params = params
        self.isDryRun = isDryRun
    }
}

public enum RouteURLInterceptResult {
    case proceed
    case rewrite(URL, params: [String: Any]? = nil)
    case handled(Bool)
    case reject
}

@MainActor
public protocol RouteURLInterceptor {
    func intercept(_ request: RouteURLRequest) -> RouteURLInterceptResult
}

@MainActor
public struct RouteRequest {
    public let context: RouteContext
    public let handlerType: any RouteHandler.Type

    public init(context: RouteContext, handlerType: any RouteHandler.Type) {
        self.context = context
        self.handlerType = handlerType
    }
}

public struct RouteResponse {
    public let handled: Bool

    public init(handled: Bool) {
        self.handled = handled
    }
}

@MainActor
public protocol RouteResponder {
    func respond(to request: RouteRequest) async throws -> RouteResponse
}

@MainActor
public protocol RouteMiddleware {
    func respond(to request: RouteRequest, chainingTo next: any RouteResponder) async throws -> RouteResponse
}

@MainActor
public enum RouterConfig {
    private static var configuredScheme: String?
    private static var configuredNormalizer: (any RouteNormalizer)?
    private static var configuredURLInterceptors: [any RouteURLInterceptor] = []
    private static var configuredMiddlewares: [any RouteMiddleware] = []
    private static var configuredDefaultOpenHandler: @MainActor (UIViewController, RouteContext) -> Void = DefaultPageOpener.open
    private static var configuredUnhandledErrorHandler: @MainActor (any Error, URL?) -> Void = { _, _ in }

    static var isFrozen = false

    public static var scheme: String? {
        get { configuredScheme }
        set { update { configuredScheme = newValue } }
    }

    public static var normalizer: (any RouteNormalizer)? {
        get { configuredNormalizer }
        set { update { configuredNormalizer = newValue } }
    }

    public static var urlInterceptors: [any RouteURLInterceptor] {
        get { configuredURLInterceptors }
        set { update { configuredURLInterceptors = newValue } }
    }

    public static var middlewares: [any RouteMiddleware] {
        get { configuredMiddlewares }
        set { update { configuredMiddlewares = newValue } }
    }

    public static var defaultOpenHandler: @MainActor (UIViewController, RouteContext) -> Void {
        get { configuredDefaultOpenHandler }
        set { update { configuredDefaultOpenHandler = newValue } }
    }

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
public protocol RouteRegistrable {
    static func register()
}

@MainActor
public protocol RouteHandler: RouteRegistrable {
    init()
    static var middlewares: [any RouteMiddleware] { get }
}

public extension RouteHandler {
    static func register() {}

    static var middlewares: [any RouteMiddleware] { [] }

    static func register(_ pattern: String, priority: RoutePriority = .default) {
        RouterRuntime.shared.register(pattern: pattern, priority: priority, handlerType: Self.self)
    }
}

@MainActor
public protocol PageRoute: RouteHandler {
    func destination(with context: RouteContext) -> UIViewController?
    func open(_ page: UIViewController?, context: RouteContext) -> Bool
}

public extension PageRoute {
    func destination(with context: RouteContext) -> UIViewController? { nil }

    func open(_ page: UIViewController?, context: RouteContext) -> Bool {
        guard let page else { return false }
        RouterConfig.defaultOpenHandler(page, context)
        return true
    }
}

@MainActor
public protocol ActionRoute: RouteHandler {
    func handle(with context: RouteContext) async throws -> Bool
}

public extension ActionRoute {
    func handle(with context: RouteContext) async throws -> Bool {
        throw RouteError.unsupportedRouteType(type(of: self))
    }
}
