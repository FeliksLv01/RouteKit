import Foundation

@MainActor
public enum Router {
    @discardableResult
    public static func open(_ url: any URLConvertible, params: [String: Any]? = nil) async throws -> Bool {
        switch try RouterRuntime.shared.resolve(url, params: params ?? [:], appliesURLInterceptors: true) {
        case .handled(let handled):
            return handled
        case .route(let handlerType, let context):
            let handler = handlerType.init()
            return try await respond(handler: handler, handlerType: handlerType, context: context).handled
        }
    }

    private static func respond(
        handler: any RouteHandler,
        handlerType: any RouteHandler.Type,
        context: RouteContext
    ) async throws -> RouteResponse {
        let request = RouteRequest(context: context, handlerType: handlerType)
        let middlewares = RouterConfig.middlewares + handlerType.middlewares
        let responder = middlewares.reversed().reduce(
            AnyRouteResponder(TerminalRouteResponder(handler: handler))
        ) { next, middleware in
            AnyRouteResponder(MiddlewareRouteResponder(middleware: middleware, next: next))
        }
        return try await responder.respond(to: request)
    }

    private static func openWithoutMiddleware(
        handler: any RouteHandler,
        handlerType: any RouteHandler.Type,
        context: RouteContext
    ) throws -> RouteExecution? {
        if let pageRoute = handler as? any PageRoute {
            guard pageRoute.open(pageRoute.destination(with: context), context: context) else { return nil }
            return RouteExecution(identifier: nil, immediateResult: true)
        }
        guard let actionRoute = handler as? any ActionRoute else {
            throw RouteError.unsupportedRouteType(handlerType)
        }
        return RouterRuntime.shared.start(actionRoute, context: context)
    }

    private static func openWithMiddleware(
        handler: any RouteHandler,
        handlerType: any RouteHandler.Type,
        context: RouteContext
    ) -> RouteExecution {
        RouterRuntime.shared.start(handler: handler) {
            do {
                return try await respond(handler: handler, handlerType: handlerType, context: context).handled
            } catch is CancellationError {
                return false
            } catch {
                RouterConfig.unhandledErrorHandler(error, context.url)
                return false
            }
        }
    }

    @discardableResult
    public static func open(_ url: any URLConvertible, params: [String: Any]? = nil) -> RouteExecution? {
        do {
            switch try RouterRuntime.shared.resolve(url, params: params ?? [:], appliesURLInterceptors: true) {
            case .handled(let handled):
                return RouteExecution(identifier: nil, immediateResult: handled)
            case .route(let handlerType, let context):
                let handler = handlerType.init()
                let middlewares = RouterConfig.middlewares + handlerType.middlewares
                if middlewares.isEmpty {
                    return try openWithoutMiddleware(handler: handler, handlerType: handlerType, context: context)
                }
                return openWithMiddleware(handler: handler, handlerType: handlerType, context: context)
            }
        } catch {
            RouterConfig.unhandledErrorHandler(error, url.urlValue)
            return nil
        }
    }

    public static func canOpen(_ url: any URLConvertible) -> Bool {
        RouterRuntime.shared.canResolve(url)
    }

    static func resetForTesting(routeTypes: [any RouteHandler.Type]) {
        RouterRuntime.shared.resetForTesting(routeTypes: routeTypes)
    }
}

@MainActor
private struct TerminalRouteResponder: RouteResponder {
    let handler: any RouteHandler

    func respond(to request: RouteRequest) async throws -> RouteResponse {
        try Task.checkCancellation()
        if let pageRoute = handler as? any PageRoute {
            return RouteResponse(handled: pageRoute.open(pageRoute.destination(with: request.context), context: request.context))
        }
        guard let actionRoute = handler as? any ActionRoute else {
            throw RouteError.unsupportedRouteType(type(of: handler))
        }
        return RouteResponse(handled: try await actionRoute.handle(with: request.context))
    }
}

@MainActor
private struct MiddlewareRouteResponder: RouteResponder {
    let middleware: any RouteMiddleware
    let next: AnyRouteResponder

    func respond(to request: RouteRequest) async throws -> RouteResponse {
        try await middleware.respond(to: request, chainingTo: next)
    }
}

@MainActor
private struct AnyRouteResponder: RouteResponder {
    private let body: @MainActor (RouteRequest) async throws -> RouteResponse

    init(_ responder: any RouteResponder) {
        body = { request in
            try await responder.respond(to: request)
        }
    }

    func respond(to request: RouteRequest) async throws -> RouteResponse {
        try await body(request)
    }
}
